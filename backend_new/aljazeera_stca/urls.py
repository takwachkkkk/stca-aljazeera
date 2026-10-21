from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from django.urls import path, include, re_path
from django.views.static import serve
from decouple import config
from rest_framework_simplejwt.views import TokenRefreshView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from users.views import (
    ForgotPasswordNewPasswordView,
    ForgotPasswordRequestView,
    ForgotPasswordVerifyView,
    LoginView,
    LogoutView,
)

urlpatterns = [
    # ── Django admin ──────────────────────────────────────────────────────────
    path('admin/', admin.site.urls),

    # ── Auth ──────────────────────────────────────────────────────────────────
    path('api/auth/login/', LoginView.as_view(), name='login'),
    path('api/auth/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('api/auth/logout/', LogoutView.as_view(), name='logout'),
    path(
        'api/auth/mot-de-passe-oublie/',
        ForgotPasswordRequestView.as_view(),
        name='forgot-password-request',
    ),
    path(
        'api/auth/mot-de-passe-oublie/verifier/',
        ForgotPasswordVerifyView.as_view(),
        name='forgot-password-verify',
    ),
    path(
        'api/auth/mot-de-passe-oublie/nouveau/',
        ForgotPasswordNewPasswordView.as_view(),
        name='forgot-password-new-password',
    ),

    # ── Domain APIs ───────────────────────────────────────────────────────────
    path('api/users/', include('users.urls')),
    path('api/fournisseurs/', include('fournisseurs.urls')),
    path('api/echantillons/', include('echantillons.urls')),
    path('api/evaluations/', include('evaluations.urls')),
    path('api/analyses/', include('analyses.urls')),
    path('api/sessions/', include('sessions_degustation.urls')),
    path('api/sessions_degustation/', include('sessions_degustation.urls')),
    path('api/planifications/', include('planifications.urls')),
    path('api/notifications/', include('notifications.urls')),
    path('api/messages/', include('messages_chat.urls')),
    path('api/messages_chat/', include('messages_chat.urls')),
    path('api/ceo/', include('ceo.urls')),
    path('api/chef/', include('chef.urls')),
    path('api/degustateur/', include('degustateur.urls')),

    # ── Interactive API docs (Swagger UI) ─────────────────────────────────────
    # Visit http://localhost:8000/api/docs/  to see and test every endpoint
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]

# Serve uploaded bottle photos in development (on-premise only).
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
elif config('SERVE_MEDIA', default=False, cast=bool):
    # Hosted demo (Render) has no separate web server for the photos.
    urlpatterns += [
        re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    ]
