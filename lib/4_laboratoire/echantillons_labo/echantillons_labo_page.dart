import 'package:project3/core/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/echantillon_labo.dart';
import 'services/labo_service.dart';
import 'widgets/echantillon_labo_card.dart';
import 'widgets/dialogs/formulaire_analyse_labo_dialog.dart';
import '../analyse_labo.dart';
import '../labo_drawer.dart';
import '../notifications/notifications_labo_page.dart';
import '../notifications/services/notification_labo_service.dart';
import '../profil_labo_page.dart';
import '../widgets/labo_nav_mixin.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/rafraichissement_periodique.dart';
import '../../core/widgets/bandeau_demonstration.dart';
import '../../core/widgets/empty_state.dart';

// Scrollbar thumb — neutral dark not in the global palette.
const Color _gray = Color.fromARGB(255, 81, 82, 81);

class EchantillonsLaboPage extends StatefulWidget {
  const EchantillonsLaboPage({
    super.key,
    this.service,
    this.notificationService,
  });

  final LaboService? service;
  final NotificationLaboService? notificationService;

  @override
  State<EchantillonsLaboPage> createState() => _EchantillonsLaboPageState();
}

class _EchantillonsLaboPageState extends State<EchantillonsLaboPage>
    with LaboNavMixin, RafraichissementPeriodique {
  late final LaboService _service;
  late final NotificationLaboService _notifService;
  final TextEditingController _searchCtrl = TextEditingController();
  String _recherche = '';
  StatutAnalyse? _filtreStatut;
  List<EchantillonLabo> _echantillons = [];
  bool _chargement = true;
  bool _estDemonstration = false;
  bool _notificationsDemonstration = false;
  Object? _erreurChargement;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LaboService();
    _notifService = widget.notificationService ?? NotificationLaboService();
    _loadEchantillons();
    _loadUnreadCount();
  }

  Future<void> _loadEchantillons() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final resultat = await _service.fetchEchantillons();
      if (!mounted) return;
      setState(() {
        _echantillons = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
        _chargement = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = erreur;
        _chargement = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final resultat = await _notifService.fetchUnreadCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = resultat.donnees;
        _notificationsDemonstration = resultat.estDemonstration;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  Future<void> _reessayer() async {
    await Future.wait([_loadEchantillons(), _loadUnreadCount()]);
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultats = await Future.wait([
        _service.fetchEchantillons(),
        _notifService.fetchUnreadCount(),
      ]);
      final echantillons = resultats[0];
      final notifications = resultats[1];
      if (!mounted) return;
      if ((echantillons.estDemonstration && !_estDemonstration) ||
          (notifications.estDemonstration && !_notificationsDemonstration)) {
        return;
      }
      setState(() {
        _echantillons = echantillons.donnees as List<EchantillonLabo>;
        _unreadCount = notifications.donnees as int;
        _estDemonstration = echantillons.estDemonstration;
        _notificationsDemonstration = notifications.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  // ── Filter logic ───────────────────────────────────────────────────────────
  List<EchantillonLabo> get _filtres {
    return DegDateUtils.plusRecentsDabord(_echantillons.where((e) {
      final q = _recherche.toLowerCase();
      final matchSearch =
          _recherche.isEmpty ||
          e.referenceBouteille.toLowerCase().contains(q) ||
          e.fournisseurTexte.toLowerCase().contains(q) ||
          e.gouvernorat.toLowerCase().contains(q) ||
          (e.variete?.toLowerCase().contains(q) ?? false) ||
          e.numero.toLowerCase().contains(q) ||
          e.collecteurNom.toLowerCase().contains(q);
      final matchStatut =
          _filtreStatut == null || e.statutAnalyse == _filtreStatut;
      return matchSearch && matchStatut;
    }), (e) => e.dateAjout);
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _onAjouterAnalyse(EchantillonLabo e) {
    showFormulaireAnalyseLaboDialog(
      context,
      echantillonRef: e.referenceBouteille,
      echantillonId: e.id,
      onSave: (analyse) => _saveAnalyse(e, analyse),
    );
  }

  void _onModifierAnalyse(EchantillonLabo e) {
    showFormulaireAnalyseLaboDialog(
      context,
      echantillonRef: e.referenceBouteille,
      echantillonId: e.id,
      analyse: e.analyse,
      onSave: (analyse) => _saveAnalyse(e, analyse),
    );
  }

  Future<void> _saveAnalyse(
    EchantillonLabo e,
    AnalyseLabo analyse, {
    List<int>? photoBytes,
    String? photoName,
  }) async {
    try {
      final saved = await _service.saveAnalyse(
        e.id,
        analyse,
        photoBytes: photoBytes,
        photoName: photoName,
      );
      if (!mounted) return;
      setState(() => e.analyse = saved);
      final msg = saved.statut == StatutAnalyse.soumis
          ? 'Analyse soumise pour ${e.referenceBouteille}'
          : 'Brouillon d\'analyse enregistre';
      _showSnack(msg);
    } catch (error) {
      if (mounted) _showSnack(_service.messageFor(error), isError: true);
    }
  }

  void _onSupprimerAnalyse(EchantillonLabo e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Supprimer l\'analyse',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Supprimer l\'analyse de ${e.referenceBouteille} ? '
          'Vous pourrez en soumettre une nouvelle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: kGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnalyse(e);
            },
            child: Text(
              'Supprimer',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _deleteAnalyse(EchantillonLabo e) async {
    try {
      await _service.deleteAnalyse(e.id);
      if (!mounted) return;
      setState(() => e.analyse = null);
      _showSnack('Analyse supprimee');
    } catch (error) {
      if (mounted) _showSnack(_service.messageFor(error), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError ? Colors.red.shade600 : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _showAnalyseReadOnly(EchantillonLabo e) {
    showFormulaireAnalyseLaboDialog(
      context,
      echantillonRef: e.referenceBouteille,
      echantillonId: e.id,
      analyse: e.analyse,
      readOnly: true,
      onSave: (_) {},
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtres;

    return Scaffold(
      backgroundColor: kBg,
      drawer: LaboDrawer(currentPage: LaboDestination.echantillons),
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Échantillons à analyser',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: kDark),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsLaboPage(),
                  ),
                ).then((_) => _loadUnreadCount()),
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: _unreadCount > 9 ? 18 : 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _reessayer,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: kGreen,
              child: Column(
                children: [
                  // ── Header zone ──────────────────────────────────────────────────
                  Container(
                    color: kHeaderBg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _recherche = v),
                          style: const TextStyle(fontSize: 14, color: kDark),
                          decoration: InputDecoration(
                            hintText:
                                'Rechercher réf, fournisseur, gouvernorat…',
                            hintStyle: const TextStyle(
                              color: Color(0xFF6B8E7A),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF6B8E7A),
                              size: 20,
                            ),
                            suffixIcon: _recherche.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 17,
                                      color: Color(0xFF6B8E7A),
                                    ),
                                    onPressed: () => setState(() {
                                      _recherche = '';
                                      _searchCtrl.clear();
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
                        // Filter chips
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _StatutChip(
                                label: 'Tous',
                                inactiveColor: const Color(0xFFF0F0F0),
                                inactiveTextColor: const Color(0xFF757575),
                                selected: _filtreStatut == null,
                                onTap: () =>
                                    setState(() => _filtreStatut = null),
                              ),
                              const SizedBox(width: 7),
                              _StatutChip(
                                label: 'Analyse en attente',
                                inactiveColor: const Color(0xFFE8F1FB),
                                inactiveTextColor: const Color(0xFF3A6EA5),
                                selected:
                                    _filtreStatut == StatutAnalyse.enAttente,
                                onTap: () => setState(
                                  () => _filtreStatut = StatutAnalyse.enAttente,
                                ),
                              ),
                              const SizedBox(width: 7),
                              _StatutChip(
                                label: 'Analyse en cours',
                                inactiveColor: const Color(0xFFFEF3E8),
                                inactiveTextColor: const Color(0xFFD07B2F),
                                selected:
                                    _filtreStatut == StatutAnalyse.enCours,
                                onTap: () => setState(
                                  () => _filtreStatut = StatutAnalyse.enCours,
                                ),
                              ),
                              const SizedBox(width: 7),
                              _StatutChip(
                                label: 'Analyse soumise',
                                inactiveColor: const Color(0xFFE6F4ED),
                                inactiveTextColor: const Color(0xFF38835A),
                                selected: _filtreStatut == StatutAnalyse.soumis,
                                onTap: () => setState(
                                  () => _filtreStatut = StatutAnalyse.soumis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),

                  // ── List ──────────────────────────────────────────────────────────
                  Expanded(
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.science_outlined,
                                        size: 52,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _echantillons.isEmpty
                                            ? kTitreSystemeNeuf
                                            : 'Aucun échantillon trouvé',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (_echantillons.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            32,
                                            6,
                                            32,
                                            0,
                                          ),
                                          child: Text(
                                            kTexteSystemeNeuf,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Theme(
                            data: Theme.of(context).copyWith(
                              scrollbarTheme: ScrollbarThemeData(
                                thumbColor: WidgetStateProperty.all(_gray),
                              ),
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  100,
                                ),
                                itemCount: items.length,
                                itemBuilder: (_, i) {
                                  final e = items[i];
                                  final canEdit =
                                      e.analyse != null &&
                                      e.analyse!.statut != StatutAnalyse.soumis;
                                  return EchantillonLaboCard(
                                    echantillon: e,
                                    onAjouterAnalyse: e.analyse == null
                                        ? () => _onAjouterAnalyse(e)
                                        : null,
                                    onVoirAnalyse: e.analyse != null
                                        ? () => _showAnalyseReadOnly(e)
                                        : null,
                                    onModifierAnalyse: canEdit
                                        ? () => _onModifierAnalyse(e)
                                        : null,
                                    onSupprimerAnalyse: canEdit
                                        ? () => _onSupprimerAnalyse(e)
                                        : null,
                                  );
                                },
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

// ── Statut chip — soft pastel inactive, tinted active (matches taster design) ──
class _StatutChip extends StatelessWidget {
  final String label;
  final Color inactiveColor;
  final Color inactiveTextColor;
  final bool selected;
  final VoidCallback onTap;

  const _StatutChip({
    required this.label,
    required this.inactiveColor,
    required this.inactiveTextColor,
    required this.selected,
    required this.onTap,
  });

  static const Color _inactiveBg = kChipBgGrey;
  static const Color _inactiveFg = Color(0xFF9E9E9E);
  static const Color _inactiveBorder = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    final bool isTous = label == 'Tous';

    final Color bg;
    final Color fg;
    final Color border;

    if (!selected) {
      bg = _inactiveBg;
      fg = _inactiveFg;
      border = _inactiveBorder;
    } else if (isTous) {
      bg = const Color(0xFF757575);
      fg = Colors.white;
      border = const Color(0xFF757575);
    } else {
      bg = inactiveColor;
      fg = inactiveTextColor;
      border = inactiveTextColor.withValues(alpha: 0.45);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        (isTous ? const Color(0xFF757575) : inactiveTextColor)
                            .withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
