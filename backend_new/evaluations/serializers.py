from django.utils import timezone
from rest_framework import serializers

from . import classification as pr48
from .models import EvaluationOrganoleptique

# Attributs positifs — echelle 0-10 (seuils PR-48 inchanges)
CHAMPS_POSITIFS = ('fruite', 'amertume', 'piquant')
# Defauts — echelle 0-10 (COI, hors perimetre du PR-48)
CHAMPS_DEFAUTS = ('chome', 'moisi', 'vinaigre', 'rance', 'gele', 'autres_defaut')


class EvaluationSerializer(serializers.ModelSerializer):
    # Read-only display field — Flutter expects degustateur_nom alongside degustateur id
    degustateur_nom = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = EvaluationOrganoleptique
        fields = [
            'id', 'echantillon', 'degustateur', 'degustateur_nom', 'session',
            'statut', 'classification',
            'classe_interne', 'classe_interne_manuelle', 'classe_interne_motif',
            'classe_interne_choisie_le', 'profil_non_harmonieux',
            'fruite', 'type_fruite', 'amertume', 'piquant',
            'chome', 'moisi', 'vinaigre', 'rance', 'gele',
            'autres_defaut', 'autres_defaut_nom',
            'commentaire',
            'soumis_le', 'date_modification',
        ]
        read_only_fields = [
            'id', 'degustateur', 'degustateur_nom',
            'classe_interne_choisie_le',
            'soumis_le', 'date_modification',
        ]

    def validate_echantillon(self, value):
        if not value.recu_physiquement:
            raise serializers.ValidationError(
                "Cet échantillon n'est pas encore arrivé à la société. Cochez d'abord "
                "« Réception physique » sur sa fiche, puis soumettez l'évaluation."
            )
        return value

    def get_degustateur_nom(self, obj):
        if obj.degustateur:
            return f"{obj.degustateur.prenom} {obj.degustateur.nom}"
        return None

    def _valeur(self, attrs, champ, defaut=None):
        """Valeur effective apres application du PATCH sur l'instance existante."""
        if champ in attrs:
            return attrs[champ]
        if self.instance is not None:
            return getattr(self.instance, champ)
        return defaut

    def validate(self, attrs):
        erreurs = {}

        # 1 / 2 — bornes des echelles de saisie
        for champ in CHAMPS_POSITIFS:
            valeur = attrs.get(champ)
            if valeur is not None and not (0 <= float(valeur) <= pr48.MAX_POSITIF):
                erreurs[champ] = (
                    f'Doit etre compris entre 0 et {pr48.MAX_POSITIF:g} (echelle PR-48).'
                )
        for champ in CHAMPS_DEFAUTS:
            valeur = attrs.get(champ)
            if valeur is not None and not (0 <= float(valeur) <= pr48.MAX_DEFAUT):
                erreurs[champ] = (
                    f'Doit etre compris entre 0 et {pr48.MAX_DEFAUT:g} (echelle COI).'
                )
        if erreurs:
            raise serializers.ValidationError(erreurs)

        fruite = self._valeur(attrs, 'fruite', 0)
        amertume = self._valeur(attrs, 'amertume', 0)
        piquant = self._valeur(attrs, 'piquant', 0)
        type_fruite = self._valeur(attrs, 'type_fruite', pr48.VERT)
        non_harmonieux = bool(self._valeur(attrs, 'profil_non_harmonieux', False))
        classe = self._valeur(attrs, 'classe_interne', '') or ''
        manuelle = bool(self._valeur(attrs, 'classe_interne_manuelle', False))

        mediane = pr48.mediane_defauts(
            *[self._valeur(attrs, champ, 0) for champ in CHAMPS_DEFAUTS]
        )
        coi = pr48.calculer_classification_coi(mediane, fruite)
        attendue = pr48.calculer_classe_interne(
            coi, fruite, type_fruite, amertume, piquant,
            profil_non_harmonieux=non_harmonieux,
        )

        # 3 — le PR-48 SS6 reserve la classe interne aux huiles extra vierges
        if classe and coi != pr48.EXTRA_VIERGE:
            raise serializers.ValidationError({'classe_interne': (
                'Reservee aux huiles extra vierges au sens COI (PR-48 SS6).'
            )})

        # 6 — le SS9 interdit les deux classes hautes a un profil non harmonieux
        if non_harmonieux and classe in pr48.CLASSES_SOUMISES_A_HARMONIE:
            raise serializers.ValidationError({'classe_interne': (
                'Interdite lorsque le profil est declare non harmonieux (PR-48 SS9).'
            )})

        if attendue is not None:
            # 5 — la grille a repondu : la classe est automatique, pas manuelle
            if manuelle:
                raise serializers.ValidationError({'classe_interne_manuelle': (
                    'La grille SS8 rend une classe : le choix manuel est reserve aux '
                    'cas hors grille.'
                )})
            # 4 — et elle doit etre celle que la grille rend
            if classe and classe != attendue:
                raise serializers.ValidationError({'classe_interne': (
                    f'La grille SS8 rend « {attendue} » pour ces valeurs.'
                )})
        elif classe and not manuelle:
            # hors grille : seul un choix manuel explicite est accepte
            raise serializers.ValidationError({'classe_interne': (
                'Aucune ligne de la grille SS8 ne correspond : le choix doit etre '
                'marque manuel (classe_interne_manuelle).'
            )})

        # Horodatage du choix manuel — pose par le serveur, jamais par le client
        if manuelle and classe:
            ancienne = getattr(self.instance, 'classe_interne', None)
            if self.instance is None or ancienne != classe:
                attrs['classe_interne_choisie_le'] = timezone.now()
        elif 'classe_interne' in attrs or 'classe_interne_manuelle' in attrs:
            attrs['classe_interne_choisie_le'] = None

        return attrs
