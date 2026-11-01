// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 6_service_achat/achats/models/achat_service_achat.dart
// PURPOSE : Un achat confirmé tel que le Service achat le voit — produit,
//           fournisseur, quantité, prix, livraison prévue. Aucune donnée de
//           dégustation ni de laboratoire (le serveur ne les envoie pas).
// ═════════════════════════════════════════════════════════════════════════════

import '../../../core/utils/json_utils.dart';

/// Où en est la livraison du stock, d'après la date prévue.
enum EtatLivraison { aVenir, enRetard, livre, sansDate }

class AchatServiceAchat {
  final String id;
  final String numero;
  final String referenceBouteille;
  final String? fournisseurNom;
  final String? fournisseurLieu;
  final String gouvernorat;
  final String? delegation;
  final String? cite;
  final String? variete;
  final String? numCiterne;
  final String? collecteurNom;
  final double? quantiteCibleT;
  final double? prixFinal;
  final double? budgetNegociation;
  final String? camionReserve;
  final String? remarqueCollecteur;
  final DateTime? dateLivraisonPrevue;
  final DateTime? dateLivraisonPrevueFin;
  final bool stockArrive;
  final bool facture;
  final DateTime? dateFacture;
  final String? factureParNom;
  final DateTime? dateEnregistrement;
  final String? imageUrl;

  const AchatServiceAchat({
    required this.id,
    required this.numero,
    required this.referenceBouteille,
    this.fournisseurNom,
    this.fournisseurLieu,
    required this.gouvernorat,
    this.delegation,
    this.cite,
    this.variete,
    this.numCiterne,
    this.collecteurNom,
    this.quantiteCibleT,
    this.prixFinal,
    this.budgetNegociation,
    this.camionReserve,
    this.remarqueCollecteur,
    this.dateLivraisonPrevue,
    this.dateLivraisonPrevueFin,
    this.stockArrive = false,
    this.facture = false,
    this.dateFacture,
    this.factureParNom,
    this.dateEnregistrement,
    this.imageUrl,
  });

  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory AchatServiceAchat.fromJson(Map<String, dynamic> json) =>
      AchatServiceAchat(
        id: json['id'] as String,
        numero: json['numero'] as String? ?? '',
        referenceBouteille: json['reference_bouteille'] as String? ?? '',
        fournisseurNom: json['fournisseur_nom'] as String?,
        fournisseurLieu: json['fournisseur_lieu'] as String?,
        gouvernorat: json['gouvernorat'] as String? ?? '',
        delegation: json['delegation'] as String?,
        cite: json['cite'] as String?,
        variete: json['variete'] as String?,
        numCiterne: json['num_citerne'] as String?,
        collecteurNom: json['collecteur_nom'] as String?,
        quantiteCibleT: nombreDepuisJson(json['quantite_cible_t']),
        prixFinal: nombreDepuisJson(json['prix_final']),
        budgetNegociation: nombreDepuisJson(json['budget_negociation']),
        camionReserve: json['camion_reserve'] as String?,
        remarqueCollecteur: json['remarque_collecteur'] as String?,
        dateLivraisonPrevue: _date(json['date_livraison_prevue']),
        dateLivraisonPrevueFin: _date(json['date_livraison_prevue_fin']),
        stockArrive: json['stock_arrive'] as bool? ?? false,
        facture: json['facture'] as bool? ?? false,
        dateFacture: _date(json['date_facture']),
        factureParNom: json['facture_par_nom'] as String?,
        dateEnregistrement: _date(json['date_enregistrement']),
        imageUrl: json['image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'numero': numero,
    'reference_bouteille': referenceBouteille,
    'fournisseur_nom': fournisseurNom,
    'fournisseur_lieu': fournisseurLieu,
    'gouvernorat': gouvernorat,
    'delegation': delegation,
    'cite': cite,
    'variete': variete,
    'num_citerne': numCiterne,
    'collecteur_nom': collecteurNom,
    'quantite_cible_t': quantiteCibleT,
    'prix_final': prixFinal,
    'budget_negociation': budgetNegociation,
    'camion_reserve': camionReserve,
    'remarque_collecteur': remarqueCollecteur,
    'date_livraison_prevue': dateLivraisonPrevue?.toIso8601String(),
    'date_livraison_prevue_fin': dateLivraisonPrevueFin?.toIso8601String(),
    'stock_arrive': stockArrive,
    'facture': facture,
    'date_facture': dateFacture?.toIso8601String(),
    'facture_par_nom': factureParNom,
    'date_enregistrement': dateEnregistrement?.toIso8601String(),
    'image_url': imageUrl,
  };

  /// « hami — Gabès » : deux fournisseurs homonymes se distinguent par le lieu.
  String get fournisseurAffichage {
    final nom = fournisseurNom ?? '';
    if (nom.isEmpty) return '—';
    final lieu = fournisseurLieu ?? '';
    return lieu.isEmpty ? nom : '$nom — $lieu';
  }

  /// Le prix final s'il existe, sinon le prix négocié.
  double? get prix => prixFinal ?? budgetNegociation;

  /// Dernier jour prévu : la fin de la période, sinon la date exacte.
  DateTime? get _dernierJourPrevu =>
      dateLivraisonPrevueFin ?? dateLivraisonPrevue;

  EtatLivraison etatLivraison(DateTime maintenant) {
    if (stockArrive) return EtatLivraison.livre;
    final fin = _dernierJourPrevu;
    if (fin == null) return EtatLivraison.sansDate;
    final aujourdhui = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );
    final jourFin = DateTime(fin.year, fin.month, fin.day);
    return jourFin.isBefore(aujourdhui)
        ? EtatLivraison.enRetard
        : EtatLivraison.aVenir;
  }
}
