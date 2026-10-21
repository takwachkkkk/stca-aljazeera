import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/services/resultat_service.dart';
import '../../../core/utils/rafraichissement_periodique.dart';
import '../../../core/widgets/bandeau_demonstration.dart';
import '../models/dashboard_chef_degustateur.dart';
import '../services/dashboard_chef_degustateur_service.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../../evaluation_echantillons/evaluation_echantillons_page.dart';
import 'home_activite_section.dart';
import 'home_alignement_section.dart';
import '../../../core/services/repartition_regions_service.dart';
import '../../../core/widgets/repartition_regions_card.dart';
import 'home_panel_coi_section.dart';
import 'home_classifications_section.dart';
import 'home_delai_section.dart';
import 'home_pipeline_section.dart';
import 'home_presence_section.dart';
import 'home_sessions_section.dart';
import 'home_urgentes_section.dart';
import 'home_shared.dart';
import '../../../core/utils/date_utils.dart';
import '../../widgets/chef_colors.dart';

const Color _green = chefGreen;
const Color _dark = chefDark;
const Color _white = chefWhite;
const Color _headerBg = chefHeaderBg;
const Color _amber = chefAmber;
const Color _blue = chefBlue;
const Color _red = chefRed;
const Color _purple = chefPurple;
const Color _olive = chefOlive;

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtN(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

class HomeBody extends StatefulWidget {
  final VoidCallback onSimulerNotification;
  final Future<void> Function()? onRefreshParent;

  const HomeBody({
    super.key,
    required this.onSimulerNotification,
    this.onRefreshParent,
  });

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> with RafraichissementPeriodique {
  final _service = DashboardChefDegustateurService();

  // ── State ─────────────────────────────────────────────────────────────────
  PipelineChefData? _pipeline;
  List<EvaluationUrgenteChef> _urgentes = [];
  List<EvaluationUrgenteCeoChef> _urgentesCeo = [];
  final Set<String> _ignoredUrgentes = {};
  final Set<String> _ignoredUrgentesCeo = {};

  List<SessionEnAttente> _sessions = [];
  PresenceChefData? _presence;
  DelaiPanelData? _delai;
  AlignementPanelData? _alignement;
  List<ClassificationPoint> _classifications = [];
  List<ActiviteItemChef> _activite = [];
  int _activiteTotal = 0;
  bool _activiteLoading = false;
  final Set<String> _sectionsDemonstration = {};
  Object? _erreurChargement;

  DateTime? _presDateDebut;
  DateTime? _presDateFin;
  DateTime? _delaiDateDebut;
  DateTime? _delaiDateFin;
  DateTime? _alignDateDebut;
  DateTime? _alignDateFin;
  DateTime? _classDateDebut;
  DateTime? _classDateFin;
  DateTime? _actDateDebut;
  DateTime? _actDateFin;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final pipeline = await _service.fetchPipeline();
      final urgentes = await _service.fetchUrgentes();
      final urgentesCeo = await _service.fetchUrgentesCeo();
      final sessions = await _service.fetchSessionsEnAttente();
      final presence = await _service.fetchPresence(
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
      );
      final alignement = await _service.fetchAlignement(
        dateDebut: _alignDateDebut,
        dateFin: _alignDateFin,
      );
      final classifications = await _service.fetchClassifications(
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
      );
      final activite = await _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('pipeline', pipeline);
        _memoriserOrigine('urgentes', urgentes);
        _memoriserOrigine('urgentes_ceo', urgentesCeo);
        _memoriserOrigine('sessions', sessions);
        _memoriserOrigine('presence', presence);
        _memoriserOrigine('alignement', alignement);
        _memoriserOrigine('classifications', classifications);
        _memoriserOrigine('activite', activite);
        _pipeline = pipeline.donnees;
        _urgentes = urgentes.donnees;
        _urgentesCeo = urgentesCeo.donnees;
        _sessions = sessions.donnees;
        _presence = presence.donnees;
        _alignement = alignement.donnees;
        _classifications = classifications.donnees;
        _activite = activite.donnees.items;
        _activiteTotal = activite.donnees.total;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  final _regionsService = RepartitionRegionsService(
    '/api/chef/dashboard/regions/',
  );
  final _regionsKey = GlobalKey<RepartitionRegionsCardState>();
  final _panelCoiKey = GlobalKey<PanelCoiSectionState>();

  Future<void> _rafraichirTout() async {
    await widget.onRefreshParent?.call();
    await _loadAll();
    await _regionsKey.currentState?.recharger();
    await _panelCoiKey.currentState?.recharger();
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final pipeline = await _service.fetchPipeline();
      final urgentes = await _service.fetchUrgentes();
      final urgentesCeo = await _service.fetchUrgentesCeo();
      final sessions = await _service.fetchSessionsEnAttente();
      final presence = await _service.fetchPresence(
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
      );
      final alignement = await _service.fetchAlignement(
        dateDebut: _alignDateDebut,
        dateFin: _alignDateFin,
      );
      final classifications = await _service.fetchClassifications(
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
      );
      final activite = await _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: 0,
      );
      if (!mounted ||
          !_peutAppliquer('pipeline', pipeline) ||
          !_peutAppliquer('urgentes', urgentes) ||
          !_peutAppliquer('urgentes_ceo', urgentesCeo) ||
          !_peutAppliquer('sessions', sessions) ||
          !_peutAppliquer('presence', presence) ||
          !_peutAppliquer('alignement', alignement) ||
          !_peutAppliquer('classifications', classifications) ||
          !_peutAppliquer('activite', activite)) {
        return;
      }
      setState(() {
        _memoriserOrigine('pipeline', pipeline);
        _memoriserOrigine('urgentes', urgentes);
        _memoriserOrigine('urgentes_ceo', urgentesCeo);
        _memoriserOrigine('sessions', sessions);
        _memoriserOrigine('presence', presence);
        _memoriserOrigine('alignement', alignement);
        _memoriserOrigine('classifications', classifications);
        _memoriserOrigine('activite', activite);
        _pipeline = pipeline.donnees;
        _urgentes = urgentes.donnees;
        _urgentesCeo = urgentesCeo.donnees;
        _sessions = sessions.donnees;
        _presence = presence.donnees;
        _alignement = alignement.donnees;
        _classifications = classifications.donnees;
        _activite = activite.donnees.items;
        _activiteTotal = activite.donnees.total;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  bool _peutAppliquer<T>(String section, Resultat<T> resultat) =>
      !resultat.estDemonstration || _sectionsDemonstration.contains(section);

  Future<void> _reloadPresence() async {
    await _recharger(
      'presence',
      _service.fetchPresence(dateDebut: _presDateDebut, dateFin: _presDateFin),
      (data) => _presence = data,
    );
  }

  Future<void> _reloadDelai() async {
    await _recharger(
      'delai',
      _service.fetchDelai(dateDebut: _delaiDateDebut, dateFin: _delaiDateFin),
      (data) => _delai = data,
    );
  }

  Future<void> _reloadAlignement() async {
    await _recharger(
      'alignement',
      _service.fetchAlignement(
        dateDebut: _alignDateDebut,
        dateFin: _alignDateFin,
      ),
      (data) => _alignement = data,
    );
  }

  Future<void> _reloadClassifications() async {
    await _recharger(
      'classifications',
      _service.fetchClassifications(
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
      ),
      (data) => _classifications = data,
    );
  }

  Future<void> _reloadActivite() async {
    await _recharger(
      'activite',
      _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: 0,
      ),
      (data) {
        _activite = data.items;
        _activiteTotal = data.total;
      },
    );
  }

  Future<void> _loadMoreActivite() async {
    if (_activiteLoading || _activite.length >= _activiteTotal) return;
    setState(() => _activiteLoading = true);
    try {
      final resultat = await _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: _activite.length,
      );
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('activite', resultat);
        _activite.addAll(resultat.donnees.items);
        _activiteTotal = resultat.donnees.total;
        _activiteLoading = false;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) {
        setState(() {
          _activiteLoading = false;
          _erreurChargement = erreur;
        });
      }
    }
  }

  Future<void> _recharger<T>(
    String section,
    Future<Resultat<T>> chargement,
    void Function(T donnees) appliquer,
  ) async {
    try {
      final resultat = await chargement;
      if (!mounted) return;
      setState(() {
        _memoriserOrigine(section, resultat);
        appliquer(resultat.donnees);
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  void _memoriserOrigine<T>(String section, Resultat<T> resultat) {
    if (resultat.estDemonstration) {
      _sectionsDemonstration.add(section);
    } else {
      _sectionsDemonstration.remove(section);
    }
  }

  Future<void> _openDateSheet({
    required DateTime? dateDebut,
    required DateTime? dateFin,
    required void Function(DateTime debut, DateTime? fin) onApply,
    required VoidCallback onClear,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        dateDebut: dateDebut,
        dateFin: dateFin,
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }

  Widget _fixedCard({
    required double height,
    required Widget header,
    required Widget body,
    Widget? footer,
  }) => Container(
    height: height,
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(
      children: [
        header,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: body,
          ),
        ),
        if (footer != null) footer,
      ],
    ),
  );

  Widget _sectionBar({
    required String title,
    required IconData icon,
    DateTime? dateDebut,
    DateTime? dateFin,
    VoidCallback? onDateTap,
  }) {
    final active = dateDebut != null;
    final chipLabel = active
        ? '${dateDebut!.day.toString().padLeft(2, '0')}/${dateDebut.month.toString().padLeft(2, '0')}/${dateDebut.year}'
        : 'Période';
    return Container(
      color: _headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Icon(icon, size: 13, color: _dark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.domine(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
          ),
          if (onDateTap != null)
            GestureDetector(
              onTap: onDateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? _green.withValues(alpha: 0.08)
                      : const Color(0xFFF0F2F1),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: active
                        ? _green.withValues(alpha: 0.25)
                        : const Color(0xFFE8EAE8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 10,
                      color: active ? _green : _dark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active ? _green : _dark,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 12,
                      color: active ? _green : _dark,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollableRows<T>({
    required List<T> items,
    required double Function(T) getValue,
    required double Function(T) getMax,
    required Color Function(T) getColor,
    required String Function(T) getLabel,
    required String Function(T) getName,
  }) {
    return SingleChildScrollView(
      child: Column(
        children: items.map((item) {
          final value = getValue(item);
          final max = getMax(item);
          final color = getColor(item);
          final label = getLabel(item);
          final name = getName(item);
          final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777777),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _IgnoreButton({required VoidCallback onConfirm}) => GestureDetector(
    onTap: onConfirm,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(
        Icons.visibility_off_outlined,
        size: 16,
        color: Colors.grey.shade400,
      ),
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return VueResultatService(
      estDemonstration: _sectionsDemonstration.isNotEmpty,
      erreur: _erreurChargement,
      onReessayer: _loadAll,
      onRefresh: _rafraichirTout,
      couleurRafraichissement: chefGreen,
      child: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 52),
            children: [
              PipelineSection(pipeline: _pipeline),
              const SizedBox(height: 12),
              UrgentesSection(
                urgentes: _urgentes,
                urgentesCeo: _urgentesCeo,
                ignoredUrgentes: _ignoredUrgentes,
                ignoredUrgentesCeo: _ignoredUrgentesCeo,
                onIgnoreUrgente: (id) =>
                    setState(() => _ignoredUrgentes.add(id)),
                onIgnoreUrgenteCeo: (id) =>
                    setState(() => _ignoredUrgentesCeo.add(id)),
              ),
              const SizedBox(height: 12),
              if (_sessions.isNotEmpty) ...[
                SessionsSection(sessions: _sessions),
                const SizedBox(height: 12),
              ],
              PresenceSection(
                presence: _presence,
                dateDebut: _presDateDebut,
                dateFin: _presDateFin,
                onDateTap: () => _openDateSheet(
                  dateDebut: _presDateDebut,
                  dateFin: _presDateFin,
                  onApply: (d, f) {
                    setState(() {
                      _presDateDebut = d;
                      _presDateFin = f;
                    });
                    _reloadPresence();
                  },
                  onClear: () {
                    setState(() {
                      _presDateDebut = null;
                      _presDateFin = null;
                    });
                    _reloadPresence();
                  },
                ),
              ),
              const SizedBox(height: 12),
              AlignementSection(
                alignement: _alignement,
                dateDebut: _alignDateDebut,
                dateFin: _alignDateFin,
                onDateTap: () => _openDateSheet(
                  dateDebut: _alignDateDebut,
                  dateFin: _alignDateFin,
                  onApply: (debut, fin) {
                    setState(() {
                      _alignDateDebut = debut;
                      _alignDateFin = fin;
                    });
                    _reloadAlignement();
                  },
                  onClear: () {
                    setState(() {
                      _alignDateDebut = null;
                      _alignDateFin = null;
                    });
                    _reloadAlignement();
                  },
                ),
              ),
              const SizedBox(height: 12),
              ClassificationsSection(
                classifications: _classifications,
                dateDebut: _classDateDebut,
                dateFin: _classDateFin,
                onDateTap: () => _openDateSheet(
                  dateDebut: _classDateDebut,
                  dateFin: _classDateFin,
                  onApply: (d, f) {
                    setState(() {
                      _classDateDebut = d;
                      _classDateFin = f;
                    });
                    _reloadClassifications();
                  },
                  onClear: () {
                    setState(() {
                      _classDateDebut = null;
                      _classDateFin = null;
                    });
                    _reloadClassifications();
                  },
                ),
              ),
              const SizedBox(height: 12),
              PanelCoiSection(key: _panelCoiKey),
              const SizedBox(height: 12),
              RepartitionRegionsCard(
                key: _regionsKey,
                service: _regionsService,
              ),
              const SizedBox(height: 12),
              ActiviteSection(
                activite: _activite,
                activiteTotal: _activiteTotal,
                activiteLoading: _activiteLoading,
                dateDebut: _actDateDebut,
                dateFin: _actDateFin,
                onDateTap: () => _openDateSheet(
                  dateDebut: _actDateDebut,
                  dateFin: _actDateFin,
                  onApply: (d, f) {
                    setState(() {
                      _actDateDebut = d;
                      _actDateFin = f;
                    });
                    _reloadActivite();
                  },
                  onClear: () {
                    setState(() {
                      _actDateDebut = null;
                      _actDateFin = null;
                    });
                    _reloadActivite();
                  },
                ),
                onLoadMore: _loadMoreActivite,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1. PIPELINE ───────────────────────────────────────────────────────────
  Widget _buildPipeline() {
    final p = _pipeline;
    return _fixedCard(
      height: 180, // was 142
      header: _sectionBar(
        title: 'Pipeline des échantillons',
        icon: Icons.timeline_outlined,
      ),
      body: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pipeCell(
              _fmtN(p?.receptionne ?? 0),
              p?.receptionne ?? 0,
              'Réceptionné',
              _blue,
            ),
            _pipeArrow(),
            _pipeCell(
              _fmtN(p?.enAttenteEval ?? 0),
              p?.enAttenteEval ?? 0,
              'Non évaluée',
              _amber,
            ),
            _pipeArrow(),
            _pipeCell(
              _fmtN(p?.enCours ?? 0),
              p?.enCours ?? 0,
              'En cours',
              _purple,
            ),
            _pipeArrow(),
            _pipeCell(_fmtN(p?.soumis ?? 0), p?.soumis ?? 0, 'Soumise', _green),
          ],
        ),
      ),
    );
  }

  Widget _pipeCell(String label, int exact, String subtitle, Color color) =>
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              '$exact',
              style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
            ),
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      );

  Widget _pipeArrow() => const Padding(
    padding: EdgeInsets.only(bottom: 24),
    child: Text('›', style: TextStyle(fontSize: 14, color: Color(0xFFEEEEEE))),
  );

  // ── 2. URGENTES ───────────────────────────────────────────────────────────
  Widget _buildUrgentes() {
    final visibleCeo = _urgentesCeo
        .where((e) => !_ignoredUrgentesCeo.contains(e.id))
        .toList();
    final visible1j = _urgentes
        .where((e) => !_ignoredUrgentes.contains(e.id) && e.joursEnAttente == 1)
        .toList();
    final visible2j = _urgentes
        .where((e) => !_ignoredUrgentes.contains(e.id) && e.joursEnAttente >= 2)
        .toList();
    final total = visibleCeo.length + visible1j.length + visible2j.length;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 430, // was 350
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // header
          Container(
            color: const Color(0xFFFDF4F3),
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Évaluations urgentes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _red,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // scrollable body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (visibleCeo.isNotEmpty) ...[
                    _subsectionHeader(
                      'Demandes urgentes — Direction',
                      _purple,
                      visibleCeo.length,
                    ),
                    ...visibleCeo.map((u) => _urgenteCeoRow(u)),
                  ],
                  if (visible1j.isNotEmpty) ...[
                    if (visibleCeo.isNotEmpty) _subsectionDivider(),
                    _subsectionHeader(
                      'En attente depuis 1 jour',
                      _amber,
                      visible1j.length,
                    ),
                    ...visible1j.map((u) => _urgenteRow(u)),
                  ],
                  if (visible2j.isNotEmpty) ...[
                    if (visibleCeo.isNotEmpty || visible1j.isNotEmpty)
                      _subsectionDivider(),
                    _subsectionHeader(
                      'Critique — 2j et plus',
                      _red,
                      visible2j.length,
                    ),
                    ...visible2j.map((u) => _urgenteRow(u)),
                  ],
                ],
              ),
            ),
          ),
          // footer
          Container(
            color: const Color(0xFFF8F8F8),
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            child: const SizedBox(
              width: double.infinity,
              child: Text(
                "Appuyez sur la ligne pour évaluer · Icône œil pour ignorer",
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFAAAAAA),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subsectionHeader(String label, Color color, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _subsectionDivider() => Container(
    height: 1,
    color: const Color(0xFFF0F0F0),
    margin: const EdgeInsets.symmetric(horizontal: 14),
  );

  // ── CEO row — NO badge, NO "Priorité direction" tag ──────────────────────
  Widget _urgenteCeoRow(EvaluationUrgenteCeoChef u) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EvaluationEchantillonsPage()),
    ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      color: _purple.withValues(alpha: 0.025),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference only — no CEO badge next to it
                Text(
                  u.reference,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${u.collecteurNom}  ·  ${u.fournisseurNom}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          // NO "Priorité direction" container here
          _IgnoreButton(
            onConfirm: () => setState(() => _ignoredUrgentesCeo.add(u.id)),
          ),
        ],
      ),
    ),
  );

  // ── Time-based urgent row — unchanged ────────────────────────────────────
  Widget _urgenteRow(EvaluationUrgenteChef u) {
    final isCritique = u.joursEnAttente >= 2;
    final color = isCritique ? _red : _amber;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EvaluationEchantillonsPage()),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFFAFAFA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.reference,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${u.collecteurNom}  ·  ${u.fournisseurNom}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Text(
                isCritique
                    ? '${u.joursEnAttente}j — critique'
                    : '${u.joursEnAttente}j en attente',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _IgnoreButton(
              onConfirm: () => setState(() => _ignoredUrgentes.add(u.id)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. SESSIONS EN ATTENTE ────────────────────────────────────────────────
  Widget _buildSessions() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            color: _headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Icon(Icons.pending_actions_outlined, size: 13, color: _purple),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    "Sessions en attente d'approbation",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_sessions.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: _sessions
                  .map(
                    (s) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _purple.withValues(alpha: 0.20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _purple,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.titre,
                                      style: GoogleFonts.domine(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _dark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${DegDateUtils.formaterAffichage(s.date)} · ${s.heure.isEmpty ? "Heure non précisée" : s.heure} · ${s.lieu.isEmpty ? "Lieu non précisé" : s.lieu}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    Text(
                                      'Proposée par ${s.proposePar}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _purple.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.red.shade400,
                                  ),
                                  label: Text(
                                    'Refuser',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Approuver',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. PRESENCE ───────────────────────────────────────────────────────────
  Widget _buildPresence() {
    final p = _presence;
    return _fixedCard(
      height: 285,
      header: _sectionBar(
        title: 'Présence aux séances',
        icon: Icons.people_outline_rounded,
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
        onDateTap: () => _openDateSheet(
          dateDebut: _presDateDebut,
          dateFin: _presDateFin,
          onApply: (d, f) {
            setState(() {
              _presDateDebut = d;
              _presDateFin = f;
            });
            _reloadPresence();
          },
          onClear: () {
            setState(() {
              _presDateDebut = null;
              _presDateFin = null;
            });
            _reloadPresence();
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Fat custom donut ──
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _DonutPainter(value: p?.taux ?? 0),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${((p?.taux ?? 0) * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _green,
                          ),
                        ),
                        const Text(
                          'présence',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _attStat(
                      _green,
                      'Séances présent',
                      '${p?.present ?? 0}',
                      _green,
                    ),
                    const SizedBox(height: 7),
                    _attStat(
                      _red,
                      'Séances manquées',
                      '${p?.manquee ?? 0}',
                      _red,
                    ),
                    const SizedBox(height: 7),
                    _attStat(
                      const Color(0xFFE5E7E5),
                      'Total',
                      '${p?.total ?? 0}',
                      _dark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p?.prochaineDate != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: _green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prochaine séance : ${p!.prochaineDate}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        if (p.prochaineLieu != null)
                          Text(
                            p.prochaineLieu!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (p.prochaineCountdown != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        p.prochaineCountdown!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attStat(Color dot, String label, String value, Color valueColor) =>
      Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF777777)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      );

  // ── 5. DELAI ─────────────────────────────────────────────────────────────
  Widget _buildDelai() {
    return _fixedCard(
      height: 295, // was 230
      header: _sectionBar(
        title: 'Délai de soumission — panel',
        icon: Icons.timer_outlined,
        dateDebut: _delaiDateDebut,
        dateFin: _delaiDateFin,
        onDateTap: () => _openDateSheet(
          dateDebut: _delaiDateDebut,
          dateFin: _delaiDateFin,
          onApply: (debut, fin) {
            setState(() {
              _delaiDateDebut = debut;
              _delaiDateFin = fin;
            });
            _reloadDelai();
          },
          onClear: () {
            setState(() {
              _delaiDateDebut = null;
              _delaiDateFin = null;
            });
            _reloadDelai();
          },
        ),
      ),
      body: Column(
        children: [
          if (_delai != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  _delaiStat(
                    'MOY. PANEL',
                    '${_delai!.panelMoyen.toStringAsFixed(1)}j',
                    _green,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  _delaiStat('MEMBRES', '${_delai!.membres.length}', _dark),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140, // was 110
            child: _delai == null
                ? const Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  )
                : _buildScrollableRows(
                    items: _delai!.membres,
                    getValue: (m) => m.delaiMoyen,
                    getMax: (m) => _delai!.membres.first.delaiMoyen,
                    getColor: (m) {
                      if (m.delaiMoyen > _delai!.panelMoyen * 1.5) return _red;
                      if (m.delaiMoyen > _delai!.panelMoyen * 1.1)
                        return _amber;
                      return _green;
                    },
                    getLabel: (m) => '${m.delaiMoyen.toStringAsFixed(1)}j',
                    getName: (m) => m.nom,
                  ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '↕ défiler pour voir tous',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _delaiStat(String label, String value, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFAAAAAA),
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );

  // ── 6. ALIGNEMENT ────────────────────────────────────────────────────────
  Widget _buildAlignement() {
    return _fixedCard(
      height: 295, // was 230
      header: _sectionBar(
        title: 'Alignement avec le panel',
        icon: Icons.check_box_outlined,
        dateDebut: _alignDateDebut,
        dateFin: _alignDateFin,
        onDateTap: () => _openDateSheet(
          dateDebut: _alignDateDebut,
          dateFin: _alignDateFin,
          onApply: (debut, fin) {
            setState(() {
              _alignDateDebut = debut;
              _alignDateFin = fin;
            });
            _reloadAlignement();
          },
          onClear: () {
            setState(() {
              _alignDateDebut = null;
              _alignDateFin = null;
            });
            _reloadAlignement();
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 140, // was 114
            child: _alignement == null
                ? const Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  )
                : _buildScrollableRows(
                    items: _alignement!.membres,
                    getValue: (m) => m.divergencePct,
                    getMax: (_) => 100.0,
                    getColor: (m) {
                      if (m.divergencePct >= 40) return _red;
                      if (m.divergencePct >= 20) return _amber;
                      return _green;
                    },
                    getLabel: (m) => '${m.divergencePct.toStringAsFixed(0)}%',
                    getName: (m) => m.nom,
                  ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '↕ défiler pour voir tous',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withValues(alpha: 0.12)),
            ),
            child: const Text(
              'Plus le % est élevé, plus le dégustateur classe différemment du reste du panel.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B8E7A)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. CLASSIFICATIONS ───────────────────────────────────────────────────
  Widget _buildClassifications() {
    return _fixedCard(
      height: 325, // was 260
      header: _sectionBar(
        title: 'Classifications du panel',
        icon: Icons.bar_chart_outlined,
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
        onDateTap: () => _openDateSheet(
          dateDebut: _classDateDebut,
          dateFin: _classDateFin,
          onApply: (d, f) {
            setState(() {
              _classDateDebut = d;
              _classDateFin = f;
            });
            _reloadClassifications();
          },
          onClear: () {
            setState(() {
              _classDateDebut = null;
              _classDateFin = null;
            });
            _reloadClassifications();
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 180, // was 150
            child: _classifications.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          _classifications
                              .map(
                                (p) => (p.extraVierge + p.vierge + p.lampante)
                                    .toDouble(),
                              )
                              .fold(0.0, (a, b) => a > b ? a : b) +
                          1,
                      barGroups: List.generate(_classifications.length, (i) {
                        final p = _classifications[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: p.extraVierge.toDouble(),
                              color: _green,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            BarChartRodData(
                              toY: p.vierge.toDouble(),
                              color: _olive,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            BarChartRodData(
                              toY: p.lampante.toDouble(),
                              color: _amber,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= _classifications.length)
                                return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _classifications[i].label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) => v % 1 == 0
                                ? Text(
                                    v.toInt().toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFCCCCCC),
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0x0D000000),
                          strokeWidth: 1,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(_green, 'Extra Vierge'),
              const SizedBox(width: 12),
              _legendDot(_olive, 'Vierge'),
              const SizedBox(width: 12),
              _legendDot(_amber, 'Lampante'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _dark,
        ),
      ),
    ],
  );

  // ── 8. ACTIVITE ──────────────────────────────────────────────────────────
  Widget _buildActivite() {
    return Container(
      height: 345, // was 260
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _sectionBar(
            title: 'Activité récente',
            icon: Icons.access_time_outlined,
            dateDebut: _actDateDebut,
            dateFin: _actDateFin,
            onDateTap: () => _openDateSheet(
              dateDebut: _actDateDebut,
              dateFin: _actDateFin,
              onApply: (d, f) {
                setState(() {
                  _actDateDebut = d;
                  _actDateFin = f;
                });
                _reloadActivite();
              },
              onClear: () {
                setState(() {
                  _actDateDebut = null;
                  _actDateFin = null;
                });
                _reloadActivite();
              },
            ),
          ),
          if (_actDateDebut != null)
            Container(
              color: _headerBg,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.06),
                  border: Border.all(color: _green.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, size: 11, color: _green),
                    const SizedBox(width: 6),
                    Text(
                      _actDateFin != null
                          ? '${_fmtDate(_actDateDebut!)} → ${_fmtDate(_actDateFin!)}'
                          : _fmtDate(_actDateDebut!),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    n.metrics.pixels >= n.metrics.maxScrollExtent - 40)
                  _loadMoreActivite();
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                itemCount: _activite.length,
                itemBuilder: (_, i) => _timelineItem(
                  _activite[i],
                  isLast: i == _activite.length - 1,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _activite.length >= _activiteTotal
                      ? '$_activiteTotal sur $_activiteTotal — tout chargé'
                      : '1–${_activite.length} sur $_activiteTotal',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
                if (_activiteLoading) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _green,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(ActiviteItemChef item, {required bool isLast}) {
    final Color dot;
    switch (item.type) {
      case 'seance_presente':
        dot = _blue;
        break;
      case 'seance_manquee':
        dot = _red;
        break;
      case 'approbation':
        dot = _green;
        break;
      case 'refus':
        dot = _red;
        break;
      default:
        dot = _amber;
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: const Color(0xFFE5E7E5)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.action,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.horodatage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBBBBBB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double value;
  const _DonutPainter({required this.value});
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = const Color(0xFFE8EAE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final fg = Paint()
      ..color = chefGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 5,
    );
    canvas.drawArc(rect, -1.5708, 6.2832, false, bg);
    canvas.drawArc(rect, -1.5708, 6.2832 * value.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.value != value;
}
