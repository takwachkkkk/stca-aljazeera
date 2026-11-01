from collections import defaultdict
from datetime import date

from django.db.models import Q
from django.db.models.functions import Coalesce
from django.utils import timezone

from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from evaluations.statistiques_panel import resultat_panel


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


def achats_confirmes(echantillons, date_debut=None, date_fin=None):
    """Les achats confirmes de la periode, dates par le jour de l'achat.

    Un echantillon enregistre en octobre et achete en decembre est un achat de
    decembre. `date_ajout` ne sert que de secours pour un achat sans date.
    """
    achats = echantillons.filter(
        statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
    ).annotate(date_achat=Coalesce('date_achat_confirme', 'date_ajout'))
    if date_debut:
        achats = achats.filter(date_achat__date__gte=date_debut)
    if date_fin:
        achats = achats.filter(date_achat__date__lte=date_fin)
    return achats


def montant_achat(echantillon):
    """Ce que coute un achat en DT : prix en DT/kg x quantite en tonnes x 1000.

    Meme calcul que MontantAchat cote application. None si le prix ou la
    quantite manque : additionner des prix au kilo ne donnerait pas un montant.
    """
    if echantillon.prix_final is None or echantillon.quantite_cible_t is None:
        return None
    return echantillon.prix_final * echantillon.quantite_cible_t * 1000


def montant_total(achats):
    return sum(montant_achat(achat) or 0 for achat in achats)


def _categories_des_achats(achats):
    """La categorie de chaque achat : la sienne, sinon le resultat du panel."""
    panels = defaultdict(list)
    evaluations = EvaluationOrganoleptique.objects.filter(
        statut=EvaluationOrganoleptique.Statut.SOUMIS,
        echantillon__in=[achat.id for achat in achats],
    )
    for evaluation in evaluations:
        panels[evaluation.echantillon_id].append(evaluation)

    categories = {}
    for achat in achats:
        resultat = resultat_panel(panels[achat.id]) or {}
        categories[achat.id] = achat.classification or resultat.get('classification')
    return categories


def synthese_achats(achats):
    """Ce qui a ete achete sur la periode : montant, quantites, derniers prix.

    `sans_quantite` compte les achats dont le montant n'est pas calculable : ils
    sont annonces a l'ecran plutot que comptes pour zero sans le dire.
    """
    achats = list(achats.order_by('date_achat'))
    categories = _categories_des_achats(achats)
    lignes = {
        cle: {'cle': cle, 'quantite_t': 0, 'montant': 0, 'nombre': 0}
        for cle in Echantillon.Classification.values
    }
    derniers_prix = {
        Echantillon.Classification.EXTRA_VIERGE: None,
        Echantillon.Classification.VIERGE: None,
    }
    for achat in achats:
        categorie = categories[achat.id]
        ligne = lignes.setdefault(categorie or 'non_classe', {
            'cle': 'non_classe', 'quantite_t': 0, 'montant': 0, 'nombre': 0,
        })
        ligne['nombre'] += 1
        ligne['quantite_t'] += achat.quantite_cible_t or 0
        ligne['montant'] += montant_achat(achat) or 0
        # Tri par date croissante : le dernier vu est le plus recent.
        if categorie in derniers_prix and achat.prix_final is not None:
            derniers_prix[categorie] = {
                'prix': float(achat.prix_final),
                'date': timezone.localtime(achat.date_achat).date().isoformat(),
            }

    return {
        'montant_total': float(sum(ligne['montant'] for ligne in lignes.values())),
        'quantite_totale_t': float(sum(ligne['quantite_t'] for ligne in lignes.values())),
        'nombre': len(achats),
        'sans_quantite': sum(1 for achat in achats if montant_achat(achat) is None),
        'categories': [
            {
                **ligne,
                'quantite_t': float(ligne['quantite_t']),
                'montant': float(ligne['montant']),
            }
            for ligne in lignes.values()
        ],
        'dernier_prix': {str(cle): prix for cle, prix in derniers_prix.items()},
    }


def _repartition(echantillons, cle_et_nom, date_debut=None, date_fin=None):
    """Echantillons enregistres et achats confirmes, regroupes par `cle_et_nom`.

    `cle_et_nom(echantillon)` rend (cle de regroupement, nom affiche). Sert au
    chef et a la direction ; du groupe le plus actif au moins actif.
    Un echantillon compte a sa date d'enregistrement, un achat a sa date d'achat.
    """
    def dans_la_periode(moment):
        jour = timezone.localtime(moment).date().isoformat()
        return (not date_debut or jour >= date_debut) and (not date_fin or jour <= date_fin)

    lignes = {}
    for echantillon in echantillons:
        enregistre = dans_la_periode(echantillon.date_ajout)
        achete = (
            echantillon.statut_collecteur == Echantillon.StatutCollecteur.ACHAT_CONFIRME
            and dans_la_periode(echantillon.date_achat_confirme or echantillon.date_ajout)
        )
        if not enregistre and not achete:
            continue
        cle, nom = cle_et_nom(echantillon)
        ligne = lignes.setdefault(cle, {'nom': nom, 'echantillons': 0, 'achats': 0})
        ligne['echantillons'] += int(enregistre)
        ligne['achats'] += int(achete)
    return sorted(
        lignes.values(),
        key=lambda ligne: (-ligne['echantillons'], -ligne['achats'], ligne['nom']),
    )


def repartition_par_gouvernorat(echantillons, date_debut=None, date_fin=None):
    """D'ou viennent les echantillons : noms regroupes sans casse ni espaces."""
    def cle_et_nom(echantillon):
        nom = (echantillon.gouvernorat or '').strip() or 'Non précisé'
        return nom.lower(), nom

    return _repartition(
        echantillons.only(
            'gouvernorat', 'statut_collecteur', 'date_ajout', 'date_achat_confirme',
        ),
        cle_et_nom, date_debut, date_fin,
    )


def repartition_par_fournisseur(echantillons, date_debut=None, date_fin=None):
    """Combien d'echantillons chaque fournisseur a apportes, et combien achetes.

    Un fournisseur = nom + lieu (tache 43) : deux homonymes de deux regions
    restent deux lignes, avec leur gouvernorat pour les distinguer.
    """
    def cle_et_nom(echantillon):
        fournisseur = echantillon.fournisseur
        if fournisseur is None:
            return None, 'Sans fournisseur'
        lieu = (fournisseur.region or '').strip()
        return fournisseur.id, f'{fournisseur.nom} — {lieu}' if lieu else fournisseur.nom

    return _repartition(
        echantillons.select_related('fournisseur'), cle_et_nom, date_debut, date_fin,
    )
