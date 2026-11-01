import '../../../core/api_client.dart';
import '../../../core/fonctionnalites.dart';
import '../../../core/services/resultat_service.dart';
import 'package:project3/core/models/notification_degustateur.dart';

class NotificationDegustateurService {
  Future<Resultat<List<NotificationDegustateur>>> fetchNotifications() =>
      avecSecours(() async {
        final data = await apiClient.getList('/api/notifications/');
        return data
            .map(
              (e) =>
                  NotificationDegustateur.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }, _mockNotifications);

  Future<void> markAsRead(String id) async {
    await apiClient.patch('/api/notifications/$id/lire/', {});
  }

  Future<void> markAllAsRead() async {
    await apiClient.post('/api/notifications/lire-tout/', {});
  }

  Future<Resultat<int>> fetchUnreadCount() => avecSecours(() async {
    final data = await apiClient.get('/api/notifications/unread-count/');
    return data['count'] as int;
  }, () => _mockNotifications().where((n) => !n.isRead).length);

  List<NotificationDegustateur> _mockNotifications() {
    final now = DateTime.now();
    return [
      // ── Aujourd'hui ───────────────────────────────────────────────────────
      NotificationDegustateur(
        id: '1',
        type: 'EVALUATION_URGENTE',
        titre: 'Dégustation urgente requise',
        message:
            "Le directeur a marqué l'échantillon ECH-2026-041 comme urgent. Vous devez soumettre votre évaluation dès que possible.",
        echantillonId: 'ech-1',
        echantillonReference: 'ECH-2026-041',
        section: 'EVALUATIONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(minutes: 8)),
      ),
      NotificationDegustateur(
        id: '2',
        type: 'NOUVEL_ECHANTILLON',
        titre: 'Nouvel échantillon enregistré',
        message:
            "Le collecteur Ahmed Dridi a ajouté l'échantillon ECH-2026-040 (Chemlali, Sfax, 120 L) au système.",
        echantillonId: 'ech-2',
        echantillonReference: 'ECH-2026-040',
        section: 'ECHANTILLONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(hours: 1)),
      ),
      NotificationDegustateur(
        id: '3',
        type: 'ECHANTILLON_MODIFIE',
        titre: 'Échantillon modifié',
        message:
            "Le collecteur Fatma Bouzid a modifié l'échantillon ECH-2026-038 (quantité : 80 L → 95 L).",
        echantillonId: 'ech-3',
        echantillonReference: 'ECH-2026-038',
        section: 'ECHANTILLONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(hours: 2)),
      ),
      if (kLaboActif)
        NotificationDegustateur(
          id: '4',
          type: 'ANALYSE_SOUMISE',
          titre: 'Analyse laboratoire soumise',
          message:
              "Le technicien a soumis l'analyse laboratoire complète de l'échantillon ECH-2026-036. Les résultats sont disponibles.",
          echantillonId: 'ech-4',
          echantillonReference: 'ECH-2026-036',
          section: 'ANALYSES',
          isRead: false,
          dateCreation: now.subtract(const Duration(hours: 4)),
        ),
      // ── Hier ─────────────────────────────────────────────────────────────
      NotificationDegustateur(
        id: '5',
        type: 'DATE_LIVRAISON_AJOUTEE',
        titre: 'Date de livraison ajoutée',
        message:
            "Le collecteur Sami Kraiem a planifié la livraison de l'échantillon ECH-2026-035 pour le ${_fmtDate(now.subtract(const Duration(days: 3)))}.",
        echantillonId: 'ech-5',
        echantillonReference: 'ECH-2026-035',
        section: 'ECHANTILLONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(days: 1, hours: 1)),
      ),
      NotificationDegustateur(
        id: '6',
        type: 'DATE_LIVRAISON_MODIFIEE',
        titre: 'Date de livraison modifiée',
        message:
            "Le collecteur Nadia Ferchichi a modifié la date de livraison de l'échantillon ECH-2026-034 : 18/04/2026 → 22/04/2026.",
        echantillonId: 'ech-6',
        echantillonReference: 'ECH-2026-034',
        section: 'ECHANTILLONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      NotificationDegustateur(
        id: '7',
        type: 'ECHANTILLON_SUPPRIME',
        titre: 'Échantillon supprimé',
        message:
            "Le collecteur Omar Ben Ali a supprimé l'échantillon ECH-2026-031 (Arbequina, Nabeul) du système.",
        echantillonId: null,
        echantillonReference: 'ECH-2026-031',
        section: 'ECHANTILLONS',
        isRead: true,
        dateCreation: now.subtract(const Duration(days: 1, hours: 6)),
      ),
      if (kLaboActif)
        NotificationDegustateur(
          id: '8',
          type: 'ANALYSE_MODIFIEE',
          titre: 'Analyse laboratoire mise à jour',
          message:
              "Le technicien a soumis une nouvelle version de l'analyse de l'échantillon ECH-2026-029. Les valeurs précédentes ont été remplacées.",
          echantillonId: 'ech-8',
          echantillonReference: 'ECH-2026-029',
          section: 'ANALYSES',
          isRead: true,
          dateCreation: now.subtract(const Duration(days: 1, hours: 9)),
        ),
      NotificationDegustateur(
        id: '9',
        type: 'SESSION_SUGGEREE',
        titre: 'Nouvelle séance de dégustation proposée',
        message:
            "Lobna E. a proposé une séance de dégustation : « Session Arbequina - Lot C » le 28/04/2026 à 09h00, Salle de dégustation A.",
        echantillonId: null,
        echantillonReference: 'SES-005',
        section: 'SESSIONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(days: 1, hours: 11)),
      ),
      NotificationDegustateur(
        id: '10',
        type: 'PRESENCE_CONFIRMEE',
        titre: 'Présence confirmée',
        message:
            "Nayrouz F. a confirmé sa présence à la séance « Session Zalmati » du 25/02/2026.",
        echantillonId: null,
        echantillonReference: 'SES-003',
        section: 'SESSIONS',
        isRead: false,
        dateCreation: now.subtract(const Duration(days: 1, hours: 13)),
      ),
      NotificationDegustateur(
        id: '11',
        type: 'PRESENCE_ANNULEE',
        titre: 'Présence annulée',
        message:
            "Yosra S. a retiré sa confirmation de présence pour la séance « Session Chetoui - Lot B » du 21/02/2026.",
        echantillonId: null,
        echantillonReference: 'SES-002',
        section: 'SESSIONS',
        isRead: true,
        dateCreation: now.subtract(const Duration(days: 1, hours: 15)),
      ),
      // ── Plus tôt ─────────────────────────────────────────────────────────
      NotificationDegustateur(
        id: '12',
        type: 'EVALUATION_SOUMISE',
        titre: 'Évaluation soumise par un dégustateur',
        message:
            "Karim Boussetta a soumis son évaluation organoleptique pour l'échantillon ECH-2026-027. 3 dégustateurs restants.",
        echantillonId: 'ech-9',
        echantillonReference: 'ECH-2026-027',
        section: 'EVALUATIONS',
        isRead: true,
        dateCreation: now.subtract(const Duration(days: 2, hours: 2)),
      ),
      NotificationDegustateur(
        id: '13',
        type: 'TOUTES_EVALUATIONS',
        titre: 'Toutes les évaluations soumises',
        message:
            "Les 4 dégustateurs ont tous soumis leur évaluation pour l'échantillon ECH-2026-025. Le panel est complet.",
        echantillonId: 'ech-10',
        echantillonReference: 'ECH-2026-025',
        section: 'EVALUATIONS',
        isRead: true,
        dateCreation: now.subtract(const Duration(days: 3, hours: 1)),
      ),
    ];
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
