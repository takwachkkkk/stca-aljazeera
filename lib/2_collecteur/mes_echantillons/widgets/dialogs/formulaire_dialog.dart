// ─────────────────────────────────────────────────────────────────────────────
// FILE : 2_collecteur/mes_echantillons/widgets/dialogs/formulaire_dialog.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/echantillon_collecteur.dart';
import '../../../../core/api_client.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/fournisseur.dart';
import '../../../../core/services/bottle_label_ocr_service.dart';
import '../../../../core/services/fournisseur_service.dart';
import '../../../../core/services/variete_service.dart';
import '../../../../core/utils/reference_bouteille.dart';
import '../../../../core/utils/validation_echantillon_formulaire.dart';
import '../../../../core/widgets/champ_autocomplete.dart';
import '../../../../core/widgets/champ_varietes.dart';
import '../../../../core/widgets/dialog_reference_bouteille.dart';
import '../../../../core/widgets/photo_plein_ecran.dart';
import '../../../../core/widgets/saisie_protegee.dart';
import '../../../../2_collecteur/carte_geo/services/geo_service.dart';
import 'bouteille_row.dart';
import 'date_livraison_section.dart';
import 'formulaire_sections.dart';
import 'formulaire_decorations.dart';

class SamplePhoto {
  final List<int> bytes;
  final String filename;

  const SamplePhoto({required this.bytes, required this.filename});
}

// Save callback. Carries one optional photo per bottle row so each created
// sample keeps its optional bottle-label photo.
typedef SaveSamplesCb =
    Future<void> Function(
      List<EchantillonCollecteur> samples, {
      List<SamplePhoto?>? photos,
    });
typedef PickBottlePhoto = Future<XFile?> Function(ImageSource source);

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
void showFormulaireDialog(
  BuildContext context, {
  EchantillonCollecteur? echantillon,
  required int prochainNumero,
  required SaveSamplesCb onSaveMultiple,
  PickBottlePhoto? pickPhoto,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FormulaireDialog(
      echantillon: echantillon,
      prochainNumero: prochainNumero,
      onSaveMultiple: onSaveMultiple,
      pickPhoto: pickPhoto,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATEFUL DIALOG WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _FormulaireDialog extends StatefulWidget {
  final EchantillonCollecteur? echantillon;
  final int prochainNumero;
  final SaveSamplesCb onSaveMultiple;
  final PickBottlePhoto? pickPhoto;

  const _FormulaireDialog({
    required this.echantillon,
    required this.prochainNumero,
    required this.onSaveMultiple,
    this.pickPhoto,
  });

  @override
  State<_FormulaireDialog> createState() => _FormulaireDialogState();
}

class _FormulaireDialogState extends State<_FormulaireDialog> {
  final GeoService _geo = GeoService.instance;
  bool _geoLoaded = false;

  /// Set only when a suggestion is picked. Stays null while the collector types
  /// a name of their own; the backend resolves that name with the sample.
  Fournisseur? _fournisseurChoisi;

  // ── Shared controllers ───────────────────────────────────────────────────
  late final TextEditingController _fournisseurTexteCtrl;
  late final TextEditingController _collecteurCtrl;
  late final TextEditingController _citeCtrl;

  // ── Date de livraison ────────────────────────────────────────────────────
  ModePlanificationUI _livMode = ModePlanificationUI.dateExacte;
  DateTime? _livExacte;
  DateTime? _livDebut;
  DateTime? _livFin;

  // ── Location ─────────────────────────────────────────────────────────────
  String? _gouvernorat;
  String? _delegation;

  // ── Per-bouteille rows ────────────────────────────────────────────────────
  final List<BouteilleRow> _bouteilles = [];
  bool _saving = false;
  bool _ocrActive = false;
  bool _ocrStatusLoaded = false;
  bool _ocrLoading = false;

  // ── Bottle photos (optional, one per sample) ──────────────────────────────
  final ImagePicker _picker = ImagePicker();
  final BottleLabelOcrService _ocrService = BottleLabelOcrService();

  Future<void> _pickPhoto(ImageSource source, BouteilleRow row) async {
    final XFile? file = widget.pickPhoto != null
        ? await widget.pickPhoto!(source)
        : await _picker.pickImage(
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

  void _removePhoto(BouteilleRow row) => setState(() {
    row.photoBytes = null;
    row.photoName = null;
  });

  void _choosePhotoSource(BouteilleRow row) {
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
              key: const ValueKey('photo-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined, color: kGreen),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera, row);
              },
            ),
            ListTile(
              key: const ValueKey('photo-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined, color: kGreen),
              title: const Text('Importer depuis la galerie'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery, row);
              },
            ),
            ListTile(
              key: const ValueKey('photo-source-cancel'),
              leading: const Icon(Icons.close, color: kDarkText),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isModification => widget.echantillon != null;
  int get _bottleCount => _bouteilles.length;

  @override
  void initState() {
    super.initState();
    final e = widget.echantillon;

    _fournisseurTexteCtrl = TextEditingController(
      text: e?.fournisseurNom ?? e?.fournisseurTexte ?? '',
    );
    _collecteurCtrl = TextEditingController(text: e?.collecteurNom ?? '');
    _citeCtrl = TextEditingController(text: e?.cite ?? '');

    _gouvernorat = (e?.gouvernorat != null && e!.gouvernorat.isNotEmpty)
        ? e.gouvernorat
        : null;
    _delegation = e?.delegation;

    // Pre-fill date de livraison — dateArriveeEchantillon is already DateTime?
    _livExacte = e?.dateArriveeEchantillon;

    _bouteilles.add(
      e != null
          ? BouteilleRow.fromSample(
              referenceBouteille: e.referenceBouteille,
              variete: e.variete ?? '',
              numCiterne: e.numCiterne ?? '',
              qte: e.quantiteEstimee ?? '',
              remarque: e.remarques ?? '',
            )
          : BouteilleRow.empty(),
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
    _citeCtrl.dispose();
    for (final b in _bouteilles) {
      b.dispose();
    }
    super.dispose();
  }

  DateTime? get _livDate =>
      _livMode == ModePlanificationUI.dateExacte ? _livExacte : _livDebut;

  String get _fournisseurPourReference => fournisseurPourReferenceBouteille(
    texteChampFournisseur: _fournisseurTexteCtrl.text,
  );

  void _actualiserReference(BouteilleRow row) {
    final nouvelleReference = construireReferenceBouteille(
      fournisseur: _fournisseurPourReference,
      numeroCiterne: row.numCiterneCtrl.text,
      quantite: row.qteCtrl.text,
    );
    if (nouvelleReference == row.refCtrl.text) return;

    row.refCtrl.value = TextEditingValue(
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
    final row = BouteilleRow.empty();
    _bouteilles.add(row);
    _actualiserReference(row);
  });
  void _removeRow(int i) {
    setState(() {
      _bouteilles[i].dispose();
      _bouteilles.removeAt(i);
    });
  }

  String? _messageValidation() {
    return validerFormulaireEchantillon(
      nombreBouteilles: _bouteilles.length,
      fournisseur: _fournisseurTexteCtrl.text,
      referencesBouteilles: _bouteilles.map((b) => b.refCtrl.text).toList(),
    );
  }

  bool get _isValid => _messageValidation() == null;

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

  String _messageErreur(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  void _prefillIfEmpty(TextEditingController controller, String? value) {
    if (value == null || controller.text.trim().isNotEmpty) return;
    controller.text = value;
  }

  Future<void> _readLabel(BouteilleRow row) async {
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
        _showErrorMessage('Aucun champ lisible. Saisissez les informations manuellement.');
        return;
      }
      setState(() {
        _prefillIfEmpty(_fournisseurTexteCtrl, result.fournisseurNom);
        _prefillIfEmpty(row.refCtrl, result.referenceBouteille);
        _prefillIfEmpty(row.varieteCtrl, result.variete);
        _prefillIfEmpty(row.qteCtrl, result.quantite);
        _prefillIfEmpty(row.numCiterneCtrl, result.numCiterne);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Étiquette lue. Vérifiez les champs avant d\'enregistrer.')),
      );
    } catch (error) {
      if (mounted) _showErrorMessage(_messageErreur(error));
    } finally {
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  Future<void> _confirmerReferenceSiRecalculee(BouteilleRow row) async {
    final e = widget.echantillon;
    if (e == null) return;

    final decision = referenceRecalculeeAConfirmer(
      estModification: true,
      ancienneReference: e.referenceBouteille,
      referenceActuelle: row.refCtrl.text,
      fournisseur: _fournisseurPourReference,
      numeroCiterne: row.numCiterneCtrl.text,
      quantite: row.qteCtrl.text,
    );
    if (decision == null) return;

    final choix = await demanderChoixReferenceBouteilleRecalculee(
      context,
      ancienneReference: decision.ancienneReference,
      nouvelleReference: decision.nouvelleReference,
      couleurPrincipale: kGreen,
    );
    if (choix == ChoixReferenceBouteille.garderAncienne) {
      row.refCtrl.text = decision.ancienneReference;
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
      final fournisseurNom = _fournisseurTexteCtrl.text.trim().isEmpty
          ? null
          : _fournisseurTexteCtrl.text.trim();
      final cite = _citeCtrl.text.trim().isEmpty ? null : _citeCtrl.text.trim();

      if (_isModification) {
        final e = widget.echantillon!;
        final b = _bouteilles.first;
        await _confirmerReferenceSiRecalculee(b);
        if (!mounted) return;
        e.referenceBouteille = b.refCtrl.text.trim();
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
        e.remarques = b.remarqueCtrl.text.trim().isEmpty
            ? null
            : b.remarqueCtrl.text.trim();
        e.dateArriveeEchantillon = _livDate;
        e.fournisseurId = _fournisseurChoisi?.id ?? e.fournisseurId;
        e.fournisseurNom = fournisseurNom;
        e.fournisseurTexte = fournisseurNom ?? '';
        await widget.onSaveMultiple(
          [e],
          photos: b.photoBytes == null
              ? null
              : [
                  SamplePhoto(
                    bytes: b.photoBytes!,
                    filename: b.photoName ?? 'etiquette.jpg',
                  ),
                ],
        );
      } else {
        final now = DateTime.now();
        final samples = _bouteilles.asMap().entries.map((entry) {
          final idx = entry.key;
          final b = entry.value;
          final numero = widget.prochainNumero + idx;
          return EchantillonCollecteur(
            id: 'new-${now.millisecondsSinceEpoch}-$idx',
            numero:
                '${now.year}/${(widget.prochainNumero + idx).toString().padLeft(4, '0')}',
            fournisseurId: _fournisseurChoisi?.id,
            fournisseurTexte: fournisseurNom ?? '',
            fournisseurNom: fournisseurNom,
            collecteurId: 'collecteur-placeholder',
            collecteurNom: collecteur ?? '',
            referenceBouteille: b.refCtrl.text.trim(),
            variete: b.varieteCtrl.text.trim().isEmpty
                ? null
                : b.varieteCtrl.text.trim(),
            numCiterne: b.numCiterneCtrl.text.trim().isEmpty
                ? null
                : b.numCiterneCtrl.text.trim(),
            gouvernorat: gouvernorat,
            delegation: _delegation,
            cite: cite,
            remarques: b.remarqueCtrl.text.trim().isEmpty
                ? null
                : b.remarqueCtrl.text.trim(),
            quantiteEstimee: b.qteCtrl.text.trim().isEmpty
                ? null
                : b.qteCtrl.text.trim(),
            dateAjout: DateTime.now(),
            dateArriveeEchantillon: _livDate,
            achatConfirme: false,
            statut: StatutCollecteur.receptionne,
          );
        }).toList();
        await widget.onSaveMultiple(
          samples,
          photos: _bouteilles
              .map(
                (b) => b.photoBytes == null
                    ? null
                    : SamplePhoto(
                        bytes: b.photoBytes!,
                        filename: b.photoName ?? 'etiquette.jpg',
                      ),
              )
              .toList(),
        );
      }
      FournisseurService.instance.invalidateCache();
      VarieteService.instance.invalidateCache();
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        _showErrorMessage(
          'Enregistrement impossible : ${_messageErreur(error)}',
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
              // ── Header ────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F4EE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isModification
                          ? Icons.edit_outlined
                          : Icons.add_circle_outline,
                      color: kDarkText,
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
                          color: kDarkText,
                        ),
                      ),
                    ),
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
                      // Fournisseur & collecteur
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
                          color: kDarkText,
                        ),
                        chercher: FournisseurService.instance.suggest,
                        libelle: libelleFournisseur,
                        texteSelection: (f) => f.nom,
                        onSelection: (f) {
                          setState(() {
                            _fournisseurChoisi = f;
                            _gouvernorat = f.region?.trim().isEmpty == true
                                ? null
                                : f.region;
                            _delegation = f.delegation?.trim().isEmpty == true
                                ? null
                                : f.delegation;
                          });
                          _actualiserToutesLesReferences();
                        },
                        // Typing again means the field no longer points at the
                        // supplier that was picked.
                        onSaisieLibre: () {
                          _fournisseurChoisi = null;
                          _actualiserToutesLesReferences();
                        },
                      ),

                      const SizedBox(height: 12),

                      // Localisation
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

                      // Bouteilles
                      _BouteillesSection(
                        bouteilles: _bouteilles,
                        isModification: _isModification,
                        onAddRow: _addRow,
                        onRemoveRow: _removeRow,
                        onPhoto: _choosePhotoSource,
                        onRemovePhoto: _removePhoto,
                        onReadLabel: _readLabel,
                        ocrActive: _ocrActive,
                        ocrStatusLoaded: _ocrStatusLoaded,
                        ocrLoading: _ocrLoading,
                        onDonneesReferenceChangees: _actualiserReference,
                      ),
                      const SizedBox(height: 12),

                      // ── Date de livraison (always visible) ────────────────
                      DateLivraisonSection(
                        mode: _livMode,
                        onModeChanged: (m) => setState(() => _livMode = m),
                        dateExacte: _livExacte,
                        periodeDebut: _livDebut,
                        periodeFin: _livFin,
                        onDateExacteChanged: (dt) =>
                            setState(() => _livExacte = dt),
                        onPeriodeDebutChanged: (dt) =>
                            setState(() => _livDebut = dt),
                        onPeriodeFinChanged: (dt) =>
                            setState(() => _livFin = dt),
                      ),
                      const SizedBox(height: 12),

                      // Statut (read-only)
                      _ReadOnlyField(
                        label: 'Statut',
                        icon: Icons.flag_outlined,
                        value: _isModification
                            ? widget.echantillon!.statut.label
                            : 'Réceptionné',
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Action buttons ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                          foregroundColor: kDarkText,
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
// ID BADGE
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
          color: kDarkText,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTEILLES SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _BouteillesSection extends StatelessWidget {
  final List<BouteilleRow> bouteilles;
  final bool isModification;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final ValueChanged<BouteilleRow> onPhoto;
  final ValueChanged<BouteilleRow> onRemovePhoto;
  final ValueChanged<BouteilleRow> onReadLabel;
  final bool ocrActive;
  final bool ocrStatusLoaded;
  final bool ocrLoading;
  final ValueChanged<BouteilleRow> onDonneesReferenceChangees;

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Bouteilles *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kOlive,
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
                    color: kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: kGreen),
                      SizedBox(width: 4),
                      Text(
                        'Ajouter une bouteille',
                        style: TextStyle(
                          fontSize: 12,
                          color: kGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (!isModification && count > 1) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: kGreen.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count bouteilles → $count échantillons séparés seront créés',
                    style: TextStyle(
                      fontSize: 11,
                      color: kGreen.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
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
// BOUTEILLE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BouteilleCard extends StatelessWidget {
  final BouteilleRow row;
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

  InputDecoration _fieldDec(
    String hint, {
    String? suffixText,
    String? helperText,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: kFieldHint, fontSize: 13),
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      color: kOlive,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
      borderSide: const BorderSide(color: kGreen, width: 1.8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('bouteille-card-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Bouteille ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kGreen,
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
                  color: kGreen,
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

          _InlineLabel(label: 'Référence bouteille', required: true),
          const SizedBox(height: 5),
          TextField(
            key: ValueKey('reference-bouteille-$index'),
            controller: row.refCtrl,
            style: const TextStyle(fontSize: 13, color: kDarkText),
            decoration: _fieldDec(
              'Ex: CHEMLALI-C1',
              helperText:
                  'Se remplit automatiquement à partir du fournisseur, '
                  'du n° de citerne et de la quantité.',
            ),
          ),
          const SizedBox(height: 8),

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
                      style: const TextStyle(fontSize: 13, color: kDarkText),
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
                      style: const TextStyle(fontSize: 13, color: kDarkText),
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
            styleTexte: const TextStyle(fontSize: 13, color: kDarkText),
          ),
          const SizedBox(height: 8),

          _InlineLabel(label: 'Remarque'),
          const SizedBox(height: 5),
          TextField(
            key: ValueKey('remarque-bouteille-$index'),
            controller: row.remarqueCtrl,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, color: kDarkText),
            decoration: _fieldDec('Notes, observations particulières...'),
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
// INLINE LABEL
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
          color: kInlineLabel,
        ),
      ),
      if (required)
        const Text(' *', style: TextStyle(fontSize: 11, color: Colors.red)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: kOlive,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  static InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: kFieldHint, fontSize: 13),
    filled: true,
    fillColor: kFieldFill,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
      borderSide: const BorderSide(color: kGreen, width: 1.8),
    ),
  );

  InputDecoration _dec() => decoration(hint);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kOlive,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: kDarkText),
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

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = items.isEmpty && onChanged != null;
    final isDisabled = onChanged == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kOlive,
          ),
        ),
        const SizedBox(height: 6),
        if (isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: kFieldFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      kGreen.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  hint,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ],
            ),
          )
        else
          Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: IgnorePointer(
              ignoring: isDisabled,
              child: DropdownButtonFormField<String>(
                initialValue: (value != null && items.contains(value))
                    ? value
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kFieldFill,
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
                    borderSide: const BorderSide(color: kGreen, width: 1.8),
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
          color: kOlive,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: kFieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: kGreen, size: 20),
            const SizedBox(width: 12),
            Text(value, style: const TextStyle(fontSize: 14, color: kDarkText)),
            const Spacer(),
            Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    ],
  );
}
