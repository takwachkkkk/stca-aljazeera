from django.conf import settings
from rest_framework.permissions import BasePermission
from .models import User


class IsDirection(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.DIRECTION


class IsCollecteur(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.COLLECTEUR


class IsDegustateur(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.DEGUSTATEUR


class IsLaboratoire(BasePermission):
    def has_permission(self, request, view):
        return (
            settings.LABO_ACTIF
            and request.user.is_authenticated
            and request.user.role == User.Role.LABORATOIRE
        )


class IsChefDegustation(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.CHEF_DEGUSTATION


class IsDegustateurOrChef(BasePermission):
    """Taster or Chef de Dégustation — both can evaluate and manage sessions."""
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role in (
            User.Role.DEGUSTATEUR, User.Role.CHEF_DEGUSTATION
        )


class IsServiceAchat(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.SERVICE_ACHAT
