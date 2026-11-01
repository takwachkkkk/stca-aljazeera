from decimal import Decimal
from datetime import datetime, timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from analyses.models import AnalyseLabo
from ceo.models import DecisionDirection
from echantillons.models import Echantillon
from evaluations.models import EvaluationOrganoleptique
from fournisseurs.models import Fournisseur
from users.models import User


class CeoDashboardApiTests(APITestCase):
    def setUp(self):
        self.direction = User.objects.create_user(
            email='direction.dashboard@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.collecteur = User.objects.create_user(
            email='collecteur.dashboard@example.com',
            password='Test@12345',
            nom='Collector',
            prenom='One',
            role=User.Role.COLLECTEUR,
        )
        self.other_collecteur = User.objects.create_user(
            email='collecteur.dashboard.other@example.com',
            password='Test@12345',
            nom='Collector',
            prenom='Two',
            role=User.Role.COLLECTEUR,
        )
        self.lab = User.objects.create_user(
            email='lab.dashboard@example.com',
            password='Test@12345',
            nom='Lab',
            prenom='Tech',
            role=User.Role.LABORATOIRE,
        )
        self.supplier = Fournisseur.objects.create(
            nom='Domaine Test',
            region='Sfax',
        )

        self.received = Echantillon.objects.create(
            reference_bouteille='REF-CEO-001',
            fournisseur=self.supplier,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=True,
            statut_collecteur=Echantillon.StatutCollecteur.RECEPTIONNE,
            statut_degustateur=Echantillon.StatutDegustateur.EN_COURS,
        )
        self.negotiation = Echantillon.objects.create(
            reference_bouteille='REF-CEO-002',
            fournisseur=self.supplier,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chetoui',
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
        )
        self.purchase = Echantillon.objects.create(
            reference_bouteille='REF-CEO-003',
            fournisseur=self.supplier,
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Oueslati',
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
            statut_ceo=Echantillon.StatutCEO.ACHAT_CONFIRME,
            prix_final=Decimal('8.500'),
            quantite_cible_t=Decimal('12'),
            stock_arrive=True,
            classification=Echantillon.Classification.EXTRA_VIERGE,
        )
        self.urgent = Echantillon.objects.create(
            reference_bouteille='REF-CEO-004',
            collecteur=self.other_collecteur,
            gouvernorat='Nabeul',
            variete='Arbequina',
            recu_physiquement=True,
            statut_collecteur=Echantillon.StatutCollecteur.RECEPTIONNE,
            statut_degustateur=Echantillon.StatutDegustateur.SOUMIS,
            statut_ceo=Echantillon.StatutCEO.SELECTIONNE,
        )
        self.refused = Echantillon.objects.create(
            reference_bouteille='REF-CEO-005',
            collecteur=self.other_collecteur,
            gouvernorat='Beja',
            variete='Zalmati',
            statut_ceo=Echantillon.StatutCEO.REFUSE,
        )
        AnalyseLabo.objects.create(
            echantillon=self.purchase,
            technicien=self.lab,
            statut=AnalyseLabo.Statut.SOUMIS,
        )

        old_date = timezone.now() - timedelta(days=3)
        Echantillon.objects.filter(id=self.urgent.id).update(updated_at=old_date)

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def test_dashboard_is_direction_only(self):
        self.authenticate(self.collecteur)

        response = self.client.get('/api/ceo/dashboard/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_dashboard_returns_kpis_pipeline_and_aggregations(self):
        self.authenticate(self.direction)

        response = self.client.get('/api/ceo/dashboard/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()

        self.assertEqual(data['echantillons_total'], 5)
        self.assertEqual(data['achats_confirmes'], 1)
        self.assertEqual(data['stocks_arrives'], 1)
        self.assertEqual(data['evaluations_en_attente'], 1)
        self.assertEqual(data['analyses_soumises'], 1)

        self.assertNotIn('pipeline', data)

        # 8,500 DT/kg x 12 tonnes, et non la somme des prix au kilo.
        self.assertEqual(data['kpis']['investissement_total'], 102000)
        self.assertEqual(data['stock'], {'en_transit': 0, 'recu': 1})
        self.assertEqual(data['classifications']['extra_vierge'], 1)
        self.assertEqual(data['fournisseurs'][0]['nom'], 'Domaine Test')
        self.assertEqual(data['fournisseurs'][0]['achats'], 1)
        self.assertEqual(data['performance_collecteurs'][0]['samples'], 3)
        self.assertEqual(data['decisions_urgentes'][0]['id'], str(self.urgent.id))
        self.assertGreaterEqual(data['decisions_urgentes'][0]['jours_en_attente'], 3)
        self.assertEqual(len(data['evolution_achats']), 6)

    def test_dashboard_date_filters_use_sample_creation_date(self):
        old_date = timezone.now() - timedelta(days=40)
        Echantillon.objects.filter(id=self.purchase.id).update(date_ajout=old_date)
        self.authenticate(self.direction)
        start = (timezone.now() - timedelta(days=7)).date().isoformat()

        response = self.client.get(f'/api/ceo/dashboard/?date_debut={start}')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['echantillons_total'], 4)
        self.assertEqual(data['achats_confirmes'], 0)
        self.assertEqual(data['analyses_soumises'], 0)

    def test_un_achat_compte_a_sa_date_d_achat(self):
        # Echantillon enregistre il y a 40 jours, achete il y a 2 jours.
        Echantillon.objects.filter(id=self.purchase.id).update(
            date_ajout=timezone.now() - timedelta(days=40),
            date_achat_confirme=timezone.now() - timedelta(days=2),
        )
        self.authenticate(self.direction)
        hier = timezone.localdate() - timedelta(days=1)
        debut = timezone.localdate() - timedelta(days=7)

        dans = self.client.get(f'/api/ceo/dashboard/?date_debut={debut}').json()
        hors = self.client.get(f'/api/ceo/dashboard/?date_debut={hier}').json()

        self.assertEqual(dans['achats_confirmes'], 1)
        self.assertEqual(dans['kpis']['investissement_total'], 102000)
        self.assertEqual(dans['fournisseurs'][0]['valeur'], 102000)
        self.assertEqual(dans['performance_collecteurs'][0]['total_value'], 102000)
        self.assertEqual(hors['achats_confirmes'], 0)
        self.assertEqual(hors['fournisseurs'], [])

    def _evolution(self, debut, fin):
        self.authenticate(self.direction)
        response = self.client.get(
            f'/api/ceo/dashboard/?date_debut={debut}&date_fin={fin}'
        )
        return response.json()['evolution_achats']

    def test_evolution_suit_les_dates_du_filtre(self):
        Echantillon.objects.filter(id=self.purchase.id).update(
            date_achat_confirme=timezone.make_aware(datetime(2026, 3, 15, 12)),
        )

        par_mois = self._evolution('2026-01-01', '2026-06-30')
        self.assertEqual(
            [point['label'] for point in par_mois],
            ['Jan 26', 'Fév 26', 'Mar 26', 'Avr 26', 'Mai 26', 'Jun 26'],
        )
        self.assertEqual([point['valeur'] for point in par_mois],
                         [0, 0, 102000, 0, 0, 0])

        par_semaine = self._evolution('2026-03-01', '2026-03-31')
        self.assertEqual(len(par_semaine), 5)
        self.assertEqual(par_semaine[2]['label'], '15 Mar')
        self.assertEqual(par_semaine[2]['valeur'], 102000)

        par_jour = self._evolution('2026-03-14', '2026-03-16')
        self.assertEqual([point['count'] for point in par_jour], [0, 1, 0])

        hors_periode = self._evolution('2025-01-01', '2025-06-30')
        self.assertEqual(sum(point['valeur'] for point in hors_periode), 0)

    def test_synthese_des_achats_par_categorie(self):
        # Sans classification propre : la categorie vient du panel.
        vierge = Echantillon.objects.create(
            reference_bouteille='REF-CEO-006',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
            prix_final=Decimal('7.200'),
            quantite_cible_t=Decimal('5'),
        )
        EvaluationOrganoleptique.objects.create(
            echantillon=vierge,
            degustateur=self.direction,
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
            rance=2,
            fruite=4,
        )
        # Sans quantite, ni panel : aucun montant possible.
        Echantillon.objects.create(
            reference_bouteille='REF-CEO-007',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
            prix_final=Decimal('6.000'),
        )
        self.authenticate(self.direction)

        achats = self.client.get('/api/ceo/dashboard/').json()['achats']

        self.assertEqual(achats['nombre'], 3)
        self.assertEqual(achats['sans_quantite'], 1)
        self.assertEqual(achats['quantite_totale_t'], 17)
        self.assertEqual(achats['montant_total'], 138000)
        categories = {ligne['cle']: ligne for ligne in achats['categories']}
        self.assertEqual(categories['extra_vierge']['quantite_t'], 12)
        self.assertEqual(categories['extra_vierge']['montant'], 102000)
        self.assertEqual(categories['vierge']['quantite_t'], 5)
        self.assertEqual(categories['lampante']['nombre'], 0)
        self.assertEqual(categories['non_classe']['nombre'], 1)
        self.assertEqual(achats['dernier_prix']['extra_vierge']['prix'], 8.5)
        self.assertEqual(achats['dernier_prix']['vierge']['prix'], 7.2)

    def test_dernier_prix_est_le_plus_recent(self):
        ancien = Echantillon.objects.create(
            reference_bouteille='REF-CEO-008',
            gouvernorat='Sfax',
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
            classification=Echantillon.Classification.EXTRA_VIERGE,
            prix_final=Decimal('9.900'),
        )
        Echantillon.objects.filter(id=ancien.id).update(
            date_achat_confirme=timezone.now() - timedelta(days=30),
        )
        self.authenticate(self.direction)

        achats = self.client.get('/api/ceo/dashboard/').json()['achats']

        self.assertEqual(achats['dernier_prix']['extra_vierge']['prix'], 8.5)


class DecisionDirectionTests(APITestCase):
    """
    Chaque decision de la direction garde son auteur : avec plusieurs comptes
    direction et des reouvertures, un champ unique ecraserait le precedent.
    """

    def setUp(self):
        self.collecteur = User.objects.create_user(
            email='collecteur.decision@example.com', password='Test@12345',
            nom='Trabelsi', prenom='Sami', role=User.Role.COLLECTEUR,
        )
        self.direction_a = User.objects.create_user(
            email='direction.a@example.com', password='Test@12345',
            nom='Ben Ali', prenom='Amel', role=User.Role.DIRECTION,
        )
        self.direction_b = User.objects.create_user(
            email='direction.b@example.com', password='Test@12345',
            nom='Gharbi', prenom='Nour', role=User.Role.DIRECTION,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='DECISION-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
        )

    def url(self, action):
        return f'/api/echantillons/{self.sample.id}/{action}/'

    def test_approuver_enregistre_la_personne_et_le_budget(self):
        self.client.force_authenticate(user=self.direction_a)
        response = self.client.patch(
            self.url('approuver'),
            {'budget_negociation': '8.60', 'note_interne': 'Bon lot'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        decision = DecisionDirection.objects.get(echantillon=self.sample)
        self.assertEqual(decision.direction, self.direction_a)
        self.assertEqual(decision.type, DecisionDirection.Type.NEGOCIATION)
        self.assertEqual(decision.budget_negociation, Decimal('8.60'))
        self.assertEqual(decision.note_interne, 'Bon lot')

    def test_refuser_enregistre_la_personne_et_la_raison(self):
        self.client.force_authenticate(user=self.direction_a)
        response = self.client.patch(
            self.url('refuser'), {'raison_refus': 'Acidite elevee'}, format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        decision = DecisionDirection.objects.get(echantillon=self.sample)
        self.assertEqual(decision.direction, self.direction_a)
        self.assertEqual(decision.type, DecisionDirection.Type.REFUS)
        self.assertEqual(decision.raison_refus, 'Acidite elevee')

    def test_une_reouverture_ne_remplace_pas_la_decision_d_un_autre(self):
        self.client.force_authenticate(user=self.direction_a)
        self.client.patch(
            self.url('approuver'), {'budget_negociation': '8.00'}, format='json',
        )
        Echantillon.objects.filter(pk=self.sample.pk).update(
            statut_ceo=Echantillon.StatutCEO.ACHAT_NON_CONCLU,
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_NON_CONCLU,
        )

        self.client.force_authenticate(user=self.direction_b)
        response = self.client.patch(
            self.url('approuver'), {'budget_negociation': '8.60'}, format='json',
        )

        self.assertEqual(
            [
                (d['type'], d['direction_nom'], d['budget_negociation'])
                for d in response.json()['decisions_direction']
            ],
            [
                ('reouverture', 'Nour Gharbi', '8.600'),
                ('negociation', 'Amel Ben Ali', '8.000'),
            ],
        )

    def test_une_decision_refusee_ne_laisse_aucune_trace(self):
        Echantillon.objects.filter(pk=self.sample.pk).update(
            statut_ceo=Echantillon.StatutCEO.ACHAT_CONFIRME,
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
        )
        self.client.force_authenticate(user=self.direction_a)
        response = self.client.patch(self.url('approuver'), {}, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(DecisionDirection.objects.exists())

    def test_l_historique_reste_reserve_a_la_direction(self):
        DecisionDirection.objects.create(
            echantillon=self.sample,
            direction=self.direction_a,
            type=DecisionDirection.Type.NEGOCIATION,
        )
        self.client.force_authenticate(user=self.collecteur)
        response = self.client.get(f'/api/echantillons/{self.sample.id}/')

        self.assertEqual(response.json()['decisions_direction'], [])

    def test_la_decision_survit_a_la_suppression_du_compte(self):
        decision = DecisionDirection.objects.create(
            echantillon=self.sample,
            direction=self.direction_a,
            type=DecisionDirection.Type.REFUS,
        )
        self.direction_a.delete()
        decision.refresh_from_db()

        self.assertIsNone(decision.direction)

    def test_le_collecteur_ne_peut_pas_modifier_les_champs_de_la_direction(self):
        Echantillon.objects.filter(pk=self.sample.pk).update(
            budget_negociation='8.00',
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
        )
        self.client.force_authenticate(user=self.collecteur)
        self.client.patch(
            f'/api/echantillons/{self.sample.id}/',
            {
                'statut_ceo': Echantillon.StatutCEO.ACHAT_CONFIRME,
                'budget_negociation': '99.00',
                'raison_refus': 'Falsifie',
            },
            format='json',
        )

        self.sample.refresh_from_db()
        self.assertEqual(self.sample.statut_ceo, Echantillon.StatutCEO.EN_NEGOCIATION)
        self.assertEqual(self.sample.budget_negociation, Decimal('8.00'))
        self.assertEqual(self.sample.raison_refus, '')
