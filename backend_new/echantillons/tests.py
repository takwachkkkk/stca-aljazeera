from datetime import timedelta
from unittest.mock import patch

import requests
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.test import APITestCase

from fournisseurs.models import Fournisseur
from notifications.models import Notification
from users.models import User

from .models import Echantillon


class EchantillonOcrApiTests(APITestCase):
    def setUp(self):
        self.collector = User.objects.create_user(
            email='ocr.collecteur@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='Ocr',
            role=User.Role.COLLECTEUR,
        )
        self.degustateur = User.objects.create_user(
            email='ocr.degustateur@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='Ocr',
            role=User.Role.DEGUSTATEUR,
        )
        self.chef = User.objects.create_user(
            email='ocr.chef@example.com',
            password='Test@12345',
            nom='Chef',
            prenom='Ocr',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.direction = User.objects.create_user(
            email='ocr.direction@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='Ocr',
            role=User.Role.DIRECTION,
        )
        self.labo = User.objects.create_user(
            email='ocr.labo@example.com',
            password='Test@12345',
            nom='Labo',
            prenom='Ocr',
            role=User.Role.LABORATOIRE,
        )

    def _image(self):
        return SimpleUploadedFile(
            'etiquette.jpg',
            b'\xff\xd8\xff\xe0test',
            content_type='image/jpeg',
        )

    def _mock_operation(self, mocked_post, mocked_get, payload):
        mocked_post.return_value.raise_for_status.return_value = None
        mocked_post.return_value.headers = {
            'Operation-Location': 'https://docintel.example/operations/1',
        }
        mocked_get.return_value.raise_for_status.return_value = None
        mocked_get.return_value.json.return_value = payload

    def _post_image(self):
        return self.client.post(
            '/api/echantillons/ocr/',
            {'image': self._image()},
            format='multipart',
        )

    @override_settings(AZURE_DOCINTEL_ENDPOINT='', AZURE_DOCINTEL_KEY='')
    def test_statut_inactif_sans_configuration_azure(self):
        self.client.force_authenticate(user=self.collector)

        response = self.client.get('/api/echantillons/ocr/statut/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, {'actif': False})

    @override_settings(AZURE_DOCINTEL_ENDPOINT='https://docintel.example', AZURE_DOCINTEL_KEY='secret')
    def test_statut_actif_avec_configuration_azure(self):
        self.client.force_authenticate(user=self.degustateur)

        response = self.client.get('/api/echantillons/ocr/statut/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, {'actif': True})

    @override_settings(AZURE_DOCINTEL_ENDPOINT='', AZURE_DOCINTEL_KEY='')
    def test_ocr_renvoie_503_sans_configuration_azure(self):
        self.client.force_authenticate(user=self.chef)

        response = self.client.post(
            '/api/echantillons/ocr/',
            {'image': self._image()},
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(
            response.data['detail'],
            "La lecture automatique n'est pas encore activée. Contactez l'administrateur.",
        )

    @override_settings(AZURE_DOCINTEL_ENDPOINT='https://docintel.example', AZURE_DOCINTEL_KEY='secret')
    @patch('core.ocr_azure.time.sleep')
    @patch('core.ocr_azure.requests.get')
    @patch('core.ocr_azure.requests.post')
    def test_ocr_extrait_les_champs_depuis_azure_simule(self, mocked_post, mocked_get, _sleep):
        Fournisseur.objects.create(nom='Domaine Hami', region='Sfax', delegation='Sfax Sud')
        self._mock_operation(mocked_post, mocked_get, {
            'status': 'succeeded',
            'analyzeResult': {
                'pages': [
                    {
                        'lines': [
                            {'content': 'Fournisseur: Domaine Hami'},
                            {'content': 'Reference: HAM-C1'},
                            {'content': 'Citerne: C1'},
                            {'content': 'Quantite: 12T'},
                            {'content': 'Variete: Chemlali'},
                        ]
                    }
                ]
            },
        })
        self.client.force_authenticate(user=self.collector)

        response = self._post_image()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn(
            '/documentintelligence/documentModels/prebuilt-read:analyze',
            mocked_post.call_args.args[0],
        )
        mocked_get.assert_called_once()
        self.assertEqual(
            mocked_get.call_args.args[0],
            'https://docintel.example/operations/1',
        )
        self.assertEqual(response.data['reference_bouteille'], 'HAM-C1')
        self.assertEqual(response.data['num_citerne'], 'C1')
        self.assertEqual(response.data['quantite'], '12T')
        self.assertEqual(response.data['variete'], 'Chemlali')
        self.assertEqual(response.data['fournisseur_nom'], 'Domaine Hami')
        self.assertIn('Fournisseur: Domaine Hami', response.data['raw_text'])

    @override_settings(AZURE_DOCINTEL_ENDPOINT='https://docintel.example', AZURE_DOCINTEL_KEY='secret')
    @patch('core.ocr_azure.time.sleep')
    @patch('core.ocr_azure.requests.get')
    @patch('core.ocr_azure.requests.post')
    def test_ocr_renvoie_503_si_analyse_azure_echoue(self, mocked_post, mocked_get, _sleep):
        self._mock_operation(mocked_post, mocked_get, {'status': 'failed'})
        self.client.force_authenticate(user=self.degustateur)

        response = self._post_image()

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(
            response.data['detail'],
            "La lecture automatique n'a pas répondu. Réessayez dans un instant.",
        )

    @override_settings(AZURE_DOCINTEL_ENDPOINT='https://docintel.example', AZURE_DOCINTEL_KEY='secret')
    @patch('core.ocr_azure.requests.post')
    def test_ocr_renvoie_503_si_azure_ne_repond_pas(self, mocked_post):
        mocked_post.side_effect = requests.exceptions.Timeout()
        self.client.force_authenticate(user=self.chef)

        response = self._post_image()

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(
            response.data['detail'],
            "La lecture automatique n'a pas répondu. Réessayez dans un instant.",
        )

    @override_settings(AZURE_DOCINTEL_ENDPOINT='https://docintel.example', AZURE_DOCINTEL_KEY='secret')
    def test_ocr_interdit_aux_roles_non_autorises(self):
        for user in (self.direction, self.labo):
            self.client.force_authenticate(user=user)
            response = self.client.get('/api/echantillons/ocr/statut/')
            self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class EchantillonNumeroGenerationTests(APITestCase):
    def test_numero_continues_numerically_after_9999(self):
        Echantillon.objects.create(
            numero='2026/9999',
            reference_bouteille='NUM-9999',
            gouvernorat='Sfax',
        )

        with patch('echantillons.models.datetime') as mocked_datetime:
            mocked_datetime.now.return_value.year = 2026
            first = Echantillon.objects.create(
                reference_bouteille='NUM-10000',
                gouvernorat='Sfax',
            )
            second = Echantillon.objects.create(
                reference_bouteille='NUM-10001',
                gouvernorat='Sfax',
            )

        self.assertEqual(first.numero, '2026/10000')
        self.assertEqual(second.numero, '2026/10001')


class CollectorEchantillonApiTests(APITestCase):
    def setUp(self):
        self.collector = User.objects.create_user(
            email='collecteur1@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='One',
            role=User.Role.COLLECTEUR,
        )
        self.other_collector = User.objects.create_user(
            email='collecteur2@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='Two',
            role=User.Role.COLLECTEUR,
        )
        self.direction = User.objects.create_user(
            email='direction2@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.degustateur = User.objects.create_user(
            email='degustateur.reception@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='User',
            role=User.Role.DEGUSTATEUR,
        )
        self.chef = User.objects.create_user(
            email='chef.echantillons@example.com',
            password='Test@12345',
            nom='Chef',
            prenom='User',
            role=User.Role.CHEF_DEGUSTATION,
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def results(self, response):
        data = response.json()
        return data.get('results', data)

    def create_sample(self, collecteur, **extra):
        data = {
            'reference_bouteille': 'B-001',
            'collecteur': collecteur,
            'gouvernorat': 'Sfax',
            'delegation': 'Sfax Sud',
            'variete': 'Chemlali',
        }
        data.update(extra)
        return Echantillon.objects.create(**data)

    def test_collector_only_lists_own_samples(self):
        own = self.create_sample(self.collector, reference_bouteille='OWN')
        other = self.create_sample(self.other_collector, reference_bouteille='OTHER')
        self.authenticate(self.collector)

        response = self.client.get('/api/echantillons/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertIn(str(own.id), ids)
        self.assertNotIn(str(other.id), ids)

    def test_collector_can_create_sample_with_supplier_name_and_location(self):
        self.authenticate(self.collector)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'CHEM-001',
                'fournisseur_nom': 'hami',
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
                'variete': 'Chemlali',
                'quantite_estimee': '20L',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.json()
        self.assertTrue(data['numero'])
        self.assertNotIn('code_' + 'fournisseur', data)
        sample = Echantillon.objects.get(id=data['id'])
        self.assertEqual(sample.collecteur, self.collector)
        self.assertEqual(sample.fournisseur.nom, 'hami')
        self.assertEqual(sample.fournisseur.region, 'Sfax')
        self.assertEqual(sample.fournisseur.delegation, 'Sfax Sud')

    def test_collector_sample_with_unknown_supplier_name_creates_and_links_it(self):
        self.authenticate(self.collector)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'NOM-001',
                'fournisseur_nom': 'Domaine Nouveau',
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertIsNotNone(sample.fournisseur)
        self.assertEqual(sample.fournisseur.nom, 'Domaine Nouveau')
        self.assertEqual(sample.fournisseur.region, 'Sfax')
        self.assertEqual(sample.fournisseur.delegation, 'Sfax Sud')
        self.assertEqual(
            Fournisseur.objects.filter(nom='Domaine Nouveau').count(),
            1,
        )

    def test_collector_sample_with_existing_supplier_name_does_not_duplicate_it(self):
        supplier = Fournisseur.objects.create(
            nom='Domaine Existant',
            region='Sfax',
            delegation='Sfax Sud',
        )
        self.authenticate(self.collector)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'NOM-002',
                'fournisseur_nom': 'domaine existant',
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertEqual(sample.fournisseur, supplier)
        self.assertEqual(
            Fournisseur.objects.filter(nom__iexact='Domaine Existant').count(),
            1,
        )

    def test_collector_can_create_sample_with_only_supplier_and_reference(self):
        self.authenticate(self.collector)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'MIN-001',
                'fournisseur_nom': 'Fournisseur Minimal',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertEqual(sample.reference_bouteille, 'MIN-001')
        self.assertEqual(sample.fournisseur.nom, 'Fournisseur Minimal')
        self.assertEqual(sample.gouvernorat, '')

    def test_update_without_supplier_fields_keeps_the_existing_supplier(self):
        # Le chef qui corrige une variete envoie sa mise a jour sans
        # aucun champ fournisseur (depuis la tache 59, un degustateur ne
        # modifie plus l'echantillon d'un collecteur). Le lien doit survivre : l'effacer ici
        # supprimerait le fournisseur d'un echantillon sans que personne ne le
        # demande, et sans qu'aucun message ne le signale.
        supplier = Fournisseur.objects.create(
            nom='Domaine A Conserver',
            region='Sfax',
            delegation='Sfax Sud',
        )
        self.authenticate(self.collector)
        created = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'MAJ-001',
                'fournisseur_nom': 'Domaine A Conserver',
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
            },
            format='json',
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        sample_id = created.data['id']

        self.authenticate(self.chef)
        response = self.client.patch(
            f'/api/echantillons/{sample_id}/',
            {'variete': 'Chetoui'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample = Echantillon.objects.get(id=sample_id)
        self.assertEqual(sample.variete, 'Chetoui')
        self.assertEqual(sample.fournisseur, supplier)

    def test_same_supplier_name_in_two_locations_creates_two_suppliers(self):
        self.authenticate(self.collector)

        first = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'HAMI-GB',
                'fournisseur_nom': 'hami',
                'gouvernorat': 'Gabes',
                'delegation': 'El Hamma',
            },
            format='json',
        )
        second = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'HAMI-SF',
                'fournisseur_nom': 'hami',
                'gouvernorat': 'Sfax',
                'delegation': 'Sakiet Ezzit',
            },
            format='json',
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Fournisseur.objects.filter(nom__iexact='hami').count(), 2)
        self.assertNotEqual(
            Echantillon.objects.get(id=first.data['id']).fournisseur_id,
            Echantillon.objects.get(id=second.data['id']).fournisseur_id,
        )

    def test_same_supplier_name_same_location_reuses_supplier(self):
        self.authenticate(self.collector)

        for ref in ('HAMI-1', 'HAMI-2'):
            response = self.client.post(
                '/api/echantillons/',
                {
                    'reference_bouteille': ref,
                    'fournisseur_nom': 'hami',
                    'gouvernorat': 'Gabes',
                    'delegation': 'El Hamma',
                },
                format='json',
            )
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        self.assertEqual(Fournisseur.objects.filter(nom__iexact='hami').count(), 1)

    def test_update_supplier_location_relinks_to_matching_supplier(self):
        sfax_supplier = Fournisseur.objects.create(
            nom='hami',
            region='Sfax',
            delegation='Sakiet Ezzit',
        )
        gabes_supplier = Fournisseur.objects.create(
            nom='hami',
            region='Gabes',
            delegation='El Hamma',
        )
        sample = self.create_sample(
            self.collector,
            reference_bouteille='HAMI-MOVE',
            fournisseur=sfax_supplier,
            gouvernorat='Sfax',
            delegation='Sakiet Ezzit',
        )
        self.authenticate(self.collector)

        response = self.client.patch(
            f'/api/echantillons/{sample.id}/',
            {
                'fournisseur_nom': 'hami',
                'gouvernorat': 'Gabes',
                'delegation': 'El Hamma',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertEqual(sample.fournisseur, gabes_supplier)

    def test_collector_sample_without_supplier_name_is_accepted(self):
        self.authenticate(self.collector)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'SANS-FOURNISSEUR',
                'gouvernorat': 'Sfax',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertIsNone(sample.fournisseur)

    def test_direction_cannot_create_collector_sample(self):
        self.authenticate(self.direction)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'DIR-001',
                'gouvernorat': 'Sfax',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_degustateur_can_create_sample_without_collecteur_owner(self):
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'DEG-001',
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
                'variete': 'Chemlali',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertIsNone(sample.collecteur)
        self.assertEqual(
            sample.statut_collecteur,
            Echantillon.StatutCollecteur.RECEPTIONNE,
        )

    def test_degustateur_can_create_sample_with_flutter_payload_and_collecteur(self):
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'DEG-FORM-001',
                'fournisseur_nom': 'Domaine Formulaire',
                'collecteur': str(self.collector.id),
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
                'cite': '',
                'num_citerne': 'C1',
                'quantite_estimee': '12',
                'variete': 'Chemlali',
                'remarques': '',
                'image_url': '',
                'statut_collecteur': 'receptionne',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertEqual(sample.collecteur, self.collector)
        self.assertEqual(sample.fournisseur.nom, 'Domaine Formulaire')

    def test_chef_can_create_sample_without_collecteur_owner(self):
        self.authenticate(self.chef)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'CHEF-001',
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
                'variete': 'Chemlali',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertIsNone(sample.collecteur)
        self.assertEqual(
            sample.statut_collecteur,
            Echantillon.StatutCollecteur.RECEPTIONNE,
        )

    def test_chef_can_create_sample_with_flutter_payload_and_collecteur(self):
        self.authenticate(self.chef)

        response = self.client.post(
            '/api/echantillons/',
            {
                'reference_bouteille': 'CHEF-FORM-001',
                'fournisseur_nom': 'Domaine Chef',
                'collecteur': str(self.collector.id),
                'gouvernorat': 'Sfax',
                'delegation': 'Sfax Sud',
                'cite': '',
                'num_citerne': 'C2',
                'quantite_estimee': '15',
                'variete': 'Chetoui',
                'remarques': '',
                'image_url': '',
                'statut_collecteur': 'receptionne',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sample = Echantillon.objects.get(id=response.data['id'])
        self.assertEqual(sample.collecteur, self.collector)
        self.assertEqual(sample.fournisseur.nom, 'Domaine Chef')

    def test_chef_can_update_sample(self):
        sample = self.create_sample(self.collector)
        self.authenticate(self.chef)

        response = self.client.patch(
            f'/api/echantillons/{sample.id}/',
            {'variete': 'Chetoui'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertEqual(sample.variete, 'Chetoui')

    def test_degustateur_cannot_delete_collector_sample(self):
        sample = self.create_sample(self.collector)
        self.authenticate(self.degustateur)

        response = self.client.delete(f'/api/echantillons/{sample.id}/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(
            response.data['detail'],
            'Impossible de supprimer un echantillon enregistre par un collecteur.',
        )
        self.assertTrue(Echantillon.objects.filter(id=sample.id).exists())

    def test_degustateur_can_delete_sample_without_collecteur_owner(self):
        sample = Echantillon.objects.create(
            reference_bouteille='DEG-DEL-001',
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
        )
        self.authenticate(self.degustateur)

        response = self.client.delete(f'/api/echantillons/{sample.id}/')

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Echantillon.objects.filter(id=sample.id).exists())

    def test_delete_blocked_after_physical_reception(self):
        sample = self.create_sample(
            self.collector,
            recu_physiquement=True,
            date_reception_echantillon=timezone.now(),
        )
        self.authenticate(self.collector)

        response = self.client.delete(f'/api/echantillons/{sample.id}/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Echantillon.objects.filter(id=sample.id).exists())

    def test_collector_purchase_action_submits_proposal_only_when_in_negotiation(self):
        sample = self.create_sample(
            self.collector,
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
            quantite_cible_t='40',
        )
        self.authenticate(self.collector)
        Notification.objects.all().delete()

        response = self.client.post(
            f'/api/echantillons/{sample.id}/confirmer-achat/',
            {'prix_final': '14.50 TND/L', 'camion_reserve': 'TU-1234'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertEqual(sample.statut_collecteur, Echantillon.StatutCollecteur.EN_NEGOCIATION)
        self.assertEqual(sample.statut_ceo, Echantillon.StatutCEO.EN_NEGOCIATION)
        self.assertEqual(str(sample.budget_negociation), '14.50')
        self.assertEqual(str(sample.prix_final), '14.50')
        notification = Notification.objects.get(
            destinataire=self.direction,
            type=Notification.Type.PROPOSITION_ACHAT_ATTENTE,
        )
        self.assertEqual(notification.section, Notification.Section.ACHATS_VALIDATION)
        self.assertEqual(notification.echantillon, sample)

    def test_collector_purchase_remark_is_stored_and_reloaded(self):
        sample = self.create_sample(
            self.collector,
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
        )
        self.authenticate(self.collector)

        response = self.client.post(
            f'/api/echantillons/{sample.id}/confirmer-achat/',
            {
                'prix_final': '8000',
                'remarque_collecteur': 'Livraison possible en deux camions.',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data['remarque_collecteur'],
            'Livraison possible en deux camions.',
        )
        sample.refresh_from_db()
        self.assertEqual(
            sample.remarque_collecteur,
            'Livraison possible en deux camions.',
        )

        reloaded = self.client.get(f'/api/echantillons/{sample.id}/')

        self.assertEqual(reloaded.status_code, status.HTTP_200_OK)
        self.assertEqual(
            reloaded.data['remarque_collecteur'],
            'Livraison possible en deux camions.',
        )

    def test_direction_lists_purchase_proposals_awaiting_validation(self):
        awaiting = self.create_sample(
            self.collector,
            reference_bouteille='PROP-A',
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
            budget_negociation='8.20',
        )
        self.create_sample(
            self.collector,
            reference_bouteille='NEGOTIATION-ONLY',
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
        )
        self.create_sample(
            self.collector,
            reference_bouteille='REFUSED-PROP',
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.REFUSE,
            budget_negociation='8.00',
        )
        self.authenticate(self.direction)

        response = self.client.get('/api/echantillons/?statut=en_negociation&proposition_soumise=true')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertEqual(ids, {str(awaiting.id)})

    def test_direction_lists_decided_purchase_proposals(self):
        confirmed = self.create_sample(
            self.collector,
            statut_collecteur=Echantillon.StatutCollecteur.ACHAT_CONFIRME,
            statut_ceo=Echantillon.StatutCEO.ACHAT_CONFIRME,
        )
        refused = self.create_sample(
            self.collector,
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.REFUSE,
            raison_refus='Prix trop eleve',
        )
        self.create_sample(self.collector)
        self.authenticate(self.direction)

        response = self.client.get('/api/echantillons/?statut__in=achat_confirme,refuse')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertEqual(ids, {str(confirmed.id), str(refused.id)})

    def test_recherche_matches_each_word_across_sample_and_supplier_fields(self):
        supplier = Fournisseur.objects.create(
            nom='Domaine Hami',
            region='Gabes',
            delegation='El Hamma',
        )
        matching = self.create_sample(
            self.collector,
            reference_bouteille='HAM-001',
            fournisseur=supplier,
            gouvernorat='Gabes',
            delegation='El Hamma',
            variete='Chemlali',
            num_citerne='4h',
        )
        self.create_sample(
            self.collector,
            reference_bouteille='HAM-002',
            fournisseur=supplier,
            gouvernorat='Gabes',
            delegation='El Hamma',
            variete='Chetoui',
            num_citerne='7',
        )
        self.authenticate(self.collector)

        response = self.client.get('/api/echantillons/?recherche=hami chemlali 4h')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertEqual(ids, {str(matching.id)})

    def test_recherche_limite_and_orders_most_recent_first(self):
        old = self.create_sample(self.collector, reference_bouteille='RECENT-OLD')
        middle = self.create_sample(self.collector, reference_bouteille='RECENT-MIDDLE')
        newest = self.create_sample(self.collector, reference_bouteille='RECENT-NEW')
        Echantillon.objects.filter(id=old.id).update(
            date_ajout=timezone.now() - timedelta(days=3)
        )
        Echantillon.objects.filter(id=middle.id).update(
            date_ajout=timezone.now() - timedelta(days=2)
        )
        Echantillon.objects.filter(id=newest.id).update(
            date_ajout=timezone.now() - timedelta(days=1)
        )
        self.authenticate(self.collector)

        response = self.client.get('/api/echantillons/?recherche=RECENT&limite=2')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [item['id'] for item in self.results(response)]
        self.assertEqual(ids, [str(newest.id), str(middle.id)])

    def test_recherche_keeps_collector_isolation(self):
        own = self.create_sample(self.collector, reference_bouteille='SECRET-OWN')
        self.create_sample(self.other_collector, reference_bouteille='SECRET-OTHER')
        self.authenticate(self.collector)

        response = self.client.get('/api/echantillons/?recherche=SECRET&limite=15')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertEqual(ids, {str(own.id)})

    def test_degustateur_and_chef_list_samples_from_all_collectors_for_variety_suggestions(self):
        own = self.create_sample(
            self.collector,
            reference_bouteille='VAR-A',
            variete='Chemlali',
        )
        other = self.create_sample(
            self.other_collector,
            reference_bouteille='VAR-B',
            variete='Chetoui',
        )

        self.authenticate(self.degustateur)
        degustateur_response = self.client.get('/api/echantillons/')
        self.assertEqual(degustateur_response.status_code, status.HTTP_200_OK)
        degustateur_ids = {item['id'] for item in self.results(degustateur_response)}
        self.assertIn(str(own.id), degustateur_ids)
        self.assertIn(str(other.id), degustateur_ids)

        self.authenticate(self.chef)
        chef_response = self.client.get('/api/echantillons/')
        self.assertEqual(chef_response.status_code, status.HTTP_200_OK)
        chef_ids = {item['id'] for item in self.results(chef_response)}
        self.assertIn(str(own.id), chef_ids)
        self.assertIn(str(other.id), chef_ids)

    def test_direction_confirms_purchase_proposal(self):
        sample = self.create_sample(
            self.collector,
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
            budget_negociation='8.20',
        )
        self.authenticate(self.direction)
        Notification.objects.all().delete()

        response = self.client.post(f'/api/echantillons/{sample.id}/confirmer-achat/', {}, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertEqual(sample.statut_collecteur, Echantillon.StatutCollecteur.ACHAT_CONFIRME)
        self.assertEqual(sample.statut_ceo, Echantillon.StatutCEO.ACHAT_CONFIRME)
        self.assertFalse(sample.stock_arrive)
        self.assertTrue(
            Notification.objects.filter(
                destinataire=self.direction,
                type=Notification.Type.ACHAT_CONFIRME,
                echantillon=sample,
            ).exists()
        )

    def test_direction_refuses_purchase_proposal_with_reason(self):
        sample = self.create_sample(
            self.collector,
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
            budget_negociation='8.20',
        )
        self.authenticate(self.direction)

        response = self.client.post(
            f'/api/echantillons/{sample.id}/refuser-achat/',
            {'raison_refus': 'Prix trop eleve'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertEqual(sample.statut_ceo, Echantillon.StatutCEO.REFUSE)
        self.assertEqual(sample.raison_refus, 'Prix trop eleve')

    def test_degustateur_can_confirm_physical_reception(self):
        sample = self.create_sample(self.collector, recu_physiquement=False)
        self.authenticate(self.degustateur)

        response = self.client.post(
            f'/api/echantillons/{sample.id}/confirmer-reception/',
            {},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertTrue(sample.recu_physiquement)
        self.assertIsNotNone(sample.date_reception_echantillon)

    def test_degustateur_can_cancel_physical_reception(self):
        sample = self.create_sample(
            self.collector,
            recu_physiquement=True,
            date_reception_echantillon=timezone.now(),
        )
        self.authenticate(self.degustateur)

        response = self.client.patch(
            f'/api/echantillons/{sample.id}/annuler-reception/',
            {},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertFalse(sample.recu_physiquement)
        self.assertIsNone(sample.date_reception_echantillon)
        self.assertFalse(response.data['recu_physiquement'])
        self.assertIsNone(response.data['date_reception_echantillon'])

    def test_physical_reception_preserves_scheduled_arrival_date(self):
        scheduled_arrival = timezone.now() + timedelta(days=3)
        sample = self.create_sample(
            self.collector,
            recu_physiquement=False,
            date_arrivee_echantillon=scheduled_arrival,
        )
        self.authenticate(self.degustateur)

        response = self.client.post(
            f'/api/echantillons/{sample.id}/confirmer-reception/',
            {},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sample.refresh_from_db()
        self.assertEqual(sample.date_arrivee_echantillon, scheduled_arrival)
        self.assertIsNotNone(sample.date_reception_echantillon)
        self.assertEqual(
            parse_datetime(response.data['date_arrivee_echantillon']),
            scheduled_arrival,
        )
        self.assertIsNotNone(response.data['date_reception_echantillon'])

    def test_direction_approval_notifies_collector_of_negotiation_proposal(self):
        sample = self.create_sample(self.collector, reference_bouteille='APPROVE-001')
        self.authenticate(self.direction)
        Notification.objects.all().delete()

        response = self.client.patch(
            f'/api/echantillons/{sample.id}/approuver/',
            {'budget_negociation': '8.20', 'quantite_cible_t': '12'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        notification = Notification.objects.get(
            destinataire=self.collector,
            type=Notification.Type.NEGOCIATION_PROPOSEE,
        )
        self.assertEqual(notification.section, Notification.Section.ACHATS_VALIDATION)
        self.assertEqual(notification.echantillon, sample)
        self.assertIn('APPROVE-001', notification.message)
        self.assertIn('8.2', notification.message)
        self.assertIn('12', notification.message)

    def test_direction_approval_notifies_collector_of_negotiation_update(self):
        sample = self.create_sample(
            self.collector,
            reference_bouteille='APPROVE-002',
            budget_negociation='8.20',
            quantite_cible_t='12',
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
        )
        self.authenticate(self.direction)
        Notification.objects.all().delete()

        response = self.client.patch(
            f'/api/echantillons/{sample.id}/approuver/',
            {'budget_negociation': '8.50', 'quantite_cible_t': '14'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        notification = Notification.objects.get(
            destinataire=self.collector,
            type=Notification.Type.NEGOCIATION_MISE_A_JOUR,
        )
        self.assertEqual(notification.section, Notification.Section.ACHATS_VALIDATION)
        self.assertEqual(notification.echantillon, sample)
        self.assertIn('APPROVE-002', notification.message)
        self.assertIn('8.5', notification.message)
        self.assertIn('14', notification.message)


class RenvoiEnNegociationTests(APITestCase):
    """
    Refus scinde : la direction refuse le PRIX sans tuer le stock.

    L'echantillon garde son statut « en negociation » ; ce qui change, c'est la
    contre-proposition et le compteur de tours (PR CEO, partie 3).
    """

    def setUp(self):
        self.collecteur = User.objects.create_user(
            email='collecteur.renego@example.com', password='Test@12345',
            nom='Collecteur', prenom='Renego', role=User.Role.COLLECTEUR,
        )
        self.direction = User.objects.create_user(
            email='direction.renego@example.com', password='Test@12345',
            nom='Direction', prenom='Renego', role=User.Role.DIRECTION,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='RENEGO-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            statut_ceo=Echantillon.StatutCEO.EN_NEGOCIATION,
            statut_collecteur=Echantillon.StatutCollecteur.EN_NEGOCIATION,
            budget_negociation='8.00',
        )
        self.url = f'/api/echantillons/{self.sample.id}/renvoyer-en-negociation/'

    def renvoyer(self, **champs):
        payload = {'raison_refus': 'Prix trop eleve', 'budget_negociation': '7.00'}
        payload.update(champs)
        return self.client.post(self.url, payload, format='json')

    def test_direction_renvoie_avec_un_prix_ferme(self):
        self.client.force_authenticate(user=self.direction)
        response = self.renvoyer()
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.sample.refresh_from_db()
        self.assertEqual(str(self.sample.budget_negociation), '7.00')
        self.assertIsNone(self.sample.budget_negociation_max)
        self.assertEqual(self.sample.nb_renegociations, 1)
        # Le statut ne bouge pas : c'est tout l'interet du refus scinde.
        self.assertEqual(self.sample.statut_ceo, Echantillon.StatutCEO.EN_NEGOCIATION)

    def test_intervalle_de_prix_et_details(self):
        self.client.force_authenticate(user=self.direction)
        response = self.renvoyer(
            budget_negociation='7.00',
            budget_negociation_max='7.40',
            quantite_cible_t='28',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.sample.refresh_from_db()
        self.assertEqual(str(self.sample.budget_negociation_max), '7.40')
        self.assertEqual(str(self.sample.quantite_cible_t), '28.00')

    def test_compteur_s_incremente_a_chaque_tour(self):
        self.client.force_authenticate(user=self.direction)
        for attendu in (1, 2, 3):
            self.renvoyer()
            self.sample.refresh_from_db()
            self.assertEqual(self.sample.nb_renegociations, attendu)

    def test_le_collecteur_est_notifie(self):
        self.client.force_authenticate(user=self.direction)
        self.renvoyer(budget_negociation='7.00', budget_negociation_max='7.40')

        notif = Notification.objects.filter(
            destinataire=self.collecteur,
            type=Notification.Type.NEGOCIATION_A_REVOIR,
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn('RENEGO-001', notif.message)
        self.assertIn('7', notif.message)

    def test_raison_obligatoire(self):
        self.client.force_authenticate(user=self.direction)
        response = self.renvoyer(raison_refus='   ')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('raison_refus', response.json())

    def test_contre_prix_obligatoire(self):
        self.client.force_authenticate(user=self.direction)
        response = self.client.post(
            self.url, {'raison_refus': 'Prix trop eleve'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('budget_negociation', response.json())

    def test_prix_haut_inferieur_au_prix_bas_refuse(self):
        self.client.force_authenticate(user=self.direction)
        response = self.renvoyer(budget_negociation='7.50', budget_negociation_max='7.00')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('budget_negociation_max', response.json())

    def test_refuse_si_aucune_proposition_en_attente(self):
        self.sample.statut_ceo = Echantillon.StatutCEO.SELECTIONNE
        self.sample.save(update_fields=['statut_ceo'])
        self.client.force_authenticate(user=self.direction)
        response = self.renvoyer()
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_le_collecteur_ne_peut_pas_renvoyer(self):
        self.client.force_authenticate(user=self.collecteur)
        response = self.renvoyer()
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_le_compteur_n_est_pas_modifiable_par_le_client(self):
        self.client.force_authenticate(user=self.direction)
        self.client.patch(
            f'/api/echantillons/{self.sample.id}/',
            {'nb_renegociations': 99}, format='json',
        )
        self.sample.refresh_from_db()
        self.assertEqual(self.sample.nb_renegociations, 0)


class PhotoModificationTests(APITestCase):
    """A bottle photo can be replaced when a sample is edited, not only created."""

    def setUp(self):
        import tempfile

        from django.test import override_settings

        self._media = override_settings(MEDIA_ROOT=tempfile.mkdtemp())
        self._media.enable()
        self.degustateur = User.objects.create_user(
            email='photo-deg@test.com',
            password='Test@12345',
            nom='Photo',
            prenom='Deg',
            role=User.Role.DEGUSTATEUR,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='PHOTO-001',
            gouvernorat='Sfax',
            # Enregistre par ce degustateur et pas encore recu : il a le droit
            # de le modifier (tache 59).
            enregistre_par=self.degustateur,
            recu_physiquement=False,
        )

    def tearDown(self):
        self._media.disable()

    def test_patch_multipart_remplace_la_photo(self):
        from django.core.files.uploadedfile import SimpleUploadedFile

        self.client.force_authenticate(user=self.degustateur)
        photo = SimpleUploadedFile('bouteille.jpg', b'\xff\xd8\xff\xe0fake', content_type='image/jpeg')
        response = self.client.patch(
            f'/api/echantillons/{self.sample.id}/',
            {'image': photo, 'reference_bouteille': 'PHOTO-001'},
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.sample.refresh_from_db()
        self.assertIn('echantillons/', self.sample.image_url)


class ModificationChampsVidesTests(APITestCase):
    """L'application envoie null pour les champs texte vides : la modification doit passer."""

    def setUp(self):
        self.chef = User.objects.create_user(
            email='modif.chef@example.com',
            password='Test@12345',
            nom='Chef',
            prenom='Modif',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='REF-1',
            gouvernorat='Sfax',
            image_url='/media/echantillons/ancienne.jpg',
        )

    def test_modification_avec_champs_null(self):
        self.client.force_authenticate(user=self.chef)
        response = self.client.patch(
            f'/api/echantillons/{self.sample.id}/',
            {
                'gouvernorat': 'Sfax',
                'delegation': None,
                'cite': None,
                'reference_bouteille': 'REF-1',
                'num_citerne': None,
                'quantite_estimee': None,
                'variete': None,
                'remarques': None,
                'image_url': None,
                'statut_collecteur': self.sample.statut_collecteur,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.sample.refresh_from_db()
        self.assertEqual(self.sample.delegation, '')
        # image_url null ne doit pas effacer la photo existante.
        self.assertEqual(self.sample.image_url, '/media/echantillons/ancienne.jpg')


class DroitsModificationDegustateursTests(APITestCase):
    """Le chef modifie tout ; un degustateur seulement ses echantillons non recus."""

    def setUp(self):
        def creer(email, role):
            return User.objects.create_user(
                email=email, password='Test@12345', nom='N', prenom='P', role=role,
            )

        self.chef = creer('droits.chef@example.com', User.Role.CHEF_DEGUSTATION)
        self.deg_a = creer('droits.a@example.com', User.Role.DEGUSTATEUR)
        self.deg_b = creer('droits.b@example.com', User.Role.DEGUSTATEUR)

    def _creer(self, user):
        self.client.force_authenticate(user=user)
        response = self.client.post(
            '/api/echantillons/',
            {'reference_bouteille': 'REF-D', 'gouvernorat': 'Sfax'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        return Echantillon.objects.get(pk=response.data['id'])

    def _modifier(self, user, sample):
        self.client.force_authenticate(user=user)
        return self.client.patch(
            f'/api/echantillons/{sample.id}/', {'variete': 'Chemlali'}, format='json',
        )

    def test_enregistre_par_est_rempli(self):
        sample = self._creer(self.deg_a)
        self.assertEqual(sample.enregistre_par, self.deg_a)

    def test_degustateur_modifie_le_sien_avant_reception(self):
        sample = self._creer(self.deg_a)
        sample.recu_physiquement = False
        sample.save(update_fields=['recu_physiquement'])
        response = self._modifier(self.deg_a, sample)
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertTrue(response.data['modifiable'])

    def test_degustateur_ne_modifie_pas_celui_d_un_autre(self):
        sample = self._creer(self.deg_b)
        sample.recu_physiquement = False
        sample.save(update_fields=['recu_physiquement'])
        response = self._modifier(self.deg_a, sample)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_degustateur_ne_modifie_plus_apres_reception(self):
        sample = self._creer(self.deg_a)
        sample.recu_physiquement = True
        sample.save(update_fields=['recu_physiquement'])
        response = self._modifier(self.deg_a, sample)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_chef_modifie_tout(self):
        sample = self._creer(self.deg_b)
        sample.recu_physiquement = True
        sample.save(update_fields=['recu_physiquement'])
        response = self._modifier(self.chef, sample)
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertTrue(response.data['modifiable'])
