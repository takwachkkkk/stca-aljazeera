"""
Service achat : un service de l'entreprise qui suit les achats confirmes.

Il voit les achats confirmes, leurs dates de livraison prevues et le detail de
chaque produit — jamais les evaluations ni les analyses du laboratoire. Pour
cela il a SA propre reponse, limitee aux champs ci-dessous, au lieu de
l'API /api/echantillons/ (qui porte classification, remarques et statuts de
degustation). Lecture seule.
"""

from rest_framework.response import Response
from rest_framework.views import APIView

from echantillons.models import Echantillon
from users.permissions import IsServiceAchat


def _iso(valeur):
    return valeur.isoformat() if valeur else None


def _decimal(valeur):
    return float(valeur) if valeur is not None else None


def achat_pour_service_achat(e):
    collecteur = e.collecteur
    fournisseur = e.fournisseur
    return {
        'id': str(e.id),
        'numero': e.numero,
        'reference_bouteille': e.reference_bouteille,
        'fournisseur_nom': fournisseur.nom if fournisseur else None,
        'fournisseur_lieu': (fournisseur.region or None) if fournisseur else None,
        'gouvernorat': e.gouvernorat,
        'delegation': e.delegation or None,
        'cite': e.cite or None,
        'variete': e.variete or None,
        'num_citerne': e.num_citerne or None,
        'collecteur_nom': (
            f'{collecteur.prenom} {collecteur.nom}'.strip() if collecteur else None
        ),
        'quantite_cible_t': _decimal(e.quantite_cible_t),
        'prix_final': _decimal(e.prix_final),
        'budget_negociation': _decimal(e.budget_negociation),
        'camion_reserve': e.camion_reserve or None,
        'remarque_collecteur': e.remarque_collecteur or None,
        'date_livraison_prevue': _iso(e.date_livraison_stock),
        'date_livraison_prevue_fin': _iso(e.date_livraison_stock_fin),
        'stock_arrive': e.stock_arrive,
        'date_enregistrement': _iso(e.date_ajout),
        'date_mise_a_jour': _iso(e.updated_at),
        'image_url': e.image_url or None,
    }


class AchatsConfirmesView(APIView):
    permission_classes = [IsServiceAchat]

    def get(self, request):
        achats = (
            Echantillon.objects
            .filter(statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME)
            .select_related('fournisseur', 'collecteur')
            .order_by('-updated_at')
        )
        return Response([achat_pour_service_achat(e) for e in achats])
