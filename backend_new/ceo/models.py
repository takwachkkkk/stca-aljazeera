import uuid

from django.conf import settings
from django.db import models


class DecisionDirection(models.Model):
    """
    Journal des decisions de la direction sur un echantillon. Une ligne par
    decision, jamais modifiee : avec plusieurs comptes direction et des
    reouvertures, un champ unique sur l'echantillon ecraserait l'auteur
    precedent et son offre.
    """

    class Type(models.TextChoices):
        NEGOCIATION = 'negociation', 'Négociation ouverte'
        REOUVERTURE = 'reouverture', 'Négociation rouverte'
        REFUS       = 'refus',       'Refus'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    echantillon = models.ForeignKey(
        'echantillons.Echantillon',
        on_delete=models.CASCADE,
        related_name='decisions_direction',
    )
    direction = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='decisions_direction',
    )
    type = models.CharField(max_length=20, choices=Type.choices)

    # Offre et motif tels qu'ils etaient au moment de la decision.
    budget_negociation = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    quantite_cible_t   = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    note_interne       = models.TextField(blank=True)
    raison_refus       = models.TextField(blank=True)

    date_decision = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date_decision']
