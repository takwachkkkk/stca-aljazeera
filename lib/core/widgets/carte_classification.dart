// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/widgets/carte_classification.dart
// PURPOSE : Carte de classification à deux niveaux, partagée par le formulaire
//           du dégustateur, celui du chef dégustateur et la vue CEO.
//
//   Bloc 1 — catégorie réglementaire COI
//   Bloc 2 — classe interne PR-48, avec sa case d'harmonie (§9) et son
//            sélecteur manuel pour les cas hors grille
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../classification/classification_interne.dart';
import '../models/enums.dart';

const Color _dark = Color(0xFF1A2E1F);
const Color _ligne = Color(0x0F000000);
const Color _horsGrille = Color(0xFFF57C00);
const Color _inactif = Color(0xFF9AA39D);

class CarteClassification extends StatelessWidget {
  final ResultatClassification resultat;
  final double medianeDefauts;
  final double fruite;
  final TypeFruite typeFruite;
  final double amertume;
  final double piquant;

  /// Nom du dégustateur, affiché sur la pastille « choisie manuellement ».
  final String? choisiePar;
  final String? choisieLe;

  /// Verrouille la carte — évaluation soumise ou vue en lecture seule.
  final bool readOnly;

  final ValueChanged<bool>? onHarmonieChanged;
  final ValueChanged<ClasseInterne?>? onClasseManuelleChanged;

  const CarteClassification({
    super.key,
    required this.resultat,
    required this.medianeDefauts,
    required this.fruite,
    required this.typeFruite,
    required this.amertume,
    required this.piquant,
    this.choisiePar,
    this.choisieLe,
    this.readOnly = false,
    this.onHarmonieChanged,
    this.onClasseManuelleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ligne),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _blocCoi(),
          Container(height: 1, color: _ligne),
          _blocInterne(context),
        ],
      ),
    );
  }

  // ── Bloc 1 — catégorie COI ─────────────────────────────────────────────────
  Widget _blocCoi() {
    final coi = resultat.coi;
    final couleur = coi == null ? _inactif : Color(coi.colorValue);

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _entete(
            'Catégorie COI',
            'Médiane des défauts : ${medianeDefauts.toStringAsFixed(1)}',
          ),
          const SizedBox(height: 7),
          _titre(coi?.label ?? 'En attente d\'évaluation', couleur),
          const SizedBox(height: 5),
          _justification(descriptionCoi(coi)),
        ],
      ),
    );
  }

  // ── Bloc 2 — classe interne PR-48 ──────────────────────────────────────────
  Widget _blocInterne(BuildContext context) {
    if (!resultat.interneApplicable) return _interneNonApplicable();
    if (resultat.horsGrille) return _interneHorsGrille(context);
    return _interneClassee();
  }

  Widget _interneNonApplicable() {
    return Container(
      color: const Color(0xFFFAFBFA),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _entete('Classe interne', 'PR-48'),
          const SizedBox(height: 7),
          _titre('Non applicable', _inactif, dotColor: const Color(0xFFCFD6D1)),
          const SizedBox(height: 5),
          _justification(
            resultat.coi == null
                ? 'Saisir le fruité et les défauts pour classifier'
                : 'Réservée aux huiles extra vierges : un défaut a été perçu.',
          ),
        ],
      ),
    );
  }

  Widget _interneClassee() {
    final classe = resultat.classeAuto!;
    final couleur = Color(classe.colorValue);

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _entete('Classe interne', 'PR-48'),
          const SizedBox(height: 7),
          _titre(classe.label, couleur),
          const SizedBox(height: 5),
          _justification(_criteres()),
          if (resultat.harmonieProposable) _caseHarmonie(),
        ],
      ),
    );
  }

  Widget _interneHorsGrille(BuildContext context) {
    final choisie = resultat.classeManuelle;

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _entete('Classe interne', 'PR-48'),
          const SizedBox(height: 7),
          if (choisie == null)
            _titre('Hors grille', _horsGrille)
          else
            _titre(choisie.label, Color(choisie.colorValue)),
          const SizedBox(height: 5),
          _justification(_motif()),
          if (choisie != null) _pastilleManuelle(),
          if (resultat.harmonieProposable) _caseHarmonie(),
          if (!readOnly) ...[
            const SizedBox(height: 10),
            _boutonChoisir(context, choisie),
          ],
        ],
      ),
    );
  }

  // ── Case « profil non harmonieux » — PR-48 §9 ─────────────────────────────
  Widget _caseHarmonie() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.only(top: 9),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x17000000))),
        ),
        child: InkWell(
          onTap: readOnly
              ? null
              : () => onHarmonieChanged?.call(!resultat.profilNonHarmonieux),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: resultat.profilNonHarmonieux,
                  onChanged: readOnly
                      ? null
                      : (v) => onHarmonieChanged?.call(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Profil non harmonieux : un attribut domine les autres',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF5D6B62), height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boutonChoisir(BuildContext context, ClasseInterne? choisie) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _ouvrirSelecteur(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: _horsGrille,
          side: const BorderSide(color: _horsGrille, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(
          choisie == null ? 'Choisir la classe' : 'Modifier la classe',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _pastilleManuelle() {
    final qui = [
      'Choisie manuellement',
      if (choisiePar != null && choisiePar!.isNotEmpty) choisiePar,
      if (choisieLe != null && choisieLe!.isNotEmpty) choisieLe,
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _horsGrille.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 12, color: _horsGrille),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                qui,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _horsGrille,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sélecteur manuel ──────────────────────────────────────────────────────
  Future<void> _ouvrirSelecteur(BuildContext context) async {
    final proposees = resultat.classesProposees;
    final exclues = resultat.profilNonHarmonieux && resultat.harmonieProposable;

    final choix = await showModalBottomSheet<ClasseInterne>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE3DF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choisir la classe interne',
                style: GoogleFonts.domine(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _motif(),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7A70), height: 1.4),
              ),
              if (exclues) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _horsGrille.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Extra A+ et Extra A sont retirées : la règle PR-48 les interdit à une '
                    'huile au profil non harmonieux.',
                    style: TextStyle(fontSize: 11.5, color: _horsGrille, height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...proposees.map((c) => _optionClasse(ctx, c)),
              if (resultat.classeManuelle != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Retirer la classe choisie'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!context.mounted) return;
    onClasseManuelleChanged?.call(choix);
  }

  Widget _optionClasse(BuildContext ctx, ClasseInterne classe) {
    final couleur = Color(classe.colorValue);
    final selectionnee = resultat.classeManuelle == classe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => Navigator.pop(ctx, classe),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selectionnee ? couleur : const Color(0xFFE2E6E3),
              width: selectionnee ? 1.8 : 1.2,
            ),
            color: selectionnee ? couleur.withValues(alpha: 0.06) : Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classe.label,
                      style: GoogleFonts.domine(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: couleur,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      classe.description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7A70),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectionnee)
                Icon(Icons.check_circle, size: 18, color: couleur),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fragments partagés ────────────────────────────────────────────────────
  Widget _entete(String label, String meta) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Color(0xFF8B968F),
          ),
        ),
        Text(
          meta,
          style: const TextStyle(fontSize: 10, color: _inactif),
        ),
      ],
    );
  }

  Widget _titre(String texte, Color couleur, {Color? dotColor}) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: dotColor ?? couleur,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texte,
            style: GoogleFonts.domine(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ),
      ],
    );
  }

  Widget _justification(String texte) => Text(
        texte,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7A70), height: 1.45),
      );

  String _criteres() =>
      'Fruité ${fruite.toStringAsFixed(1)} ${typeFruite.label.toLowerCase()} · '
      'Amertume ${amertume.toStringAsFixed(1)} · '
      'Piquant ${piquant.toStringAsFixed(1)}';

  String _motif() => motifHorsGrille(
        coi: resultat.coi,
        fruite: fruite,
        typeFruite: typeFruite,
        amertume: amertume,
        piquant: piquant,
        profilNonHarmonieux: resultat.profilNonHarmonieux,
      );
}
