import 'package:flutter/material.dart';
import 'sample_card_echantillon.dart'; // DetailItem lives here
import '../../core/utils/date_utils.dart';
import '../utilisateurs/models/echantillon_ceo_view.dart';
import '../../core/widgets/grille_details.dart';

const Color _dark = Color(0xFF1A2E1F);
const Color _white = Color.fromARGB(255, 255, 255, 255);

// ─────────────────────────────────────────────────────────────────────────────
// BASE SAMPLE CARD
// ─────────────────────────────────────────────────────────────────────────────
class BaseSampleCard extends StatefulWidget {
  final String referenceBouteille;
  final String numero;
  final Color tintColor;
  final Color? accentColor; // left accent bar color (collecteur-style)
  /// Sans badge, la référence prend toute la largeur de l'en-tête.
  final Widget? badge;

  /// Cellules du panneau de détails — voir [GrilleDetails.items].
  final List<Widget> detailItems;
  final Widget? bottomSection;

  final Widget? deliveryWidget;

  const BaseSampleCard({
    super.key,
    required this.referenceBouteille,
    String? numero,
    String? id,
    required this.tintColor,
    this.accentColor,
    this.badge,
    required this.detailItems,
    this.bottomSection,
    this.deliveryWidget,
  }) : numero = numero ?? id ?? '';

  @override
  State<BaseSampleCard> createState() => _BaseSampleCardState();
}

class _BaseSampleCardState extends State<BaseSampleCard> {
  bool _detailExpanded = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header with left accent bar ────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _detailExpanded = !_detailExpanded),
            behavior: HitTestBehavior.opaque,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  if (accent != null) Container(width: 4, color: accent),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.referenceBouteille,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                    letterSpacing: -0.2,
                                  ),
                                  // Sans badge à côté, une longue référence
                                  // passe à la ligne au lieu d'être coupée.
                                  maxLines: widget.badge == null ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.numero,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                  // Sans ça, un en-tête trop chargé écrasait la
                                  // référence en une colonne d'un caractère.
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Le badge occupe la moitié droite et s'y aligne à
                          // droite : sans ça, il restait collé au titre et la
                          // moitié de la carte tombait en vide après le
                          // chevron. Il cède quand même de la place au lieu de
                          // déborder — certains badges s'ouvrent au clic et
                          // deviennent bien plus larges que la carte.
                          if (widget.badge != null)
                            Expanded(child: widget.badge!),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: _detailExpanded ? 0.5 : 0.0,
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

          // ── Expandable detail panel ──────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _DetailPanel(
              items: widget.detailItems,
              deliveryWidget: widget.deliveryWidget,
            ),
            crossFadeState: _detailExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // ── Optional bottom section ──────────────────────────────────
          if (widget.bottomSection != null) ...[
            Divider(color: Colors.grey.shade100, height: 1),
            widget.bottomSection!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _DetailPanel extends StatelessWidget {
  final List<Widget> items;
  final Widget? deliveryWidget;
  const _DetailPanel({required this.items, this.deliveryWidget});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GrilleDetails(items: items),
        if (deliveryWidget != null) ...[
          const SizedBox(height: 12),
          deliveryWidget!,
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD BADGE HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class CardBadge extends StatelessWidget {
  final String label;
  final Color color;

  const CardBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class CardBadgeRow extends StatelessWidget {
  final List<Widget> badges;
  const CardBadgeRow({super.key, required this.badges});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    // Les badges se rangent contre le chevron, à droite de la carte, plutôt
    // que de flotter au milieu.
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      for (int i = 0; i < badges.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        // Chaque badge cède de la place plutôt que de pousser ses voisins hors
        // de la carte. Certains s'ouvrent au clic sur un texte long.
        Flexible(child: badges[i]),
      ],
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SAMPLE DELIVERY INDICATOR
// Full 6-state delivery section matching SampleDetails in sample_card_widgets.
// ─────────────────────────────────────────────────────────────────────────────
class SampleDeliveryIndicator extends StatelessWidget {
  final EchantillonCeoView e;
  final Color accentColor;
  const SampleDeliveryIndicator({
    super.key,
    required this.e,
    this.accentColor = const Color(0xFF38835A),
  });

  static const TextStyle _greyStyle = TextStyle(
    fontSize: 13,
    color: Color(0xFF9C9B9B),
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) {
    if (e.stockArrive) {
      // ① Stock physically arrived
      return Text(
        e.dateLivraisonStock != null
            ? '— Stock réceptionné le ${DegDateUtils.formaterDateHeureOuTiret(e.dateLivraisonStock)} —'
            : '— Stock réceptionné —',
        style: _greyStyle,
      );
    } else if (e.dateLivraisonStock != null) {
      // ② Stock delivery date set but not yet received
      return Text(
        '— Livraison du stock prévue le ${DegDateUtils.formaterDateHeureOuTiret(e.dateLivraisonStock)} —',
        style: _greyStyle,
      );
    } else if (e.recuPhysiquement) {
      // ③ Sample physically received
      return Text(
        e.dateReceptionEchantillon != null
            ? '— Échantillon réceptionné le ${DegDateUtils.formaterDateHeureOuTiret(e.dateReceptionEchantillon)} —'
            : '— Échantillon réceptionné —',
        style: _greyStyle,
      );
    } else if ((e.dateArriveeEchantillon?.isNotEmpty ?? false) ||
        e.dateLivraisonPrevue != null) {
      // ④ Delivery date announced but not yet arrived
      final dateAnnoncee = (e.dateArriveeEchantillon?.isNotEmpty ?? false)
          ? e.dateArriveeEchantillon
          : e.dateLivraisonPrevue;
      return Text(
        '— Arrivée prévue le ${DegDateUtils.formaterDateHeureOuTiret(dateAnnoncee)} —',
        style: _greyStyle,
      );
    } else if (e.statut == StatutCeo.enNegociation ||
        e.statut == StatutCeo.achatConfirme) {
      // ⑤ Purchase confirmed but no stock delivery date yet
      return const Text(
        '— Livraison du stock non programmée —',
        style: _greyStyle,
      );
    } else {
      // ⑥ Sample registered, no delivery date announced
      return const Text('— Livraison non planifiée —', style: _greyStyle);
    }
  }
}
