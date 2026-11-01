import '../api_client.dart';
import '../models/contact_messagerie.dart';
import '../models/enums.dart';
import '../models/message.dart';
import 'resultat_service.dart';

class MessagerieService {
  MessagerieService._();
  static final MessagerieService instance = MessagerieService._();

  Future<Resultat<List<Message>>> fetchMessages() => avecSecours(() async {
    final items = await apiClient.getList('/api/messages/');
    return items
        .map((item) => Message.fromJson(item as Map<String, dynamic>))
        .toList();
  }, () => List<Message>.from(_messagesDemo));

  Future<Resultat<List<ContactMessagerie>>> fetchContacts() =>
      avecSecours(() async {
        final items = await apiClient.getList('/api/messages/contacts/');
        return ContactMessagerie.fromJsonList(items);
      }, () => List<ContactMessagerie>.from(_contactsDemo));

  Future<int> fetchUnreadCount() async {
    try {
      final data = await apiClient.get('/api/messages/non-lus/');
      return (data['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Les derniers messages reçus et pas encore lus, du plus récent au plus ancien.
  Future<List<Message>> fetchDerniersNonLus() async {
    final data = await apiClient.get('/api/messages/non-lus/');
    return ((data['derniers'] as List<dynamic>?) ?? const [])
        .map((item) => Message.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendMessage(
    String destinataireId,
    String contenu, {
    List<int>? bytes,
    String? filename,
    String? echantillonId,
  }) async {
    final texte = contenu.trim();
    final fields = <String, String>{
      'destinataire': destinataireId,
      'contenu': texte,
      if (echantillonId != null && echantillonId.isNotEmpty)
        'echantillon': echantillonId,
    };
    final data = bytes == null
        ? await apiClient.post('/api/messages/', fields)
        : await apiClient.postMultipart(
            '/api/messages/',
            bytes: bytes,
            filename: filename ?? 'message.jpg',
            fileField: 'image',
            fields: fields,
          );
    return Message.fromJson(data);
  }

  Future<Message> editMessage(String id, String nouveauContenu) async {
    final data = await apiClient.patch('/api/messages/$id/', {
      'contenu': nouveauContenu.trim(),
    });
    return Message.fromJson(data);
  }

  Future<void> deleteMessage(String id) async {
    await apiClient.delete('/api/messages/$id/');
  }

  Future<void> markAsRead(String messageId) async {
    await apiClient.patch('/api/messages/$messageId/lire/', {});
  }

  static const _contactsDemo = [
    ContactMessagerie(
      id: 'demo-direction',
      nom: 'Ben Salem',
      prenom: 'Meriem',
      role: RoleUtilisateur.direction,
    ),
    ContactMessagerie(
      id: 'demo-collecteur',
      nom: 'Trabelsi',
      prenom: 'Ali',
      role: RoleUtilisateur.collecteur,
    ),
    ContactMessagerie(
      id: 'demo-chef',
      nom: 'Gharbi',
      prenom: 'Nadia',
      role: RoleUtilisateur.chefDegustation,
    ),
  ];

  static final _messagesDemo = [
    Message(
      id: 'demo-message-1',
      expediteur: 'demo-direction',
      destinataire: 'demo-moi',
      expediteurNom: 'Meriem Ben Salem',
      destinataireNom: 'Vous',
      contenu: 'Pouvez-vous confirmer la disponibilité du lot Chemlali ?',
      lu: false,
      dateEnvoi: '2026-05-20T09:15:00Z',
    ),
    Message(
      id: 'demo-message-2',
      expediteur: 'demo-moi',
      destinataire: 'demo-direction',
      expediteurNom: 'Vous',
      destinataireNom: 'Meriem Ben Salem',
      contenu: 'Oui, le fournisseur garde le stock disponible cette semaine.',
      lu: true,
      dateEnvoi: '2026-05-20T09:28:00Z',
    ),
    Message(
      id: 'demo-message-3',
      expediteur: 'demo-chef',
      destinataire: 'demo-moi',
      expediteurNom: 'Nadia Gharbi',
      destinataireNom: 'Vous',
      contenu: 'Les évaluations du panel seront prêtes cet après-midi.',
      lu: true,
      luLe: '2026-05-19T15:10:00Z',
      dateEnvoi: '2026-05-19T14:45:00Z',
    ),
    Message(
      id: 'demo-message-4',
      expediteur: 'demo-moi',
      destinataire: 'demo-collecteur',
      expediteurNom: 'Vous',
      destinataireNom: 'Ali Trabelsi',
      contenu: 'Merci de mettre à jour la date de livraison prévue.',
      lu: true,
      dateEnvoi: '2026-05-18T11:20:00Z',
    ),
  ];
}
