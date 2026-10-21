from django.urls import path
from .views import (
    ChefEvaluationsView,
    ChefDashboardPipelineView, ChefDashboardUrgentesView,
    ChefDashboardSessionsEnAttenteView, ChefDashboardDelaiView,
    ChefDashboardAlignementView, ChefDashboardClassificationsView,
    ChefDashboardPresenceView, ChefDashboardUrgentesCeoView,
    ChefDashboardActiviteView, ChefDashboardRegionsView, ChefPanelCoiView,
)

urlpatterns = [
    path('evaluations/', ChefEvaluationsView.as_view(), name='chef-evaluations'),
    path('dashboard/pipeline/', ChefDashboardPipelineView.as_view(), name='chef-pipeline'),
    path('dashboard/urgentes/', ChefDashboardUrgentesView.as_view(), name='chef-urgentes'),
    path('dashboard/sessions-en-attente/', ChefDashboardSessionsEnAttenteView.as_view(), name='chef-sessions-attente'),
    path('dashboard/delai/', ChefDashboardDelaiView.as_view(), name='chef-delai'),
    path('dashboard/alignement/', ChefDashboardAlignementView.as_view(), name='chef-alignement'),
    path('dashboard/classifications/', ChefDashboardClassificationsView.as_view(), name='chef-classifications'),
    path('dashboard/presence/', ChefDashboardPresenceView.as_view(), name='chef-presence'),
    path('dashboard/urgentes-ceo/', ChefDashboardUrgentesCeoView.as_view(), name='chef-urgentes-ceo'),
    path('dashboard/activite/', ChefDashboardActiviteView.as_view(), name='chef-activite'),
    path('dashboard/regions/', ChefDashboardRegionsView.as_view(), name='chef-regions'),
    path('panel-coi/', ChefPanelCoiView.as_view(), name='chef-panel-coi'),
]
