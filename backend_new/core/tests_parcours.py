import json
import re
from datetime import timedelta
from pathlib import Path

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from users.models import User


FIXTURES_ROOT = Path(__file__).resolve().parents[2] / 'test' / 'fixtures' / 'api'
PASSWORD = 'Test@12345'


@override_settings(LABO_ACTIF=True)
class ParcoursBoutEnBoutApiTests(APITestCase):
    maxDiff = None

    @classmethod
    def setUpTestData(cls):
        cls.direction = cls._user('direction@audit.test', 'direction', 'Direction', 'Audit')
        cls.collecteur = cls._user('collecteur@audit.test', 'collecteur', 'Collecteur', 'Audit')
        cls.autre_collecteur = cls._user(
            'collecteur2@audit.test',
            'collecteur',
            'Autre collecteur',
            'Audit',
        )
        cls.degustateur = cls._user('degustateur@audit.test', 'degustateur', 'Degustateur', 'Audit')
        cls.chef = cls._user('chef@audit.test', 'chef_degustation', 'Chef', 'Audit')
        cls.labo = cls._user('labo@audit.test', 'laboratoire', 'Labo', 'Audit')

    @classmethod
    def _user(cls, email, role, nom, prenom):
        return User.objects.create_user(
            email=email,
            password=PASSWORD,
            role=role,
            nom=nom,
            prenom=prenom,
            telephone='20000000',
        )

    def setUp(self):
        FIXTURES_ROOT.mkdir(parents=True, exist_ok=True)
        self.sample_id = None
        self.numero = None
        self.recu_physiquement = False

    @override_settings(DEFAULT_FILE_STORAGE='django.core.files.storage.InMemoryStorage')
    def test_parcours_reel_cable_tous_roles(self):
        sample = self._post(
            self.collecteur,
            '/api/echantillons/',
            {
                'reference_bouteille': 'AUDIT-BOUT-001',
                'fournisseur_nom': 'Domaine Audit',
                'gouvernorat': 'Sfax',
                'delegation': 'Sakiet Ezzit',
                'cite': 'Route olive',
                'variete': 'Chemlali',
                'num_citerne': 'C-47',
                'quantite_estimee': '12',
                'date_arrivee_echantillon': '2026-09-25T09:00:00Z',
                'remarques': 'Echantillon de parcours audit',
            },
            files={
                'image': SimpleUploadedFile(
                    'bouteille.jpg',
                    b'image-test',
                    content_type='image/jpeg',
                )
            },
            expected=status.HTTP_201_CREATED,
        )
        self.sample_id = sample['id']
        self.numero = sample['numero']
        self.assertRegex(self.numero, r'^\d{4}/\d{4}$')
        self._snapshot('01_creation_collecteur')

        received = self._patch(
            self.degustateur,
            f'/api/echantillons/{self.sample_id}/confirmer-reception/',
            {},
        )
        self.assertTrue(received['recu_physiquement'])
        self.assertIsNotNone(received['date_reception_echantillon'])
        self.recu_physiquement = True
        self._snapshot('02_reception_degustateur')

        session = self._post(
            self.degustateur,
            '/api/sessions/',
            {
                'titre': 'Session audit cablage',
                'date': (timezone.localdate() + timedelta(days=7)).isoformat(),
                'heure': '10:30:00',
                'lieu': 'Salle degustation',
                'notes': 'Creee par le test parcours',
                'participant_ids': [str(self.degustateur.id), str(self.chef.id)],
                'nombre_echantillons_prevus': 1,
            },
            expected=status.HTTP_201_CREATED,
        )
        self.assertEqual(session['statut'], 'en_attente_validation')
        session_id = session['id']
        approved = self._post(self.chef, f'/api/sessions/{session_id}/approuver/', {})
        self.assertEqual(approved['statut'], 'planifiee')
        self._post(self.degustateur, f'/api/sessions/{session_id}/confirmer_presence/', {})
        self._post(self.chef, f'/api/sessions/{session_id}/confirmer_presence/', {})
        self._snapshot('03_session_approuvee_presence')

        evaluation_deg = self._creer_et_soumettre_evaluation(self.degustateur, session_id, 3.2)
        evaluation_chef = self._creer_et_soumettre_evaluation(self.chef, session_id, 3.4)
        self.assertEqual(evaluation_deg['statut'], 'soumis')
        self.assertEqual(evaluation_chef['statut'], 'soumis')
        self._snapshot('04_evaluations_soumises')

        analysis = self._post(
            self.labo,
            '/api/analyses/',
            {
                'echantillon': self.sample_id,
                'numero_certificat': 'CERT-AUDIT-001',
                'numero_lot': 'LOT-AUDIT',
                'date_debut_analyse': '2026-09-26',
                'date_fin_analyse': '2026-09-27',
                'quantite_ml': 250,
                'acidite': '0.32',
                'indice_peroxyde': '5.1',
                'k232': '1.9',
                'k270': '0.12',
                'delta_k': '0.01',
                'notes': 'Analyse saisie par le parcours audit',
            },
            expected=status.HTTP_201_CREATED,
        )
        submitted_analysis = self._post(
            self.labo,
            f"/api/analyses/{analysis['id']}/soumettre/",
            {},
        )
        self.assertEqual(submitted_analysis['statut'], 'soumis')
        self._snapshot('05_analyse_labo_soumise')

        approved_sample = self._patch(
            self.direction,
            f'/api/echantillons/{self.sample_id}/approuver/',
            {
                'budget_negociation': '7.50',
                'quantite_cible_t': '11.5',
                'note_interne': 'Bon profil, ouvrir la negociation.',
            },
        )
        self.assertEqual(approved_sample['statut_collecteur'], 'en_negociation')
        # Le collecteur conclut lui-meme : plus de validation par la direction.
        confirmed = self._patch(
            self.collecteur,
            f'/api/echantillons/{self.sample_id}/confirmer-achat/',
            {
                'prix_final': '7.40',
                'remarque_collecteur': 'Prix accepte par le fournisseur.',
                'date_livraison_stock': '2026-10-02T08:00:00Z',
                'date_livraison_stock_fin': '2026-10-03T16:00:00Z',
            },
        )
        self.assertEqual(confirmed['statut_collecteur'], 'achat_confirme')
        self.assertEqual(confirmed['statut_ceo'], 'achat_confirme')
        self._snapshot('06_achat_confirme')

        message = self._post(
            self.collecteur,
            '/api/messages/',
            {
                'destinataire': str(self.direction.id),
                'contenu': 'Le stock audit sera livre selon la fenetre convenue.',
                'echantillon': self.sample_id,
            },
            expected=status.HTTP_201_CREATED,
        )
        self.assertEqual(message['echantillon_numero'], self.numero)
        self._snapshot('07_notifications_messagerie')

    def _creer_et_soumettre_evaluation(self, user, session_id, fruite):
        draft = self._post(
            user,
            '/api/evaluations/',
            {
                'echantillon': self.sample_id,
                'session': session_id,
                'classification': 'extra_vierge',
                'fruite': str(fruite),
                'type_fruite': 'vert',
                'amertume': '2.0',
                'piquant': '2.1',
                'chome': '0',
                'moisi': '0',
                'vinaigre': '0',
                'rance': '0',
                'gele': '0',
                'autres_defaut': '0',
                'commentaire': f'Evaluation audit par {user.email}',
            },
            expected=status.HTTP_201_CREATED,
        )
        return self._post(user, f"/api/evaluations/{draft['id']}/soumettre/", {})

    def _snapshot(self, step):
        for role, user in self._roles().items():
            for route in self._routes_for(role):
                response = self._get(user, route, expected=(status.HTTP_200_OK, status.HTTP_403_FORBIDDEN))
                self._write_fixture(role, step, route, response.status_code, self._json(response))
                self._assert_no_server_error(response, role, route, step)
                if response.status_code == status.HTTP_200_OK:
                    self._assert_visibility(role, route, response)

    def _roles(self):
        return {
            'direction': self.direction,
            'collecteur': self.collecteur,
            'collecteur_autre': self.autre_collecteur,
            'degustateur': self.degustateur,
            'chef_degustation': self.chef,
            'laboratoire': self.labo,
        }

    def _routes_for(self, role):
        common = [
            '/api/users/me/',
            '/api/notifications/',
            '/api/notifications/unread-count/',
            '/api/messages/',
            '/api/messages/contacts/',
            '/api/messages/non-lus/',
        ]
        if role in ('collecteur', 'collecteur_autre'):
            return common + ['/api/echantillons/', '/api/echantillons/collecteur/carte/']
        if role == 'degustateur':
            return common + [
                '/api/echantillons/',
                '/api/echantillons/?recu_physiquement=true',
                '/api/evaluations/',
                '/api/analyses/',
                '/api/analyses/echantillons/',
                '/api/sessions/',
                '/api/users/panel-members/',
                '/api/degustateur/dashboard/pipeline/',
                '/api/degustateur/dashboard/urgentes/',
                '/api/degustateur/dashboard/classifications/',
                '/api/degustateur/dashboard/presence/',
                '/api/degustateur/dashboard/delai/',
                '/api/degustateur/activite/',
            ]
        if role == 'chef_degustation':
            return common + [
                '/api/echantillons/',
                '/api/echantillons/?recu_physiquement=true',
                '/api/evaluations/',
                '/api/analyses/',
                '/api/analyses/echantillons/',
                '/api/sessions/',
                '/api/users/',
                '/api/users/panel-members/',
                '/api/chef/evaluations/',
                '/api/chef/dashboard/pipeline/',
                '/api/chef/dashboard/urgentes/',
                '/api/chef/dashboard/sessions-en-attente/',
                '/api/chef/dashboard/delai/',
                '/api/chef/dashboard/alignement/',
                '/api/chef/dashboard/classifications/',
                '/api/chef/dashboard/presence/',
                '/api/chef/dashboard/urgentes-ceo/',
                '/api/chef/dashboard/activite/',
            ]
        if role == 'laboratoire':
            return common + ['/api/echantillons/', '/api/analyses/', '/api/analyses/echantillons/']
        return common + [
            '/api/echantillons/',
            '/api/evaluations/',
            '/api/analyses/',
            '/api/analyses/echantillons/',
            '/api/users/',
            '/api/users/panel-members/',
            '/api/ceo/dashboard/',
        ]

    def _assert_visibility(self, role, route, response):
        if not self.sample_id:
            return
        data = self._json(response)
        contains = self._contains_sample(data)
        if route == '/api/echantillons/' or route == '/api/echantillons/?recu_physiquement=true':
            if route.endswith('recu_physiquement=true') and not self.recu_physiquement:
                self.assertFalse(contains, f'{role} ne doit pas voir l echantillon non recu via {route}')
                return
            if role == 'collecteur_autre':
                self.assertFalse(contains, f'{role} voit l echantillon d un autre collecteur via {route}')
            elif role == 'laboratoire':
                if route == '/api/echantillons/' and data.get('count', 0) == 0:
                    return
                self.assertTrue(contains, f'{role} doit voir les echantillons recus via {route}')
            else:
                self.assertTrue(contains, f'{role} doit voir l echantillon via {route}')
        if route == '/api/analyses/echantillons/' and role != 'collecteur_autre':
            if self._step_has_reception(data):
                self.assertTrue(contains, f'{role} doit voir l echantillon recu cote labo')
        if route == '/api/messages/' and role not in ('degustateur', 'chef_degustation', 'laboratoire'):
            if role in ('collecteur', 'direction'):
                self.assertTrue(
                    contains or data.get('count', 0) == 0,
                    f'{role} ne doit recevoir que ses messages lies au parcours',
                )

    def _step_has_reception(self, data):
        return self._contains_key_value(data, 'recu_physiquement', True) or self._contains_key(data, 'date_reception_echantillon')

    def _contains_sample(self, data):
        return self._contains_value(data, self.sample_id) or self._contains_value(data, self.numero)

    def _contains_value(self, data, expected):
        if expected is None:
            return False
        if isinstance(data, dict):
            return any(self._contains_value(value, expected) for value in data.values())
        if isinstance(data, list):
            return any(self._contains_value(item, expected) for item in data)
        return str(data) == str(expected)

    def _contains_key(self, data, key):
        if isinstance(data, dict):
            return key in data or any(self._contains_key(value, key) for value in data.values())
        if isinstance(data, list):
            return any(self._contains_key(item, key) for item in data)
        return False

    def _contains_key_value(self, data, key, expected):
        if isinstance(data, dict):
            if data.get(key) == expected:
                return True
            return any(self._contains_key_value(value, key, expected) for value in data.values())
        if isinstance(data, list):
            return any(self._contains_key_value(item, key, expected) for item in data)
        return False

    def _write_fixture(self, role, step, route, status_code, data):
        path = FIXTURES_ROOT / role / step / self._route_filename(route)
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {'status_code': status_code, 'route': route, 'data': data}
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, default=str), encoding='utf-8')

    def _route_filename(self, route):
        safe = route.strip('/').replace('/', '__').replace('?', '__').replace('&', '__').replace('=', '-')
        return f'{safe or "root"}.json'

    def _get(self, user, route, expected=status.HTTP_200_OK):
        self.client.force_authenticate(user=user)
        response = self.client.get(route)
        if isinstance(expected, tuple):
            self.assertIn(response.status_code, expected, f'GET {route}: {response.content!r}')
        else:
            self.assertEqual(response.status_code, expected, f'GET {route}: {response.content!r}')
        return response

    def _post(self, user, route, data, files=None, expected=status.HTTP_200_OK):
        self.client.force_authenticate(user=user)
        payload = dict(data)
        if files:
            payload.update(files)
        response = self.client.post(route, payload, format='multipart' if files else 'json')
        self.assertEqual(response.status_code, expected, f'POST {route}: {response.content!r}')
        return self._json(response)

    def _patch(self, user, route, data, expected=status.HTTP_200_OK):
        self.client.force_authenticate(user=user)
        response = self.client.patch(route, data, format='json')
        self.assertEqual(response.status_code, expected, f'PATCH {route}: {response.content!r}')
        return self._json(response)

    def _json(self, response):
        if not response.content:
            return {}
        try:
            return response.json()
        except ValueError:
            return {'raw': response.content.decode('utf-8', errors='replace')}

    def _assert_no_server_error(self, response, role, route, step):
        self.assertLess(
            response.status_code,
            500,
            f'Erreur serveur pour {role} {step} GET {route}: {response.content!r}',
        )
        if response.status_code == status.HTTP_200_OK:
            self.assertNotRegex(
                json.dumps(self._json(response), ensure_ascii=False, default=str),
                re.compile(r'Traceback|Server Error', re.IGNORECASE),
            )
