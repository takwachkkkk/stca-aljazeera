from datetime import time, timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from fournisseurs.models import Fournisseur
from sessions_degustation.models import SessionDegustation
from users.models import User


class DegustateurDashboardApiTests(APITestCase):
    def setUp(self):
        self.taster_a = User.objects.create_user(
            email='taster.a.dashboard@example.com',
            password='Test@12345',
            nom='Alpha',
            prenom='Alice',
            role=User.Role.DEGUSTATEUR,
        )
        self.taster_b = User.objects.create_user(
            email='taster.b.dashboard@example.com',
            password='Test@12345',
            nom='BetaSecret',
            prenom='BobSecret',
            role=User.Role.DEGUSTATEUR,
        )
        self.chef = User.objects.create_user(
            email='chef.dashboard.isolation@example.com',
            password='Test@12345',
            nom='Chef',
            prenom='Panel',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.collector = User.objects.create_user(
            email='collector.dashboard.isolation@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='Claire',
            role=User.Role.COLLECTEUR,
        )
        self.supplier = Fournisseur.objects.create(
            nom='Domaine Dashboard',
            region='Sfax',
        )
        self.received_at = timezone.now() - timedelta(days=4)
        self.pending_sample = Echantillon.objects.create(
            reference_bouteille='REF-PENDING-GLOBAL',
            fournisseur=self.supplier,
            collecteur=self.collector,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            date_arrivee_echantillon=self.received_at,
            statut_degustateur=Echantillon.StatutDegustateur.NON_EVALUEE,
        )
        self.submitted_sample = Echantillon.objects.create(
            reference_bouteille='REF-SUBMITTED-PANEL',
            fournisseur=self.supplier,
            collecteur=self.collector,
            gouvernorat='Sfax',
            variete='Chetoui',
            recu_physiquement=True,
            date_arrivee_echantillon=self.received_at,
            statut_degustateur=Echantillon.StatutDegustateur.SOUMIS,
        )
        self.evaluation_a = self._submitted_evaluation(
            self.taster_a,
            Echantillon.Classification.EXTRA_VIERGE,
            timedelta(hours=36),
        )
        self.evaluation_b = self._submitted_evaluation(
            self.taster_b,
            Echantillon.Classification.LAMPANTE,
            timedelta(hours=60),
        )
        EvaluationOrganoleptique.objects.create(
            echantillon=self.pending_sample,
            degustateur=self.taster_a,
            statut=EvaluationOrganoleptique.Statut.EN_COURS,
        )
        self._create_sessions()
        self.client.force_authenticate(user=self.taster_a)

    def _submitted_evaluation(self, taster, classification, delay):
        return EvaluationOrganoleptique.objects.create(
            echantillon=self.submitted_sample,
            degustateur=taster,
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
            classification=classification,
            soumis_le=self.received_at + delay,
        )

    def _create_sessions(self):
        today = timezone.now().date()
        present_a = SessionDegustation.objects.create(
            titre='Session passée Alice',
            date=today - timedelta(days=2),
            heure=time(9),
            lieu='Salle A',
            cree_par=self.taster_a,
            statut=SessionDegustation.Statut.TERMINEE,
        )
        present_a.participants.add(self.taster_a)
        present_a.presences_confirmees.add(self.taster_a)
        future_a = SessionDegustation.objects.create(
            titre='Session future Alice',
            date=today + timedelta(days=2),
            heure=time(10),
            lieu='Salle A',
            cree_par=self.taster_a,
            statut=SessionDegustation.Statut.PLANIFIEE,
        )
        future_a.participants.add(self.taster_a)
        private_b = SessionDegustation.objects.create(
            titre='Session privée BobSecret BetaSecret',
            date=today + timedelta(days=1),
            heure=time(11),
            lieu='Salle B secrète',
            cree_par=self.taster_b,
            statut=SessionDegustation.Statut.PLANIFIEE,
        )
        private_b.participants.add(self.taster_b)

    def assert_no_taster_b_identity(self, response):
        payload = str(response.json())
        self.assertNotIn('BobSecret', payload)
        self.assertNotIn('BetaSecret', payload)
        self.assertNotIn(str(self.taster_b.id), payload)

    def test_pipeline_is_global_but_non_nominative(self):
        response = self.client.get('/api/degustateur/dashboard/pipeline/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['non_evaluee'], 1)
        self.assertEqual(response.json()['soumise'], 1)
        self.assert_no_taster_b_identity(response)

    def test_urgencies_are_global_work_without_evaluator_identity(self):
        response = self.client.get('/api/degustateur/dashboard/urgentes/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in response.json()}
        self.assertIn(str(self.pending_sample.id), ids)
        self.assert_no_taster_b_identity(response)

    def test_classifications_are_panel_aggregates_without_member_breakdown(self):
        response = self.client.get('/api/degustateur/dashboard/classifications/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(response.json()[0]['extra_vierge'], 1)
        self.assertEqual(response.json()[0]['lampante'], 1)
        self.assertEqual(
            set(response.json()[0]),
            {'label', 'annee', 'mois', 'extra_vierge', 'vierge', 'lampante'},
        )
        self.assert_no_taster_b_identity(response)

    def test_presence_is_scoped_to_authenticated_taster(self):
        response = self.client.get('/api/degustateur/dashboard/presence/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['present'], 1)
        self.assertEqual(response.json()['manquee'], 0)
        self.assertEqual(response.json()['prochaine_titre'], 'Session future Alice')
        self.assert_no_taster_b_identity(response)

    def test_delay_exposes_only_my_points_and_an_anonymous_panel_average(self):
        response = self.client.get('/api/degustateur/dashboard/delai/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['mon_delai_moyen'], 1.5)
        self.assertEqual(response.json()['panel_moyen'], 2.0)
        self.assertEqual(response.json()['nb_evals'], 1)
        self.assertEqual(len(response.json()['points']), 1)
        self.assert_no_taster_b_identity(response)

    def test_activity_contains_only_authenticated_taster_submissions(self):
        response = self.client.get('/api/degustateur/activite/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['count'], 1)
        self.assertEqual(
            response.json()['results'][0]['id'],
            str(self.evaluation_a.id),
        )
        self.assert_no_taster_b_identity(response)

    def test_dashboard_views_reject_non_tasters(self):
        self.client.force_authenticate(user=self.chef)

        for path in (
            '/api/degustateur/dashboard/pipeline/',
            '/api/degustateur/dashboard/urgentes/',
            '/api/degustateur/dashboard/classifications/',
            '/api/degustateur/dashboard/presence/',
            '/api/degustateur/dashboard/delai/',
            '/api/degustateur/activite/',
        ):
            with self.subTest(path=path):
                response = self.client.get(path)
                self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
