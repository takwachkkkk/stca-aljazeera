from django.test import SimpleTestCase
from rest_framework import status
from rest_framework.test import APITestCase

from echantillons.models import Echantillon
from users.models import User

from . import classification as pr48
from .models import EvaluationOrganoleptique


class EvaluationOrganoleptiqueApiTests(APITestCase):
    def setUp(self):
        self.degustateur = User.objects.create_user(
            email='degustateur.eval@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='One',
            role=User.Role.DEGUSTATEUR,
        )
        self.other_degustateur = User.objects.create_user(
            email='degustateur.other@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='Two',
            role=User.Role.DEGUSTATEUR,
        )
        self.collecteur = User.objects.create_user(
            email='collecteur.eval@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='User',
            role=User.Role.COLLECTEUR,
        )
        self.direction = User.objects.create_user(
            email='direction.eval@example.com',
            password='Test@12345',
            nom='Direction',
            prenom='User',
            role=User.Role.DIRECTION,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='EV-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
            recu_physiquement=True,
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def test_degustateur_can_create_own_evaluation(self):
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/evaluations/',
            {
                'echantillon': str(self.sample.id),
                'fruite': '4.0',
                'classification': 'extra_vierge',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        evaluation = EvaluationOrganoleptique.objects.get(id=response.json()['id'])
        self.assertEqual(evaluation.degustateur, self.degustateur)
        self.sample.refresh_from_db()
        self.assertEqual(
            self.sample.statut_degustateur,
            Echantillon.StatutDegustateur.EN_COURS,
        )

    def test_evaluation_requires_physical_reception(self):
        pending = Echantillon.objects.create(
            reference_bouteille='EV-002',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            variete='Chemlali',
            recu_physiquement=False,
        )
        self.authenticate(self.degustateur)

        response = self.client.post(
            '/api/evaluations/',
            {'echantillon': str(pending.id), 'fruite': '3.0'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(
            response.json()['echantillon'],
            [
                "Cet échantillon n'est pas encore arrivé à la société. Cochez d'abord "
                "« Réception physique » sur sa fiche, puis soumettez l'évaluation."
            ],
        )

    def test_degustateur_lists_only_own_evaluations(self):
        own = EvaluationOrganoleptique.objects.create(
            echantillon=self.sample,
            degustateur=self.degustateur,
            fruite='4.0',
        )
        EvaluationOrganoleptique.objects.create(
            echantillon=self.sample,
            degustateur=self.other_degustateur,
            fruite='2.0',
        )
        self.authenticate(self.degustateur)

        response = self.client.get('/api/evaluations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        results = data.get('results', data)
        ids = {item['id'] for item in results}
        self.assertEqual(ids, {str(own.id)})

    def test_submitted_evaluation_is_read_only(self):
        evaluation = EvaluationOrganoleptique.objects.create(
            echantillon=self.sample,
            degustateur=self.degustateur,
            fruite='4.0',
            statut=EvaluationOrganoleptique.Statut.SOUMIS,
        )
        self.authenticate(self.degustateur)

        response = self.client.patch(
            f'/api/evaluations/{evaluation.id}/',
            {'fruite': '7.0'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        evaluation.refresh_from_db()
        self.assertEqual(str(evaluation.fruite), '4.0')

    def test_collecteur_cannot_create_evaluation(self):
        self.authenticate(self.collecteur)

        response = self.client.post(
            '/api/evaluations/',
            {'echantillon': str(self.sample.id), 'fruite': '4.0'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_direction_can_read_all_evaluations_but_not_create(self):
        one = EvaluationOrganoleptique.objects.create(
            echantillon=self.sample,
            degustateur=self.degustateur,
            fruite='4.0',
        )
        two = EvaluationOrganoleptique.objects.create(
            echantillon=self.sample,
            degustateur=self.other_degustateur,
            fruite='2.0',
        )
        self.authenticate(self.direction)

        read = self.client.get('/api/evaluations/')
        create = self.client.post(
            '/api/evaluations/',
            {
                'echantillon': str(self.sample.id),
                'fruite': '4.0',
                'classification': 'extra_vierge',
            },
            format='json',
        )

        self.assertEqual(read.status_code, status.HTTP_200_OK)
        data = read.json()
        results = data.get('results', data)
        ids = {item['id'] for item in results}
        self.assertEqual(ids, {str(one.id), str(two.id)})
        self.assertEqual(create.status_code, status.HTTP_403_FORBIDDEN)


class GrillePr48Tests(SimpleTestCase):
    """
    Grille de classification interne PR-48 SS8.

    Ce jeu de cas est le meme que celui de test/classification_interne_test.dart :
    les deux implementations doivent rendre exactement les memes resultats.
    """

    def classe(self, fruite, type_fruite, amertume, piquant,
               mediane=0.0, non_harmonieux=False):
        coi = pr48.calculer_classification_coi(mediane, fruite)
        return pr48.calculer_classe_interne(
            coi, fruite, type_fruite, amertume, piquant,
            profil_non_harmonieux=non_harmonieux,
        )

    # ── un cas nominal par classe ────────────────────────────────────────────
    def test_extra_a_plus(self):
        self.assertEqual(self.classe(5.0, pr48.VERT, 3.5, 4.0), pr48.EXTRA_A_PLUS)

    def test_extra_a(self):
        self.assertEqual(self.classe(4.0, pr48.VERT, 3.0, 3.5), pr48.EXTRA_A)

    def test_extra_b_plus(self):
        self.assertEqual(self.classe(3.5, pr48.VERT, 3.0, 3.5), pr48.EXTRA_B_PLUS)

    def test_extra_b(self):
        self.assertEqual(self.classe(2.5, pr48.VERT_MUR, 3.0, 3.0), pr48.EXTRA_B)

    def test_extra_b_moins(self):
        self.assertEqual(self.classe(2.0, pr48.MUR, 2.5, 2.0), pr48.EXTRA_B_MOINS)

    def test_extra_c(self):
        self.assertEqual(self.classe(1.5, pr48.VERT, 1.5, 1.5), pr48.EXTRA_C)

    # ── les quatre cas hors grille du SS5 de la spec ─────────────────────────
    def test_hors_grille_fruite_entre_a_et_a_plus(self):
        self.assertIsNone(self.classe(4.7, pr48.VERT, 3.5, 4.0))

    def test_hors_grille_fruite_entre_b_et_b_moins(self):
        self.assertIsNone(self.classe(2.3, pr48.VERT, 3.0, 3.0))

    def test_hors_grille_amertume_pile_sur_la_borne_stricte(self):
        # Extra A+ exige 3 < amertume ; a 3.0 pile la ligne ne s'applique pas,
        # et le fruite de 5.0 est trop haut pour Extra A.
        self.assertIsNone(self.classe(5.0, pr48.VERT, 3.0, 4.0))

    def test_hors_grille_amertume_et_piquant_ecrasent_le_fruite(self):
        # Cas SS9 : oriente vers Extra desequilibree par choix manuel.
        self.assertIsNone(self.classe(2.0, pr48.VERT, 4.5, 5.0))

    # ── resolution des chevauchements par l'ordre de lecture ─────────────────
    def test_fruite_pile_3_donne_extra_b_plus(self):
        self.assertEqual(self.classe(3.0, pr48.VERT, 3.0, 3.5), pr48.EXTRA_B_PLUS)

    def test_profil_plat_mur_donne_extra_b_moins_avant_extra_c(self):
        self.assertEqual(self.classe(1.5, pr48.MUR, 1.5, 1.5), pr48.EXTRA_B_MOINS)

    # ── condition prealable SS6 ──────────────────────────────────────────────
    def test_un_defaut_ferme_la_classification_interne(self):
        self.assertIsNone(self.classe(5.0, pr48.VERT, 3.5, 4.0, mediane=2.0))

    def test_fruite_nul_ferme_la_classification_interne(self):
        coi = pr48.calculer_classification_coi(2.0, 0.0)
        self.assertEqual(coi, pr48.VIERGE_ORDINAIRE)
        self.assertIsNone(
            pr48.calculer_classe_interne(coi, 0.0, pr48.VERT, 0.0, 0.0)
        )

    # ── critere « profil harmonieux » SS8 / SS9 ──────────────────────────────
    def test_profil_non_harmonieux_annule_extra_a_plus(self):
        self.assertIsNone(
            self.classe(5.0, pr48.VERT, 3.5, 4.0, non_harmonieux=True)
        )

    def test_profil_non_harmonieux_annule_extra_a(self):
        self.assertIsNone(
            self.classe(4.0, pr48.VERT, 3.0, 3.5, non_harmonieux=True)
        )

    def test_profil_non_harmonieux_laisse_extra_b_plus_intacte(self):
        # Le SS9 ne vise que les deux classes hautes.
        self.assertEqual(
            self.classe(3.5, pr48.VERT, 3.0, 3.5, non_harmonieux=True),
            pr48.EXTRA_B_PLUS,
        )

    def test_liste_manuelle_exclut_les_classes_hautes_si_non_harmonieux(self):
        proposees = pr48.classes_choisissables(profil_non_harmonieux=True)
        self.assertNotIn(pr48.EXTRA_A_PLUS, proposees)
        self.assertNotIn(pr48.EXTRA_A, proposees)
        self.assertIn(pr48.EXTRA_DESEQUILIBRE, proposees)

    def test_liste_manuelle_complete_par_defaut(self):
        proposees = pr48.classes_choisissables()
        self.assertEqual(len(proposees), 7)
        self.assertIn(pr48.EXTRA_A_PLUS, proposees)

    # ── categorie COI inchangee ──────────────────────────────────────────────
    def test_categorie_coi_inchangee(self):
        self.assertIsNone(pr48.calculer_classification_coi(0.0, 0.0))
        self.assertEqual(pr48.calculer_classification_coi(0.0, 3.0), pr48.EXTRA_VIERGE)
        self.assertEqual(pr48.calculer_classification_coi(2.0, 3.0), pr48.VIERGE)
        self.assertEqual(pr48.calculer_classification_coi(5.0, 3.0), pr48.VIERGE_ORDINAIRE)
        self.assertEqual(pr48.calculer_classification_coi(7.0, 3.0), pr48.LAMPANTE)

    def test_mediane_defauts_est_le_plus_fort_des_six(self):
        self.assertEqual(
            pr48.mediane_defauts(0.0, 1.5, 0.0, 3.0, 0.0, 0.5), 3.0
        )


class ClasseInterneApiTests(APITestCase):
    """Validation serveur de la classe interne (PR-48 SS6, SS8, SS9)."""

    def setUp(self):
        self.degustateur = User.objects.create_user(
            email='degustateur.pr48@example.com',
            password='Test@12345',
            nom='Degustateur',
            prenom='Pr48',
            role=User.Role.DEGUSTATEUR,
        )
        self.collecteur = User.objects.create_user(
            email='collecteur.pr48@example.com',
            password='Test@12345',
            nom='Collecteur',
            prenom='Pr48',
            role=User.Role.COLLECTEUR,
        )
        self.sample = Echantillon.objects.create(
            reference_bouteille='PR48-001',
            collecteur=self.collecteur,
            gouvernorat='Sfax',
            delegation='Sfax Sud',
            variete='Chemlali',
            recu_physiquement=True,
        )
        self.client.force_authenticate(user=self.degustateur)

    def poster(self, **champs):
        payload = {'echantillon': str(self.sample.id)}
        payload.update(champs)
        return self.client.post('/api/evaluations/', payload, format='json')

    def test_classe_automatique_acceptee(self):
        response = self.poster(
            fruite='4.0', type_fruite='vert', amertume='3.0', piquant='3.5',
            classification='extra_vierge', classe_interne='extra_a',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        evaluation = EvaluationOrganoleptique.objects.get(id=response.json()['id'])
        self.assertEqual(evaluation.classe_interne, 'extra_a')
        self.assertFalse(evaluation.classe_interne_manuelle)
        self.assertIsNone(evaluation.classe_interne_choisie_le)

    def test_fruite_hors_echelle_refuse(self):
        # Echelle 0-10 depuis la tache 59.
        response = self.poster(fruite='10.5')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('fruite', response.json())

    def test_defaut_garde_son_echelle_0_10(self):
        response = self.poster(fruite='3.0', rance='7.0', classification='lampante')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_classe_interne_refusee_si_huile_non_extra_vierge(self):
        response = self.poster(
            fruite='4.0', rance='7.0',
            classification='lampante', classe_interne='extra_a',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('classe_interne', response.json())

    def test_classe_automatique_incoherente_refusee(self):
        response = self.poster(
            fruite='4.0', type_fruite='vert', amertume='3.0', piquant='3.5',
            classification='extra_vierge', classe_interne='extra_a_plus',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('classe_interne', response.json())

    def test_choix_manuel_refuse_quand_la_grille_repond(self):
        response = self.poster(
            fruite='4.0', type_fruite='vert', amertume='3.0', piquant='3.5',
            classification='extra_vierge', classe_interne='extra_a',
            classe_interne_manuelle=True,
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('classe_interne_manuelle', response.json())

    def test_choix_manuel_accepte_hors_grille(self):
        response = self.poster(
            fruite='4.7', type_fruite='vert', amertume='3.5', piquant='4.0',
            classification='extra_vierge',
            classe_interne='extra_a_plus', classe_interne_manuelle=True,
            classe_interne_motif='Fruite 4.7 : entre Extra A et Extra A+',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        evaluation = EvaluationOrganoleptique.objects.get(id=response.json()['id'])
        self.assertTrue(evaluation.classe_interne_manuelle)
        self.assertIsNotNone(evaluation.classe_interne_choisie_le)

    def test_classe_hors_grille_refusee_sans_marquage_manuel(self):
        response = self.poster(
            fruite='4.7', type_fruite='vert', amertume='3.5', piquant='4.0',
            classification='extra_vierge', classe_interne='extra_a_plus',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('classe_interne', response.json())

    def test_profil_non_harmonieux_refuse_les_classes_hautes(self):
        response = self.poster(
            fruite='5.0', type_fruite='vert', amertume='3.5', piquant='4.0',
            classification='extra_vierge', profil_non_harmonieux=True,
            classe_interne='extra_a_plus', classe_interne_manuelle=True,
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('classe_interne', response.json())

    def test_profil_non_harmonieux_accepte_une_classe_basse(self):
        response = self.poster(
            fruite='5.0', type_fruite='vert', amertume='3.5', piquant='4.0',
            classification='extra_vierge', profil_non_harmonieux=True,
            classe_interne='extra_desequilibre', classe_interne_manuelle=True,
            classe_interne_motif='Profil non harmonieux (SS9)',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_type_fruite_par_defaut_vert(self):
        response = self.poster(fruite='3.0', classification='extra_vierge')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        evaluation = EvaluationOrganoleptique.objects.get(id=response.json()['id'])
        self.assertEqual(evaluation.type_fruite, 'vert')

