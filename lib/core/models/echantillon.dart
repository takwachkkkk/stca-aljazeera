// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/models/echantillon.dart
// PURPOSE : Canonical sample model — matches the `echantillons` table exactly.
//           All four roles work with this single class. Each role reads only
//           the fields relevant to its view; unused fields are simply null.
//
//           Field naming: snake_case in JSON to match Django serializer output.
// ═════════════════════════════════════════════════════════════════════════════

import 'enums.dart';
import 'package:project3/core/utils/json_utils.dart';

class Echantillon {
  // ── Primary key & display reference ──────────────────────────────────────────
  final String id; // UUID — backend primary key, opaque to the UI
  String numero; // "2026/0001" — sequential human-readable reference

  // ── Foreign keys (UUIDs) ─────────────────────────────────────────────────────
  final String fournisseurId;
  final String collecteurId;

  // ── Denormalized display fields (returned by the API, not stored separately) ──
  // These are read-only annotations on the API response — never sent on POST/PUT.
  final String? fournisseurTexte; // e.g. "SF-42" — shown in list cards
  final String? fournisseurNom; // supplier's full name
  final String? collecteurNom; // collector's full name

  // ── Location ──────────────────────────────────────────────────────────────────
  String gouvernorat;
  String? delegation;
  String? cite;

  // ── Bottle identity ───────────────────────────────────────────────────────────
  String referenceBouteille; // written on the physical bottle label
  String? numCiterne; // tank number
  String? variete; // olive variety, e.g. "Chemlali"
  String? quantiteEstimee; // estimated batch in tonnes, e.g. "25"

  /// Photo picked in the form and not sent yet. Never read from or written to
  /// JSON: the service sends it as a file with the create / edit request.
  List<int>? photoAEnvoyer;
  String? photoNomFichier;
  String? imageUrl;

  // ── Per-role statuses ─────────────────────────────────────────────────────────
  // Each role sees only its own status field; the others may be null.
  StatutCollecteur statutCollecteur;
  StatutDegustateur? statutDegustateur;
  StatutLabo? statutLabo;
  StatutCeo? statutCeo;

  // ── Physical reception ────────────────────────────────────────────────────────
  bool recuPhysiquement; // true once bottle arrives at company
  String? dateArriveeEchantillon; // ISO 8601 — planned sample delivery
  String? dateReceptionEchantillon; // ISO 8601 — physical reception timestamp

  // ── CEO negotiation & purchase fields ────────────────────────────────────────
  double? budgetNegociation; // negotiation budget in TND/L
  double? quantiteCibleT; // target quantity in tonnes
  String? camionReserve; // truck ID reserved for transport
  String? noteInterne; // internal note — Direction only
  String? raisonRefus; // reason for rejection — Direction only
  bool stockArrive; // true once full stock is delivered
  String? dateLivraisonStock; // ISO 8601 — expected/actual stock delivery date

  // ── Final classification ──────────────────────────────────────────────────────
  ClassificationHuile? classification; // set once tasters reach consensus

  // ── Shared notes ──────────────────────────────────────────────────────────────
  String? remarques;
  final String? remarqueCollecteur; // collector's purchase remark — read-only here
  final bool modifiable;

  // ── Timestamps ────────────────────────────────────────────────────────────────
  final String dateAjout; // ISO 8601 — set by the server on creation
  String? updatedAt; // ISO 8601 — updated on every save

  Echantillon({
    required this.id,
    required this.numero,
    required this.fournisseurId,
    required this.collecteurId,
    this.fournisseurTexte,
    this.fournisseurNom,
    this.collecteurNom,
    required this.gouvernorat,
    this.delegation,
    this.cite,
    required this.referenceBouteille,
    this.numCiterne,
    this.variete,
    this.quantiteEstimee,
    this.imageUrl,
    required this.statutCollecteur,
    this.statutDegustateur,
    this.statutLabo,
    this.statutCeo,
    this.recuPhysiquement = false,
    this.dateArriveeEchantillon,
    this.dateReceptionEchantillon,
    this.budgetNegociation,
    this.quantiteCibleT,
    this.camionReserve,
    this.noteInterne,
    this.raisonRefus,
    this.stockArrive = false,
    this.dateLivraisonStock,
    this.classification,
    this.remarques,
    this.remarqueCollecteur,
    this.modifiable = false,
    required this.dateAjout,
    this.updatedAt,
  });

  // ── Collector convenience getters ─────────────────────────────────────────────
  // Physical reception ends the collector's write rights: he can neither edit
  // nor delete.
  bool get canModify =>
      statutCollecteur == StatutCollecteur.receptionne && !recuPhysiquement;
  bool get canDelete =>
      statutCollecteur == StatutCollecteur.receptionne && !recuPhysiquement;
  bool get canNegocier => statutCollecteur == StatutCollecteur.enNegociation;
  bool get canPlanifier => statutCollecteur == StatutCollecteur.achatConfirme;
  String get fournisseurAffichage {
    final nom = fournisseurNom?.trim() ?? '';
    if (nom.isNotEmpty) return nom;
    return fournisseurTexte?.trim() ?? '';
  }

  // ── Serialization ─────────────────────────────────────────────────────────────
  factory Echantillon.fromJson(Map<String, dynamic> json) => Echantillon(
    id: json['id'] as String,
    numero: json['numero'] as String,
    fournisseurId: json['fournisseur_id'] as String,
    collecteurId: json['collecteur_id'] as String,
    fournisseurTexte: json['fournisseur_nom'] as String?,
    fournisseurNom: json['fournisseur_nom'] as String?,
    collecteurNom: json['collecteur_nom'] as String?,
    gouvernorat: json['gouvernorat'] as String,
    delegation: json['delegation'] as String?,
    cite: json['cite'] as String?,
    referenceBouteille: json['reference_bouteille'] as String,
    numCiterne: json['num_citerne'] as String?,
    variete: json['variete'] as String?,
    quantiteEstimee: json['quantite_estimee'] as String?,
    imageUrl: json['image_url'] as String?,
    statutCollecteur: StatutCollecteurX.fromJson(
      json['statut_collecteur'] as String,
    ),
    statutDegustateur: json['statut_degustateur'] != null
        ? StatutDegustateurX.fromJson(json['statut_degustateur'] as String)
        : null,
    statutLabo: json['statut_labo'] != null
        ? StatutLaboX.fromJson(json['statut_labo'] as String)
        : null,
    statutCeo: json['statut_ceo'] != null
        ? StatutCeoX.fromJson(json['statut_ceo'] as String)
        : null,
    recuPhysiquement: (json['recu_physiquement'] as bool?) ?? false,
    dateArriveeEchantillon: json['date_arrivee_echantillon'] as String?,
    dateReceptionEchantillon: json['date_reception_echantillon'] as String?,
    budgetNegociation: nombreDepuisJson(json['budget_negociation']),
    quantiteCibleT: nombreDepuisJson(json['quantite_cible_t']),
    camionReserve: json['camion_reserve'] as String?,
    noteInterne: json['note_interne'] as String?,
    raisonRefus: json['raison_refus'] as String?,
    stockArrive: (json['stock_arrive'] as bool?) ?? false,
    dateLivraisonStock: json['date_livraison_stock'] as String?,
    // The server sends '' for a sample not classified yet: same as null.
    classification: (json['classification'] as String?)?.isNotEmpty == true
        ? ClassificationHuileX.fromJson(json['classification'] as String)
        : null,
    remarques: json['remarques'] as String?,
    remarqueCollecteur: json['remarque_collecteur'] as String?,
    modifiable: (json['modifiable'] as bool?) ?? false,
    dateAjout: json['date_ajout'] as String,
    updatedAt: json['updated_at'] as String?,
  );

  /// For paginated Django list responses: { "count": N, "results": [...] }
  static List<Echantillon> fromJsonList(Map<String, dynamic> json) =>
      (json['results'] as List).map((e) => Echantillon.fromJson(e)).toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'numero': numero,
    'fournisseur_id': fournisseurId,
    'collecteur_id': collecteurId,
    'gouvernorat': gouvernorat,
    'delegation': delegation,
    'cite': cite,
    'reference_bouteille': referenceBouteille,
    'num_citerne': numCiterne,
    'variete': variete,
    'quantite_estimee': quantiteEstimee,
    'image_url': imageUrl,
    'statut_collecteur': statutCollecteur.toJson,
    'statut_degustateur': statutDegustateur?.toJson,
    'statut_labo': statutLabo?.toJson,
    'statut_ceo': statutCeo?.toJson,
    'recu_physiquement': recuPhysiquement,
    'date_arrivee_echantillon': dateArriveeEchantillon,
    'date_reception_echantillon': dateReceptionEchantillon,
    'budget_negociation': budgetNegociation,
    'quantite_cible_t': quantiteCibleT,
    'camion_reserve': camionReserve,
    'note_interne': noteInterne,
    'raison_refus': raisonRefus,
    'stock_arrive': stockArrive,
    'date_livraison_stock': dateLivraisonStock,
    'classification': classification?.toJson,
    'remarques': remarques,
    'remarque_collecteur': remarqueCollecteur,
    'modifiable': modifiable,
    'date_ajout': dateAjout,
    'updated_at': updatedAt,
    // Note: fournisseurTexte, fournisseurNom, collecteurNom are read-only
    // API annotations — not sent on POST/PUT.
  };
}
