import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/services/resultat_service.dart';
import '../../../core/utils/rafraichissement_periodique.dart';
import '../../../core/widgets/bandeau_demonstration.dart';
import '../models/dashboard_degustateur.dart';
import '../services/dashboard_degustateur_service.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../../evaluation_echantillons/evaluation_echantillons_page.dart';
import 'home_activite_section.dart';
import 'home_classifications_section.dart';
import 'home_delai_section.dart';
import 'home_presence_section.dart';
import 'home_pipeline_section.dart';
import 'home_urgentes_section.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _white = Color(0xFFFFFFFF);
const Color _headerBg = Color.fromARGB(255, 220, 233, 226);
const Color _amber = Color(0xFFD07B2F);
const Color _blue = Color(0xFF3A6EA5);
const Color _red = Color(0xFFC0392B);
const Color _purple = Color(0xFF7B3FC4);
const Color _olive = Color(0xFF6B8143);

const List<String> _moisAbr = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class HomeBody extends StatefulWidget {
  final Future<void> Function()? onRefreshParent;

  const HomeBody({super.key, this.onRefreshParent});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> with RafraichissementPeriodique {
  final _service = DashboardDegustateurService();

  List<EvaluationUrgente> _urgentes = [];
  final Set<String> _ignoredUrgentes = {};

  PipelineData? _pipeline;
  List<ClassificationPoint> _classifications = [];
  PresenceData? _presence;
  DelaiSummary? _delai;
  List<ActiviteItem> _activite = [];
  int _activiteTotal = 0;
  bool _activiteLoading = false;
  final Set<String> _sectionsDemonstration = {};
  Object? _erreurChargement;

  DateTime? _classDateDebut;
  DateTime? _classDateFin;
  DateTime? _presDateDebut;
  DateTime? _presDateFin;
  DateTime _delaiDateDebut = DateTime(DateTime.now().year, 1, 1);
  DateTime _delaiDateFin = DateTime.now();
  DateTime? _actDateDebut;
  DateTime? _actDateFin;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final fUrgentes = _service.fetchUrgentes();
      final fPipeline = _service.fetchPipeline();
      final fCls = _service.fetchClassifications(
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
      );
      final fPresence = _service.fetchPresence(
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
      );
      final fAct = _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: 0,
      );
      final results = await Future.wait([
        fUrgentes,
        fPipeline,
        fCls,
        fPresence,
      ]);
      final activite = await fAct;
      final urgentes = results[0] as Resultat<List<EvaluationUrgente>>;
      final pipeline = results[1] as Resultat<PipelineData>;
      final classifications = results[2] as Resultat<List<ClassificationPoint>>;
      final presence = results[3] as Resultat<PresenceData>;
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('urgentes', urgentes);
        _memoriserOrigine('pipeline', pipeline);
        _memoriserOrigine('classifications', classifications);
        _memoriserOrigine('presence', presence);
        _memoriserOrigine('activite', activite);
        _urgentes = urgentes.donnees;
        _pipeline = pipeline.donnees;
        _classifications = classifications.donnees;
        _presence = presence.donnees;
        _activite = activite.donnees.items;
        _activiteTotal = activite.donnees.total;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  Future<void> _rafraichirTout() async {
    await widget.onRefreshParent?.call();
    await _loadAll();
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final fUrgentes = _service.fetchUrgentes();
      final fPipeline = _service.fetchPipeline();
      final fCls = _service.fetchClassifications(
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
      );
      final fPresence = _service.fetchPresence(
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
      );
      final fAct = _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: 0,
      );
      final results = await Future.wait([
        fUrgentes,
        fPipeline,
        fCls,
        fPresence,
      ]);
      final activite = await fAct;
      final urgentes = results[0] as Resultat<List<EvaluationUrgente>>;
      final pipeline = results[1] as Resultat<PipelineData>;
      final classifications = results[2] as Resultat<List<ClassificationPoint>>;
      final presence = results[3] as Resultat<PresenceData>;
      if (!mounted ||
          !_peutAppliquer('urgentes', urgentes) ||
          !_peutAppliquer('pipeline', pipeline) ||
          !_peutAppliquer('classifications', classifications) ||
          !_peutAppliquer('presence', presence) ||
          !_peutAppliquer('activite', activite)) {
        return;
      }
      setState(() {
        _memoriserOrigine('urgentes', urgentes);
        _memoriserOrigine('pipeline', pipeline);
        _memoriserOrigine('classifications', classifications);
        _memoriserOrigine('presence', presence);
        _memoriserOrigine('activite', activite);
        _urgentes = urgentes.donnees;
        _pipeline = pipeline.donnees;
        _classifications = classifications.donnees;
        _presence = presence.donnees;
        _activite = activite.donnees.items;
        _activiteTotal = activite.donnees.total;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  bool _peutAppliquer<T>(String section, Resultat<T> resultat) =>
      !resultat.estDemonstration || _sectionsDemonstration.contains(section);

  Future<void> _reloadClassifications() async {
    try {
      final resultat = await _service.fetchClassifications(
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
      );
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('classifications', resultat);
        _classifications = resultat.donnees;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  Future<void> _reloadPresence() async {
    try {
      final resultat = await _service.fetchPresence(
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
      );
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('presence', resultat);
        _presence = resultat.donnees;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  Future<void> _reloadDelai() async {
    try {
      final resultat = await _service.fetchDelai(
        dateDebut: _delaiDateDebut,
        dateFin: _delaiDateFin,
      );
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('delai', resultat);
        _delai = resultat.donnees;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  Future<void> _reloadActivite() async {
    try {
      final resultat = await _service.fetchActivite(
        dateDebut: _actDateDebut,
        dateFin: _actDateFin,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _memoriserOrigine('activite', resultat);
        _activite = resultat.donnees.items;
        _activiteTotal = resultat.donnees.total;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
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

  void _memoriserOrigine<T>(String section, Resultat<T> resultat) {
    if (resultat.estDemonstration) {
      _sectionsDemonstration.add(section);
    } else {
      _sectionsDemonstration.remove(section);
    }
  }

  Future<void> _openDateSheet({
    required String titre,
    required DateTime? dateDebut,
    required DateTime? dateFin,
    required bool periodOnly,
    required void Function(DateTime debut, DateTime? fin) onApply,
    required VoidCallback onClear,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        titre: titre,
        dateDebut: dateDebut,
        dateFin: periodOnly ? dateFin : null,
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }

  void _openPresenceDateSheet() => _openDateSheet(
    titre: 'Filtrer les séances',
    dateDebut: _presDateDebut,
    dateFin: _presDateFin,
    periodOnly: false,
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
  );

  String _chipLabel({required DateTime? debut, required DateTime? fin}) {
    if (debut == null) return '';
    if (fin == null ||
        (debut.year == fin.year &&
            debut.month == fin.month &&
            debut.day == fin.day)) {
      return _fmtDate(debut);
    }
    return '${debut.day} ${_moisAbr[debut.month - 1]} → ${fin.day} ${_moisAbr[fin.month - 1]}';
  }

  void _openClassDateSheet() => _openDateSheet(
    titre: 'Filtrer les classifications',
    dateDebut: _classDateDebut,
    dateFin: _classDateFin,
    periodOnly: false,
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
  );

  void _openDelaiDateSheet() => _openDateSheet(
    titre: 'Délai de soumission — période',
    dateDebut: _delaiDateDebut,
    dateFin: _delaiDateFin,
    periodOnly: true,
    onApply: (debut, fin) {
      setState(() {
        _delaiDateDebut = debut;
        _delaiDateFin = fin ?? debut;
      });
      _reloadDelai();
    },
    onClear: () {
      setState(() {
        _delaiDateDebut = DateTime(DateTime.now().year, 1, 1);
        _delaiDateFin = DateTime.now();
      });
      _reloadDelai();
    },
  );

  void _openActDateSheet() => _openDateSheet(
    titre: "Filtrer l'activité",
    dateDebut: _actDateDebut,
    dateFin: _actDateFin,
    periodOnly: false,
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
  );

  Widget _sectionBar({
    required String title,
    required IconData icon,
    DateTime? dateDebut,
    DateTime? dateFin,
    VoidCallback? onDateTap,
  }) {
    final active = dateDebut != null;
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
              style: const TextStyle(
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
                      active
                          ? _chipLabel(debut: dateDebut, fin: dateFin)
                          : 'Période',
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

  // ── Shared card shell ─────────────────────────────────────────────────────
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
        ?footer,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return VueResultatService(
      estDemonstration: _sectionsDemonstration.isNotEmpty,
      erreur: _erreurChargement,
      onReessayer: _loadAll,
      onRefresh: _rafraichirTout,
      couleurRafraichissement: _green,
      child: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 52),
            children: [
              HomePipelineSection(pipeline: _pipeline),
              const SizedBox(height: 12),
              HomeUrgentesSection(
                urgentes: _urgentes,
                ignoredUrgentes: _ignoredUrgentes,
                onIgnore: (id) => setState(() => _ignoredUrgentes.add(id)),
              ),
              const SizedBox(height: 12),
              HomePresenceSection(
                presence: _presence,
                dateDebut: _presDateDebut,
                dateFin: _presDateFin,
                onDateTap: _openPresenceDateSheet,
              ),
              const SizedBox(height: 12),
              HomeClassificationsSection(
                classifications: _classifications,
                dateDebut: _classDateDebut,
                dateFin: _classDateFin,
                onDateTap: _openClassDateSheet,
              ),
              const SizedBox(height: 12),
              _buildActivite(),
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
      height: 142,
      header: _sectionBar(
        title: 'Pipeline de mes évaluations',
        icon: Icons.timeline_outlined,
      ),
      body: _buildPipelineGrid(p),
    );
  }

  Widget _buildPipelineGrid(PipelineData? p) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pipeCell(p?.receptionne ?? 0, 'Réceptionné', _blue),
          _pipeArrow(),
          _pipeCell(p?.nonEvaluee ?? 0, 'Non évaluée', _amber),
          _pipeArrow(),
          _pipeCell(p?.enCours ?? 0, 'En cours', _purple),
          _pipeArrow(),
          _pipeCell(p?.soumise ?? 0, 'Soumise', _green),
        ],
      ),
    );
  }

  Widget _pipeCell(int n, String label, Color color) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$n',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
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
          label,
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
    final visible1j = _urgentes
        .where((e) => !_ignoredUrgentes.contains(e.id) && e.joursEnAttente == 1)
        .toList();
    final visible2j = _urgentes
        .where((e) => !_ignoredUrgentes.contains(e.id) && e.joursEnAttente >= 2)
        .toList();
    final total = visible1j.length + visible2j.length;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 390,
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
                  // ── 1-day ──
                  if (visible1j.isNotEmpty) ...[
                    _subsectionHeader(
                      'En attente depuis 1 jour',
                      _amber,
                      visible1j.length,
                    ),
                    ...visible1j.map((u) => _urgenteRow(u)),
                  ],
                  // ── 2+ days ──
                  if (visible2j.isNotEmpty) ...[
                    if (visible1j.isNotEmpty) _subsectionDivider(),
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

  // Row for time-based urgent evaluation
  Widget _urgenteRow(EvaluationUrgente u) {
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
            _ignoreButton(
              onConfirm: () => setState(() => _ignoredUrgentes.add(u.id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ignoreButton({required VoidCallback onConfirm}) => GestureDetector(
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

  // ── 3. PRESENCE ───────────────────────────────────────────────────────────
  Widget _buildPresence() {
    final p = _presence;
    // Height bumped to 290 to accommodate the larger 130×130 donut
    return _fixedCard(
      height: 285,
      header: _sectionBar(
        title: 'Présence aux séances',
        icon: Icons.people_outline_rounded,
        dateDebut: _presDateDebut,
        dateFin: _presDateFin,
        onDateTap: () => _openDateSheet(
          titre: 'Filtrer les séances',
          dateDebut: _presDateDebut,
          dateFin: _presDateFin,
          periodOnly: false,
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

  // ── 4. DELAI ─────────────────────────────────────────────────────────────
  Widget _buildDelai() {
    final d = _delai;
    final diff = d != null ? d.monDelaiMoyen - d.panelMoyen : 0.0;
    final isBetter = diff <= 0;
    return _fixedCard(
      height: 320,
      header: _sectionBar(
        title: 'Délai de soumission',
        icon: Icons.timer_outlined,
        dateDebut: _delaiDateDebut,
        dateFin: _delaiDateFin,
        onDateTap: () => _openDateSheet(
          titre: 'Délai de soumission — période',
          dateDebut: _delaiDateDebut,
          dateFin: _delaiDateFin,
          periodOnly: true,
          onApply: (debut, fin) {
            setState(() {
              _delaiDateDebut = debut;
              _delaiDateFin = fin ?? debut;
            });
            _reloadDelai();
          },
          onClear: () {
            setState(() {
              _delaiDateDebut = DateTime(DateTime.now().year, 1, 1);
              _delaiDateFin = DateTime.now();
            });
            _reloadDelai();
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _summaryItem(
                  label: 'MON DÉLAI MOY.',
                  value: d != null
                      ? '${d.monDelaiMoyen.toStringAsFixed(1)}j'
                      : '—',
                  valueColor: _amber,
                  sub: diff == 0.0
                      ? null
                      : (isBetter
                            ? '↑ −${diff.abs().toStringAsFixed(1)}j vs panel'
                            : '↓ +${diff.toStringAsFixed(1)}j vs panel'),
                  subColor: isBetter ? _green : _red,
                ),
                Container(
                  width: 2,
                  height: 42,
                  color: Colors.black.withValues(alpha: 0.07),
                ),
                _summaryItem(
                  label: 'MOY. PANEL',
                  value: d != null
                      ? '${d.panelMoyen.toStringAsFixed(1)}j'
                      : '—',
                  valueColor: _green,
                  sub: 'sur la période',
                ),
                Container(
                  width: 2,
                  height: 42,
                  color: Colors.black.withValues(alpha: 0.07),
                ),
                _summaryItem(
                  label: 'ÉVALS.',
                  value: '${d?.nbEvals ?? 0}',
                  valueColor: _dark,
                  sub: 'comptées',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: d == null || d.points.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 4,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0x0D000000),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) => v % 1 == 0
                                ? Text(
                                    '${v.toInt()}j',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFCCCCCC),
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 ||
                                  i >= d.points.length ||
                                  i % (d.points.length > 6 ? 2 : 1) != 0) {
                                return const SizedBox();
                              }
                              final dt = d.points[i].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${dt.day} ${_moisAbr[dt.month - 1]}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            d.points.length,
                            (i) => FlSpot(i.toDouble(), d.points[i].monDelai),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: _amber,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (p, x, bar, i) => FlDotCirclePainter(
                              radius: 3,
                              color: _amber,
                              strokeColor: _white,
                              strokeWidth: 1.5,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                _amber.withValues(alpha: 0.12),
                                _amber.withValues(alpha: 0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        LineChartBarData(
                          spots: List.generate(
                            d.points.length,
                            (i) => FlSpot(i.toDouble(), d.points[i].panelMoyen),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: const Color(0xFFB8DCC8),
                          barWidth: 1.5,
                          dashArray: [5, 4],
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(1)}j',
                                  TextStyle(
                                    color: s.bar.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 16, height: 2, color: _amber),
              const SizedBox(width: 5),
              const Text(
                'Mon délai',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 16,
                height: 12,
                child: CustomPaint(painter: _DashPainter()),
              ),
              const SizedBox(width: 5),
              const Text(
                'Moy. panel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required String value,
    required Color valueColor,
    String? sub,
    Color? subColor,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: subColor ?? const Color(0xFFAAAAAA),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  );

  // ── 5. CLASSIFICATIONS ───────────────────────────────────────────────────
  Widget _buildClassifications() {
    return _fixedCard(
      height: 285,
      header: _sectionBar(
        title: 'Mes classifications',
        icon: Icons.bar_chart_outlined,
        dateDebut: _classDateDebut,
        dateFin: _classDateFin,
        onDateTap: () => _openDateSheet(
          titre: 'Filtrer les classifications',
          dateDebut: _classDateDebut,
          dateFin: _classDateFin,
          periodOnly: false,
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
            height: 150,
            child: _classifications.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY:
                                  _classifications
                                      .map(
                                        (p) =>
                                            (p.extraVierge +
                                                    p.vierge +
                                                    p.lampante)
                                                .toDouble(),
                                      )
                                      .fold(0.0, (a, b) => a > b ? a : b) +
                                  1,
                              barGroups: List.generate(
                                _classifications.length,
                                (i) {
                                  final p = _classifications[i];
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: p.extraVierge.toDouble(),
                                        color: _green,
                                        width: 10,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                      ),
                                      BarChartRodData(
                                        toY: p.vierge.toDouble(),
                                        color: _olive,
                                        width: 10,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                      ),
                                      BarChartRodData(
                                        toY: p.lampante.toDouble(),
                                        color: _amber,
                                        width: 10,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
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
                                      if (i < 0 ||
                                          i >= _classifications.length) {
                                        return const SizedBox();
                                      }
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
                      ),
                    ],
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

  // ── 6. ACTIVITE ──────────────────────────────────────────────────────────
  Widget _buildActivite() {
    return Container(
      height: 345,
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
            onDateTap: _openActDateSheet,
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
                    n.metrics.pixels >= n.metrics.maxScrollExtent - 40) {
                  _loadMoreActivite();
                }
                return false;
              },
              child: _activite.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune activité récente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    )
                  : ListView.builder(
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

  Widget _timelineItem(ActiviteItem item, {required bool isLast}) {
    final Color dot;
    switch (item.type) {
      case 'seance_presente':
        dot = _blue;
        break;
      case 'seance_manquee':
        dot = _red;
        break;
      case 'profil':
        dot = _amber;
        break;
      default:
        dot = _green;
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
      ..color = _green
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

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8DCC8)
      ..strokeWidth = 1.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 4, size.height / 2),
        paint,
      );
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
