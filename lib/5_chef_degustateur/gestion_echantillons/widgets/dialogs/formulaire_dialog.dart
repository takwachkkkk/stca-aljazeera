// ─────────────────────────────────────────────────────────────────────────────
// FILE : gestion_echantillons/widgets/dialogs/formulaire_dialog.dart
// PURPOSE : add / edit dialog for one or more Echantillons (degustateur module)
//           — in add mode: multiple bouteilles per fournisseur, each becomes its
//             own card in the list (same pattern as formulaire_collecteur_dialog)
//           — shared fields: collecteur, fournisseur, gouvernorat, délégation,
//             date d'arrivée, statut (read-only), photo, action buttons
//           — per-bouteille fields: référence, variété, numCiterne, quantité
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api_client.dart';
import '../../../../core/models/collecteur_suggestion.dart';
import '../../../../core/models/echantillon.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/fournisseur.dart';
import '../../../../core/services/bottle_label_ocr_service.dart';
import '../../../../core/services/collecteur_suggestion_service.dart';
import '../../../../core/services/fournisseur_service.dart';
import '../../../../core/services/variete_service.dart';
import '../../../../core/utils/reference_bouteille.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validation_echantillon_formulaire.dart';
import '../../../../core/widgets/champ_autocomplete.dart';
import '../../../../core/widgets/champ_varietes.dart';
import '../../../../core/widgets/date_input_field.dart';
import '../../../../core/widgets/dialog_reference_bouteille.dart';
import '../../../../core/widgets/photo_plein_ecran.dart';
import '../../../../core/widgets/saisie_protegee.dart';
// TODO(core): move GeoService to lib/core/services/ — cross-module import from 2_collecteur
import '../../../../2_collecteur/carte_geo/services/geo_service.dart';
import '../../../widgets/chef_colors.dart';

const Color _beige = Color(0xFFE9F4EE);

const Color _olive = Color(0xFF6B8143);
const Color _cream = Color(0xFFF9F6EF);
const Color _fieldFill = Color(0xFFF7FAF8);
final Color _hintColor = Colors.grey.shade600;
final Color _inlineLabelColor = Colors.grey.shade800;
const Color _labelOlive = Color(0xFF46542B);

// Section accent colors
const Color _sectionFournisseur = Color(0xFF2E7D98); // teal-blue
const Color _sectionLocalisation = Color(0xFF6D4C41); // earthy
const Color _sectionDate = Color(0xFF5C6BC0); // muted indigo

// ─────────────────────────────────────────────────────────────────────────────
// BOUTEILLE ROW — one row per bottle in the list
// ─────────────────────────────────────────────────────────────────────────────
class _BouteilleRow {
  final TextEditingController referenceCtrl;
  final TextEditingController varieteCtrl;
  final TextEditingController numCiterneCtrl;
  final TextEditingController qteCtrl;
  Uint8List? photoBytes;
  String? photoName;

  _BouteilleRow({
    required this.referenceCtrl,
    required this.varieteCtrl,
    required this.numCiterneCtrl,
    required this.qteCtrl,
  });

  factory _BouteilleRow.empty() => _BouteilleRow(
    referenceCtrl: TextEditingController(),
    varieteCtrl: TextEditingController(),
    numCiterneCtrl: TextEditingController(),
    qteCtrl: TextEditingController(),
  );

  factory _BouteilleRow.fromSample(Echantillon e) => _BouteilleRow(
    referenceCtrl: TextEditingController(text: e.referenceBouteille),
    varieteCtrl: TextEditingController(text: e.variete ?? ''),
    numCiterneCtrl: TextEditingController(text: e.numCiterne ?? ''),
    qteCtrl: TextEditingController(text: e.quantiteEstimee ?? ''),
  );

  void dispose() {
    referenceCtrl.dispose();
    varieteCtrl.dispose();
    numCiterneCtrl.dispose();
    qteCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
void showFormulaireDialog(
  BuildContext context, {
  Echantillon? echantillon,
  required int prochainNumero,
  required Future<void> Function(List<Echantillon>) onSaveMultiple,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FormulaireDialog(
      echantillon: echantillon,
      prochainNumero: prochainNumero,
      onSaveMultiple: onSaveMultiple,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATEFUL DIALOG WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _FormulaireDialog extends StatefulWidget {
  final Echantillon? echantillon;
  final int prochainNumero;
  final Future<void> Function(List<Echantillon>) onSaveMultiple;

  const _FormulaireDialog({
    required this.echantillon,
    required this.prochainNumero,
    required this.onSaveMultiple,
  });

  @override
  State<_FormulaireDialog> createState() => _FormulaireDialogState();
}

class _FormulaireDialogState extends State<_FormulaireDialog> {
  // ── GeoService ────────────────────────────────────────────────────────────
  final GeoService _geo = GeoService.instance;
  bool _geoLoaded = false;

  // ── Shared controllers ───────────────────────────────────────────────────
  late final TextEditingController _fournisseurTexteCtrl;
  late final TextEditingController _collecteurCtrl;
  late final TextEditingController _dateAjoutCtrl;
  late final TextEditingController _citeCtrl;
  late final TextEditingController _remarquesCtrl;
  CollecteurSuggestion? _collecteurChoisi;

  // ── Location state ────────────────────────────────────────────────────────
  String? _gouvernorat;
  String? _delegation;

  // ── Per-bouteille rows ────────────────────────────────────────────────────
  final List<_BouteilleRow> _bouteilles = [];
  bool _saving = false;

  bool get _isModification => widget.echantillon != null;

  // ── Photo of each bottle (optional) ─────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();
  bool _ocrActive = false;
  bool _ocrStatusLoaded = false;
  bool _ocrLoading = false;
  final BottleLabelOcrService _ocrService = BottleLabelOcrService();

  Future<void> _pickRowPhoto(ImageSource source, _BouteilleRow row) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      row.photoBytes = bytes;
      row.photoName = file.name;
    });
  }

  void _removeRowPhoto(_BouteilleRow row) => setState(() {
    row.photoBytes = null;
    row.photoName = null;
  });

  void _chooseRowPhotoSource(_BouteilleRow row) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: chefGreen,
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickRowPhoto(ImageSource.camera, row);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: chefGreen,
              ),
              title: const Text('Importer depuis la galerie'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickRowPhoto(ImageSource.gallery, row);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: chefDark),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _prefillIfEmpty(TextEditingController controller, String? value) {
    if (value == null || controller.text.trim().isNotEmpty) return;
    controller.text = value;
  }

  Future<void> _readLabel(_BouteilleRow row) async {
    if (!_ocrActive || _ocrLoading) return;
    final bytes = row.photoBytes;
    if (bytes == null) {
      _showErrorMessage('Ajoutez une photo avant de lire l\'étiquette.');
      return;
    }
    setState(() => _ocrLoading = true);
    try {
      final result = await _ocrService.readLabel(
        bytes: bytes,
        filename: row.photoName ?? 'etiquette.jpg',
      );
      if (!mounted) return;
      if (!result.hasAnyValue) {
        _showErrorMessage(
          'Aucun champ lisible. Saisissez les informations manuellement.',
        );
        return;
      }
      setState(() {
        _prefillIfEmpty(_fournisseurTexteCtrl, result.fournisseurNom);
        _prefillIfEmpty(row.referenceCtrl, result.referenceBouteille);
        _prefillIfEmpty(row.varieteCtrl, result.variete);
        _prefillIfEmpty(row.qteCtrl, result.quantite);
        _prefillIfEmpty(row.numCiterneCtrl, result.numCiterne);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Étiquette lue. Vérifiez les champs avant d\'enregistrer.',
          ),
        ),
      );
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      if (mounted) _showErrorMessage(message);
    } finally {
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  int get _bottleCount => _bouteilles.length;

  @override
  void initState() {
    super.initState();
    final e = widget.echantillon;

    _fournisseurTexteCtrl = TextEditingController(
      text: e?.fournisseurNom ?? e?.fournisseurTexte ?? '',
    );
    _collecteurCtrl = TextEditingController(text: e?.collecteurNom ?? '');
    _dateAjoutCtrl = TextEditingController(
      text: DegDateUtils.formaterSaisie(e?.dateArriveeEchantillon),
    );
    _citeCtrl = TextEditingController(text: e?.cite ?? '');
    _remarquesCtrl = TextEditingController(text: e?.remarques ?? '');

    _gouvernorat = e?.gouvernorat.isEmpty == true ? null : e?.gouvernorat;
    _delegation = e?.delegation;

    // Seed with one row (pre-filled for edit, empty for add)
    _bouteilles.add(
      e != null ? _BouteilleRow.fromSample(e) : _BouteilleRow.empty(),
    );

    _geo.load().then((_) {
      if (mounted) setState(() => _geoLoaded = true);
    });
    _loadOcrStatus();
  }

  Future<void> _loadOcrStatus() async {
    try {
      final active = await _ocrService.isActive();
      if (!mounted) return;
      setState(() {
        _ocrActive = active;
        _ocrStatusLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocrActive = false;
        _ocrStatusLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _fournisseurTexteCtrl.dispose();
    _collecteurCtrl.dispose();
    _dateAjoutCtrl.dispose();
    _citeCtrl.dispose();
    _remarquesCtrl.dispose();
    for (final b in _bouteilles) {
      b.dispose();
    }
    super.dispose();
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/'
        '${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  String get _fournisseurPourReference => fournisseurPourReferenceBouteille(
    texteChampFournisseur: _fournisseurTexteCtrl.text,
  );

  void _actualiserReference(_BouteilleRow row) {
    final nouvelleReference = construireReferenceBouteille(
      fournisseur: _fournisseurPourReference,
      numeroCiterne: row.numCiterneCtrl.text,
      quantite: row.qteCtrl.text,
    );
    if (nouvelleReference == row.referenceCtrl.text) return;

    row.referenceCtrl.value = TextEditingValue(
      text: nouvelleReference,
      selection: TextSelection.collapsed(offset: nouvelleReference.length),
    );
  }

  void _actualiserToutesLesReferences() {
    for (final row in _bouteilles) {
      _actualiserReference(row);
    }
  }

  void _addRow() => setState(() {
    final row = _BouteilleRow.empty();
    _bouteilles.add(row);
    _actualiserReference(row);
  });

  void _removeRow(int index) {
    setState(() {
      _bouteilles[index].dispose();
      _bouteilles.removeAt(index);
    });
  }

  String? _messageValidation() {
    return validerFormulaireEchantillon(
      nombreBouteilles: _bouteilles.length,
      fournisseur: _fournisseurTexteCtrl.text,
      referencesBouteilles: _bouteilles
          .map((b) => b.referenceCtrl.text)
          .toList(),
    );
  }

  Future<void> _confirmerReferenceSiRecalculee(_BouteilleRow row) async {
    final e = widget.echantillon;
    if (e == null) return;

    final decision = referenceRecalculeeAConfirmer(
      estModification: true,
      ancienneReference: e.referenceBouteille,
      referenceActuelle: row.referenceCtrl.text,
      fournisseur: _fournisseurPourReference,
      numeroCiterne: row.numCiterneCtrl.text,
      quantite: row.qteCtrl.text,
    );
    if (decision == null) return;

    final choix = await demanderChoixReferenceBouteilleRecalculee(
      context,
      ancienneReference: decision.ancienneReference,
      nouvelleReference: decision.nouvelleReference,
      couleurPrincipale: chefGreen,
    );
    if (choix == ChoixReferenceBouteille.garderAncienne) {
      row.referenceCtrl.text = decision.ancienneReference;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final validation = _messageValidation();
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      final gouvernorat = _gouvernorat ?? '';
      final collecteur = _collecteurCtrl.text.trim().isEmpty
          ? null
          : _collecteurCtrl.text.trim();
      final fournisseurTexte = _fournisseurTexteCtrl.text.trim().isEmpty
          ? null
          : _fournisseurTexteCtrl.text.trim();
      final cite = _citeCtrl.text.trim().isEmpty ? null : _citeCtrl.text.trim();

      if (_isModification) {
        final e = widget.echantillon!;
        final b = _bouteilles.first;
        await _confirmerReferenceSiRecalculee(b);
        if (!mounted) return;
        e.referenceBouteille = b.referenceCtrl.text.trim();
        e.variete = b.varieteCtrl.text.trim().isEmpty
            ? null
            : b.varieteCtrl.text.trim();
        e.numCiterne = b.numCiterneCtrl.text.trim().isEmpty
            ? null
            : b.numCiterneCtrl.text.trim();
        e.quantiteEstimee = b.qteCtrl.text.trim().isEmpty
            ? null
            : b.qteCtrl.text.trim();
        e.gouvernorat = gouvernorat;
        e.delegation = _delegation;
        e.cite = cite;
        e.remarques = _remarquesCtrl.text.trim().isEmpty
            ? null
            : _remarquesCtrl.text.trim();
        e.dateArriveeEchantillon = DegDateUtils.dateSaisieVersIso(
          _dateAjoutCtrl.text,
        );
        // A newly picked photo is sent with the edit; otherwise the old one stays.
        e.photoAEnvoyer = b.photoBytes;
        e.photoNomFichier = b.photoName;
        // fournisseurTexte, dateAjout, collecteurNom are API-assigned — not mutated
        await widget.onSaveMultiple([e]);
      } else {
        final now = DateTime.now();
        final samples = _bouteilles.asMap().entries.map((entry) {
          final idx = entry.key;
          final b = entry.value;
          final numero = widget.prochainNumero + idx;
          return Echantillon(
              id: 'new-${now.millisecondsSinceEpoch}-$idx',
              numero: '${now.year}/${numero.toString().padLeft(4, '0')}',
              fournisseurId: 'fournisseur-placeholder',
              collecteurId: _collecteurChoisi?.id ?? '',
              fournisseurTexte: fournisseurTexte,
              collecteurNom: _collecteurChoisi?.nomComplet ?? collecteur,
              referenceBouteille: b.referenceCtrl.text.trim(),
              variete: b.varieteCtrl.text.trim().isEmpty
                  ? null
                  : b.varieteCtrl.text.trim(),
              numCiterne: b.numCiterneCtrl.text.trim().isEmpty
                  ? null
                  : b.numCiterneCtrl.text.trim(),
              gouvernorat: gouvernorat,
              delegation: _delegation,
              cite: cite,
              remarques: _remarquesCtrl.text.trim().isEmpty
                  ? null
                  : _remarquesCtrl.text.trim(),
              quantiteEstimee: b.qteCtrl.text.trim().isEmpty
                  ? null
                  : b.qteCtrl.text.trim(),
              dateAjout: now.toIso8601String(),
              dateArriveeEchantillon: DegDateUtils.dateSaisieVersIso(
                _dateAjoutCtrl.text,
              ),
              statutCollecteur: StatutCollecteur.receptionne,
              statutDegustateur: StatutDegustateur.nonEvaluee,
              recuPhysiquement: true,
            )
            ..photoAEnvoyer = b.photoBytes
            ..photoNomFichier = b.photoName;
        }).toList();
        await widget.onSaveMultiple(samples);
      }
      FournisseurService.instance.invalidateCache();
      VarieteService.instance.invalidateCache();
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enregistrement impossible : $message'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SaisieProtegee(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Dialog header ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: const BoxDecoration(
                  color: _beige,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isModification
                          ? Icons.edit_outlined
                          : Icons.add_circle_outline,
                      color: chefDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isModification
                            ? "Modifier l'échantillon"
                            : 'Nouvel échantillon',
                        style: GoogleFonts.domine(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: chefDark,
                        ),
                      ),
                    ),
                    // ID badge — add mode only
                    if (!_isModification)
                      _IdBadge(
                        prochainNumero: widget.prochainNumero,
                        bottleCount: _bottleCount,
                      ),
                  ],
                ),
              ),

              // ── Scrollable body ───────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SHARED: FOURNISSEUR & COLLECTEUR ─────────────────
                      ChampAutocomplete<Fournisseur>(
                        label: 'Fournisseur',
                        titre: const _InlineLabel(
                          label: 'Fournisseur',
                          required: true,
                        ),
                        controller: _fournisseurTexteCtrl,
                        decoration: _FormField.decoration(
                          'Ex: Domaine Bel-Air',
                        ),
                        styleTexte: const TextStyle(
                          fontSize: 14,
                          color: chefDark,
                        ),
                        chercher: FournisseurService.instance.suggest,
                        libelle: libelleFournisseur,
                        texteSelection: (f) => f.nom,
                        onSelection: (f) {
                          setState(() {
                            _gouvernorat = f.region?.trim().isEmpty == true
                                ? null
                                : f.region;
                            _delegation = f.delegation?.trim().isEmpty == true
                                ? null
                                : f.delegation;
                          });
                          _actualiserToutesLesReferences();
                        },
                        onSaisieLibre: _actualiserToutesLesReferences,
                      ),
                      const SizedBox(height: 12),
                      ChampAutocomplete<CollecteurSuggestion>(
                        label: 'Collecteur',
                        titre: const _InlineLabel(label: 'Collecteur'),
                        controller: _collecteurCtrl,
                        decoration: _FormField.decoration('Ex: Ahmed Dridi'),
                        styleTexte: const TextStyle(
                          fontSize: 14,
                          color: chefDark,
                        ),
                        hint: 'Ex: Ahmed Dridi',
                        chercher: CollecteurSuggestionService.instance.suggest,
                        libelle: (c) => c.nomComplet,
                        texteSelection: (c) => c.nomComplet,
                        onSelection: (c) => setState(() {
                          _collecteurChoisi = c;
                        }),
                        onSaisieLibre: () => _collecteurChoisi = null,
                      ),

                      const SizedBox(height: 12),

                      // ── SHARED: LOCALISATION ─────────────────────────────
                      _DropdownField(
                        label: 'Gouvernorat',
                        value: _gouvernorat,
                        items: _geoLoaded
                            ? _geo.gouvernorats.toSet().toList()
                            : [],
                        hint: _geoLoaded
                            ? 'Sélectionner un gouvernorat'
                            : 'Chargement…',
                        onChanged: (v) => setState(() {
                          _gouvernorat = v;
                          _delegation = null;
                        }),
                      ),
                      const SizedBox(height: 12),

                      _DropdownField(
                        label: 'Délégation',
                        value: _delegation,
                        items: (_geoLoaded && _gouvernorat != null)
                            ? _geo
                                  .delegationsFor(_gouvernorat!)
                                  .toSet()
                                  .toList()
                            : [],
                        hint: _gouvernorat == null
                            ? "Choisir un gouvernorat d'abord"
                            : 'Sélectionner une délégation',
                        onChanged: _gouvernorat == null
                            ? null
                            : (v) => setState(() => _delegation = v),
                      ),

                      const SizedBox(height: 12),
                      _FormField(
                        label: 'Lieu précis (optionnel)',
                        controller: _citeCtrl,
                        hint: 'Ex: nom du village, du lieu-dit...',
                      ),

                      const SizedBox(height: 12),

                      // ── PER-BOUTEILLE SECTION ─────────────────────────────
                      _BouteillesSection(
                        bouteilles: _bouteilles,
                        isModification: _isModification,
                        onAddRow: _addRow,
                        onRemoveRow: _removeRow,
                        onPhoto: _chooseRowPhotoSource,
                        onRemovePhoto: _removeRowPhoto,
                        onReadLabel: _readLabel,
                        ocrActive: _ocrActive,
                        ocrStatusLoaded: _ocrStatusLoaded,
                        ocrLoading: _ocrLoading,
                        onDonneesReferenceChangees: _actualiserReference,
                      ),

                      const SizedBox(height: 12),
                      // ── SHARED: DATE ──────────────────────────────────────
                      DateInputField(controller: _dateAjoutCtrl),
                      const SizedBox(height: 12),

                      // ── SHARED: STATUT (read-only) ────────────────────────
                      _ReadOnlyField(
                        label: 'Statut',
                        icon: Icons.flag_outlined,
                        value: _isModification
                            ? (widget.echantillon!.statutDegustateur?.label ??
                                  'En attente')
                            : 'En attente',
                      ),

                      const SizedBox(height: 16),
                      // ── SHARED: PHOTO (optionnelle) ───────────────────────
                      const SizedBox(height: 12),

                      // ── SHARED: REMARQUES ─────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Remarques',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _labelOlive,
                                ),
                              ),
                              Text(
                                ' (optionnel)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _remarquesCtrl,
                            maxLines: 3,
                            minLines: 2,
                            style: const TextStyle(
                              fontSize: 14,
                              color: chefDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Notes, observations particulières...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: _fieldFill,
                              contentPadding: const EdgeInsets.all(12),
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
                                  color: chefGreen,
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Action buttons ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: _cream,
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
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: Icon(
                          _isModification ? Icons.check : Icons.add,
                          size: 16,
                        ),
                        label: Text(
                          _isModification
                              ? 'Enregistrer'
                              : _bottleCount > 1
                              ? 'Ajouter $_bottleCount échantillons'
                              : 'Ajouter',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            197,
                            206,
                            201,
                          ),
                          foregroundColor: chefDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ID BADGE — shows auto-generated numero range (add mode only)
// ─────────────────────────────────────────────────────────────────────────────
class _IdBadge extends StatelessWidget {
  final int prochainNumero;
  final int bottleCount;

  const _IdBadge({required this.prochainNumero, required this.bottleCount});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final from = prochainNumero.toString().padLeft(4, '0');
    final to = (prochainNumero + bottleCount - 1).toString().padLeft(4, '0');
    final label = bottleCount > 1 ? '$year/$from → $to' : '$year/$from';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 26, 46, 31).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: chefDark,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTEILLES SECTION — list of per-bottle cards with add/remove controls
// ─────────────────────────────────────────────────────────────────────────────
class _BouteillesSection extends StatelessWidget {
  final List<_BouteilleRow> bouteilles;
  final bool isModification;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final ValueChanged<_BouteilleRow> onPhoto;
  final ValueChanged<_BouteilleRow> onRemovePhoto;
  final ValueChanged<_BouteilleRow> onReadLabel;
  final bool ocrActive;
  final bool ocrStatusLoaded;
  final bool ocrLoading;
  final ValueChanged<_BouteilleRow> onDonneesReferenceChangees;

  const _BouteillesSection({
    required this.bouteilles,
    required this.isModification,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onPhoto,
    required this.onRemovePhoto,
    required this.onReadLabel,
    required this.ocrActive,
    required this.ocrStatusLoaded,
    required this.ocrLoading,
    required this.onDonneesReferenceChangees,
  });

  @override
  Widget build(BuildContext context) {
    final count = bouteilles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header row with "Ajouter une bouteille" button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Bouteilles *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _labelOlive,
              ),
            ),
            const Spacer(),
            if (!isModification)
              GestureDetector(
                onTap: onAddRow,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: chefGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: chefGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: chefGreen),
                      SizedBox(width: 4),
                      Text(
                        'Ajouter une bouteille',
                        style: TextStyle(
                          fontSize: 12,
                          color: chefGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Info banner when multiple bottles
        if (!isModification && count > 1) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: chefGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chefGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: chefGreen.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count bouteilles → $count échantillons séparés seront créés',
                    style: TextStyle(
                      fontSize: 11,
                      color: chefGreen.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Bottle cards
        ...List.generate(
          count,
          (i) => _BouteilleCard(
            row: bouteilles[i],
            index: i,
            showRemove: !isModification && count > 1,
            onRemove: () => onRemoveRow(i),
            onPhoto: () => onPhoto(bouteilles[i]),
            onRemovePhoto: () => onRemovePhoto(bouteilles[i]),
            onReadLabel: () => onReadLabel(bouteilles[i]),
            ocrActive: ocrActive,
            ocrStatusLoaded: ocrStatusLoaded,
            ocrLoading: ocrLoading,
            onDonneesReferenceChangees: () =>
                onDonneesReferenceChangees(bouteilles[i]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTEILLE CARD — reference, variété, numCiterne, quantité fields for one bottle
// ─────────────────────────────────────────────────────────────────────────────
class _BouteilleCard extends StatelessWidget {
  final _BouteilleRow row;
  final int index;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onReadLabel;
  final bool ocrActive;
  final bool ocrStatusLoaded;
  final bool ocrLoading;
  final VoidCallback onDonneesReferenceChangees;

  const _BouteilleCard({
    required this.row,
    required this.index,
    required this.showRemove,
    required this.onRemove,
    required this.onPhoto,
    required this.onRemovePhoto,
    required this.onReadLabel,
    required this.ocrActive,
    required this.ocrStatusLoaded,
    required this.ocrLoading,
    required this.onDonneesReferenceChangees,
  });

  InputDecoration _fieldDec(String hint, {String? suffixText}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _hintColor, fontSize: 13),
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: _labelOlive,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: chefGreen, width: 1.8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header: bottle label + remove button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chefGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Bouteille ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chefGreen,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('photo-bouteille-$index'),
                onPressed: onPhoto,
                tooltip: row.photoBytes == null
                    ? 'Ajouter une photo'
                    : 'Remplacer la photo',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  row.photoBytes == null
                      ? Icons.add_a_photo_outlined
                      : Icons.photo_camera_back_outlined,
                  size: 18,
                  color: chefGreen,
                ),
              ),
              if (showRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 15,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Référence bouteille *
          _InlineLabel(label: 'Référence bouteille', required: true),
          const SizedBox(height: 5),
          TextField(
            controller: row.referenceCtrl,
            style: const TextStyle(fontSize: 13, color: chefDark),
            decoration: _fieldDec('Ex: CHEMLALI-C1'),
          ),
          const SizedBox(height: 8),

          // N° citerne + quantité estimée (side by side)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineLabel(label: 'N° citerne'),
                    const SizedBox(height: 5),
                    TextField(
                      controller: row.numCiterneCtrl,
                      onChanged: (_) => onDonneesReferenceChangees(),
                      style: const TextStyle(fontSize: 13, color: chefDark),
                      decoration: _fieldDec('Ex: Z1'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineLabel(label: 'Quantité estimée'),
                    const SizedBox(height: 5),
                    TextField(
                      controller: row.qteCtrl,
                      onChanged: (_) => onDonneesReferenceChangees(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      style: const TextStyle(fontSize: 13, color: chefDark),
                      decoration: _fieldDec('Ex: 5000', suffixText: 'T'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ChampVarietes(
            label: "Variété d'olive",
            titre: const _InlineLabel(label: "Variété d'olive"),
            controller: row.varieteCtrl,
            decoration: _fieldDec('Chemlali, Chétoui...'),
            styleTexte: const TextStyle(fontSize: 13, color: chefDark),
          ),
          const SizedBox(height: 10),

          _InlineLabel(label: 'Photo de la bouteille'),
          const SizedBox(height: 5),
          if (row.photoBytes == null)
            Text(
              'Aucune photo',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          else ...[
            PhotoPleinEcran.memory(
              bytes: row.photoBytes!,
              height: 130,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.photoName ?? 'photo.jpg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                TextButton.icon(
                  onPressed: onPhoto,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Remplacer'),
                ),
                TextButton.icon(
                  onPressed: onRemovePhoto,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                  label: Text(
                    'Retirer',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: ocrActive && row.photoBytes != null && !ocrLoading
                  ? onReadLabel
                  : null,
              icon: ocrLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined, size: 16),
              label: Text(
                ocrStatusLoaded && !ocrActive
                    ? 'Lecture automatique bientôt disponible'
                    : 'Lire l\'étiquette',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE LABEL — small label above a field inside a card
// ─────────────────────────────────────────────────────────────────────────────
class _InlineLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _InlineLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _inlineLabelColor,
        ),
      ),
      if (required)
        const Text(' *', style: TextStyle(fontSize: 11, color: Colors.red)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD LABEL — standalone label row (used before DateInputField)
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;
  final double fontSize;
  const _FieldLabel({
    required this.label,
    this.optional = false,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: _labelOlive,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final String? suffixText;
  final bool required;
  final bool optional;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.suffixText,
    this.required = false,
    this.optional = false,
  });

  static InputDecoration decoration(String hint, {String? suffixText}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _hintColor, fontSize: 13),
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: _labelOlive,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: chefGreen, width: 1.8),
        ),
      );

  InputDecoration _dec() => decoration(hint, suffixText: suffixText);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _labelOlive,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: chefDark),
          decoration: _dec(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?>? onChanged;
  final bool optional;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _labelOlive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        IgnorePointer(
          ignoring: onChanged == null,
          child: Opacity(
            opacity: onChanged == null ? 0.5 : 1.0,
            child: DropdownButtonFormField<String>(
              value: (value != null && items.contains(value)) ? value : null,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: _fieldFill,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: chefGreen, width: 1.8),
                ),
              ),
              hint: Text(
                hint,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              items: items
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ-ONLY FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;

  const _ReadOnlyField({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _labelOlive,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _fieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: chefGreen, size: 20),
            const SizedBox(width: 12),
            Text(value, style: const TextStyle(fontSize: 14, color: chefDark)),
            const Spacer(),
            Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    ],
  );
}
