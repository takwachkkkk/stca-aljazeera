import 'rapport_labo.dart';

enum StatutAnalyse { enAttente, enCours, soumise }

/// Une ligne de la liste « Analyse de laboratoire », commune aux deux rôles
/// de dégustation. Elle ne contient aucun chemin d'écriture du rapport.
class LigneAnalyseLabo {
  final String id;
  final String echantillonId;
  final String numero;
  final String referenceBouteille;
  final String echantillonNom;
  final String technicienNom;
  final StatutAnalyse statut;
  final String? fournisseurNom;
  final String? gouvernorat;
  final String? delegation;
  final String? collecteurNom;
  final String? variete;
  final String? quantiteEstimee;
  final String? dateAjout;
  final String? dateArriveeEchantillon;
  final String? dateReceptionEchantillon;
  final bool recuPhysiquement;
  final String? numCiterne;
  final String? dateLivraisonStock;
  final RapportLabo? rapport;

  const LigneAnalyseLabo({
    required this.id,
    required this.echantillonId,
    required this.numero,
    required this.referenceBouteille,
    required this.echantillonNom,
    required this.technicienNom,
    required this.statut,
    this.fournisseurNom,
    this.gouvernorat,
    this.delegation,
    this.collecteurNom,
    this.variete,
    this.quantiteEstimee,
    this.dateAjout,
    this.dateArriveeEchantillon,
    this.dateReceptionEchantillon,
    this.recuPhysiquement = false,
    this.numCiterne,
    this.dateLivraisonStock,
    this.rapport,
  });

  factory LigneAnalyseLabo.fromJson(Map<String, dynamic> json) {
    final rapportJson = json['rapport'] as Map<String, dynamic>?;
    return LigneAnalyseLabo(
      id: json['id'] as String,
      echantillonId: json['echantillon_id'] as String,
      numero: (json['numero'] ?? '').toString(),
      referenceBouteille: (json['echantillon_ref'] ?? '').toString(),
      echantillonNom: json['echantillon_nom'] as String,
      technicienNom: json['technicien_nom'] as String,
      statut: switch (json['statut']) {
        'soumise' || 'soumis' => StatutAnalyse.soumise,
        'en_cours' => StatutAnalyse.enCours,
        _ => StatutAnalyse.enAttente,
      },
      fournisseurNom: json['fournisseur_nom'] as String?,
      gouvernorat: json['gouvernorat'] as String?,
      delegation: json['delegation'] as String?,
      collecteurNom: json['collecteur_nom'] as String?,
      variete: json['variete'] as String?,
      quantiteEstimee: json['quantite_estimee'] as String?,
      dateAjout: json['date_ajout'] as String?,
      dateArriveeEchantillon: json['date_arrivee_echantillon'] as String?,
      dateReceptionEchantillon: json['date_reception_echantillon'] as String?,
      recuPhysiquement: json['recu_physiquement'] as bool? ?? false,
      numCiterne: json['num_citerne'] as String?,
      dateLivraisonStock: json['date_livraison_stock'] as String?,
      rapport: rapportJson == null ? null : RapportLabo.fromJson(rapportJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'echantillon_id': echantillonId,
    'numero': numero,
    'echantillon_ref': referenceBouteille,
    'echantillon_nom': echantillonNom,
    'technicien_nom': technicienNom,
    'statut': switch (statut) {
      StatutAnalyse.soumise => 'soumise',
      StatutAnalyse.enCours => 'en_cours',
      StatutAnalyse.enAttente => 'en_attente',
    },
    'fournisseur_nom': fournisseurNom,
    'gouvernorat': gouvernorat,
    'delegation': delegation,
    'collecteur_nom': collecteurNom,
    'variete': variete,
    'quantite_estimee': quantiteEstimee,
    'date_ajout': dateAjout,
    'date_arrivee_echantillon': dateArriveeEchantillon,
    'date_reception_echantillon': dateReceptionEchantillon,
    'recu_physiquement': recuPhysiquement,
    'num_citerne': numCiterne,
    'date_livraison_stock': dateLivraisonStock,
    'rapport': rapport?.toJson(),
  };
}
