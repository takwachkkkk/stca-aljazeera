// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/analyse_organoleptique/widgets/panel_widgets.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/models/enums.dart';
import 'package:project3/core/theme/app_colors.dart';
import '../../utilisateurs/models/echantillon_ceo_view.dart';
import '../../widgets/shared_evaluation_form_sheet.dart';
import '../../widgets/base_sample_card.dart';
import '../models/sample_status.dart';
import '../../../../2_collecteur/mes_echantillons/widgets/dialogs/formulaire_sections.dart'
    show DateLivraisonSection, ModePlanificationUI;

// Small pill-shaped decision button
class DecisionButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool dimmed;
  final Color activeColor;
  final VoidCallback onTap;

  const DecisionButton({
    required this.label,
    required this.active,
    required this.dimmed,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveGray = Color(0xFFB4B2A9);

    return Opacity(
      opacity: dimmed ? 0.38 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.35)
                  : inactiveGray.withValues(alpha: 0.45),
              width: active ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? activeColor : inactiveGray,
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
// PANEL LIST
// ─────────────────────────────────────────────────────────────────────────────
class PanelList extends StatelessWidget {
  final EchantillonCeoView echantillon;
  final void Function(EvaluationOrganoleptique) onViewForm;
  const PanelList({super.key, required this.echantillon, required this.onViewForm});

  @override
  Widget build(BuildContext context) {
    final e = echantillon;

    // Empty state — always show the panel box, just with a message
    if (e.evaluations.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2EFE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Center(
          child: Text(
            'Aucune évaluation soumise',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EFE7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: e.evaluations.map((ev) {
          final classColor = Color(ev.classification.colorValue);
          final classeInterne = ev.classeInterne;
          // Nom en entier (plus de pastille d'initiale, police plus petite,
          // deux lignes au besoin), puis catégorie COI et classe interne ;
          // l'icône « fiche » ouvre le formulaire.
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev.tasteurNom ?? 'Dégustateur',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                        maxLines: 2,
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          CardBadge(
                            label: ev.classification.label,
                            color: classColor,
                          ),
                          if (classeInterne != null)
                            CardBadge(
                              label: classeInterne.label,
                              color: kGreen,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Voir le formulaire',
                  onPressed: () => onViewForm(ev),
                  icon: const Icon(Icons.description_outlined, color: kGreen),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECU PHYSIQUE INDICATOR
// Mimics the look of the tick in echantillon_card: filled/outlined check_circle
// icon with an animated inline pill that appears on tap and auto-dismisses.
// ─────────────────────────────────────────────────────────────────────────────
class RecuPhysiqueIndicator extends StatefulWidget {
  final bool recuPhysiquement;
  const RecuPhysiqueIndicator({super.key, required this.recuPhysiquement});

  @override
  State<RecuPhysiqueIndicator> createState() => _RecuPhysiqueIndicatorState();
}

class _RecuPhysiqueIndicatorState extends State<RecuPhysiqueIndicator> {
  bool _showPill = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap() {
    _timer?.cancel();
    setState(() => _showPill = true);
    // Same 6 s as the taster's sample card.
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showPill = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF38835A);
    // Nothing to show until the sample has physically arrived.
    if (!widget.recuPhysiquement) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated inline pill (same pattern as echantillon_card)
            // Flexible : la pastille dépliée réclamait sinon sa largeur
            // naturelle et poussait tout l'en-tête hors de la carte.
            Flexible(
              child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showPill && widget.recuPhysiquement
                  ? Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          // Same one-line pill as the taster's sample card.
                          Flexible(
                            child: Text(
                              'Réception physique confirmée',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
            ),
            // Animated icon (same as echantillon_card tick)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.recuPhysiquement
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                key: ValueKey(widget.recuPhysiquement),
                size: 20,
                color: widget.recuPhysiquement ? green : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
