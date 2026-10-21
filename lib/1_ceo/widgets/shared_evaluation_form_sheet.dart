// ═════════════════════════════════════════════════════════════════════════════
// FILE : ceo/widgets/shared_evaluation_form_sheet.dart
// PURPOSE : Read-only full evaluation form — reused in:
//           - degustateur_detail_ceo_page.dart
//           - echantillon_detail_ceo_page.dart
//           - evaluations_panel_sheet.dart
// Shows every COI criterion with its value, same visual logic as
// FormulaireEvaluationPage but locked (read-only).
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/classification/classification_interne.dart';
import '../../core/models/enums.dart';
import '../utilisateurs/models/echantillon_ceo_view.dart';

const Color _green = Color(0xFF38835A);
const Color _olive = Color(0xFF6B8143);
const Color _cream = Color(0xFFF9F6EF);
const Color _dark = Color(0xFF1A2E1F);

// ── Entry point ───────────────────────────────────────────────────────────────
void showEvaluationFormSheet(
  BuildContext context, {
  required EvaluationOrganoleptique evaluation,
  required String sampleRef,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _EvaluationFormSheet(evaluation: evaluation, sampleRef: sampleRef),
  );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────
class _EvaluationFormSheet extends StatelessWidget {
  final EvaluationOrganoleptique evaluation;
  final String sampleRef;

  const _EvaluationFormSheet({
    required this.evaluation,
    required this.sampleRef,
  });

  @override
  Widget build(BuildContext context) {
    final ev = evaluation;
    final classColor = Color(ev.classification.colorValue);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: classColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (ev.tasteurNom != null && ev.tasteurNom!.isNotEmpty)
                          ? ev.tasteurNom![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: classColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev.tasteurNom ?? ev.tasteurId,
                        style: GoogleFonts.domine(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      Text(
                        'Fiche d\'évaluation — $sampleRef',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        _fmtDate(
                          DateTime.tryParse(ev.soumisLe) ?? DateTime.now(),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lock badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 11,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verrouillé',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Classification ─────────────────────────────────────────────
            _ClassificationCard(evaluation: ev),

            const SizedBox(height: 14),

            // ── Attributs positifs ─────────────────────────────────────────
            _buildCard(
              title: 'Attributs Positifs',
              icon: Icons.thumb_up_outlined,
              iconColor: _green,
              child: Column(
                children: [
                  if (ev.fruite != null)
                    _CriteriaRow(
                      label:
                          'Fruité'
                          '${ev.fruite! > 0 ? " — ${ev.typeFruite.label}" : ""}',
                      value: ev.fruite!,
                      isPositif: true,
                    ),
                  if (ev.amertume != null)
                    _CriteriaRow(
                      label: 'Amer',
                      value: ev.amertume!,
                      isPositif: true,
                    ),
                  if (ev.piquant != null)
                    _CriteriaRow(
                      label: 'Piquant',
                      value: ev.piquant!,
                      isPositif: true,
                    ),
                  if (ev.fruite == null &&
                      ev.amertume == null &&
                      ev.piquant == null)
                    _emptyHint('Aucun attribut positif renseigné'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Attributs négatifs ─────────────────────────────────────────
            _buildCard(
              title: 'Attributs Négatifs — Défauts',
              icon: Icons.warning_amber_outlined,
              iconColor: Colors.orange.shade700,
              child: Column(
                children: [
                  if (ev.chome != null && ev.chome! > 0)
                    _CriteriaRow(
                      label: 'Chômé / Lie de boue',
                      value: ev.chome!,
                      isPositif: false,
                    ),
                  if (ev.moisi != null && ev.moisi! > 0)
                    _CriteriaRow(
                      label: 'Moisi / Humide / Terreux',
                      value: ev.moisi!,
                      isPositif: false,
                    ),
                  if (ev.vinaigre != null && ev.vinaigre! > 0)
                    _CriteriaRow(
                      label: 'Vinaigré / Acide-Aigre',
                      value: ev.vinaigre!,
                      isPositif: false,
                    ),
                  if (ev.gele != null && ev.gele! > 0)
                    _CriteriaRow(
                      label: 'Gelé (Bois mouillé)',
                      value: ev.gele!,
                      isPositif: false,
                    ),
                  if (ev.rance != null && ev.rance! > 0)
                    _CriteriaRow(
                      label: 'Rance',
                      value: ev.rance!,
                      isPositif: false,
                    ),
                  if (ev.autresDefaut != null && ev.autresDefaut! > 0)
                    _CriteriaRow(
                      label:
                          ev.autresDefautNom != null &&
                              ev.autresDefautNom!.isNotEmpty
                          ? 'Autre — ${ev.autresDefautNom}'
                          : 'Autre défaut',
                      value: ev.autresDefaut!,
                      isPositif: false,
                    ),
                  // No defects at all
                  if ((ev.chome == null || ev.chome == 0) &&
                      (ev.moisi == null || ev.moisi == 0) &&
                      (ev.vinaigre == null || ev.vinaigre == 0) &&
                      (ev.gele == null || ev.gele == 0) &&
                      (ev.rance == null || ev.rance == 0) &&
                      (ev.autresDefaut == null || ev.autresDefaut == 0))
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: _green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Aucun défaut détecté',
                          style: TextStyle(
                            fontSize: 13,
                            color: _green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Notes libres ───────────────────────────────────────────────
            if (ev.commentaire != null && ev.commentaire!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCard(
                title: 'Notes du dégustateur',
                icon: Icons.notes_outlined,
                iconColor: Colors.grey.shade600,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ev.commentaire!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _olive,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _emptyHint(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Colors.grey.shade400,
      fontStyle: FontStyle.italic,
    ),
  );

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
      '  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Classification card ───────────────────────────────────────────────────────
class _ClassificationCard extends StatelessWidget {
  final EvaluationOrganoleptique evaluation;
  const _ClassificationCard({required this.evaluation});

  @override
  Widget build(BuildContext context) {
    final ev = evaluation;
    final classColor = Color(ev.classification.colorValue);
    final med = ev.medianeDefauts;

    Color bgColor;
    Color borderColor;
    if (ev.classification == ClassificationHuile.extraVierge) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
    } else if (ev.classification == ClassificationHuile.vierge) {
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
    } else if (ev.classification == ClassificationHuile.viergeOrdinaire) {
      bgColor = Colors.deepOrange.shade50;
      borderColor = Colors.deepOrange.shade200;
    } else {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 14,
                color: classColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Classification COI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _olive,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                'Méd. défaut : ${med.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ev.classification.label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: classColor,
            ),
          ),

          // ── Classe interne PR-48 — §6 : huiles extra vierges uniquement ──
          if (ev.classeInterne != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Color(ev.classeInterne!.colorValue)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'CLASSE INTERNE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'PR-48',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ev.classeInterne!.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(ev.classeInterne!.colorValue),
                    ),
                  ),
                  if (ev.classeInterneManuelle) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Choisie manuellement'
                      '${ev.classeInterneMotif?.isNotEmpty == true ? " — ${ev.classeInterneMotif}" : ""}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.orange.shade800,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (ev.profilNonHarmonieux) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Profil déclaré non harmonieux',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          // Value pills summary
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (ev.fruite != null && ev.fruite! > 0)
                _Pill(
                  'Fruité ${ev.typeFruite.label} : ${ev.fruite!.toStringAsFixed(1)}',
                  _green,
                ),
              if (ev.amertume != null && ev.amertume! > 0)
                _Pill('Amer : ${ev.amertume!.toStringAsFixed(1)}', _olive),
              if (ev.piquant != null && ev.piquant! > 0)
                _Pill('Piquant : ${ev.piquant!.toStringAsFixed(1)}', _olive),
              if (ev.chome != null && ev.chome! > 0)
                _Pill(
                  'Chômé : ${ev.chome!.toStringAsFixed(1)}',
                  Colors.orange.shade700,
                ),
              if (ev.moisi != null && ev.moisi! > 0)
                _Pill(
                  'Moisi : ${ev.moisi!.toStringAsFixed(1)}',
                  Colors.orange.shade700,
                ),
              if (ev.vinaigre != null && ev.vinaigre! > 0)
                _Pill(
                  'Vinaigré : ${ev.vinaigre!.toStringAsFixed(1)}',
                  Colors.red.shade600,
                ),
              if (ev.gele != null && ev.gele! > 0)
                _Pill(
                  'Gelé : ${ev.gele!.toStringAsFixed(1)}',
                  Colors.red.shade600,
                ),
              if (ev.rance != null && ev.rance! > 0)
                _Pill(
                  'Rance : ${ev.rance!.toStringAsFixed(1)}',
                  Colors.red.shade600,
                ),
              if (ev.autresDefaut != null && ev.autresDefaut! > 0)
                _Pill(
                  '${ev.autresDefautNom ?? "Autre"} : ${ev.autresDefaut!.toStringAsFixed(1)}',
                  Colors.red.shade600,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Criteria row with bar ─────────────────────────────────────────────────────
class _CriteriaRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isPositif;

  const _CriteriaRow({
    required this.label,
    required this.value,
    required this.isPositif,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositif ? _barColorPositif(value) : _barColorNegatif(value);
    final intensite = intensiteLabel(value, positif: isPositif);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPositif ? _green : _dark,
                  ),
                ),
              ),
              // Value badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (intensite.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
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
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 10,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          // Tick marks 0–10
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(11, (i) {
                final active = value >= i.toDouble();
                return Text(
                  '$i',
                  style: TextStyle(
                    fontSize: 9,
                    color: active ? color : Colors.grey.shade300,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _barColorPositif(double v) {
    if (v <= 3.0) return _green;
    if (v <= 6.0) return _olive;
    return Colors.teal.shade600;
  }

  Color _barColorNegatif(double v) {
    if (v <= 3.0) return Colors.green.shade600;
    if (v <= 6.0) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}

// ── Pill widget ───────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
