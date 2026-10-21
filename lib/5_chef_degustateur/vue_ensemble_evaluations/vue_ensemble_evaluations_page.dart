// ═════════════════════════════════════════════════════════════════════════════
// FILE : vue_ensemble_evaluations/vue_ensemble_evaluations_page.dart
// PURPOSE : Chef de Dégustation — all tasters' submitted evaluations per sample,
//           read-only overview. "Voir" opens the shared CEO evaluation form sheet.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:project3/core/widgets/details_echantillon.dart';
import 'package:flutter/material.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/enums.dart';
import '../../core/utils/json_utils.dart';
import '../panel_coi/fiche_resultat_panel.dart';
import '../../core/logout_navigation.dart';
import '../../core/widgets/messagerie/conversations_page.dart';

import '../profil.dart';
import '../tableau_de_bord/widgets/app_drawer.dart';
import '../utilisateurs/utilisateurs_chef_page.dart';
import '../tableau_de_bord/homepage_page.dart';
import '../gestion_echantillons/gestion_echantillons_page.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart'
    show DateFilterSheet;
import '../evaluation_echantillons/evaluation_echantillons_page.dart';
import '../analyse_labo/analyse_laboratoire_page.dart';
import '../sessions_degustation/sessions_degustation_page.dart';
// TODO(core): move shared_evaluation_form_sheet to lib/core/widgets/ — cross-module import from 1_ceo
import '../../../1_ceo/widgets/shared_evaluation_form_sheet.dart';
// TODO(core): create a shared EchantillonView model in lib/core/models/ — cross-module import from 1_ceo
import '../../../1_ceo/utilisateurs/models/echantillon_ceo_view.dart';
// TODO(core): move these card widgets to lib/core/widgets/ — cross-module import from 1_ceo
import '../../../1_ceo/widgets/base_sample_card.dart';
import '../../../1_ceo/analyse_organoleptique/widgets/panel_section.dart';
import '../../../1_ceo/analyse_organoleptique/widgets/panel_widgets.dart'
    show RecuPhysiqueIndicator;
import '../../../main.dart';
import '../widgets/chef_colors.dart';
import '../../../core/api_client.dart';
import '../../core/utils/rafraichissement_periodique.dart';
import '../../core/widgets/grille_details.dart';
import '../../core/services/resultat_service.dart';
import '../../core/widgets/bandeau_demonstration.dart';

const Color _olive = Color(0xFF6B8143);

// ── Models ────────────────────────────────────────────────────────────────────

class _EvalEntry {
  final String attribut;
  final double score;
  const _EvalEntry(this.attribut, this.score);
}

class _TasterEval {
  final String tasterName;
  final String statut; // 'Soumis' | 'En attente'
  final String? dateEval;
  final String? classification;
  final List<_EvalEntry> scores;

  /// Réponse serveur complète : défauts, type de fruité et classe interne
  /// servent à la fiche « formulaire » ouverte depuis la ligne du dégustateur.
  final Map<String, dynamic> brut;

  const _TasterEval({
    required this.tasterName,
    required this.statut,
    this.dateEval,
    this.classification,
    this.scores = const [],
    this.brut = const {},
  });
}

class _SampleEvalGroup {
  final String sampleId;
  final String referenceBouteille;
  final String gouvernorat;
  final String variete;
  final String dateAjout;
  final bool recuPhysiquement;
  final String? dateReceptionEchantillon;
  final List<_TasterEval> evaluations;
  final String? numero;
  final String? fournisseur;
  final String? delegation;
  final String? collecteur;
  final String? numCiterne;
  final String? dateArrivee;
  final String? dateLivraisonStock;

  const _SampleEvalGroup({
    required this.sampleId,
    required this.referenceBouteille,
    required this.gouvernorat,
    required this.variete,
    required this.dateAjout,
    required this.recuPhysiquement,
    this.dateReceptionEchantillon,
    required this.evaluations,
    this.numero,
    this.fournisseur,
    this.delegation,
    this.collecteur,
    this.numCiterne,
    this.dateArrivee,
    this.dateLivraisonStock,
  });

  int get submitted => evaluations.where((e) => e.statut == 'Soumis').length;
  int get total => evaluations.length;
  bool get isComplete => submitted == total && total > 0;
}

const _attrs = ['Fruité', 'Amer', 'Piquant', 'Doux', 'Floral'];

// ── Mock data ─────────────────────────────────────────────────────────────────

final _mockGroups = [
  _SampleEvalGroup(
    sampleId: 'OL-2024-001',
    referenceBouteille: 'REF-2024-0341',
    gouvernorat: 'Sfax',
    variete: 'Chemlali',
    dateAjout: '20/02/2026',
    recuPhysiquement: true,
    dateReceptionEchantillon: '18/02/2026',
    evaluations: [
      _TasterEval(
        tasterName: 'Ichrak C.',
        statut: 'Soumis',
        dateEval: '20/02/2026',
        classification: 'Extra Vierge',
        scores: [
          _EvalEntry('Fruité', 4.5),
          _EvalEntry('Amer', 3.8),
          _EvalEntry('Piquant', 3.5),
          _EvalEntry('Doux', 4.2),
          _EvalEntry('Floral', 4.0),
        ],
      ),
      _TasterEval(
        tasterName: 'Lobna E.',
        statut: 'Soumis',
        dateEval: '20/02/2026',
        classification: 'Extra Vierge',
        scores: [
          _EvalEntry('Fruité', 4.2),
          _EvalEntry('Amer', 4.0),
          _EvalEntry('Piquant', 3.8),
          _EvalEntry('Doux', 3.9),
          _EvalEntry('Floral', 3.7),
        ],
      ),
      _TasterEval(
        tasterName: 'Maha O.',
        statut: 'Soumis',
        dateEval: '21/02/2026',
        classification: 'Vierge',
        scores: [
          _EvalEntry('Fruité', 2.5),
          _EvalEntry('Amer', 2.0),
          _EvalEntry('Piquant', 1.8),
          _EvalEntry('Doux', 2.5),
          _EvalEntry('Floral', 2.2),
        ],
      ),
      _TasterEval(tasterName: 'Nayrouz F.', statut: 'En attente'),
    ],
  ),
  _SampleEvalGroup(
    sampleId: 'OL-2024-002',
    referenceBouteille: 'REF-2024-0342',
    gouvernorat: 'Bizerte',
    variete: 'Chetoui',
    dateAjout: '21/02/2026',
    recuPhysiquement: false,
    evaluations: [
      _TasterEval(
        tasterName: 'Nayrouz F.',
        statut: 'Soumis',
        dateEval: '21/02/2026',
        classification: 'Extra Vierge',
        scores: [
          _EvalEntry('Fruité', 3.9),
          _EvalEntry('Amer', 4.1),
          _EvalEntry('Piquant', 3.7),
          _EvalEntry('Doux', 3.5),
          _EvalEntry('Floral', 3.8),
        ],
      ),
      _TasterEval(
        tasterName: 'Yosra S.',
        statut: 'Soumis',
        dateEval: '21/02/2026',
        classification: 'Extra Vierge',
        scores: [
          _EvalEntry('Fruité', 4.1),
          _EvalEntry('Amer', 3.9),
          _EvalEntry('Piquant', 3.6),
          _EvalEntry('Doux', 3.7),
          _EvalEntry('Floral', 4.0),
        ],
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────
class VueEnsembleEvaluationsPage extends StatefulWidget {
  const VueEnsembleEvaluationsPage({super.key});

  @override
  State<VueEnsembleEvaluationsPage> createState() =>
      _VueEnsembleEvaluationsPageState();
}

class _VueEnsembleEvaluationsPageState extends State<VueEnsembleEvaluationsPage>
    with RafraichissementPeriodique {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  final Set<String> _expandedPanel = {};
  List<_SampleEvalGroup> _groups = [];
  bool _chargement = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final resultat = await _fetchGroups();
      if (!mounted) return;
      setState(() {
        _groups = resultat.donnees;
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

  Future<Resultat<List<_SampleEvalGroup>>> _fetchGroups() {
    return avecSecours(() async {
      final data = await apiClient.getList('/api/chef/evaluations/');
      return data.map((e) => _groupFromApi(e as Map<String, dynamic>)).toList();
    }, () => List.of(_mockGroups));
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await _fetchGroups();
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _groups = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  bool get _dateFilterActive => _dateDebut != null || _dateFin != null;

  void _goTo(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _goToLogin() {
    Navigator.pop(context);
    logoutAndShowLogin(context);
  }

  DateTime? _parseDate(String s) {
    try {
      final p = s.split('/');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  List<_SampleEvalGroup> get _filtered {
    var list = _groups;
    if (_dateFilterActive) {
      list = list.where((g) {
        if (!g.recuPhysiquement || g.dateReceptionEchantillon == null) {
          return false;
        }
        final d = _parseDate(g.dateReceptionEchantillon!);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        final debut = _dateDebut != null
            ? DateTime(_dateDebut!.year, _dateDebut!.month, _dateDebut!.day)
            : null;
        final fin = _dateFin != null
            ? DateTime(_dateFin!.year, _dateFin!.month, _dateFin!.day)
            : null;
        if (debut != null && fin != null) {
          return !day.isBefore(debut) && !day.isAfter(fin);
        }
        if (debut != null) return !day.isBefore(debut);
        if (fin != null) return !day.isAfter(fin);
        return true;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (g) =>
                (g.numero?.toLowerCase().contains(q) ?? false) ||
                g.referenceBouteille.toLowerCase().contains(q) ||
                g.gouvernorat.toLowerCase().contains(q) ||
                g.variete.toLowerCase().contains(q),
          )
          .toList();
    }
    return DegDateUtils.plusRecentsDabord(list, (e) => e.dateAjout);
  }

  _SampleEvalGroup _groupFromApi(Map<String, dynamic> json) {
    return _SampleEvalGroup(
      sampleId:
          json['sample_id'] as String? ?? json['echantillon_id'] as String,
      referenceBouteille:
          json['reference_bouteille'] as String? ??
          json['numero'] as String? ??
          '',
      gouvernorat: json['gouvernorat'] as String? ?? '',
      variete: json['variete'] as String? ?? '',
      dateAjout: json['date_ajout']?.toString() ?? '',
      recuPhysiquement: json['recu_physiquement'] as bool? ?? false,
      dateReceptionEchantillon:
          (json['date_reception_echantillon'] ?? json['date_reception_physique'])
              ?.toString(),
      numero: json['numero'] as String?,
      fournisseur: json['fournisseur_nom'] as String?,
      delegation: json['delegation'] as String?,
      collecteur: json['collecteur_nom'] as String?,
      numCiterne: json['num_citerne'] as String?,
      dateArrivee: json['date_arrivee_echantillon']?.toString(),
      dateLivraisonStock: json['date_livraison_stock']?.toString(),
      evaluations: ((json['evaluations'] as List<dynamic>?) ?? const [])
          .map((e) => _tasterEvalFromApi(e as Map<String, dynamic>))
          .toList(),
    );
  }

  _TasterEval _tasterEvalFromApi(Map<String, dynamic> json) {
    final submitted = json['statut'] == 'soumis';
    return _TasterEval(
      tasterName:
          json['taster_name'] as String? ??
          json['degustateur_nom'] as String? ??
          '',
      statut: submitted ? 'Soumis' : 'En attente',
      dateEval: _formatDate(json['soumis_le'] ?? json['date_eval']),
      classification: _classificationLabel(json['classification'] as String?),
      scores: _scoresFromApi(json),
      brut: json,
    );
  }

  List<_EvalEntry> _scoresFromApi(Map<String, dynamic> json) {
    final rawScores = json['scores'] as List<dynamic>?;
    if (rawScores != null && rawScores.isNotEmpty) {
      return rawScores
          .whereType<Map<String, dynamic>>()
          .where((score) => score['score'] != null)
          .map(
            (score) => _EvalEntry(
              _scoreLabel(
                score['key'] as String?,
                score['attribut'] as String?,
              ),
              _double(score['score']),
            ),
          )
          .toList();
    }

    return [
      if (json['fruite'] != null)
        _EvalEntry(_attrs[0], _double(json['fruite'])),
      if (json['amertume'] != null)
        _EvalEntry(_attrs[1], _double(json['amertume'])),
      if (json['piquant'] != null)
        _EvalEntry(_attrs[2], _double(json['piquant'])),
    ];
  }

  String _scoreLabel(String? key, String? fallback) {
    switch (key) {
      case 'fruite':
        return _attrs[0];
      case 'amertume':
        return _attrs[1];
      case 'piquant':
        return _attrs[2];
      default:
        return fallback ?? '';
    }
  }

  String? _classificationLabel(String? value) {
    switch (value) {
      case 'extra_vierge':
        return 'Extra Vierge';
      case 'vierge':
        return 'Vierge';
      case 'vierge_ordinaire':
        return 'Vierge Ordinaire';
      case 'lampante':
        return 'Lampante';
      default:
        return value;
    }
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  Future<void> _showDateFilter() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        onApply: (d, f) => setState(() {
          _dateDebut = d;
          _dateFin = f;
        }),
        onClear: () => setState(() {
          _dateDebut = null;
          _dateFin = null;
        }),
      ),
    );
  }

  /// Traduit un groupe du chef vers le modele que la carte partagee attend.
  ///
  /// Seules les evaluations soumises sont converties : la liste du panel
  /// n'affiche que du travail rendu, et le compteur « 3 / 4 » du badge dit deja
  /// combien manquent.
  EchantillonCeoView _vueDepuisGroupe(_SampleEvalGroup g) {
    return EchantillonCeoView(
      id: g.sampleId,
      referenceBouteille: g.referenceBouteille,
      fournisseurTexte: '',
      gouvernorat: g.gouvernorat,
      variete: g.variete,
      dateAjout: g.dateAjout,
      recuPhysiquement: g.recuPhysiquement,
      statut: StatutCeo.selectionne,
      totalTasteurs: g.total,
      evaluations: g.evaluations
          .where((e) => e.statut == 'Soumis' && e.classification != null)
          .map((e) => _evaluationDepuis(e, g))
          .toList(),
    );
  }

  EvaluationOrganoleptique _evaluationDepuis(
    _TasterEval eval,
    _SampleEvalGroup group,
  ) {
    final b = eval.brut;
    return EvaluationOrganoleptique(
      id: b['id'] as String? ?? '${group.sampleId}_${eval.tasterName}',
      echantillonId: group.sampleId,
      tasteurId: b['degustateur_id'] as String? ?? eval.tasterName,
      tasteurNom: eval.tasterName,
      soumisLe: eval.dateEval != null
          ? _parseDateToIso(eval.dateEval!)
          : DateTime.now().toIso8601String(),
      classification: _classificationFromStr(eval.classification!),
      classeInterne: ClasseInterneX.fromJson(b['classe_interne'] as String?),
      classeInterneManuelle: b['classe_interne_manuelle'] as bool? ?? false,
      classeInterneMotif: b['classe_interne_motif'] as String?,
      profilNonHarmonieux: b['profil_non_harmonieux'] as bool? ?? false,
      fruite: nombreDepuisJson(b['fruite']) ?? _scoreFor(eval.scores, 'Fruité'),
      typeFruite: TypeFruiteX.fromJson(b['type_fruite'] as String?),
      amertume:
          nombreDepuisJson(b['amertume']) ?? _scoreFor(eval.scores, 'Amer'),
      piquant:
          nombreDepuisJson(b['piquant']) ?? _scoreFor(eval.scores, 'Piquant'),
      chome: nombreDepuisJson(b['chome']),
      moisi: nombreDepuisJson(b['moisi']),
      vinaigre: nombreDepuisJson(b['vinaigre']),
      rance: nombreDepuisJson(b['rance']),
      gele: nombreDepuisJson(b['gele']),
      autresDefaut: nombreDepuisJson(b['autres_defaut']),
      autresDefautNom: b['autres_defaut_nom'] as String?,
      commentaire: b['commentaire'] as String?,
    );
  }

  // ── "Voir" handler — builds EvaluationOrganoleptique and opens CEO sheet ──
  void _onViewEval(_TasterEval eval, _SampleEvalGroup group) {
    if (eval.statut != 'Soumis' || eval.classification == null) return;
    showEvaluationFormSheet(
      context,
      evaluation: _evaluationDepuis(eval, group),
      sampleRef: group.referenceBouteille,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double? _scoreFor(List<_EvalEntry> scores, String attribut) {
    final match = scores.where((s) => s.attribut == attribut);
    return match.isEmpty ? null : match.first.score;
  }

  String _parseDateToIso(String ddMMyyyy) {
    try {
      final p = ddMMyyyy.split('/');
      if (p.length != 3) return DateTime.now().toIso8601String();
      return DateTime(
        int.parse(p[2]),
        int.parse(p[1]),
        int.parse(p[0]),
      ).toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  ClassificationHuile _classificationFromStr(String s) {
    switch (s) {
      case 'Extra Vierge':
        return ClassificationHuile.extraVierge;
      case 'Vierge':
        return ClassificationHuile.vierge;
      case 'Vierge Ordinaire':
        return ClassificationHuile.viergeOrdinaire;
      default:
        return ClassificationHuile.lampante;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filtered;

    return Scaffold(
      backgroundColor: chefBg,
      drawer: AppDrawer(currentPage: ChefDestination.vueEnsemble),
      appBar: AppBar(
        backgroundColor: chefHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Vue d\'ensemble évaluations',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: chefDark,
          ),
        ),
        iconTheme: const IconThemeData(color: chefDark),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _dateFilterActive
                      ? chefGreen
                      : const Color(0xFF6B8E7A),
                ),
                onPressed: _showDateFilter,
                tooltip: 'Filtrer par date de réception physique',
              ),
              if (_dateFilterActive)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: chefGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: chefGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _loadGroups,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: chefGreen,
              child: Column(
                children: [
                  // ── Search bar ────────────────────────────────────────────────────
                  Container(
                    color: chefHeaderBg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: const TextStyle(fontSize: 14, color: chefDark),
                      decoration: InputDecoration(
                        hintText:
                            'Rechercher échantillon, variété, gouvernorat…',
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
                            color: chefGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),

                  // ── List ──────────────────────────────────────────────────────────
                  Expanded(
                    child: groups.isEmpty
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
                                        Icons.assessment_outlined,
                                        size: 52,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Aucun échantillon trouvé',
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
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                            itemCount: groups.length,
                            itemBuilder: (_, i) {
                              final g = groups[i];
                              // Meme carte que l'ecran Analyse organoleptique de la
                              // direction : le chef consulte les memes donnees, il n'y
                              // a aucune raison que les deux ecrans se ressemblent de
                              // loin plutot que d'etre identiques.
                              final vue = _vueDepuisGroupe(g);
                              return BaseSampleCard(
                                referenceBouteille: g.referenceBouteille,
                                numero: g.numero ?? '',
                                tintColor: Colors.white,
                                accentColor: g.isComplete ? chefGreen : _olive,
                                badge: CardBadgeRow(
                                  badges: [
                                    CardBadge(
                                      label: '${g.submitted} / ${g.total}',
                                      color: g.isComplete ? chefGreen : _olive,
                                    ),
                                  ],
                                ),
                                detailItems: [
                                  ...detailsEchantillon(
                                    numero: g.numero,
                                    referenceBouteille: g.referenceBouteille,
                                    fournisseur: g.fournisseur,
                                    variete: g.variete,
                                    gouvernorat: g.gouvernorat,
                                    delegation: g.delegation,
                                    collecteur: g.collecteur,
                                    numCiterne: g.numCiterne,
                                    dateAjout: g.dateAjout,
                                    recuPhysiquement: g.recuPhysiquement,
                                    dateArrivee: g.dateArrivee,
                                    dateReception: g.dateReceptionEchantillon,
                                    dateLivraisonStock: g.dateLivraisonStock,
                                  ),
                                  DetailItem(
                                    'Évaluations',
                                    '${g.submitted} / ${g.total} soumises',
                                  ),
                                ],
                                bottomSection: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    PanelSection(
                                      echantillon: vue,
                                      isExpanded: _expandedPanel.contains(
                                        g.sampleId,
                                      ),
                                      onToggle: () => setState(() {
                                        _expandedPanel.contains(g.sampleId)
                                            ? _expandedPanel.remove(g.sampleId)
                                            : _expandedPanel.add(g.sampleId);
                                      }),
                                      // Le chef consulte, il ne decide pas de l'achat.
                                      showDecisions: false,
                                      showRecu: false,
                                      onViewForm: (ev) =>
                                          showEvaluationFormSheet(
                                            context,
                                            evaluation: ev,
                                            sampleRef: g.referenceBouteille,
                                          ),
                                    ),
                                    // Mediane, CVr % et categorie du panel
                                    // (methode COI) pour cet echantillon.
                                    if (g.submitted > 0)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          10,
                                        ),
                                        child: OutlinedButton.icon(
                                          onPressed: () => ouvrirResultatPanel(
                                            context,
                                            g.sampleId,
                                          ),
                                          icon: const Icon(
                                            Icons.functions,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Résultat du panel (méthode COI)',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: chefGreen,
                                            side: BorderSide(
                                              color: chefGreen.withValues(
                                                alpha: 0.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
