// ─────────────────────────────────────────────────────────────────────────────
// FILE : homepage/widgets/app_drawer.dart
// PURPOSE : left-side navigation drawer — CEO-style design
// receives : navigation callbacks FROM the page, does NOT navigate itself
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/widgets/messagerie/messagerie_badge.dart';
import '../homepage_page.dart';
import '../../../core/logout_navigation.dart';
import '../../analyse_labo/analyse_laboratoire_page.dart';
import '../../evaluation_echantillons/evaluation_echantillons_page.dart';
import '../../gestion_echantillons/gestion_echantillons_page.dart';
import '../../membres_panel/membres_panel_page.dart';
import '../../profil.dart';
import '../../sessions_degustation/sessions_degustation_page.dart';
import '../../utilisateurs/utilisateurs_chef_page.dart';
import '../../vue_ensemble_evaluations/vue_ensemble_evaluations_page.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import '../../widgets/chef_colors.dart';

const Color _olive = Color(0xFF6B8143);
const Color _iconBg = Color(0x1A38835A); // green at 10% opacity

enum ChefDestination {
  accueil,
  evaluation,
  gestion,
  laboratoire,
  sessions,
  panel,
  utilisateurs,
  vueEnsemble,
  messagerie,
  profil,
}

class AppDrawer extends StatelessWidget {
  final ChefDestination? currentPage;

  const AppDrawer({super.key, this.currentPage});

  void _navigate(BuildContext context, ChefDestination destination) {
    Navigator.pop(context);
    if (destination == currentPage) return;
    final Widget page = switch (destination) {
      ChefDestination.accueil => const HomePage(),
      ChefDestination.evaluation => const EvaluationEchantillonsPage(),
      ChefDestination.gestion => const GestionEchantillonsPage(),
      ChefDestination.laboratoire => const AnalyseLaboratoirePage(),
      ChefDestination.sessions => const SessionsDegustationPage(),
      ChefDestination.panel => const MembresPanelPage(),
      ChefDestination.utilisateurs => const UtilisateursChefPage(),
      ChefDestination.vueEnsemble => const VueEnsembleEvaluationsPage(),
      ChefDestination.messagerie => const ConversationsPage(),
      ChefDestination.profil => const ProfilePage(),
    };
    // La messagerie s'ouvre PAR-DESSUS la page courante : sa flèche de
    // retour ramène à la page d'où l'on vient (elle n'a pas de menu).
    if (destination == ChefDestination.messagerie) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else if (destination == ChefDestination.accueil) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chef de Dégustation',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.domine(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: chefDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'STCA Aljazira',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: chefDark),
                        ),
                      ],
                    ),
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
                    active: currentPage == ChefDestination.accueil,
                    onTap: () => _navigate(context, ChefDestination.accueil),
                  ),

                  const SizedBox(height: 4),
                  Divider(color: _olive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),

                  _SectionLabel('Échantillons'),
                  _DrawerItem(
                    icon: Icons.folder_outlined,
                    label: 'Gestion des échantillons',
                    active: currentPage == ChefDestination.gestion,
                    onTap: () => _navigate(context, ChefDestination.gestion),
                  ),
                  _DrawerItem(
                    customIcon: SizedBox(
                      width: 19,
                      height: 19,
                      child: Image.asset('assets/img/glass.png'),
                    ),
                    label: 'Évaluations des échantillons',
                    active: currentPage == ChefDestination.evaluation,
                    onTap: () => _navigate(context, ChefDestination.evaluation),
                  ),
                  _DrawerItem(
                    icon: Icons.science_outlined,
                    label: 'Analyse de laboratoire',
                    active: currentPage == ChefDestination.laboratoire,
                    onTap: () =>
                        _navigate(context, ChefDestination.laboratoire),
                  ),

                  const SizedBox(height: 4),
                  Divider(color: _olive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),

                  _SectionLabel('Panel'),
                  _DrawerItem(
                    icon: Icons.event_note_outlined,
                    label: 'Sessions de dégustation',
                    active: currentPage == ChefDestination.sessions,
                    onTap: () => _navigate(context, ChefDestination.sessions),
                  ),
                  _DrawerItem(
                    icon: Icons.assessment_outlined,
                    label: 'Vue d\'ensemble évaluations',
                    active: currentPage == ChefDestination.vueEnsemble,
                    onTap: () =>
                        _navigate(context, ChefDestination.vueEnsemble),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Membres du panel',
                    active: currentPage == ChefDestination.panel,
                    onTap: () => _navigate(context, ChefDestination.panel),
                  ),

                  const SizedBox(height: 4),
                  Divider(color: _olive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),

                  // Les trois entrées qui parlent de personnes, de la plus large
                  // responsabilité à la plus étroite : les comptes de tous, puis
                  // l'équipe, puis soi-même.
                  _SectionLabel('Comptes'),
                  _DrawerItem(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Utilisateurs',
                    active: currentPage == ChefDestination.utilisateurs,
                    onTap: () =>
                        _navigate(context, ChefDestination.utilisateurs),
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messagerie',
                    trailing: const MessagerieBadge(),
                    active: currentPage == ChefDestination.messagerie,
                    onTap: () => _navigate(context, ChefDestination.messagerie),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Votre profil',
                    active: currentPage == ChefDestination.profil,
                    onTap: () => _navigate(context, ChefDestination.profil),
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
          color: active ? chefHeaderBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: chefGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: customIcon ?? Icon(icon, color: chefGreen, size: 20),
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
                  color: chefDark,
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
