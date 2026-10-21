// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/analyse_organoleptique/analyse_organoleptique_ceo_page.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/widgets/bandeau_demonstration.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'models/sample_status.dart';
import '../widgets/ceo_nav_mixin.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../3_degustateur/notifications/services/notification_degustateur_service.dart';
import '../widgets/ceo_drawer.dart';
import '../utilisateurs/models/echantillon_ceo_view.dart';
import '../widgets/shared_evaluation_form_sheet.dart';
import '../echantillons/echantillons_ceo_page.dart';
import '../analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../validation_achats/validation_achats_ceo_page.dart';
import '../tableau_de_bord/tableau_de_bord.dart';
import '../profil_ceo_page.dart';
import '../../main.dart';
import '../utilisateurs/models/mock_data_patch.dart';
import '../utilisateurs/utilisateurs_ceo_page.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../widgets/sample_card_echantillon.dart';
import '../widgets/base_sample_card.dart'; // ← shared card
import 'widgets/approval_dialog.dart';
import 'widgets/refusal_dialog.dart';
import 'widgets/panel_section.dart';
import 'widgets/panel_widgets.dart';
import '../echantillons/services/echantillon_ceo_service.dart';
import '../../core/widgets/grille_details.dart';

const Color _headerBg = Color.fromARGB(255, 220, 233, 226);
const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _bg = Color.fromARGB(255, 255, 255, 255);
const Color _olive = Color(0xFF6B8143);

const Color _statusGreen = Color(0xFF38835A);
const Color _statusBlue = Color(0xFF3A6EA5);
const Color _statusOrange = Color(0xFFD07B2F);
const Color _tintGreen = Color.fromARGB(255, 212, 225, 217);
const Color _tintBlue = Color(0xFFEAF0F8);
const Color _tintOrange = Color(0xFFFAF0E6);

enum _SampleStatus { complete, partial, none }

extension _StatusStyle on _SampleStatus {
  Color get color {
    switch (this) {
      case _SampleStatus.complete:
        return _statusGreen;
      case _SampleStatus.partial:
        return _statusBlue;
      case _SampleStatus.none:
        return _statusOrange;
    }
  }

  Color get tint {
    switch (this) {
      case _SampleStatus.complete:
        return _tintGreen;
      case _SampleStatus.partial:
        return _tintBlue;
      case _SampleStatus.none:
        return _tintOrange;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class AnalyseOrganoleptiqueCeoPage extends StatefulWidget {
  const AnalyseOrganoleptiqueCeoPage({super.key});
  @override
  State<AnalyseOrganoleptiqueCeoPage> createState() =>
      _AnalyseOrganoleptiqueCeoPageState();
}

class _AnalyseOrganoleptiqueCeoPageState
    extends State<AnalyseOrganoleptiqueCeoPage>
    with CeoNavMixin, RafraichissementPeriodique {
  final Set<String> _expandedPanel = {};
  final Set<String> _urgentSent = {};

  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateType = DateFilterType.enregistrement;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final _service = EchantillonCeoService();
  List<EchantillonCeoView> _allEchantillons = [];
  bool _chargement = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _loadEchantillons();
  }

  Future<void> _loadEchantillons() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final resultat = await _service.fetchCeoViews(
        () => List.of(mockEchantillonsOrganoleptique),
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
        () => List.of(mockEchantillonsOrganoleptique),
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

  List<EchantillonCeoView> get _filtered {
    var result = _allEchantillons;
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
                e.fournisseurTexte.toLowerCase().contains(q) ||
                (e.fournisseurNom?.toLowerCase().contains(q) ?? false) ||
                e.numero.toLowerCase().contains(q) ||
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

  SampleStatus _statusOf(EchantillonCeoView e) {
    if (e.evaluations.isEmpty) return SampleStatus.none;
    if (e.tousEvalue) return SampleStatus.complete;
    return SampleStatus.partial;
  }

  Color _cardAccent(EchantillonCeoView e) {
    if (e.statut == StatutCeo.refuse) return Colors.red.shade400;
    return _statusOf(e).color;
  }

  // ── Urgent notification ────────────────────────────────────────────────────
  Future<void> _confirmSendUrgent(EchantillonCeoView e) async {
    if (_urgentSent.contains(e.id)) return;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3E8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notification_important_outlined,
                    color: Color(0xFFD07B2F),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Marquer comme urgent',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                        Text(
                          e.referenceBouteille,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E7A4B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Text(
                'Tous les dégustateurs recevront une notification urgente pour soumettre leur évaluation de ${e.referenceBouteille} en priorité.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A4A4A),
                  height: 1.5,
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6EF),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD07B2F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await NotificationDegustateurService()
                              .sendUrgentDegustation(e.id);
                          if (!mounted) return;
                          setState(() => _urgentSent.add(e.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Notification urgente envoyée à tous les dégustateurs',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: const Color(0xFFD07B2F),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(20),
                            ),
                          );
                        } catch (erreur) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Notification non envoyée : $erreur',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(20),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Notifier',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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

  // ── Decision dialogs ───────────────────────────────────────────────────────
  Future<void> _showApprouverDialog(EchantillonCeoView e) async {
    final isEdit = e.statut == StatutCeo.enNegociation;
    final isAchatConfirme = e.statut == StatutCeo.achatConfirme;

    if (isAchatConfirme) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Achat déjà confirmé'),
          content: const Text(
            'Cet échantillon a un achat confirmé. Voulez-vous vraiment modifier la décision ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApprovalDialog(
        reference: e.referenceBouteille,
        isEdit: isEdit,
        initialBudget: e.budgetNegociation,
        initialQuantite: e.quantiteCibleT,
        initialNote: e.noteInterne,
        onApprove: (budget, quantite, dateSouhaitee, note) =>
            _enregistrerNegociation(e, budget, quantite, dateSouhaitee, note),
      ),
    );
  }

  /// La négociation part au serveur avant d'être affichée. Sans cet appel elle
  /// ne vivait qu'en mémoire : elle disparaissait au redémarrage et le
  /// collecteur ne la voyait jamais.
  Future<void> _enregistrerNegociation(
    EchantillonCeoView e,
    String budget,
    String? quantite,
    String? dateSouhaitee,
    String? note,
  ) async {
    try {
      await _service.approuver(
        e.id,
        budgetNegociation: budget,
        quantiteCibleT: quantite,
        noteInterne: note,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          content: Text(
            'Négociation non enregistrée pour ${e.referenceBouteille}.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      e.statut = StatutCeo.enNegociation;
      e.budgetNegociation = budget;
      e.quantiteCibleT = quantite;
      e.dateLivraisonStockSouhaitee = dateSouhaitee;
      e.noteInterne = note;
      e.raisonRefus = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Text(
          'Négociation enregistrée pour ${e.referenceBouteille}.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showRefuserDialog(EchantillonCeoView e) async {
    final isAchatConfirme = e.statut == StatutCeo.achatConfirme;

    if (isAchatConfirme) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Achat déjà confirmé'),
          content: const Text(
            'Cet échantillon a un achat confirmé. Voulez-vous vraiment le refuser ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Refuser quand même',
                style: TextStyle(color: Colors.red.shade600),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefusalDialog(
        reference: e.referenceBouteille,
        initialRaison: e.raisonRefus,
        onRefuse: (raison) => _enregistrerRefus(e, raison),
      ),
    );
  }

  Future<void> _enregistrerRefus(EchantillonCeoView e, String? raison) async {
    try {
      await _service.refuser(e.id, raison ?? '');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refus non enregistré pour ${e.referenceBouteille}.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      e.statut = StatutCeo.refuse;
      e.raisonRefus = raison;
      e.budgetNegociation = null;
      e.noteInterne = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final echantillons = _filtered;
    return Scaffold(
      backgroundColor: kBg,
      drawer: CeoDrawer(
        currentPage: CeoDestination.organoleptique,
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
          'Analyse organoleptique',
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
                  // List
                  Expanded(
                    child: echantillons.isEmpty
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
                            itemCount: echantillons.length,
                            itemBuilder: (_, i) {
                              final e = echantillons[i];
                              final panelExp = _expandedPanel.contains(e.id);

                              return BaseSampleCard(
                                referenceBouteille: e.referenceBouteille,
                                numero: e.numero,
                                tintColor: Colors.white,
                                accentColor: _cardAccent(e),
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
                                bottomSection: PanelSection(
                                  echantillon: e,
                                  isExpanded: panelExp,
                                  onToggle: () => setState(
                                    () => panelExp
                                        ? _expandedPanel.remove(e.id)
                                        : _expandedPanel.add(e.id),
                                  ),
                                  onViewForm: (ev) => showEvaluationFormSheet(
                                    context,
                                    evaluation: ev,
                                    sampleRef: e.numero,
                                  ),
                                  onApprouver: () => _showApprouverDialog(e),
                                  onRefuser: () => _showRefuserDialog(e),
                                  isUrgent: _urgentSent.contains(e.id),
                                  onUrgent: () => _confirmSendUrgent(e),
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
