// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/validation_achats/validation_achats_ceo_page.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/widgets/bandeau_demonstration.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import '../widgets/ceo_nav_mixin.dart';
import '../widgets/ceo_drawer.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../widgets/sample_card_echantillon.dart';
import '../widgets/base_sample_card.dart';
import '../widgets/status_filter_chip.dart';
import '../utilisateurs/models/echantillon_ceo_view.dart';
import '../utilisateurs/models/mock_data_patch.dart';
import '../echantillons/echantillons_ceo_page.dart';
import '../analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import '../analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../tableau_de_bord/tableau_de_bord.dart';
import '../utilisateurs/utilisateurs_ceo_page.dart';
import '../profil_ceo_page.dart';
import '../../main.dart';
import 'widgets/proposition_section.dart';
import 'widgets/decision_dialog.dart';
import 'widgets/refus_dialog.dart';
import '../../core/widgets/grille_details.dart';
import '../../core/widgets/marqueur_renegocie.dart';
import '../echantillons/services/echantillon_ceo_service.dart';

class ValidationAchatsCeoPage extends StatefulWidget {
  const ValidationAchatsCeoPage({super.key});

  @override
  State<ValidationAchatsCeoPage> createState() =>
      _ValidationAchatsCeoPageState();
}

class _ValidationAchatsCeoPageState extends State<ValidationAchatsCeoPage>
    with CeoNavMixin, RafraichissementPeriodique {
  static const _orangeActive = Color(0xFFD07B2F);
  static const _orangeTint = Color(0xFFFEF3E8);
  static const _greenTint = Color(0xFFE6F4ED);
  static const _redTint = Color(0xFFFFEBEE);

  final Set<String> _expanded = {};

  /// 'a_valider' | 'decidees' | 'tout'
  String _activeFilter = 'a_valider';

  DateTime? _dateDebut;
  DateTime? _dateFin;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final _service = EchantillonCeoService();

  /// Propositions en attente de décision — statut « en négociation ».
  List<EchantillonCeoView> _enAttente = [];

  /// Propositions déjà tranchées — achat confirmé ou refusé.
  List<EchantillonCeoView> _decidees = [];
  bool _chargement = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _loadPropositions();
  }

  /// Les données viennent de l'API, comme sur les trois autres écrans de la
  /// direction. Les listes mock ne servent que de repli hors ligne : sans ce
  /// chargement, l'écran affichait des propositions codées en dur et le
  /// directeur ne voyait jamais les vraies.
  Future<void> _loadPropositions() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final resultat = await _service.fetchCeoViews(
        () => [...mockPropositionsEnAttente, ...mockPropositionsDecidees],
      );
      if (!mounted) return;
      setState(() {
        _enAttente = resultat.donnees
            .where((e) => e.statut == StatutCeo.enNegociation)
            .toList();
        _decidees = resultat.donnees
            .where(
              (e) =>
                  e.statut == StatutCeo.achatConfirme ||
                  e.statut == StatutCeo.refuse,
            )
            .toList();
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
        () => [...mockPropositionsEnAttente, ...mockPropositionsDecidees],
      );
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _enAttente = resultat.donnees
            .where((e) => e.statut == StatutCeo.enNegociation)
            .toList();
        _decidees = resultat.donnees
            .where(
              (e) =>
                  e.statut == StatutCeo.achatConfirme ||
                  e.statut == StatutCeo.refuse,
            )
            .toList();
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

  List<EchantillonCeoView> get _source {
    switch (_activeFilter) {
      case 'a_valider':
        return _enAttente;
      case 'decidees':
        return _decidees;
      default:
        return [..._enAttente, ..._decidees];
    }
  }

  List<EchantillonCeoView> get _filtered {
    var result = _source;
    if (_dateDebut != null) {
      result = result.where((e) {
        final d = DegDateUtils.parseDate(e.dateAjout);
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
                (e.collecteurNom?.toLowerCase().contains(q) ?? false),
          )
          .toList();
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
      ),
    );
  }

  Future<void> _confirmer(EchantillonCeoView e) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmerAchatDialog(
        referenceBouteille: e.referenceBouteille,
        budgetNegociation: e.budgetNegociation,
        quantite: e.quantiteCibleT ?? e.quantiteEstimee,
      ),
    );
    if (confirme != true) return;
    if (!mounted) return;

    // La décision part au serveur avant d'être affichée. Sans cet appel, elle
    // ne vivait qu'en mémoire : elle disparaissait au redémarrage et aucun
    // autre rôle ne la voyait.
    try {
      await _service.confirmerAchat(e.id);
    } catch (error) {
      if (!mounted) return;
      _erreur('Confirmation non enregistrée — ${e.referenceBouteille}.');
      return;
    }

    if (!mounted) return;
    setState(() => _expanded.remove(e.id));
    await _loadPropositions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kGreen,
        content: Text(
          'Décision enregistrée — ${e.referenceBouteille} confirmé.',
          style: const TextStyle(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Message d'échec — la décision n'est pas partie, il ne faut pas laisser
  /// croire le contraire.
  void _erreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB71C1C),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Refus en deux temps : la direction choisit d'abord la nature du refus,
  /// puis confirme. Un refus définitif est irréversible, un renvoi en
  /// négociation engage une contre-proposition — les deux méritent une relecture
  /// avant départ.
  Future<void> _refuser(EchantillonCeoView e) async {
    final decision = await showDialog<DecisionRefus>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefusDecisionDialog(
        referenceBouteille: e.referenceBouteille,
        nbRenegociations: e.nbRenegociations,
        quantiteActuelle: e.quantiteCibleT,
      ),
    );
    if (decision == null || !mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmerRefusDialog(
        referenceBouteille: e.referenceBouteille,
        decision: decision,
        nbRenegociations: e.nbRenegociations,
      ),
    );
    if (confirme != true || !mounted) return;

    try {
      if (decision.definitif) {
        await _service.refuserAchat(e.id, decision.raison);
      } else {
        await _service.renvoyerEnNegociation(
          e.id,
          raisonRefus: decision.raison,
          contrePrix: decision.contrePrix ?? '',
          contrePrixMax: decision.contrePrixMax,
          quantiteCibleT: decision.quantiteCibleT,
          dateLivraisonStock: decision.dateLivraison,
          dateLivraisonStockFin: decision.dateLivraisonFin,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _erreur(
        decision.definitif
            ? 'Refus non enregistré — ${e.referenceBouteille}.'
            : 'Renvoi en négociation non enregistré — ${e.referenceBouteille}.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _expanded.remove(e.id));
    await _loadPropositions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: decision.definitif
            ? const Color(0xFFB71C1C)
            : _orangeActive,
        content: Text(
          decision.definitif
              ? 'Proposition refusée — ${e.referenceBouteille}.'
              : 'Renvoyée en négociation — ${e.referenceBouteille}.',
          style: const TextStyle(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  (Color, Color) _colorsFor(EchantillonCeoView e) {
    switch (e.statut) {
      case StatutCeo.achatConfirme:
        return (kGreen, _greenTint);
      case StatutCeo.refuse:
        return (const Color(0xFFB71C1C), _redTint);
      default:
        return (_orangeActive, _orangeTint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: kBg,
      drawer: CeoDrawer(
        currentPage: CeoDestination.validation,
        onEchantillons: () => goToPage(const EchantillonsCeoPage()),
        onAnalyseOrganoleptique: () =>
            goToPage(const AnalyseOrganoleptiqueCeoPage()),
        onAnalyseLaboratoire: () => goToPage(const AnalyseLaboratoireCeoPage()),
        onValidationAchats: () => Navigator.pop(context),
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
          'Validation achats',
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
                tooltip: 'Filtrer par date',
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
              onReessayer: _loadPropositions,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: kGreen,
              child: Column(
                children: [
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
                  Container(
                    color: kBg,
                    padding: const EdgeInsets.fromLTRB(16, 9, 16, 6),
                    child: Row(
                      children: [
                        StatusFilterChip(
                          label: 'À valider',
                          isActive: _activeFilter == 'a_valider',
                          activeBg: _orangeActive.withValues(alpha: 0.12),
                          activeFg: _orangeActive,
                          onTap: () =>
                              setState(() => _activeFilter = 'a_valider'),
                        ),
                        const SizedBox(width: 8),
                        StatusFilterChip(
                          label: 'Décidées',
                          isActive: _activeFilter == 'decidees',
                          activeBg: kGreen.withValues(alpha: 0.12),
                          activeFg: kGreen,
                          onTap: () =>
                              setState(() => _activeFilter = 'decidees'),
                        ),
                        const SizedBox(width: 8),
                        StatusFilterChip(
                          label: 'Tout',
                          isActive: _activeFilter == 'tout',
                          activeBg: const Color(0xFF757575),
                          activeFg: Colors.white,
                          onTap: () => setState(() => _activeFilter = 'tout'),
                        ),
                        const Spacer(),
                        Text(
                          '${items.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                                        Icons.fact_check_outlined,
                                        size: 52,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _activeFilter == 'a_valider'
                                            ? 'Aucune proposition à valider'
                                            : _activeFilter == 'decidees'
                                            ? 'Aucune décision enregistrée'
                                            : 'Aucune proposition',
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
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final e = items[i];
                              final (accent, tint) = _colorsFor(e);
                              final isOpen = _expanded.contains(e.id);

                              return BaseSampleCard(
                                referenceBouteille: e.referenceBouteille,
                                numero: e.numero,
                                tintColor: tint,
                                accentColor: accent,
                                badge: CardBadgeRow(
                                  badges: [
                                    if (e.quantiteCibleT != null)
                                      CardBadge(
                                        label: 'Qté : ${e.quantiteCibleT}T',
                                        color: kOlive,
                                      ),
                                    // Sans plafond au nombre de tours, ce compteur est
                                    // le seul signal qu'un dossier s'enlise.
                                    if (e.nbRenegociations > 0)
                                      MarqueurRenegocie(
                                        nombre: e.nbRenegociations,
                                      ),
                                    // The price is not repeated here: it already has a
                                    // line in the proposal details just below, and the
                                    // header only needs what tells two cards apart.
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
                                  if (e.collecteurNom != null)
                                    DetailItem('Collecteur', e.collecteurNom!),
                                  DetailItem(
                                    'Enregistré le',
                                    DegDateUtils.formaterDateHeureOuTiret(
                                      e.dateAjout,
                                    ),
                                  ),
                                ],
                                bottomSection: PropositionSection(
                                  echantillon: e,
                                  accentColor: accent,
                                  isExpanded: isOpen,
                                  onToggle: () => setState(
                                    () => isOpen
                                        ? _expanded.remove(e.id)
                                        : _expanded.add(e.id),
                                  ),
                                  onConfirmer: () => _confirmer(e),
                                  onRefuser: () => _refuser(e),
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
