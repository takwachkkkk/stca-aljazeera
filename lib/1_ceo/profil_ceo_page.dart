// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/profil_ceo_page.dart
// PURPOSE : CEO profile page — personal info and account settings
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/services/profile_service.dart';
import 'package:project3/core/widgets/change_password_dialog.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'widgets/ceo_nav_mixin.dart';
import 'package:google_fonts/google_fonts.dart';

import 'echantillons/echantillons_ceo_page.dart';
import '../../../main.dart';
import 'widgets/ceo_drawer.dart';
import 'achats_confirmes/achats_confirmes_ceo_page.dart';
import 'analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import 'analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import 'utilisateurs/utilisateurs_ceo_page.dart';
import 'tableau_de_bord/tableau_de_bord.dart';

class ProfilceoPage extends StatefulWidget {
  const ProfilceoPage({super.key});

  @override
  _ProfilceoPageState createState() => _ProfilceoPageState();
}

class _ProfilceoPageState extends State<ProfilceoPage> with CeoNavMixin {
  // ── Brand Colors ──────────────────────────────────────────────────────────

  // ── Controllers — empty by default, filled by backend later ──────────────
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _emailController;
  late TextEditingController _numeroController;

  // ── Per-field editing booleans ────────────────────────────────────────────
  bool _editingNom = false;
  bool _editingPrenom = false;
  bool _editingEmail = false;
  bool _editingnumero = false;
  bool _profileLoading = false;
  bool _profileSaving = false;

  // ── Displayed header values ───────────────────────────────────────────────
  String _displayedFullName = '';

  // ── FocusNodes ────────────────────────────────────────────────────────────
  final FocusNode _nomFocus = FocusNode();
  final FocusNode _prenomFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _numeroFocus = FocusNode();

  // ── initState ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // ✅ Empty controllers — no default values
    // Later: populate from Spring Boot API response
    // Example: GET /api/user/profile → _nomController.text = response.nom
    _nomController = TextEditingController(text: '');
    _prenomController = TextEditingController(text: '');
    _emailController = TextEditingController(text: '');
    _numeroController = TextEditingController(text: '');
    _loadProfile();
  }

  // ── dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _numeroController.dispose();
    _nomFocus.dispose();
    _prenomFocus.dispose();
    _emailFocus.dispose();
    _numeroFocus.dispose();
    super.dispose();
  }

  // ── Toggle edit/save ─────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _profileLoading = true);
    try {
      final profile = await profileService.currentProfile();
      if (!mounted) return;
      setState(() {
        _nomController.text = profile.nom;
        _prenomController.text = profile.prenom;
        _emailController.text = profile.email;
        _numeroController.text = profile.telephone ?? '';
        _displayedFullName = profile.nomComplet;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(profileService.messageFor(error));
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<bool> _saveProfile(String successMessage) async {
    if (_profileSaving) return false;
    setState(() => _profileSaving = true);
    try {
      final profile = await profileService.updateCurrentProfile(
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        email: _emailController.text.trim(),
        telephone: _numeroController.text.trim(),
      );
      if (!mounted) return false;
      setState(() {
        _nomController.text = profile.nom;
        _prenomController.text = profile.prenom;
        _emailController.text = profile.email;
        _numeroController.text = profile.telephone ?? '';
        _displayedFullName = profile.nomComplet;
      });
      _showSuccess(successMessage);
      return true;
    } catch (error) {
      if (!mounted) return false;
      _showError(profileService.messageFor(error));
      return false;
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  void _focusField(String fieldKey) {
    FocusNode? focusNode;
    switch (fieldKey) {
      case 'prenom':
        focusNode = _prenomFocus;
        break;
      case 'nom':
        focusNode = _nomFocus;
        break;
      case 'email':
        focusNode = _emailFocus;
        break;
      case 'numero':
        focusNode = _numeroFocus;
        break;
    }
    if (focusNode != null) {
      Future.delayed(const Duration(milliseconds: 50), focusNode.requestFocus);
    }
  }

  Future<void> _toggleEdit(String fieldKey) async {
    if (_profileLoading || _profileSaving) return;
    var enteringEdit = false;
    var successMessage = '';

    setState(() {
      switch (fieldKey) {
        case 'prenom':
          _editingPrenom = !_editingPrenom;
          if (_editingPrenom) {
            enteringEdit = true;
          } else {
            _displayedFullName =
                '${_prenomController.text} ${_nomController.text}'.trim();
            successMessage = 'Prénom mis à jour';
          }
          break;

        case 'nom':
          _editingNom = !_editingNom;
          if (_editingNom) {
            enteringEdit = true;
          } else {
            _displayedFullName =
                '${_prenomController.text} ${_nomController.text}'.trim();
            successMessage = 'Nom mis à jour';
          }
          break;

        case 'email':
          _editingEmail = !_editingEmail;
          if (_editingEmail) {
            enteringEdit = true;
          } else {
            successMessage = 'Email mis à jour';
          }
          break;

        case 'numero':
          _editingnumero = !_editingnumero;
          if (_editingnumero) {
            enteringEdit = true;
          } else {
            successMessage = 'Numéro mis à jour';
          }
          break;
      }
    });

    if (enteringEdit) {
      _focusField(fieldKey);
      return;
    }

    final saved = await _saveProfile(successMessage);
    if (!saved && mounted) {
      setState(() {
        switch (fieldKey) {
          case 'prenom':
            _editingPrenom = true;
            break;
          case 'nom':
            _editingNom = true;
            break;
          case 'email':
            _editingEmail = true;
            break;
          case 'numero':
            _editingnumero = true;
            break;
        }
      });
      _focusField(fieldKey);
    }
  }

  // ── Profile picture bottom sheet ──────────────────────────────────────────
  // ── Build ─────────────────────────────────────────────────────────────────
  /// Back from the profile always lands on the role's home page: the profile
  /// is opened from the menu in place of the previous page, so there is
  /// often nothing behind it to go back to.
  void _retourAccueil() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePageCeo()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _retourAccueil();
    },
    child: _page(context),
  );

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CeoDrawer(
        currentPage: CeoDestination.profil,
        onEchantillons: () => goToPage(const EchantillonsCeoPage()),
        onAnalyseOrganoleptique: () =>
            goToPage(const AnalyseOrganoleptiqueCeoPage()),
        onAnalyseLaboratoire: () => goToPage(const AnalyseLaboratoireCeoPage()),
        onAchatsConfirmes: () => goToPage(const AchatsConfirmesCeoPage()),
        onTableauDeBord: () {
          Navigator.pop(context); // closes the menu
          _retourAccueil();
        },
        onProfil: () => goToPage(const ProfilceoPage()),
        onutilisiateurs: () => goToPage(const UtilisateursCeoPage()),
        onMessagerie: () => goToPage(const ConversationsPage()),
        onDeconnexion: () => goToPage(LoginPage()),
      ),

      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Votre Profil',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ══════════════════════════════════════════════════════════════
            // AVATAR + pen icon
            // ══════════════════════════════════════════════════════════════
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGreen.withOpacity(0.2),
                    border: Border.all(color: kGreen, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: const Icon(Icons.person, size: 60, color: kGreen),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Full name — shows after user saves prenom + nom ──
            if (_displayedFullName.isNotEmpty)
              Text(
                _displayedFullName,
                style: GoogleFonts.domine(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),

            const SizedBox(height: 30),

            // ══════════════════════════════════════════════════════════════
            // INFO CARD
            // ══════════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kGreen.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Informations Personnelles'),
                  const SizedBox(height: 20),

                  // ── Prénom ──
                  _buildField(
                    label: 'Prénom',
                    controller: _prenomController,
                    focusNode: _prenomFocus,
                    icon: Icons.person_outline,
                    isEditing: _editingPrenom,
                    fieldKey: 'prenom',
                    hint: 'Votre prénom',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),

                  // ── Nom ──
                  _buildField(
                    label: 'Nom',
                    controller: _nomController,
                    focusNode: _nomFocus,
                    icon: Icons.person_outline,
                    isEditing: _editingNom,
                    fieldKey: 'nom',
                    hint: 'Votre nom',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),

                  // ── Email ──
                  _buildField(
                    label: 'Email',
                    controller: _emailController,
                    focusNode: _emailFocus,
                    icon: Icons.email_outlined,
                    isEditing: _editingEmail,
                    fieldKey: 'email',
                    hint: 'Votre email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  // ── Email ──
                  _buildField(
                    label: 'Numéro de Téléphone',
                    controller: _numeroController,
                    focusNode: _numeroFocus,
                    icon: Icons.phone_outlined,
                    isEditing: _editingnumero,
                    fieldKey: 'numero',
                    hint: 'Votre Numéro de Téléphone',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Change password ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Changer le mot de passe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: const BorderSide(color: kGreen, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _buildField
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required bool isEditing,
    required String fieldKey,
    required String hint, // ✅ hint is now required
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          readOnly: !isEditing,
          style: TextStyle(
            color: kDark,
            fontSize: 15,
            fontWeight: isEditing ? FontWeight.w500 : FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hint, // ✅ shows hint when field is empty
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: kGreen, size: 20),
            suffixIcon: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isEditing ? kGreen : kGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  isEditing ? Icons.check : Icons.edit,
                  color: isEditing ? Colors.white : kGreen,
                  size: 15,
                ),
              ),
              onPressed: _profileLoading || _profileSaving
                  ? null
                  : () {
                      _toggleEdit(fieldKey);
                    },
            ),
            filled: true,
            fillColor: isEditing ? Colors.white : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isEditing
                  ? BorderSide(color: kGreen.withOpacity(0.5), width: 1.5)
                  : BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _buildLockedField
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLockedField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: value),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            suffixIcon: Icon(
              Icons.lock_outline,
              color: Colors.grey.shade400,
              size: 18,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _sectionTitle
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.domine(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kDark,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _fieldLabel
  // ─────────────────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kOlive,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _bottomSheetItem
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _showSuccess
  // ─────────────────────────────────────────────────────────────────────────
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — _showChangePasswordDialog
  // ─────────────────────────────────────────────────────────────────────────
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(
        accentColor: kGreen,
        labelColor: kOlive,
        titleColor: kDark,
      ),
    );
    if (changed == true && mounted) {
      _showSuccess('Mot de passe changé avec succès');
    }
  }
}
