from datetime import timedelta

from django.test import override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from analyses.models import AnalyseLabo
from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from sessions_degustation.models import SessionDegustation
from users.models import User

from .models import Notification


@override_settings(LABO_ACTIF=True)
class NotificationApiTests(APITestCase):
    def setUp(self):
        self.direction = User.objects.create_user(
            email='direction.notifications@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.chef = User.objects.create_user(
            email='chef.notifications@example.com',
            password='Test@12345',
            nom='Panel',
            prenom='Chef',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.degustateur = User.objects.create_user(
            email='degustateur.notifications@example.com',
            password='Test@12345',
            nom='One',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.other_degustateur = User.objects.create_user(
            email='degustateur.notifications.other@example.com',
            password='Test@12345',
            nom='Two',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.collecteur = User.objects.create_user(
            email='collecteur.notifications@example.com',
            password='Test@12345',
            nom='Collector',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.lab = User.objects.create_user(
            email='lab.notifications@example.com',
            password='Test@12345',
            nom='Lab',
            prenom='Active',
            role=User.Role.LABORATOIRE,
        )
        self.inactive_lab = User.objects.create_user(
            email='lab.inactive.notifications@example.com',
            password='Test@12345',
            nom='Lab',
            prenom='Inactive',
            role=User.Role.LABORATOIRE,
            is_active=False,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='REF-NOTIF-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now(),
        )
        Notification.objects.all().delete()

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def _notification(self, user, is_read=False):
        return Notification.objects.create(
            destinataire=user,
            type=Notification.Type.NOUVEL_ECHANTILLON,
            titre='Nouvel echantillon',
            message='Message',
            echantillon=self.sample,
            section=Notification.Section.ECHANTILLONS,
            is_read=is_read,
        )

    def test_user_lists_only_own_notifications_with_sample_reference(self):
        own = self._notification(self.direction)
        self._notification(self.chef)
        self.authenticate(self.direction)

        response = self.client.get('/api/notifications/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        results = data.get('results', data)
        self.assertEqual([item['id'] for item in results], [str(own.id)])
        self.assertEqual(results[0]['echantillon'], str(self.sample.id))
        self.assertEqual(results[0]['echantillon_reference'], 'REF-NOTIF-001')
        self.assertEqual(results[0]['echantillon_numero'], self.sample.numero)

    def test_unread_filter_and_count_aliases(self):
        self._notification(self.direction, is_read=False)
        self._notification(self.direction, is_read=True)
        self.authenticate(self.direction)

        unread_list = self.client.get('/api/notifications/?is_read=false')
        unread_count = self.client.get('/api/notifications/unread-count/')
        unread_count_alias = self.client.get('/api/notifications/non-lus/')

        self.assertEqual(unread_list.status_code, status.HTTP_200_OK)
        results = unread_list.json().get('results', unread_list.json())
        self.assertEqual(len(results), 1)
        self.assertEqual(unread_count.json(), {'count': 1})
        self.assertEqual(unread_count_alias.json(), {'count': 1})

    def test_mark_one_and_all_read_aliases(self):
        notification = self._notification(self.direction, is_read=False)
        self._notification(self.direction, is_read=False)
        self.authenticate(self.direction)

        mark_one = self.client.patch(f'/api/notifications/{notification.id}/lire/')
        mark_all = self.client.post('/api/notifications/lire-tout/')

        self.assertEqual(mark_one.status_code, status.HTTP_200_OK)
        self.assertTrue(Notification.objects.get(id=notification.id).is_read)
        self.assertEqual(mark_all.status_code, status.HTTP_200_OK)
        self.assertFalse(Notification.objects.filter(destinataire=self.direction, is_read=False).exists())

    def test_notification_detail_is_scoped_to_recipient(self):
        notification = self._notification(self.direction)
        self.authenticate(self.chef)

        response = self.client.patch(f'/api/notifications/{notification.id}/lire/')

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertFalse(Notification.objects.get(id=notification.id).is_read)

    def test_degustateur_can_request_urgent_lab_analysis(self):
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/notifications/analyse-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.json()['created'], 1)
        notification = Notification.objects.get(type=Notification.Type.ANALYSE_URGENTE)
        self.assertEqual(notification.destinataire, self.lab)
        self.assertEqual(notification.echantillon, self.sample)
        self.assertEqual(notification.section, Notification.Section.ANALYSES)
        self.assertIn('Taster One', notification.message)

    def test_urgent_lab_analysis_request_is_idempotent_per_unread_lab_notification(self):
        self.authenticate(self.chef)

        first = self.client.post(
            '/api/notifications/analyse-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )
        second = self.client.post(
            '/api/notifications/analyse-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(second.json()['created'], 0)
        self.assertEqual(
            Notification.objects.filter(type=Notification.Type.ANALYSE_URGENTE).count(),
            1,
        )

    def test_only_panel_roles_can_request_urgent_lab_analysis(self):
        self.authenticate(self.collecteur)

        response = self.client.post(
            '/api/notifications/analyse-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(Notification.objects.filter(type=Notification.Type.ANALYSE_URGENTE).exists())

    def test_urgent_lab_analysis_requires_physical_reception(self):
        not_received = Echantillon.objects.create(
            reference_bouteille='REF-NOTIF-002',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
            recu_physiquement=False,
        )
        Notification.objects.all().delete()
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/notifications/analyse-urgente/',
            {'echantillon': str(not_received.id)},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(Notification.objects.filter(type=Notification.Type.ANALYSE_URGENTE).exists())

    def test_direction_requests_urgent_evaluation_for_active_panel(self):
        inactive_taster = User.objects.create_user(
            email='degustateur.inactive.notifications@example.com',
            password='Test@12345',
            nom='Inactive',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
            is_active=False,
        )
        self.authenticate(self.direction)

        response = self.client.post(
            '/api/notifications/evaluation-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.json(), {'created': 3, 'recipients': 3})
        notifications = Notification.objects.filter(
            type=Notification.Type.EVALUATION_URGENTE,
        )
        self.assertEqual(
            set(notifications.values_list('destinataire_id', flat=True)),
            {self.chef.id, self.degustateur.id, self.other_degustateur.id},
        )
        self.assertFalse(notifications.filter(destinataire=inactive_taster).exists())
        for notification in notifications:
            self.assertEqual(notification.echantillon, self.sample)
            self.assertEqual(notification.section, Notification.Section.EVALUATIONS)
            self.assertEqual(
                notification.titre,
                f'Évaluation urgente — échantillon {self.sample.reference_bouteille}',
            )

    def test_urgent_evaluation_request_is_idempotent_per_unread_recipient(self):
        self.authenticate(self.direction)

        first = self.client.post(
            '/api/notifications/evaluation-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )
        second = self.client.post(
            '/api/notifications/evaluation-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(second.json(), {'created': 0, 'recipients': 3})
        self.assertEqual(
            Notification.objects.filter(
                type=Notification.Type.EVALUATION_URGENTE,
            ).count(),
            3,
        )

    def test_non_direction_cannot_request_urgent_evaluation(self):
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/notifications/evaluation-urgente/',
            {'echantillon': str(self.sample.id)},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(
            Notification.objects.filter(
                type=Notification.Type.EVALUATION_URGENTE,
            ).exists()
        )

    def test_urgent_evaluation_requires_physical_reception(self):
        not_received = Echantillon.objects.create(
            reference_bouteille='REF-NOTIF-EVAL-002',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
            recu_physiquement=False,
        )
        Notification.objects.all().delete()
        self.authenticate(self.direction)

        response = self.client.post(
            '/api/notifications/evaluation-urgente/',
            {'echantillon': str(not_received.id)},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(
            Notification.objects.filter(
                type=Notification.Type.EVALUATION_URGENTE,
            ).exists()
        )


@override_settings(LABO_ACTIF=True)
class NotificationSignalTests(APITestCase):
    def setUp(self):
        self.direction = User.objects.create_user(
            email='direction.signal@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.chef = User.objects.create_user(
            email='chef.signal@example.com',
            password='Test@12345',
            nom='Panel',
            prenom='Chef',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.taster_one = User.objects.create_user(
            email='taster.signal.one@example.com',
            password='Test@12345',
            nom='One',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.taster_two = User.objects.create_user(
            email='taster.signal.two@example.com',
            password='Test@12345',
            nom='Two',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.collecteur = User.objects.create_user(
            email='collector.signal@example.com',
            password='Test@12345',
            nom='Collector',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.lab = User.objects.create_user(
            email='lab.signal@example.com',
            password='Test@12345',
            nom='Lab',
            prenom='Active',
            role=User.Role.LABORATOIRE,
        )
        self.inactive_lab = User.objects.create_user(
            email='lab.signal.inactive@example.com',
            password='Test@12345',
            nom='Lab',
            prenom='Inactive',
            role=User.Role.LABORATOIRE,
            is_active=False,
        )

    def test_sample_creation_notifies_direction_chef_and_tasters(self):
        Echantillon.objects.create(
            reference_bouteille='REF-SIGNAL-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
        )

        recipients = set(
            Notification.objects.filter(
                type=Notification.Type.NOUVEL_ECHANTILLON,
            ).values_list('destinataire__email', flat=True)
        )

        self.assertEqual(
            recipients,
            {
                self.direction.email,
                self.chef.email,
                self.taster_one.email,
                self.taster_two.email,
            },
        )

    def test_physical_reception_notifies_collector_and_active_labs(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-RECU-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=False,
        )
        Notification.objects.all().delete()

        sample.recu_physiquement = True
        sample.date_reception_echantillon = timezone.now()
        sample.save(update_fields=['recu_physiquement', 'date_reception_echantillon', 'updated_at'])

        reception_notifications = Notification.objects.filter(
            type=Notification.Type.ECHANTILLON_RECU,
        )
        self.assertEqual(
            set(reception_notifications.values_list('destinataire__email', flat=True)),
            {self.direction.email, self.chef.email, self.collecteur.email},
        )
        lab_notifications = Notification.objects.filter(
            type=Notification.Type.NOUVEL_ECHANTILLON,
            section=Notification.Section.ANALYSES,
        )
        self.assertEqual(
            set(lab_notifications.values_list('destinataire__email', flat=True)),
            {self.lab.email},
        )
        self.assertFalse(lab_notifications.filter(destinataire=self.inactive_lab).exists())

    def test_reception_cancellation_notifies_collector_and_lab_when_analysis_in_progress(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-ANNUL-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            date_reception_echantillon=timezone.now(),
        )
        AnalyseLabo.objects.create(
            echantillon=sample,
            technicien=self.lab,
            statut=AnalyseLabo.Statut.EN_COURS,
        )
        Notification.objects.all().delete()

        sample.recu_physiquement = False
        sample.date_reception_echantillon = None
        sample.save(update_fields=['recu_physiquement', 'date_reception_echantillon', 'updated_at'])

        notifications = Notification.objects.filter(type=Notification.Type.RECEPTION_ANNULEE)
        self.assertEqual(
            set(notifications.values_list('destinataire__email', flat=True)),
            {self.direction.email, self.chef.email, self.collecteur.email, self.lab.email},
        )
        self.assertEqual(
            notifications.filter(section=Notification.Section.ANALYSES).count(),
            1,
        )
        self.assertFalse(notifications.filter(destinataire=self.inactive_lab).exists())

    def test_reception_cancellation_does_not_notify_lab_without_in_progress_analysis(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-ANNUL-002',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            date_reception_echantillon=timezone.now(),
        )
        AnalyseLabo.objects.create(
            echantillon=sample,
            technicien=self.lab,
            statut=AnalyseLabo.Statut.SOUMIS,
        )
        Notification.objects.all().delete()

        sample.recu_physiquement = False
        sample.date_reception_echantillon = None
        sample.save(update_fields=['recu_physiquement', 'date_reception_echantillon', 'updated_at'])

        notifications = Notification.objects.filter(type=Notification.Type.RECEPTION_ANNULEE)
        self.assertEqual(
            set(notifications.values_list('destinataire__email', flat=True)),
            {self.direction.email, self.chef.email, self.collecteur.email},
        )
        self.assertFalse(
            notifications.filter(section=Notification.Section.ANALYSES).exists(),
        )

    def test_all_evaluations_signal_waits_for_all_active_panel_members(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-EVAL-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now(),
        )
        Notification.objects.all().delete()

        for user in (self.taster_one, self.taster_two):
            EvaluationOrganoleptique.objects.create(
                echantillon=sample,
                degustateur=user,
                statut=EvaluationOrganoleptique.Statut.SOUMIS,
                fruite='3.0',
                soumis_le=timezone.now(),
            )
        self.assertFalse(
            Notification.objects.filter(type=Notification.Type.TOUTES_EVALUATIONS).exists()
        )

        EvaluationOrganoleptique.objects.create(
            echantillon=sample,
            degustateur=self.chef,
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
            fruite='3.0',
            soumis_le=timezone.now(),
        )

        recipients = set(
            Notification.objects.filter(
                type=Notification.Type.TOUTES_EVALUATIONS,
            ).values_list('destinataire__email', flat=True)
        )
        self.assertEqual(recipients, {self.direction.email, self.chef.email})

    def test_submitted_evaluation_notification_includes_taster_name(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-EVAL-NAME-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now(),
        )
        Notification.objects.all().delete()

        EvaluationOrganoleptique.objects.create(
            echantillon=sample,
            degustateur=self.taster_one,
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
            fruite='3.0',
            soumis_le=timezone.now(),
        )

        notification = Notification.objects.get(
            type=Notification.Type.EVALUATION_SOUMISE,
            destinataire=self.chef,
        )
        self.assertIn('Taster One', notification.message)
        self.assertIn(sample.reference_bouteille, notification.message)
        self.assertNotIn(sample.numero, notification.message)

    def test_stock_delivery_date_change_notifies_all_tasters_and_chef(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-DELIVERY-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
        )
        Notification.objects.all().delete()

        sample.date_livraison_stock = timezone.now() + timedelta(days=7)
        sample.save(update_fields=['date_livraison_stock', 'updated_at'])

        notifications = Notification.objects.filter(
            type=Notification.Type.DATE_LIVRAISON_AJOUTEE,
        )
        recipients = set(notifications.values_list('destinataire__email', flat=True))
        self.assertEqual(
            recipients,
            {self.chef.email, self.taster_one.email, self.taster_two.email},
        )
        self.assertFalse(notifications.filter(destinataire=self.direction).exists())
        self.assertEqual(notifications.count(), 3)
        self.assertFalse(
            Notification.objects.filter(type=Notification.Type.ECHANTILLON_MODIFIE).exists()
        )

    def test_collector_detail_change_notifies_panel_but_not_direction(self):
        sample = Echantillon.objects.create(
            reference_bouteille='REF-DETAIL-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            quantite_estimee='20T',
        )
        Notification.objects.all().delete()

        sample.quantite_estimee = '25T'
        sample.remarques = 'Correction terrain'
        sample.save(update_fields=['quantite_estimee', 'remarques', 'updated_at'])

        notifications = Notification.objects.filter(
            type=Notification.Type.ECHANTILLON_MODIFIE,
        )
        recipients = set(notifications.values_list('destinataire__email', flat=True))
        self.assertEqual(
            recipients,
            {
                self.chef.email,
                self.taster_one.email,
                self.taster_two.email,
            },
        )
        self.assertEqual(notifications.count(), 3)
        self.assertFalse(notifications.filter(destinataire=self.direction).exists())
        for notification in notifications:
            self.assertIn('REF-DETAIL-001', notification.message)
            self.assertNotIn(sample.numero, notification.message)

    def test_degustateur_created_session_notifies_chef(self):
        Notification.objects.all().delete()

        SessionDegustation.objects.create(
            titre='Session a valider',
            date='2099-05-20',
            heure='09:00',
            lieu='Salle A',
            cree_par=self.taster_one,
        )

        notification = Notification.objects.get(type=Notification.Type.NOUVELLE_SESSION)
        self.assertEqual(notification.destinataire, self.chef)
        self.assertEqual(notification.section, Notification.Section.SESSIONS)
