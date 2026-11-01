// ═════════════════════════════════════════════════════════════════════════════
// FILE : 1_ceo/achats_confirmes/widgets/achat_section.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/theme/app_colors.dart';
import '../../utilisateurs/models/echantillon_ceo_view.dart';
import '../../widgets/sample_card_echantillon.dart';
import '../../../core/widgets/grille_details.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/montant_achat.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ACHAT SECTION
// ─────────────────────────────────────────────────────────────────────────────
class AchatSection extends StatelessWidget {
  final EchantillonCeoView echantillon;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AchatSection({
    required this.echantillon,
    required this.accentColor,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final e = echantillon;
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  e.stockArrive
                      ? Icons.inventory_2_outlined
                      : Icons.local_shipping_outlined,
                  size: 13,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Détails de l\'achat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: AchatDetails(echantillon: e, accentColor: accentColor),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHAT DETAILS
// ─────────────────────────────────────────────────────────────────────────────
class AchatDetails extends StatelessWidget {
  final EchantillonCeoView echantillon;
  final Color accentColor;
  const AchatDetails({
    super.key,
    required this.echantillon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final e = echantillon;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails de l\'achat',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kOlive,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          GrilleDetails(
            items: [
              if (e.quantiteCibleT != null)
                DetailItem('Quantité achetée', '${e.quantiteCibleT} T'),
              if (MontantAchat.formaterPrixParKg(e.budgetNegociation) != null)
                DetailItem(
                  'Prix négocié',
                  MontantAchat.formaterPrixParKg(e.budgetNegociation)!,
                ),
              if (e.camionReserve != null)
                DetailItem('Camion réservé', e.camionReserve!),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  e.stockArrive
                      ? Icons.inventory_2_rounded
                      : Icons.local_shipping_outlined,
                  size: 14,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.stockArrive
                        ? 'Stock arrivé en entrepôt${e.dateLivraisonStock != null ? " — ${DegDateUtils.formaterDateHeureOuTiret(e.dateLivraisonStock)}" : ""}'
                        : 'En transit${e.dateLivraisonStock != null ? " — Livraison prévue : ${DegDateUtils.formaterDateHeureOuTiret(e.dateLivraisonStock)}" : ""}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (e.noteInterne != null && e.noteInterne!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes_outlined,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e.noteInterne!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP  — replaces old _FilterBtn
// Active "Tout"  → solid gray (#757575) bg + white text  (mirrors utilisateurs)
// Active status  → tinted bg + colored text
// Inactive any   → light gray bg + gray text
// ─────────────────────────────────────────────────────────────────────────────
class AchatFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeBg;
  final Color activeFg;
  final VoidCallback onTap;

  const AchatFilterChip({
    required this.label,
    required this.isActive,
    required this.activeBg,
    required this.activeFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color inactiveBg = Color(0xFFF0F0F0);
    const Color inactiveFg = Color(0xFF9E9E9E);

    final bg = isActive ? activeBg : inactiveBg;
    final fg = isActive ? activeFg : inactiveFg;
    final borderColor = isActive
        ? activeFg.withValues(alpha: activeFg == Colors.white ? 0.0 : 0.3)
        : const Color(0xFFE0E0E0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
