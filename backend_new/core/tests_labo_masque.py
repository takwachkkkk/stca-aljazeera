from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from notifications.models import Notification
from notifications.signals import _get_users_by_roles
from users.models import User


class LaboMasqueTests(APITestCase):
    """LABO_ACTIF vaut False par defaut : le role labo disparait sans rien supprimer."""

    @classmethod
    def setUpTestData(cls):
        cls.direction = cls._user('direction@masque.test', User.Role.DIRECTION)
        cls.chef = cls._user('chef@masque.test', User.Role.CHEF_DEGUSTATION)
        cls.labo = cls._user('labo@masque.test', User.Role.LABORATOIRE)

    @staticmethod
    def _user(email, role):
        return User.objects.create_user(
            email=email,
            password='Test@12345',
            nom='Masque',
            prenom='Test',
            role=role,
        )

    def _login_labo(self):
        return self.client.post(
            '/api/auth/login/',
            {'email': self.labo.email, 'password': 'Test@12345'},
            format='json',
        )

    def test_un_compte_labo_ne_peut_plus_se_connecter(self):
        response = self._login_labo()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertNotIn('access', response.data)

    def test_une_session_labo_deja_ouverte_est_bloquee(self):
        self.client.force_authenticate(self.labo)

        for route in ('/api/analyses/', '/api/analyses/echantillons/', '/api/echantillons/'):
            response = self.client.get(route)
            self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN, route)

    def test_le_compte_labo_reste_en_base(self):
        self.assertTrue(User.objects.filter(pk=self.labo.pk, is_active=True).exists())

    def test_la_liste_des_utilisateurs_ne_montre_pas_le_labo(self):
        self.client.force_authenticate(self.direction)

        response = self.client.get('/api/users/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        items = response.data['results'] if isinstance(response.data, dict) else response.data
        emails = {item['email'] for item in items}
        self.assertIn(self.chef.email, emails)
        self.assertNotIn(self.labo.email, emails)

    def test_on_ne_peut_plus_creer_de_compte_labo(self):
        self.client.force_authenticate(self.chef)

        response = self.client.post(
            '/api/users/',
            {
                'email': 'nouveau.labo@masque.test',
                'nom': 'Nouveau',
                'prenom': 'Labo',
                'role': User.Role.LABORATOIRE,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(User.objects.filter(email='nouveau.labo@masque.test').exists())

    def test_le_labo_ne_recoit_plus_de_notification(self):
        destinataires = _get_users_by_roles(User.Role.LABORATOIRE, User.Role.DIRECTION)

        self.assertEqual(list(destinataires), [self.direction])

    def test_les_anciennes_notifications_labo_sont_cachees_sans_etre_supprimees(self):
        Notification.objects.all().delete()
        for section, titre in (
            (Notification.Section.ANALYSES, 'Analyse soumise'),
            (Notification.Section.ECHANTILLONS, 'Nouvel echantillon'),
        ):
            Notification.objects.create(
                destinataire=self.direction,
                type=Notification.Type.ANALYSE_SOUMISE,
                titre=titre,
                message=titre,
                section=section,
            )
        self.client.force_authenticate(self.direction)

        liste = self.client.get('/api/notifications/')
        compte = self.client.get('/api/notifications/unread-count/')

        items = liste.data['results'] if isinstance(liste.data, dict) else liste.data
        self.assertEqual([item['titre'] for item in items], ['Nouvel echantillon'])
        self.assertEqual(compte.data['count'], 1)
        self.assertEqual(Notification.objects.count(), 2)

    def test_la_demande_d_analyse_urgente_est_indisponible(self):
        self.client.force_authenticate(self.chef)

        response = self.client.post('/api/notifications/analyse-urgente/', {}, format='json')

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    @override_settings(LABO_ACTIF=True)
    def test_reactiver_le_labo_rend_la_connexion(self):
        response = self._login_labo()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
