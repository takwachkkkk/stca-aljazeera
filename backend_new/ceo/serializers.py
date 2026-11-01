from rest_framework import serializers

from .models import DecisionDirection


class DecisionDirectionSerializer(serializers.ModelSerializer):
    direction_nom = serializers.SerializerMethodField()

    class Meta:
        model = DecisionDirection
        fields = [
            'id', 'type', 'direction', 'direction_nom',
            'budget_negociation', 'quantite_cible_t',
            'note_interne', 'raison_refus', 'date_decision',
        ]

    def get_direction_nom(self, obj):
        if obj.direction:
            return f"{obj.direction.prenom} {obj.direction.nom}"
        return None
