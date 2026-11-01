from django.urls import path

from .views import AchatsConfirmesView, FacturerAchatView

urlpatterns = [
    path('achats/', AchatsConfirmesView.as_view(), name='service-achat-achats'),
    path(
        'achats/<uuid:pk>/facturer/',
        FacturerAchatView.as_view(),
        name='service-achat-facturer',
    ),
]
