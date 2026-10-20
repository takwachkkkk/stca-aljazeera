// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/analyse_laboratoire/analyse_laboratoire_ceo_page.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/widgets/bandeau_demonstration.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'models/lab_row.dart';
import '../widgets/ceo_nav_mixin.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/ceo_drawer.dart';
import '../utilisateurs/models/echantillon_ceo_view.dart';
import '../echantillons/echantillons_ceo_page.dart';
import '../analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../validation_achats/validation_achats_ceo_page.dart';
import '../tableau_de_bord/tableau_de_bord.dart';
import '../profil_ceo_page.dart';
import '../../main.dart';
import '../utilisateurs/models/mock_data_patch.dart';
import '../utilisateurs/utilisateurs_ceo_page.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../widgets/sample_card_echantillon.dart';
import '../widgets/base_sample_card.dart';
import '../widgets/status_filter_chip.dart';
import 'widgets/rapport_section.dart';
import '../echantillons/services/echantillon_ceo_service.dart';
import '../../core/widgets/grille_details.dart';

const Color _teal = Color(0xFF00796B);
const Color _dark = Color(0xFF1A2E1F);

// ─────────────────────────────────────────────────────────────────────────────
class AnalyseLaboratoireCeoPage extends StatefulWidget {
  const AnalyseLaboratoireCeoPage({super.key});
  @override
  State<AnalyseLaboratoireCeoPage> createState() =>
      _AnalyseLaboratoireCeoPageState();
}

class _AnalyseLaboratoireCeoPageState extends State<AnalyseLaboratoireCeoPage>
    with CeoNavMixin, RafraichissementPeriodique {
  final Set<String> _expandedRapport = {};

  // ── ADDED: active filter state (mirrors achats confirmes pattern) ──────────
  String _activeFilter = 'tout';

  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateType = DateFilterType.enregistrement;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final _service = EchantillonCeoService();
  List<EchantillonCeoView> _allSamples = [];
  bool _chargement = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final resultat = await _service.fetchCeoViews(
        () => List.of(mockEchantillonsLabo),
      );
      if (!mounted) return;
      setState(() {
        _allSamples = resultat.donnees;
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
        () => List.of(mockEchantillonsLabo),
      );
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _allSamples = resultat.donnees;
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

  List<EchantillonCeoView> get _samples {
    var result = _allSamples;
    if (_dateDebut != null) {
      result = result.where((e) {
        final dateStr = _dateFieldFor(e);
        if (dateStr == null) return false;
        final d = DegDateUtils.parseDate(dateStr);
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
      result = result
          .where(
            (e) =>
                e.referenceBouteille.toLowerCase().contains(q) ||
                e.numero.toLowerCase().contains(q) ||
                e.fournisseurTexte.toLowerCase().contains(q) ||
                (e.fournisseurNom?.toLowerCase().contains(q) ?? false) ||
                e.gouvernorat.toLowerCase().contains(q) ||
                (e.variete?.toLowerCase().contains(q) ?? false) ||
                (e.collecteurNom?.toLowerCase().contains(q) ?? false) ||
                (e.analyse?.classificationAuto.toLowerCase().contains(q) ??
                    false),
          )
          .toList();
    }
    // ── ADDED: apply status filter ────────────────────────────────────────────
    if (_activeFilter == 'Analyse soumise') {
      result = result.where((e) => e.analyse != null).toList();
    } else if (_activeFilter == 'Analyse en attente') {
      result = result.where((e) => e.analyse == null).toList();
    }
    return DegDateUtils.plusRecentsDabord(result, (e) => e.dateAjout);
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
        availableTypes: const [
          DateFilterType.enregistrement,
          DateFilterType.livraisonEchantillon,
        ],
        initialType: _dateType,
        onApplyTyped: (d, f, type) => setState(() {
          _dateDebut = d;
          _dateFin = f;
          _dateType = type;
        }),
      ),
    );
  }

  Color _classifColor(String c) {
    if (c == 'Extra Vierge') return kGreen;
    if (c == 'Vierge') return Colors.orange.shade700;
    if (c == 'Lampante') return Colors.red.shade600;
    return Colors.grey.shade500;
  }

  Color _headerTint(bool hasAnalyse, String classif) {
    if (!hasAnalyse) return const Color(0xFFFAF0E6);
    if (classif == 'Extra Vierge') return const Color(0xFFEAF4EE);
    if (classif == 'Vierge') return const Color(0xFFFFF3E0);
    if (classif == 'Lampante') return const Color(0xFFFFEBEE);
    return const Color(0xFFF5F5F5);
  }

  @override
  Widget build(BuildContext context) {
    final samples = _samples;
    return Scaffold(
      backgroundColor: kBg,
      drawer: CeoDrawer(
        currentPage: CeoDestination.laboratoire,
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
          'Analyse laboratoire',
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
                  color: (_dateDebut != null || _dateFin != null)
                      ? kGreen
                      : const Color(0xFF6B8E7A),
                ),
                onPressed: _showDateFilter,
                tooltip: _dateDebut != null
                    ? 'Filtré par : ${_dateType.label}'
                    : 'Filtrer par date',
              ),
              if (_dateDebut != null || _dateFin != null)
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
              onReessayer: _loadSamples,
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
                            'Réf, numéro, fournisseur, gouvernorat, variété, collecteur, classification…',
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

                  // ── CHANGED: filter chips strip (replaces old stats strip) ───────────
                  Container(
                    color: kBg,
                    padding: const EdgeInsets.fromLTRB(16, 9, 16, 6),
                    child: Row(
                      children: [
                        StatusFilterChip(
                          label: 'Tout',
                          isActive: _activeFilter == 'tout',
                          activeBg: const Color(0xFF757575),
                          activeFg: Colors.white,
                          onTap: () => setState(() => _activeFilter = 'tout'),
                        ),
                        const SizedBox(width: 8),
                        StatusFilterChip(
                          label: 'Analyse soumise',
                          isActive: _activeFilter == 'Analyse soumise',
                          activeBg: kGreen.withValues(alpha: 0.12),
                          activeFg: kGreen,
                          onTap: () =>
                              setState(() => _activeFilter = 'Analyse soumise'),
                        ),
                        const SizedBox(width: 8),
                        StatusFilterChip(
                          label: 'Analyse en attente',
                          isActive: _activeFilter == 'Analyse en attente',
                          activeBg: Colors.orange.shade700.withValues(
                            alpha: 0.12,
                          ),
                          activeFg: Colors.orange.shade700,
                          onTap: () => setState(
                            () => _activeFilter = 'Analyse en attente',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List
                  Expanded(
                    child: samples.isEmpty
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
                            itemCount: samples.length,
                            itemBuilder: (_, i) {
                              final e = samples[i];
                              final hasAnalyse = e.analyse != null;
                              final classif =
                                  e.analyse?.classificationAuto ?? '—';
                              final classifColor = _classifColor(classif);
                              final rapportExp = _expandedRapport.contains(
                                e.id,
                              );

                              return BaseSampleCard(
                                referenceBouteille: e.referenceBouteille,
                                numero: e.numero,
                                tintColor: _headerTint(hasAnalyse, classif),
                                accentColor: _teal,
                                badge: CardBadgeRow(
                                  badges: [
                                    if (e.quantiteEstimee != null)
                                      CardBadge(
                                        label: 'Qté : ${e.quantiteEstimee}T',
                                        color: kOlive,
                                      ),
                                  ],
                                ),
                                detailItems: [
                                  DetailItem('N° échantillon', e.numero),
                                  DetailItem(
                                    'Ref. bouteille',
                                    e.referenceBouteille,
                                  ),
                                  DetailItem(
                                    'Gouvernorat',
                                    '${e.gouvernorat}${e.delegation != null ? " — ${e.delegation}" : ""}',
                                  ),
                                  DetailItem(
                                    'Fournisseur',
                                    e.fournisseurAffichage,
                                  ),
                                  if (e.variete != null)
                                    DetailItem('Variété', e.variete!),
                                  if (e.quantiteEstimee != null)
                                    DetailItem(
                                      'Quantité',
                                      '${e.quantiteEstimee} T',
                                    ),
                                  DetailItem(
                                    'Enregistré le',
                                    DegDateUtils.formaterDateHeureOuTiret(
                                      e.dateAjout,
                                    ),
                                  ),
                                  if (e.collecteurNom != null)
                                    DetailItem('Collecteur', e.collecteurNom!),
                                  DetailItem(
                                    "Confirmation réception d'échantillon",
                                    e.recuPhysiquement ? 'Oui' : 'Non',
                                  ),
                                ],
                                deliveryWidget: SampleDeliveryIndicator(e: e),
                                bottomSection: RapportSection(
                                  echantillon: e,
                                  hasAnalyse: hasAnalyse,
                                  isExpanded: rapportExp,
                                  onToggle: () => setState(
                                    () => rapportExp
                                        ? _expandedRapport.remove(e.id)
                                        : _expandedRapport.add(e.id),
                                  ),
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
