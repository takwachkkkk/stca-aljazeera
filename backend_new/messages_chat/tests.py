from pathlib import Path
import shutil

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from echantillons.models import Echantillon
from fournisseurs.models import Fournisseur
from users.models import User

from .models import Message


TEST_MEDIA_ROOT = Path(__file__).resolve().parent / 'test_media'


@override_settings(MEDIA_ROOT=TEST_MEDIA_ROOT)
class MessageApiTests(APITestCase):
    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(TEST_MEDIA_ROOT, ignore_errors=True)

    def setUp(self):
        self.sender = User.objects.create_user(
            email='sender.messages@example.com',
            password='Test@12345',
            nom='Sender',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.recipient = User.objects.create_user(
            email='recipient.messages@example.com',
            password='Test@12345',
            nom='Recipient',
            prenom='User',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.other_chef = User.objects.create_user(
            email='other.chef.messages@example.com',
            password='Test@12345',
            nom='OtherChef',
            prenom='User',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.other = User.objects.create_user(
            email='other.messages@example.com',
            password='Test@12345',
            nom='Other',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.direction = User.objects.create_user(
            email='direction.messages@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.other_direction = User.objects.create_user(
            email='other.direction.messages@example.com',
            password='Test@12345',
            nom='OtherDirection',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.degustateur = User.objects.create_user(
            email='degustateur.messages@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='User',
            role=User.Role.DEGUSTATEUR,
        )
        self.laboratoire = User.objects.create_user(
            email='labo.messages@example.com',
            password='Test@12345',
            nom='Labo',
            prenom='User',
            role=User.Role.LABORATOIRE,
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def create_sample(self, **extra):
        data = {
            'reference_bouteille': 'REF-MSG-001',
            'collecteur': self.sender,
            'gouvernorat': 'Sfax',
            'delegation': 'Sfax Sud',
            'variete': 'Chemlali',
        }
        data.update(extra)
        return Echantillon.objects.create(**data)

    def test_user_can_send_message_and_sender_is_forced_from_token(self):
        self.authenticate(self.sender)

        response = self.client.post(
            '/api/messages/',
            {
                'expediteur': str(self.other.id),
                'destinataire': str(self.direction.id),
                'contenu': 'Bonjour',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        message = Message.objects.get(id=response.json()['id'])
        self.assertEqual(message.expediteur, self.sender)
        self.assertEqual(message.destinataire, self.direction)
        self.assertFalse(message.lu)

    def test_user_can_send_message_with_photo(self):
        self.authenticate(self.sender)
        image = SimpleUploadedFile(
            'message.jpg',
            b'fake-image-content',
            content_type='image/jpeg',
        )

        response = self.client.post(
            '/api/messages/',
            {
                'destinataire': str(self.direction.id),
                'contenu': '',
                'image': image,
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.json()
        self.assertIn('messages/', data['photo_url'])
        message = Message.objects.get(id=data['id'])
        self.assertIn('messages/', message.photo_url)
        self.assertEqual(message.contenu, '')

    def test_user_can_send_message_with_sample_reference(self):
        fournisseur = Fournisseur.objects.create(nom='Domaine Message')
        sample = self.create_sample(
            reference_bouteille='REF-MSG-777',
            fournisseur=fournisseur,
        )
        self.authenticate(self.sender)

        response = self.client.post(
            '/api/messages/',
            {
                'destinataire': str(self.direction.id),
                'contenu': 'Voir cet echantillon',
                'echantillon': str(sample.id),
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.json()
        self.assertEqual(data['echantillon'], str(sample.id))
        self.assertEqual(data['echantillon_numero'], sample.numero)
        self.assertEqual(data['echantillon_reference_bouteille'], 'REF-MSG-777')
        self.assertEqual(data['echantillon_fournisseur_nom'], 'Domaine Message')

    def test_cannot_send_empty_message_without_photo(self):
        self.authenticate(self.sender)

        response = self.client.post(
            '/api/messages/',
            {
                'destinataire': str(self.direction.id),
                'contenu': '   ',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('texte ou une photo', str(response.json()))

    def test_user_lists_only_sent_or_received_messages(self):
        own_sent = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='Sent',
        )
        own_received = Message.objects.create(
            expediteur=self.recipient,
            destinataire=self.sender,
            contenu='Received',
        )
        Message.objects.create(
            expediteur=self.recipient,
            destinataire=self.other,
            contenu='Hidden',
        )
        self.authenticate(self.sender)

        response = self.client.get('/api/messages/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.json().get('results', response.json())
        ids = {item['id'] for item in results}
        self.assertEqual(ids, {str(own_sent.id), str(own_received.id)})
        self.assertIn('is_read', results[0])
        self.assertIn('horodatage', results[0])

    def test_only_recipient_can_mark_message_as_read(self):
        message = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='A lire',
        )

        self.authenticate(self.sender)
        sender_response = self.client.patch(f'/api/messages/{message.id}/lire/')
        self.assertEqual(sender_response.status_code, status.HTTP_404_NOT_FOUND)

        self.authenticate(self.recipient)
        recipient_response = self.client.patch(f'/api/messages/{message.id}/lire/')

        self.assertEqual(recipient_response.status_code, status.HTTP_200_OK)
        message.refresh_from_db()
        self.assertTrue(message.lu)
        self.assertIsNotNone(message.lu_le)
        self.assertTrue(recipient_response.json()['is_read'])

    def test_sender_can_update_message_content(self):
        message = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='Ancien texte',
        )
        self.authenticate(self.sender)

        response = self.client.patch(
            f'/api/messages/{message.id}/',
            {'contenu': 'Nouveau texte'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        message.refresh_from_db()
        self.assertEqual(message.contenu, 'Nouveau texte')
        self.assertTrue(message.modifie)
        self.assertIsNotNone(message.modifie_le)
        self.assertTrue(response.json()['modifie'])
        self.assertIsNotNone(response.json()['modifie_le'])

    def test_recipient_cannot_update_message_content(self):
        message = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='Ancien texte',
        )
        self.authenticate(self.recipient)

        response = self.client.patch(
            f'/api/messages/{message.id}/',
            {'contenu': 'Modification interdite'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        message.refresh_from_db()
        self.assertEqual(message.contenu, 'Ancien texte')
        self.assertFalse(message.modifie)

    def test_sender_cannot_update_recipient_or_sample_reference(self):
        sample = self.create_sample(reference_bouteille='REF-MSG-888')
        message = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='Texte',
        )
        self.authenticate(self.sender)

        recipient_response = self.client.patch(
            f'/api/messages/{message.id}/',
            {'destinataire': str(self.direction.id)},
            format='json',
        )
        sample_response = self.client.patch(
            f'/api/messages/{message.id}/',
            {'echantillon': str(sample.id)},
            format='json',
        )

        self.assertEqual(recipient_response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(sample_response.status_code, status.HTTP_400_BAD_REQUEST)
        message.refresh_from_db()
        self.assertEqual(message.destinataire, self.recipient)
        self.assertIsNone(message.echantillon)

    def test_sender_can_delete_own_message(self):
        message = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='A supprimer',
        )
        self.authenticate(self.sender)

        response = self.client.delete(f'/api/messages/{message.id}/')

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Message.objects.filter(id=message.id).exists())

    def test_recipient_cannot_delete_received_message(self):
        message = Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='A conserver',
        )
        self.authenticate(self.recipient)

        response = self.client.delete(f'/api/messages/{message.id}/')

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Message.objects.filter(id=message.id).exists())

    def test_cannot_send_message_to_self(self):
        self.authenticate(self.sender)

        response = self.client.post(
            '/api/messages/',
            {
                'destinataire': str(self.sender.id),
                'contenu': 'Moi-meme',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_chef_cannot_send_message_to_self(self):
        self.authenticate(self.recipient)

        response = self.client.post(
            '/api/messages/',
            {
                'destinataire': str(self.recipient.id),
                'contenu': 'Moi-meme',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_allowed_contact_matrix_can_send_messages(self):
        scenarios = [
            (self.sender, self.recipient),
            (self.sender, self.direction),
            (self.recipient, self.sender),
            (self.recipient, self.direction),
            (self.recipient, self.other_chef),
            (self.other_chef, self.recipient),
            (self.direction, self.sender),
            (self.direction, self.recipient),
        ]

        for expediteur, destinataire in scenarios:
            with self.subTest(expediteur=expediteur.role, destinataire=destinataire.role):
                self.authenticate(expediteur)
                response = self.client.post(
                    '/api/messages/',
                    {
                        'destinataire': str(destinataire.id),
                        'contenu': 'Bonjour',
                    },
                    format='json',
                )

                self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_roles_without_messaging_cannot_send_messages(self):
        for expediteur in (self.degustateur, self.laboratoire):
            with self.subTest(role=expediteur.role):
                self.authenticate(expediteur)
                response = self.client.post(
                    '/api/messages/',
                    {
                        'destinataire': str(self.direction.id),
                        'contenu': 'Bonjour',
                    },
                    format='json',
                )

                self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
                self.assertIn("Vous n'avez pas de messagerie.", str(response.json()))

    def test_collector_cannot_send_message_to_another_collector(self):
        self.authenticate(self.sender)

        response = self.client.post(
            '/api/messages/',
            {
                'destinataire': str(self.other.id),
                'contenu': 'Bonjour',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Vous ne pouvez pas ecrire a ce contact.', str(response.json()))

    def test_contacts_list_for_collector_and_empty_for_degustateur(self):
        inactive_direction = User.objects.create_user(
            email='inactive.direction.messages@example.com',
            password='Test@12345',
            nom='Inactive',
            prenom='User',
            role=User.Role.DIRECTION,
            is_active=False,
        )
        deleted_direction = User.objects.create_user(
            email='deleted.direction.messages@example.com',
            password='Test@12345',
            nom='Deleted',
            prenom='User',
            role=User.Role.DIRECTION,
            is_active=False,
            date_suppression=timezone.now(),
        )
        self.authenticate(self.sender)

        response = self.client.get('/api/messages/contacts/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in response.json()}
        self.assertIn(str(self.direction.id), ids)
        self.assertIn(str(self.other_direction.id), ids)
        self.assertIn(str(self.recipient.id), ids)
        self.assertIn(str(self.other_chef.id), ids)
        self.assertNotIn(str(self.other.id), ids)
        self.assertNotIn(str(self.sender.id), ids)
        self.assertNotIn(str(inactive_direction.id), ids)
        self.assertNotIn(str(deleted_direction.id), ids)
        self.assertEqual(set(response.json()[0].keys()), {'id', 'nom', 'prenom', 'role'})

        self.authenticate(self.degustateur)
        empty_response = self.client.get('/api/messages/contacts/')

        self.assertEqual(empty_response.status_code, status.HTTP_200_OK)
        self.assertEqual(empty_response.json(), [])

    def test_contacts_list_for_chef_includes_other_chefs_but_not_self(self):
        self.authenticate(self.recipient)

        response = self.client.get('/api/messages/contacts/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in response.json()}
        self.assertIn(str(self.sender.id), ids)
        self.assertIn(str(self.direction.id), ids)
        self.assertIn(str(self.other_direction.id), ids)
        self.assertIn(str(self.other_chef.id), ids)
        self.assertNotIn(str(self.recipient.id), ids)
        self.assertNotIn(str(self.degustateur.id), ids)
        self.assertNotIn(str(self.laboratoire.id), ids)

    def test_contacts_list_for_direction_does_not_include_other_direction(self):
        self.authenticate(self.direction)

        response = self.client.get('/api/messages/contacts/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in response.json()}
        self.assertIn(str(self.sender.id), ids)
        self.assertIn(str(self.other.id), ids)
        self.assertIn(str(self.recipient.id), ids)
        self.assertIn(str(self.other_chef.id), ids)
        self.assertNotIn(str(self.direction.id), ids)
        self.assertNotIn(str(self.other_direction.id), ids)

    def test_unread_count_only_counts_unread_received_messages(self):
        Message.objects.create(
            expediteur=self.recipient,
            destinataire=self.sender,
            contenu='Non lu recu',
        )
        Message.objects.create(
            expediteur=self.recipient,
            destinataire=self.sender,
            contenu='Lu recu',
            lu=True,
        )
        Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='Envoye non lu',
        )
        self.authenticate(self.sender)

        response = self.client.get('/api/messages/non-lus/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['total'], 1)
        self.assertEqual(
            [m['contenu'] for m in response.json()['derniers']],
            ['Non lu recu'],
        )

    def test_derniers_non_lus_ne_montrent_pas_les_messages_des_autres(self):
        Message.objects.create(
            expediteur=self.sender,
            destinataire=self.recipient,
            contenu='Pour le destinataire',
        )
        self.authenticate(self.sender)

        response = self.client.get('/api/messages/non-lus/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json(), {'total': 0, 'derniers': []})
