// ─────────────────────────────────────────────────────────────────────────────
// FILE : evaluation_echantillons/widgets/echantillon_card.dart
// PURPOSE : CEO-style card — flat tinted header (no gradient/colored shadow),
//           expandable detail panel, pill action buttons
//           — soumis: shows classification badge + "Voir" button (read-only)
//           — en cours/en attente: shows "Commencer/Continuer" + "Voir" pills
// ─────────────────────────────────────────────────────────────────────────────

import 'package:project3/core/widgets/details_echantillon.dart';
import 'package:flutter/material.dart';
import 'package:project3/core/models/echantillon_evaluation.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/widgets/grille_details.dart';
import 'package:project3/core/widgets/quantity_pill.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _white = Color.fromARGB(255, 255, 255, 255);

// ── Status palette (matching CEO) ─────────────────────────────────────────────
Color _statusColor(StatutEchantillon s) {
  switch (s) {
    case StatutEchantillon.enCours:
      return const Color(0xFFD07B2F);
    case StatutEchantillon.soumis:
      return const Color(0xFF38835A);
    default:
      return const Color(0xFF3A6EA5);
  }
}

Color _classifColor(String? c) {
  if (c == 'Extra Vierge') return const Color(0xFF38835A);
  if (c == 'Vierge') return const Color(0xFFD07B2F);
  if (c == 'Vierge Ordinaire') return const Color(0xFFE64A19);
  if (c == 'Lampante') return const Color(0xFFD32F2F);
  return Colors.grey.shade500;
}

// ─────────────────────────────────────────────────────────────────────────────
class EchantillonCard extends StatefulWidget {
  final Echantillon echantillon;
  final VoidCallback onAction; // Commencer / Continuer
  final VoidCallback? onVoir; // Voir l'évaluation soumise (read-only)
  final bool isHighlighted;

  const EchantillonCard({
    super.key,
    required this.echantillon,
    required this.onAction,
    this.onVoir,
    this.isHighlighted = false,
  });

  @override
  State<EchantillonCard> createState() => _EchantillonCardState();
}

class _EchantillonCardState extends State<EchantillonCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.echantillon;
    final accent = _statusColor(e.statut);
    final isSoumis = e.statut == StatutEchantillon.soumis;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isHighlighted
              ? const Color(0xFFD07B2F)
              : Colors.grey.shade200,
          width: widget.isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isHighlighted
                ? const Color(0xFFD07B2F).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: widget.isHighlighted ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header with left accent bar (always visible) ────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thick left accent bar (status indicator)
                  Container(width: 4, color: accent),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left: reference stacked above id
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.referenceBouteille.isNotEmpty
                                      ? e.referenceBouteille
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.numero ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right: classification badge above quantity pill (soumis)
                          //        OR just quantity pill (non-soumis)
                          if (isSoumis && e.classification != null) ...[
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _ClassificationBadge(e.classification!),
                                if (e.quantite != null &&
                                    e.quantite!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  QuantityPill(quantite: e.quantite!),
                                ],
                              ],
                            ),
                            const SizedBox(width: 6),
                          ] else if (e.quantite != null &&
                              e.quantite!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            QuantityPill(quantite: e.quantite!),
                            const SizedBox(width: 6),
                          ] else
                            const SizedBox(width: 6),
                          // Chevron
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable detail + action panel ─────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _DetailPanel(
              e: e,
              accent: accent,
              isSoumis: isSoumis,
              onAction: widget.onAction,
              onVoir: widget.onVoir,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSIFICATION BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _ClassificationBadge extends StatelessWidget {
  final String classification;
  const _ClassificationBadge(this.classification);

  @override
  Widget build(BuildContext context) {
    final color = _classifColor(classification);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        classification,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _DetailPanel extends StatelessWidget {
  final Echantillon e;
  final Color accent;
  final bool isSoumis;
  final VoidCallback onAction;
  final VoidCallback? onVoir;

  const _DetailPanel({
    required this.e,
    required this.accent,
    required this.isSoumis,
    required this.onAction,
    this.onVoir,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: Colors.grey.shade100, height: 1),

        // Info grid
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: GrilleDetails(
            items: [
              ...detailsEchantillon(
                numero: e.numero,
                referenceBouteille: e.referenceBouteille,
                fournisseur: e.fournisseur,
                variete: e.variete,
                gouvernorat: e.gouvernorat,
                delegation: e.delegation,
                collecteur: e.collecteur,
                numCiterne: e.numCiterne,
                dateAjout: e.dateAjout,
                recuPhysiquement: e.recuPhysiquement,
                dateArrivee: e.dateArriveeEchantillon,
                dateReception: e.dateReceptionEchantillon,
                dateLivraisonStock: e.dateLivraisonStock,
              ),
              if (isSoumis && e.classification != null)
                DetailItem('Classification', e.classification!),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Action row — pill-style buttons ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              if (!isSoumis) ...[
                // Commencer / Continuer
                _PillButton(
                  label: e.statut == StatutEchantillon.enAttente
                      ? 'Commencer'
                      : 'Continuer',
                  icon: e.statut == StatutEchantillon.enAttente
                      ? Icons.play_arrow_rounded
                      : Icons.edit_outlined,
                  color: accent,
                  filled: true,
                  onTap: onAction,
                ),
                if (onVoir != null) ...[
                  const SizedBox(width: 8),
                  _PillButton(
                    label: 'Voir',
                    icon: Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                    filled: false,
                    onTap: onVoir!,
                  ),
                ],
              ] else ...[
                // Soumis — only "Voir" (read-only)
                _PillButton(
                  label: 'Voir l\'évaluation',
                  icon: Icons.visibility_outlined,
                  color: _green,
                  filled: false,
                  onTap: onVoir ?? () {},
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _dateOuTiret(String? iso) {
  final texte = DegDateUtils.formaterDateHeure(iso);
  return texte.isEmpty ? '—' : texte;
}

// ─────────────────────────────────────────────────────────────────────────────
// PILL BUTTON — compact, inline action
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: filled ? color : color.withValues(alpha: 0.3),
          width: filled ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: filled ? Colors.white : color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL ITEM — label (grey) above value (dark bold)
// ─────────────────────────────────────────────────────────────────────────────
