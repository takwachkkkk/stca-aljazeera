// ═════════════════════════════════════════════════════════════════════════════
// FILE : ceo/utilisateurs/models/mock_data_patch.dart
// PURPOSE : Single source of truth for all CEO mock data.
//           When the real API is ready, delete this file and replace
//           the imports with service calls — nothing else changes.
// TODO: remove when backend is ready
// ═════════════════════════════════════════════════════════════════════════════

import 'echantillon_ceo_view.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/models/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ALL SAMPLES — used by echantillons_ceo_page.dart
// Every other list below is derived from this one (filtered by statut).
// ─────────────────────────────────────────────────────────────────────────────
final List<EchantillonCeoView> mockEchantillons = [
  EchantillonCeoView(
    id: '2026/0001',
    referenceBouteille: 'CHEMLALI-C1',
    gouvernorat: 'Sfax',
    delegation: 'Sfax Sud',
    fournisseurTexte: 'SF-42',
    variete: 'Chemlali',
    quantiteEstimee: '25',
    dateAjout: '01/03/2026',
    dateArriveeEchantillon: '03/03/2026 à 09h15',
    collecteurNom: 'Ahmed Dridi',
    recuPhysiquement: true,
    statut: StatutCeo.selectionne,
    totalTasteurs: 5,
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-001',
        echantillonId: 'mock',
        tasteurId: 'D1',
        tasteurNom: 'Ali Ben Salem',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-03-11T10:30:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.vert,
        amertume: 2.5,
        piquant: 3.0,
        chome: 0,
        moisi: 0,
        vinaigre: 0,
        gele: 0,
        rance: 0,
        commentaire: 'Bon fruité vert, bien équilibré.',
      ),
      EvaluationOrganoleptique(
        id: 'eval-mock-002',
        echantillonId: 'mock',
        tasteurId: 'D2',
        tasteurNom: 'Sara Mbarki',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-03-11T11:15:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.vert,
        amertume: 2.0,
        piquant: 3.0,
      ),
      EvaluationOrganoleptique(
        id: 'eval-mock-003',
        echantillonId: 'mock',
        tasteurId: 'D3',
        tasteurNom: 'Hedi Rjaibi',
        classification: ClassificationHuile.vierge,
        soumisLe: '2026-03-11T14:00:00Z',
        fruite: 2.0,
        typeFruite: TypeFruite.vert,
        amertume: 1.5,
        piquant: 2.0,
        chome: 1.0,
      ),
      EvaluationOrganoleptique(
        id: 'eval-mock-004',
        echantillonId: 'mock',
        tasteurId: 'D3',
        tasteurNom: 'rajab saye9',
        classification: ClassificationHuile.vierge,
        soumisLe: '2026-03-11T14:00:00Z',
        fruite: 2.0,
        typeFruite: TypeFruite.vert,
        amertume: 1.5,
        piquant: 2.0,
        chome: 1.0,
      ),
      EvaluationOrganoleptique(
        id: 'eval-mock-005',
        echantillonId: 'mock',
        tasteurId: 'D3',
        tasteurNom: 'ichrak chk',
        classification: ClassificationHuile.vierge,
        soumisLe: '2026-03-11T14:00:00Z',
        fruite: 2.0,
        typeFruite: TypeFruite.vert,
        amertume: 1.5,
        piquant: 2.0,
        chome: 1.0,
      ),
    ],
    analyse: const RapportLabo(
      numeroCertificat: '188-2026',
      numeroLot: 'COM142-0426',
      valeurs: {
        'acidite': 0.42,
        'indice_peroxyde': 8.6,
        'k232': 1.92,
        'k270': 0.14,
        'delta_k': 0.003,
        'humidite': 0.06,
        'impuretes': 0.03,
        'ecn42': 0.052,
      },
      dateAnalyse: '05/03/2026',
    ),
  ),

  EchantillonCeoView(
    id: '2026/0002',
    referenceBouteille: 'CHEMLALI-C4',
    gouvernorat: 'Sfax',
    delegation: 'Mahres',
    fournisseurTexte: 'SF-17',
    variete: 'Chemlali',
    quantiteEstimee: '12',
    dateAjout: '05/03/2026',
    dateArriveeEchantillon: '08/03/2026 à 14h00',
    collecteurNom: 'Ahmed Dridi',
    recuPhysiquement: true,
    statut: StatutCeo.enNegociation,
    totalTasteurs: 5,
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-006',
        echantillonId: 'mock',
        tasteurId: 'D1',
        tasteurNom: 'Ali Ben Salem',
        classification: ClassificationHuile.vierge,
        soumisLe: '2026-03-10T09:00:00Z',
        fruite: 2.5,
        typeFruite: TypeFruite.vert,
        amertume: 2.0,
        piquant: 2.0,
      ),
    ],
  ),

  EchantillonCeoView(
    id: '2026/0003',
    referenceBouteille: 'ZALMATI-07-B',
    gouvernorat: 'Gafsa',
    delegation: 'Gafsa Nord',
    fournisseurTexte: 'GF-08',
    variete: 'Zalmati',
    quantiteEstimee: '30',
    dateAjout: '20/02/2026',
    dateArriveeEchantillon: '23/02/2026 à 11h30',
    collecteurNom: 'Sami Khaled',
    recuPhysiquement: true,
    statut: StatutCeo.achatConfirme,
    totalTasteurs: 5,
    budgetNegociation: '8.50 DT/kg',
    quantiteCibleT: '30',
    camionReserve: 'TRK-003',
    stockArrive: false,
    dateLivraisonStock: '28/03/2026 à 09h00',
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-007',
        echantillonId: 'mock',
        tasteurId: 'D1',
        tasteurNom: 'Ali Ben Salem',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-02-25T10:00:00Z',
        fruite: 4.5,
        typeFruite: TypeFruite.mur,
        amertume: 3.0,
        piquant: 4.0,
      ),
      EvaluationOrganoleptique(
        id: 'eval-mock-008',
        echantillonId: 'mock',
        tasteurId: 'D2',
        tasteurNom: 'Sara Mbarki',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-02-25T11:00:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.mur,
        amertume: 3.0,
        piquant: 3.5,
      ),
    ],
    // Échantillon refusé : acidité au-dessus de la norme extra vierge, et un
    // stérol qui trahit un mélange sans que le classement le dise.
    analyse: const RapportLabo(
      numeroCertificat: '164-2026',
      valeurs: {
        'acidite': 1.80,
        'indice_peroxyde': 18.0,
        'k232': 2.40,
        'k270': 0.19,
        'campesterol': 4.60,
        'beta_sitosterol_apparent': 91.20,
      },
      dateAnalyse: '22/02/2026',
    ),
  ),

  EchantillonCeoView(
    id: '2026/0004',
    referenceBouteille: 'CHETOUI-C3',
    gouvernorat: 'Béja',
    fournisseurTexte: 'BJ-15',
    variete: 'Chetoui',
    quantiteEstimee: '8',
    dateAjout: '28/02/2026',
    collecteurNom: 'Sami Khaled',
    statut: StatutCeo.refuse,
    totalTasteurs: 5,
    raisonRefus: 'Qualité insuffisante',
    evaluations: [],
  ),

  EchantillonCeoView(
    id: '2026/0005',
    referenceBouteille: 'OUESLATI-C2',
    gouvernorat: 'Kairouan',
    fournisseurTexte: 'KR-22',
    variete: 'Oueslati',
    quantiteEstimee: '15',
    dateAjout: '18/03/2026',
    dateLivraisonPrevue:
        '15/05/2026 à 10h00', // shows "Échantillon attendu le [date exacte]" case
    collecteurNom: 'Mounir Zouaghi',
    statut: StatutCeo.selectionne,
    totalTasteurs: 5,
    // Le rapport complet : les 28 valeurs du certificat 188-2026, recopiées
    // telles quelles. Sert d'exemple d'un rapport entièrement rempli.
    analyse: const RapportLabo(
      numeroCertificat: '188-2026',
      numeroLot: 'COM142-0426',
      valeurs: {
        'acidite': 0.30,
        'indice_peroxyde': 9.71,
        'k232': 2.02,
        'k270': 0.12,
        'delta_k': 0.003,
        'humidite': 0.06,
        'impuretes': 0.03,
        'ecn42': 0.052,
        'cholesterol': 0.09,
        'brassicasterol': 0.00,
        'campesterol': 3.30,
        'stigmasterol': 0.64,
        'beta_sitosterol_apparent': 95.00,
        'delta_7_stigmastenol': 0.36,
        'delta_7_avenasterol': 0.61,
        'erythrodiol_uvaol': 2.00,
        'acide_palmitique': 14.65,
        'acide_palmitoleique': 1.61,
        'acide_heptadecanoique': 0.05,
        'acide_heptadecenoique': 0.09,
        'acide_stearique': 2.56,
        'acide_oleique': 64.06,
        'acide_linoleique': 15.68,
        'acide_linolenique': 0.66,
        'acide_arachidique': 0.39,
        'acide_gadoleique': 0.21,
        'trans_c18_1': 0.02,
        'trans_c18_2_c18_3': 0.02,
      },
      dateAnalyse: '20/03/2026',
    ),
  ),

  EchantillonCeoView(
    id: '2026/0006',
    referenceBouteille: 'ARBEQUINA-I1',
    gouvernorat: 'Tunis',
    fournisseurTexte: 'TN-01',
    variete: 'Arbequina',
    quantiteEstimee: '5',
    dateAjout: '10/03/2026',
    collecteurNom: null, // interne
    statut: StatutCeo.selectionne,
    totalTasteurs: 5,
  ),

  EchantillonCeoView(
    id: '2026/0007',
    referenceBouteille: 'CHEMLALI-C8',
    gouvernorat: 'Sfax',
    delegation: 'Sfax Sud',
    fournisseurTexte: 'SF-42',
    variete: 'Chemlali',
    quantiteEstimee: '25',
    dateAjout: '01/03/2026',
    dateArriveeEchantillon: '05/03/2026 à 08h45',
    collecteurNom: 'Ahmed Dridi',
    recuPhysiquement: true,
    statut: StatutCeo.achatConfirme,
    totalTasteurs: 5,
    budgetNegociation: '9.20 DT/kg',
    quantiteCibleT: '25',
    camionReserve: 'TRK-007',
    noteInterne: 'Qualité extra vierge confirmée.',
    stockArrive: true,
    dateLivraisonStock: '20/03/2026 à 07h30',
  ),

  EchantillonCeoView(
    id: '2026/0008',
    referenceBouteille: 'CHETOUI-C5',
    gouvernorat: 'Béja',
    fournisseurTexte: 'BJ-15',
    variete: 'Chetoui',
    quantiteEstimee: '18',
    dateAjout: '28/02/2026',
    dateArriveeEchantillon: '03/03/2026 à 16h20',
    collecteurNom: 'Ahmed Dridi',
    recuPhysiquement: true,
    statut: StatutCeo.achatConfirme,
    totalTasteurs: 5,
    budgetNegociation: '7.80 DT/kg',
    quantiteCibleT: '18',
    stockArrive: true,
    dateLivraisonStock: '15/03/2026 à 07h30',
  ),

  // ── State ④ : dateLivraisonPrevue set, sample not yet received ──────────────
  EchantillonCeoView(
    id: '2026/0009',
    referenceBouteille: 'SAHLI-B2',
    gouvernorat: 'Monastir',
    delegation: 'Ksar Hellal',
    fournisseurTexte: 'MN-09',
    variete: 'Sahli',
    quantiteEstimee: '20',
    dateAjout: '25/03/2026',
    dateLivraisonPrevue: '20/04/2026',
    dateLivraisonPrevueFin: '05/05/2026',
    collecteurNom: 'Mounir Zouaghi',
    recuPhysiquement: false,
    statut: StatutCeo.selectionne,
    totalTasteurs: 5,
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-009',
        echantillonId: 'mock',
        tasteurId: 'D2',
        tasteurNom: 'Sara Mbarki',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-03-27T10:00:00Z',
        fruite: 3.5,
        typeFruite: TypeFruite.mur,
        amertume: 3.0,
        piquant: 3.0,
      ),
    ],
  ),

  // ── State ⑤ : achatConfirme but stock delivery not yet scheduled ────────────
  EchantillonCeoView(
    id: '2026/0010',
    referenceBouteille: 'CHEMLALI-C9',
    gouvernorat: 'Sfax',
    delegation: 'Jebeniana',
    fournisseurTexte: 'SF-55',
    variete: 'Chemlali',
    quantiteEstimee: '40',
    dateAjout: '15/03/2026',
    dateArriveeEchantillon: '18/03/2026 à 13h10',
    collecteurNom: 'Sami Khaled',
    recuPhysiquement: true,
    statut: StatutCeo.achatConfirme,
    totalTasteurs: 5,
    budgetNegociation: '9.00 DT/kg',
    quantiteCibleT: '40',
    stockArrive: false,
    dateLivraisonStock: '01/04/2026',
    dateLivraisonStockFin:
        '15/04/2026', // shows "Stock attendu entre [d1] et [d2]" case
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-010',
        echantillonId: 'mock',
        tasteurId: 'D1',
        tasteurNom: 'Ali Ben Salem',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-03-20T09:30:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.vert,
        amertume: 3.0,
        piquant: 3.0,
      ),
      EvaluationOrganoleptique(
        id: 'eval-mock-011',
        echantillonId: 'mock',
        tasteurId: 'D2',
        tasteurNom: 'Sara Mbarki',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-03-20T11:00:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.vert,
        amertume: 3.0,
        piquant: 3.0,
      ),
    ],
  ),
  // ── Propositions d'achat en attente de validation CEO ─────────────────────
  EchantillonCeoView(
    id: '2026/0012',
    referenceBouteille: 'CHEMLALI-K7',
    gouvernorat: 'Sfax',
    delegation: 'Kerkennah',
    fournisseurTexte: 'SF-22',
    variete: 'Chemlali',
    quantiteEstimee: '40',
    dateAjout: '18/05/2026',
    dateArriveeEchantillon: '19/05/2026 à 10h30',
    collecteurNom: 'Ahmed Dridi',
    recuPhysiquement: true,
    statut: StatutCeo.enNegociation,
    budgetNegociation: '8.20 DT/kg',
    camionReserve: '204 TN 5621',
    numCiterne: 'CT-9821',
    quantiteCibleT: '40',
    dateLivraisonStock: '23/05/2026 à 09h00',
    totalTasteurs: 5,
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-012',
        echantillonId: 'mock',
        tasteurId: 'D1',
        tasteurNom: 'Ali Ben Salem',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-05-19T10:30:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.vert,
        amertume: 3.0,
        piquant: 3.0,
      ),
    ],
  ),
  EchantillonCeoView(
    id: '2026/0013',
    referenceBouteille: 'CHETOUI-J3',
    gouvernorat: 'Béja',
    delegation: 'Téboursouk',
    fournisseurTexte: 'BJ-19',
    variete: 'Chetoui',
    quantiteEstimee: '28',
    dateAjout: '15/05/2026',
    dateArriveeEchantillon: '17/05/2026 à 14h00',
    collecteurNom: 'Sami Khaled',
    recuPhysiquement: true,
    statut: StatutCeo.enNegociation,
    budgetNegociation: '7.95 DT/kg',
    camionReserve: 'TRK-009',
    numCiterne: 'CT-9745',
    quantiteCibleT: '28',
    dateLivraisonStock: '24/05/2026 à 08h30',
    totalTasteurs: 5,
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-013',
        echantillonId: 'mock',
        tasteurId: 'D2',
        tasteurNom: 'Sara Mbarki',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-05-18T11:00:00Z',
        fruite: 3.5,
        typeFruite: TypeFruite.mur,
        amertume: 2.5,
        piquant: 3.0,
      ),
    ],
  ),
  EchantillonCeoView(
    id: '2026/0014',
    referenceBouteille: 'OUESLATI-M1',
    gouvernorat: 'Mahdia',
    delegation: 'Ksour Essaf',
    fournisseurTexte: 'MH-07',
    variete: 'Oueslati',
    quantiteEstimee: '15',
    dateAjout: '12/05/2026',
    dateArriveeEchantillon: '14/05/2026 à 09h45',
    collecteurNom: 'Mounir Zouaghi',
    recuPhysiquement: true,
    statut: StatutCeo.enNegociation,
    budgetNegociation: '8.50 DT/kg',
    camionReserve: 'TRK-002',
    // no numCiterne → exercises optional rendering
    quantiteCibleT: '15',
    dateLivraisonStock: '21/05/2026',
    dateLivraisonStockFin: '23/05/2026',
    totalTasteurs: 5,
    evaluations: [
      EvaluationOrganoleptique(
        id: 'eval-mock-014',
        echantillonId: 'mock',
        tasteurId: 'D1',
        tasteurNom: 'Ali Ben Salem',
        classification: ClassificationHuile.extraVierge,
        soumisLe: '2026-05-16T10:00:00Z',
        fruite: 4.0,
        typeFruite: TypeFruite.vert,
        amertume: 2.5,
        piquant: 3.0,
      ),
    ],
  ),

  // ── Stock non planifié : achat confirmé mais aucune date de livraison stock ──
  EchantillonCeoView(
    id: '2026/0011',
    referenceBouteille: 'NOURI-03',
    gouvernorat: 'Nabeul',
    delegation: 'Nabeul Nord',
    fournisseurTexte: 'NB-04',
    variete: 'Nouri',
    quantiteEstimee: '22',
    dateAjout: '10/04/2026',
    dateArriveeEchantillon: '14/04/2026 à 10h00',
    collecteurNom: 'Mounir Zouaghi',
    recuPhysiquement: true,
    statut: StatutCeo.achatConfirme,
    totalTasteurs: 5,
    budgetNegociation: '8.00 DT/kg',
    quantiteCibleT: '22',
    stockArrive: false,
    // no dateLivraisonStock → shows "Livraison du stock non encore planifiée"
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// DERIVED LISTS — each page filters mockEchantillons instead of owning data
// ─────────────────────────────────────────────────────────────────────────────

/// Used by analyse_organoleptique_ceo_page.dart
/// Only samples that have at least started the tasting process.
List<EchantillonCeoView> get mockEchantillonsOrganoleptique => mockEchantillons
    .where((e) => e.evaluations.isNotEmpty || e.statut == StatutCeo.selectionne)
    .toList();

/// Used by analyse_laboratoire_ceo_page.dart
/// All samples — labo page shows all with or without analysis.
List<EchantillonCeoView> get mockEchantillonsLabo => mockEchantillons;

/// Used by achats_confirmes_ceo_page.dart
/// Only confirmed purchases.
List<EchantillonCeoView> get mockAchatsConfirmes =>
    mockEchantillons.where((e) => e.statut == StatutCeo.achatConfirme).toList();

// ─────────────────────────────────────────────────────────────────────────────
// ALL USERS — used by utilisateurs_ceo_page.dart
// TODO: remove when backend is ready and replace with GET /api/users/
// ─────────────────────────────────────────────────────────────────────────────
final List<UserProfile> mockUtilisateurs = [
  UserProfile(
    id: 'U001',
    email: 'takwa.amara@aljazira.tn',
    role: RoleUtilisateur.direction,
    nom: 'Amara',
    prenom: 'Takwa',
    telephone: '+216 98 123 456',
    dateCreation: '2024-01-01',
  ),
  UserProfile(
    id: 'U002',
    email: 'mslim@aljazira.tn',
    role: RoleUtilisateur.laboratoire,
    nom: 'Slim',
    prenom: 'Mohamed',
    telephone: '+216 55 234 567',
    dateCreation: '2024-02-15',
  ),
  UserProfile(
    id: 'U003',
    email: 'ali.bensalem@aljazira.tn',
    role: RoleUtilisateur.degustateur,
    nom: 'Ben Salem',
    prenom: 'Ali',
    telephone: '+216 20 345 678',
    dateCreation: '2024-03-10',
  ),
  UserProfile(
    id: 'U004',
    email: 'sara.mbarki@aljazira.tn',
    role: RoleUtilisateur.degustateur,
    nom: 'Mbarki',
    prenom: 'Sara',
    telephone: '+216 22 456 789',
    dateCreation: '2024-03-10',
  ),
  UserProfile(
    id: 'U005',
    email: 'hedi.rjaibi@aljazira.tn',
    role: RoleUtilisateur.degustateur,
    nom: 'Rjaibi',
    prenom: 'Hedi',
    telephone: '+216 25 567 890',
    dateCreation: '2024-03-10',
    isActive: false,
  ),
  UserProfile(
    id: 'U006',
    email: 'ahmed.dridi@aljazira.tn',
    role: RoleUtilisateur.collecteur,
    nom: 'Dridi',
    prenom: 'Ahmed',
    telephone: '+216 50 678 901',
    dateCreation: '2024-02-01',
  ),
  UserProfile(
    id: 'U007',
    email: 'sami.khaled@aljazira.tn',
    role: RoleUtilisateur.collecteur,
    nom: 'Khaled',
    prenom: 'Sami',
    telephone: '+216 52 789 012',
    dateCreation: '2024-02-01',
  ),
  UserProfile(
    id: 'U008',
    email: 'mounir.z@aljazira.tn',
    role: RoleUtilisateur.collecteur,
    nom: 'Zouaghi',
    prenom: 'Mounir',
    telephone: '+216 54 890 123',
    dateCreation: '2024-02-15',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// DERIVED LISTS
// ─────────────────────────────────────────────────────────────────────────────

/// Active users only.
List<UserProfile> get mockUtilisateursActifs =>
    mockUtilisateurs.where((u) => u.isActive).toList();

/// Dégustateurs only — used by session planning.
List<UserProfile> get mockDegustateurs => mockUtilisateurs
    .where((u) => u.role == RoleUtilisateur.degustateur)
    .toList();

/// Collecteurs only — used by sample tracking.
List<UserProfile> get mockCollecteurs => mockUtilisateurs
    .where((u) => u.role == RoleUtilisateur.collecteur)
    .toList();
