// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/widgets/repartition_card.dart
// PURPOSE : Cartes « Échantillons par gouvernorat » et « Échantillons par
//           fournisseur » des tableaux de bord du chef et de la direction :
//           d'où viennent les échantillons, chez qui l'entreprise achète.
//           Une seule carte pour les deux usages et les deux rôles ; elle
//           charge ses propres données et a son propre choix de période.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../services/repartition_service.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _achat = Color(0xFFD07B2F);

enum _Periode { mois, troisMois, annee, tout }

extension on _Periode {
  String get libelle => switch (this) {
    _Periode.mois => 'Ce mois',
    _Periode.troisMois => '3 derniers mois',
    _Periode.annee => 'Cette année',
    _Periode.tout => 'Tout',
  };

  DateTime? debut(DateTime maintenant) => switch (this) {
    _Periode.mois => DateTime(maintenant.year, maintenant.month, 1),
    _Periode.troisMois => DateTime(maintenant.year, maintenant.month - 2, 1),
    _Periode.annee => DateTime(maintenant.year, 1, 1),
    _Periode.tout => null,
  };
}

class RepartitionCard extends StatefulWidget {
  final RepartitionService service;
  final String titre;
  final String sousTitre;
  final IconData icone;

  const RepartitionCard({
    super.key,
    required this.service,
    required this.titre,
    required this.sousTitre,
    required this.icone,
  });

  /// Par gouvernorat — chemin `/api/<role>/dashboard/regions/`.
  factory RepartitionCard.gouvernorats({Key? key, required String role}) =>
      RepartitionCard(
        key: key,
        service: RepartitionService('/api/$role/dashboard/regions/'),
        titre: 'Échantillons par gouvernorat',
        sousTitre:
            "D'où viennent les échantillons et où l'entreprise achète le plus.",
        icone: Icons.map_outlined,
      );

  /// Par fournisseur — chemin `/api/<role>/dashboard/fournisseurs/`.
  factory RepartitionCard.fournisseurs({Key? key, required String role}) =>
      RepartitionCard(
        key: key,
        service: RepartitionService('/api/$role/dashboard/fournisseurs/'),
        titre: 'Échantillons par fournisseur',
        sousTitre:
            'Combien chaque fournisseur a apporté et combien a été acheté.',
        icone: Icons.storefront_outlined,
      );

  @override
  State<RepartitionCard> createState() => RepartitionCardState();
}

class RepartitionCardState extends State<RepartitionCard> {
  _Periode _periode = _Periode.annee;
  List<LigneRepartition> _lignes = const [];
  bool _chargement = true;
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  /// Appelée aussi par le tableau de bord quand l'utilisateur tire pour
  /// rafraîchir.
  Future<void> recharger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final lignes = await widget.service.fetch(
        debut: _periode.debut(DateTime.now()),
      );
      if (!mounted) return;
      setState(() {
        _lignes = lignes;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = true;
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalEchantillons = _lignes.fold(0, (s, l) => s + l.echantillons);
    final totalAchats = _lignes.fold(0, (s, l) => s + l.achats);
    final max = _lignes.isEmpty
        ? 1
        : _lignes.map((l) => l.echantillons).reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icone, size: 18, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.titre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.sousTitre,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _Periode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p.libelle),
                      selected: _periode == p,
                      onSelected: (_) {
                        setState(() => _periode = p);
                        recharger();
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _periode == p
                            ? Colors.white
                            : const Color(0xFF616161),
                      ),
                      selectedColor: _green,
                      backgroundColor: const Color(0xFFF0F0F0),
                      side: BorderSide.none,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: _green, strokeWidth: 2),
              ),
            )
          else if (_erreur)
            _message('Impossible de charger cette carte pour le moment.')
          else if (_lignes.isEmpty)
            _message('Aucun échantillon sur cette période.')
          else ...[
            Row(
              children: [
                _legende(_green, '$totalEchantillons échantillons'),
                const SizedBox(width: 14),
                _legende(_achat, '$totalAchats achats confirmés'),
              ],
            ),
            const SizedBox(height: 10),
            for (final ligne in _lignes) _ligne(ligne, max),
          ],
        ],
      ),
    );
  }

  Widget _ligne(LigneRepartition l, int max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.nom,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ),
              Text(
                '${l.echantillons} éch. · ${l.achats} achat${l.achats > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, contraintes) {
              final largeur = contraintes.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 8,
                    width: largeur,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: largeur * l.echantillons / max,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Les achats sont une partie des échantillons de la région.
                  Container(
                    height: 8,
                    width: largeur * l.achats / max,
                    decoration: BoxDecoration(
                      color: _achat,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legende(Color couleur, String texte) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: couleur,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        texte,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _message(String texte) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(
        texte,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    ),
  );
}
