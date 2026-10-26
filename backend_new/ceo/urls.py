from django.urls import path
from .views import CeoDashboardFournisseursView, CeoDashboardRegionsView, CeoDashboardView

urlpatterns = [
    path('dashboard/', CeoDashboardView.as_view(), name='ceo-dashboard'),
    path('dashboard/regions/', CeoDashboardRegionsView.as_view(), name='ceo-regions'),
    path('dashboard/fournisseurs/', CeoDashboardFournisseursView.as_view(), name='ceo-fournisseurs'),
]
