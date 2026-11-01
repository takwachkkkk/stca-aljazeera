// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 6_service_achat/achats/services/achats_service_achat_service.dart
// PURPOSE : Achats confirmés du Service achat (/api/service-achat/achats/) et
//           signalement qu'un stock est facturé.
// ═════════════════════════════════════════════════════════════════════════════

import '../../../core/api_client.dart';
import '../models/achat_service_achat.dart';

class AchatsServiceAchatService {
  final ApiClient _api;

  AchatsServiceAchatService({ApiClient? api}) : _api = api ?? apiClient;

  Future<List<AchatServiceAchat>> fetchAchats() async {
    final items = await _api.getList('/api/service-achat/achats/');
    return items
        .map((e) => AchatServiceAchat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AchatServiceAchat> facturer(String id) async {
    final data = await _api.post('/api/service-achat/achats/$id/facturer/', {});
    return AchatServiceAchat.fromJson(data);
  }
}
