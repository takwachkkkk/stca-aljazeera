// ═════════════════════════════════════════════════════════════════════════════
// FILE    : ceo/utilisateurs/models/echantillon_ceo_view.dart
// PURPOSE : CEO-specific view model — aggregates sample + evaluations + analysis
//           into one object for the CEO pages. All enums/types come from core.
// ═════════════════════════════════════════════════════════════════════════════

// Re-export core types so CEO pages only need to import this one file.
export '../../../../core/models/enums.dart'
    show ClassificationHuile, ClassificationHuileX, StatutCeo, StatutCeoX;

export '../../../../core/models/evaluation_organoleptique.dart';
export '../../../../core/analyses/rapport_labo.dart';
export '../../../../core/widgets/analyse_labo_sheet_adapter.dart';

import '../../../../core/analyses/rapport_labo.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/evaluation_organoleptique.dart';

// ── Sample view model ─────────────────────────────────────────────────────────
class EchantillonCeoView {
  final String id;
  final String numero;
  final String referenceBouteille;
  final String gouvernorat;
  final String? delegation;
  final String fournisseurTexte;
  final String? fournisseurNom;
  final String? numCiterne;
  final String? variete;
  final String? quantiteEstimee;
  final String dateAjout;
  final String? dateLivraisonPrevue;
  final String? dateArriveeEchantillon;
  final String? dateReceptionEchantillon;
  final String? collecteurNom;
  bool recuPhysiquement;
  StatutCeo statut;
  final int totalTasteurs;
  final List<EvaluationOrganoleptique> evaluations;
  final RapportLabo? analyse;
  String? raisonRefus;
  String? budgetNegociation;

  /// Borne haute quand la direction propose un intervalle plutôt qu'un prix
  /// ferme. Vide = prix unique.
  String? budgetNegociationMax;

  /// Nombre de fois que la direction a rouvert la négociation après un achat
  /// non conclu. Alimente le marqueur « Renégocié ×N » sur la carte.
  int nbRenegociations;
  String? dateLivraisonStockSouhaitee; // CEO's desired delivery date for stock
  String? quantiteCibleT;
  String? camionReserve;
  String? noteInterne;

  // Issue de la négociation, saisie par le collecteur.
  String? prixFinal;
  String? remarqueCollecteur;

  /// Raison facultative donnée par le collecteur quand l'achat n'aboutit pas.
  /// Distincte de [raisonRefus], qui est celle de la direction.
  String? raisonNonConclu;
  bool stockArrive;
  String? dateLivraisonStock;
  String? dateLivraisonStockFin; // end of range when stock delivery is a period
  String?
  dateLivraisonPrevueFin; // end of range when sample delivery is a period
  String? remarques;

  EchantillonCeoView({
    required this.id,
    String? numero,
    required this.referenceBouteille,
    required this.gouvernorat,
    this.delegation,
    required this.fournisseurTexte,
    this.fournisseurNom,
    this.numCiterne,
    this.variete,
    this.quantiteEstimee,
    required this.dateAjout,
    this.dateLivraisonPrevue,
    this.dateArriveeEchantillon,
    this.dateReceptionEchantillon,
    this.collecteurNom,
    this.recuPhysiquement = false,
    required this.statut,
    required this.totalTasteurs,
    this.evaluations = const [],
    this.analyse,
    this.raisonRefus,
    this.budgetNegociation,
    this.budgetNegociationMax,
    this.nbRenegociations = 0,
    this.dateLivraisonStockSouhaitee,
    this.quantiteCibleT,
    this.camionReserve,
    this.noteInterne,
    this.prixFinal,
    this.remarqueCollecteur,
    this.raisonNonConclu,
    this.stockArrive = false,
    this.dateLivraisonStock,
    this.dateLivraisonStockFin,
    this.dateLivraisonPrevueFin,
    this.remarques,
  }) : numero = numero ?? id;

  int get nombreEvaluations => evaluations.length;
  bool get tousEvalue => evaluations.length >= totalTasteurs;
  String get fournisseurAffichage {
    final nom = fournisseurNom?.trim() ?? '';
    if (nom.isNotEmpty) return nom;
    return fournisseurTexte.trim();
  }

  ClassificationHuile? get classificationMajoritaire {
    if (evaluations.isEmpty) return null;
    final counts = <ClassificationHuile, int>{};
    for (final e in evaluations) {
      counts[e.classification] = (counts[e.classification] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
