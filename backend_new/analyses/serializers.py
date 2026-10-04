from rest_framework import serializers

from echantillons.models import Echantillon
from notifications.models import Notification

from . import normes_coi
from .models import AnalyseLabo, CritereAnalyse

# Les 28 valeurs mesurees, dans l'ordre du rapport papier. Une seule liste :
# ajouter un parametre dans normes_coi suffit a l'exposer par l'API.
VALEURS_MESUREES = [p.cle for p in normes_coi.TOUS_PARAMETRES]


class CritereAnalyseSerializer(serializers.ModelSerializer):
    class Meta:
        model = CritereAnalyse
        fields = ['id', 'label', 'valeur', 'unite', 'valeur_min', 'valeur_max', 'conforme']


class AnalyseLaboSerializer(serializers.ModelSerializer):
    criteres = CritereAnalyseSerializer(many=True, read_only=True)
    echantillon_id = serializers.UUIDField(source='echantillon.id', read_only=True)
    echantillon_ref = serializers.CharField(source='echantillon.reference_bouteille', read_only=True)
    acidite_libre = serializers.SerializerMethodField()
    technicien_id = serializers.UUIDField(source='technicien.id', read_only=True)
    technicien_nom = serializers.SerializerMethodField()
    # Deduits des valeurs, jamais saisis : le classement et l'alerte doivent
    # dire la meme chose sur tous les ecrans.
    classification = serializers.CharField(read_only=True)
    parametres_hors_normes = serializers.ListField(read_only=True)

    class Meta:
        model = AnalyseLabo
        fields = [
            'id', 'echantillon', 'echantillon_id', 'echantillon_ref',
            'technicien', 'technicien_id', 'technicien_nom', 'statut',
            # identification du certificat
            'numero_certificat', 'numero_lot',
            'date_debut_analyse', 'date_fin_analyse', 'quantite_ml',
            # valeurs mesurees
            *VALEURS_MESUREES,
            'acidite_libre',
            # deduits
            'classification', 'parametres_hors_normes',
            'photo', 'notes', 'criteres',
            'date_analyse', 'date_modification',
        ]
        read_only_fields = [
            'id', 'technicien', 'technicien_id', 'technicien_nom',
            'classification', 'parametres_hors_normes',
            'date_analyse', 'date_modification',
        ]

    def get_acidite_libre(self, obj):
        return obj.acidite

    def get_technicien_nom(self, obj):
        if obj.technicien:
            return f'{obj.technicien.prenom} {obj.technicien.nom}'.strip()
        return ''

    def to_internal_value(self, data):
        data = data.copy()
        if data.get('acidite_libre') is not None and data.get('acidite') is None:
            data['acidite'] = data['acidite_libre']
        if data.get('echantillon_id') is not None and data.get('echantillon') is None:
            data['echantillon'] = data['echantillon_id']
        return super().to_internal_value(data)

    def validate(self, attrs):
        echantillon = attrs.get('echantillon')
        if self.instance:
            echantillon = echantillon or self.instance.echantillon
            if self.instance.statut == AnalyseLabo.Statut.SOUMIS:
                raise serializers.ValidationError(
                    {'detail': 'Une analyse soumise ne peut plus etre modifiee.'}
                )

        if echantillon is None:
            raise serializers.ValidationError({'echantillon': ['Champ requis.']})

        if not echantillon.recu_physiquement:
            raise serializers.ValidationError(
                {'echantillon': ['Seuls les echantillons recus physiquement peuvent etre analyses.']}
            )

        duplicate = AnalyseLabo.objects.filter(echantillon=echantillon)
        if self.instance:
            duplicate = duplicate.exclude(pk=self.instance.pk)
        if duplicate.exists():
            raise serializers.ValidationError(
                {'echantillon': ['Une analyse existe deja pour cet echantillon.']}
            )

        return attrs


class LabEchantillonAnalyseSerializer(serializers.ModelSerializer):
    ref = serializers.CharField(source='numero', read_only=True)
    fournisseur_nom = serializers.SerializerMethodField()
    collecteur_nom = serializers.SerializerMethodField()
    date_arrivee = serializers.DateTimeField(source='date_arrivee_echantillon', read_only=True)
    numero_lot = serializers.SerializerMethodField()
    origine_campagne = serializers.SerializerMethodField()
    priorite = serializers.SerializerMethodField()
    notes_reception = serializers.SerializerMethodField()
    analyse = AnalyseLaboSerializer(read_only=True)

    class Meta:
        model = Echantillon
        fields = [
            'id', 'ref', 'numero', 'gouvernorat',
            'delegation', 'date_ajout',
            'fournisseur_nom', 'collecteur_nom',
            'reference_bouteille', 'variete', 'quantite_estimee',
            'date_arrivee', 'date_arrivee_echantillon',
            'recu_physiquement', 'date_reception_echantillon',
            'num_citerne', 'date_livraison_stock',
            'numero_lot', 'origine_campagne', 'priorite',
            'notes_reception', 'statut_labo', 'analyse',
        ]

    def get_fournisseur_nom(self, obj):
        return obj.fournisseur.nom if obj.fournisseur else ''

    def get_collecteur_nom(self, obj):
        if obj.collecteur:
            return f'{obj.collecteur.prenom} {obj.collecteur.nom}'.strip()
        return ''

    def get_numero_lot(self, obj):
        return ''

    def get_origine_campagne(self, obj):
        return ''

    def get_priorite(self, obj):
        # Urgent while an urgent request exists and the analysis is not submitted yet.
        if obj.statut_labo == 'soumis':
            return 'normale'
        urgent = obj.notifications.filter(type=Notification.Type.ANALYSE_URGENTE).exists()
        return 'urgente' if urgent else 'normale'

    def get_notes_reception(self, obj):
        return obj.remarques or ''
