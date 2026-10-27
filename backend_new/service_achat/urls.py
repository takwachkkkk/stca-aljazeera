from django.urls import path

from .views import AchatsConfirmesView

urlpatterns = [
    path('achats/', AchatsConfirmesView.as_view(), name='service-achat-achats'),
]
