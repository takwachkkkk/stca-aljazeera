from collections import defaultdict
from datetime import date

from django.db.models import Q

from echantillons.models import Echantillon


def user_full_name(user):
    if not user:
        return 'Inconnu'
    return f'{user.prenom} {user.nom}'.strip()


def rounded_average(values):
    return round(sum(values) / len(values), 1) if values else 0


def evaluation_delays(evaluations):
    """Return (evaluation, fractional days) for evaluations with usable dates."""
    result = []
    for evaluation in evaluations:
        received_at = evaluation.echantillon.date_arrivee_echantillon
        if not received_at or not evaluation.soumis_le:
            continue
        delay = (evaluation.soumis_le - received_at).total_seconds() / 86400
        result.append((evaluation, delay))
    return result


def pipeline_counts():
    """Global, non-nominative operational counts shared by both dashboards."""
    return {
        'receptionne': Echantillon.objects.filter(
            statut_collecteur=Echantillon.StatutCollecteur.RECEPTIONNE,
            recu_physiquement=False,
        ).count(),
        'non_evaluee': Echantillon.objects.filter(
            recu_physiquement=True,
            statut_degustateur=Echantillon.StatutDegustateur.NON_EVALUEE,
        ).count(),
        'en_cours': Echantillon.objects.filter(
            statut_degustateur=Echantillon.StatutDegustateur.EN_COURS,
        ).count(),
        'soumise': Echantillon.objects.filter(
            statut_degustateur=Echantillon.StatutDegustateur.SOUMIS,
        ).count(),
    }


def urgent_evaluations_payload(echantillons, now):
    """Serialize global work-to-do samples without exposing evaluator identities."""
    result = []
    for echantillon in echantillons:
        days = (
            (now - echantillon.date_arrivee_echantillon).days
            if echantillon.date_arrivee_echantillon
            else 0
        )
        result.append({
            'id': str(echantillon.id),
            'numero': echantillon.numero,
            'reference': f'{echantillon.variete} - {echantillon.numero}'.strip(' -'),
            'variete': echantillon.variete,
            'collecteur_nom': user_full_name(echantillon.collecteur),
            'fournisseur_nom': echantillon.fournisseur.nom if echantillon.fournisseur else '',
            'jours_en_attente': days,
            'days_waiting': days,
            'badge': 'red' if days >= 2 else ('amber' if days == 1 else 'normal'),
        })
    return result


def monthly_classification_distribution(evaluations):
    """Aggregate classifications by month; never emits an evaluator identity."""
    monthly = defaultdict(lambda: {
        'extra_vierge': 0,
        'vierge': 0,
        'lampante': 0,
    })
    for evaluation in evaluations:
        # Cle (annee, mois) et non le libelle : trier "Apr 2026" et "Jan 2026"
        # comme du texte met avril avant janvier. Le libelle est reconstruit a
        # la fin, une fois le tri fait sur des nombres.
        cle = (evaluation.soumis_le.year, evaluation.soumis_le.month)
        if evaluation.classification == Echantillon.Classification.EXTRA_VIERGE:
            monthly[cle]['extra_vierge'] += 1
        elif evaluation.classification in (
            Echantillon.Classification.VIERGE,
            Echantillon.Classification.VIERGE_ORDINAIRE,
        ):
            monthly[cle]['vierge'] += 1
        elif evaluation.classification == Echantillon.Classification.LAMPANTE:
            monthly[cle]['lampante'] += 1
    return [
        # annee / mois : l'application affiche le mois en francais.
        {'label': date(annee, mois, 1).strftime('%b %Y'), 'annee': annee, 'mois': mois, **counts}
        for (annee, mois), counts in sorted(monthly.items())
    ]


def presence_summary(sessions, user, today, upcoming_sessions=None):
    """Aggregate only the supplied user's attendance over an already scoped queryset."""
    present = sessions.filter(presences_confirmees=user).count()
    missed = (
        sessions.filter(date__lt=today)
        .exclude(statut='refusee')
        .exclude(presences_confirmees=user)
        .count()
    )
    upcoming_source = upcoming_sessions if upcoming_sessions is not None else sessions
    upcoming = (
        upcoming_source.filter(date__gte=today, statut='planifiee')
        .order_by('date')
        .first()
    )
    return {
        'present': present,
        'manquee': missed,
        'prochaine_titre': upcoming.titre if upcoming else None,
        'prochaine_date': upcoming.date.isoformat() if upcoming else None,
        'prochaine_lieu': upcoming.lieu if upcoming else None,
        'prochaine_countdown': f'{(upcoming.date - today).days}j' if upcoming else None,
    }


def sessions_for_user(user):
    """Scope sessions before attendance aggregation to prevent cross-user leakage."""
    from sessions_degustation.models import SessionDegustation

    return SessionDegustation.objects.filter(
        Q(participants=user) | Q(cree_par=user)
    ).distinct()


def repartition_par_gouvernorat(echantillons, date_debut=None, date_fin=None):
    """Echantillons enregistres et achats confirmes par gouvernorat.

    Sert au chef et a la direction : savoir d'ou viennent les echantillons et
    ou l'entreprise achete le plus. Les noms sont regroupes sans tenir compte
    de la casse ni des espaces ; du gouvernorat le plus actif au moins actif.
    """
    if date_debut:
        echantillons = echantillons.filter(date_ajout__date__gte=date_debut)
    if date_fin:
        echantillons = echantillons.filter(date_ajout__date__lte=date_fin)

    lignes = {}
    for gouvernorat, statut in echantillons.values_list('gouvernorat', 'statut_collecteur'):
        nom = (gouvernorat or '').strip() or 'Non précisé'
        ligne = lignes.setdefault(
            nom.lower(), {'gouvernorat': nom, 'echantillons': 0, 'achats': 0},
        )
        ligne['echantillons'] += 1
        if statut == Echantillon.StatutCollecteur.ACHAT_CONFIRME:
            ligne['achats'] += 1
    return sorted(
        lignes.values(),
        key=lambda ligne: (-ligne['echantillons'], -ligne['achats'], ligne['gouvernorat']),
    )
