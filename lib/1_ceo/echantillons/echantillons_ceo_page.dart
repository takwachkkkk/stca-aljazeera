// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/echantillons/echantillons_ceo_page.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/widgets/bandeau_demonstration.dart';
import 'package:project3/core/widgets/empty_state.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'models/collecteur_group.dart';
import '../widgets/ceo_nav_mixin.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/ceo_drawer.dart';
import '../utilisateurs/models/echantillon_ceo_view.dart';
import '../analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import '../analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../validation_achats/validation_achats_ceo_page.dart';
import '../utilisateurs/models/mock_data_patch.dart';
import '../utilisateurs/utilisateurs_ceo_page.dart';
import '../../main.dart';
import '../profil_ceo_page.dart';
import '../tableau_de_bord/tableau_de_bord.dart';

// ── Reusable widget imports ──────────────────────────────────────────────────
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../widgets/sample_card_echantillon.dart';
import 'widgets/collecteur_section.dart';
import 'services/echantillon_ceo_service.dart';

String _initials(String name) {
  final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class EchantillonsCeoPage extends StatefulWidget {
  const EchantillonsCeoPage({super.key, this.referenceInitiale, this.service});

  final String? referenceInitiale;
  final EchantillonCeoService? service;

  @override
  State<EchantillonsCeoPage> createState() => _EchantillonsCeoPageState();
}

class _EchantillonsCeoPageState extends State<EchantillonsCeoPage>
    with CeoNavMixin, RafraichissementPeriodique {
  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateType = DateFilterType.enregistrement;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _expandedCollecteurs = {};
  final Set<String> _expandedSamples = {};

  late final EchantillonCeoService _service;
  List<EchantillonCeoView> _allEchantillons = [];
  bool _chargement = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EchantillonCeoService();
    final referenceInitiale = widget.referenceInitiale?.trim();
    if (referenceInitiale != null && referenceInitiale.isNotEmpty) {
      _searchQuery = referenceInitiale;
      _searchController.text = referenceInitiale;
    }
    _loadEchantillons();
  }

  Future<void> _loadEchantillons() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final resultat = await _service.fetchCeoViews(
        () => List.of(mockEchantillons),
      );
      if (!mounted) return;
      setState(() {
        _allEchantillons = resultat.donnees;
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

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await _service.fetchCeoViews(
        () => List.of(mockEchantillons),
      );
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _allEchantillons = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────
  String? _dateFieldFor(EchantillonCeoView e) {
    switch (_dateType) {
      case DateFilterType.enregistrement:
        return e.dateAjout;
      case DateFilterType.livraisonEchantillon:
        return e.dateArriveeEchantillon ?? e.dateLivraisonPrevue;
      case DateFilterType.receptionPhysique:
        return e.dateReceptionEchantillon;
      case DateFilterType.arriveeStock:
        return e.dateLivraisonStock;
    }
  }

  List<EchantillonCeoView> _applyFilters(List<EchantillonCeoView> list) {
    var result = list;

    if (_dateDebut != null) {
      result = result.where((e) {
        final raw = _dateFieldFor(e);
        if (raw == null) return false;
        final d = DegDateUtils.parseDate(raw);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        final debut = DateTime(
          _dateDebut!.year,
          _dateDebut!.month,
          _dateDebut!.day,
        );
        if (_dateFin != null) {
          final fin = DateTime(_dateFin!.year, _dateFin!.month, _dateFin!.day);
          return !day.isBefore(debut) && !day.isAfter(fin);
        }
        return day == debut;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) {
        return e.referenceBouteille.toLowerCase().contains(q) ||
            e.fournisseurTexte.toLowerCase().contains(q) ||
            (e.fournisseurNom?.toLowerCase().contains(q) ?? false) ||
            e.numero.toLowerCase().contains(q) ||
            e.gouvernorat.toLowerCase().contains(q) ||
            (e.variete?.toLowerCase().contains(q) ?? false) ||
            (e.collecteurNom?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return result;
  }

  List<CollecteurGroup> get _groups {
    final filtered = DegDateUtils.plusRecentsDabord(_applyFilters(_allEchantillons), (e) => e.dateAjout);
    final Map<String, List<EchantillonCeoView>> byCollecteur = {};

    for (final e in filtered) {
      final key = e.collecteurNom ?? '__interne__';
      byCollecteur.putIfAbsent(key, () => []).add(e);
    }

    final List<CollecteurGroup> groups = [];
    final collecteurKeys =
        byCollecteur.keys.where((k) => k != '__interne__').toList()..sort();

    for (final key in collecteurKeys) {
      groups.add(
        CollecteurGroup(
          collecteurNom: key,
          collecteurId: key.replaceAll(' ', '_').toLowerCase(),
          echantillons: byCollecteur[key]!,
        ),
      );
    }

    if (byCollecteur.containsKey('__interne__')) {
      groups.add(
        CollecteurGroup(
          collecteurNom: null,
          echantillons: byCollecteur['__interne__']!,
        ),
      );
    }

    return groups;
  }

  // ── Date filter sheet ──────────────────────────────────────────────────────
  Future<void> _showDateFilter() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        availableTypes: DateFilterType.values,
        initialType: _dateType,
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

  bool get _dateFilterActive => _dateDebut != null || _dateFin != null;
  bool get _anyFilter => _dateFilterActive || _searchQuery.isNotEmpty;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final groups = _groups;

    return Scaffold(
      backgroundColor: kBg,
      drawer: CeoDrawer(
        currentPage: CeoDestination.echantillons,
        onEchantillons: () => goToPage(const EchantillonsCeoPage()),
        onAnalyseOrganoleptique: () =>
            goToPage(const AnalyseOrganoleptiqueCeoPage()),
        onAnalyseLaboratoire: () => goToPage(const AnalyseLaboratoireCeoPage()),
        onValidationAchats: () => goToPage(const ValidationAchatsCeoPage()),
        onAchatsConfirmes: () => goToPage(const AchatsConfirmesCeoPage()),
        onTableauDeBord: () => goToPage(const HomePageCeo()),
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
          'Échantillons',
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
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _loadEchantillons,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: kGreen,
              child: Column(
                children: [
                  // ── Unified header zone ──────────────────────────────────────
                  Container(
                    color: kHeaderBg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: const TextStyle(fontSize: 14, color: kDark),
                      decoration: InputDecoration(
                        hintText:
                            'Réf, numéro, fournisseur, gouvernorat, variété, collecteur…',
                        hintStyle: const TextStyle(
                          color: Color(0xFF6B8E7A),
                          fontSize: 11,
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
                  ),
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),

                  // ── List ─────────────────────────────────────────────────────
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
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _allEchantillons.isEmpty
                                            ? kTitreSystemeNeuf
                                            : 'Aucun échantillon trouvé',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (_allEchantillons.isEmpty)
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
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                            itemCount: groups.length,
                            itemBuilder: (_, i) => CollecteurSection(
                              group: groups[i],
                              isExpanded: _expandedCollecteurs.contains(
                                groups[i].displayName,
                              ),
                              expandedSamples: _expandedSamples,
                              onToggleCollecteur: () => setState(() {
                                final key = groups[i].displayName;
                                _expandedCollecteurs.contains(key)
                                    ? _expandedCollecteurs.remove(key)
                                    : _expandedCollecteurs.add(key);
                              }),
                              onToggleSample: (id) => setState(() {
                                _expandedSamples.contains(id)
                                    ? _expandedSamples.remove(id)
                                    : _expandedSamples.add(id);
                              }),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
