import logging
import secrets
from datetime import timedelta

from django.core import signing
from django.core.cache import cache
from django.core.mail import send_mail
from django.db.models import F
from django.conf import settings
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from .models import CodeReinitialisation, User
from .permissions import IsChefDegustation, IsDirection
from .serializers import (
    ChangePasswordSerializer,
    CollecteurSuggestionSerializer,
    ForgotPasswordNewPasswordSerializer,
    ForgotPasswordRequestSerializer,
    ForgotPasswordVerifySerializer,
    LoginSerializer,
    PanelMemberSerializer,
    UserAdminUpdateSerializer,
    UserCreateSerializer,
    UserProfileUpdateSerializer,
    UserSerializer,
)


logger = logging.getLogger(__name__)
FORGOT_PASSWORD_RESPONSE = 'Si un compte existe, un code a été envoyé.'
FORGOT_PASSWORD_SALT = 'users.mot_de_passe_oublie'


# POST /api/auth/login/
# Returns access + refresh JWT tokens plus the current user profile.
class LoginView(TokenObtainPairView):
    serializer_class = LoginSerializer
    permission_classes = [AllowAny]


class ForgotPasswordRequestView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = ForgotPasswordRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = User.objects.normalize_email(serializer.validated_data['email'])
        cache_key = f'forgot_password_requests:{email.lower()}'
        demandes = cache.get(cache_key, 0)
        if demandes >= 3:
            return Response({'detail': FORGOT_PASSWORD_RESPONSE}, status=status.HTTP_200_OK)
        cache.set(cache_key, demandes + 1, timeout=3600)

        user = User.objects.filter(email__iexact=email, is_active=True).first()
        if user is not None:
            CodeReinitialisation.objects.filter(
                utilisateur=user,
                utilise=False,
            ).update(utilise=True)
            code = f'{secrets.randbelow(1000000):06d}'
            reset_code = CodeReinitialisation(
                utilisateur=user,
                expire_le=timezone.now() + timedelta(minutes=15),
            )
            reset_code.set_code(code)
            reset_code.save()
            # Same answer whether or not the mail leaves: a crash here would
            # reveal which emails have an account.
            try:
                send_mail(
                    'Votre code Al Jazeera STCA',
                    (
                        f'Votre code de réinitialisation est : {code}\n\n'
                        'Il est valable 15 minutes.\n'
                        "Si vous n'avez rien demandé, ignorez ce message."
                    ),
                    settings.DEFAULT_FROM_EMAIL,
                    [user.email],
                    fail_silently=False,
                )
            except Exception:
                logger.exception('Envoi du code de réinitialisation impossible')

        return Response({'detail': FORGOT_PASSWORD_RESPONSE}, status=status.HTTP_200_OK)


class ForgotPasswordVerifyView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = ForgotPasswordVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = User.objects.normalize_email(serializer.validated_data['email'])
        code = serializer.validated_data['code']
        reset_code = CodeReinitialisation.objects.filter(
            utilisateur__email__iexact=email,
            utilisateur__is_active=True,
            utilise=False,
        ).select_related('utilisateur').order_by('-cree_le').first()

        if reset_code is None or reset_code.est_expire_ou_epuise:
            return Response(
                {'detail': 'Code expiré ou épuisé. Demandez un nouveau code.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not reset_code.check_code(code):
            # Atomic increment: parallel guesses cannot share one attempt.
            CodeReinitialisation.objects.filter(pk=reset_code.pk).update(
                nombre_essais=F('nombre_essais') + 1
            )
            reset_code.refresh_from_db(fields=['nombre_essais'])
            if reset_code.est_expire_ou_epuise:
                return Response(
                    {'detail': 'Code expiré ou épuisé. Demandez un nouveau code.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            essais_restants = 4 - reset_code.nombre_essais
            return Response(
                {'detail': f'Code incorrect. Il vous reste {essais_restants} essai(s).'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        jeton = signing.dumps(
            {'code_id': str(reset_code.id), 'user_id': str(reset_code.utilisateur_id)},
            salt=FORGOT_PASSWORD_SALT,
        )
        return Response({'jeton': jeton}, status=status.HTTP_200_OK)


class ForgotPasswordNewPasswordView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = ForgotPasswordNewPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            payload = signing.loads(
                serializer.validated_data['jeton'],
                salt=FORGOT_PASSWORD_SALT,
                max_age=600,
            )
        except signing.BadSignature:
            return Response(
                {'detail': 'Jeton expiré ou invalide.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reset_code = CodeReinitialisation.objects.filter(
            pk=payload.get('code_id'),
            utilisateur_id=payload.get('user_id'),
            utilisateur__is_active=True,
        ).select_related('utilisateur').first()
        if reset_code is None or reset_code.est_expire_ou_epuise:
            return Response(
                {'detail': 'Code expiré ou épuisé. Demandez un nouveau code.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = reset_code.utilisateur
        user.set_password(serializer.validated_data['nouveau_mot_de_passe'])
        user.doit_changer_mot_de_passe = False
        user.save(update_fields=['password', 'doit_changer_mot_de_passe'])
        reset_code.utilise = True
        reset_code.save(update_fields=['utilise'])
        _blacklister_refresh_tokens(user)
        return Response(
            {'detail': 'Mot de passe modifié avec succès.'},
            status=status.HTTP_200_OK,
        )


def _blacklister_refresh_tokens(user):
    try:
        from rest_framework_simplejwt.token_blacklist.models import (
            BlacklistedToken,
            OutstandingToken,
        )
    except ImportError:
        return

    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


# POST /api/auth/logout/
# Blacklists the refresh token so it can no longer generate new access tokens.
class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response({'detail': 'Token de rafraîchissement requis.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response({'detail': 'Token invalide ou déjà révoqué.'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(status=status.HTTP_204_NO_CONTENT)


# GET   /api/users/me/
# PATCH /api/users/me/
# Returns or updates the profile of the currently logged-in user.
# Flutter calls this right after login to get the role and navigate accordingly.
class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        serializer = UserProfileUpdateSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSerializer(request.user).data, status=status.HTTP_200_OK)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ancien = request.data.get('ancien_mot_de_passe')
        nouveau = request.data.get('nouveau_mot_de_passe')
        # Pas de `ancien is not None` ici : une requete sans ancien mot de passe
        # doit etre refusee, pas laissee passer. Le serializer l'exige aussi,
        # mais la verification ne doit dependre que d'elle-meme.
        if not request.user.check_password(ancien or ''):
            return Response(
                {
                    'code': 'password_incorrect',
                    'detail': 'Mot de passe actuel incorrect.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        if nouveau == ancien:
            return Response(
                {
                    'detail': "Le nouveau mot de passe doit être différent de l'ancien."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.set_password(
            serializer.validated_data['nouveau_mot_de_passe']
        )
        request.user.doit_changer_mot_de_passe = False
        request.user.save(update_fields=['password', 'doit_changer_mot_de_passe'])
        return Response(
            {'detail': 'Mot de passe changé avec succès.'},
            status=status.HTTP_200_OK,
        )


class PanelMemberListView(generics.ListAPIView):
    serializer_class = PanelMemberSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return User.objects.filter(
            role__in=[User.Role.DEGUSTATEUR, User.Role.CHEF_DEGUSTATION],
            is_active=True,
        ).order_by('nom', 'prenom', 'date_creation')


class CollecteurSuggestionListView(generics.ListAPIView):
    serializer_class = CollecteurSuggestionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return User.objects.filter(
            role=User.Role.COLLECTEUR,
            is_active=True,
            date_suppression__isnull=True,
        ).order_by('nom', 'prenom', 'date_creation')


# GET /api/users/
# Returns the full list of users — used by the CEO on the Utilisateurs page.
class UserListCreateView(generics.ListCreateAPIView):
    queryset = User.objects.all().order_by('date_creation', 'nom', 'prenom')

    def get_queryset(self):
        queryset = super().get_queryset()
        if not settings.LABO_ACTIF:
            queryset = queryset.exclude(role=User.Role.LABORATOIRE)
        return queryset

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsChefDegustation()]
        return [(IsDirection | IsChefDegustation)()]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserCreateSerializer
        return UserSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        data = UserSerializer(user).data
        data['mot_de_passe_temporaire'] = user.mot_de_passe_temporaire
        data['email_utilisateur_envoye'] = user.email_utilisateur_envoye
        data['email_createur_envoye'] = user.email_createur_envoye
        return Response(data, status=status.HTTP_201_CREATED)


# POST /api/users/create/
# Creates a new user account. Uses UserCreateSerializer so the password
# is hashed via set_password() before being stored.
class UserCreateView(generics.CreateAPIView):
    serializer_class = UserCreateSerializer
    permission_classes = [IsChefDegustation]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        data = UserSerializer(user).data
        data['mot_de_passe_temporaire'] = user.mot_de_passe_temporaire
        data['email_utilisateur_envoye'] = user.email_utilisateur_envoye
        data['email_createur_envoye'] = user.email_createur_envoye
        return Response(data, status=status.HTTP_201_CREATED)


# GET  /api/users/<uuid>/  — fetch a single user's details
# PUT  /api/users/<uuid>/  — update name, phone, email, role
# DELETE /api/users/<uuid>/ — permanently remove a user account
class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()

    def get_permissions(self):
        if self.request.method in ('PUT', 'PATCH', 'DELETE'):
            return [IsChefDegustation()]
        return [(IsDirection | IsChefDegustation)()]

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return UserAdminUpdateSerializer
        return UserSerializer

    def perform_update(self, serializer):
        instance = serializer.instance
        if instance.pk == self.request.user.pk:
            if serializer.validated_data.get('is_active') is False:
                raise ValidationError({'detail': 'Vous ne pouvez pas desactiver votre propre compte.'})
            if serializer.validated_data.get('role') not in (None, instance.role):
                raise ValidationError({'detail': 'Vous ne pouvez pas modifier votre propre role.'})
        serializer.save()

    def perform_destroy(self, instance):
        if str(instance.id) == str(self.request.user.id):
            raise ValidationError({
                'detail': 'Vous ne pouvez pas désactiver ou supprimer votre propre compte.'
            })
        instance.is_active = False
        instance.date_suppression = timezone.now()
        instance.save(update_fields=['is_active', 'date_suppression'])


# POST /api/users/<uuid>/toggle-active/
# Flips is_active between True and False.
# The CEO uses this to suspend or reactivate an account without deleting it.
class UserToggleActiveView(APIView):
    permission_classes = [IsChefDegustation]

    def post(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"detail": "Utilisateur introuvable."}, status=status.HTTP_404_NOT_FOUND)
        if str(user.id) == str(request.user.id):
            raise ValidationError({
                'detail': 'Vous ne pouvez pas désactiver ou supprimer votre propre compte.'
            })
        if user.date_suppression is not None:
            raise ValidationError({
                'detail': 'Un utilisateur supprimé ne peut pas être réactivé.'
            })
        user.is_active = not user.is_active
        user.save(update_fields=['is_active'])
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)
