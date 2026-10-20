import uuid
from datetime import datetime
from django.db import IntegrityError, transaction
from django.db import models
from django.conf import settings


class Echantillon(models.Model):

    class StatutCollecteur(models.TextChoices):
        RECEPTIONNE    = 'receptionne',    'Réceptionné'
        EN_NEGOCIATION = 'en_negociation', 'En négociation'
        ACHAT_CONFIRME = 'achat_confirme', 'Achat confirmé'

    class StatutDegustateur(models.TextChoices):
        NON_EVALUEE = 'non_evaluee', 'Non évaluée'
        EN_COURS    = 'en_cours',    'Évaluation en cours'
        SOUMIS      = 'soumis',      'Évaluation soumise'

    class StatutLabo(models.TextChoices):
        EN_ATTENTE = 'en_attente', 'En attente'
        EN_COURS   = 'en_cours',   'En cours'
        SOUMIS     = 'soumis',     'Soumis'

    class StatutCEO(models.TextChoices):
        SELECTIONNE    = 'selectionne',    'Sélectionné'
        EN_NEGOCIATION = 'en_negociation', 'En négociation'
        ACHAT_CONFIRME = 'achat_confirme', 'Achat confirmé'
        REFUSE         = 'refuse',         'Refusé'

    class Classification(models.TextChoices):
        EXTRA_VIERGE    = 'extra_vierge',    'Extra vierge'
        VIERGE          = 'vierge',          'Vierge'
        VIERGE_ORDINAIRE = 'vierge_ordinaire', 'Vierge Ordinaire'
        LAMPANTE        = 'lampante',        'Lampante'

    id                  = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    numero              = models.CharField(max_length=20, unique=True, blank=True)
    reference_bouteille = models.CharField(max_length=100, blank=True)

    # Relations
    fournisseur = models.ForeignKey(
        'fournisseurs.Fournisseur',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='echantillons'
    )
    collecteur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='echantillons_collectes'
    )
    enregistre_par = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='echantillons_enregistres',
    )

    # Location
    gouvernorat = models.CharField(max_length=100)
    delegation  = models.CharField(max_length=100, blank=True)
    cite        = models.CharField(max_length=100, blank=True)

    # Sample physical details (stored as strings: values like "20L" or tank numbers)
    variete          = models.CharField(max_length=255, blank=True)
    num_citerne      = models.CharField(max_length=50, blank=True)
    quantite_estimee = models.CharField(max_length=50, blank=True)
    image_url        = models.CharField(max_length=500, blank=True)

    # Status fields — each role sees its own status
    statut_collecteur = models.CharField(
        max_length=20, choices=StatutCollecteur.choices, default=StatutCollecteur.RECEPTIONNE
    )
    statut_degustateur = models.CharField(
        max_length=20, choices=StatutDegustateur.choices, default=StatutDegustateur.NON_EVALUEE
    )
    statut_labo = models.CharField(
        max_length=20, choices=StatutLabo.choices, default=StatutLabo.EN_ATTENTE
    )
    statut_ceo = models.CharField(
        max_length=20, choices=StatutCEO.choices, default=StatutCEO.SELECTIONNE
    )

    # Physical reception at company
    recu_physiquement          = models.BooleanField(default=False)
    date_arrivee_echantillon   = models.DateTimeField(null=True, blank=True)
    date_reception_echantillon = models.DateTimeField(null=True, blank=True)

    # CEO negotiation details (set when CEO approves)
    budget_negociation  = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    # Borne haute quand la direction propose un intervalle de prix plutot qu'un
    # prix ferme. Vide = prix unique, porte par budget_negociation seul.
    budget_negociation_max = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    quantite_cible_t    = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    camion_reserve      = models.CharField(max_length=50, blank=True)
    note_interne        = models.TextField(blank=True)
    raison_refus        = models.TextField(blank=True)

    # Nombre de fois que la direction a renvoye la proposition en negociation.
    # Aucun plafond : la decision de refuser reste humaine. Ce compteur est donc
    # le seul signal qu'un dossier s'enlise — d'ou son affichage sur la carte.
    nb_renegociations   = models.PositiveIntegerField(default=0)

    # Purchase confirmation (set by collector when confirming achat)
    prix_final = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    remarque_collecteur = models.TextField(blank=True, default='')

    # Stock delivery tracking
    stock_arrive        = models.BooleanField(default=False)
    date_livraison_stock = models.DateTimeField(null=True, blank=True)
    date_livraison_stock_fin = models.DateTimeField(null=True, blank=True)

    # Quality assessment
    classification = models.CharField(max_length=20, choices=Classification.choices, blank=True)
    remarques      = models.TextField(blank=True)

    # Timestamps
    date_ajout = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @classmethod
    def _next_numero_for_year(cls, year):
        prefix = f"{year}/"
        max_sequence = 0
        for numero in cls.objects.filter(
            numero__startswith=prefix
        ).values_list('numero', flat=True):
            try:
                sequence = int(numero.split('/', 1)[1])
            except (IndexError, ValueError):
                continue
            max_sequence = max(max_sequence, sequence)
        return f"{year}/{max_sequence + 1:04d}"

    def save(self, *args, **kwargs):
        if self.numero:
            return super().save(*args, **kwargs)

        for attempt in range(10):
            self.numero = self._next_numero_for_year(datetime.now().year)
            try:
                # Savepoint: a clash on the number must not break the caller's
                # transaction, or the retry below could not run.
                with transaction.atomic():
                    return super().save(*args, **kwargs)
            except IntegrityError:
                self.numero = ''
                if attempt == 9:
                    raise

    def __str__(self):
        return self.numero
