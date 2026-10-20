from django.db.models.signals import post_save, pre_delete, pre_save
from django.dispatch import receiver
from django.utils import timezone

from users.models import User

from .models import Notification


COLLECTOR_DETAIL_FIELDS = (
    'fournisseur_id',
    'gouvernorat',
    'delegation',
    'cite',
    'reference_bouteille',
    'num_citerne',
    'quantite_estimee',
    'variete',
    'date_arrivee_echantillon',
    'remarques',
    'image_url',
)

LEGACY_STATUS_FIELDS = (
    'statut_labo',
    'statut_ceo',
)

STOCK_DELIVERY_FIELDS = (
    'date_livraison_stock',
    'date_livraison_stock_fin',
)


def _get_users_by_roles(*roles):
    return User.objects.filter(role__in=roles, is_active=True, date_suppression__isnull=True)


def _notify(recipients, type_, titre, message, echantillon=None, section='ECHANTILLONS'):
    notifications = [
        Notification(
            destinataire=user,
            type=type_,
            titre=titre,
            message=message,
            echantillon=echantillon,
            section=section,
        )
        for user in recipients
    ]
    if notifications:
        Notification.objects.bulk_create(notifications)


def _sample_ref(echantillon):
    if not echantillon:
        return '-'
    return echantillon.reference_bouteille or echantillon.numero or str(echantillon.id)[:8]


def _snapshot(instance, fields):
    return {field: getattr(instance, field) for field in fields}


def _changed(instance, old_values, fields):
    return any(old_values.get(field) != getattr(instance, field) for field in fields)


def _format_date(value):
    if not value:
        return None
    return timezone.localtime(value).strftime('%d/%m/%Y')


def _delivery_label(echantillon):
    start = _format_date(echantillon.date_livraison_stock)
    end = _format_date(echantillon.date_livraison_stock_fin)
    if start and end:
        return f'entre le {start} et le {end}'
    if start:
        return f'pour le {start}'
    return 'sans date definie'


@receiver(pre_save, sender='echantillons.Echantillon')
def echantillon_pre_save(sender, instance, **kwargs):
    if instance.pk:
        try:
            old = sender.objects.get(pk=instance.pk)
            instance._old_recu_physiquement = old.recu_physiquement
            instance._old_statut_collecteur = old.statut_collecteur
            instance._old_collector_details = _snapshot(old, COLLECTOR_DETAIL_FIELDS)
            instance._old_legacy_statuses = _snapshot(old, LEGACY_STATUS_FIELDS)
            instance._old_stock_delivery = _snapshot(old, STOCK_DELIVERY_FIELDS)
        except sender.DoesNotExist:
            instance._old_recu_physiquement = False
            instance._old_statut_collecteur = None
            instance._old_collector_details = {}
            instance._old_legacy_statuses = {}
            instance._old_stock_delivery = {}
    else:
        instance._old_recu_physiquement = False
        instance._old_statut_collecteur = None
        instance._old_collector_details = {}
        instance._old_legacy_statuses = {}
        instance._old_stock_delivery = {}


@receiver(post_save, sender='echantillons.Echantillon')
def on_echantillon_saved(sender, instance, created, **kwargs):
    ref = _sample_ref(instance)

    if created:
        recipients = _get_users_by_roles(
            User.Role.DIRECTION,
            User.Role.CHEF_DEGUSTATION,
            User.Role.DEGUSTATEUR,
        )
        _notify(
            recipients,
            Notification.Type.NOUVEL_ECHANTILLON,
            'Nouvel echantillon',
            f"L'echantillon {ref} a ete enregistre.",
            echantillon=instance,
            section=Notification.Section.ECHANTILLONS,
        )
        return

    old_recu = getattr(instance, '_old_recu_physiquement', None)
    old_statut = getattr(instance, '_old_statut_collecteur', None)

    if old_recu is False and instance.recu_physiquement:
        now = timezone.now()
        recipients = list(_get_users_by_roles(User.Role.DIRECTION, User.Role.CHEF_DEGUSTATION))
        if instance.collecteur:
            recipients.append(instance.collecteur)
        _notify(
            recipients,
            Notification.Type.ECHANTILLON_RECU,
            "Confirmation réception d'échantillon",
            (
                f"La réception de l'échantillon {ref} a été confirmée "
                f"le {now.strftime('%d/%m/%Y a %H:%M')}."
            ),
            echantillon=instance,
            section=Notification.Section.ECHANTILLONS,
        )
        lab_recipients = _get_users_by_roles(User.Role.LABORATOIRE)
        _notify(
            lab_recipients,
            Notification.Type.NOUVEL_ECHANTILLON,
            'Echantillon disponible pour analyse',
            f"L'echantillon {ref} est disponible pour analyse laboratoire.",
            echantillon=instance,
            section=Notification.Section.ANALYSES,
        )
    elif old_recu is True and not instance.recu_physiquement:
        recipients = list(_get_users_by_roles(User.Role.DIRECTION, User.Role.CHEF_DEGUSTATION))
        if instance.collecteur:
            recipients.append(instance.collecteur)
        _notify(
            recipients,
            Notification.Type.RECEPTION_ANNULEE,
            'Reception physique annulee',
            f"La reception physique de l'echantillon {ref} a ete annulee.",
            echantillon=instance,
            section=Notification.Section.ECHANTILLONS,
        )

        from analyses.models import AnalyseLabo

        analyse = getattr(instance, 'analyse', None)
        if analyse and analyse.statut == AnalyseLabo.Statut.EN_COURS:
            lab_recipients = _get_users_by_roles(User.Role.LABORATOIRE)
            _notify(
                lab_recipients,
                Notification.Type.RECEPTION_ANNULEE,
                'Reception physique annulee',
                (
                    f"La reception physique de l'echantillon {ref} a ete annulee. "
                    "L'analyse en cours doit etre suspendue."
                ),
                echantillon=instance,
                section=Notification.Section.ANALYSES,
            )
    elif old_statut != 'achat_confirme' and instance.statut_collecteur == 'achat_confirme':
        recipients = _get_users_by_roles(User.Role.DIRECTION, User.Role.CHEF_DEGUSTATION)
        _notify(
            recipients,
            Notification.Type.ACHAT_CONFIRME,
            'Achat confirme',
            f"L'achat de {ref} a ete confirme.",
            echantillon=instance,
            section=Notification.Section.ACHATS,
        )
    else:
        old_delivery = getattr(instance, '_old_stock_delivery', {})
        delivery_changed = _changed(instance, old_delivery, STOCK_DELIVERY_FIELDS)
        if delivery_changed:
            had_delivery = any(old_delivery.get(field) for field in STOCK_DELIVERY_FIELDS)
            notification_type = (
                Notification.Type.DATE_LIVRAISON_MODIFIEE
                if had_delivery
                else Notification.Type.DATE_LIVRAISON_AJOUTEE
            )
            title = (
                'Date de livraison modifiee'
                if had_delivery
                else 'Date de livraison ajoutee'
            )
            recipients = _get_users_by_roles(
                User.Role.DEGUSTATEUR,
                User.Role.CHEF_DEGUSTATION,
            )
            _notify(
                recipients,
                notification_type,
                title,
                f"La livraison de l'echantillon {ref} est planifiee {_delivery_label(instance)}.",
                echantillon=instance,
                section=Notification.Section.ECHANTILLONS,
            )
            return

        collector_detail_change = _changed(
            instance,
            getattr(instance, '_old_collector_details', {}),
            COLLECTOR_DETAIL_FIELDS,
        )
        if collector_detail_change:
            recipients = _get_users_by_roles(
                User.Role.CHEF_DEGUSTATION,
                User.Role.DEGUSTATEUR,
            )
            _notify(
                recipients,
                Notification.Type.ECHANTILLON_MODIFIE,
                'Echantillon modifie',
                f"L'echantillon {ref} a ete modifie.",
                echantillon=instance,
                section=Notification.Section.ECHANTILLONS,
            )
            return

        legacy_status_change = _changed(
            instance,
            getattr(instance, '_old_legacy_statuses', {}),
            LEGACY_STATUS_FIELDS,
        )
        if legacy_status_change:
            recipients = _get_users_by_roles(User.Role.CHEF_DEGUSTATION)
            _notify(
                recipients,
                Notification.Type.ECHANTILLON_MODIFIE,
                'Echantillon modifie',
                f"L'echantillon {ref} a ete modifie.",
                echantillon=instance,
                section=Notification.Section.ECHANTILLONS,
            )


@receiver(pre_delete, sender='echantillons.Echantillon')
def on_echantillon_deleted(sender, instance, **kwargs):
    ref = _sample_ref(instance)
    recipients = _get_users_by_roles(User.Role.DIRECTION, User.Role.CHEF_DEGUSTATION)
    _notify(
        recipients,
        Notification.Type.ECHANTILLON_SUPPRIME,
        'Echantillon supprime',
        f"L'echantillon {ref} a ete supprime.",
        echantillon=None,
        section=Notification.Section.ECHANTILLONS,
    )


@receiver(post_save, sender='evaluations.EvaluationOrganoleptique')
def on_evaluation_saved(sender, instance, created, **kwargs):
    if instance.statut != 'soumis':
        return

    echantillon = instance.echantillon
    ref = _sample_ref(echantillon)
    submitted_count = sender.objects.filter(
        echantillon=echantillon,
        statut='soumis',
    ).values('degustateur').distinct().count()
    active_taster_count = User.objects.filter(
        is_active=True,
        role__in=[User.Role.DEGUSTATEUR, User.Role.CHEF_DEGUSTATION],
    ).count()

    if active_taster_count and submitted_count >= active_taster_count:
        recipients = _get_users_by_roles(User.Role.DIRECTION, User.Role.CHEF_DEGUSTATION)
        _notify(
            recipients,
            Notification.Type.TOUTES_EVALUATIONS,
            'Toutes les evaluations soumises',
            f"Toutes les evaluations de {ref} sont soumises.",
            echantillon=echantillon,
            section=Notification.Section.EVALUATIONS,
        )
    else:
        recipients = _get_users_by_roles(User.Role.CHEF_DEGUSTATION).exclude(id=instance.degustateur_id)
        degustateur_name = f'{instance.degustateur.prenom} {instance.degustateur.nom}'.strip()
        _notify(
            recipients,
            Notification.Type.EVALUATION_SOUMISE,
            'Evaluation soumise',
            f"{degustateur_name} a soumis une evaluation de {ref}.",
            echantillon=echantillon,
            section=Notification.Section.EVALUATIONS,
        )


@receiver(post_save, sender='analyses.AnalyseLabo')
def on_analyse_saved(sender, instance, created, **kwargs):
    if instance.statut != 'soumis':
        return

    echantillon = instance.echantillon
    ref = _sample_ref(echantillon)
    recipients = _get_users_by_roles(User.Role.DIRECTION, User.Role.CHEF_DEGUSTATION)
    _notify(
        recipients,
        Notification.Type.ANALYSE_SOUMISE,
        'Analyse soumise',
        f"L'analyse de {ref} a ete soumise.",
        echantillon=echantillon,
        section=Notification.Section.ANALYSES,
    )


@receiver(post_save, sender='sessions_degustation.SessionDegustation')
def on_session_saved(sender, instance, created, **kwargs):
    if not created:
        return

    creator = instance.cree_par
    if creator and creator.role == User.Role.DEGUSTATEUR:
        recipients = _get_users_by_roles(User.Role.CHEF_DEGUSTATION)
    else:
        recipients = instance.participants.filter(is_active=True)

    _notify(
        recipients,
        Notification.Type.NOUVELLE_SESSION,
        'Nouvelle session',
        f"La session {instance.titre} a été créée.",
        echantillon=None,
        section=Notification.Section.SESSIONS,
    )
