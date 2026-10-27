from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from echantillons.models import Echantillon
from fournisseurs.models import Fournisseur
from users.models import User


class ServiceAchatTests(APITestCase):
    def setUp(self):
        def creer(email, role):
            return User.objects.create_user(
                email=email, password='Test@12345', nom='N', prenom='P', role=role,
            )

        self.achat = creer('achat@example.com', User.Role.SERVICE_ACHAT)
        self.chef = creer('achat.chef@example.com', User.Role.CHEF_DEGUSTATION)
        fournisseur = Fournisseur.objects.create(nom='hami', region='Gabès')
        Echantillon.objects.create(
            reference_bouteille='ACH-1', gouvernorat='Gabès', fournisseur=fournisseur,
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
            classification='extra_vierge', remarques='note de degustation',
            quantite_cible_t='12.5', date_livraison_stock=timezone.now(),
        )
        Echantillon.objects.create(
            reference_bouteille='ACH-2', gouvernorat='Sfax',
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
        )

    def test_voit_seulement_les_achats_confirmes(self):
        self.client.force_authenticate(user=self.achat)
        response = self.client.get('/api/service-achat/achats/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([a['reference_bouteille'] for a in response.json()], ['ACH-1'])
        achat = response.json()[0]
        self.assertEqual(achat['fournisseur_nom'], 'hami')
        self.assertEqual(achat['quantite_cible_t'], 12.5)
        self.assertIsNotNone(achat['date_livraison_prevue'])

    def test_aucune_donnee_de_degustation_ni_de_labo(self):
        self.client.force_authenticate(user=self.achat)
        achat = self.client.get('/api/service-achat/achats/').json()[0]
        for champ in ('classification', 'remarques', 'statut_degustateur',
                      'statut_labo', 'note_interne'):
            self.assertNotIn(champ, achat)

    def test_pas_d_acces_aux_evaluations_ni_au_labo(self):
        self.client.force_authenticate(user=self.achat)
        for chemin in ('/api/evaluations/', '/api/analyses/', '/api/echantillons/',
                       '/api/chef/evaluations/'):
            self.assertEqual(
                self.client.get(chemin).status_code, status.HTTP_403_FORBIDDEN, chemin,
            )

    def test_reserve_au_service_achat(self):
        self.client.force_authenticate(user=self.chef)
        response = self.client.get('/api/service-achat/achats/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_le_chef_cree_un_compte_service_achat_qui_peut_se_connecter(self):
        self.client.force_authenticate(user=self.chef)
        response = self.client.post(
            '/api/users/',
            {'email': 'service.achat@stca.tn', 'nom': 'Achat', 'prenom': 'Service',
             'role': User.Role.SERVICE_ACHAT},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.client.force_authenticate(user=None)
        login = self.client.post(
            '/api/auth/login/',
            {'email': 'service.achat@stca.tn',
             'password': response.data['mot_de_passe_temporaire']},
            format='json',
        )
        self.assertEqual(login.status_code, status.HTTP_200_OK, login.data)
