import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/classification/classification_interne.dart';
import '../../core/models/enums.dart';
import '../../core/widgets/carte_classification.dart';
import '../../core/widgets/bandeau_demonstration.dart';
import '../../core/widgets/photo_plein_ecran.dart';
import '../../core/widgets/saisie_protegee.dart';
import 'package:project3/core/services/evaluation_service.dart';
import 'package:project3/core/utils/date_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAGE — FormulaireEvaluationPage
// Formulaire de dégustation conforme aux normes COI
// StatefulWidget car : sliders changent, classification recalculée en temps réel
// ─────────────────────────────────────────────────────────────────────────────
class FormulaireEvaluationPage extends StatefulWidget {
  final String echantillonId;
  final String? numero;
  final String fournisseur;
  final String variete;
  final String origine;
  final String dateArrivee;
  final String? photoUrl;

  /// When true, all fields are locked — used to view a submitted evaluation.
  final bool readOnly;

  /// Pre-filled classification label when opened in read-only mode.
  final String? classification;

  const FormulaireEvaluationPage({
    super.key,
    required this.echantillonId,
    this.numero,
    required this.fournisseur,
    required this.variete,
    required this.origine,
    required this.dateArrivee,
    this.photoUrl,
    this.readOnly = false,
    this.classification,
  });

  @override
  State<FormulaireEvaluationPage> createState() =>
      _FormulaireEvaluationPageState();
}

class _FormulaireEvaluationPageState extends State<FormulaireEvaluationPage> {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color _headerBg = Color.fromARGB(255, 220, 233, 226);
  static const Color green = Color(0xFF38835A);
  static const Color oliveGreen = Color(0xFF6B8143);
  static const Color darkText = Color(0xFF1A2E1F);
  static const Color _bg = Color.fromARGB(255, 255, 255, 255);

  // ── Soumis → verrouille tout ──────────────────────────────────────────────
  late bool _estSoumis;
  bool _chargement = true;
  bool _estDemonstration = false;
  Object? _erreurChargement;
  final EvaluationService _service = EvaluationService();
  String? _evaluationId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _estSoumis = widget.readOnly;
    _loadExistingEvaluation();
  }

  // ── TYPE de fruité — PR-48 §5 et §8 ──────────────────────────────────────
  TypeFruite _typeFruite = TypeFruite.vert;

  // ── Classification interne PR-48 ─────────────────────────────────────────
  /// Case du §9 : le PR-48 exige un « profil harmonieux » pour les deux classes
  /// hautes mais ne le chiffre pas — c'est le dégustateur qui juge.
  bool _profilNonHarmonieux = false;

  /// Classe retenue à la main quand la grille §8 ne rend rien.
  ClasseInterne? _classeManuelle;
  String? _classeChoisieLe;

  // ─────────────────────────────────────────────────────────────────────────
  // ATTRIBUTS NÉGATIFS (défauts) — tous initialisés à 0.0
  // ─────────────────────────────────────────────────────────────────────────
  double _chome = 0.0; // Chômé / Lie de boue
  double _moisi = 0.0; // Moisi / Humide / Terreux
  double _vinaigre = 0.0; // Vinaigré / Acide-Aigre
  double _gele = 0.0; // Gelé (bois mouillé)
  double _rance = 0.0; // Rance
  double _autresDefaut = 0.0; // Autres défauts

  // ─────────────────────────────────────────────────────────────────────────
  // ATTRIBUTS POSITIFS — tous initialisés à 0.0
  // ─────────────────────────────────────────────────────────────────────────
  double _fruite = 0.0; // Fruité
  double _amer = 0.0; // Amer
  double _piquant = 0.0; // Piquant

  // ── Notes libres du dégustateur ──────────────────────────────────────────
  final TextEditingController _notesController = TextEditingController();

  // ── Autres défauts texte libre ────────────────────────────────────────────
  final TextEditingController _autresDefautNomController =
      TextEditingController();

  // ─────────────────────────────────────────────────────────────────────────
  // CALCUL — délégué à lib/core/classification/classification_interne.dart
  // La logique vivait ici en trois copies qui avaient divergé ; elle n'existe
  // plus qu'au même endroit pour tous les rôles.
  // ─────────────────────────────────────────────────────────────────────────
  double get _medianeDefauts => medianeDefauts(
    chome: _chome,
    moisi: _moisi,
    vinaigre: _vinaigre,
    gele: _gele,
    rance: _rance,
    autresDefaut: _autresDefaut,
  );

  ResultatClassification get _resultat => ResultatClassification(
    fruite: _fruite,
    typeFruite: _typeFruite,
    amertume: _amer,
    piquant: _piquant,
    mediane: _medianeDefauts,
    profilNonHarmonieux: _profilNonHarmonieux,
    classeManuelle: _classeManuelle,
  );

  Future<void> _loadExistingEvaluation() async {
    try {
      final resultat = await _service.fetchEvaluation(widget.echantillonId);
      if (!mounted) return;
      setState(() {
        final evaluation = resultat.donnees;
        if (evaluation != null) _applyEvaluation(evaluation);
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

  void _applyEvaluation(Map<String, dynamic> data) {
    _evaluationId = data['id'] as String?;
    _fruite = _numValue(data['fruite']);
    _typeFruite = TypeFruiteX.fromJson(data['type_fruite'] as String?);
    _profilNonHarmonieux = data['profil_non_harmonieux'] as bool? ?? false;
    // Seule une classe explicitement marquée manuelle est restaurée : une classe
    // automatique se recalcule depuis les valeurs, elle n'a pas à être relue.
    _classeManuelle = (data['classe_interne_manuelle'] as bool? ?? false)
        ? ClasseInterneX.fromJson(data['classe_interne'] as String?)
        : null;
    _classeChoisieLe = data['classe_interne_choisie_le'] as String?;
    _amer = _numValue(data['amertume']);
    _piquant = _numValue(data['piquant']);
    _chome = _numValue(data['chome']);
    _moisi = _numValue(data['moisi']);
    _vinaigre = _numValue(data['vinaigre']);
    _rance = _numValue(data['rance']);
    _gele = _numValue(data['gele']);
    _autresDefaut = _numValue(data['autres_defaut']);
    _autresDefautNomController.text =
        data['autres_defaut_nom']?.toString() ?? '';
    _notesController.text = data['commentaire']?.toString() ?? '';
    _estSoumis = widget.readOnly || data['statut'] == 'soumis';
  }

  double _numValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> _evaluationPayload() {
    final resultat = _resultat;
    return {
      'echantillon': widget.echantillonId,
      'statut': 'en_cours',
      'classification': resultat.coi?.toJson ?? '',
      'classe_interne': resultat.classeRetenue?.toJson ?? '',
      'classe_interne_manuelle': resultat.estManuelle,
      'classe_interne_motif': resultat.estManuelle ? _motifCourant() : '',
      'profil_non_harmonieux': _profilNonHarmonieux,
      'fruite': _fruite,
      'type_fruite': _typeFruite.toJson,
      'amertume': _amer,
      'piquant': _piquant,
      'chome': _chome,
      'moisi': _moisi,
      'vinaigre': _vinaigre,
      'rance': _rance,
      'gele': _gele,
      'autres_defaut': _autresDefaut,
      'autres_defaut_nom': _autresDefautNomController.text.trim(),
      'commentaire': _notesController.text.trim(),
    };
  }

  /// Motif « hors grille » figé en base au moment du choix manuel (§14).
  String _motifCourant() => motifHorsGrille(
    coi: _resultat.coi,
    fruite: _fruite,
    typeFruite: _typeFruite,
    amertume: _amer,
    piquant: _piquant,
    profilNonHarmonieux: _profilNonHarmonieux,
  );

  Future<Map<String, dynamic>> _saveDraft() async {
    final payload = _evaluationPayload();
    final saved = _evaluationId == null
        ? await _service.createEvaluation(payload)
        : await _service.updateEvaluation(_evaluationId!, payload);
    _evaluationId = saved['id'] as String?;
    return saved;
  }

  // ── Couleur d'un slider de défaut — échelle 0–10, seuils COI inchangés ────
  Color _sliderColor(double val) {
    if (val <= 3.0) return green;
    if (val <= 6.0) return Colors.orange.shade500;
    return Colors.red.shade500;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _autresDefautNomController.dispose();
    super.dispose();
  }

  Future<void> _quitterAvecConfirmation() async {
    final quitter = _estSoumis || await confirmerAbandonSaisie(context);
    if (quitter && mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SaisieProtegee(
      actif: !_estSoumis,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _headerBg,
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 65,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: darkText),
            onPressed: _quitterAvecConfirmation,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fiche d\'Évaluation',
                style: GoogleFonts.domine(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
              Text(
                widget.numero ?? widget.echantillonId,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            // ── Badge soumis ──
            if (_estSoumis)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Verrouillé',
                      style: TextStyle(
                        color: green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        body: _chargement
            ? const Center(child: CircularProgressIndicator(color: green))
            : VueResultatService(
                estDemonstration: _estDemonstration,
                erreur: _erreurChargement,
                onReessayer: _loadExistingEvaluation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ══════════════════════════════════════════════════════════════
                      // SECTION 1 — INFORMATIONS DE L'ÉCHANTILLON
                      // ══════════════════════════════════════════════════════════════
                      _buildSectionCard(
                        title: '📋 Informations de l\'Échantillon',
                        child: Column(
                          children: [
                            // Photo + infos côte à côte
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Photo ──
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: _headerBg.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child:
                                      widget.photoUrl != null &&
                                          widget.photoUrl!.trim().isNotEmpty
                                      ? PhotoPleinEcran.network(
                                          imageUrl: widget.photoUrl!,
                                          height: 80,
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              size: 26,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Pas de photo',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),

                                const SizedBox(width: 14),

                                // ── Infos ──
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.numero ?? widget.echantillonId,
                                        style: GoogleFonts.domine(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _infoRow(
                                        Icons.store_outlined,
                                        widget.fournisseur,
                                      ),
                                      _infoRow(
                                        Icons.eco_outlined,
                                        widget.variete,
                                      ),
                                      _infoRow(
                                        Icons.location_on_outlined,
                                        widget.origine,
                                      ),
                                      _infoRow(
                                        Icons.calendar_today_outlined,
                                        DegDateUtils.formaterAffichage(
                                          widget.dateArrivee,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ══════════════════════════════════════════════════════════════
                      // SECTION 2 — CLASSIFICATION EN TEMPS RÉEL
                      // ══════════════════════════════════════════════════════════════
                      _buildClassificationCard(),

                      const SizedBox(height: 16),

                      // ══════════════════════════════════════════════════════════════
                      // SECTION 4 — ATTRIBUTS POSITIFS
                      // ══════════════════════════════════════════════════════════════
                      _buildSectionCard(
                        title: '✅ Attributs Positifs',
                        subtitle: 'Tous les champs sont optionnels',
                        child: Column(
                          children: [
                            // ── Fruité avec toggle Vert / Mûr ──
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSlider(
                                  label: 'Fruité',
                                  description:
                                      'Sensations olfactives caractéristiques',
                                  value: _fruite,
                                  onChanged: (v) => setState(() => _fruite = v),
                                  isPositif: true,
                                ),
                                // ── Type de fruité — 3 valeurs (PR-48 §5 et §8) ──
                                // « Vert-mûr » est ce qui sépare Extra B d'Extra B−.
                                if (_fruite > 0.0) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Type de fruité :',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: oliveGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      for (final type in TypeFruite.values) ...[
                                        Expanded(child: _chipTypeFruite(type)),
                                        if (type != TypeFruite.values.last)
                                          const SizedBox(width: 6),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),

                            _buildSlider(
                              label: 'Amertume',
                              description:
                                  'Goût primaire — olives vertes ou en véraison',
                              value: _amer,
                              onChanged: (v) => setState(() => _amer = v),
                              isPositif: true,
                            ),
                            _buildSlider(
                              label: 'Piquant',
                              description:
                                  'Sensation tactile — olives en début de campagne',
                              value: _piquant,
                              onChanged: (v) => setState(() => _piquant = v),
                              isPositif: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ══════════════════════════════════════════════════════════════
                      // SECTION 3 — ATTRIBUTS NÉGATIFS (DÉFAUTS)
                      // ══════════════════════════════════════════════════════════════
                      _buildSectionCard(
                        title: '⚠️ Attributs Négatifs — Défauts',
                        subtitle: 'Tous les champs sont optionnels',
                        child: Column(
                          children: [
                            _buildSlider(
                              label: 'Chômé / Lie de boue',
                              description:
                                  'Huile d\'olives en fermentation anaérobie',
                              value: _chome,
                              onChanged: (v) => setState(() => _chome = v),
                            ),
                            _buildSlider(
                              label: 'Moisi / Humide / Terreux',
                              description:
                                  'Olives stockées en conditions humides',
                              value: _moisi,
                              onChanged: (v) => setState(() => _moisi = v),
                            ),
                            _buildSlider(
                              label: 'Vinaigré / Acide-Aigre',
                              description:
                                  'Fermentation aérobie — acide acétique',
                              value: _vinaigre,
                              onChanged: (v) => setState(() => _vinaigre = v),
                            ),
                            _buildSlider(
                              label: 'Gelé (Bois Mouillé)',
                              description: 'Olives blessées par le gel',
                              value: _gele,
                              onChanged: (v) => setState(() => _gele = v),
                            ),
                            _buildSlider(
                              label: 'Rance',
                              description: 'Processus d\'oxydation intense',
                              value: _rance,
                              onChanged: (v) => setState(() => _rance = v),
                            ),

                            // ── Autres défauts avec nom libre ──
                            const SizedBox(height: 8),
                            TextField(
                              controller: _autresDefautNomController,
                              enabled: !_estSoumis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: darkText,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Autre défaut (Métallique, Grillé, Esparto...)',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                                prefixIcon: const Icon(
                                  Icons.add_circle_outline,
                                  color: oliveGreen,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: green,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            if (_autresDefautNomController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildSlider(
                                label: 'Intensité — Autre défaut',
                                description: _autresDefautNomController.text,
                                value: _autresDefaut,
                                onChanged: (v) =>
                                    setState(() => _autresDefaut = v),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ══════════════════════════════════════════════════════════════
                      // SECTION 5 — NOTES LIBRES
                      // ══════════════════════════════════════════════════════════════
                      _buildSectionCard(
                        title: '📝 Notes du Dégustateur',
                        subtitle:
                            'Observations, remarques, impressions générales',
                        child: TextField(
                          controller: _notesController,
                          enabled: !_estSoumis,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 14, color: darkText),
                          decoration: InputDecoration(
                            hintText:
                                'Ex: Profil aromatique dominé par des notes vertes (herbe coupée, artichaut). Bonne cohérence entre fruité et piquant...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: green,
                                width: 1.8,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════════════════════════
                      // SECTION 6 — ACTIONS
                      // ══════════════════════════════════════════════════════════════
                      if (!_estSoumis) ...[
                        // ── Enregistrer brouillon ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _enregistrerBrouillon,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Enregistrer le brouillon'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: green,
                              side: const BorderSide(color: green, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Soumettre et verrouiller ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _confirmerSoumission,
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: const Text(
                              'Soumettre & Verrouiller',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            'Une fois soumis, la fiche ne peut plus être modifiée',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],

                      // ── Message si déjà soumis ──
                      if (_estSoumis)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: green.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: green.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: green, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Évaluation soumise et verrouillée',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: darkText,
                                      ),
                                    ),
                                    Text(
                                      'Cette fiche est en lecture seule',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET — _buildSlider
  // Slider avec boutons +/- et graduation colorée selon COI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSlider({
    required String label,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
    bool isPositif = false,
  }) {
    // Attributs positifs : 0–5 (PR-48). Défauts : 0–10 (COI, inchangé).
    final maxValeur = isPositif ? kMaxPositif : kMaxDefaut;
    final color = isPositif ? _sliderPositifColor(value) : _sliderColor(value);
    final intensite = intensiteLabel(value, positif: isPositif);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label + valeur + intensité ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPositif ? green : darkText,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Valeur numérique ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: value > 0
                      ? color.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value > 0
                        ? color.withValues(alpha: 0.4)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: value > 0 ? color : Colors.grey.shade400,
                  ),
                ),
              ),

              // ── Intensité label ──
              if (intensite.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    intensite,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // ── [ - ] Slider [ + ] ──
          Row(
            children: [
              // ── Bouton MOINS ──
              GestureDetector(
                onTap: _estSoumis
                    ? null
                    : () {
                        if (value > 0.0) {
                          onChanged(
                            double.parse(
                              (value - kPasSlider)
                                  .clamp(0.0, maxValeur)
                                  .toStringAsFixed(1),
                            ),
                          );
                        }
                      },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: value > 0 && !_estSoumis
                        ? color.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value > 0 && !_estSoumis
                          ? color.withValues(alpha: 0.4)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Icon(
                    Icons.remove,
                    size: 16,
                    color: value > 0 && !_estSoumis
                        ? color
                        : Colors.grey.shade400,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── Slider ──
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _estSoumis
                            ? Colors.grey.shade300
                            : color,
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: _estSoumis ? Colors.grey.shade400 : color,
                        overlayColor: color.withValues(alpha: 0.15),
                        trackHeight: 5.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 9,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                      ),
                      child: Slider(
                        value: value.clamp(0.0, maxValeur),
                        min: 0.0,
                        max: maxValeur,
                        divisions: (maxValeur / kPasSlider).round(),
                        onChanged: _estSoumis
                            ? null
                            : (v) => onChanged((v * 10).round() / 10),
                      ),
                    ),

                    // ── Graduation, 0 au maximum de l'échelle ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(maxValeur.round() + 1, (i) {
                          final isActive = value >= i.toDouble();
                          return Text(
                            '$i',
                            style: TextStyle(
                              fontSize: 9,
                              color: isActive && !_estSoumis
                                  ? color
                                  : Colors.grey.shade400,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Bouton PLUS ──
              GestureDetector(
                onTap: _estSoumis
                    ? null
                    : () {
                        if (value < maxValeur) {
                          onChanged(
                            double.parse(
                              (value + kPasSlider)
                                  .clamp(0.0, maxValeur)
                                  .toStringAsFixed(1),
                            ),
                          );
                        }
                      },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: value < maxValeur && !_estSoumis
                        ? color.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value < maxValeur && !_estSoumis
                          ? color.withValues(alpha: 0.4)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: value < maxValeur && !_estSoumis
                        ? color
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET — carte de classification à deux niveaux (COI + classe interne)
  // Le rendu vit dans lib/core/widgets/carte_classification.dart, partagé avec
  // le chef dégustateur et la vue CEO.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildClassificationCard() {
    return CarteClassification(
      resultat: _resultat,
      medianeDefauts: _medianeDefauts,
      fruite: _fruite,
      typeFruite: _typeFruite,
      amertume: _amer,
      piquant: _piquant,
      choisieLe: _dateCourte(_classeChoisieLe),
      readOnly: _estSoumis,
      onHarmonieChanged: (v) => setState(() {
        _profilNonHarmonieux = v;
        // Cocher la case annule la classe automatique : le choix manuel
        // précédent ne vaut plus pour la nouvelle situation.
        _classeManuelle = null;
      }),
      onClasseManuelleChanged: (c) => setState(() {
        _classeManuelle = c;
        _classeChoisieLe = c == null ? null : DateTime.now().toIso8601String();
      }),
    );
  }

  /// Date affichée sur la pastille « choisie manuellement ».
  String? _dateCourte(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET — _chipTypeFruite
  // Vert / Vert-mûr / Mûr — PR-48 §5 et §8
  // ─────────────────────────────────────────────────────────────────────────
  Widget _chipTypeFruite(TypeFruite type) {
    final actif = _typeFruite == type;
    final couleur = type == TypeFruite.mur ? oliveGreen : green;

    return GestureDetector(
      onTap: _estSoumis ? null : () => setState(() => _typeFruite = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: actif ? couleur.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: actif ? couleur : Colors.grey.shade300,
            width: actif ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          '${type.emoji} ${type.label}',
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: actif ? couleur : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET — _valuePill
  // Petit badge avec nom + valeur
  // ─────────────────────────────────────────────────────────────────────────
  Widget _valuePill(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET — _buildSectionCard
  // Carte section avec titre et contenu
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.domine(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET — _infoRow
  // Ligne d'info avec icône
  // ─────────────────────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: oliveGreen),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(fontSize: 13, color: darkText),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COULEUR — slider positif (vert uniquement)
  // Seuils rebasés sur l'échelle 0–5 du PR-48 : sur les anciens seuils 3 et 6,
  // un fruité au maximum serait resté dans la couleur du milieu.
  // ─────────────────────────────────────────────────────────────────────────
  Color _sliderPositifColor(double val) {
    if (val <= 1.5) return green;
    if (val <= 3.0) return oliveGreen;
    return Colors.teal.shade600;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION — Enregistrer brouillon
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _enregistrerBrouillon() async {
    setState(() => _saving = true);
    try {
      await _saveDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Brouillon enregistré',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: oliveGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _service.messageFor(error),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION — Confirmer soumission
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmerSoumission() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: green, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Soumettre ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: darkText, height: 1.5),
            children: [
              const TextSpan(
                text:
                    'Vous êtes sur le point de soumettre votre évaluation pour ',
              ),
              TextSpan(
                text: widget.numero ?? widget.echantillonId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: green,
                ),
              ),
              const TextSpan(text: '.\n\nAprès soumission, la fiche sera '),
              const TextSpan(
                text: 'verrouillée et ne pourra plus être modifiée.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _saving = true);
              try {
                final draft = await _saveDraft();
                final evaluationId = _evaluationId ?? draft['id'] as String?;
                if (evaluationId == null) {
                  throw StateError('Evaluation introuvable.');
                }
                await _service.soumettre(evaluationId);
                if (!mounted) return;
                setState(() => _estSoumis = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Évaluation soumise et verrouillée',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(20),
                  ),
                );
                Navigator.pop(context, _resultat.coi?.label ?? '');
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _service.messageFor(error),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(20),
                  ),
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Soumettre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
