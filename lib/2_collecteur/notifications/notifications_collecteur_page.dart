import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'models/notification_collecteur.dart';
import 'services/notification_collecteur_service.dart';
import '../widgets/col_colors.dart';
import '../../core/widgets/bandeau_demonstration.dart';
import '../../core/utils/montant_achat.dart';

class NotificationsCollecteurPage extends StatefulWidget {
  final NotificationCollecteurService service;
  final bool Function(NotificationCollecteur) onNavigate;

  const NotificationsCollecteurPage({
    super.key,
    required this.service,
    required this.onNavigate,
  });

  @override
  State<NotificationsCollecteurPage> createState() =>
      _NotificationsCollecteurPageState();
}

class _NotificationsCollecteurPageState
    extends State<NotificationsCollecteurPage>
    with RafraichissementPeriodique {
  List<NotificationCollecteur> _all = [];
  bool _loading = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;
  String _filter = 'tous';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final resultat = await widget.service.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _all = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
        _loading = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = erreur;
        _loading = false;
      });
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await widget.service.fetchNotifications();
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _all = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  List<NotificationCollecteur> get _filtered =>
      _filter == 'non_lus' ? _all.where((n) => !n.isRead).toList() : _all;

  int get _unreadCount => _all.where((n) => !n.isRead).length;

  Future<bool> _markRead(NotificationCollecteur n) async {
    if (n.isRead) return true;
    try {
      await widget.service.markAsRead(n.id);
      if (!mounted) return false;
      setState(() {
        final i = _all.indexWhere((x) => x.id == n.id);
        if (i != -1) _all[i] = n.copyWith(isRead: true);
      });
      return true;
    } catch (_) {
      if (mounted) _signalerErreur();
      return false;
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.service.markAllAsRead();
      if (!mounted) return;
      setState(() => _all = _all.map((n) => n.copyWith(isRead: true)).toList());
    } catch (_) {
      if (mounted) _signalerErreur();
    }
  }

  Future<void> _onTap(NotificationCollecteur n) async {
    if (!await _markRead(n) || !mounted) return;
    if (n.echantillonId == null) return;
    final navigated = widget.onNavigate(n);
    if (navigated && mounted) Navigator.pop(context);
  }

  void _signalerErreur() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La notification n’a pas pu être mise à jour.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colBg,
      appBar: AppBar(
        backgroundColor: colHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Notifications',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colDark,
          ),
        ),
        iconTheme: const IconThemeData(color: colDark),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Tout marquer lu',
                style: TextStyle(
                  fontSize: 12,
                  color: colGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: colGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _load,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: colGreen,
              child: Column(
                children: [
                  // ── Filter chips ────────────────────────────────────────────────
                  Container(
                    color: colHeaderBg,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          active: _filter == 'tous',
                          onTap: () => setState(() => _filter = 'tous'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: _unreadCount > 0
                              ? 'Non lus ($_unreadCount)'
                              : 'Non lus',
                          active: _filter == 'non_lus',
                          onTap: () => setState(() => _filter = 'non_lus'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? _buildEmpty()
                        : _buildGroupedList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupedList() {
    final grouped = <String, List<NotificationCollecteur>>{};
    final now = DateTime.now();
    for (final n in _filtered) {
      final diff = now.difference(n.dateCreation);
      final String group;
      if (diff.inDays == 0) {
        group = "Aujourd'hui";
      } else if (diff.inDays == 1) {
        group = 'Hier';
      } else {
        group = 'Plus tôt';
      }
      grouped.putIfAbsent(group, () => []).add(n);
    }

    final order = ["Aujourd'hui", 'Hier', 'Plus tôt'];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        for (final group in order)
          if (grouped.containsKey(group)) ...[
            _GroupHeader(group),
            const SizedBox(height: 8),
            ...grouped[group]!.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationCard(
                  notification: n,
                  onTap: () => _onTap(n),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
      ],
    );
  }

  Widget _buildEmpty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 52,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Aucune notification',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tout est à jour.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ── Group header ──────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    ),
  );
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? colGreen : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: colGreen.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final NotificationCollecteur notification;
  final VoidCallback onTap;
  const _NotificationCard({required this.notification, required this.onTap});

  static const _typeConfig = {
    'ECHANTILLON_APPROUVE': (
      Icons.handshake_outlined,
      Color(0xFF38835A),
      Color(0xFFE6F4ED),
    ),
    'ECHANTILLON_REFUSE': (
      Icons.cancel_outlined,
      Color(0xFFB71C1C),
      Color(0xFFFFEBEE),
    ),
    'STOCK_RECEPTIONNE': (
      Icons.warehouse_outlined,
      Color(0xFF0277BD),
      Color(0xFFE1F5FE),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[notification.type];
    final icon = cfg?.$1 ?? Icons.notifications_outlined;
    final color = cfg?.$2 ?? colGreen;
    final bgCol = cfg?.$3 ?? const Color(0xFFE6F4ED);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? Colors.grey.shade100
                : color.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!notification.isRead) Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    notification.isRead ? 14 : 10,
                    14,
                    14,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ─────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: bgCol,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.titre,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: notification.isRead
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          color: colDark,
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // ── Negotiation detail panel (APPROUVE only) ───────────
                      if (notification.type == 'ECHANTILLON_APPROUVE' &&
                          notification.budgetNegociation != null) ...[
                        const SizedBox(height: 10),
                        _NegotiationPanel(
                          budget: notification.budgetNegociation!,
                          dateSouhaitee:
                              notification.dateLivraisonStockSouhaitee,
                          color: color,
                          bgCol: bgCol,
                        ),
                      ],

                      // ── Footer row ─────────────────────────────────────────
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (notification.echantillonReference != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notification.echantillonReference!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _relativeTime(notification.dateCreation),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

// ── Negotiation detail panel ──────────────────────────────────────────────────
class _NegotiationPanel extends StatelessWidget {
  final double budget;
  final DateTime? dateSouhaitee;
  final Color color;
  final Color bgCol;

  const _NegotiationPanel({
    required this.budget,
    required this.dateSouhaitee,
    required this.color,
    required this.bgCol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails de la négociation',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Prix proposé',
            value:
                '${MontantAchat.formaterPrixParKg(budget.toString())} '
                '(${MontantAchat.formaterPrixParTonne(budget.toString())})',
            color: color,
          ),
          if (dateSouhaitee != null) ...[
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.local_shipping_outlined,
              label: 'Livraison stock souhaitée avant',
              value: _fmtDate(dateSouhaitee!),
              color: color,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 12,
                color: color.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Ouvrez votre liste d\'échantillons pour confirmer l\'achat.',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: color.withValues(alpha: 0.75)),
      const SizedBox(width: 6),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, height: 1.3),
            children: [
              TextSpan(
                text: '$label : ',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: const Color(0xFF1A2E1F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
