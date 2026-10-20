from django.db import transaction
from django.db.models import Q
from datetime import datetime
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from notifications.models import Notification
from .models import SessionDegustation
from .serializers import SessionDegustationSerializer
from users.models import User
from users.permissions import IsChefDegustation, IsDegustateurOrChef


def _session_datetime(session):
    heure = session.heure or datetime.max.time().replace(microsecond=0)
    return timezone.make_aware(
        datetime.combine(session.date, heure),
        timezone.get_current_timezone(),
    )


def _session_is_past(session):
    return _session_datetime(session) < timezone.localtime()


def _session_date_label(session):
    date_label = session.date.strftime('%d/%m/%Y')
    if session.heure is None:
        return f'le {date_label}'
    return f"le {date_label} à {session.heure.strftime('%H:%M')}"


SESSION_PASSEE_DETAIL = 'Cette session est passée : elle ne peut plus être approuvée ni refusée.'


def _active_panel():
    return User.objects.filter(
        role__in=(User.Role.DEGUSTATEUR, User.Role.CHEF_DEGUSTATION),
        is_active=True,
        date_suppression__isnull=True,
    )


def _membres_concernes(session):
    participants = session.participants.filter(is_active=True, date_suppression__isnull=True)
    if participants.exists():
        return participants
    return _active_panel()


def _notify_session(recipients, titre, message, exclude_user=None):
    if not hasattr(recipients, 'exclude'):
        recipients = list(recipients)
    elif exclude_user is not None:
        recipients = recipients.exclude(pk=exclude_user.pk)
    if exclude_user is not None and not hasattr(recipients, 'exclude'):
        recipients = [user for user in recipients if user.pk != exclude_user.pk]
    notifications = [
        Notification(
            destinataire=user,
            type=Notification.Type.NOUVELLE_SESSION,
            titre=titre,
            message=message,
            section=Notification.Section.SESSIONS,
        )
        for user in recipients
    ]
    if notifications:
        Notification.objects.bulk_create(notifications)


def _notify_chef_validation(session, actor):
    _notify_session(
        _active_panel().filter(role=User.Role.CHEF_DEGUSTATION),
        'Session en attente',
        f"La session {session.titre} attend votre validation.",
        exclude_user=actor,
    )


# Handles two things:
# GET /api/sessions/       → returns list of all sessions
# POST /api/sessions/      → creates a new session
class SessionListCreateView(generics.ListCreateAPIView):
    serializer_class = SessionDegustationSerializer
    permission_classes = [IsAuthenticated, IsDegustateurOrChef]

    # Returns all sessions, newest first
    def get_queryset(self):
        queryset = (
            SessionDegustation.objects
            .select_related('cree_par')
            .prefetch_related('participants', 'presences_confirmees', 'echantillons')
            .order_by('-date_creation')
        )
        user = self.request.user
        if user.role == User.Role.CHEF_DEGUSTATION:
            return queryset.exclude(statut=SessionDegustation.Statut.REFUSEE)
        return queryset.filter(
            Q(cree_par=user)
            | Q(
                statut__in=[
                    SessionDegustation.Statut.PLANIFIEE,
                    SessionDegustation.Statut.EN_COURS,
                    SessionDegustation.Statut.TERMINEE,
                ],
                participants=user,
            )
            | Q(
                statut__in=[
                    SessionDegustation.Statut.PLANIFIEE,
                    SessionDegustation.Statut.EN_COURS,
                    SessionDegustation.Statut.TERMINEE,
                ],
                participants__isnull=True,
            )
        ).distinct()

    # When creating a session, automatically set cree_par to the logged-in user
    # The user doesn't need to send their own ID — Django knows who they are from the JWT token
    def perform_create(self, serializer):
        statut = SessionDegustation.Statut.PLANIFIEE
        if self.request.user.role == User.Role.DEGUSTATEUR:
            statut = SessionDegustation.Statut.EN_ATTENTE_VALIDATION
        session = serializer.save(cree_par=self.request.user, statut=statut)
        if statut == SessionDegustation.Statut.PLANIFIEE:
            _notify_session(
                _membres_concernes(session),
                'Nouvelle session',
                f"Nouvelle session : {session.titre} le {_session_date_label(session)}",
                exclude_user=self.request.user,
            )


# Handles three things for ONE specific session (identified by its UUID in the URL):
# GET /api/sessions/<uuid>/     → returns that session's details
# PUT /api/sessions/<uuid>/     → edits that session
# DELETE /api/sessions/<uuid>/  → deletes that session
class SessionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SessionDegustationSerializer
    permission_classes = [IsAuthenticated, IsDegustateurOrChef]

    def get_queryset(self):
        queryset = (
            SessionDegustation.objects
            .select_related('cree_par')
            .prefetch_related('participants', 'presences_confirmees', 'echantillons')
        )
        user = self.request.user
        if user.role == User.Role.CHEF_DEGUSTATION:
            return queryset.exclude(statut=SessionDegustation.Statut.REFUSEE)
        return queryset.filter(
            Q(cree_par=user)
            | Q(
                statut__in=[
                    SessionDegustation.Statut.PLANIFIEE,
                    SessionDegustation.Statut.EN_COURS,
                    SessionDegustation.Statut.TERMINEE,
                ],
                participants=user,
            )
            | Q(
                statut__in=[
                    SessionDegustation.Statut.PLANIFIEE,
                    SessionDegustation.Statut.EN_COURS,
                    SessionDegustation.Statut.TERMINEE,
                ],
                participants__isnull=True,
            )
        ).distinct()

    def perform_update(self, serializer):
        session = serializer.instance
        if session.cree_par_id != self.request.user.id:
            raise PermissionDenied('Seul le créateur peut modifier cette session.')
        old_date = session.date
        old_heure = session.heure
        old_statut = session.statut
        old_was_approved = old_statut in (
            SessionDegustation.Statut.PLANIFIEE,
            SessionDegustation.Statut.EN_COURS,
            SessionDegustation.Statut.TERMINEE,
        )
        serializer.save()
        session.refresh_from_db()
        date_or_time_changed = old_date != session.date or old_heure != session.heure
        if (
            self.request.user.role == User.Role.DEGUSTATEUR
            and old_was_approved
            and date_or_time_changed
        ):
            session.statut = SessionDegustation.Statut.EN_ATTENTE_VALIDATION
            session.save(update_fields=['statut'])
            _notify_session(
                _membres_concernes(session),
                'Session en attente',
                f"La session {session.titre} n'est plus prévue pour l'instant.",
                exclude_user=self.request.user,
            )
            _notify_chef_validation(session, self.request.user)
            return
        if old_was_approved:
            _notify_session(
                _membres_concernes(session),
                'Session modifiée',
                f"La session {session.titre} a été modifiée.",
                exclude_user=self.request.user,
            )
        else:
            _notify_chef_validation(session, self.request.user)

    def perform_destroy(self, instance):
        if instance.cree_par_id != self.request.user.id:
            raise PermissionDenied('Seul le créateur peut supprimer cette session.')
        was_approved = instance.statut in (
            SessionDegustation.Statut.PLANIFIEE,
            SessionDegustation.Statut.EN_COURS,
            SessionDegustation.Statut.TERMINEE,
        )
        recipients = list(_membres_concernes(instance))
        titre = instance.titre
        instance.delete()
        if was_approved:
            _notify_session(
                recipients,
                'Session annulée',
                f"Session annulée : {titre}",
                exclude_user=self.request.user,
            )
        else:
            _notify_chef_validation(instance, self.request.user)


class SessionApprouverView(APIView):
    permission_classes = [IsAuthenticated, IsChefDegustation]

    def post(self, request, pk):
        with transaction.atomic():
            try:
                session = SessionDegustation.objects.select_for_update().get(pk=pk)
            except SessionDegustation.DoesNotExist:
                return Response({'detail': 'Session introuvable.'}, status=status.HTTP_404_NOT_FOUND)
            if session.statut != SessionDegustation.Statut.EN_ATTENTE_VALIDATION:
                return Response(
                    {'detail': 'Seules les sessions en attente peuvent être approuvées.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if _session_is_past(session):
                return Response(
                    {'detail': SESSION_PASSEE_DETAIL},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            session.statut = SessionDegustation.Statut.PLANIFIEE
            session.save()
            _notify_session(
                _membres_concernes(session).exclude(pk=session.cree_par_id),
                'Nouvelle session',
                f"Nouvelle session : {session.titre} le {_session_date_label(session)}",
                exclude_user=request.user,
            )
            if session.cree_par_id and session.cree_par_id != request.user.id:
                _notify_session(
                    User.objects.filter(pk=session.cree_par_id, is_active=True),
                    'Session approuvée',
                    'Votre session a été approuvée.',
                    exclude_user=request.user,
                )
        return Response(SessionDegustationSerializer(session, context={'request': request}).data)


class SessionRefuserView(APIView):
    permission_classes = [IsAuthenticated, IsChefDegustation]

    def post(self, request, pk):
        with transaction.atomic():
            try:
                session = SessionDegustation.objects.select_for_update().get(pk=pk)
            except SessionDegustation.DoesNotExist:
                return Response({'detail': 'Session introuvable.'}, status=status.HTTP_404_NOT_FOUND)
            if session.statut != SessionDegustation.Statut.EN_ATTENTE_VALIDATION:
                return Response(
                    {'detail': 'Seules les sessions en attente peuvent être refusées.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if _session_is_past(session):
                return Response(
                    {'detail': SESSION_PASSEE_DETAIL},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            session.statut = SessionDegustation.Statut.REFUSEE
            session.save()
            if session.cree_par_id and session.cree_par_id != request.user.id:
                _notify_session(
                    User.objects.filter(pk=session.cree_par_id, is_active=True),
                    'Session refusée',
                    f"Votre session {session.titre} a été refusée.",
                    exclude_user=request.user,
                )
        return Response(SessionDegustationSerializer(session, context={'request': request}).data)


class SessionConfirmerPresenceView(APIView):
    permission_classes = [IsAuthenticated, IsDegustateurOrChef]

    def post(self, request, pk):
        try:
            session = SessionDegustation.objects.prefetch_related(
                'participants',
                'presences_confirmees',
            ).get(pk=pk)
        except SessionDegustation.DoesNotExist:
            return Response({'detail': 'Session introuvable.'}, status=status.HTTP_404_NOT_FOUND)
        if session.statut not in (
            SessionDegustation.Statut.PLANIFIEE,
            SessionDegustation.Statut.EN_COURS,
        ):
            return Response(
                {'detail': "Cette session n'est pas encore approuvée."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if _session_is_past(session):
            return Response(
                {'detail': 'Cette session est déjà passée.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if session.participants.exists() and not session.participants.filter(pk=request.user.pk).exists():
            return Response(
                {'detail': 'Vous ne faites pas partie des participants de cette session.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        session.presences_confirmees.add(request.user)
        return Response(SessionDegustationSerializer(session, context={'request': request}).data)
