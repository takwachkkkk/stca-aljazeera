// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 5_chef_degustateur/panel_coi/resultat_panel.dart
// PURPOSE : Résultat du panel par échantillon, méthode du fichier COI_CALC du
//           COI : médiane de chaque attribut sur tous les dégustateurs, CVr %
//           (fiable sous 20 %), intervalle à 95 %, catégorie de l'échantillon.
//           Tout est calculé par le serveur (/api/chef/panel-coi/).
// ═════════════════════════════════════════════════════════════════════════════

import '../../core/api_client.dart';
import '../../core/models/enums.dart';
import '../../core/utils/json_utils.dart';

class StatistiqueAttribut {
  final String champ;
  final String libelle;
  final bool positif;
  final double mediane;
  final double moyenne;
  final double? ecartType;
  final double iqr;
  final double? cvr;
  final double icBas;
  final double icHaut;

  const StatistiqueAttribut({
    required this.champ,
    required this.libelle,
    required this.positif,
    required this.mediane,
    required this.moyenne,
    this.ecartType,
    required this.iqr,
    this.cvr,
    required this.icBas,
    required this.icHaut,
  });

  factory StatistiqueAttribut.fromJson(Map<String, dynamic> json) =>
      StatistiqueAttribut(
        champ: json['champ'] as String,
        libelle: json['libelle'] as String,
        positif: json['positif'] as bool? ?? false,
        mediane: nombreDepuisJson(json['mediane']) ?? 0,
        moyenne: nombreDepuisJson(json['moyenne']) ?? 0,
        ecartType: nombreDepuisJson(json['ecart_type']),
        iqr: nombreDepuisJson(json['iqr']) ?? 0,
        cvr: nombreDepuisJson(json['cvr']),
        icBas: nombreDepuisJson(json['ic_bas']) ?? 0,
        icHaut: nombreDepuisJson(json['ic_haut']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'champ': champ,
    'libelle': libelle,
    'positif': positif,
    'mediane': mediane,
    'moyenne': moyenne,
    'ecart_type': ecartType,
    'iqr': iqr,
    'cvr': cvr,
    'ic_bas': icBas,
    'ic_haut': icHaut,
  };
}

class ResultatPanel {
  final String echantillonId;
  final String? numero;
  final String referenceBouteille;
  final String? variete;
  final String? gouvernorat;
  final DateTime? derniereSoumission;
  final int nombreDegustateurs;
  final List<StatistiqueAttribut> attributs;
  final String? defautPrincipal;
  final double medianeDefautPrincipal;
  final double medianeFruite;

  /// Catégorie COI tirée des médianes ; null si rien n'a été perçu.
  final ClassificationHuile? classification;
  final bool fiable;
  final double cvrMax;
  final TypeFruite? typeFruiteMajoritaire;

  const ResultatPanel({
    required this.echantillonId,
    this.numero,
    required this.referenceBouteille,
    this.variete,
    this.gouvernorat,
    this.derniereSoumission,
    required this.nombreDegustateurs,
    required this.attributs,
    this.defautPrincipal,
    required this.medianeDefautPrincipal,
    required this.medianeFruite,
    this.classification,
    required this.fiable,
    required this.cvrMax,
    this.typeFruiteMajoritaire,
  });

  factory ResultatPanel.fromJson(Map<String, dynamic> json) {
    final classification = json['classification'] as String?;
    final type = json['type_fruite_majoritaire'] as String?;
    return ResultatPanel(
      echantillonId: json['echantillon_id'] as String,
      numero: json['numero'] as String?,
      referenceBouteille: json['reference_bouteille'] as String? ?? '',
      variete: json['variete'] as String?,
      gouvernorat: json['gouvernorat'] as String?,
      derniereSoumission: DateTime.tryParse(
        json['derniere_soumission'] as String? ?? '',
      )?.toLocal(),
      nombreDegustateurs: json['nombre_degustateurs'] as int? ?? 0,
      attributs: ((json['attributs'] as List<dynamic>?) ?? const [])
          .map((a) => StatistiqueAttribut.fromJson(a as Map<String, dynamic>))
          .toList(),
      defautPrincipal: json['defaut_principal'] as String?,
      medianeDefautPrincipal:
          nombreDepuisJson(json['mediane_defaut_principal']) ?? 0,
      medianeFruite: nombreDepuisJson(json['mediane_fruite']) ?? 0,
      classification: classification == null
          ? null
          : ClassificationHuileX.fromJson(classification),
      fiable: json['fiable'] as bool? ?? false,
      cvrMax: nombreDepuisJson(json['cvr_max']) ?? 20,
      typeFruiteMajoritaire: type == null ? null : TypeFruiteX.fromJson(type),
    );
  }

  Map<String, dynamic> toJson() => {
    'echantillon_id': echantillonId,
    'numero': numero,
    'reference_bouteille': referenceBouteille,
    'variete': variete,
    'gouvernorat': gouvernorat,
    'derniere_soumission': derniereSoumission?.toIso8601String(),
    'nombre_degustateurs': nombreDegustateurs,
    'attributs': attributs.map((a) => a.toJson()).toList(),
    'defaut_principal': defautPrincipal,
    'mediane_defaut_principal': medianeDefautPrincipal,
    'mediane_fruite': medianeFruite,
    'classification': classification?.toJson,
    'fiable': fiable,
    'cvr_max': cvrMax,
    'type_fruite_majoritaire': typeFruiteMajoritaire?.toJson,
  };
}

class ResultatPanelService {
  final ApiClient _api;

  ResultatPanelService({ApiClient? api}) : _api = api ?? apiClient;

  Future<List<ResultatPanel>> fetchTous() async {
    final items = await _api.getList('/api/chef/panel-coi/');
    return items
        .map((e) => ResultatPanel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ResultatPanel?> fetchEchantillon(String echantillonId) async {
    final items = await _api.getList(
      '/api/chef/panel-coi/?echantillon=$echantillonId',
    );
    if (items.isEmpty) return null;
    return ResultatPanel.fromJson(items.first as Map<String, dynamic>);
  }
}
