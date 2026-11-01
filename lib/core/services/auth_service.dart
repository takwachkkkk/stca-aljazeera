import '../api_client.dart';
import '../models/user_profile.dart';
import 'alerte_message_service.dart';
import 'fournisseur_service.dart';
import 'variete_service.dart';

class AuthService {
  const AuthService();

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    _invalidateSuggestionCaches();
    await apiClient.login(email, password);
    _invalidateSuggestionCaches();
    return currentUser();
  }

  Future<UserProfile> currentUser() async {
    final data = await apiClient.get('/api/users/me/');
    return UserProfile.fromJson(data);
  }

  Future<void> logout() async {
    alerteMessages.arreter();
    await apiClient.logout();
    _invalidateSuggestionCaches();
  }

  void _invalidateSuggestionCaches() {
    FournisseurService.instance.invalidateCache();
    VarieteService.instance.invalidateCache();
  }
}

const authService = AuthService();
