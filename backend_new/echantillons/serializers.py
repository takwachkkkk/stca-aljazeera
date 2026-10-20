from rest_framework import serializers

from fournisseurs.models import Fournisseur
from users.models import User

from .models import Echantillon


class EchantillonSerializer(serializers.ModelSerializer):
    fournisseur_nom  = serializers.SerializerMethodField(read_only=True)
    collecteur_nom   = serializers.SerializerMethodField(read_only=True)
    collecteur = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(
            role=User.Role.COLLECTEUR,
            is_active=True,
            date_suppression__isnull=True,
        ),
        required=False,
        allow_null=True,
    )
    modifiable = serializers.SerializerMethodField()

    class Meta:
        model = Echantillon
        fields = [
            'id', 'numero', 'reference_bouteille',
            'fournisseur', 'fournisseur_nom',
            'collecteur', 'collecteur_nom', 'modifiable',
            'gouvernorat', 'delegation', 'cite',
            'variete', 'num_citerne', 'quantite_estimee', 'image_url',
            'statut_collecteur', 'statut_degustateur', 'statut_labo', 'statut_ceo',
            'recu_physiquement', 'date_arrivee_echantillon',
            'date_reception_echantillon',
            'budget_negociation', 'budget_negociation_max', 'nb_renegociations',
            'quantite_cible_t', 'camion_reserve',
            'note_interne', 'raison_refus',
            'prix_final', 'remarque_collecteur',
            'stock_arrive', 'date_livraison_stock', 'date_livraison_stock_fin',
            'classification', 'remarques',
            'date_ajout', 'updated_at',
        ]
        # nb_renegociations n'est jamais pose par le client : seule l'action
        # renvoyer-en-negociation l'incremente, ce qui garantit qu'il compte
        # bien des tours reels et pas ce que l'app veut afficher.
        read_only_fields = [
            'id', 'numero',
            'nb_renegociations', 'date_reception_echantillon',
            'date_ajout', 'updated_at',
        ]
        extra_kwargs = {
            'gouvernorat': {'required': False, 'allow_blank': True},
            'delegation': {'required': False, 'allow_blank': True},
            'cite': {'required': False, 'allow_blank': True},
            'variete': {'required': False, 'allow_blank': True},
            'num_citerne': {'required': False, 'allow_blank': True},
            'quantite_estimee': {'required': False, 'allow_blank': True},
            'image_url': {'required': False, 'allow_blank': True},
            'date_arrivee_echantillon': {'required': False, 'allow_null': True},
            'classification': {'required': False, 'allow_blank': True},
            'remarques': {'required': False, 'allow_blank': True},
        }

    # Champs texte facultatifs : l'application envoie null quand la case est
    # vide. Sans cette conversion, toute modification d'un echantillon sans
    # delegation, cite, remarques... echouait avec « Ce champ ne peut etre nul ».
    CHAMPS_TEXTE_FACULTATIFS = (
        'gouvernorat', 'delegation', 'cite', 'variete', 'num_citerne',
        'quantite_estimee', 'remarques', 'remarque_collecteur', 'camion_reserve',
        'note_interne', 'raison_refus', 'classification',
    )

    def to_internal_value(self, data):
        # JSON seulement : un QueryDict (multipart) n'envoie jamais null.
        if isinstance(data, dict) and not hasattr(data, 'getlist'):
            data = dict(data)
            for champ in self.CHAMPS_TEXTE_FACULTATIFS:
                if champ in data and data[champ] is None:
                    data[champ] = ''
            # image_url null = « pas de nouvelle photo » : on garde l'ancienne.
            if data.get('image_url', '') is None:
                data.pop('image_url')
        if hasattr(data, 'get'):
            raw = data.get('fournisseur_nom') or ''
            self._extra_fournisseur_nom = raw.strip() if isinstance(raw, str) else ''
        else:
            self._extra_fournisseur_nom = ''
        return super().to_internal_value(data)

    def validate(self, attrs):
        if not self.instance and not attrs.get('reference_bouteille'):
            raise serializers.ValidationError(
                {'reference_bouteille': ['La reference bouteille est obligatoire.']}
            )
        return attrs

    def _resolve_fournisseur(self, validated_data, is_update=False):
        nom_input = getattr(self, '_extra_fournisseur_nom', '').strip()

        if nom_input:
            region = validated_data.get(
                'gouvernorat',
                self.instance.gouvernorat if is_update and self.instance else '',
            )
            delegation = validated_data.get(
                'delegation',
                self.instance.delegation if is_update and self.instance else '',
            )
            validated_data['fournisseur'] = self._supplier_by_name_or_create(
                nom_input, region, delegation
            )
            return validated_data

        # Aucune information de fournisseur dans la requete.
        #
        # A la creation, l'echantillon n'a simplement pas de fournisseur.
        # A la modification, il faut LAISSER celui qui existe deja : le
        # degustateur qui corrige une variete envoie sa mise a jour sans champ
        # fournisseur, et effacer le lien ici supprimerait le fournisseur d'un
        # echantillon sans que personne ne le demande ni ne le voie.
        if is_update:
            validated_data.pop('fournisseur', None)
            return validated_data

        validated_data['fournisseur'] = None
        return validated_data

    @staticmethod
    def _supplier_by_name_or_create(nom, region, delegation):
        region = (region or '').strip()
        delegation = (delegation or '').strip()
        existing = Fournisseur.objects.filter(
            nom__iexact=nom,
            region__iexact=region,
            delegation__iexact=delegation,
        ).first()
        if existing:
            return existing
        return Fournisseur.objects.create(
            nom=nom,
            region=region,
            delegation=delegation,
        )

    def create(self, validated_data):
        validated_data = self._resolve_fournisseur(validated_data)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        validated_data = self._resolve_fournisseur(validated_data, is_update=True)
        return super().update(instance, validated_data)

    def get_fournisseur_nom(self, obj):
        return obj.fournisseur.nom if obj.fournisseur else None

    def get_collecteur_nom(self, obj):
        if obj.collecteur:
            return f"{obj.collecteur.prenom} {obj.collecteur.nom}"
        return None

    def get_modifiable(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            return False
        if user.role == User.Role.CHEF_DEGUSTATION:
            return True
        return (
            user.role == User.Role.DEGUSTATEUR
            and obj.enregistre_par_id == user.id
            and not obj.recu_physiquement
        )
