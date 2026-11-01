// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/notifications/widgets/notification_card.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/theme/app_colors.dart';
import '../models/notification_ceo.dart';

// ── Notification card ─────────────────────────────────────────────────────────
class CeoNotificationCard extends StatelessWidget {
  final NotificationCeo notification;
  final VoidCallback onTap;
  const CeoNotificationCard({super.key, required this.notification, required this.onTap});

  static const _typeConfig = {
    'NOUVEL_ECHANTILLON':       (Icons.science_outlined,         Color(0xFF3A6EA5), Color(0xFFE8F1FB)),
    'ECHANTILLON_MODIFIE':      (Icons.edit_outlined,            Color(0xFFD07B2F), Color(0xFFFEF3E8)),
    'ECHANTILLON_SUPPRIME':     (Icons.delete_outline,           Color(0xFFB71C1C), Color(0xFFFFEBEE)),
    'ECHANTILLON_RECU':         (Icons.check_circle_outline,     Color(0xFF38835A), Color(0xFFE6F4ED)),
    'PREMIERE_EVALUATION':      (Icons.star_border_outlined,     Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
    'TOUTES_EVALUATIONS':       (Icons.group_outlined,           Color(0xFF38835A), Color(0xFFE6F4ED)),
    'ANALYSE_SOUMISE':          (Icons.biotech_outlined,         Color(0xFF0277BD), Color(0xFFE1F5FE)),
    'ACHAT_CONFIRME':           (Icons.handshake_outlined,       Color(0xFF38835A), Color(0xFFE6F4ED)),
    'ACHAT_NON_CONCLU':         (Icons.do_not_disturb_on_outlined, Color(0xFF616161), Color(0xFFF0F0F0)),
    // Ancien circuit de validation des achats : notifications déjà reçues.
    'proposition_achat_attente':(Icons.pending_actions_outlined, Color(0xFFD07B2F), Color(0xFFFEF3E8)),
  };

  @override
  Widget build(BuildContext context) {
    final cfg   = _typeConfig[notification.type];
    final icon  = cfg?.$1 ?? Icons.notifications_outlined;
    final color = cfg?.$2 ?? kGreen;
    final bgCol = cfg?.$3 ?? const Color(0xFFE6F4ED);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead ? Colors.grey.shade100 : color.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left accent bar — visible only for unread, no height: infinity needed
            if (!notification.isRead)
              Container(width: 4, color: color),
            // Card content
            Expanded(child: Padding(
              padding: EdgeInsets.fromLTRB(notification.isRead ? 14 : 10, 14, 14, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: bgCol, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(notification.titre,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: kDark,
                        ))),
                    if (!notification.isRead)
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(notification.message,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (notification.echantillonReference != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(notification.echantillonReference!,
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(_relativeTime(notification.dateCreation),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade300),
                  ]),
                ])),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }
}
