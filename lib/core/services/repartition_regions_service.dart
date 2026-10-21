// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/services/repartition_regions_service.dart
// PURPOSE : Échantillons enregistrés et achats confirmés par gouvernorat.
//           Même calcul serveur pour le chef (/api/chef/dashboard/regions/)
//           et la direction (/api/ceo/dashboard/regions/).
// ═════════════════════════════════════════════════════════════════════════════

import '../api_client.dart';

class RepartitionRegion {
  final String gouvernorat;
  final int echantillons;
  final int achats;

  const RepartitionRegion({
    required this.gouvernorat,
    required this.echantillons,
    required this.achats,
  });

  factory RepartitionRegion.fromJson(Map<String, dynamic> json) =>
      RepartitionRegion(
        gouvernorat: json['gouvernorat'] as String? ?? 'Non précisé',
        echantillons: json['echantillons'] as int? ?? 0,
        achats: json['achats'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'gouvernorat': gouvernorat,
    'echantillons': echantillons,
    'achats': achats,
  };
}

class RepartitionRegionsService {
  final String chemin;
  final ApiClient _api;

  RepartitionRegionsService(this.chemin, {ApiClient? api})
    : _api = api ?? apiClient;

  static String _jour(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<RepartitionRegion>> fetch({
    DateTime? debut,
    DateTime? fin,
  }) async {
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
        .map((e) => RepartitionRegion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
