import re
import unicodedata

from django.conf import settings
from django.core.mail import send_mail
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from .models import User


def _normaliser_mot_de_passe_fragment(value):
    texte = unicodedata.normalize('NFKD', value or '')
    texte = ''.join(c for c in texte if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]+', '', texte.lower())


def generer_mot_de_passe_compte(prenom, nom):
    prenom = _normaliser_mot_de_passe_fragment(prenom) or 'user'
    nom = _normaliser_mot_de_passe_fragment(nom) or 'stca'
    return f'{prenom}@{nom}'


class UserSerializer(serializers.ModelSerializer):
    statut = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'email',
            'nom',
            'prenom',
            'role',
            'telephone',
            'is_active',
            'statut',
            'date_creation',
            'date_suppression',
            'doit_changer_mot_de_passe',
            'last_login',
        ]
        read_only_fields = [
            'id',
            'statut',
            'date_creation',
            'date_suppression',
            'doit_changer_mot_de_passe',
            'last_login',
        ]

    def get_statut(self, obj):
        if obj.date_suppression is not None:
            return 'supprime'
        if obj.is_active:
            return 'actif'
        return 'desactive'


class PanelMemberSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    membre_depuis = serializers.SerializerMethodField()
    est_en_ligne = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'nom',
            'prenom',
            'role',
            'membre_depuis',
            'est_en_ligne',
        ]
        read_only_fields = fields

    def get_membre_depuis(self, obj):
        month_names = [
            'Jan',
            'Fev',
            'Mar',
            'Avr',
            'Mai',
            'Juin',
            'Juil',
            'Aout',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
        ]
        created = obj.date_creation
        return f'{month_names[created.month - 1]} {created.year}'

    def get_role(self, obj):
        request = self.context.get('request')
        if (
            getattr(getattr(request, 'user', None), 'role', None)
            == User.Role.DEGUSTATEUR
            and obj.role == User.Role.CHEF_DEGUSTATION
        ):
            return User.Role.DEGUSTATEUR.label
        return obj.get_role_display()

    def get_est_en_ligne(self, obj):
        return obj.is_active


class CollecteurSuggestionSerializer(serializers.ModelSerializer):
    nom_complet = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'nom', 'prenom', 'nom_complet']
        read_only_fields = fields

    def get_nom_complet(self, obj):
        return f'{obj.prenom} {obj.nom}'.strip()


class UserAdminUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['email', 'nom', 'prenom', 'role', 'telephone', 'is_active']

    def validate_email(self, value):
        value = User.objects.normalize_email(value)
        queryset = User.objects.filter(
            email__iexact=value,
            date_suppression__isnull=True,
        )
        if self.instance is not None:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError('Cet email est deja utilise.')
        return value


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['email', 'nom', 'prenom', 'telephone']

    def validate_email(self, value):
        value = User.objects.normalize_email(value)
        queryset = User.objects.filter(
            email__iexact=value,
            date_suppression__isnull=True,
        )
        if self.instance is not None:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError('Cet email est deja utilise.')
        return value

    def validate(self, attrs):
        protected_fields = {
            'id',
            'role',
            'is_active',
            'is_staff',
            'is_superuser',
            'password',
            'date_creation',
            'last_login',
        }
        requested_protected_fields = protected_fields.intersection(self.initial_data.keys())
        if requested_protected_fields:
            raise serializers.ValidationError({
                field: ['Ce champ ne peut pas etre modifie depuis le profil.']
                for field in sorted(requested_protected_fields)
            })
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    ancien_mot_de_passe = serializers.CharField(write_only=True, trim_whitespace=False)
    nouveau_mot_de_passe = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_nouveau_mot_de_passe(self, value):
        if len(value) < 6 or not re.search(r'[a-zA-ZÀ-ÿ]', value) or not re.search(r'[0-9]', value):
            raise serializers.ValidationError(
                'Le mot de passe doit contenir au moins 6 caractères, dont des lettres et des chiffres.'
            )
        return value


class ForgotPasswordRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ForgotPasswordVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.RegexField(
        regex=r'^\d{6}$',
        error_messages={'invalid': 'Le code doit contenir 6 chiffres.'},
    )


class ForgotPasswordNewPasswordSerializer(serializers.Serializer):
    jeton = serializers.CharField()
    nouveau_mot_de_passe = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_nouveau_mot_de_passe(self, value):
        return ChangePasswordSerializer().validate_nouveau_mot_de_passe(value)

class LoginSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role
        token['nom'] = user.nom
        token['prenom'] = user.prenom
        token['email'] = user.email
        return token

    def validate(self, attrs):
        email = attrs.get(self.username_field, '')
        password = attrs.get('password', '')
        user = User.objects.filter(
            email__iexact=email,
            date_suppression__isnull=True,
        ).first()

        if user is None:
            if User.objects.filter(email__iexact=email).exists():
                raise serializers.ValidationError({
                    'code': 'account_inactive',
                    'detail': 'Ce compte est desactive.',
                })
            raise serializers.ValidationError({
                'code': 'email_not_found',
                'detail': "Aucun compte n'est associe a cet email.",
            })

        if not user.check_password(password):
            raise serializers.ValidationError({
                'code': 'password_incorrect',
                'detail': 'Mot de passe incorrect.',
            })

        if not user.is_active:
            raise serializers.ValidationError({
                'code': 'account_inactive',
                'detail': 'Ce compte est desactive.',
            })

        self.user = user
        refresh = RefreshToken.for_user(user)
        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'user': UserSerializer(user).data,
        }


class UserCreateSerializer(serializers.ModelSerializer):
    mot_de_passe_temporaire = serializers.CharField(read_only=True)
    email_utilisateur_envoye = serializers.BooleanField(read_only=True)
    email_createur_envoye = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'email',
            'nom',
            'prenom',
            'role',
            'telephone',
            'mot_de_passe_temporaire',
            'email_utilisateur_envoye',
            'email_createur_envoye',
        ]
        read_only_fields = ['id']

    def validate_email(self, value):
        value = User.objects.normalize_email(value)
        if User.objects.filter(
            email__iexact=value,
            date_suppression__isnull=True,
        ).exists():
            raise serializers.ValidationError(
                'Un compte actif utilise déjà cet email.'
            )
        return value

    def create(self, validated_data):
        createur = self.context.get('request').user
        password = generer_mot_de_passe_compte(
            validated_data.get('prenom', ''),
            validated_data.get('nom', ''),
        )
        user = User(**validated_data)
        user.set_password(password)
        user.doit_changer_mot_de_passe = True
        user.save()
        user.mot_de_passe_temporaire = password
        user.email_utilisateur_envoye = self._envoyer_email_utilisateur(
            user,
            password,
        )
        user.email_createur_envoye = self._envoyer_email_createur(
            createur,
            user,
            password,
        )
        return user

    def _envoyer_email_utilisateur(self, user, password):
        try:
            send_mail(
                'Vos identifiants Al Jazeera STCA',
                (
                    f'Bonjour {user.prenom},\n\n'
                    'Votre compte Al Jazeera STCA a été créé.\n'
                    f'Email : {user.email}\n'
                    f'Mot de passe temporaire : {password}\n\n'
                    'Vous devrez choisir un nouveau mot de passe à la première connexion.'
                ),
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
                fail_silently=False,
            )
            return True
        except Exception:
            return False

    def _envoyer_email_createur(self, createur, user, password):
        try:
            send_mail(
                'Compte utilisateur créé',
                (
                    f'Nous avons envoyé ses identifiants à {user.email} ; '
                    f'son mot de passe est : {password}'
                ),
                settings.DEFAULT_FROM_EMAIL,
                [createur.email],
                fail_silently=False,
            )
            return True
        except Exception:
            return False
