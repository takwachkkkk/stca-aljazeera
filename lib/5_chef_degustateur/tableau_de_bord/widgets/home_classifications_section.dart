import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/dashboard_chef_degustateur.dart';
import 'home_shared.dart';
import '../../widgets/chef_colors.dart';

/// Classifications données par le panel, mois par mois.
///
/// Les nombres exacts sont affichés (tuiles + valeur au-dessus de chaque
/// barre) et un mois peut être choisi ; « Tous les mois » additionne la
/// période filtrée par dates.
class ClassificationsSection extends StatefulWidget {
  final List<ClassificationPoint> classifications;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final VoidCallback onDateTap;

  const ClassificationsSection({
    super.key,
    required this.classifications,
    required this.dateDebut,
    required this.dateFin,
    required this.onDateTap,
  });

  @override
  State<ClassificationsSection> createState() => _ClassificationsSectionState();
}

class _ClassificationsSectionState extends State<ClassificationsSection> {
  /// Index du mois choisi dans [ClassificationsSection.classifications] ;
  /// null = tous les mois.
  int? _moisChoisi;

  @override
  void didUpdateWidget(covariant ClassificationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final choisi = _moisChoisi;
    if (choisi != null && choisi >= widget.classifications.length) {
      _moisChoisi = null;
    }
  }

  ({int extraVierge, int vierge, int lampante}) get _totaux {
    final choisi = _moisChoisi;
    final points = choisi == null
        ? widget.classifications
        : [widget.classifications[choisi]];
    var ev = 0, v = 0, l = 0;
    for (final p in points) {
      ev += p.extraVierge;
      v += p.vierge;
      l += p.lampante;
    }
    return (extraVierge: ev, vierge: v, lampante: l);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.classifications;
    final totaux = _totaux;
    final total = totaux.extraVierge + totaux.vierge + totaux.lampante;

    return fixedCard(
      height: 430,
      header: sectionBar(
        title: 'Classifications du panel',
        icon: Icons.bar_chart_outlined,
        dateDebut: widget.dateDebut,
        dateFin: widget.dateFin,
        onDateTap: widget.onDateTap,
        chipLabel: ({required debut, required fin}) {
          if (debut == null) return '';
          final mois = [
            'Jan',
            'Fév',
            'Mar',
            'Avr',
            'Mai',
            'Jun',
            'Jul',
            'Aoû',
            'Sep',
            'Oct',
            'Nov',
            'Déc',
          ];
          if (fin == null ||
              (debut.year == fin.year &&
                  debut.month == fin.month &&
                  debut.day == fin.day)) {
            return '${debut.day.toString().padLeft(2, '0')}/${debut.month.toString().padLeft(2, '0')}/${debut.year}';
          }
          return '${debut.day} ${mois[debut.month - 1]} → ${fin.day} ${mois[fin.month - 1]}';
        },
      ),
      body: points.isEmpty
          ? const Center(
              child: Text(
                'Aucune donnée',
                style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _choixMois(points),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _tuile('Extra vierge', totaux.extraVierge, chefGreen),
                    const SizedBox(width: 6),
                    _tuile('Vierge', totaux.vierge, chefOlive),
                    const SizedBox(width: 6),
                    _tuile('Lampante', totaux.lampante, chefAmber),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Total : $total évaluation${total > 1 ? 's' : ''} soumise${total > 1 ? 's' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B8E7A),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(height: 170, child: _graphique(points)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    legendDot(chefGreen, 'Extra Vierge'),
                    const SizedBox(width: 12),
                    legendDot(chefOlive, 'Vierge'),
                    const SizedBox(width: 12),
                    legendDot(chefAmber, 'Lampante'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _choixMois(List<ClassificationPoint> points) {
    Widget puce(String libelle, int? index) {
      final actif = _moisChoisi == index;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(libelle),
          selected: actif,
          onSelected: (_) => setState(() => _moisChoisi = index),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: actif ? Colors.white : const Color(0xFF616161),
          ),
          selectedColor: chefGreen,
          backgroundColor: const Color(0xFFF0F0F0),
          side: BorderSide.none,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // Du plus récent au plus ancien : le mois en cours est le premier visible.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          puce('Tous les mois', null),
          for (var i = points.length - 1; i >= 0; i--)
            puce(points[i].libelleMois, i),
        ],
      ),
    );
  }

  Widget _tuile(String libelle, int nombre, Color couleur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$nombre',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: couleur,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              libelle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graphique(List<ClassificationPoint> points) {
    final maxY =
        points
            .expand((p) => [p.extraVierge, p.vierge, p.lampante])
            .fold(0, (a, b) => a > b ? a : b)
            .toDouble() +
        1;

    BarChartRodData barre(int valeur, Color couleur) => BarChartRodData(
      toY: valeur.toDouble(),
      color: couleur,
      width: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: false,
          // Le nombre exact au-dessus de chaque barre, toujours visible.
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (groupe, _, barreDonnee, _) {
              if (barreDonnee.toY == 0) return null;
              return BarTooltipItem(
                barreDonnee.toY.toInt().toString(),
                TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: barreDonnee.color,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: [0, 1, 2],
              barRods: [
                barre(points[i].extraVierge, chefGreen),
                barre(points[i].vierge, chefOlive),
                barre(points[i].lampante, chefAmber),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                final actif = _moisChoisi == i;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].libelleMois,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
                      color: actif ? chefGreen : const Color(0xFFAAAAAA),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}
