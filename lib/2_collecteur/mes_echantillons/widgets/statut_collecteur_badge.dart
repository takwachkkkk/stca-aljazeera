// ═════════════════════════════════════════════════════════════════════════════
// FILE : collecteur/pages/mes_echantillons/widgets/statut_collecteur_badge.dart
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/echantillon_collecteur.dart';

class StatutCollecteurBadge extends StatelessWidget {
  final StatutCollecteur statut;
  const StatutCollecteurBadge({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cfg.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            cfg.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cfg.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cfg {
  final Color bg, dot, text;
  final String label;
  const _Cfg(this.bg, this.dot, this.text, this.label);
}

_Cfg _cfg(StatutCollecteur s) {
  switch (s) {
    case StatutCollecteur.receptionne:
      return const _Cfg(
        Color(0xFFE3F2FD),
        Color(0xFF1E88E5),
        Color(0xFF1E88E5),
        'Échantillon enregistré',
      );
    case StatutCollecteur.enNegociation:
      return const _Cfg(
        Color(0xFFFFF3E0),
        Color(0xFFF57C00),
        Color(0xFFF57C00),
        'Prix en négociation',
      );
    case StatutCollecteur.achatConfirme:
      return const _Cfg(
        Color(0xFFE8F5E9),
        Color(0xFF38835A),
        Color(0xFF38835A),
        'Achat conclu',
      );
    case StatutCollecteur.achatNonConclu:
      return const _Cfg(
        Color(0xFFF0F0F0),
        Color(0xFF616161),
        Color(0xFF616161),
        'Achat non conclu',
      );
  }
}
