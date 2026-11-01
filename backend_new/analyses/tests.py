from django.test import override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from echantillons.models import Echantillon
from users.models import User

from . import normes_coi
from .models import AnalyseLabo

# Les 28 valeurs du certificat 188-2026, un vrai rapport du laboratoire STCA
# Al Jazira, recopiees telles qu'imprimees. Il conclut "extra virgin olive oil".
RAPPORT_188 = {
    'acidite': '0.30',
    'indice_peroxyde': '9.71',
    'k232': '2.02',
    'k270': '0.12',
    'delta_k': '0.003',
    'humidite': '0.06',
    'impuretes': '0.03',
    'ecn42': '0.052',
    'cholesterol': '0.09',
    'brassicasterol': '0.00',
    'campesterol': '3.30',
    'stigmasterol': '0.64',
    'beta_sitosterol_apparent': '95.00',
    'delta_7_stigmastenol': '0.36',
    'delta_7_avenasterol': '0.61',
    'erythrodiol_uvaol': '2.00',
    'acide_palmitique': '14.65',
    'acide_palmitoleique': '1.61',
    'acide_heptadecanoique': '0.05',
    'acide_heptadecenoique': '0.09',
    'acide_stearique': '2.56',
    'acide_oleique': '64.06',
    'acide_linoleique': '15.68',
    'acide_linolenique': '0.66',
    'acide_arachidique': '0.39',
    'acide_gadoleique': '0.21',
    'trans_c18_1': '0.02',
    'trans_c18_2_c18_3': '0.02',
}


@override_settings(LABO_ACTIF=True)
class AnalyseLaboApiTests(APITestCase):
    def setUp(self):
        self.lab = User.objects.create_user(
            email='labo@example.com',
            password='Test@12345',
            nom='Labo',
            prenom='Technicien',
            role=User.Role.LABORATOIRE,
        )
        self.direction = User.objects.create_user(
            email='direction@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.degustateur = User.objects.create_user(
            email='degustateur@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='User',
            role=User.Role.DEGUSTATEUR,
        )
        self.chef = User.objects.create_user(
            email='chef@example.com',
            password='Test@12345',
            nom='Chef',
            prenom='Degustation',
            role=User.Role.CHEF_DEGUSTATION,
        )
        self.collecteur = User.objects.create_user(
            email='collecteur@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.received = Echantillon.objects.create(
            reference_bouteille='B-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            quantite_estimee='20L',
            recu_physiquement=True,
            date_arrivee_echantillon=timezone.now(),
        )
        self.not_received = Echantillon.objects.create(
            reference_bouteille='B-002',
            collecteur=self.collecteur,
            gouvernorat='Sousse',
            recu_physiquement=False,
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def results(self, response):
        data = response.json()
        return data.get('results', data)

    def test_lab_sees_only_physically_received_samples(self):
        self.authenticate(self.lab)

        response = self.client.get('/api/analyses/echantillons/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertIn(str(self.received.id), ids)
        self.assertNotIn(str(self.not_received.id), ids)

    def test_degustateur_sees_unreceived_samples(self):
        self.authenticate(self.degustateur)

        response = self.client.get('/api/analyses/echantillons/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertIn(str(self.not_received.id), ids)

    def test_chef_sees_unreceived_samples(self):
        self.authenticate(self.chef)

        response = self.client.get('/api/analyses/echantillons/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = {item['id'] for item in self.results(response)}
        self.assertIn(str(self.not_received.id), ids)

    def test_lab_can_create_analysis_for_received_sample(self):
        self.authenticate(self.lab)

        response = self.client.post(
            '/api/analyses/',
            {
                'echantillon': str(self.received.id),
                'statut': AnalyseLabo.Statut.EN_COURS,
                'acidite': '0.420',
                'indice_peroxyde': '8.500',
                'k232': '1.900',
                'k270': '0.140',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.received.refresh_from_db()
        self.assertEqual(self.received.statut_labo, Echantillon.StatutLabo.EN_COURS)
        self.assertEqual(AnalyseLabo.objects.get().technicien, self.lab)

    def test_lab_cannot_create_analysis_for_unreceived_sample(self):
        self.authenticate(self.lab)

        response = self.client.post(
            '/api/analyses/',
            {
                'echantillon': str(self.not_received.id),
                'statut': AnalyseLabo.Statut.EN_COURS,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_submitted_analysis_is_read_only(self):
        self.authenticate(self.lab)
        analyse = AnalyseLabo.objects.create(
            echantillon=self.received,
            technicien=self.lab,
            statut=AnalyseLabo.Statut.EN_COURS,
            acidite='0.300',
        )

        submit = self.client.post(f'/api/analyses/{analyse.id}/soumettre/')
        self.assertEqual(submit.status_code, status.HTTP_200_OK)
        self.received.refresh_from_db()
        self.assertEqual(self.received.statut_labo, Echantillon.StatutLabo.SOUMIS)

        patch = self.client.patch(
            f'/api/analyses/{analyse.id}/',
            {'acidite': '0.900'},
            format='json',
        )
        delete = self.client.delete(f'/api/analyses/{analyse.id}/')

        self.assertEqual(patch.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(delete.status_code, status.HTTP_400_BAD_REQUEST)

    def test_direction_can_read_but_not_create_lab_analysis(self):
        self.authenticate(self.direction)

        read = self.client.get('/api/analyses/echantillons/')
        create = self.client.post(
            '/api/analyses/',
            {'echantillon': str(self.received.id)},
            format='json',
        )

        self.assertEqual(read.status_code, status.HTTP_200_OK)
        self.assertEqual(create.status_code, status.HTTP_403_FORBIDDEN)
        ids = {item['id'] for item in self.results(read)}
        self.assertNotIn(str(self.not_received.id), ids)

    def test_degustateur_can_read_but_not_create_lab_analysis(self):
        self.authenticate(self.degustateur)

        read_samples = self.client.get('/api/analyses/echantillons/')
        read_analyses = self.client.get('/api/analyses/')
        create = self.client.post(
            '/api/analyses/',
            {'echantillon': str(self.received.id)},
            format='json',
        )

        self.assertEqual(read_samples.status_code, status.HTTP_200_OK)
        self.assertEqual(read_analyses.status_code, status.HTTP_200_OK)
        self.assertEqual(create.status_code, status.HTTP_403_FORBIDDEN)


class NormesCoiTests(APITestCase):
    """La table des seuils, verifiee contre un vrai rapport.

    C'est la seule preuve dont on dispose que les seuils ecrits dans le code
    correspondent a ceux qu'applique le laboratoire : le rapport papier
    n'imprime aucune norme, il ne donne que les valeurs mesurees.
    """

    def valeurs(self):
        return {cle: normes_coi.lire_decimal(v) for cle, v in RAPPORT_188.items()}

    def test_la_table_porte_les_28_parametres(self):
        self.assertEqual(len(normes_coi.TOUS_PARAMETRES), 28)
        self.assertEqual(len(normes_coi.PARAMETRES_PRINCIPAUX), 8)
        self.assertEqual(len(normes_coi.STEROLS), 8)
        self.assertEqual(len(normes_coi.ACIDES_GRAS), 12)

    def test_les_cles_sont_uniques(self):
        cles = [p.cle for p in normes_coi.TOUS_PARAMETRES]
        self.assertEqual(len(set(cles)), len(cles))

    def test_le_rapport_reel_ne_sort_d_aucune_norme(self):
        hors = normes_coi.parametres_hors_normes(self.valeurs())
        self.assertEqual(hors, [], f'juges hors norme : {[p.cle for p in hors]}')

    def test_le_rapport_reel_est_classe_extra_vierge(self):
        self.assertEqual(normes_coi.classification_coi(self.valeurs()), 'Extra Vierge')

    def test_la_virgule_et_le_point_donnent_le_meme_nombre(self):
        self.assertEqual(normes_coi.lire_decimal('0,30'), 0.30)
        self.assertEqual(normes_coi.lire_decimal('0.30'), 0.30)
        self.assertEqual(normes_coi.lire_decimal('0,003'), 0.003)

    def test_une_valeur_absente_ne_vaut_pas_zero(self):
        # Confondre "non mesure" et "mesure a zero" ferait passer un rapport
        # incomplet pour un rapport parfait.
        self.assertIsNone(normes_coi.lire_decimal(''))
        self.assertIsNone(normes_coi.lire_decimal(None))
        self.assertIsNone(normes_coi.lire_decimal('abc'))

    def test_le_stigmasterol_se_juge_contre_le_campesterol(self):
        stigmasterol = normes_coi.PAR_CLE['stigmasterol']
        self.assertTrue(normes_coi.conformite(stigmasterol, 0.64, {'campesterol': 3.30}))
        self.assertFalse(normes_coi.conformite(stigmasterol, 4.00, {'campesterol': 3.30}))
        # Sans campesterol, la question n'a pas de reponse.
        self.assertIsNone(normes_coi.conformite(stigmasterol, 0.64))

    def test_un_parametre_sans_seuil_ne_se_juge_pas(self):
        # Le COI ne fixe pas de limite au Delta7-avenasterol.
        avenasterol = normes_coi.PAR_CLE['delta_7_avenasterol']
        self.assertFalse(avenasterol.a_une_norme)
        self.assertIsNone(normes_coi.conformite(avenasterol, 99.0))

    def test_le_classement_reste_indecidable_si_une_valeur_manque(self):
        valeurs = self.valeurs()
        valeurs['k270'] = None
        self.assertIsNone(normes_coi.classification_coi(valeurs))

    def test_un_sterol_hors_norme_ne_change_pas_le_classement(self):
        # Un sterol anormal trahit un melange, pas une degradation : il doit
        # declencher l'alerte sans toucher au classement.
        valeurs = self.valeurs()
        valeurs['campesterol'] = 5.20
        self.assertEqual(normes_coi.classification_coi(valeurs), 'Extra Vierge')
        self.assertEqual(
            [p.cle for p in normes_coi.parametres_hors_normes(valeurs)],
            ['campesterol'],
        )


class AnalyseComplete28ValeursTests(AnalyseLaboApiTests):
    """Les 28 valeurs doivent survivre a l'aller-retour par l'API.

    Le formulaire envoyait 5 champs que le serializer ne declarait pas : le
    technicien les saisissait, DRF les jetait en silence, personne ne voyait
    d'erreur. Ce test echoue si un parametre de la table sort de l'API.
    """

    def test_les_28_valeurs_sont_enregistrees_et_relues(self):
        self.authenticate(self.lab)

        payload = {
            'echantillon': str(self.received.id),
            'statut': AnalyseLabo.Statut.EN_COURS,
            'numero_certificat': '188-2026',
            'numero_lot': 'COM142-0426',
            'quantite_ml': 100,
            **RAPPORT_188,
        }
        response = self.client.post('/api/analyses/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        analyse = AnalyseLabo.objects.get()
        for parametre in normes_coi.TOUS_PARAMETRES:
            enregistre = getattr(analyse, parametre.cle)
            self.assertIsNotNone(
                enregistre,
                f'{parametre.cle} a ete perdu a l\'enregistrement',
            )
            self.assertEqual(
                float(enregistre),
                float(RAPPORT_188[parametre.cle]),
                f'{parametre.cle} a change de valeur',
            )

        self.assertEqual(analyse.numero_certificat, '188-2026')
        self.assertEqual(analyse.numero_lot, 'COM142-0426')
        self.assertEqual(analyse.quantite_ml, 100)

    def test_l_api_renvoie_le_classement_et_les_ecarts(self):
        self.authenticate(self.lab)

        self.client.post(
            '/api/analyses/',
            {
                'echantillon': str(self.received.id),
                'statut': AnalyseLabo.Statut.EN_COURS,
                **RAPPORT_188,
            },
            format='json',
        )
        analyse = AnalyseLabo.objects.get()

        response = self.client.get(f'/api/analyses/{analyse.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        # Le classement est deduit, jamais saisi : le labo et la direction
        # lisent forcement la meme valeur.
        self.assertEqual(data['classification'], 'Extra Vierge')
        self.assertEqual(data['parametres_hors_normes'], [])

    def test_un_sterol_hors_norme_remonte_par_l_api(self):
        self.authenticate(self.lab)

        self.client.post(
            '/api/analyses/',
            {
                'echantillon': str(self.received.id),
                'statut': AnalyseLabo.Statut.EN_COURS,
                **RAPPORT_188,
                'campesterol': '5.20',
            },
            format='json',
        )
        analyse = AnalyseLabo.objects.get()

        data = self.client.get(f'/api/analyses/{analyse.id}/').json()
        self.assertEqual(data['classification'], 'Extra Vierge')
        self.assertEqual(data['parametres_hors_normes'], ['campesterol'])
