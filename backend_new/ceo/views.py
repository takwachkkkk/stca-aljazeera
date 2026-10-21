from decimal import Decimal

from django.db.models import Count, Sum
from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView

from analyses.models import AnalyseLabo
from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from core.dashboard_calculations import repartition_par_gouvernorat
from users.permissions import IsDirection


def _month_start(base_dt, months_back):
    month = base_dt.month - months_back
    year = base_dt.year
    while month <= 0:
        month += 12
        year -= 1
    return base_dt.replace(
        year=year,
        month=month,
        day=1,
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    )


def _next_month(dt):
    if dt.month == 12:
        return dt.replace(year=dt.year + 1, month=1)
    return dt.replace(month=dt.month + 1)


def _full_name(user):
    if not user:
        return 'Inconnu'
    return f"{user.prenom} {user.nom}".strip()


def _initials(user):
    if not user:
        return '--'
    return f"{(user.prenom or ' ')[0]}{(user.nom or ' ')[0]}".upper()


def _money(value):
    if value is None:
        return 0.0
    if isinstance(value, Decimal):
        return float(value)
    return float(value or 0)


class CeoDashboardView(APIView):
    permission_classes = [IsDirection]

    def get(self, request):
        now = timezone.now()
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')

        samples = Echantillon.objects.select_related('collecteur', 'fournisseur')
        if date_debut:
            samples = samples.filter(date_ajout__date__gte=date_debut)
        if date_fin:
            samples = samples.filter(date_ajout__date__lte=date_fin)

        total_samples = samples.count()
        purchases = samples.filter(statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME)
        confirmed_count = purchases.count()
        investment = purchases.aggregate(total=Sum('prix_final'))['total'] or Decimal('0')

        kpis = {
            'total': total_samples,
            'receptionnes': samples.filter(statut_collecteur=Echantillon.StatutCollecteur.RECEPTIONNE).count(),
            'en_negociation': samples.filter(statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION).count(),
            'achat_confirme': confirmed_count,
            'refuses': samples.filter(statut_ceo=Echantillon.StatutCEO.REFUSE).count(),
            'stocks_arrives': purchases.filter(stock_arrive=True).count(),
            'evaluations_en_attente': samples.filter(
                recu_physiquement=True,
            ).exclude(statut_degustateur=Echantillon.StatutDegustateur.SOUMIS).count(),
            'analyses_soumises': AnalyseLabo.objects.filter(
                statut=AnalyseLabo.Statut.SOUMIS,
                echantillon__in=samples,
            ).count(),
            'investissement_total': _money(investment),
        }

        pipeline = {
            'receptionne': kpis['receptionnes'],
            'en_negociation': kpis['en_negociation'],
            'achat_confirme': kpis['achat_confirme'],
            'refuse': kpis['refuses'],
        }

        collector_stats = self._collector_performance(samples)
        supplier_stats = self._supplier_frequency(purchases)
        classification_counts = self._classification_counts(samples)
        urgent_decisions = self._urgent_decisions(samples, now)
        stock = {
            'en_transit': purchases.filter(stock_arrive=False).count(),
            'recu': purchases.filter(stock_arrive=True).count(),
        }
        evolution_achats = self._purchase_evolution(samples, now)

        return Response({
            # Legacy/top-level Flutter-friendly keys kept for easy wiring.
            'echantillons_total': total_samples,
            'echantillons_selectionnes': samples.filter(
                statut_ceo=Echantillon.StatutCEO.SELECTIONNE
            ).count(),
            'achats_confirmes': confirmed_count,
            'stocks_arrives': kpis['stocks_arrives'],
            'evaluations_en_attente': kpis['evaluations_en_attente'],
            'analyses_soumises': kpis['analyses_soumises'],

            # Structured dashboard payload.
            'kpis': kpis,
            'pipeline': pipeline,
            'performance_collecteurs': collector_stats,
            'collecteurs': collector_stats,
            'fournisseurs': supplier_stats,
            'classifications': classification_counts,
            'decisions_urgentes': urgent_decisions,
            'stock': stock,
            'evolution_achats': evolution_achats,
        })

    def _collector_performance(self, samples):
        stats = []
        collecteurs = {
            sample.collecteur_id: sample.collecteur
            for sample in samples
            if sample.collecteur_id
        }
        for collecteur_id, collecteur in collecteurs.items():
            qs = samples.filter(collecteur_id=collecteur_id)
            total = qs.count()
            confirmed = qs.filter(
                statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME
            )
            total_value = confirmed.aggregate(total=Sum('prix_final'))['total'] or Decimal('0')
            closed_delays = []
            for sample in confirmed:
                if sample.date_ajout and sample.updated_at:
                    closed_delays.append((sample.updated_at - sample.date_ajout).days)
            avg_days = round(sum(closed_delays) / len(closed_delays), 1) if closed_delays else 0
            approval_rate = round(confirmed.count() / total, 2) if total else 0
            item = {
                'collecteur_id': str(collecteur_id),
                'nom': _full_name(collecteur),
                'name': _full_name(collecteur),
                'initials': _initials(collecteur),
                'samples': total,
                'nb': total,
                'approval_rate': approval_rate,
                'total_value': _money(total_value),
                'avg_days_to_close': avg_days,
            }
            stats.append(item)
        return sorted(stats, key=lambda item: item['total_value'], reverse=True)[:10]

    def _supplier_frequency(self, purchases):
        stats = []
        fournisseurs = {
            sample.fournisseur_id: sample.fournisseur
            for sample in purchases
            if sample.fournisseur_id
        }
        for fournisseur_id, fournisseur in fournisseurs.items():
            qs = purchases.filter(fournisseur_id=fournisseur_id)
            value = qs.aggregate(total=Sum('prix_final'))['total'] or Decimal('0')
            stats.append({
                'fournisseur_id': str(fournisseur_id),
                'name': fournisseur.nom,
                'nom': fournisseur.nom,
                'region': fournisseur.region,
                'achats': qs.count(),
                'valeur': _money(value),
            })
        return sorted(stats, key=lambda item: item['achats'], reverse=True)[:10]

    def _classification_counts(self, samples):
        counts = {
            'extra_vierge': 0,
            'vierge': 0,
            'vierge_ordinaire': 0,
            'lampante': 0,
        }
        direct_counts = (
            samples
            .exclude(classification='')
            .values('classification')
            .annotate(count=Count('id'))
        )
        for row in direct_counts:
            if row['classification'] in counts:
                counts[row['classification']] += row['count']

        if not any(counts.values()):
            evaluation_counts = (
                EvaluationOrganoleptique.objects
                .filter(
                    statut=EvaluationOrganoleptique.Statut.SOUMIS,
                    echantillon__in=samples,
                )
                .exclude(classification='')
                .values('classification')
                .annotate(count=Count('id'))
            )
            for row in evaluation_counts:
                if row['classification'] in counts:
                    counts[row['classification']] += row['count']
        return counts

    def _urgent_decisions(self, samples, now):
        qs = (
            samples
            .filter(
                statut_degustateur=Echantillon.StatutDegustateur.SOUMIS,
                statut_ceo=Echantillon.StatutCEO.SELECTIONNE,
            )
            .select_related('collecteur', 'fournisseur')
            .order_by('updated_at')[:10]
        )
        result = []
        for sample in qs:
            waiting_since = sample.updated_at or sample.date_arrivee_echantillon or sample.date_ajout
            days = (now - waiting_since).days if waiting_since else 0
            result.append({
                'id': str(sample.id),
                'ref': sample.numero,
                'numero': sample.numero,
                'reference_bouteille': sample.reference_bouteille,
                'collecteur': _full_name(sample.collecteur),
                'collecteur_nom': _full_name(sample.collecteur),
                'fournisseur': sample.fournisseur.nom if sample.fournisseur else '',
                'fournisseur_nom': sample.fournisseur.nom if sample.fournisseur else '',
                'jours_en_attente': days,
            })
        return result

    def _purchase_evolution(self, samples, now):
        evolution = []
        purchases = samples.filter(statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME)
        for i in range(5, -1, -1):
            month_start = _month_start(now, i)
            month_end = _next_month(month_start)
            month_qs = purchases.filter(date_ajout__gte=month_start, date_ajout__lt=month_end)
            value = month_qs.aggregate(total=Sum('prix_final'))['total'] or Decimal('0')
            evolution.append({
                'label': month_start.strftime('%b %Y'),
                'count': month_qs.count(),
                'valeur': _money(value),
            })
        return evolution


class CeoDashboardRegionsView(APIView):
    """Echantillons et achats confirmes par gouvernorat : ou l'entreprise achete."""
    permission_classes = [IsDirection]

    def get(self, request):
        return Response(repartition_par_gouvernorat(
            Echantillon.objects.all(),
            date_debut=request.query_params.get('date_debut'),
            date_fin=request.query_params.get('date_fin'),
        ))
