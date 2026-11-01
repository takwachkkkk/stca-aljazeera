// ═════════════════════════════════════════════════════════════════════════════
// FILE : collecteur/mes_echantillons/models/echantillon_collecteur.dart
// ═════════════════════════════════════════════════════════════════════════════

export '../../../../../core/models/enums.dart' show StatutCollecteur;
import '../../../../../core/models/enums.dart'
    show StatutCollecteur, StatutCollecteurX;

// ── Display helpers (used by model and UI layers) ─────────────────────────────
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtDateHeure(DateTime d) {
  final base = fmtDate(d);
  if (d.hour == 0 && d.minute == 0) return base;
  return '$base à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANIFICATION LIVRAISON — stock delivery scheduling (post achatConfirme)
// ─────────────────────────────────────────────────────────────────────────────
class PlanificationLivraison {
  final DateTime? dateExacte;
  final String heure;
  final String lieu;
  final String? camion;

  PlanificationLivraison._({
    this.dateExacte,
    required this.heure,
    required this.lieu,
    this.camion,
  });

  factory PlanificationLivraison.exact({
    required DateTime date,
    required String heure,
    required String lieu,
    String? camion,
  }) => PlanificationLivraison._(
    dateExacte: date,
    heure: heure,
    lieu: lieu,
    camion: camion,
  );

  factory PlanificationLivraison.fromJson(Map<String, dynamic> json) =>
      PlanificationLivraison._(
        dateExacte: json['date_exacte'] != null
            ? DateTime.parse(json['date_exacte'] as String)
            : null,
        heure: json['heure'] as String? ?? '',
        lieu: json['lieu'] as String? ?? '',
        camion: json['camion'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'date_exacte': dateExacte?.toIso8601String(),
    'heure': heure,
    'lieu': lieu,
    'camion': camion,
  };

  bool get isComplete => dateExacte != null && heure.isNotEmpty;

  String get libelle {
    final parts = <String>[];
    if (dateExacte != null) parts.add(fmtDate(dateExacte!));
    if (heure.isNotEmpty) parts.add(heure);
    if (lieu.isNotEmpty) parts.add(lieu);
    return parts.join('  ·  ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHAT SAISI — ce que le collecteur remplit en concluant l'achat
// ─────────────────────────────────────────────────────────────────────────────
class AchatSaisi {
  final String prixFinal;
  final String remarqueCollecteur;
  final String? numCiterne;

  /// Date exacte, ou début de la période de livraison du stock.
  final DateTime? livraisonDebut;

  /// Fin de la période ; vide pour une date exacte.
  final DateTime? livraisonFin;

  const AchatSaisi({
    required this.prixFinal,
    required this.remarqueCollecteur,
    this.numCiterne,
    this.livraisonDebut,
    this.livraisonFin,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ECHANTILLON COLLECTEUR
// ─────────────────────────────────────────────────────────────────────────────
class EchantillonCollecteur {
  String id;
  String numero;

  // Location
  String gouvernorat;
  String? delegation;
  String? cite;

  // Supplier
  // The link to the reference entry. Without it the sample reaches the database
  // with no supplier at all, and the CEO dashboard — which aggregates purchases
  // per supplier — has nothing to count it under.
  String? fournisseurId;
  String fournisseurTexte;
  // Supplier name displayed by the app and sent on create/update so the backend
  // can match by name without a separate supplier creation request.
  String? fournisseurNom;

  // Bottle
  String referenceBouteille;
  String? numCiterne;
  String? quantiteEstimee;
  String? variete;

  // Purchase
  bool achatConfirme;
  PlanificationLivraison? livraison;

  // Sample delivery date (when the bottle is expected at the company)
  DateTime? dateArriveeEchantillon;

  // Physical receipt (set by taster when sample arrives at company)
  bool recuPhysiquement;
  DateTime? dateReceptionEchantillon;

  // Negotiation details (communicated by CEO after approval)
  String? budgetNegociation;
  String? quantiteCibleT;
  // Stock delivery window desired by CEO — may be a range or a single date
  DateTime? dateStockSouhaiteeDebut;
  DateTime? dateStockSouhaiteeFin;

  // Confirmed purchase details (filled by collector when confirming)
  String? prixFinal;
  String? camionLivraison;
  String? remarqueCollecteur;

  // Metadata
  String? remarques;
  DateTime dateAjout;

  String? imageUrl;
  String collecteurId;
  String collecteurNom;

  // Status
  StatutCollecteur statut;

  EchantillonCollecteur({
    required this.id,
    required this.numero,
    required this.gouvernorat,
    this.delegation,
    this.cite,
    this.fournisseurId,
    required this.fournisseurTexte,
    this.fournisseurNom,
    required this.referenceBouteille,
    this.numCiterne,
    this.quantiteEstimee,
    this.variete,
    required this.achatConfirme,
    this.livraison,
    this.dateArriveeEchantillon,
    this.recuPhysiquement = false,
    this.dateReceptionEchantillon,
    this.budgetNegociation,
    this.quantiteCibleT,
    this.dateStockSouhaiteeDebut,
    this.dateStockSouhaiteeFin,
    this.prixFinal,
    this.camionLivraison,
    this.remarqueCollecteur,
    this.remarques,
    required this.dateAjout,
    this.imageUrl,
    required this.collecteurId,
    required this.collecteurNom,
    required this.statut,
  });

  static StatutCollecteur _statutFromJson(dynamic value) {
    final raw = value as String? ?? 'receptionne';
    switch (raw) {
      case 'enNegociation':
        return StatutCollecteur.enNegociation;
      case 'achatConfirme':
        return StatutCollecteur.achatConfirme;
      case 'achatNonConclu':
        return StatutCollecteur.achatNonConclu;
      default:
        try {
          return StatutCollecteurX.fromJson(raw);
        } catch (_) {
          return StatutCollecteur.receptionne;
        }
    }
  }

  factory EchantillonCollecteur.fromJson(Map<String, dynamic> json) =>
      EchantillonCollecteur(
        id: json['id'] as String,
        numero: json['numero'] as String,
        gouvernorat: json['gouvernorat'] as String,
        delegation: json['delegation'] as String?,
        cite: json['cite'] as String?,
        fournisseurId: json['fournisseur']?.toString(),
        fournisseurNom: json['fournisseur_nom'] as String?,
        fournisseurTexte: json['fournisseur_nom'] as String? ?? '',
        referenceBouteille: json['reference_bouteille'] as String? ?? '',
        numCiterne: json['num_citerne'] as String?,
        quantiteEstimee: json['quantite_estimee'] as String?,
        variete: json['variete'] as String?,
        achatConfirme:
            (json['statut_collecteur'] == 'achat_confirme' ||
            json['statut_collecteur'] == 'achatConfirme'),
        livraison: json['livraison'] is Map<String, dynamic>
            ? PlanificationLivraison.fromJson(
                json['livraison'] as Map<String, dynamic>,
              )
            : null,
        dateArriveeEchantillon: json['date_arrivee_echantillon'] != null
            ? DateTime.parse(json['date_arrivee_echantillon'] as String)
            : null,
        recuPhysiquement: json['recu_physiquement'] as bool? ?? false,
        dateReceptionEchantillon: json['date_reception_echantillon'] != null
            ? DateTime.parse(json['date_reception_echantillon'] as String)
            : null,
        budgetNegociation: json['budget_negociation']?.toString(),
        quantiteCibleT: json['quantite_cible_t']?.toString(),
        dateStockSouhaiteeDebut: null,
        dateStockSouhaiteeFin: null,
        prixFinal: json['prix_final']?.toString(),
        camionLivraison: json['camion_reserve'] as String?,
        remarqueCollecteur: json['remarque_collecteur'] as String?,
        remarques: json['remarques'] as String?,
        dateAjout: DateTime.parse(json['date_ajout'] as String),
        imageUrl: json['image_url'] as String?,
        collecteurId: json['collecteur']?.toString() ?? '',
        collecteurNom: json['collecteur_nom'] as String? ?? '',
        statut: _statutFromJson(json['statut_collecteur']),
      );

  Map<String, dynamic> toJson() => {
    // Sent as the FK Django expects. Null is accepted by the API, but a null
    // here is exactly the sample the dashboard cannot attribute to anyone.
    'fournisseur': fournisseurId,
    'gouvernorat': gouvernorat,
    'delegation': delegation ?? '',
    'cite': cite ?? '',
    'reference_bouteille': referenceBouteille,
    'num_citerne': numCiterne ?? '',
    'quantite_estimee': quantiteEstimee ?? '',
    'variete': variete ?? '',
    'statut_collecteur': statut.toJson,
    'date_arrivee_echantillon': dateArriveeEchantillon?.toIso8601String(),
    'recu_physiquement': recuPhysiquement,
    'budget_negociation': budgetNegociation,
    'quantite_cible_t': quantiteCibleT,
    'prix_final': prixFinal,
    'camion_reserve': camionLivraison ?? '',
    'remarque_collecteur': remarqueCollecteur ?? '',
    'remarques': remarques ?? '',
    'image_url': imageUrl ?? '',
  };

  // Handles Django paginated format: { "count": N, "results": [...] }
  static List<EchantillonCollecteur> fromJsonList(Map<String, dynamic> json) =>
      (json['results'] as List)
          .map((e) => EchantillonCollecteur.fromJson(e as Map<String, dynamic>))
          .toList();

  // Once the bottle is physically at the company the collector loses every
  // write right on it — no edit, no delete. Corrections then go through the
  // head taster or the taster, who edit with the change kept on record.
  bool get canModify =>
      statut == StatutCollecteur.receptionne && !recuPhysiquement;
  bool get canDelete =>
      statut == StatutCollecteur.receptionne && !recuPhysiquement;
  bool get canConfirm => statut == StatutCollecteur.enNegociation;
  bool get canPlanifier => statut == StatutCollecteur.achatConfirme;
  String get fournisseurAffichage {
    final nom = fournisseurNom?.trim() ?? '';
    if (nom.isNotEmpty) return nom;
    return fournisseurTexte.trim();
  }

  bool get canScheduleArrivee =>
      statut == StatutCollecteur.receptionne && !recuPhysiquement;
}
