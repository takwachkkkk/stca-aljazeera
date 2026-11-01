import 'package:project3/core/logout_navigation.dart';
import 'package:flutter/material.dart';
import 'package:project3/core/theme/app_colors.dart';
import 'package:project3/core/services/resultat_service.dart';
import 'package:project3/core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/ceo_drawer.dart';
import '../profil_ceo_page.dart';
import '../../../main.dart';
import '../echantillons/echantillons_ceo_page.dart';
import '../analyse_organoleptique/analyse_organoleptique_ceo_page.dart';
import '../analyse_laboratoire/analyse_laboratoire_ceo_page.dart';
import '../achats_confirmes/achats_confirmes_ceo_page.dart';
import '../utilisateurs/utilisateurs_ceo_page.dart';
import '../notifications/models/notification_ceo.dart';
import '../notifications/services/notification_ceo_service.dart';
import '../notifications/notifications_ceo_page.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../../core/widgets/bandeau_demonstration.dart';
import 'models/dashboard_models.dart';
import 'services/dashboard_ceo_service.dart';
import 'widgets/investissement_card.dart';
import 'widgets/urgent_panel.dart';
import 'widgets/collector_section.dart';
import 'widgets/sales_evolution_card.dart';
import 'widgets/classification_card.dart';
import 'widgets/supplier_frequency_card.dart';
import 'widgets/stock_donut_card.dart';
import '../../core/widgets/repartition_card.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _pageBg = Color(0xFFF2F4F2);
const Color _white = Color(0xFFFFFFFF);
const Color _dark = Color(0xFF1A2E1F);
const Color _green = Color(0xFF38835A);

/// Les cartes qui ont leur propre filtre de dates.
enum _CarteDatee {
  achats,
  collecteurs,
  evolution,
  classification,
  fournisseurs,
}

/// Une réponse du serveur pour chaque carte, plus les chiffres sans période.
class _DonneesDashboard {
  final Resultat<DashboardCeoSnapshot> general;
  final Map<_CarteDatee, CardDateRange> periodes;
  final Map<CardDateRange, Resultat<DashboardCeoSnapshot>> parPeriode;

  const _DonneesDashboard(this.general, this.periodes, this.parPeriode);

  bool get estDemonstration =>
      general.estDemonstration ||
      parPeriode.values.any((resultat) => resultat.estDemonstration);
}

// ─────────────────────────────────────────────────────────────────────────────
class HomePageCeo extends StatefulWidget {
  const HomePageCeo({super.key});
  @override
  State<HomePageCeo> createState() => _HomePageCeoState();
}

class _HomePageCeoState extends State<HomePageCeo>
    with TickerProviderStateMixin, RafraichissementPeriodique {
  // ── Animations ──────────────────────────────────────────────────────────────
  late AnimationController _ctrl;
  late List<Animation<double>> _anims;

  // ── Per-card date ranges ───────────────────────────────────────────────────
  final Map<_CarteDatee, CardDateRange> _periodes = {
    for (final carte in _CarteDatee.values) carte: _periodeParDefaut(),
  };
  final Map<_CarteDatee, DashboardCeoSnapshot> _donneesCartes = {};
  final Set<_CarteDatee> _cartesEnChargement = {};

  /// Les douze derniers mois : assez large pour couvrir une campagne entière.
  static CardDateRange _periodeParDefaut() {
    final aujourdhui = DateTime.now();
    return CardDateRange(
      DateTime(aujourdhui.year - 1, aujourdhui.month, 1),
      DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day),
    );
  }

  // ── Collector metric: 0=Valeur 1=Échantillons 2=Approbation ───────────────
  int _collectorMetric = 0;

  // ── Notifications ──────────────────────────────────────────────────────────
  final _notifService = NotificationCeoService();
  final _dashboardService = DashboardCeoService();
  DashboardCeoSnapshot _dashboard = DashboardCeoSnapshot.mock();
  int _unreadCount = 0;
  bool _chargementDashboard = true;
  bool _demoDashboard = false;
  bool _demoNotifications = false;
  Object? _erreurChargement;

  bool get _estDemonstration => _demoDashboard || _demoNotifications;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anims = List.generate(
      12,
      (i) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          i * 0.06,
          (i * 0.06 + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    _ctrl.forward();
    _loadUnreadCount();
    _loadDashboard();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final resultat = await _notifService.fetchUnreadCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = resultat.donnees;
        _demoNotifications = resultat.estDemonstration;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  Future<void> _loadDashboard() async {
    if (mounted) setState(() => _chargementDashboard = true);
    try {
      final donnees = await _chargerDonnees();
      if (!mounted) return;
      setState(() {
        _appliquerDonnees(donnees);
        _erreurChargement = null;
        _chargementDashboard = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = erreur;
        _chargementDashboard = false;
      });
    }
  }

  /// Demande chaque période une seule fois : tant que les cartes partagent la
  /// même, un seul appel suffit.
  Future<_DonneesDashboard> _chargerDonnees() async {
    final periodes = Map.of(_periodes);
    final general = _dashboardService.fetchDashboard();
    final distinctes = periodes.values.toSet().toList();
    final resultats = await Future.wait([
      general,
      for (final periode in distinctes)
        _dashboardService.fetchDashboard(
          dateDebut: periode.from,
          dateFin: periode.to,
        ),
    ]);
    return _DonneesDashboard(
      resultats.first,
      periodes,
      Map.fromIterables(distinctes, resultats.skip(1)),
    );
  }

  /// À appeler dans un setState. Une carte dont la période a changé pendant le
  /// chargement garde sa réponse à elle, pas celle de l'ancienne période.
  void _appliquerDonnees(_DonneesDashboard donnees) {
    _dashboard = donnees.general.donnees;
    _demoDashboard = donnees.estDemonstration;
    for (final carte in _CarteDatee.values) {
      final periode = donnees.periodes[carte]!;
      if (periode == _periodes[carte]) {
        _donneesCartes[carte] = donnees.parPeriode[periode]!.donnees;
      }
    }
  }

  DashboardCeoSnapshot _donnees(_CarteDatee carte) =>
      _donneesCartes[carte] ?? _dashboard;

  void _reessayer() {
    _loadUnreadCount();
    _loadDashboard();
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultats = await Future.wait([
        _notifService.fetchUnreadCount(),
        _chargerDonnees(),
      ]);
      final notifications = resultats[0] as Resultat<int>;
      final donnees = resultats[1] as _DonneesDashboard;
      if (!mounted) return;
      final notificationsDemo = notifications.estDemonstration;
      if ((notificationsDemo && !_demoNotifications) ||
          (donnees.estDemonstration && !_demoDashboard)) {
        return;
      }
      setState(() {
        _unreadCount = notifications.donnees;
        _demoNotifications = notificationsDemo;
        _appliquerDonnees(donnees);
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _goTo(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsCeoPage(
          service: _notifService,
          onNavigate: _handleNotifNavigation,
        ),
      ),
    ).then((_) => _loadUnreadCount());
  }

  void _handleNotifNavigation(NotificationCeo n) {
    // Un achat non conclu se rouvre depuis l'analyse organoleptique, là où la
    // direction approuve les échantillons.
    if (n.type == 'ACHAT_NON_CONCLU') {
      _goTo(const AnalyseOrganoleptiqueCeoPage());
      return;
    }
    switch (n.section) {
      case 'EVALUATIONS':
        _goTo(const AnalyseOrganoleptiqueCeoPage());
        break;
      case 'ANALYSES':
        _goTo(const AnalyseLaboratoireCeoPage());
        break;
      // Anciennes notifications du circuit de validation des achats, supprimé.
      case 'ACHATS_VALIDATION':
        _goTo(const AnalyseOrganoleptiqueCeoPage());
        break;
      case 'ACHATS':
        _goTo(const AchatsConfirmesCeoPage());
        break;
      default:
        _goTo(const EchantillonsCeoPage());
        break;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Wraps a widget in a staggered fade+slide animation.
  Widget _fs(int i, Widget child) => AnimatedBuilder(
    animation: _anims[i],
    builder: (_, c) => Opacity(
      opacity: _anims[i].value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - _anims[i].value)),
        child: c,
      ),
    ),
    child: child,
  );

  /// Shows the date-range bottom sheet for [carte].
  Future<void> _choisirPeriode(_CarteDatee carte) async {
    final periode = _periodes[carte]!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DateFilterSheet(
        dateDebut: periode.from,
        dateFin: periode.to,
        onApply: (debut, fin) {
          final dernierJour = fin ?? debut;
          _changerPeriode(
            carte,
            dernierJour.isBefore(debut)
                ? CardDateRange(dernierJour, debut)
                : CardDateRange(debut, dernierJour),
          );
        },
        onClear: () => _changerPeriode(carte, _periodeParDefaut()),
      ),
    );
  }

  /// Recharge seulement [carte]. Si le serveur échoue, elle revient à sa
  /// période précédente pour que le libellé reste vrai.
  Future<void> _changerPeriode(_CarteDatee carte, CardDateRange periode) async {
    final precedente = _periodes[carte]!;
    if (periode == precedente) return;
    setState(() {
      _periodes[carte] = periode;
      _cartesEnChargement.add(carte);
    });
    try {
      final resultat = await _dashboardService.fetchDashboard(
        dateDebut: periode.from,
        dateFin: periode.to,
      );
      if (!mounted || _periodes[carte] != periode) return;
      setState(() {
        _donneesCartes[carte] = resultat.donnees;
        _demoDashboard = resultat.estDemonstration;
        _cartesEnChargement.remove(carte);
      });
    } catch (_) {
      if (!mounted || _periodes[carte] != periode) return;
      setState(() {
        _periodes[carte] = precedente;
        _cartesEnChargement.remove(carte);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger cette période pour le moment.'),
        ),
      );
    }
  }

  /// Une carte s'estompe pendant que sa nouvelle période arrive.
  Widget _carteDatee(_CarteDatee carte, Widget child) => AnimatedOpacity(
    opacity: _cartesEnChargement.contains(carte) ? 0.45 : 1,
    duration: const Duration(milliseconds: 150),
    child: child,
  );

  Widget _puceDate(_CarteDatee carte) =>
      _dateChip(_periodes[carte]!, () => _choisirPeriode(carte));

  /// Small tappable date chip rendered on each dashboard card.
  Widget _dateChip(CardDateRange range, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8EAE8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 11, color: kGreen),
            const SizedBox(width: 5),
            Text(
              range.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: _green,
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      drawer: CeoDrawer(
        currentPage: CeoDestination.accueil,
        onEchantillons: () => _goTo(const EchantillonsCeoPage()),
        onAnalyseOrganoleptique: () =>
            _goTo(const AnalyseOrganoleptiqueCeoPage()),
        onAnalyseLaboratoire: () => _goTo(const AnalyseLaboratoireCeoPage()),
        onAchatsConfirmes: () => _goTo(const AchatsConfirmesCeoPage()),
        onTableauDeBord: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePageCeo()),
          (route) => false,
        ),
        onProfil: () => _goTo(const ProfilceoPage()),
        onutilisiateurs: () => _goTo(const UtilisateursCeoPage()),
        onMessagerie: () => _goTo(const ConversationsPage()),
        onDeconnexion: () {
          Navigator.pop(context);
          logoutAndShowLogin(context);
        },
      ),
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        toolbarHeight: 65,
        title: Text(
          'Tableau de Bord',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: kDark),
                onPressed: _openNotifications,
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
          const SizedBox(width: 4),
        ],
      ),
      body: _chargementDashboard
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _reessayer,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: kGreen,
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.07),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 52),
                      children: [
                        _fs(
                          0,
                          _carteDatee(
                            _CarteDatee.achats,
                            InvestissementCard(
                              achats: _donnees(_CarteDatee.achats).achats,
                              submittedAnalyses: _donnees(
                                _CarteDatee.achats,
                              ).submittedAnalyses,
                              dateChip: _puceDate(_CarteDatee.achats),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_dashboard.urgentItems.isNotEmpty) ...[
                          _fs(
                            2,
                            UrgentPanel(
                              items: _dashboard.urgentItems,
                              onTap: () =>
                                  _goTo(const AnalyseOrganoleptiqueCeoPage()),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _fs(
                          3,
                          _carteDatee(
                            _CarteDatee.collecteurs,
                            CollectorSection(
                              collectors: _donnees(
                                _CarteDatee.collecteurs,
                              ).collectors,
                              selectedMetric: _collectorMetric,
                              dateRange: _periodes[_CarteDatee.collecteurs]!,
                              onMetricChanged: (m) =>
                                  setState(() => _collectorMetric = m),
                              dateChipBuilder: (_, _) =>
                                  _puceDate(_CarteDatee.collecteurs),
                              onRangeChanged: (r) =>
                                  _changerPeriode(_CarteDatee.collecteurs, r),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fs(
                          4,
                          _carteDatee(
                            _CarteDatee.evolution,
                            SalesEvolutionCard(
                              dateRange: _periodes[_CarteDatee.evolution]!,
                              points: _donnees(
                                _CarteDatee.evolution,
                              ).purchaseEvolution,
                              dateChipBuilder: (_, _) =>
                                  _puceDate(_CarteDatee.evolution),
                              onRangeChanged: (r) =>
                                  _changerPeriode(_CarteDatee.evolution, r),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fs(
                          5,
                          _carteDatee(
                            _CarteDatee.classification,
                            ClassificationCard(
                              dateRange: _periodes[_CarteDatee.classification]!,
                              values: _donnees(
                                _CarteDatee.classification,
                              ).classifications,
                              dateChipBuilder: (_, _) =>
                                  _puceDate(_CarteDatee.classification),
                              onRangeChanged: (r) => _changerPeriode(
                                _CarteDatee.classification,
                                r,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fs(
                          6,
                          _carteDatee(
                            _CarteDatee.fournisseurs,
                            SupplierFrequencyCard(
                              suppliers: _donnees(
                                _CarteDatee.fournisseurs,
                              ).suppliers,
                              dateRange: _periodes[_CarteDatee.fournisseurs]!,
                              dateChipBuilder: (_, _) =>
                                  _puceDate(_CarteDatee.fournisseurs),
                              onRangeChanged: (r) =>
                                  _changerPeriode(_CarteDatee.fournisseurs, r),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Où et chez qui l'entreprise achète : mêmes cartes
                        // que le chef.
                        RepartitionCard.gouvernorats(role: 'ceo'),
                        const SizedBox(height: 12),
                        RepartitionCard.fournisseurs(role: 'ceo'),
                        const SizedBox(height: 12),
                        _fs(
                          7,
                          StockDonutCard(
                            transitLots: _dashboard.stockTransit,
                            receivedLots: _dashboard.stockReceived,
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
}
