// ═════════════════════════════════════════════════════════════════════════════
// FILE    : analyse_laboratoire/analyse_laboratoire_page.dart
// PURPOSE : THE BRAIN — owns all state, filter logic, actions
// ═════════════════════════════════════════════════════════════════════════════

import 'package:project3/core/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/analyses/ligne_analyse_labo.dart';
import '../../../core/analyses/ligne_analyse_labo_service.dart';
import 'package:project3/core/widgets/analyse_labo/analyse_card.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../core/widgets/bandeau_demonstration.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_filter_utils.dart';
import '../../../core/utils/rafraichissement_periodique.dart';
import '../widgets/degustateur_nav_mixin.dart';
import '../tableau_de_bord/homepage_page.dart';
import '../profil/profil_page.dart';
import '../tableau_de_bord/widgets/app_drawer.dart';
import '../membres_panel/membres_panel_page.dart';
import '../gestion_echantillons/gestion_echantillons_page.dart';
import '../evaluation_echantillons/evaluation_echantillons_page.dart';
import '../sessions_degustation/sessions_degustation_page.dart';
import '../widgets/deg_colors.dart';

class AnalyseLaboratoirePage extends StatefulWidget {
  const AnalyseLaboratoirePage({super.key});

  @override
  State<AnalyseLaboratoirePage> createState() => _AnalyseLaboratoirePageState();
}

class _AnalyseLaboratoirePageState extends State<AnalyseLaboratoirePage>
    with DegustateurNavMixin, RafraichissementPeriodique {
  final _service = LigneAnalyseLaboService();

  // ── STATE ────────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _recherche = '';
  String? _filtreStatutLabel; // null = all
  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateType = DateFilterType.enregistrement;

  static const _dateFilterTypes = [
    DateFilterType.enregistrement,
    DateFilterType.livraisonEchantillon,
    DateFilterType.receptionPhysique,
  ];

  String get _dateTypeLabel => _dateType.label;

  // ── STATE ────────────────────────────────────────────────────────────────────
  List<LigneAnalyseLabo> _analyses = [];
  final Set<String> _urgentSent = {};
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final resultat = await _service.fetchAnalyses();
      if (!mounted) return;
      setState(() {
        _analyses = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreurChargement = erreur);
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await _service.fetchAnalyses();
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _analyses = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  // ── FILTER LOGIC ─────────────────────────────────────────────────────────────
  StatutAnalyse? _labelToStatut(String? label) {
    switch (label) {
      case 'Analyse en attente':
        return StatutAnalyse.enAttente;
      case 'Analyse soumise':
        return StatutAnalyse.soumise;
      default:
        return null;
    }
  }

  List<LigneAnalyseLabo> get _filtres {
    return DegDateUtils.plusRecentsDabord(_analyses.where((a) {
      final matchRecherche =
          _recherche.isEmpty ||
          a.echantillonNom.toLowerCase().contains(_recherche.toLowerCase()) ||
          a.referenceBouteille.toLowerCase().contains(
            _recherche.toLowerCase(),
          ) ||
          a.numero.toLowerCase().contains(_recherche.toLowerCase()) ||
          a.id.toLowerCase().contains(_recherche.toLowerCase()) ||
          a.technicienNom.toLowerCase().contains(_recherche.toLowerCase());

      final filtreEnum = _labelToStatut(_filtreStatutLabel);
      final matchStatut = switch (_filtreStatutLabel) {
        'Pas encore reçu' => !a.recuPhysiquement,
        'Analyse en attente' =>
          a.recuPhysiquement && a.statut == StatutAnalyse.enAttente,
        _ => filtreEnum == null || a.statut == filtreEnum,
      };

      final matchDate = dateCorrespondAuFiltre(
        dateAnalyseLabo(a, _dateType),
        debut: _dateDebut,
        fin: _dateFin,
      );

      return matchRecherche && matchStatut && matchDate;
    }), (a) => a.dateAjout);
  }

  // ── Date filter sheet ─────────────────────────────────────────────────────────
  Future<void> _showDateFilter() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        titre: 'Filtrer par date',
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

  void _confirmSendUrgent(LigneAnalyseLabo a) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                color: Color(0xFFC62828),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Notifier le laboratoire',
                    style: GoogleFonts.domine(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'Envoyer une demande urgente au technicien laboratoire pour prioriser l\'analyse chimique de ${a.echantillonNom} ?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A2E1F),
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(color: Color(0xFF6B8E7A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendUrgent(a);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Notifier',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendUrgent(LigneAnalyseLabo analyse) async {
    try {
      await _service.sendUrgentAnalyseLabo(
        analyse.echantillonId,
        analyse.echantillonNom,
      );
      if (mounted) setState(() => _urgentSent.add(analyse.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La demande urgente n’a pas pu être envoyée.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _dateFilterActive => _dateDebut != null || _dateFin != null;

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtres = _filtres;

    return Scaffold(
      backgroundColor: kBg,

      // ── DRAWER ────────────────────────────────────────────────────────────────
      drawer: AppDrawer(currentPage: DegustateurDestination.laboratoire),

      // ── APPBAR ────────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Analyse de laboratoire',
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
                    ? 'Filtré par : $_dateTypeLabel'
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
            // ── UNIFIED HEADER ZONE ───────────────────────────────────────────────
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
                      hintText: 'Réf · technicien · ID analyse…',
                      hintStyle: const TextStyle(
                        color: Color(0xFF6B8E7A),
                        fontSize: 11,
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

                  // ── Filter chips ──────────────────────────────────────────
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
                          label: 'Pas encore reçu',
                          activeColor: const Color(0xFF616161),
                          inactiveColor: const Color(0xFFF0F0F0),
                          inactiveTextColor: const Color(0xFF616161),
                          selected: _filtreStatutLabel == 'Pas encore reçu',
                          onTap: () => setState(
                            () => _filtreStatutLabel = 'Pas encore reçu',
                          ),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Analyse en attente',
                          activeColor: const Color(0xFFD07B2F),
                          inactiveColor: const Color(0xFFFEF3E8),
                          inactiveTextColor: const Color(0xFFD07B2F),
                          selected: _filtreStatutLabel == 'Analyse en attente',
                          onTap: () => setState(
                            () => _filtreStatutLabel = 'Analyse en attente',
                          ),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Analyse soumise',
                          activeColor: const Color(0xFF38835A),
                          inactiveColor: const Color(0xFFE6F4ED),
                          inactiveTextColor: const Color(0xFF38835A),
                          selected: _filtreStatutLabel == 'Analyse soumise',
                          onTap: () => setState(
                            () => _filtreStatutLabel = 'Analyse soumise',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Thin separator
            Container(height: 1, color: Colors.black.withValues(alpha: 0.06)),

            // ── LIST ──────────────────────────────────────────────────────────────
            Expanded(
              child: filtres.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.biotech_outlined,
                                  size: 52,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune analyse trouvée',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        itemCount: filtres.length,
                        itemBuilder: (context, index) {
                          final a = filtres[index];
                          return AnalyseCard(
                            analyse: a,
                            isUrgentLabo: _urgentSent.contains(a.id),
                            onUrgentLabo: () => _confirmSendUrgent(a),
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
