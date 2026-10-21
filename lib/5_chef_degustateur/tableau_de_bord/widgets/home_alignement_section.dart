import 'package:flutter/material.dart';

import '../models/dashboard_chef_degustateur.dart';
import '../../widgets/chef_colors.dart';
import 'home_shared.dart';

class AlignementSection extends StatelessWidget {
  final AlignementPanelData? alignement;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final VoidCallback onDateTap;

  const AlignementSection({
    super.key,
    required this.alignement,
    required this.dateDebut,
    required this.dateFin,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return fixedCard(
      height: 270,
      header: sectionBar(
        title: "Niveau d'harmonisation avec le panel",
        icon: Icons.check_box_outlined,
        dateDebut: dateDebut,
        dateFin: dateFin,
        onDateTap: onDateTap,
        chipLabel: ({required debut, required fin}) {
          if (debut == null) return '';
          final mois = [
            'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
            'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
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
      body: Column(
        children: [
          SizedBox(
            height: 140,
            child: alignement == null
                ? const Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  )
                : buildScrollableRows(
                    items: alignement!.membres,
                    // Harmonisation = part des notes proches de la moyenne du
                    // panel (100 % − divergence). Plus c'est haut, mieux c'est.
                    getValue: (m) => 100 - m.divergencePct,
                    getMax: (_) => 100.0,
                    getColor: (m) {
                      if (m.divergencePct >= 40) return chefRed;
                      if (m.divergencePct >= 20) return chefAmber;
                      return chefGreen;
                    },
                    getLabel: (m) =>
                        '${(100 - m.divergencePct).toStringAsFixed(0)}%',
                    getName: (m) => m.nom,
                  ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '↕ défiler pour voir tous',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: chefGreen.withValues(alpha: 0.12),
              ),
            ),
            child: const Text(
              'Plus le % est élevé, plus le dégustateur note comme le reste du panel.',
              style: TextStyle(fontSize: 10, color: Color(0xFF6B8E7A)),
            ),
          ),
        ],
      ),
    );
  }
}
