// ═════════════════════════════════════════════════════════════════════════════
// FILE : core/utilisateurs/utilisateurs_page_body.dart
// PURPOSE : Shared user page — view all users, their roles,
//           contact info, status, and perform admin actions.
// DATA   : Reads from the Django API, with mockUtilisateurs kept as fallback.
// STYLE  : Matches ProfilceoPage — same palette, fonts, and component style.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:project3/core/fonctionnalites.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/widgets/saisie_protegee.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../models/enums.dart';
import '../widgets/bandeau_demonstration.dart';
import 'utilisateurs_service.dart';
import 'widgets/user_card.dart';
import 'widgets/user_created_dialog.dart';

// ── Local aliases — keep page code unchanged while using core types ────────────
typedef UserRole = RoleUtilisateur;

class UtilisateursPageBody extends StatefulWidget {
  /// Quand false, la page est en consultation : ni bouton d'ajout, ni bascule
  /// d'activation, ni suppression. Le serveur reste le vrai garde-fou.
  final bool peutGerer;
  final UtilisateursService? service;

  const UtilisateursPageBody({
    super.key,
    required this.peutGerer,
    this.service,
  });

  @override
  State<UtilisateursPageBody> createState() => _UtilisateursPageBodyState();
}

class _UtilisateursPageBodyState extends State<UtilisateursPageBody>
    with RafraichissementPeriodique {
  late final UtilisateursService _service;
  // ── Neutral user identity colors ───────────────────────────────────────────
  static const _roleColors = {
    UserRole.direction: (bg: Color(0xFFF1F3F2), fg: Color(0xFF4A5A50)),
    UserRole.laboratoire: (bg: Color(0xFFF1F3F2), fg: Color(0xFF4A5A50)),
    UserRole.degustateur: (bg: Color(0xFFF1F3F2), fg: Color(0xFF4A5A50)),
    UserRole.collecteur: (bg: Color(0xFFF1F3F2), fg: Color(0xFF4A5A50)),
    UserRole.chefDegustation: (bg: Color(0xFFF1F3F2), fg: Color(0xFF4A5A50)),
    UserRole.serviceAchat: (bg: Color(0xFFF1F3F2), fg: Color(0xFF4A5A50)),
  };

  // ── Data ──────────────────────────────────────────────────────────────────
  List<UserProfile> _utilisateurs = [];
  bool _isLoading = false;
  bool _isMutating = false;
  bool _usesMockData = false;
  Object? _loadError;

  // ── Local UI state ─────────────────────────────────────────────────────────
  UserRole? _activeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Derived filtered list ──────────────────────────────────────────────────
  List<UserProfile> get _filtered {
    return _utilisateurs.where((u) {
      final matchRole = _activeFilter == null || u.role == _activeFilter;
      final q = _searchQuery.toLowerCase();
      final matchSearch =
          q.isEmpty ||
          u.nomComplet.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.telephone?.contains(q) ?? false);
      return matchRole && matchSearch;
    }).toList();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? utilisateursService;
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final resultat = await _service.fetchUsers();
      if (!mounted) return;
      setState(() {
        _utilisateurs = resultat.donnees;
        _usesMockData = resultat.estDemonstration;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await _service.fetchUsers();
      if (!mounted || (resultat.estDemonstration && !_usesMockData)) {
        return;
      }
      setState(() {
        _utilisateurs = resultat.donnees;
        _usesMockData = resultat.estDemonstration;
        _loadError = null;
      });
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Stack(
      children: [
        Positioned.fill(
          child: _isLoading && _utilisateurs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : VueResultatService(
                  estDemonstration: _usesMockData,
                  erreur: _loadError,
                  onReessayer: _loadUsers,
                  onRefresh: rechargerEnSilence,
                  couleurRafraichissement: kGreen,
                  child: Column(
                    children: [
                      // ── Unified header zone ──────────────────────────────────────
                      Container(
                        color: kHeaderBg,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v.trim()),
                              style: const TextStyle(
                                fontSize: 14,
                                color: kDark,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Rechercher par nom, email ou téléphone…',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF6B8E7A),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF6B8E7A),
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 17,
                                          color: Color(0xFF6B8E7A),
                                        ),
                                        onPressed: () => setState(() {
                                          _searchQuery = '';
                                          _searchController.clear();
                                        }),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: kGreen,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            SizedBox(height: 34, child: _buildFilterChips()),
                          ],
                        ),
                      ),
                      Container(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmpty()
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  widget.peutGerer ? 100 : 24,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => UserCard(
                                  user: filtered[i],
                                  green: kGreen,
                                  darkText: kDark,
                                  roleColors: _roleColors,
                                  peutGerer: widget.peutGerer,
                                  onToggleStatus: () =>
                                      _confirmToggleStatus(filtered[i]),
                                  onDelete: () => _confirmDelete(filtered[i]),
                                  onViewProfile: () =>
                                      _showUserProfile(filtered[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
        if (widget.peutGerer)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              key: const ValueKey('utilisateurs_ajouter'),
              onPressed: _isLoading || _usesMockData ? null : _showAddUserSheet,
              backgroundColor: const Color.fromARGB(255, 197, 206, 201),
              elevation: 2,
              icon: const Icon(Icons.person_add_outlined, color: kDark),
              label: Text(
                'Ajouter',
                style: GoogleFonts.domine(
                  color: kDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────
  // Inactive = gray (like current "Tous" inactive).
  // Active   = role-colored kBg + colored text (like current inactive role chips).
  Widget _buildFilterChips() {
    // (label, role, activeBg, activeFg)
    const chips = [
      (
        label: 'Tous',
        role: null as UserRole?,
        activeBg: Color(0xFF757575),
        activeFg: Colors.white,
      ),
      (
        label: 'CEO',
        role: UserRole.direction as UserRole?,
        activeBg: Color(0xFFE6F1FB),
        activeFg: Color(0xFF185FA5),
      ),
      if (kLaboActif)
        (
          label: 'Laboratoire',
          role: UserRole.laboratoire as UserRole?,
          activeBg: Color(0xFFFAEEDA),
          activeFg: Color(0xFF854F0B),
        ),
      (
        label: 'Dégustateur',
        role: UserRole.degustateur as UserRole?,
        activeBg: Color(0xFFE1F5EE),
        activeFg: Color(0xFF0F6E56),
      ),
      (
        label: 'Collecteur',
        role: UserRole.collecteur as UserRole?,
        activeBg: Color(0xFFFBEAF0),
        activeFg: Color(0xFF993556),
      ),
      (
        label: 'Chef Dégustation',
        role: UserRole.chefDegustation as UserRole?,
        activeBg: Color(0xFFF3EBF9),
        activeFg: Color(0xFF6A3D9A),
      ),
      (
        label: 'Service achat',
        role: UserRole.serviceAchat as UserRole?,
        activeBg: Color(0xFFFEF3E8),
        activeFg: Color(0xFFD07B2F),
      ),
    ];

    const Color inactiveBg = Color(0xFFF0F0F0);
    const Color inactiveFg = Color(0xFF757575);

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (_, i) {
        final chip = chips[i];
        final isActive = _activeFilter == chip.role;
        final kBg = isActive ? chip.activeBg : inactiveBg;
        final fg = isActive ? chip.activeFg : inactiveFg;

        return GestureDetector(
          onTap: () => setState(() => _activeFilter = chip.role),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? chip.activeFg.withValues(alpha: 0.4)
                    : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            child: Text(
              chip.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aucun utilisateur trouvé',
                  style: GoogleFonts.domine(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Toggle active / inactive ───────────────────────────────────────────────
  void _confirmToggleStatus(UserProfile user) {
    final action = user.isActive ? 'désactiver' : 'réactiver';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Confirmer',
          style: GoogleFonts.domine(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        content: Text(
          'Voulez-vous $action le compte de ${user.nomComplet} ?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _isMutating
                ? null
                : () async {
                    Navigator.pop(context);
                    await _toggleUserStatus(user);
                  },
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            child: Text(
              user.isActive ? 'Désactiver' : 'Réactiver',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  void _confirmDelete(UserProfile user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Supprimer l'utilisateur",
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.red.shade700,
          ),
        ),
        content: Text(
          'Cette action est irréversible. Voulez-vous supprimer '
          '${user.nomComplet} ?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _isMutating
                ? null
                : () async {
                    Navigator.pop(context);
                    await _deleteUser(user);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(UserProfile user) async {
    if (_isMutating) return;
    if (user.estSupprime) {
      _showError('Un utilisateur supprimé ne peut pas être réactivé.');
      return;
    }
    if (_usesMockData) {
      _showError(
        'Action indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.',
      );
      return;
    }

    setState(() => _isMutating = true);
    try {
      final updated = await _service.toggleActive(user.id);
      if (!mounted) return;
      setState(() {
        final idx = _utilisateurs.indexWhere((u) => u.id == user.id);
        if (idx != -1) _utilisateurs[idx] = updated;
      });
      _showSuccess(
        updated.isActive
            ? '${updated.nomComplet} réactivé'
            : '${updated.nomComplet} désactivé',
      );
    } catch (error) {
      if (!mounted) return;
      _showError(_service.messageFor(error));
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteUser(UserProfile user) async {
    if (_isMutating) return;
    if (_usesMockData) {
      _showError(
        'Action indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.',
      );
      return;
    }

    setState(() => _isMutating = true);
    try {
      await _service.deleteUser(user.id);
      if (!mounted) return;
      await _loadUsers();
      _showSuccess('${user.nomComplet} supprimé');
    } catch (error) {
      if (!mounted) return;
      _showError(_service.messageFor(error));
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  // ── Profile bottom sheet ───────────────────────────────────────────────────
  void _showUserProfile(UserProfile user) {
    final colors = _roleColors[user.role]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colors.bg,
                    child: Text(
                      user.initiales,
                      style: TextStyle(
                        color: colors.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nomComplet,
                          style: GoogleFonts.domine(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.role.label,
                            style: TextStyle(
                              color: colors.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 16),
              Text(
                'Informations',
                style: GoogleFonts.domine(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 12),
              _infoTile(Icons.email_outlined, 'Email', user.email),
              _infoTile(
                Icons.phone_outlined,
                'Téléphone',
                user.telephone ?? '—',
              ),
              _infoTile(
                Icons.calendar_today_outlined,
                'Date de début',
                DegDateUtils.formaterAffichage(user.dateCreation),
              ),
              _infoTile(
                Icons.verified_user_outlined,
                'Statut',
                user.statutLabel,
              ),
              _infoTile(Icons.badge_outlined, 'Rôle', user.role.label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kGreen),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: kOlive,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(value, style: TextStyle(fontSize: 14, color: kDark)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Add user bottom sheet ──────────────────────────────────────────────────
  void _showAddUserSheet() {
    final nomCtrl = TextEditingController();
    final prenomCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    UserRole selectedRole = UserRole.degustateur;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SaisieProtegee(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle + close ────────────────────────────────
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 17,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Single card: title + role picker ──────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE8E8E8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_add_outlined,
                              color: kDark,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Nouvel Utilisateur',
                            style: GoogleFonts.domine(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: Colors.grey.shade100, height: 1),
                      const SizedBox(height: 14),

                      // Role label
                      const Text(
                        'Rôle',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kOlive,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<UserRole>(
                        value: selectedRole,
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                            color: kGreen,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: kGreen, width: 2),
                          ),
                        ),
                        items: UserRole.values
                            .where(
                              (role) =>
                                  kLaboActif || role != UserRole.laboratoire,
                            )
                            .map(
                              (role) => DropdownMenuItem<UserRole>(
                                value: role,
                                child: Text(role.label),
                              ),
                            )
                            .toList(),
                        onChanged: (role) {
                          if (role != null) {
                            setSheet(() => selectedRole = role);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Form fields ────────────────────────────────────────
                _addField(
                  prenomCtrl,
                  'Prénom',
                  Icons.person_outline,
                  TextInputType.name,
                ),
                const SizedBox(height: 14),
                _addField(
                  nomCtrl,
                  'Nom',
                  Icons.person_outline,
                  TextInputType.name,
                ),
                const SizedBox(height: 14),
                _addField(
                  emailCtrl,
                  'Email',
                  Icons.email_outlined,
                  TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _addField(
                  telCtrl,
                  'Téléphone',
                  Icons.phone_outlined,
                  TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // ── Action buttons ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.domine(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (prenomCtrl.text.isEmpty ||
                                    nomCtrl.text.isEmpty ||
                                    emailCtrl.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Veuillez remplir tous les champs obligatoires',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setSheet(() => isSaving = true);
                                try {
                                  final creation = await _service.createUser(
                                    prenom: prenomCtrl.text.trim(),
                                    nom: nomCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    role: selectedRole,
                                    telephone: telCtrl.text.trim(),
                                  );
                                  final newUser = creation.utilisateur;
                                  if (!mounted) return;
                                  setState(() => _utilisateurs.add(newUser));
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _showUserCreatedDialog(
                                    newUser.prenom,
                                    newUser.nom,
                                    newUser.email,
                                    newUser.role.label,
                                    creation.motDePasseTemporaire,
                                    creation.emailUtilisateurEnvoye,
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  _showError(_service.messageFor(error));
                                } finally {
                                  if (ctx.mounted) {
                                    setSheet(() => isSaving = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            197,
                            206,
                            201,
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Enregistrer',
                          style: GoogleFonts.domine(
                            color: kDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    TextInputType type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kOlive,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          style: TextStyle(color: kDark, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: kGreen, size: 18),
            hintText: label,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 14,
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
              borderSide: const BorderSide(color: kGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ── User-created success dialog (auto-closes after 4 s) ───────────────────
  void _showUserCreatedDialog(
    String prenom,
    String nom,
    String email,
    String role,
    String? motDePasseTemporaire,
    bool emailUtilisateurEnvoye,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => UserCreatedDialog(
        prenom: prenom,
        nom: nom,
        email: email,
        role: role,
        motDePasseTemporaire: motDePasseTemporaire,
        emailUtilisateurEnvoye: emailUtilisateurEnvoye,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _todayFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';
  }

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
}
