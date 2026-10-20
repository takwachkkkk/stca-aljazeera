// ═════════════════════════════════════════════════════════════════════════════
// FILE    : evaluation_echantillons/evaluation_echantillons_page.dart
// PURPOSE : THE BRAIN — owns all state, filter logic, navigation
// ═════════════════════════════════════════════════════════════════════════════

import 'package:project3/core/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';

// ── Page imports ──────────────────────────────────────────────────────────────
import '../tableau_de_bord/widgets/app_drawer.dart';
import '../utilisateurs/utilisateurs_chef_page.dart';
import '../widgets/statut_chip.dart';
import '../../../main.dart';
import '../profil.dart';

import '../gestion_echantillons/gestion_echantillons_page.dart';
import '../formulaire_evaluation.dart';
import '../sessions_degustation/sessions_degustation_page.dart';
import '../analyse_labo/analyse_laboratoire_page.dart';
import '../vue_ensemble_evaluations/vue_ensemble_evaluations_page.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/chef_nav_mixin.dart';
import '../../../core/utils/date_filter_utils.dart';
import '../../../core/utils/rafraichissement_periodique.dart';
import '../../../core/widgets/bandeau_demonstration.dart';

// ── Own model ─────────────────────────────────────────────────────────────────
import '../../core/models/echantillon_evaluation.dart';
import 'package:project3/core/services/evaluation_service.dart';

// ── Own widgets ───────────────────────────────────────────────────────────────
import 'package:project3/core/widgets/evaluation_echantillons/echantillon_card.dart';
import 'navigation/widgets/empty_state.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';

class EvaluationEchantillonsPage extends StatefulWidget {
  final String? echantillonCible;
  final EvaluationService? service;

  const EvaluationEchantillonsPage({
    super.key,
    this.echantillonCible,
    this.service,
  });

  @override
  _EvaluationEchantillonsPageState createState() =>
      _EvaluationEchantillonsPageState();
}

class _EvaluationEchantillonsPageState extends State<EvaluationEchantillonsPage>
    with ChefNavMixin, RafraichissementPeriodique {
  // ── STATE ────────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _cibleKey = GlobalKey();
  bool _cibleIntrouvableSignalee = false;
  String _recherche = '';
  String? _filtreStatutLabel;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateType = DateFilterType.enregistrement;

  static const _dateFilterTypes = [
    DateFilterType.enregistrement,
    DateFilterType.livraisonEchantillon,
    DateFilterType.receptionPhysique,
  ];

  bool get _dateFilterActive => _dateDebut != null || _dateFin != null;
  bool get _anyFilter =>
      _dateFilterActive || _recherche.isNotEmpty || _filtreStatutLabel != null;

  // ── DATA ──────────────────────────────────────────────────────────────────────
  late final EvaluationService _service;
  List<Echantillon> _echantillons = [];
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EvaluationService();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final resultat = await _service.fetchEchantillons();
      if (!mounted) return;
      setState(() {
        _echantillons = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
      _positionnerCible();
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await _service.fetchEchantillons();
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _echantillons = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  void _positionnerCible() {
    final cible = widget.echantillonCible;
    if (cible == null) return;
    final index = _echantillonsFiltres.indexWhere((e) => e.id == cible);
    if (index == -1) {
      if (_cibleIntrouvableSignalee) return;
      _cibleIntrouvableSignalee = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "L'échantillon demandé n'est plus disponible dans cette liste.",
            ),
          ),
        );
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final positionApproximative = (index * 104.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      await _scrollController.animateTo(
        positionApproximative,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      final cibleContext = _cibleKey.currentContext;
      if (cibleContext != null && cibleContext.mounted) {
        await Scrollable.ensureVisible(
          cibleContext,
          duration: const Duration(milliseconds: 250),
          alignment: 0.2,
        );
      }
    });
  }

  // ── FILTER LOGIC ─────────────────────────────────────────────────────────────
  StatutEchantillon? _labelToStatut(String? label) {
    switch (label) {
      case 'Non évaluée':
        return StatutEchantillon.enAttente;
      case 'Évaluation en cours':
        return StatutEchantillon.enCours;
      case 'Évaluation soumise':
        return StatutEchantillon.soumis;
      default:
        return null;
    }
  }

  List<Echantillon> get _echantillonsFiltres {
    return DegDateUtils.plusRecentsDabord(_echantillons.where((e) {
      final q = _recherche.toLowerCase();
      final matchRecherche =
          _recherche.isEmpty ||
          e.id.toLowerCase().contains(q) ||
          e.referenceBouteille.toLowerCase().contains(q) ||
          e.fournisseur.toLowerCase().contains(q) ||
          e.variete.toLowerCase().contains(q) ||
          (e.gouvernorat?.toLowerCase().contains(q) ?? false) ||
          (e.delegation?.toLowerCase().contains(q) ?? false) ||
          (e.collecteur?.toLowerCase().contains(q) ?? false);

      final filtreEnum = _labelToStatut(_filtreStatutLabel);
      final matchStatut = filtreEnum == null || e.statut == filtreEnum;

      final matchDate = dateCorrespondAuFiltre(
        dateEvaluationEchantillon(e, _dateType),
        debut: _dateDebut,
        fin: _dateFin,
      );

      return matchRecherche && matchStatut && matchDate;
    }), (e) => e.dateAjout);
  }

  // ── ACTION ────────────────────────────────────────────────────────────────────

  Future<void> _onActionEchantillon(Echantillon e) async {
    if (e.statut == StatutEchantillon.enAttente) {
      setState(() => e.statut = StatutEchantillon.enCours);
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FormulaireEvaluationPage(
          echantillonId: e.id,
          numero: e.numero,
          fournisseur: e.fournisseur,
          variete: e.variete,
          origine: e.gouvernorat ?? 'Non spécifiée',
          dateArrivee: e.dateArriveeEchantillon,
          photoUrl: e.photoUrl,
        ),
      ),
    );

    // result is classification label when submitted, null if just navigated back
    if (result != null && mounted) {
      setState(() {
        e.statut = StatutEchantillon.soumis;
        e.classification = result;
      });
    }
  }

  void _onVoir(Echantillon e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormulaireEvaluationPage(
          echantillonId: e.id,
          numero: e.numero,
          fournisseur: e.fournisseur,
          variete: e.variete,
          origine: e.gouvernorat ?? 'Non spécifiée',
          dateArrivee: e.dateArriveeEchantillon,
          photoUrl: e.photoUrl,
          readOnly: true,
          classification: e.classification,
        ),
      ),
    );
  }

  // ── Date filter sheet ─────────────────────────────────────────────────────────
  Future<void> _showDateFilter() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        availableTypes: _dateFilterTypes,
        initialType: _dateType,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        onApply: (debut, fin) => setState(() {
          _dateDebut = debut;
          _dateFin = fin;
        }),
        onApplyTyped: (debut, fin, type) => setState(() {
          _dateDebut = debut;
          _dateFin = fin;
          _dateType = type;
        }),
        onClear: () => setState(() {
          _dateDebut = null;
          _dateFin = null;
        }),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtres = _echantillonsFiltres;

    return Scaffold(
      backgroundColor: kBg,

      drawer: AppDrawer(currentPage: ChefDestination.evaluation),

      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Évaluation des échantillons',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _dateFilterActive ? kGreen : const Color(0xFF6B8E7A),
                ),
                onPressed: _showDateFilter,
                tooltip: _dateFilterActive
                    ? 'Filtré par : ${_dateType.label}'
                    : 'Filtrer par date',
              ),
              if (_dateFilterActive)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: VueResultatService(
        estDemonstration: _estDemonstration,
        erreur: _erreurChargement,
        onReessayer: _loadData,
        onRefresh: _loadData,
        couleurRafraichissement: kGreen,
        child: Column(
          children: [
            // ── UNIFIED HEADER ZONE ────────────────────────────────────────────
            Container(
              color: kHeaderBg,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _recherche = v.trim()),
                    style: const TextStyle(fontSize: 14, color: kDark),
                    decoration: InputDecoration(
                      hintText: 'Rechercher réf, fournisseur, gouvernorat…',
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
                        borderSide: const BorderSide(color: kGreen, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 11),

                  // ── Statut filter chips ─────────────────────────────────────
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        StatutChip(
                          label: 'Tous',
                          activeColor: const Color(0xFF616161),
                          inactiveColor: const Color(0xFFF0F0F0),
                          inactiveTextColor: const Color(0xFF757575),
                          selected: _filtreStatutLabel == null,
                          onTap: () =>
                              setState(() => _filtreStatutLabel = null),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Non évaluée',
                          activeColor: const Color(0xFF3A6EA5),
                          inactiveColor: const Color(0xFFE8F1FB),
                          inactiveTextColor: const Color(0xFF3A6EA5),
                          selected: _filtreStatutLabel == 'Non évaluée',
                          onTap: () => setState(
                            () => _filtreStatutLabel = 'Non évaluée',
                          ),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Évaluation en cours',
                          activeColor: const Color(0xFFD07B2F),
                          inactiveColor: const Color(0xFFFEF3E8),
                          inactiveTextColor: const Color(0xFFD07B2F),
                          selected: _filtreStatutLabel == 'Évaluation en cours',
                          onTap: () => setState(
                            () => _filtreStatutLabel = 'Évaluation en cours',
                          ),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Évaluation soumise',
                          activeColor: kGreen,
                          inactiveColor: const Color(0xFFE6F4ED),
                          inactiveTextColor: kGreen,
                          selected: _filtreStatutLabel == 'Évaluation soumise',
                          onTap: () => setState(
                            () => _filtreStatutLabel = 'Évaluation soumise',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Thin separator shadow
            Container(height: 1, color: Colors.black.withValues(alpha: 0.06)),

            // ── LIST ────────────────────────────────────────────────────────────
            Expanded(
              child: filtres.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: EmptyState(systemeNeuf: _echantillons.isEmpty),
                        ),
                      ],
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: filtres.length,
                        itemBuilder: (context, index) {
                          final e = filtres[index];
                          return EchantillonCard(
                            key: e.id == widget.echantillonCible
                                ? _cibleKey
                                : ValueKey(e.id),
                            echantillon: e,
                            isHighlighted: e.id == widget.echantillonCible,
                            onAction: () => _onActionEchantillon(e),
                            onVoir: () => _onVoir(e),
                          );
                        },
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
// STATUT CHIP — soft pastel inactive, solid color active
