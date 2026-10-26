// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/services/repartition_service.dart
// PURPOSE : Échantillons enregistrés et achats confirmés, regroupés par
//           gouvernorat ou par fournisseur. Même calcul serveur pour le chef
//           (/api/chef/dashboard/regions|fournisseurs/) et la direction
//           (/api/ceo/dashboard/regions|fournisseurs/).
// ═════════════════════════════════════════════════════════════════════════════

import '../api_client.dart';

class LigneRepartition {
  /// Gouvernorat, ou « fournisseur — lieu ».
  final String nom;
  final int echantillons;
  final int achats;

  const LigneRepartition({
    required this.nom,
    required this.echantillons,
    required this.achats,
  });

  factory LigneRepartition.fromJson(Map<String, dynamic> json) =>
      LigneRepartition(
        nom: json['nom'] as String? ?? 'Non précisé',
        echantillons: json['echantillons'] as int? ?? 0,
        achats: json['achats'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'echantillons': echantillons,
    'achats': achats,
  };
}

class RepartitionService {
  final String chemin;
  final ApiClient _api;

  RepartitionService(this.chemin, {ApiClient? api}) : _api = api ?? apiClient;

  static String _jour(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<LigneRepartition>> fetch({DateTime? debut, DateTime? fin}) async {
    final query = <String, String>{
      if (debut != null) 'date_debut': _jour(debut),
      if (fin != null) 'date_fin': _jour(fin),
    };
    final path = Uri(
      path: chemin,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    final items = await _api.getList(path);
    return items
        .map((e) => LigneRepartition.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
