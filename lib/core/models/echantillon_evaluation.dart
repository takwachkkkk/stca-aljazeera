// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/models/echantillon_evaluation.dart
// PURPOSE : One sample as it appears in an evaluation list.
//
//           Shared by the taster (3_degustateur) and the head taster
//           (5_chef_degustateur): same fields, same screen, same job — so one
//           file, not one per module.
//
//           This used to be duplicated in both modules. The copies drifted: the
//           taster's parser was taught to read lowercase statuses, the head
//           taster's copy never got the fix, and every submitted evaluation
//           showed as "En attente" on his screen. Merged here so a fix lands
//           once and reaches both screens.
//
//           Not to be confused with core/models/echantillon.dart, which is the
//           full sample record. This one is the lighter evaluation-list view.
// ═════════════════════════════════════════════════════════════════════════════

enum StatutEchantillon { enAttente, enCours, soumis }

class Echantillon {
  final String id;
  final String referenceBouteille;
  final String? numero; // sample number shown to people, e.g. 2026/0012
  final String fournisseur;
  final String dateArriveeEchantillon;
  final String? dateAjout;
  final String? dateReceptionEchantillon;
  final String variete;
  final String? gouvernorat; // Tunisian governorate (replaces origine)
  final String? delegation; // sub-region — optional, cascades from gouvernorat
  final String? cite; // precise place — optional free text
  final String? photoUrl;
  final String? quantite; // quantity in tonnes
  final String? collecteur; // collector name — optional
  final bool recuPhysiquement;
  final String? numCiterne;
  final String? dateLivraisonStock;
  StatutEchantillon statut; // not final — statut can change
  String? classification; // set when soumis (e.g. 'Extra Vierge', 'Vierge')

  Echantillon({
    required this.id,
    required this.referenceBouteille,
    this.numero,
    required this.fournisseur,
    required this.dateArriveeEchantillon,
    this.dateAjout,
    this.dateReceptionEchantillon,
    required this.variete,
    this.gouvernorat,
    this.delegation,
    this.cite,
    this.photoUrl,
    this.quantite,
    this.collecteur,
    this.recuPhysiquement = false,
    this.numCiterne,
    this.dateLivraisonStock,
    required this.statut,
    this.classification,
  });

  factory Echantillon.fromJson(Map<String, dynamic> json) {
    return Echantillon(
      id: json['id'] as String,
      referenceBouteille: json['reference_bouteille'] as String,
      numero: json['numero'] as String?,
      fournisseur: json['fournisseur'] as String,
      dateArriveeEchantillon: json['date_arrivee_echantillon'] as String,
      dateAjout: json['date_ajout'] as String?,
      dateReceptionEchantillon: json['date_reception_echantillon'] as String?,
      variete: json['variete'] as String,
      gouvernorat: json['gouvernorat'] as String?,
      delegation: json['delegation'] as String?,
      cite: json['cite'] as String?,
      photoUrl: json['photo_url'] as String?,
      quantite: json['quantite'] as String?,
      collecteur: json['collecteur'] as String?,
      recuPhysiquement: json['recu_physiquement'] as bool? ?? false,
      numCiterne: json['num_citerne'] as String?,
      dateLivraisonStock: json['date_livraison_stock'] as String?,
      statut: _parseStatut(json['statut'] as String),
      classification: json['classification'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference_bouteille': referenceBouteille,
    'fournisseur': fournisseur,
    'date_ajout': dateAjout,
    'date_arrivee_echantillon': dateArriveeEchantillon,
    'date_reception_echantillon': dateReceptionEchantillon,
    'variete': variete,
    'gouvernorat': gouvernorat,
    'delegation': delegation,
    'cite': cite,
    'photo_url': photoUrl,
    'quantite': quantite,
    'collecteur': collecteur,
    'recu_physiquement': recuPhysiquement,
    'num_citerne': numCiterne,
    'date_livraison_stock': dateLivraisonStock,
    'statut': _statutToString(statut),
    'classification': classification,
  };

  /// Accepts both spellings on purpose. Django stores lowercase
  /// (`evaluations.models.Statut`: 'en_cours' / 'soumis'), but uppercase shows up
  /// in older payloads and in mock data — reading only one of the two is what
  /// caused the head taster's screen to report everything as "En attente".
  static StatutEchantillon _parseStatut(String s) {
    switch (s) {
      case 'en_cours':
      case 'EN_COURS':
        return StatutEchantillon.enCours;
      case 'soumis':
      case 'SOUMIS':
        return StatutEchantillon.soumis;
      case 'non_evaluee':
      case 'en_attente':
      case 'EN_ATTENTE':
      default:
        return StatutEchantillon.enAttente;
    }
  }

  /// Lowercase, to match what Django expects and what the services already send.
  static String _statutToString(StatutEchantillon s) {
    switch (s) {
      case StatutEchantillon.enCours:
        return 'en_cours';
      case StatutEchantillon.soumis:
        return 'soumis';
      default:
        return 'en_attente';
    }
  }
}
