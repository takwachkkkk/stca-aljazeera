// ═════════════════════════════════════════════════════════════════════════════
// FILE : laboratoire/echantillons_labo/widgets/echantillon_labo_card.dart
// PURPOSE : Expandable card for a lab sample — accent bar for analysis status,
//           inline icon actions, expandable detail panel with all attributes.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/echantillon_labo.dart';
import '../../analyse_labo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/grille_details.dart';

Color _accentColor(StatutAnalyse s) {
  switch (s) {
    case StatutAnalyse.enAttente:
      return kStatusBlue;
    case StatutAnalyse.enCours:
      return kStatusOrange;
    case StatutAnalyse.soumis:
      return kStatusGreen;
  }
}

class EchantillonLaboCard extends StatefulWidget {
  final EchantillonLabo echantillon;
  final VoidCallback? onAjouterAnalyse;
  final VoidCallback? onVoirAnalyse;
  final VoidCallback? onModifierAnalyse;
  final VoidCallback? onSupprimerAnalyse;

  const EchantillonLaboCard({
    super.key,
    required this.echantillon,
    this.onAjouterAnalyse,
    this.onVoirAnalyse,
    this.onModifierAnalyse,
    this.onSupprimerAnalyse,
  });

  @override
  State<EchantillonLaboCard> createState() => _EchantillonLaboCardState();
}

class _EchantillonLaboCardState extends State<EchantillonLaboCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.echantillon;
    final hasAnalyse = e.analyse != null;
    // Red ribbon while an urgent analysis is still to be done.
    final accent = e.priorite == PrioriteLabo.urgente &&
            e.statutAnalyse != StatutAnalyse.soumis
        ? const Color(0xFFC62828)
        : _accentColor(e.statutAnalyse);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header (always visible) ──────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thick left accent bar
                  Container(width: 4, color: accent),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Row 1: bottle reference + qty pill + chevron ──────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  e.referenceBouteille.isNotEmpty
                                      ? e.referenceBouteille
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: kDark,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (e.quantiteEstimee != null &&
                                  e.quantiteEstimee!.isNotEmpty) ...[
                                _QuantityPill(quantite: e.quantiteEstimee!),
                                const SizedBox(width: 8),
                              ],
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

                          const SizedBox(height: 2),

                          // ── Row 2: numero + action icons (only when expanded)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                e.numero,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const Spacer(),
                              if (_expanded) ...[
                                if (!hasAnalyse &&
                                    widget.onAjouterAnalyse != null)
                                  GestureDetector(
                                    onTap: widget.onAjouterAnalyse!,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kGreen.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: kGreen.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline,
                                            size: 14,
                                            color: kGreen,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Ajouter une analyse',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: kGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (hasAnalyse) ...[
                                  Tooltip(
                                    message: 'Voir rapport',
                                    child: _SmallIconBtn(
                                      icon: Icons.visibility_outlined,
                                      color: kGreen,
                                      onTap: widget.onVoirAnalyse ?? () {},
                                    ),
                                  ),
                                  if (widget.onModifierAnalyse != null) ...[
                                    const SizedBox(width: 2),
                                    Tooltip(
                                      message: 'Modifier',
                                      child: _SmallIconBtn(
                                        icon: Icons.edit_outlined,
                                        color: Colors.orange.shade700,
                                        onTap: widget.onModifierAnalyse!,
                                      ),
                                    ),
                                  ],
                                  if (widget.onSupprimerAnalyse != null) ...[
                                    const SizedBox(width: 2),
                                    Tooltip(
                                      message: 'Supprimer l\'analyse',
                                      child: _SmallIconBtn(
                                        icon: Icons.delete_outline,
                                        color: Colors.red.shade600,
                                        onTap: widget.onSupprimerAnalyse!,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable detail panel ──────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _DetailPanel(e: e, accentColor: accent),
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
// SMALL ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Icon(icon, size: 18, color: color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// QUANTITY PILL
// ─────────────────────────────────────────────────────────────────────────────
class _QuantityPill extends StatelessWidget {
  final String quantite;
  const _QuantityPill({required this.quantite});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: kOlive.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: kOlive.withValues(alpha: 0.22)),
    ),
    child: Text(
      'Qté : $quantite T',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kOlive,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PANEL — expandable with all lab attributes + analysis summary
// ─────────────────────────────────────────────────────────────────────────────
class _DetailPanel extends StatelessWidget {
  final EchantillonLabo e;
  final Color accentColor;

  const _DetailPanel({required this.e, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: Colors.grey.shade100, height: 1),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GrilleDetails(
                items: [
                  DetailItem('N° échantillon', e.numero),
                  DetailItem('Réf. bouteille', e.referenceBouteille),
                  DetailItem('Gouvernorat', e.gouvernorat),
                  DetailItem('Fournisseur', e.fournisseurTexte),
                  DetailItem('Collecteur', e.collecteurNom),
                  DetailItem(
                    'Date arrivée',
                    DegDateUtils.formaterAffichage(e.dateArrivee),
                  ),
                  DetailItem('Enregistré le', _dateOuTiret(e.dateAjout)),
                  if (e.variete != null && e.variete!.isNotEmpty)
                    DetailItem('Variété', e.variete!),
                  if (e.origineCampagne != null && e.origineCampagne!.isNotEmpty)
                    DetailItem('Campagne', e.origineCampagne!),
                ],
              ),
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
// DETAIL ITEM
// ─────────────────────────────────────────────────────────────────────────────
