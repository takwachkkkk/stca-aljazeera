import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _white = Color(0xFFFFFFFF);

const _supplierGreenStops = [
  Color(0xFF38835A), Color(0xFF4E9A72), Color(0xFF62AD88),
  Color(0xFF84C4A0), Color(0xFFA8D6BC),
];

/// Horizontal bar chart showing each supplier's share of total purchases.
class SupplierFrequencyCard extends StatelessWidget {
  final List<FournisseurStat> suppliers;
  final CardDateRange dateRange;
  final Widget Function(CardDateRange, VoidCallback) dateChipBuilder;
  final void Function(CardDateRange) onRangeChanged;

  const SupplierFrequencyCard({
    super.key,
    required this.suppliers,
    required this.dateRange,
    required this.dateChipBuilder,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalAchats = suppliers.fold(0, (s, e) => s + e.achats);
    final effectiveTotal = totalAchats == 0 ? 1 : totalAchats;

    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(child: _sectionLabel('Fournisseurs', Icons.storefront_outlined)),
                dateChipBuilder(dateRange, () {}),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Part des achats par fournisseur',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${suppliers.length} au total',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _green),
                  ),
                ),
              ],
            ),
          ),
          if (suppliers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text(
                'Aucun achat confirmé sur cette période.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            )
          else
          SizedBox(
            height: 212,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: suppliers.length,
              itemBuilder: (_, i) {
                final s = suppliers[i];
                final share = s.achats / effectiveTotal;
                final pct = (share * 100).toStringAsFixed(1);
                final color = _supplierGreenStops[i.clamp(0, _supplierGreenStops.length - 1)];
                return Padding(
                  padding: EdgeInsets.only(bottom: i < suppliers.length - 1 ? 14 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Le nom a toute la largeur : il n'est jamais coupé.
                      Row(
                        children: [
                          Expanded(child: _NomFournisseur(s.name)),
                          const SizedBox(width: 10),
                          Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _green)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 10,
                            color: const Color(0xFFEEF4F0),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: share),
                              duration: Duration(milliseconds: 800 + i * 120),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: v.clamp(0.05, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.region, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          Text('${s.achats} achat${s.achats > 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (suppliers.length > 3) ...[
          Container(height: 1, color: Colors.black.withValues(alpha: 0.05)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Faites défiler pour voir tous les fournisseurs',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }
}

/// Le nom complet s'il tient sur la ligne, sinon « James.N ».
class _NomFournisseur extends StatelessWidget {
  final String nom;

  const _NomFournisseur(this.nom);

  static const _style = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final mesure = TextPainter(
          text: TextSpan(text: nom, style: _style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final tientSurLaLigne = mesure.width <= contraintes.maxWidth;
        mesure.dispose();
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            tientSurLaLigne ? nom : nomFournisseurCourt(nom),
            style: _style,
            maxLines: 1,
          ),
        );
      },
    );
  }
}

Widget _sectionLabel(String text, IconData icon) => Row(
  children: [
    Container(
      width: 3, height: 16,
      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(width: 8),
    Icon(icon, size: 14, color: _green),
    const SizedBox(width: 6),
    Flexible(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark))),
  ],
);

BoxDecoration _cardDeco() => BoxDecoration(
  color: _white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
  boxShadow: [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ],
);
