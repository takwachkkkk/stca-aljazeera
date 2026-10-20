from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from echantillons.models import Echantillon
from users.models import User
from users.permissions import IsDegustateurOrChef, IsDirection
from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(generics.ListAPIView):
    """GET /api/notifications/ — list the authenticated user's notifications.
    Optional query param: ?is_read=false to get only unread."""
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Notification.objects.filter(destinataire=self.request.user)
        is_read = self.request.query_params.get('is_read')
        if is_read is not None:
            qs = qs.filter(is_read=is_read.lower() == 'true')
        return qs


class NotificationMarkReadView(generics.UpdateAPIView):
    """PATCH /api/notifications/<uuid>/ — mark one notification as read."""
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(destinataire=self.request.user)

    def partial_update(self, request, *args, **kwargs):
        notification = self.get_object()
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response(NotificationSerializer(notification).data)


class NotificationMarkAllReadView(APIView):
    """POST /api/notifications/read-all/ — mark all user notifications as read."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        updated = Notification.objects.filter(
            destinataire=request.user,
            is_read=False
        ).update(is_read=True)
        return Response({'updated': updated}, status=status.HTTP_200_OK)


class NotificationUnreadCountView(APIView):
    """GET /api/notifications/unread-count/ — returns count of unread notifications."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(destinataire=request.user, is_read=False).count()
        return Response({'count': count})


class UrgentAnalysisRequestView(APIView):
    permission_classes = [IsDegustateurOrChef]

    def post(self, request):
        echantillon_id = request.data.get('echantillon') or request.data.get('echantillon_id')
        if not echantillon_id:
            return Response(
                {'echantillon': ['Champ requis.']},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            echantillon = Echantillon.objects.get(pk=echantillon_id)
        except Echantillon.DoesNotExist:
            return Response(
                {'detail': 'Echantillon introuvable.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not echantillon.recu_physiquement:
            return Response(
                {'detail': 'Seuls les échantillons dont la réception est confirmée peuvent être demandés en urgence.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        lab_users = User.objects.filter(
            role=User.Role.LABORATOIRE,
            is_active=True,
        )
        if not lab_users.exists():
            return Response(
                {'detail': 'Aucun technicien laboratoire actif.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        requester_name = f'{request.user.prenom} {request.user.nom}'.strip()
        sample_label = echantillon.reference_bouteille or echantillon.numero or str(echantillon.id)
        title = 'Analyse laboratoire urgente'
        message = (
            f'{requester_name} demande une analyse urgente pour '
            f"l'echantillon {sample_label}."
        )

        created = []
        for lab_user in lab_users:
            notification, was_created = Notification.objects.get_or_create(
                destinataire=lab_user,
                type=Notification.Type.ANALYSE_URGENTE,
                echantillon=echantillon,
                is_read=False,
                defaults={
                    'titre': title,
                    'message': message,
                    'section': Notification.Section.ANALYSES,
                },
            )
            if was_created:
                created.append(notification)

        return Response(
            {
                'created': len(created),
                'recipients': lab_users.count(),
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class UrgentEvaluationRequestView(APIView):
    permission_classes = [IsDirection]

    def post(self, request):
        echantillon_id = request.data.get('echantillon') or request.data.get('echantillon_id')
        if not echantillon_id:
            return Response(
                {'echantillon': ['Champ requis.']},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            echantillon = Echantillon.objects.get(pk=echantillon_id)
        except Echantillon.DoesNotExist:
            return Response(
                {'detail': 'Echantillon introuvable.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not echantillon.recu_physiquement:
            return Response(
                {'detail': 'Seuls les échantillons dont la réception est confirmée peuvent être demandés en urgence.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        panel_users = User.objects.filter(
            role__in=(User.Role.DEGUSTATEUR, User.Role.CHEF_DEGUSTATION),
            is_active=True,
        )
        if not panel_users.exists():
            return Response(
                {'detail': 'Aucun degustateur actif.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        requester_name = f'{request.user.prenom} {request.user.nom}'.strip()
        sample_label = echantillon.reference_bouteille or echantillon.numero or str(echantillon.id)
        title = f'Évaluation urgente — échantillon {sample_label}'
        message = (
            f'{requester_name} demande une évaluation urgente pour '
            f"l'échantillon {sample_label}."
        )

        created = []
        for panel_user in panel_users:
            notification, was_created = Notification.objects.get_or_create(
                destinataire=panel_user,
                type=Notification.Type.EVALUATION_URGENTE,
                echantillon=echantillon,
                is_read=False,
                defaults={
                    'titre': title,
                    'message': message,
                    'section': Notification.Section.EVALUATIONS,
                },
            )
            if was_created:
                created.append(notification)

        return Response(
            {
                'created': len(created),
                'recipients': panel_users.count(),
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )
