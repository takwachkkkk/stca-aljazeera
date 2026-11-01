import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:project3/core/utils/montant_achat.dart';
import '../models/dashboard_models.dart';
import 'dash_line_painter.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _white = Color(0xFFFFFFFF);

class SalesEvolutionCard extends StatelessWidget {
  final CardDateRange dateRange;
  final List<PurchaseEvolutionPoint> points;
  final Widget Function(CardDateRange, VoidCallback) dateChipBuilder;
  final void Function(CardDateRange) onRangeChanged;

  const SalesEvolutionCard({
    super.key,
    required this.dateRange,
    required this.points,
    required this.dateChipBuilder,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePoints = points.isEmpty
        ? const [PurchaseEvolutionPoint('Aucun', 0)]
        : points;
    final values = effectivePoints.map((point) => point.value).toList();
    final maxInput = values.fold(0.0, (a, b) => a > b ? a : b);
    final maxVal = maxInput <= 0 ? 1.0 : maxInput * 1.25;
    final total = values.fold(0.0, (s, e) => s + e);
    final nombreAchats = effectivePoints.fold(0, (s, p) => s + p.count);
    // Une année de mois ou trente jours ne tiennent pas tous sous la courbe.
    final pasLibelles = (effectivePoints.length / 6).ceil();
    final dernierPoint = (effectivePoints.length - 1).toDouble();

    Widget legendLine({required Color color, bool dashed = false}) => SizedBox(
          width: 20,
          height: 12,
          child: CustomPaint(painter: DashLinePainter(color: color, dashed: dashed)),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionLabel('Évolution des achats', Icons.show_chart_outlined)),
              dateChipBuilder(dateRange, () {}),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              legendLine(color: _green),
              const SizedBox(width: 6),
              const Text('Montant des achats confirmés, en DT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _dark)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            // Les libellés sont centrés sous les points : ceux des bords
            // dépasseraient de la carte.
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal / 3,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: pasLibelles.toDouble(),
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i != v || i < 0 || i >= effectivePoints.length) return const SizedBox();
                        return Text(
                          effectivePoints[i].label,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                // Une seule tranche (un seul jour choisi) reste un point visible.
                minX: dernierPoint == 0 ? -0.5 : 0,
                maxX: dernierPoint == 0 ? 0.5 : dernierPoint,
                minY: 0,
                maxY: maxVal,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            MontantAchat.formaterMontant(spot.y),
                            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      effectivePoints.length,
                      (i) => FlSpot(i.toDouble(), effectivePoints[i].value),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: _green,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (p, x, bar, i) => FlDotCirclePainter(
                        radius: 3.5,
                        color: _green,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [_green.withValues(alpha: 0.18), _green.withValues(alpha: 0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
            child: Row(
              children: [
                Expanded(child: _kpiMini(MontantAchat.formaterMontant(total), 'Montant sur la période', _green)),
                Container(width: 1, height: 32, color: Colors.grey.shade100),
                Expanded(child: _kpiMini('$nombreAchats', nombreAchats > 1 ? 'Achats confirmés' : 'Achat confirmé', _dark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiMini(String value, String label, Color color) => Column(
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      );
}

Widget _sectionLabel(String text, IconData icon) => Row(
      children: [
        Container(
          width: 3,
          height: 16,
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
