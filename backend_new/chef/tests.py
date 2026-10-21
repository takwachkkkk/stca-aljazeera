from datetime import time, timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from fournisseurs.models import Fournisseur
from sessions_degustation.models import SessionDegustation
from users.models import User


class ChefEvaluationOverviewApiTests(APITestCase):
    def setUp(self):
        self.chef = User.objects.create_user(
            email='chef.overview@example.com',
            password='Test@12345',
            nom='Degustation',
            prenom='Chef',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.taster_one = User.objects.create_user(
            email='taster.one@example.com',
            password='Test@12345',
            nom='One',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.taster_two = User.objects.create_user(
            email='taster.two@example.com',
            password='Test@12345',
            nom='Two',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.taster_three = User.objects.create_user(
            email='taster.three@example.com',
            password='Test@12345',
            nom='Three',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.collecteur = User.objects.create_user(
            email='collector.overview@example.com',
            password='Test@12345',
            nom='Collector',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.fournisseur = Fournisseur.objects.create(
            nom='Domaine Sfax',
            region='Sfax',
        )
        self.received_at = timezone.now() - timedelta(days=1)
        self.sample = Echantillon.objects.create(
            reference_bouteille='REF-DIV-001',
            fournisseur=self.fournisseur,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
            recu_physiquement=True,
            date_arrivee_echantillon=self.received_at,
            date_reception_echantillon=self.received_at,
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def _submitted_eval(self, user, sample, fruite, classification='extra_vierge'):
        return EvaluationOrganoleptique.objects.create(
            echantillon=sample,
            degustateur=user,
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
            classification=classification,
            fruite=fruite,
            amertume='2.0',
            piquant='2.0',
            soumis_le=timezone.now(),
        )

    def test_only_chef_can_read_evaluation_overview(self):
        self.authenticate(self.taster_one)

        response = self.client.get('/api/chef/evaluations/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_groups_submitted_evaluations_by_sample_with_pending_members(self):
        self._submitted_eval(self.taster_one, self.sample, '2.0')
        self._submitted_eval(self.taster_two, self.sample, '2.0')
        self._submitted_eval(self.taster_three, self.sample, '5.0', classification='vierge')
        self.authenticate(self.chef)

        response = self.client.get('/api/chef/evaluations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data), 1)
        group = data[0]
        self.assertEqual(group['echantillon_id'], str(self.sample.id))
        self.assertEqual(group['numero'], self.sample.numero)
        self.assertEqual(group['reference_bouteille'], 'REF-DIV-001')
        self.assertEqual(group['submitted_count'], 3)
        self.assertEqual(group['total_count'], 4)
        self.assertFalse(group['is_complete'])
        self.assertTrue(group['divergence'])
        self.assertEqual(group['divergence_details'][0]['key'], 'fruite')

        statuses = {item['degustateur']: item['statut'] for item in group['evaluations']}
        self.assertEqual(statuses['Chef Degustation'], 'en_attente')
        self.assertEqual(statuses['Taster One'], EvaluationOrganoleptique.Statut.SOUMIS)

    def test_does_not_flag_divergence_before_three_submitted_evaluations(self):
        self._submitted_eval(self.taster_one, self.sample, '1.0')
        self._submitted_eval(self.taster_two, self.sample, '8.0')
        self.authenticate(self.chef)

        response = self.client.get('/api/chef/evaluations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.json()[0]['divergence'])

    def test_filters_by_physical_reception_date_and_search(self):
        old_sample = Echantillon.objects.create(
            reference_bouteille='REF-OLD-001',
            collecteur=self.collecteur,
            gouvernorat='Nabeul',
            delegation='Menzel Temime',
            variete='Chetoui',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now() - timedelta(days=30),
            date_reception_echantillon=timezone.now() - timedelta(days=30),
        )
        self._submitted_eval(self.taster_one, self.sample, '3.0')
        self._submitted_eval(self.taster_one, old_sample, '3.0')
        self.authenticate(self.chef)

        start_date = (timezone.now() - timedelta(days=2)).date().isoformat()
        response = self.client.get(
            f'/api/chef/evaluations/?date_debut={start_date}&search=REF-DIV'
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['echantillon_id'], str(self.sample.id))

    def test_overview_returns_physical_reception_not_scheduled_delivery(self):
        scheduled = timezone.now() - timedelta(days=5)
        received = timezone.now() - timedelta(days=1)
        self.sample.date_arrivee_echantillon = scheduled
        self.sample.date_reception_echantillon = received
        self.sample.save(
            update_fields=[
                'date_arrivee_echantillon',
                'date_reception_echantillon',
                'updated_at',
            ]
        )
        self._submitted_eval(self.taster_one, self.sample, '3.0')
        self.authenticate(self.chef)

        response = self.client.get('/api/chef/evaluations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.json()[0]['date_reception_physique'],
            received.isoformat(),
        )

    def test_drafts_are_not_exposed_in_chef_overview(self):
        EvaluationOrganoleptique.objects.create(
            echantillon=self.sample,
            degustateur=self.taster_one,
            statut=EvaluationOrganoleptique.Statut.EN_COURS,
            fruite='4.0',
        )
        self.authenticate(self.chef)

        response = self.client.get('/api/chef/evaluations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json(), [])


class ChefDashboardApiTests(APITestCase):
    def setUp(self):
        self.chef = User.objects.create_user(
            email='chef.dashboard@example.com',
            password='Test@12345',
            nom='Degustation',
            prenom='Chef',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.taster_one = User.objects.create_user(
            email='taster.dashboard.one@example.com',
            password='Test@12345',
            nom='One',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.taster_two = User.objects.create_user(
            email='taster.dashboard.two@example.com',
            password='Test@12345',
            nom='Two',
            prenom='Taster',
            role=User.Role.DEGUSTATEUR,
        )
        self.collecteur = User.objects.create_user(
            email='collector.dashboard@example.com',
            password='Test@12345',
            nom='Collector',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.supplier = Fournisseur.objects.create(
            nom='Domaine Dashboard',
            region='Sfax',
        )
        self.received_at = timezone.now() - timedelta(days=3)
        self.pending_sample = Echantillon.objects.create(
            reference_bouteille='REF-DASH-PENDING',
            fournisseur=self.supplier,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            date_arrivee_echantillon=self.received_at,
            statut_degustateur=Echantillon.StatutDegustateur.NON_EVALUEE,
        )
        self.in_progress_sample = Echantillon.objects.create(
            reference_bouteille='REF-DASH-COURSE',
            fournisseur=self.supplier,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chetoui',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now() - timedelta(days=2),
            statut_degustateur=Echantillon.StatutDegustateur.EN_COURS,
        )
        self.submitted_sample = Echantillon.objects.create(
            reference_bouteille='REF-DASH-SUB',
            fournisseur=self.supplier,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Oueslati',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now() - timedelta(days=1),
            statut_degustateur=Echantillon.StatutDegustateur.SOUMIS,
            statut_ceo=Echantillon.StatutCEO.SELECTIONNE,
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def _submitted_eval(self, user, sample, fruite, submitted_delta_hours=12):
        return EvaluationOrganoleptique.objects.create(
            echantillon=sample,
            degustateur=user,
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
            classification=Echantillon.Classification.EXTRA_VIERGE,
            fruite=fruite,
            amertume='2.0',
            piquant='2.0',
            soumis_le=sample.date_arrivee_echantillon + timedelta(hours=submitted_delta_hours),
        )

    def test_dashboard_endpoints_are_chef_only(self):
        self.authenticate(self.taster_one)

        response = self.client.get('/api/chef/dashboard/pipeline/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_pipeline_urgentes_and_ceo_blockers_return_flutter_keys(self):
        self.pending_sample.collecteur = None
        self.pending_sample.save(update_fields=['collecteur'])
        SessionDegustation.objects.create(
            titre='Session a valider',
            date=(timezone.now() + timedelta(days=1)).date(),
            heure=time(8, 30),
            lieu='Salle validation',
            cree_par=self.taster_one,
            statut=SessionDegustation.Statut.EN_ATTENTE_VALIDATION,
        )
        self.authenticate(self.chef)

        pipeline = self.client.get('/api/chef/dashboard/pipeline/')
        urgentes = self.client.get('/api/chef/dashboard/urgentes/')
        sessions = self.client.get('/api/chef/dashboard/sessions-en-attente/')
        ceo_blockers = self.client.get('/api/chef/dashboard/urgentes-ceo/')

        self.assertEqual(pipeline.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(pipeline.json()),
            {'receptionne', 'en_attente_eval', 'en_cours', 'soumis'},
        )
        self.assertEqual(pipeline.json()['en_attente_eval'], 1)
        self.assertEqual(pipeline.json()['en_cours'], 1)
        self.assertEqual(pipeline.json()['soumis'], 1)

        self.assertEqual(urgentes.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(urgentes.json()[0]),
            {
                'id', 'numero', 'reference', 'variete', 'collecteur_nom',
                'fournisseur_nom', 'jours_en_attente', 'days_waiting', 'badge',
            },
        )
        self.assertEqual(urgentes.json()[0]['id'], str(self.pending_sample.id))
        self.assertEqual(urgentes.json()[0]['collecteur_nom'], 'Inconnu')
        self.assertIn('jours_en_attente', urgentes.json()[0])
        self.assertIn('collecteur_nom', urgentes.json()[0])

        self.assertEqual(sessions.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(sessions.json()[0]),
            {'id', 'titre', 'date', 'heure', 'lieu', 'cree_par', 'propose_par'},
        )

        self.assertEqual(ceo_blockers.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(ceo_blockers.json()[0]),
            {
                'id', 'numero', 'reference', 'reference_bouteille', 'variete',
                'collecteur_nom', 'fournisseur_nom',
            },
        )
        self.assertEqual(ceo_blockers.json()[0]['id'], str(self.submitted_sample.id))
        self.assertEqual(ceo_blockers.json()[0]['reference_bouteille'], 'REF-DASH-SUB')

    def test_delai_alignement_and_classifications_use_submitted_evaluations(self):
        self._submitted_eval(self.chef, self.submitted_sample, '2.0', submitted_delta_hours=24)
        self._submitted_eval(self.taster_one, self.submitted_sample, '2.0', submitted_delta_hours=48)
        self._submitted_eval(self.taster_two, self.submitted_sample, '5.0', submitted_delta_hours=72)
        self.authenticate(self.chef)

        delai = self.client.get('/api/chef/dashboard/delai/')
        alignement = self.client.get('/api/chef/dashboard/alignement/')
        classifications = self.client.get('/api/chef/dashboard/classifications/')

        self.assertEqual(delai.status_code, status.HTTP_200_OK)
        self.assertEqual(set(delai.json()), {'membres', 'panel_moyen'})
        self.assertEqual(
            set(delai.json()['membres'][0]),
            {'nom', 'delai_moyen', 'panel_moyen'},
        )
        self.assertEqual(delai.json()['panel_moyen'], 2.0)
        self.assertEqual(len(delai.json()['membres']), 3)

        self.assertEqual(alignement.status_code, status.HTTP_200_OK)
        self.assertEqual(set(alignement.json()), {'membres'})
        self.assertEqual(
            set(alignement.json()['membres'][0]),
            {'nom', 'divergence_pct'},
        )
        divergent = {
            item['nom']: item['divergence_pct']
            for item in alignement.json()['membres']
        }
        self.assertGreater(divergent['Taster Two'], 0)

        self.assertEqual(classifications.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(classifications.json()[0]),
            {'label', 'annee', 'mois', 'extra_vierge', 'vierge', 'lampante'},
        )
        # Somme sur tous les mois : les trois evaluations sont soumises a 24h,
        # 48h et 72h d'intervalle, elles peuvent donc tomber a cheval sur deux
        # mois. Lire seulement le premier groupe faisait echouer ce test les
        # trois derniers jours de chaque mois.
        total_extra_vierge = sum(
            mois['extra_vierge'] for mois in classifications.json()
        )
        self.assertEqual(total_extra_vierge, 3)

    def test_presence_and_activity_are_paginated_and_do_not_include_drafts(self):
        self._submitted_eval(self.chef, self.submitted_sample, '3.0')
        draft_sample = Echantillon.objects.create(
            reference_bouteille='REF-DRAFT',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
        )
        EvaluationOrganoleptique.objects.create(
            echantillon=draft_sample,
            degustateur=self.chef,
            statut=EvaluationOrganoleptique.Statut.EN_COURS,
        )
        past_present = SessionDegustation.objects.create(
            titre='Session presente',
            date=(timezone.now() - timedelta(days=2)).date(),
            heure=time(9, 0),
            lieu='Salle A',
            cree_par=self.chef,
            statut=SessionDegustation.Statut.TERMINEE,
        )
        past_present.presences_confirmees.add(self.chef)
        past_missing = SessionDegustation.objects.create(
            titre='Session manquee',
            date=(timezone.now() - timedelta(days=1)).date(),
            heure=time(10, 0),
            lieu='Salle B',
            cree_par=self.chef,
            statut=SessionDegustation.Statut.PLANIFIEE,
        )
        future = SessionDegustation.objects.create(
            titre='Session future',
            date=(timezone.now() + timedelta(days=3)).date(),
            heure=time(11, 0),
            lieu='Salle C',
            cree_par=self.chef,
            statut=SessionDegustation.Statut.PLANIFIEE,
        )
        self.authenticate(self.chef)

        date_fin = timezone.now().date().isoformat()
        presence = self.client.get(
            f'/api/chef/dashboard/presence/?date_fin={date_fin}'
        )
        activity = self.client.get('/api/chef/dashboard/activite/?offset=0&limit=2')

        self.assertEqual(presence.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(presence.json()),
            {
                'present', 'manquee', 'prochaine_titre', 'prochaine_date',
                'prochaine_lieu', 'prochaine_countdown',
            },
        )
        self.assertEqual(presence.json()['present'], 1)
        self.assertEqual(presence.json()['manquee'], 1)
        self.assertEqual(presence.json()['prochaine_titre'], future.titre)

        self.assertEqual(activity.status_code, status.HTTP_200_OK)
        self.assertEqual(set(activity.json()), {'count', 'results'})
        self.assertEqual(
            set(activity.json()['results'][0]),
            {'id', 'type', 'date', 'horodatage', 'description', 'action'},
        )
        self.assertEqual(activity.json()['count'], 4)
        self.assertEqual(len(activity.json()['results']), 2)
        self.assertIn('action', activity.json()['results'][0])
        self.assertIn('horodatage', activity.json()['results'][0])


class PanelCoiEtRegionsTests(APITestCase):
    """Tache 60 : resultat du panel (methode COI_CALC) et carte par gouvernorat."""

    def setUp(self):
        def creer(email, role):
            return User.objects.create_user(
                email=email, password='Test@12345', nom='N', prenom='P', role=role,
            )

        self.chef = creer('coi.chef@example.com', User.Role.CHEF_DEGUSTATION)
        self.direction = creer('coi.direction@example.com', User.Role.DIRECTION)
        self.taster = creer('coi.taster@example.com', User.Role.DEGUSTATEUR)
        self.tasters = [
            creer(f'coi.t{i}@example.com', User.Role.DEGUSTATEUR) for i in range(8)
        ]
        self.sample = Echantillon.objects.create(
            reference_bouteille='COI-1', gouvernorat='Sfax', recu_physiquement=True,
        )
        # Echantillon 1 du fichier COI_CALC.xlsx (juges A a H).
        rance = ['5', '5', '5', '6', '5', '7', '5', '7']
        fruite = ['4.1', '3', '2.3', '3', '2.7', '3', '0', '0']
        for user, r, f in zip(self.tasters, rance, fruite):
            EvaluationOrganoleptique.objects.create(
                echantillon=self.sample,
                degustateur=user,
                statut=EvaluationOrganoleptique.Statut.SOUMIS,
                classification='vierge_ordinaire',
                rance=r,
                fruite=f,
                soumis_le=timezone.now(),
            )

    def test_resultat_panel_suit_le_fichier_du_coi(self):
        self.client.force_authenticate(user=self.chef)
        response = self.client.get(f'/api/chef/panel-coi/?echantillon={self.sample.id}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ligne = response.json()[0]
        self.assertEqual(ligne['nombre_degustateurs'], 8)
        attributs = {a['champ']: a for a in ligne['attributs']}
        self.assertEqual(attributs['rance']['mediane'], 5.0)
        self.assertEqual(attributs['rance']['iqr'], 1.25)
        self.assertEqual(attributs['rance']['cvr'], 8.2)
        self.assertEqual(attributs['fruite']['mediane'], 2.85)
        # Defaut principal 5 (> 3.5, <= 6) avec du fruite : vierge ordinaire.
        self.assertEqual(ligne['mediane_defaut_principal'], 5.0)
        self.assertEqual(ligne['classification'], 'vierge_ordinaire')
        self.assertTrue(ligne['fiable'])

    def test_panel_reserve_au_chef(self):
        self.client.force_authenticate(user=self.taster)
        response = self.client.get('/api/chef/panel-coi/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_regions_pour_chef_et_direction(self):
        Echantillon.objects.create(
            reference_bouteille='R-2', gouvernorat='sfax ',
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
        )
        Echantillon.objects.create(reference_bouteille='R-3', gouvernorat='Gabès')
        for user, chemin in (
            (self.chef, '/api/chef/dashboard/regions/'),
            (self.direction, '/api/ceo/dashboard/regions/'),
        ):
            self.client.force_authenticate(user=user)
            response = self.client.get(chemin)
            self.assertEqual(response.status_code, status.HTTP_200_OK)
            premiere = response.json()[0]
            # « Sfax » et « sfax » forment un seul gouvernorat.
            self.assertEqual(premiere['gouvernorat'], 'Sfax')
            self.assertEqual(premiere['echantillons'], 2)
            self.assertEqual(premiere['achats'], 1)

    def test_regions_refusees_au_degustateur(self):
        self.client.force_authenticate(user=self.taster)
        self.assertEqual(
            self.client.get('/api/chef/dashboard/regions/').status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(
            self.client.get('/api/ceo/dashboard/regions/').status_code,
            status.HTTP_403_FORBIDDEN,
        )
