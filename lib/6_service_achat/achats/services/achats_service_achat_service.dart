// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 6_service_achat/achats/services/achats_service_achat_service.dart
// PURPOSE : Lecture des achats confirmés pour le Service achat
//           (/api/service-achat/achats/, lecture seule).
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
}
