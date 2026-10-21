import 'package:project3/core/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tableau_de_bord/homepage_page.dart';

import '../../../core/models/echantillon.dart';
import '../../../core/models/enums.dart';
import '../../../core/utils/date_filter_utils.dart';
import '../../../core/utils/rafraichissement_periodique.dart';
import 'package:project3/core/services/gestion_echantillons_service.dart';
import 'package:project3/core/widgets/gestion_echantillons/echantillon_card.dart';
import '../../../core/widgets/empty_state.dart';
import 'widgets/dialogs/formulaire_dialog.dart';
import 'package:project3/core/widgets/search_date_filter_bar.dart';
import '../evaluation_echantillons/evaluation_echantillons_page.dart';
import '../profil/profil_page.dart';
import '../tableau_de_bord/widgets/app_drawer.dart';
import '../membres_panel/membres_panel_page.dart';
import '../sessions_degustation/sessions_degustation_page.dart';
import '../analyse_labo/analyse_laboratoire_page.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bandeau_demonstration.dart';
import '../widgets/degustateur_nav_mixin.dart';
import 'package:project3/core/services/bordereau_pdf_service.dart';
import 'package:project3/core/widgets/bouton_bordereau.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────
class GestionEchantillonsPage extends StatefulWidget {
  final GestionEchantillonsService? service;

  const GestionEchantillonsPage({super.key, this.service});

  @override
  State<GestionEchantillonsPage> createState() =>
      _GestionEchantillonsPageState();
}

class _GestionEchantillonsPageState extends State<GestionEchantillonsPage>
    with DegustateurNavMixin, RafraichissementPeriodique {
  // ───────────────────────────────────────────────────────────────────────────
  // 1. STATE
  // ───────────────────────────────────────────────────────────────────────────

  final TextEditingController _searchController = TextEditingController();
  // Every sample, not only received ones: this is the page where reception
  // is confirmed, so filtering on it would leave the list empty forever.
  late final GestionEchantillonsService _service;
  String _recherche = '';
  String? _filtreStatut;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  DateFilterType _dateType = DateFilterType.enregistrement;

  static const _dateFilterTypes = [
    DateFilterType.enregistrement,
    DateFilterType.livraisonEchantillon,
    DateFilterType.receptionPhysique,
    DateFilterType.arriveeStock,
  ];

  bool get _dateFilterActive => _dateDebut != null || _dateFin != null;

  // ───────────────────────────────────────────────────────────────────────────
  // 2. DATA
  // ───────────────────────────────────────────────────────────────────────────

  List<Echantillon> _echantillons = [];
  bool _estDemonstration = false;
  Object? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        GestionEchantillonsService(
          uniquementRecusPhysiquement: false,
          statutPersonnel: true,
        );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final resultat = await _service.fetchEchantillons();
      if (!mounted) return;
      setState(() {
        _echantillons = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreurChargement = erreur);
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final resultat = await _service.fetchEchantillons();
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _echantillons = resultat.donnees;
        _estDemonstration = resultat.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. FILTER LOGIC
  // ───────────────────────────────────────────────────────────────────────────

  List<Echantillon> get _filtres {
    final liste = _echantillons.where((e) {
      final q = _recherche.toLowerCase();
      final matchRecherche =
          _recherche.isEmpty ||
          e.referenceBouteille.toLowerCase().contains(q) ||
          e.numero.toLowerCase().contains(q) ||
          (e.fournisseurTexte?.toLowerCase().contains(q) ?? false) ||
          (e.fournisseurNom?.toLowerCase().contains(q) ?? false) ||
          (e.variete?.toLowerCase().contains(q) ?? false) ||
          e.gouvernorat.toLowerCase().contains(q) ||
          (e.delegation?.toLowerCase().contains(q) ?? false) ||
          (e.collecteurNom?.toLowerCase().contains(q) ?? false);

      final matchStatut =
          _filtreStatut == null ||
          (e.statutDegustateur ?? StatutDegustateur.nonEvaluee).libelleFiltre ==
              _filtreStatut;

      final matchDate = dateCorrespondAuFiltre(
        dateGestionEchantillon(e, _dateType),
        debut: _dateDebut,
        fin: _dateFin,
      );

      return matchRecherche && matchStatut && matchDate;
    }).toList();

    return DegDateUtils.plusRecentsDabord(liste, (e) => e.dateAjout);
  }

  int get _prochainNumero => _echantillons.length + 1;
  bool _peutSupprimer(Echantillon e) =>
      e.canDelete && e.collecteurId.trim().isEmpty;

  // ───────────────────────────────────────────────────────────────────────────
  // 6. ACTIONS
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _onModifier(List<Echantillon> modifies) async {
    try {
      final updated = await _service.updateEchantillon(modifies.single);
      if (!mounted) return;
      setState(() {
        final index = _echantillons.indexWhere((e) => e.id == updated.id);
        if (index != -1) _echantillons[index] = updated;
      });
      _showSuccess('Échantillon modifié avec succès');
    } catch (error) {
      await _loadData();
      if (mounted) _showError('Modification impossible : $error');
      rethrow;
    }
  }

  Future<void> _onAjouter(List<Echantillon> nouveaux) async {
    try {
      final created = <Echantillon>[];
      for (final e in nouveaux) {
        created.add(await _service.createEchantillon(e));
      }
      if (!mounted) return;
      setState(() {
        for (final e in created) {
          _echantillons.insert(0, e);
        }
      });
      final label = created.length == 1
          ? '"${created.first.referenceBouteille}" ajouté'
          : '${created.length} échantillons ajoutés';
      _showSuccess(label);
    } catch (error) {
      if (mounted) _showError('Ajout impossible : $error');
      rethrow;
    }
  }

  void _onSupprimer(Echantillon e) {
    if (_estDemonstration) {
      _showError(
        'Suppression indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.',
      );
      return;
    }
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
                setState(
                  () => _echantillons.removeWhere((item) => item.id == e.id),
                );
                _showSuccess('"${e.referenceBouteille}" supprimé');
              } catch (error) {
                if (mounted) _showError('Suppression impossible : $error');
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

  Future<bool> _onToggleRecu(Echantillon e) async {
    if (_estDemonstration) {
      _showError(
        'Action indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.',
      );
      return false;
    }
    try {
      final nouvelleValeur = !e.recuPhysiquement;
      await _service.toggleRecuPhysiquement(e.id, nouvelleValeur);
      if (!mounted) return false;
      setState(() => e.recuPhysiquement = nouvelleValeur);
      return true;
    } catch (error) {
      if (mounted) {
        _showError(
          e.recuPhysiquement
              ? 'Annulation impossible : $error'
              : 'Confirmation impossible : $error',
        );
      }
      return false;
    }
  }

  void _ouvrirModification(Echantillon e) {
    if (_estDemonstration) {
      _showError(
        'Modification indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.',
      );
      return;
    }
    showFormulaireDialog(
      context,
      echantillon: e,
      prochainNumero: _prochainNumero,
      onSaveMultiple: _onModifier,
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

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

  // ───────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. BUILD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = _filtres;

    return Scaffold(
      backgroundColor: kBg,

      // ── DRAWER ─────────────────────────────────────────────────────────────
      drawer: AppDrawer(currentPage: DegustateurDestination.gestion),

      // ── APPBAR ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,

        title: Text(
          'Gestion des échantillons',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),

        iconTheme: const IconThemeData(color: kDark),

        actions: [
          BoutonBordereau(
            lignes: () => _echantillons
                .map(LigneBordereau.depuisEchantillon)
                .whereType<LigneBordereau>()
                .toList(),
          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_estDemonstration) {
            _showError(
              'Ajout indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.',
            );
            return;
          }
          showFormulaireDialog(
            context,
            prochainNumero: _prochainNumero,
            onSaveMultiple: _onAjouter,
          );
        },
        backgroundColor: const Color.fromARGB(255, 197, 206, 201),
        elevation: 2,
        icon: const Icon(Icons.add, color: kDark),
        label: const Text(
          'Ajouter',
          style: TextStyle(color: kDark, fontWeight: FontWeight.w700),
        ),
      ),

      body: VueResultatService(
        estDemonstration: _estDemonstration,
        erreur: _erreurChargement,
        onReessayer: _loadData,
        onRefresh: _loadData,
        couleurRafraichissement: kGreen,
        child: Column(
          children: [
            // ── UNIFIED HEADER ZONE ─────────────────────────────────────────
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
                      hintText: 'Réf · fournisseur · gouvernorat · collecteur…',
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

                  // ── Statut filter chips ─────────────────────────────────
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
                          selected: _filtreStatut == null,
                          onTap: () => setState(() => _filtreStatut = null),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Non évaluée',
                          activeColor: const Color(0xFF3A6EA5),
                          inactiveColor: const Color(0xFFE8F1FB),
                          inactiveTextColor: const Color(0xFF3A6EA5),
                          selected: _filtreStatut == 'Non évaluée',
                          onTap: () =>
                              setState(() => _filtreStatut = 'Non évaluée'),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Évaluation en cours',
                          activeColor: const Color(0xFFD07B2F),
                          inactiveColor: const Color(0xFFFEF3E8),
                          inactiveTextColor: const Color(0xFFD07B2F),
                          selected: _filtreStatut == 'Évaluation en cours',
                          onTap: () => setState(
                            () => _filtreStatut = 'Évaluation en cours',
                          ),
                        ),
                        const SizedBox(width: 7),
                        StatutChip(
                          label: 'Évaluation soumise',
                          activeColor: const Color(0xFF38835A),
                          inactiveColor: const Color(0xFFE6F4ED),
                          inactiveTextColor: const Color(0xFF38835A),
                          selected: _filtreStatut == 'Évaluation soumise',
                          onTap: () => setState(
                            () => _filtreStatut = 'Évaluation soumise',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Thin separator shadow
            Container(height: 1, color: Colors.black.withValues(alpha: 0.06)),

            // ── FLAT LIST ─────────────────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: EmptyState(systemeNeuf: _echantillons.isEmpty),
                        ),
                      ],
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final e = items[i];
                          return EchantillonCard(
                            echantillon: e,
                            onModifier: e.modifiable
                                ? () => _ouvrirModification(e)
                                : null,
                            onSupprimer: _peutSupprimer(e)
                                ? () => _onSupprimer(e)
                                : null,
                            onToggleRecu: () => _onToggleRecu(e),
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
