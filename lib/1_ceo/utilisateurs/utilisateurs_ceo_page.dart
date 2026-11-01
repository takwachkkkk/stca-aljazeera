import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utilisateurs/utilisateurs_page_body.dart';
import '../../core/widgets/messagerie/conversations_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import '../analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import '../echantillons/echantillons_ceo_page.dart';
import '../profil_ceo_page.dart';
import '../tableau_de_bord/tableau_de_bord.dart';
import '../widgets/ceo_drawer.dart';
import '../widgets/ceo_nav_mixin.dart';

class UtilisateursCeoPage extends StatefulWidget {
  const UtilisateursCeoPage({super.key});

  @override
  State<UtilisateursCeoPage> createState() => _UtilisateursCeoPageState();
}

class _UtilisateursCeoPageState extends State<UtilisateursCeoPage>
    with CeoNavMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      drawer: CeoDrawer(
        currentPage: CeoDestination.utilisateurs,
        onEchantillons: () => goToPage(const EchantillonsCeoPage()),
        onAnalyseOrganoleptique: () =>
            goToPage(const AnalyseOrganoleptiqueCeoPage()),
        onAnalyseLaboratoire: () => goToPage(const AnalyseLaboratoireCeoPage()),
        onAchatsConfirmes: () => goToPage(const AchatsConfirmesCeoPage()),
        onTableauDeBord: () => goToPage(const HomePageCeo()),
        onProfil: () => goToPage(const ProfilceoPage()),
        onutilisiateurs: () => Navigator.pop(context),
        onMessagerie: () => goToPage(const ConversationsPage()),
        onDeconnexion: goToLogin,
      ),
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Utilisateurs',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
      ),
      body: const UtilisateursPageBody(peutGerer: false),
    );
  }
}
