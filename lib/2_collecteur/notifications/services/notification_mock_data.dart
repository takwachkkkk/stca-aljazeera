// ═════════════════════════════════════════════════════════════════════════════
// FILE : collecteur/notifications/services/notification_mock_data.dart
// Mock data — 7 notification scenarios for the collector role.
// Flip useMock = true in NotificationCollecteurService to use these.
// ═════════════════════════════════════════════════════════════════════════════

import '../models/notification_collecteur.dart';

String fmtNotifDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    'à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';

List<NotificationCollecteur> mockNotifications() {
  final now = DateTime.now();
  return [
    // ── Aujourd'hui ───────────────────────────────────────────────────────────
    NotificationCollecteur(
      id: '1',
      type: 'ECHANTILLON_APPROUVE',
      titre: 'Échantillon approuvé — négociation ouverte',
      message:
          "La direction a approuvé l'échantillon ECH-2026-041 pour achat. "
          "Budget alloué : 7.80 DT/kg. Livraison du stock souhaitée avant le 10/05/2026. "
          "Confirmez l'achat depuis votre liste d'échantillons.",
      echantillonId: 'ech-1',
      echantillonReference: 'ECH-2026-041',
      section: 'MES_ECHANTILLONS',
      isRead: false,
      dateCreation: now.subtract(const Duration(minutes: 25)),
      budgetNegociation: 7.80,
      dateLivraisonStockSouhaitee: now.add(const Duration(days: 15)),
    ),

    NotificationCollecteur(
      id: '2',
      type: 'ECHANTILLON_REFUSE',
      titre: 'Échantillon refusé par la direction',
      message:
          "La direction a refusé l'échantillon ECH-2026-039 après analyse organoleptique. "
          "Motif : résultats sensoriels insuffisants (score < seuil minimal). "
          "Cet échantillon ne fera pas l'objet d'un achat.",
      echantillonId: 'ech-2',
      echantillonReference: 'ECH-2026-039',
      section: 'MES_ECHANTILLONS',
      isRead: false,
      dateCreation: now.subtract(const Duration(hours: 2)),
    ),

    NotificationCollecteur(
      id: '3',
      type: 'STOCK_RECEPTIONNE',
      titre: 'Stock réceptionné en entrepôt',
      message:
          "La direction a confirmé la réception physique du stock de l'échantillon ECH-2026-037. "
          "Le stock est arrivé en entrepôt le ${fmtNotifDate(now.subtract(const Duration(hours: 4)))}. "
          "La transaction est clôturée.",
      echantillonId: 'ech-3',
      echantillonReference: 'ECH-2026-037',
      section: 'MES_ECHANTILLONS',
      isRead: false,
      dateCreation: now.subtract(const Duration(hours: 4)),
    ),

    // ── Hier ─────────────────────────────────────────────────────────────────
    NotificationCollecteur(
      id: '4',
      type: 'ECHANTILLON_APPROUVE',
      titre: 'Échantillon approuvé — négociation ouverte',
      message:
          "La direction a approuvé l'échantillon ECH-2026-035 pour achat. "
          "Budget alloué : 8.50 DT/kg. Livraison du stock souhaitée avant le 05/05/2026. "
          "Confirmez l'achat depuis votre liste d'échantillons.",
      echantillonId: 'ech-4',
      echantillonReference: 'ECH-2026-035',
      section: 'MES_ECHANTILLONS',
      isRead: true,
      dateCreation: now.subtract(const Duration(days: 1, hours: 2)),
      budgetNegociation: 8.50,
      dateLivraisonStockSouhaitee: now.add(const Duration(days: 10)),
    ),

    NotificationCollecteur(
      id: '5',
      type: 'ECHANTILLON_REFUSE',
      titre: 'Échantillon refusé par la direction',
      message:
          "La direction a refusé l'échantillon ECH-2026-033 après analyse organoleptique. "
          "Motif : teneur en acides gras libres hors norme. "
          "Cet échantillon ne fera pas l'objet d'un achat.",
      echantillonId: 'ech-5',
      echantillonReference: 'ECH-2026-033',
      section: 'MES_ECHANTILLONS',
      isRead: true,
      dateCreation: now.subtract(const Duration(days: 1, hours: 5)),
    ),

    // ── Plus tôt ─────────────────────────────────────────────────────────────
    NotificationCollecteur(
      id: '6',
      type: 'STOCK_RECEPTIONNE',
      titre: 'Stock réceptionné en entrepôt',
      message:
          "La direction a confirmé la réception physique du stock de l'échantillon ECH-2026-029. "
          "Le stock est arrivé en entrepôt le ${fmtNotifDate(now.subtract(const Duration(days: 3)))}. "
          "La transaction est clôturée.",
      echantillonId: 'ech-6',
      echantillonReference: 'ECH-2026-029',
      section: 'MES_ECHANTILLONS',
      isRead: true,
      dateCreation: now.subtract(const Duration(days: 3)),
    ),

    NotificationCollecteur(
      id: '7',
      type: 'ECHANTILLON_APPROUVE',
      titre: 'Échantillon approuvé — négociation ouverte',
      message:
          "La direction a approuvé l'échantillon ECH-2026-025 pour achat. "
          "Budget alloué : 7.20 DT/kg. Livraison du stock souhaitée avant le 01/05/2026. "
          "Confirmez l'achat depuis votre liste d'échantillons.",
      echantillonId: 'ech-7',
      echantillonReference: 'ECH-2026-025',
      section: 'MES_ECHANTILLONS',
      isRead: true,
      dateCreation: now.subtract(const Duration(days: 5)),
      budgetNegociation: 7.20,
      dateLivraisonStockSouhaitee: now.add(const Duration(days: 6)),
    ),
  ];
}
