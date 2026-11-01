import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _amber = Color(0xFFD07B2F);
const Color _blue = Color(0xFF3A6EA5);
const Color _red = Color(0xFFC0392B);
const Color _white = Color(0xFFFFFFFF);

/// Scrollable bar chart comparing collector performance across three metrics:
/// total purchase value, sample count, and approval rate.
class CollectorSection extends StatelessWidget {
  final List<CollecteurDashStat> collectors;
  final int selectedMetric;
  final CardDateRange dateRange;
  final ValueChanged<int> onMetricChanged;
  final Widget Function(CardDateRange, VoidCallback) dateChipBuilder;
  final void Function(CardDateRange) onRangeChanged;

  const CollectorSection({
    super.key,
    required this.collectors,
    required this.selectedMetric,
    required this.dateRange,
    required this.onMetricChanged,
    required this.dateChipBuilder,
    required this.onRangeChanged,
  });

  // ── Metric helpers ──────────────────────────────────────────────────────────

  String _metricDesc(int metric) {
    switch (metric) {
      case 0: return 'Montant total (TND) des achats confirmés par collecteur sur la période';
      case 1: return 'Nombre d\'échantillons collectés et soumis à l\'évaluation qualité';
      default: return 'Taux d\'approbation : part des échantillons acceptés pour l\'achat par la direction';
    }
  }

  List<CollecteurDashStat> _sorted(int metric) {
    final list = List<CollecteurDashStat>.from(collectors);
    if (metric == 0) {
      list.sort((a, b) => b.totalValue.compareTo(a.totalValue));
    } else if (metric == 1) {
      list.sort((a, b) => b.samples.compareTo(a.samples));
    } else {
      list.sort((a, b) => b.approvalRate.compareTo(a.approvalRate));
    }
    return list;
  }

  double _maxRaw(int metric, List<CollecteurDashStat> sorted) {
    // Une période sans achat ne doit pas diviser par zéro.
    final max = metric == 0
        ? sorted.first.totalValue.toDouble()
        : metric == 1
        ? sorted.first.samples.toDouble()
        : 1.0;
    return max > 0 ? max : 1.0;
  }

  String _yLabel(double frac, int metric, double maxRaw) {
    final val = maxRaw * frac;
    if (metric == 0) return '${(val / 1000).toStringAsFixed(0)}k';
    if (metric == 1) return val.toInt().toString();
    return '${(val * 100).toInt()}%';
  }

  double _barFraction(CollecteurDashStat c, int metric, double maxRaw) {
    if (metric == 0) return c.totalValue / maxRaw;
    if (metric == 1) return c.samples / maxRaw;
    return c.approvalRate;
  }

  Color _barColor(CollecteurDashStat c, int metric) {
    if (metric == 2) {
      if (c.approvalRate >= 0.75) return _green;
      if (c.approvalRate >= 0.50) return _amber;
      return _red;
    }
    return metric == 0 ? _green : _blue;
  }

  String _barTopLabel(CollecteurDashStat c, int metric) {
    if (metric == 0) return '${(c.totalValue / 1000).toStringAsFixed(0)}k TND';
    if (metric == 1) return '${c.samples} éch.';
    return '${(c.approvalRate * 100).toInt()}%';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(child: _sectionLabel('Performance collecteurs', Icons.leaderboard_outlined)),
                dateChipBuilder(dateRange, () {}),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Metric tabs
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: List.generate(3, (i) {
                const tabLabels = ['Valeur', 'Échantillons', 'Approbation'];
                final sel = selectedMetric == i;
                return GestureDetector(
                  onTap: () => onMetricChanged(i),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: sel ? const BorderSide(color: _dark, width: 2) : BorderSide.none),
                    ),
                    child: Text(
                      tabLabels[i],
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: sel ? _dark : Colors.grey.shade400,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          _buildChart(selectedMetric),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChart(int metric) {
    const double barAreaH = 110.0;
    const double labelAreaH = 16.0;
    final double bottomAreaH = metric == 2 ? 68.0 : 44.0;
    final double totalH = labelAreaH + barAreaH + bottomAreaH;
    const double colW = 64.0;
    const double yAxisW = 36.0;
    const double barW = 36.0;

    final sorted = _sorted(metric);
    if (sorted.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Text(
          'Aucune donnee collecteur disponible',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }
    final maxRaw = _maxRaw(metric, sorted);

    final yTop = _yLabel(1.0, metric, maxRaw);
    final yMid = _yLabel(0.5, metric, maxRaw);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              _metricDesc(metric),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ),
          SizedBox(
            height: totalH,
            child: Row(
              children: [
                SizedBox(
                  width: yAxisW,
                  child: Stack(
                    children: [
                      Positioned(top: labelAreaH - 8, right: 2,
                        child: Text(yTop, style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
                      Positioned(top: labelAreaH + barAreaH * 0.5 - 8, right: 2,
                        child: Text(yMid, style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
                      Positioned(top: labelAreaH + barAreaH - 8, right: 2,
                        child: Text('0', style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 1,
                  margin: EdgeInsets.only(top: labelAreaH, bottom: bottomAreaH),
                  color: Colors.grey.shade200,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(width: 4),
                        ...sorted.map((c) {
                          final f = _barFraction(c, metric, maxRaw);
                          final color = _barColor(c, metric);
                          final label = _barTopLabel(c, metric);
                          return SizedBox(
                            width: colW,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: labelAreaH,
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: barAreaH,
                                  child: Stack(
                                    children: [
                                      Positioned(top: 0, left: 0, right: 0,
                                        child: Container(height: 1, color: Colors.grey.shade50)),
                                      Positioned(top: barAreaH * 0.5, left: 0, right: 0,
                                        child: Container(height: 1, color: Colors.grey.shade50)),
                                      Positioned.fill(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: f),
                                            duration: const Duration(milliseconds: 900),
                                            curve: Curves.easeOutCubic,
                                            builder: (_, v, _) => Container(
                                              width: barW,
                                              height: barAreaH * v.clamp(0.0, 1.0),
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(c.initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _dark)),
                                    Text(
                                      c.name.split(' ').first,
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                      overflow: TextOverflow.ellipsis, maxLines: 1,
                                    ),
                                    if (metric == 2) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          c.approvalRate >= 0.75 ? 'Bon' : c.approvalRate >= 0.50 ? 'Moyen' : 'Faible',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 13, color: const Color(0xFF7A8A7E)),
              const SizedBox(width: 5),
              const Text(
                'Faites glisser pour voir tous les collecteurs',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8A7E), fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
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
