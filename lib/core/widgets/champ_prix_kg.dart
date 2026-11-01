import 'package:flutter/material.dart';

import '../utils/montant_achat.dart';

/// Saisie d'un prix en DT/kg, suivie du prix par tonne qui en découle.
///
/// Partagé par la direction et le collecteur : les deux parlent de la même
/// offre. La direction raisonne au kilo et masque le prix par tonne
/// ([afficherPrixTonne] à faux). Le prix par tonne n'est jamais saisi ni
/// enregistré.
class ChampPrixKg extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool afficherPrixTonne;

  const ChampPrixKg({
    super.key,
    required this.controller,
    required this.decoration,
    this.afficherPrixTonne = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: decoration.copyWith(suffixText: 'DT/kg'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
        ),
        if (afficherPrixTonne) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F4EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prix par tonne',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B8E7A)),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, saisie, _) => Text(
                    MontantAchat.formaterPrixParTonne(saisie.text) ?? '—',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E1F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
