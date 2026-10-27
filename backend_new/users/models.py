import uuid
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.contrib.auth.hashers import check_password, make_password
from django.db import models
from django.db.models import Q
from django.utils import timezone


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save()
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        DIRECTION             = 'direction',             'Direction'
        COLLECTEUR            = 'collecteur',            'Collecteur'
        DEGUSTATEUR           = 'degustateur',           'Dégustateur'
        LABORATOIRE           = 'laboratoire',           'Laboratoire'
        CHEF_DEGUSTATION      = 'chef_degustation',      'Chef de Dégustation'
        RESPONSABLE_FINANCIER = 'responsable_financier', 'Responsable Financier'
        SERVICE_ACHAT         = 'service_achat',         'Service achat'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField()
    nom = models.CharField(max_length=100)
    prenom = models.CharField(max_length=100)
    telephone = models.CharField(max_length=20, blank=True)
    role = models.CharField(max_length=25, choices=Role.choices)
    date_creation = models.DateTimeField(default=timezone.now)
    date_suppression = models.DateTimeField(null=True, blank=True)
    doit_changer_mot_de_passe = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['nom', 'prenom', 'role']

    objects = UserManager()

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['email'],
                condition=Q(date_suppression__isnull=True),
                name='users_email_unique_compte_non_supprime',
            ),
        ]


class CodeReinitialisation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    utilisateur = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='codes_reinitialisation',
    )
    empreinte_code = models.CharField(max_length=128)
    cree_le = models.DateTimeField(default=timezone.now)
    expire_le = models.DateTimeField()
    nombre_essais = models.PositiveSmallIntegerField(default=0)
    utilise = models.BooleanField(default=False)

    class Meta:
        ordering = ['-cree_le']
        indexes = [
            models.Index(fields=['utilisateur', 'utilise', 'expire_le']),
        ]

    def set_code(self, code):
        self.empreinte_code = make_password(code)

    def check_code(self, code):
        return check_password(code, self.empreinte_code)

    @property
    def est_expire_ou_epuise(self):
        return self.utilise or self.expire_le <= timezone.now() or self.nombre_essais >= 4
