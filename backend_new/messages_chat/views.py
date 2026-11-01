from django.db.models import Q
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from users.models import User

from .models import Message
from .permissions import roles_contacts_autorises
from .serializers import ContactSerializer, MessageSerializer


class MessageListCreateView(generics.ListCreateAPIView):
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_queryset(self):
        user = self.request.user
        return (
            Message.objects
            .filter(Q(expediteur=user) | Q(destinataire=user))
            .select_related('expediteur', 'destinataire', 'echantillon')
            .order_by('-date_envoi')
        )

    def _store_message_photo(self):
        import os
        import uuid
        f = self.request.FILES.get('image')
        if not f:
            return None
        ext = os.path.splitext(f.name)[1].lower() or '.jpg'
        name = f"messages/{uuid.uuid4().hex}{ext}"
        saved = default_storage.save(name, ContentFile(f.read()))
        return default_storage.url(saved)

    def perform_create(self, serializer):
        extra = {}
        photo_url = self._store_message_photo()
        if photo_url:
            extra['photo_url'] = photo_url
        serializer.save(expediteur=self.request.user, **extra)


class MessageDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_queryset(self):
        user = self.request.user
        if self.request.method == 'DELETE':
            query = Q(expediteur=user)
        else:
            query = Q(expediteur=user) | Q(destinataire=user)
        return (
            Message.objects
            .filter(query)
            .select_related('expediteur', 'destinataire', 'echantillon')
        )

    def perform_update(self, serializer):
        message = serializer.instance
        if message.expediteur != self.request.user:
            raise PermissionDenied('Seul l expediteur peut modifier ce message.')

        forbidden_fields = {'destinataire', 'echantillon', 'expediteur'}
        sent_forbidden_fields = forbidden_fields.intersection(self.request.data.keys())
        if sent_forbidden_fields:
            raise ValidationError({
                field: ['Ce champ ne peut pas etre modifie sur un message existant.']
                for field in sorted(sent_forbidden_fields)
            })

        nouveau_contenu = serializer.validated_data.get('contenu', message.contenu)
        if nouveau_contenu != message.contenu:
            serializer.save(modifie=True, modifie_le=timezone.now())
        else:
            serializer.save()


class MessageMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            message = Message.objects.get(pk=pk, destinataire=request.user)
        except Message.DoesNotExist:
            return Response(
                {'detail': 'Message introuvable.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not message.lu:
            message.lu = True
            message.lu_le = timezone.now()
            message.save(update_fields=['lu', 'lu_le'])

        return Response(MessageSerializer(message, context={'request': request}).data)


class MessageContactsView(generics.ListAPIView):
    serializer_class = ContactSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        roles_autorises = roles_contacts_autorises(self.request.user)
        if not roles_autorises:
            return User.objects.none()
        return User.objects.filter(
            is_active=True,
            role__in=roles_autorises,
        ).exclude(id=self.request.user.id).order_by('nom', 'prenom')


class MessageUnreadCountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        non_lus = Message.objects.filter(destinataire=request.user, lu=False)
        derniers = (
            non_lus
            .select_related('expediteur', 'destinataire', 'echantillon')
            .order_by('-date_envoi')[:5]
        )
        return Response({
            'total': non_lus.count(),
            'derniers': MessageSerializer(
                derniers,
                many=True,
                context={'request': request},
            ).data,
        })
