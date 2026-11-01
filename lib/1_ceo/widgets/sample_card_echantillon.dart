// ═════════════════════════════════════════════════════════════════════════════
// FILE : shared/widgets/sample_card_widgets.dart
// Reusable sample-card widgets: DetailItem, SampleDetails, SampleRow.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart';

import '../utilisateurs/models/echantillon_ceo_view.dart';
import '../../core/widgets/grille_details.dart';
import '../../core/utils/montant_achat.dart';

const Color _green = Color(0xFF38835A);
const Color _white = Color.fromARGB(255, 255, 255, 255);
const Color _dark = Color(0xFF1A2E1F);
const Color _olive = Color(0xFF6B8143);
const Color _sageTint = Color(0xFFF2F5F0);

// ─────────────────────────────────────────────────────────────────────────────
// STATUT CONFIG  (public so callers can use it if needed)
// ─────────────────────────────────────────────────────────────────────────────
class StatutCfg {
  final Color color;
  final String label;
  const StatutCfg(this.color, this.label);
}

StatutCfg statutConfig(StatutCeo s) {
  switch (s) {
    case StatutCeo.selectionne:
      return StatutCfg(Colors.blue.shade400, 'Enregistré');
    case StatutCeo.enNegociation:
      return StatutCfg(Colors.orange.shade500, 'En négociation');
    case StatutCeo.achatConfirme:
      return const StatutCfg(_green, 'Achat confirmé');
    case StatutCeo.achatNonConclu:
      return StatutCfg(Colors.grey.shade600, 'Achat non conclu');
    case StatutCeo.refuse:
      return StatutCfg(Colors.red.shade400, 'Refusé');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL ITEM  — a small label + value column, used inside SampleDetails
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SAMPLE DETAILS  — expanded detail panel for one echantillon
// ─────────────────────────────────────────────────────────────────────────────
class SampleDetails extends StatefulWidget {
  final EchantillonCeoView e;
  const SampleDetails({super.key, required this.e});

  @override
  State<SampleDetails> createState() => _SampleDetailsState();
}

class _SampleDetailsState extends State<SampleDetails> {
  bool _purchaseExpanded = false;

  // Helper: wraps a string in the — sentence — gray style
  Text _dLine(String s) => Text(
    '— $s —',
    style: const TextStyle(
      fontSize: 13,
      color: Color(0xFF9C9B9B),
      fontWeight: FontWeight.w400,
    ),
  );

  Color _statutColor(StatutCeo s) {
    switch (s) {
      case StatutCeo.selectionne:
        return Colors.blue.shade500;
      case StatutCeo.enNegociation:
        return Colors.orange.shade600;
      case StatutCeo.achatConfirme:
        return _green;
      case StatutCeo.achatNonConclu:
        return Colors.grey.shade600;
      case StatutCeo.refuse:
        return Colors.red.shade500;
    }
  }

  String _statutLabel(StatutCeo s) {
    switch (s) {
      case StatutCeo.selectionne:
        return 'Enregistré';
      case StatutCeo.enNegociation:
        return 'En négociation';
      case StatutCeo.achatConfirme:
        return 'Achat confirmé';
      case StatutCeo.achatNonConclu:
        return 'Achat non conclu';
      case StatutCeo.refuse:
        return 'Refusé';
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final statutColor = _statutColor(e.statut);
    final statutLabel = _statutLabel(e.statut);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _green.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status badge (pill with border) ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statutColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statutColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statutLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: statutColor,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Detail grid ───────────────────────────────────────────────────
          GrilleDetails(
            items: [
              DetailItem('N° échantillon', e.numero),
              DetailItem('Ref. bouteille', e.referenceBouteille),
              DetailItem(
                'Gouvernorat',
                '${e.gouvernorat}${e.delegation != null ? " — ${e.delegation}" : ""}',
              ),
              DetailItem('Fournisseur', e.fournisseurAffichage),
              if (e.variete != null) DetailItem('Variété', e.variete!),
              if (e.numCiterne != null) DetailItem('N° citerne', e.numCiterne!),
              if (e.quantiteEstimee != null)
                DetailItem('Quantité', '${e.quantiteEstimee} T'),
              DetailItem('Enregistré le', _dateOuTiret(e.dateAjout)),
              if ((e.dateArriveeEchantillon?.isNotEmpty ?? false) ||
                  e.dateLivraisonPrevue != null)
                DetailItem(
                  'Livraison prévue',
                  (e.dateArriveeEchantillon?.isNotEmpty ?? false)
                      ? DegDateUtils.formaterDateHeureOuTiret(
                          e.dateArriveeEchantillon,
                        )
                      : DegDateUtils.formaterDateHeureOuTiret(
                          e.dateLivraisonPrevue,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 15),

          // ── Delivery section — layout depends on statut ───────────────────
          //
          // Enregistré : 4 sample delivery scenarios
          // En négociation : sample has arrived → show reception only
          // Achat confirmé : show reception + 4 stock delivery scenarios
          // Refusé : no delivery section
          if (e.statut == StatutCeo.selectionne) ...[
            if (e.recuPhysiquement)
              _dLine(
                e.dateReceptionEchantillon != null
                    ? 'Échantillon réceptionné le ${DegDateUtils.formaterDateHeureOuTiret(e.dateReceptionEchantillon)}'
                    : 'Échantillon réceptionné',
              )
            else if (e.dateLivraisonPrevue != null &&
                e.dateLivraisonPrevueFin != null)
              _dLine(
                'Échantillon attendu entre le ${DegDateUtils.formaterAffichage(e.dateLivraisonPrevue)} et le ${DegDateUtils.formaterAffichage(e.dateLivraisonPrevueFin)}',
              )
            else if ((e.dateArriveeEchantillon?.isNotEmpty ?? false) ||
                e.dateLivraisonPrevue != null)
              _dLine(
                'Échantillon attendu le ${DegDateUtils.formaterAffichage((e.dateArriveeEchantillon?.isNotEmpty ?? false) ? e.dateArriveeEchantillon : e.dateLivraisonPrevue)}',
              )
            else
              _dLine('Livraison de l\'échantillon non planifiée'),
          ] else if (e.statut == StatutCeo.enNegociation ||
              e.statut == StatutCeo.achatNonConclu) ...[
            _dLine(
              e.dateReceptionEchantillon != null
                  ? 'Échantillon réceptionné le ${DegDateUtils.formaterDateHeureOuTiret(e.dateReceptionEchantillon)}'
                  : 'Échantillon réceptionné',
            ),
          ] else if (e.statut == StatutCeo.achatConfirme) ...[
            _dLine(
              e.dateReceptionEchantillon != null
                  ? 'Échantillon réceptionné le ${DegDateUtils.formaterDateHeureOuTiret(e.dateReceptionEchantillon)}'
                  : 'Échantillon réceptionné',
            ),
            const SizedBox(height: 4),
            if (e.stockArrive)
              _dLine(
                e.dateLivraisonStock != null
                    ? 'Stock réceptionné le ${DegDateUtils.formaterDateHeureOuTiret(e.dateLivraisonStock)}'
                    : 'Stock réceptionné',
              )
            else if (e.dateLivraisonStock != null &&
                e.dateLivraisonStockFin != null)
              _dLine(
                'Stock attendu entre le ${DegDateUtils.formaterAffichage(e.dateLivraisonStock)} et le ${DegDateUtils.formaterAffichage(e.dateLivraisonStockFin)}',
              )
            else if (e.dateLivraisonStock != null)
              _dLine(
                'Stock attendu pour le ${DegDateUtils.formaterAffichage(e.dateLivraisonStock)}',
              )
            else
              _dLine('Livraison du stock non encore planifiée'),
          ],

          // ── Purchase details (collapsible, achat confirmé only) ───────────
          if (e.statut == StatutCeo.achatConfirme &&
              PurchaseDetailsPanel.aDesDetails(e)) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () =>
                  setState(() => _purchaseExpanded = !_purchaseExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.stockArrive
                        ? 'Détails de l\'achat'
                        : 'Détails de la commande',
                    style: TextStyle(
                      fontSize: 12,
                      color: statutColor,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: statutColor.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _purchaseExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: statutColor,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: PurchaseDetailsPanel(e: e, color: statutColor),
              crossFadeState: _purchaseExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],

          // ── Achat non conclu : raison du collecteur ───────────────────────
          if (e.statut == StatutCeo.achatNonConclu) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                (e.raisonNonConclu?.isNotEmpty ?? false)
                    ? 'Achat non conclu par le collecteur : ${e.raisonNonConclu}'
                    : 'Achat non conclu par le collecteur (aucune raison donnée)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ),
          ],

          // ── Refusal reason ────────────────────────────────────────────────
          if (e.statut == StatutCeo.refuse && e.raisonRefus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                'Raison du refus : ${e.raisonRefus}',
                style: TextStyle(fontSize: 13, color: Colors.red.shade700),
              ),
            ),
          ],

          // ── Remarks ───────────────────────────────────────────────────────
          if (e.remarques != null && e.remarques!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Remarques : ${e.remarques}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

String _dateOuTiret(String? iso) {
  return DegDateUtils.formaterDateHeureOuTiret(iso);
}

// ─────────────────────────────────────────────────────────────────────────────
// PURCHASE DETAILS PANEL  — collapsible receipt shown under "Détails de l'achat"
// ─────────────────────────────────────────────────────────────────────────────
class PurchaseDetailsPanel extends StatelessWidget {
  final EchantillonCeoView e;
  final Color color;
  const PurchaseDetailsPanel({super.key, required this.e, required this.color});

  static bool aDesDetails(EchantillonCeoView e) =>
      (e.prixFinal?.isNotEmpty ?? false) ||
      e.quantiteCibleT != null ||
      (e.numCiterne?.isNotEmpty ?? false) ||
      (e.remarqueCollecteur?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!aDesDetails(e)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: GrilleDetails(
        items: [
          if (e.prixFinal?.isNotEmpty ?? false)
            DetailItem(
              'Prix convenu',
              MontantAchat.formaterPrixParKg(e.prixFinal) ?? e.prixFinal!,
            ),
          if (e.quantiteCibleT != null)
            DetailItem('Quantité', '${e.quantiteCibleT} T'),
          if (MontantAchat.formater(e.prixFinal, e.quantiteCibleT) != null)
            DetailItem(
              'Montant total',
              MontantAchat.formater(e.prixFinal, e.quantiteCibleT)!,
            ),
          if (e.numCiterne?.isNotEmpty ?? false)
            DetailItem('N° citerne', e.numCiterne!),
          if (e.remarqueCollecteur?.isNotEmpty ?? false)
            DetailItem('Remarque du collecteur', e.remarqueCollecteur!),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAMPLE ROW  — one row in the collecteur list, with expandable details
// ─────────────────────────────────────────────────────────────────────────────
class SampleRow extends StatelessWidget {
  final EchantillonCeoView echantillon;
  final bool isExpanded;
  final bool isOdd;
  final bool isLast;
  final VoidCallback onToggle;

  const SampleRow({
    super.key,
    required this.echantillon,
    required this.isExpanded,
    required this.isOdd,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final e = echantillon;
    final cfg = statutConfig(e.statut);

    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: e.statut == StatutCeo.refuse
                ? Colors.red.shade50
                : isOdd
                ? _sageTint
                : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status dot
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: cfg.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),

                // Left: bottle reference (top) + sample number (bottom)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.referenceBouteille,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        e.numero,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 111, 111, 111),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: quantity (top) + date (bottom)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (e.quantiteEstimee != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _olive.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Qté : ${e.quantiteEstimee} T',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _olive,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                    const SizedBox(height: 2),
                    Text(
                      DegDateUtils.formaterAffichage(e.dateAjout),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color.fromARGB(255, 111, 111, 111),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),
                // Expand / collapse arrow
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated detail panel
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: SampleDetails(e: e),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        // Divider between rows
        if (!isLast)
          Divider(
            color: Colors.grey.shade100,
            height: 1,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}
