// ─────────────────────────────────────────────────────────────────────────────
// FILE : homepage/widgets/app_drawer.dart
// PURPOSE : left-side navigation drawer — CEO-style design
// receives : navigation callbacks FROM the page, does NOT navigate itself
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/fonctionnalites.dart';
import '../homepage_page.dart';
import '../../analyse_labo/analyse_laboratoire_page.dart';
import '../../evaluation_echantillons/evaluation_echantillons_page.dart';
import '../../gestion_echantillons/gestion_echantillons_page.dart';
import '../../membres_panel/membres_panel_page.dart';
import '../../profil/profil_page.dart';
import '../../sessions_degustation/sessions_degustation_page.dart';
import '../../../core/logout_navigation.dart';

const Color _headerBg = Color.fromARGB(255, 220, 233, 226);
const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _olive = Color(0xFF6B8143);
const Color _iconBg = Color(0x1A38835A); // green at 10% opacity

enum DegustateurDestination {
  accueil,
  evaluation,
  gestion,
  laboratoire,
  sessions,
  panel,
  profil,
}

class AppDrawer extends StatelessWidget {
  final DegustateurDestination? currentPage;

  const AppDrawer({super.key, this.currentPage});

  void _navigate(BuildContext context, DegustateurDestination destination) {
    Navigator.pop(context);
    if (destination == currentPage) return;
    final Widget page = switch (destination) {
      DegustateurDestination.accueil => const HomePage(),
      DegustateurDestination.evaluation => const EvaluationEchantillonsPage(),
      DegustateurDestination.gestion => const GestionEchantillonsPage(),
      DegustateurDestination.laboratoire => const AnalyseLaboratoirePage(),
      DegustateurDestination.sessions => const SessionsDegustationPage(),
      DegustateurDestination.panel => const MembresPanelPage(),
      DegustateurDestination.profil => const ProfilePage(),
    };
    if (destination == DegustateurDestination.accueil) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => page),
        (_) => false,
      );
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
            // ── Header ───────────────────────────────────────────────────────
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
                        'Dégustateur',
                        style: GoogleFonts.domine(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'STCA Aljazira',
                        style: TextStyle(fontSize: 12, color: _dark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Navigation items ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  _SectionLabel('Tableau de bord'),
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Accueil',
                    active: currentPage == DegustateurDestination.accueil,
                    onTap: () =>
                        _navigate(context, DegustateurDestination.accueil),
                  ),

                  const SizedBox(height: 4),
                  Divider(color: _olive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),

                  _SectionLabel('Échantillons'),
                  _DrawerItem(
                    icon: Icons.folder_outlined,
                    label: 'Gestion des échantillons',
                    active: currentPage == DegustateurDestination.gestion,
                    onTap: () =>
                        _navigate(context, DegustateurDestination.gestion),
                  ),
                  _DrawerItem(
                    customIcon: SizedBox(
                      width: 19,
                      height: 19,
                      child: Image.asset('assets/img/glass.png'),
                    ),
                    label: 'Évaluations des échantillons',
                    active: currentPage == DegustateurDestination.evaluation,
                    onTap: () =>
                        _navigate(context, DegustateurDestination.evaluation),
                  ),
                  if (kLaboActif)
                    _DrawerItem(
                      icon: Icons.science_outlined,
                      label: 'Analyse de laboratoire',
                      active:
                          currentPage == DegustateurDestination.laboratoire,
                      onTap: () => _navigate(
                        context,
                        DegustateurDestination.laboratoire,
                      ),
                    ),

                  const SizedBox(height: 4),
                  Divider(color: _olive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),

                  _SectionLabel('Panel'),
                  _DrawerItem(
                    icon: Icons.event_note_outlined,
                    label: 'Sessions de dégustation',
                    active: currentPage == DegustateurDestination.sessions,
                    onTap: () =>
                        _navigate(context, DegustateurDestination.sessions),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Membres du panel',
                    active: currentPage == DegustateurDestination.panel,
                    onTap: () =>
                        _navigate(context, DegustateurDestination.panel),
                  ),

                  const SizedBox(height: 4),
                  Divider(color: _olive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),

                  _SectionLabel('Compte'),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Votre profil',
                    active: currentPage == DegustateurDestination.profil,
                    onTap: () =>
                        _navigate(context, DegustateurDestination.profil),
                  ),
                ],
              ),
            ),

            // ── Déconnexion ──────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL  — olive uppercase caption above a group of items
// ─────────────────────────────────────────────────────────────────────────────
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
        color: _olive,
        letterSpacing: 1.1,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER ITEM  — icon in green bg container + label, no trailing arrow
// ─────────────────────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _DrawerItem({
    this.icon,
    this.customIcon,
    required this.label,
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
          color: active ? _headerBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: customIcon ?? Icon(icon, color: _green, size: 20),
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
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
