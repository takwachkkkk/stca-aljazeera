import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/widgets/messagerie/messagerie_badge.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'package:project3/core/logout_navigation.dart';
import '../mes_echantillons/mes_echantillons_page.dart';
import '../profilcom.dart';
import 'col_colors.dart';

enum CollecteurDestination { echantillons, messagerie, profil }

class CollecteurDrawer extends StatelessWidget {
  final CollecteurDestination? currentPage;

  const CollecteurDrawer({super.key, this.currentPage});

  void _navigate(BuildContext context, CollecteurDestination destination) {
    Navigator.pop(context);
    if (destination == currentPage) return;
    final Widget page = switch (destination) {
      CollecteurDestination.echantillons => const MesEchantillonsPage(),
      CollecteurDestination.messagerie => const ConversationsPage(),
      CollecteurDestination.profil => const ProfileCollecteurPage(),
    };
    // La messagerie s'ouvre PAR-DESSUS la page courante : sa flèche de
    // retour ramène à la page d'où l'on vient (elle n'a pas de menu).
    if (destination == CollecteurDestination.messagerie) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
              decoration: const BoxDecoration(
                color: Color(0xFF55755E),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        146,
                        172,
                        157,
                      ).withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Collecteur',
                        style: GoogleFonts.domine(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'STCA Aljazira',
                        style: TextStyle(fontSize: 12, color: colDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Nav ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  _SectionLabel('Activités'),
                  _DrawerItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Mes échantillons',
                    active: currentPage == CollecteurDestination.echantillons,
                    onTap: () =>
                        _navigate(context, CollecteurDestination.echantillons),
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messagerie',
                    trailing: const MessagerieBadge(),
                    active: currentPage == CollecteurDestination.messagerie,
                    onTap: () =>
                        _navigate(context, CollecteurDestination.messagerie),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: colOlive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),
                  _SectionLabel('Compte'),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Mon profil',
                    active: currentPage == CollecteurDestination.profil,
                    onTap: () =>
                        _navigate(context, CollecteurDestination.profil),
                  ),
                ],
              ),
            ),

            // ── Déconnexion ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    logoutAndShowLogin(context);
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Déconnexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF55755E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: colOlive,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _DrawerItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool active;

  const _DrawerItem({
    this.icon,
    this.customIcon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.active = false,
  }) : assert(icon != null || customIcon != null);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: active ? colHeaderBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: customIcon ?? Icon(icon, color: colGreen, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: colDark,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    ),
  );
}
