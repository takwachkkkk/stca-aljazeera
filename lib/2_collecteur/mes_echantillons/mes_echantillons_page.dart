// ═════════════════════════════════════════════════════════════════════════════
// FILE : collecteur/pages/mes_echantillons/mes_echantillons_page.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:project3/core/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';
import 'models/echantillon_collecteur.dart';
import 'services/echantillon_collecteur_service.dart';
import 'widgets/card/echantillon_collecteur_card.dart' show EchantillonComCard;

import 'widgets/dialogs/formulaire_dialog.dart';
import 'widgets/dialogs/date_livraison_section.dart'
    show DateLivraisonSection, ModePlanificationUI;
import 'widgets/dialogs/confirmer_achat_dialog.dart'
    show showConfirmerAchatDialog;
import 'package:project3/core/widgets/search_date_filter_bar.dart'
    show DateFilterSheet, DateFilterType;
import '../widgets/collecteur_drawer.dart';
import '../widgets/col_colors.dart';
import '../widgets/nav_mixin.dart';
import '../notifications/notifications_collecteur_page.dart';
import '../notifications/services/notification_collecteur_service.dart';
import '../../../main.dart';
import '../profilcom.dart';
import '../carte_geo/services/geo_service.dart';
import '../../core/widgets/bandeau_demonstration.dart';
import '../../core/utils/date_filter_utils.dart';
import '../../core/utils/rafraichissement_periodique.dart';
import '../../core/widgets/saisie_protegee.dart';
import '../../core/widgets/empty_state.dart';
import 'package:project3/core/services/bordereau_pdf_service.dart';
import 'package:project3/core/widgets/bouton_bordereau.dart';

class MesEchantillonsPage extends StatefulWidget {
  const MesEchantillonsPage({
    super.key,
    this.referenceInitiale,
    this.service,
    this.notificationService,
  });

  final String? referenceInitiale;
  final EchantillonCollecteurService? service;
  final NotificationCollecteurService? notificationService;

  @override
  State<MesEchantillonsPage> createState() => _MesEchantillonsPageState();
}

class _MesEchantillonsPageState extends State<MesEchantillonsPage>
    with CollecteurNavMixin, RafraichissementPeriodique {
  late final EchantillonCollecteurService _service;
  late final NotificationCollecteurService _notifService;
  final TextEditingController _searchCtrl = TextEditingController();

  List<EchantillonCollecteur> _echantillons = [];
  bool _loading = true;
  bool _demoEchantillons = false;
  bool _demoNotifications = false;
  Object? _erreurChargement;
  String _recherche = '';
  StatutCollecteur? _filtreStatut;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateFilterType = DateFilterType.enregistrement;
  String? _selectionEchantillonId;
  int _unreadNotifCount = 0;

  bool get _estDemonstration => _demoEchantillons || _demoNotifications;

  bool get _dateFilterActive => _dateDebut != null || _dateFin != null;
  bool get _anyFilter =>
      _dateFilterActive ||
      _recherche.isNotEmpty ||
      _filtreStatut != null ||
      _selectionEchantillonId != null;

  // Next reference number derived from loaded data — no magic constant needed
  int get _prochainNumero => _echantillons.length + 1;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EchantillonCollecteurService();
    _notifService =
        widget.notificationService ?? NotificationCollecteurService();
    final referenceInitiale = widget.referenceInitiale?.trim();
    if (referenceInitiale != null && referenceInitiale.isNotEmpty) {
      _recherche = referenceInitiale;
      _searchCtrl.text = referenceInitiale;
    }
    _loadEchantillons();
    _loadUnreadCount();
  }

  Future<void> _loadEchantillons() async {
    if (mounted) setState(() => _loading = true);
    try {
      final resultat = await _service.fetchEchantillons();
      if (!mounted) return;
      setState(() {
        _echantillons = resultat.donnees;
        _demoEchantillons = resultat.estDemonstration;
        _erreurChargement = null;
        _loading = false;
      });
      _rebuildMap();
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = erreur;
        _loading = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final resultat = await _notifService.fetchUnreadCount();
      if (!mounted) return;
      setState(() {
        _unreadNotifCount = resultat.donnees;
        _demoNotifications = resultat.estDemonstration;
      });
    } catch (_) {
      if (mounted) setState(() => _demoNotifications = false);
    }
  }

  Future<void> _reessayer() async {
    await Future.wait([_loadEchantillons(), _loadUnreadCount()]);
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultats = await Future.wait([
        _service.fetchEchantillons(),
        _notifService.fetchUnreadCount(),
      ]);
      final echantillons = resultats[0];
      final notifications = resultats[1];
      if (!mounted) return;
      if ((echantillons.estDemonstration && !_demoEchantillons) ||
          (notifications.estDemonstration && !_demoNotifications)) {
        return;
      }
      setState(() {
        _echantillons = echantillons.donnees as List<EchantillonCollecteur>;
        _unreadNotifCount = notifications.donnees as int;
        _demoEchantillons = echantillons.estDemonstration;
        _demoNotifications = notifications.estDemonstration;
        _erreurChargement = null;
      });
      _rebuildMap();
    } catch (_) {}
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsCollecteurPage(
          service: _notifService,
          onNavigate: (notification) {
            final targetId = notification.echantillonId;
            if (targetId == null) return false;
            final exists = _echantillons.any((item) => item.id == targetId);
            if (!exists) return false;
            setState(() {
              _selectionEchantillonId = targetId;
              _recherche = '';
              _searchCtrl.clear();
              _filtreStatut = null;
              _dateDebut = null;
              _dateFin = null;
            });
            return true;
          },
        ),
      ),
    );
    _loadUnreadCount();
  }

  void _rebuildMap() {
    GeoService.instance.rebuildFromEchantillons(
      _echantillons
          .map((e) => (gouvernorat: e.gouvernorat, delegation: e.delegation))
          .toList(),
    );
  }

  List<EchantillonCollecteur> get _filtres {
    final selectionId = _selectionEchantillonId;
    if (selectionId != null) {
      return _echantillons.where((e) => e.id == selectionId).toList();
    }
    return DegDateUtils.plusRecentsDabord(_echantillons.where((e) {
      final q = _recherche.toLowerCase();
      final matchRecherche =
          _recherche.isEmpty ||
          e.id.toLowerCase().contains(q) ||
          e.numero.toLowerCase().contains(q) ||
          e.referenceBouteille.toLowerCase().contains(q) ||
          e.fournisseurTexte.toLowerCase().contains(q) ||
          (e.fournisseurNom?.toLowerCase().contains(q) ?? false) ||
          e.gouvernorat.toLowerCase().contains(q) ||
          (e.variete?.toLowerCase().contains(q) ?? false);
      final matchStatut = _filtreStatut == null || e.statut == _filtreStatut;
      DateTime? rawDate;
      switch (_dateFilterType) {
        case DateFilterType.enregistrement:
          rawDate = e.dateAjout;
        case DateFilterType.livraisonEchantillon:
          rawDate = e.dateArriveeEchantillon;
        case DateFilterType.receptionPhysique:
          rawDate = e.dateReceptionEchantillon;
        case DateFilterType.arriveeStock:
          rawDate = e.livraison?.dateExacte;
      }
      final matchDate = dateCorrespondAuFiltre(
        rawDate,
        debut: _dateDebut,
        fin: _dateFin,
      );
      return matchRecherche && matchStatut && matchDate;
    }), (e) => e.dateAjout.toIso8601String());
  }

  void _onModifier(EchantillonCollecteur e) {
    showFormulaireDialog(
      context,
      echantillon: e,
      prochainNumero: _prochainNumero,
      onSaveMultiple: (_, {photos}) async {
        final photo = photos?.whereType<SamplePhoto>().firstOrNull;
        await _saveEchantillon(
          e,
          successMessage: '"${e.referenceBouteille}" modifié',
          rethrowError: true,
          photo: photo,
        );
        _rebuildMap();
      },
    );
  }

  void _onSupprimer(EchantillonCollecteur e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'échantillon'),
        content: Text(
          'Voulez-vous supprimer "${e.referenceBouteille}" (${e.numero}) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.deleteEchantillon(e.id);
                if (!mounted) return;
                setState(() => _echantillons.remove(e));
                _rebuildMap();
                _showSuccess('"${e.referenceBouteille}" supprime');
              } catch (error) {
                if (mounted) _showError(_service.messageFor(error));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _onConfirmerAchat(EchantillonCollecteur e) {
    showConfirmerAchatDialog(
      context: context,
      echantillon: e,
      onConfirm:
          (prix, camion, livraison, numCiterne, remarqueCollecteur) async {
            try {
              final saved = await _service.confirmerAchat(
                e.id,
                prixFinal: prix,
                camionLivraison: camion,
                remarqueCollecteur: remarqueCollecteur,
              );
              if (!mounted) return;
              setState(() {
                final index = _echantillons.indexWhere(
                  (item) => item.id == e.id,
                );
                if (livraison != null) saved.livraison = livraison;
                if (numCiterne != null) saved.numCiterne = numCiterne;
                if (index != -1) _echantillons[index] = saved;
              });
              _showPropositionEnvoyeeDialog(saved.referenceBouteille);
            } catch (error) {
              if (mounted) _showError(_service.messageFor(error));
            }
          },
    );
  }

  void _showPropositionEnvoyeeDialog(String reference) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFE9F4EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_outlined, color: colGreen, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Proposition envoyée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Votre proposition pour "$reference" a été transmise à la direction. '
              'L\'achat sera finalisé après validation par le CEO.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B8E7A),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: colGreen),
            child: const Text(
              'Compris',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _onScheduleArrivee(EchantillonCollecteur e) {
    bool active = e.dateArriveeEchantillon != null;
    ModePlanificationUI mode = ModePlanificationUI.dateExacte;
    DateTime? dateExacte;
    DateTime? periodeDebut;
    DateTime? periodeFin;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => SaisieProtegee(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE9F4EE),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_outlined, color: colDark, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Planifier l\'arrivée de l\'échantillon',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Arrivée de la bouteille',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colDark,
                                ),
                              ),
                              Switch(
                                value: active,
                                onChanged: (_) =>
                                    setDialogState(() => active = !active),
                                activeThumbColor: colGreen,
                              ),
                            ],
                          ),
                          if (active) ...[
                            const SizedBox(height: 8),
                            DateLivraisonSection(
                              mode: mode,
                              onModeChanged: (m) =>
                                  setDialogState(() => mode = m),
                              dateExacte: dateExacte,
                              periodeDebut: periodeDebut,
                              periodeFin: periodeFin,
                              onDateExacteChanged: (dt) =>
                                  setDialogState(() => dateExacte = dt),
                              onPeriodeDebutChanged: (dt) =>
                                  setDialogState(() => periodeDebut = dt),
                              onPeriodeFinChanged: (dt) =>
                                  setDialogState(() => periodeFin = dt),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F6EF),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (!active) {
                                setState(() => e.dateArriveeEchantillon = null);
                                _saveEchantillon(e);
                                return;
                              }
                              final dt = mode == ModePlanificationUI.dateExacte
                                  ? dateExacte
                                  : periodeDebut;
                              if (dt == null) return;
                              setState(() => e.dateArriveeEchantillon = dt);
                              _saveEchantillon(
                                e,
                                successMessage:
                                    'Arrivee planifiee pour "${e.referenceBouteille}"',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                197,
                                206,
                                201,
                              ),
                              foregroundColor: colDark,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Enregistrer',
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
          ),
        ),
      ),
    );
  }

  void _onPlanifierLivraison(EchantillonCollecteur e) {
    showConfirmerAchatDialog(
      context: context,
      echantillon: e,
      onConfirm: (prix, camion, livraison, numCiterne, remarqueCollecteur) {
        setState(() {
          e.prixFinal = prix;
          if (camion != null) e.camionLivraison = camion;
          if (livraison != null) e.livraison = livraison;
          if (numCiterne != null) e.numCiterne = numCiterne;
          e.remarqueCollecteur = remarqueCollecteur;
        });
        _saveEchantillon(
          e,
          successMessage:
              'Livraison mise a jour pour "${e.referenceBouteille}"',
        );
      },
    );
  }

  Future<void> _saveEchantillon(
    EchantillonCollecteur e, {
    String? successMessage,
    bool rethrowError = false,
    SamplePhoto? photo,
  }) async {
    try {
      // A new photo picked while editing is sent with the edit.
      final saved = photo == null
          ? await _service.updateEchantillon(e)
          : await _service.updateEchantillonWithImage(
              e,
              imageBytes: photo.bytes,
              filename: photo.filename,
            );
      if (!mounted) return;
      setState(() {
        final index = _echantillons.indexWhere((item) => item.id == e.id);
        if (index != -1) _echantillons[index] = saved;
      });
      _rebuildMap();
      if (successMessage != null) _showSuccess(successMessage);
    } catch (error) {
      if (mounted) _showError(_service.messageFor(error));
      if (rethrowError) rethrow;
    }
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: colGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
    ),
  );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
    ),
  );

  void _showDateFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateFilterSheet(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        onApply: (debut, fin) => setState(() {
          _selectionEchantillonId = null;
          _dateDebut = debut;
          _dateFin = fin;
        }),
        onClear: () => setState(() {
          _selectionEchantillonId = null;
          _dateDebut = null;
          _dateFin = null;
        }),
        availableTypes: const [
          DateFilterType.enregistrement,
          DateFilterType.livraisonEchantillon,
          DateFilterType.receptionPhysique,
          DateFilterType.arriveeStock,
        ],
        initialType: _dateFilterType,
        onApplyTyped: (debut, fin, type) => setState(() {
          _selectionEchantillonId = null;
          _dateDebut = debut;
          _dateFin = fin;
          _dateFilterType = type;
        }),
      ),
    );
  }

  String get _descriptionFiltreStatut {
    if (_selectionEchantillonId != null) {
      return 'Echantillon ouvert depuis une notification.';
    }
    switch (_filtreStatut) {
      case null:
        return 'Tous vos échantillons, quel que soit leur état.';
      case StatutCollecteur.receptionne:
        return 'Échantillons enregistrés, en attente de négociation.';
      case StatutCollecteur.enNegociation:
        return 'Échantillons en cours de négociation avec le fournisseur.';
      case StatutCollecteur.achatConfirme:
        return "Échantillons dont l'achat est confirmé.";
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtres;

    return Scaffold(
      backgroundColor: colBg,
      drawer: CollecteurDrawer(currentPage: CollecteurDestination.echantillons),
      appBar: AppBar(
        backgroundColor: colHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Mes échantillons',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colDark,
          ),
        ),
        iconTheme: const IconThemeData(color: colDark),
        actions: [
          BoutonBordereau(
            lignes: () => [
              for (final e in _echantillons)
                LigneBordereau(
                  dateAjout: e.dateAjout,
                  fournisseur: (e.fournisseurNom?.trim().isNotEmpty ?? false)
                      ? e.fournisseurNom!.trim()
                      : e.fournisseurTexte,
                  gouvernorat: e.gouvernorat,
                  delegation: e.delegation,
                  referenceBouteille: e.referenceBouteille,
                  numCiterne: e.numCiterne,
                  quantiteEstimee: e.quantiteEstimee,
                  remarque: e.remarqueCollecteur,
                  collecteur: e.collecteurNom,
                ),
            ],
          ),
          // ── Bell icon with unread badge ──────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: Color(0xFF6B8E7A),
                ),
                onPressed: _openNotifications,
                tooltip: 'Notifications',
              ),
              if (_unreadNotifCount > 0)
                Positioned(
                  right: 8,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // ── Date filter ──────────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _dateFilterActive ? colGreen : const Color(0xFF6B8E7A),
                ),
                onPressed: _showDateFilter,
                tooltip: 'Filtrer par date',
              ),
              if (_dateFilterActive)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: colGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showFormulaireDialog(
            context,
            prochainNumero: _prochainNumero,
            onSaveMultiple: (nouveaux, {photos}) async {
              try {
                final created = <EchantillonCollecteur>[];
                for (var i = 0; i < nouveaux.length; i++) {
                  final s = nouveaux[i];
                  final photo = photos != null && i < photos.length
                      ? photos[i]
                      : null;
                  // Attach each label photo to the matching bottle sample.
                  if (photo != null) {
                    created.add(
                      await _service.createEchantillonWithImage(
                        s,
                        imageBytes: photo.bytes,
                        filename: photo.filename,
                      ),
                    );
                  } else {
                    created.add(await _service.createEchantillon(s));
                  }
                }
                if (!mounted) return;
                setState(() {
                  for (final s in created) {
                    _echantillons.insert(0, s);
                  }
                });
                _rebuildMap();
                final label = created.length == 1
                    ? '"${created.first.referenceBouteille}" ajoute'
                    : '${created.length} echantillons ajoutes';
                _showSuccess(label);
              } catch (error) {
                if (mounted) _showError(_service.messageFor(error));
                rethrow;
              }
            },
          );
        },
        backgroundColor: const Color.fromARGB(255, 197, 206, 201),
        elevation: 2,
        icon: const Icon(Icons.add_a_photo_outlined, color: colDark),
        label: const Text(
          'Ajouter',
          style: TextStyle(color: colDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: colGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _reessayer,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: colGreen,
              child: Column(
                children: [
                  // ── Header zone ──────────────────────────────────────────────────
                  Container(
                    color: colHeaderBg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() {
                            _selectionEchantillonId = null;
                            _recherche = v.trim();
                          }),
                          style: const TextStyle(fontSize: 14, color: colDark),
                          decoration: InputDecoration(
                            hintText: 'Réf., fournisseur, gouvernorat, variété',
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
                                      _selectionEchantillonId = null;
                                      _recherche = '';
                                      _searchCtrl.clear();
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
                                color: colGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 11),
                        // Filter chips
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _StatutChip(
                                label: 'Tous',
                                activeBg: const Color(0xFF757575),
                                activeFg: Colors.white,
                                inactiveBg: const Color(0xFFF0F0F0),
                                inactiveFg: const Color(0xFF9E9E9E),
                                selected: _filtreStatut == null,
                                onTap: () => setState(() {
                                  _selectionEchantillonId = null;
                                  _filtreStatut = null;
                                }),
                              ),
                              const SizedBox(width: 7),
                              _StatutChip(
                                label: 'Enregistré',
                                activeBg: const Color(
                                  0xFF3A6EA5,
                                ).withValues(alpha: 0.12),
                                activeFg: const Color(0xFF3A6EA5),
                                inactiveBg: const Color(0xFFF0F0F0),
                                inactiveFg: const Color(0xFF9E9E9E),
                                selected:
                                    _filtreStatut ==
                                    StatutCollecteur.receptionne,
                                onTap: () => setState(() {
                                  _selectionEchantillonId = null;
                                  _filtreStatut = StatutCollecteur.receptionne;
                                }),
                              ),
                              const SizedBox(width: 7),
                              _StatutChip(
                                label: 'Négociation',
                                activeBg: const Color(
                                  0xFFD07B2F,
                                ).withValues(alpha: 0.12),
                                activeFg: const Color(0xFFD07B2F),
                                inactiveBg: const Color(0xFFF0F0F0),
                                inactiveFg: const Color(0xFF9E9E9E),
                                selected:
                                    _filtreStatut ==
                                    StatutCollecteur.enNegociation,
                                onTap: () => setState(() {
                                  _selectionEchantillonId = null;
                                  _filtreStatut =
                                      StatutCollecteur.enNegociation;
                                }),
                              ),
                              const SizedBox(width: 7),
                              _StatutChip(
                                label: 'Achat conclu',
                                activeBg: const Color(
                                  0xFF38835A,
                                ).withValues(alpha: 0.12),
                                activeFg: const Color(0xFF38835A),
                                inactiveBg: const Color(0xFFF0F0F0),
                                inactiveFg: const Color(0xFF9E9E9E),
                                selected:
                                    _filtreStatut ==
                                    StatutCollecteur.achatConfirme,
                                onTap: () => setState(() {
                                  _selectionEchantillonId = null;
                                  _filtreStatut =
                                      StatutCollecteur.achatConfirme;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),

                  // ── Stats strip ──────────────────────────────────────────────────
                  Container(
                    color: colBg,
                    padding: const EdgeInsets.fromLTRB(16, 9, 16, 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: Color.fromARGB(255, 156, 156, 156),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _descriptionFiltreStatut,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 156, 156, 156),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_dateFilterActive) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.filter_alt_outlined,
                            color: Colors.grey.shade400,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _dateFin == null ||
                                      _dateDebut!.isAtSameMomentAs(_dateFin!)
                                  ? 'Le ${fmtDate(_dateDebut!)}'
                                  : 'Du ${fmtDate(_dateDebut!)}  →  ${fmtDate(_dateFin!)}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── List ──────────────────────────────────────────────────────────
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
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
                                        Icons.inventory_2_outlined,
                                        size: 52,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _echantillons.isEmpty
                                            ? kTitreSystemeNeuf
                                            : 'Aucun échantillon trouvé',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (_echantillons.isEmpty)
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
                        : Theme(
                            data: Theme.of(context).copyWith(
                              scrollbarTheme: ScrollbarThemeData(
                                thumbColor: WidgetStateProperty.all(colGray),
                              ),
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  100,
                                ),
                                itemCount: items.length,
                                itemBuilder: (_, i) {
                                  final e = items[i];
                                  return EchantillonComCard(
                                    echantillon: e,
                                    onModifier: e.canModify
                                        ? () => _onModifier(e)
                                        : null,
                                    onSupprimer: e.canDelete
                                        ? () => _onSupprimer(e)
                                        : null,
                                    onConfirmerAchat: e.canConfirm
                                        ? () => _onConfirmerAchat(e)
                                        : null,
                                    onPlanifierLivraison: e.canPlanifier
                                        ? () => _onPlanifierLivraison(e)
                                        : null,
                                    onScheduleArrivee: e.canScheduleArrivee
                                        ? () => _onScheduleArrivee(e)
                                        : null,
                                    initiallyExpanded:
                                        e.id == _selectionEchantillonId,
                                  );
                                },
                              ),
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
class _StatutChip extends StatelessWidget {
  final String label;
  final Color activeBg;
  final Color activeFg;
  final Color inactiveBg;
  final Color inactiveFg;
  final bool selected;
  final VoidCallback onTap;

  const _StatutChip({
    required this.label,
    required this.activeBg,
    required this.activeFg,
    required this.inactiveBg,
    required this.inactiveFg,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? activeBg : inactiveBg;
    final fg = selected ? activeFg : inactiveFg;
    final borderColor = selected
        ? activeFg.withValues(alpha: activeFg == Colors.white ? 0.0 : 0.3)
        : const Color(0xFFE0E0E0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
