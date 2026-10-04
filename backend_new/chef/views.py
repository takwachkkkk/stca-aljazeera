from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Q
from django.utils import timezone
from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from sessions_degustation.models import SessionDegustation
from users.models import User
from users.permissions import IsChefDegustation
from core.dashboard_calculations import (
    evaluation_delays,
    monthly_classification_distribution,
    pipeline_counts,
    presence_summary,
    rounded_average,
    sessions_for_user,
    urgent_evaluations_payload,
)


EVALUATION_SCORE_FIELDS = [
    ('fruite', 'Fruite'),
    ('amertume', 'Amertume'),
    ('piquant', 'Piquant'),
    ('chome', 'Chome'),
    ('moisi', 'Moisi'),
    ('vinaigre', 'Vinaigre'),
    ('rance', 'Rance'),
    ('gele', 'Gele'),
    ('autres_defaut', 'Autres defauts'),
]


def _decimal_to_float(value):
    return float(value) if value is not None else None


def _user_full_name(user):
    if not user:
        return 'Inconnu'
    return f"{user.prenom} {user.nom}".strip()


def _iso_or_none(value):
    return value.isoformat() if value else None


class ChefEvaluationsView(APIView):
    """Chef-only overview of submitted panel evaluations grouped by sample."""
    permission_classes = [IsChefDegustation]

    def get(self, request):
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')
        search = request.query_params.get('search', '')

        qs = EvaluationOrganoleptique.objects.select_related(
            'echantillon', 'echantillon__fournisseur', 'echantillon__collecteur', 'degustateur'
        ).filter(statut=EvaluationOrganoleptique.Statut.SOUMIS)
        if date_debut:
            qs = qs.filter(echantillon__date_reception_echantillon__date__gte=date_debut)
        if date_fin:
            qs = qs.filter(echantillon__date_reception_echantillon__date__lte=date_fin)
        if search:
            qs = qs.filter(
                Q(echantillon__numero__icontains=search) |
                Q(echantillon__reference_bouteille__icontains=search) |
                Q(echantillon__variete__icontains=search) |
                Q(echantillon__fournisseur__nom__icontains=search)
            )
        qs = qs.order_by('-echantillon__date_reception_echantillon', 'degustateur__nom')

        active_panel_members = list(
            User.objects.filter(
                role__in=[User.Role.DEGUSTATEUR, User.Role.CHEF_DEGUSTATION],
                is_active=True,
            ).order_by('nom', 'prenom')
        )
        grouped = {}
        for ev in qs:
            sample = ev.echantillon
            eid = str(ev.echantillon_id)
            if eid not in grouped:
                grouped[eid] = {
                    'echantillon_id': eid,
                    'sample_id': eid,
                    'echantillon_numero': sample.numero,
                    'numero': sample.numero,
                    'reference_bouteille': sample.reference_bouteille,
                    'gouvernorat': sample.gouvernorat,
                    'delegation': sample.delegation,
                    'variete': sample.variete,
                    'date_ajout': _iso_or_none(sample.date_ajout),
                    'recu_physiquement': sample.recu_physiquement,
                    'date_reception_physique': _iso_or_none(sample.date_reception_echantillon),
                    'date_reception_echantillon': _iso_or_none(sample.date_reception_echantillon),
                    'date_arrivee_echantillon': _iso_or_none(sample.date_arrivee_echantillon),
                    'date_livraison_stock': _iso_or_none(sample.date_livraison_stock),
                    'num_citerne': sample.num_citerne,
                    'collecteur_nom': (
                        f"{sample.collecteur.prenom} {sample.collecteur.nom}".strip()
                        if sample.collecteur else None
                    ),
                    'fournisseur_nom': sample.fournisseur.nom if sample.fournisseur else None,
                    'evaluations': [],
                    '_submitted_by_user': {},
                    'divergence': False,
                    'divergence_details': [],
                }
            scores = [
                {
                    'key': field,
                    'attribut': label,
                    'score': _decimal_to_float(getattr(ev, field)),
                }
                for field, label in EVALUATION_SCORE_FIELDS
                if getattr(ev, field) is not None
            ]
            payload = {
                'id': str(ev.id),
                'degustateur_id': str(ev.degustateur_id) if ev.degustateur_id else None,
                'degustateur': _user_full_name(ev.degustateur),
                'degustateur_nom': _user_full_name(ev.degustateur),
                'taster_name': _user_full_name(ev.degustateur),
                'fruite': _decimal_to_float(ev.fruite),
                'amertume': _decimal_to_float(ev.amertume),
                'piquant': _decimal_to_float(ev.piquant),
                'chome': _decimal_to_float(ev.chome),
                'moisi': _decimal_to_float(ev.moisi),
                'vinaigre': _decimal_to_float(ev.vinaigre),
                'rance': _decimal_to_float(ev.rance),
                'gele': _decimal_to_float(ev.gele),
                'autres_defaut': _decimal_to_float(ev.autres_defaut),
                'scores': scores,
                'classification': ev.classification,
                'statut': ev.statut,
                'date_eval': _iso_or_none(ev.soumis_le),
                'soumis_le': _iso_or_none(ev.soumis_le),
                'commentaire': ev.commentaire,
            }
            grouped[eid]['evaluations'].append(payload)
            if ev.degustateur_id:
                grouped[eid]['_submitted_by_user'][str(ev.degustateur_id)] = payload

        for group in grouped.values():
            submitted = [e for e in group['evaluations'] if e['statut'] == 'soumis']
            group['submitted_count'] = len(submitted)
            group['total_count'] = len(active_panel_members)
            group['is_complete'] = bool(active_panel_members) and len(submitted) >= len(active_panel_members)

            if len(submitted) >= 3:
                for attr, label in EVALUATION_SCORE_FIELDS:
                    vals = [
                        (e, e[attr])
                        for e in submitted
                        if e.get(attr) is not None
                    ]
                    if len(vals) >= 3:
                        avg = sum(score for _, score in vals) / len(vals)
                        divergent = [
                            {
                                'key': attr,
                                'attribut': label,
                                'degustateur_id': e['degustateur_id'],
                                'degustateur': e['degustateur'],
                                'score': score,
                                'panel_average': round(avg, 2),
                                'ecart': round(abs(score - avg), 2),
                            }
                            for e, score in vals
                            if abs(score - avg) > 1.5
                        ]
                        if divergent:
                            group['divergence'] = True
                            group['divergence_details'].extend(divergent)

            submitted_by_user = group.pop('_submitted_by_user')
            for member in active_panel_members:
                if str(member.id) not in submitted_by_user:
                    group['evaluations'].append({
                        'id': None,
                        'degustateur_id': str(member.id),
                        'degustateur': _user_full_name(member),
                        'degustateur_nom': _user_full_name(member),
                        'taster_name': _user_full_name(member),
                        'statut': 'en_attente',
                        'classification': None,
                        'scores': [],
                        'date_eval': None,
                        'soumis_le': None,
                    })

        return Response(list(grouped.values()))


class ChefDashboardPipelineView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        counts = pipeline_counts()
        return Response({
            'receptionne': counts['receptionne'],
            'en_attente_eval': counts['non_evaluee'],
            'en_cours': counts['en_cours'],
            'soumis': counts['soumise'],
        })


class ChefDashboardUrgentesView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        now = timezone.now()
        echantillons = Echantillon.objects.filter(
            recu_physiquement=True,
            statut_degustateur__in=['non_evaluee', 'en_cours']
        ).select_related('collecteur', 'fournisseur').order_by(
            'date_arrivee_echantillon'
        )[:20]
        return Response(urgent_evaluations_payload(echantillons, now))


class ChefDashboardSessionsEnAttenteView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        sessions = SessionDegustation.objects.filter(
            statut='en_attente_validation'
        ).select_related('cree_par').order_by('date')
        return Response([{
            'id': str(s.id),
            'titre': s.titre,
            'date': s.date.isoformat(),
            'heure': s.heure.isoformat() if s.heure else None,
            'lieu': s.lieu,
            'cree_par': f"{s.cree_par.prenom} {s.cree_par.nom}" if s.cree_par else '',
            'propose_par': _user_full_name(s.cree_par),
        } for s in sessions])


class ChefDashboardDelaiView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')

        qs = EvaluationOrganoleptique.objects.filter(
            statut='soumis',
            soumis_le__isnull=False,
        ).select_related('degustateur', 'echantillon').order_by('soumis_le')
        if date_debut:
            qs = qs.filter(soumis_le__date__gte=date_debut)
        if date_fin:
            qs = qs.filter(soumis_le__date__lte=date_fin)
        qs = qs[:1000]

        per_member = {}
        delays = evaluation_delays(qs)
        for ev, delay in delays:
            uid = str(ev.degustateur_id) if ev.degustateur_id else 'inconnu'
            if uid not in per_member:
                per_member[uid] = {
                    'nom': f"{ev.degustateur.prenom} {ev.degustateur.nom}" if ev.degustateur else 'Inconnu',
                    'delays': [],
                }
            per_member[uid]['delays'].append(delay)

        panel_moyen = rounded_average([delay for _, delay in delays])
        membres = [{
            'nom': v['nom'],
            'delai_moyen': rounded_average(v['delays']),
            'panel_moyen': panel_moyen,
        } for v in per_member.values()]

        return Response({'membres': membres, 'panel_moyen': panel_moyen})


class ChefDashboardAlignementView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')

        qs = EvaluationOrganoleptique.objects.filter(
            statut='soumis',
            soumis_le__isnull=False,
        ).select_related('degustateur').order_by('soumis_le')
        if date_debut:
            qs = qs.filter(soumis_le__date__gte=date_debut)
        if date_fin:
            qs = qs.filter(soumis_le__date__lte=date_fin)
        qs = qs[:1000]

        by_sample = {}
        for ev in qs:
            eid = str(ev.echantillon_id)
            if eid not in by_sample:
                by_sample[eid] = []
            by_sample[eid].append(ev)

        member_data = {}
        for evals in by_sample.values():
            if len(evals) < 3:
                continue
            for attr, _ in EVALUATION_SCORE_FIELDS:
                values = [
                    (evaluation, getattr(evaluation, attr))
                    for evaluation in evals
                    if getattr(evaluation, attr) is not None
                ]
                if len(values) < 3:
                    continue
                attr_scores = [float(score) for _, score in values]
                avg = sum(attr_scores) / len(attr_scores)
                for ev, raw_score in values:
                    uid = str(ev.degustateur_id) if ev.degustateur_id else 'inconnu'
                    if uid not in member_data:
                        member_data[uid] = {
                            'nom': f"{ev.degustateur.prenom} {ev.degustateur.nom}" if ev.degustateur else 'Inconnu',
                            'divergent': 0, 'total': 0,
                        }
                    score = float(raw_score)
                    member_data[uid]['divergent'] += 1 if abs(score - avg) > 1.5 else 0
                    member_data[uid]['total'] += 1

        membres = [{
            'nom': v['nom'],
            'divergence_pct': round(100 * v['divergent'] / v['total'], 1) if v['total'] else 0,
        } for v in member_data.values()]

        return Response({'membres': membres})


class ChefDashboardClassificationsView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')

        qs = EvaluationOrganoleptique.objects.filter(
            statut='soumis',
            soumis_le__isnull=False,
        ).order_by('soumis_le')
        if date_debut:
            qs = qs.filter(soumis_le__date__gte=date_debut)
        if date_fin:
            qs = qs.filter(soumis_le__date__lte=date_fin)
        qs = qs[:1000]

        return Response(monthly_classification_distribution(qs))


class ChefDashboardPresenceView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')
        today = timezone.now().date()

        all_sessions = sessions_for_user(request.user)
        qs = all_sessions
        if date_debut:
            qs = qs.filter(date__gte=date_debut)
        if date_fin:
            qs = qs.filter(date__lte=date_fin)

        return Response(
            presence_summary(
                qs,
                request.user,
                today,
                upcoming_sessions=all_sessions,
            )
        )


class ChefDashboardUrgentesCeoView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        echantillons = Echantillon.objects.filter(
            statut_degustateur='soumis',
            statut_ceo='selectionne'
        ).select_related('collecteur', 'fournisseur')[:20]

        return Response([{
            'id': str(e.id),
            'numero': e.numero,
            'reference': f"{e.variete} - {e.numero}".strip(' -'),
            'reference_bouteille': e.reference_bouteille,
            'variete': e.variete,
            'collecteur_nom': f"{e.collecteur.prenom} {e.collecteur.nom}" if e.collecteur else '',
            'fournisseur_nom': e.fournisseur.nom if e.fournisseur else '',
        } for e in echantillons])


class ChefDashboardActiviteView(APIView):
    permission_classes = [IsChefDegustation]

    def get(self, request):
        offset = int(request.query_params.get('offset', 0))
        limit = min(int(request.query_params.get('limit', 5)), 100)
        date_debut = request.query_params.get('date_debut')
        date_fin = request.query_params.get('date_fin')
        cap = offset + limit + 500

        evals = EvaluationOrganoleptique.objects.filter(
            degustateur=request.user,
            statut='soumis',
            soumis_le__isnull=False,
        ).select_related('echantillon')
        if date_debut:
            evals = evals.filter(soumis_le__date__gte=date_debut)
        if date_fin:
            evals = evals.filter(soumis_le__date__lte=date_fin)
        evals = evals[:cap]

        activities = [{
            'id': str(ev.id),
            'type': 'evaluation',
            'date': ev.soumis_le.isoformat(),
            'horodatage': ev.soumis_le.isoformat(),
            'description': f"Evaluation - {ev.echantillon.numero} ({ev.statut})",
            'action': f"Evaluation soumise - {ev.echantillon.numero}",
        } for ev in evals]

        sessions = SessionDegustation.objects.filter(cree_par=request.user)
        if date_debut:
            sessions = sessions.filter(date_creation__date__gte=date_debut)
        if date_fin:
            sessions = sessions.filter(date_creation__date__lte=date_fin)
        sessions = sessions[:cap]
        for s in sessions:
            activities.append({
                'id': str(s.id),
                'type': 'session',
                'date': s.date_creation.isoformat(),
                'horodatage': s.date_creation.isoformat(),
                'description': f"Session creee - {s.titre}",
                'action': f"Session creee - {s.titre}",
            })

        activities.sort(key=lambda x: x['date'], reverse=True)
        total = len(activities)
        page = activities[offset:offset + limit]
        return Response({'count': total, 'results': page})
