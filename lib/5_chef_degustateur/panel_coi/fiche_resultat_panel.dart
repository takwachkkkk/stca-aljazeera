// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 5_chef_degustateur/panel_coi/fiche_resultat_panel.dart
// PURPOSE : Fiche « Résultat du panel » d'un échantillon (méthode COI_CALC),
//           ouverte depuis la vue d'ensemble et depuis le tableau de bord.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/enums.dart';
import '../../core/utils/date_utils.dart';
import 'resultat_panel.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _rouge = Color(0xFFC0392B);

String _n(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 1 : 2);

/// Charge le résultat d'un échantillon puis ouvre la fiche.
Future<void> ouvrirResultatPanel(
  BuildContext context,
  String echantillonId, {
  ResultatPanelService? service,
}) async {
  final messager = ScaffoldMessenger.of(context);
  try {
    final resultat = await (service ?? ResultatPanelService()).fetchEchantillon(
      echantillonId,
    );
    if (!context.mounted) return;
    if (resultat == null) {
      messager.showSnackBar(
        const SnackBar(
          content: Text("Aucune évaluation soumise pour cet échantillon."),
        ),
      );
      return;
    }
    await afficherResultatPanel(context, resultat);
  } catch (_) {
    messager.showSnackBar(
      const SnackBar(
        content: Text('Impossible de charger le résultat du panel.'),
      ),
    );
  }
}

Future<void> afficherResultatPanel(BuildContext context, ResultatPanel r) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controleur) =>
            FicheResultatPanel(resultat: r, controleur: controleur),
      ),
    );

class FicheResultatPanel extends StatelessWidget {
  final ResultatPanel resultat;
  final ScrollController? controleur;

  const FicheResultatPanel({
    super.key,
    required this.resultat,
    this.controleur,
  });

  @override
  Widget build(BuildContext context) {
    final r = resultat;
    final categorie = r.classification;
    final couleur = categorie == null
        ? Colors.grey
        : Color(categorie.colorValue);
    final defauts = r.attributs.where((a) => !a.positif).toList();
    final positifs = r.attributs.where((a) => a.positif).toList();

    return ListView(
      controller: controleur,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Résultat du panel',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            r.numero ?? r.referenceBouteille,
            if ((r.variete ?? '').isNotEmpty) r.variete!,
            if (r.derniereSoumission != null)
              'dernière évaluation le ${DegDateUtils.formaterAffichage(r.derniereSoumission!.toIso8601String())}',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),

        // ── Catégorie et fiabilité ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: couleur.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categorie?.label ?? 'Aucun attribut perçu',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: couleur,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Médiane du défaut principal : ${_n(r.medianeDefautPrincipal)}'
                '${r.defautPrincipal != null ? ' (${r.defautPrincipal})' : ''}'
                ' · Médiane du fruité : ${_n(r.medianeFruite)}'
                '${r.typeFruiteMajoritaire != null ? ' (${r.typeFruiteMajoritaire!.label.toLowerCase()})' : ''}',
                style: const TextStyle(fontSize: 12, color: _dark),
              ),
              const SizedBox(height: 4),
              Text(
                '${r.nombreDegustateurs} dégustateur${r.nombreDegustateurs > 1 ? 's' : ''} '
                'ont soumis leur évaluation.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              _fiabilite(r),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _tableau('Défauts', defauts, r.cvrMax),
        const SizedBox(height: 16),
        _tableau('Attributs positifs', positifs, r.cvrMax),
        const SizedBox(height: 16),
        Text(
          'Méthode du COI (fichier COI_CALC) : médiane des notes de tous les '
          'dégustateurs ; CVr = écart robuste ÷ médiane × 100, fiable jusqu\'à '
          '${r.cvrMax.toStringAsFixed(0)} % ; l\'intervalle donne la plage où se '
          'trouve la vraie médiane à 95 %. La catégorie vient de la médiane du '
          'défaut le plus fort et de celle du fruité.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _fiabilite(ResultatPanel r) {
    final ok = r.fiable;
    return Row(
      children: [
        Icon(
          ok ? Icons.verified_outlined : Icons.warning_amber_rounded,
          size: 18,
          color: ok ? _green : _rouge,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ok
                ? 'Panel fiable : les notes décisives sont cohérentes (CVr ≤ ${r.cvrMax.toStringAsFixed(0)} %).'
                : 'Panel peu fiable : les dégustateurs sont trop dispersés '
                      '(CVr > ${r.cvrMax.toStringAsFixed(0)} %). Le COI conseille de refaire la dégustation.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ok ? _green : _rouge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableau(
    String titre,
    List<StatistiqueAttribut> lignes,
    double cvrMax,
  ) {
    TextStyle entete = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade600,
    );
    const valeur = TextStyle(fontSize: 12, color: _dark);

    Widget cellule(String texte, {TextStyle? style, TextAlign? align}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Text(
            texte,
            textAlign: align ?? TextAlign.right,
            style: style ?? valeur,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 6),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.4),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(2),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200),
          ),
          children: [
            TableRow(
              children: [
                cellule('Attribut', style: entete, align: TextAlign.left),
                cellule('Médiane', style: entete),
                cellule('CVr %', style: entete),
                cellule('Intervalle 95 %', style: entete),
              ],
            ),
            for (final a in lignes)
              TableRow(
                children: [
                  cellule(a.libelle, align: TextAlign.left),
                  cellule(
                    _n(a.mediane),
                    style: valeur.copyWith(fontWeight: FontWeight.w700),
                  ),
                  cellule(
                    a.cvr == null ? '—' : a.cvr!.toStringAsFixed(1),
                    style: a.cvr != null && a.cvr! > cvrMax
                        ? valeur.copyWith(
                            color: _rouge,
                            fontWeight: FontWeight.w700,
                          )
                        : valeur,
                  ),
                  cellule(
                    a.mediane == 0 && a.iqr == 0
                        ? '—'
                        : '${_n(a.icBas < 0 ? 0 : a.icBas)} – ${_n(a.icHaut)}',
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
