import 'package:flutter/material.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/widgets/messagerie/messagerie_badge.dart';
import '../tableau_de_bord/tableau_de_bord.dart';
import '../echantillons/echantillons_ceo_page.dart';
import '../analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import '../analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import '../validation_achats/validation_achats_ceo_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../utilisateurs/utilisateurs_ceo_page.dart';
import '../profil_ceo_page.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';

const Color _iconBg = Color(0x1A38835A);

enum CeoDestination {
  accueil,
  echantillons,
  organoleptique,
  laboratoire,
  validation,
  achats,
  utilisateurs,
  messagerie,
  profil,
}

class CeoDrawer extends StatelessWidget {
  final CeoDestination? currentPage;
  final VoidCallback onEchantillons;
  final VoidCallback onAnalyseOrganoleptique;
  final VoidCallback onAnalyseLaboratoire;
  final VoidCallback onValidationAchats;
  final VoidCallback onAchatsConfirmes;
  final VoidCallback onTableauDeBord;
  final VoidCallback onProfil;
  final VoidCallback onutilisiateurs;
  final VoidCallback onMessagerie;
  final VoidCallback onDeconnexion;

  const CeoDrawer({
    super.key,
    this.currentPage,
    required this.onEchantillons,
    required this.onAnalyseOrganoleptique,
    required this.onAnalyseLaboratoire,
    required this.onValidationAchats,
    required this.onAchatsConfirmes,
    required this.onTableauDeBord,
    required this.onProfil,
    required this.onutilisiateurs,
    required this.onMessagerie,
    required this.onDeconnexion,
  });

  void _navigate(BuildContext context, CeoDestination destination) {
    Navigator.pop(context);
    if (destination == currentPage) return;
    final page = switch (destination) {
      CeoDestination.accueil => const HomePageCeo(),
      CeoDestination.echantillons => const EchantillonsCeoPage(),
      CeoDestination.organoleptique => const AnalyseOrganoleptiqueCeoPage(),
      CeoDestination.laboratoire => const AnalyseLaboratoireCeoPage(),
      CeoDestination.validation => const ValidationAchatsCeoPage(),
      CeoDestination.achats => const AchatsConfirmesCeoPage(),
      CeoDestination.utilisateurs => const UtilisateursCeoPage(),
      CeoDestination.messagerie => const ConversationsPage(),
      CeoDestination.profil => const ProfilceoPage(),
    };
    // La messagerie s'ouvre PAR-DESSUS la page courante : sa flèche de
    // retour ramène à la page d'où l'on vient (elle n'a pas de menu).
    if (destination == CeoDestination.messagerie) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else if (destination == CeoDestination.accueil) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => page),
        (route) => false,
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
                      color: Color.fromARGB(255, 255, 255, 255),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Directeur',
                        style: GoogleFonts.domine(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'STCA Aljazira',
                        style: const TextStyle(fontSize: 12, color: kDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Nav (same as before) ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  const SizedBox(height: 11),

                  const SizedBox(height: 4),
                  _SectionLabel('Tableau de bord'),

                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Tableau de bord',
                    active: currentPage == CeoDestination.accueil,
                    onTap: () => _navigate(context, CeoDestination.accueil),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: kOlive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),
                  _SectionLabel('Échantillons'),
                  _DrawerItem(
                    icon: Icons.science_outlined,
                    label: 'Échantillons',
                    active: currentPage == CeoDestination.echantillons,
                    onTap: () =>
                        _navigate(context, CeoDestination.echantillons),
                  ),
                  _DrawerItem(
                    customIcon: SizedBox(
                      width: 19,
                      height: 19,
                      child: Image.asset('assets/img/glass.png'),
                    ),
                    label: 'Analyse organoleptique',
                    active: currentPage == CeoDestination.organoleptique,
                    onTap: () =>
                        _navigate(context, CeoDestination.organoleptique),
                  ),
                  _DrawerItem(
                    icon: Icons.biotech_outlined,
                    label: 'Analyse laboratoire',
                    active: currentPage == CeoDestination.laboratoire,
                    onTap: () => _navigate(context, CeoDestination.laboratoire),
                  ),
                  _DrawerItem(
                    icon: Icons.fact_check_outlined,
                    label: 'Validation achats',
                    active: currentPage == CeoDestination.validation,
                    onTap: () => _navigate(context, CeoDestination.validation),
                  ),
                  _DrawerItem(
                    icon: Icons.handshake_outlined,
                    label: 'Achats confirmés',
                    active: currentPage == CeoDestination.achats,
                    onTap: () => _navigate(context, CeoDestination.achats),
                  ),

                  const SizedBox(height: 4),
                  Divider(color: kOlive.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 4),
                  _SectionLabel('Compte'),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Utilisateurs',
                    active: currentPage == CeoDestination.utilisateurs,
                    onTap: () =>
                        _navigate(context, CeoDestination.utilisateurs),
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messagerie',
                    active: currentPage == CeoDestination.messagerie,
                    trailing: const MessagerieBadge(),
                    onTap: () => _navigate(context, CeoDestination.messagerie),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    active: currentPage == CeoDestination.profil,
                    onTap: () => _navigate(context, CeoDestination.profil),
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
                  onPressed: onDeconnexion,
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

// _SectionLabel and _DrawerItem stay exactly the same as you had them

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kOlive,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Material(
      color: active ? kHeaderBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? kHeaderBg : _iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: customIcon ?? Icon(icon, color: kGreen, size: 20),
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
                    color: kDark,
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
}
