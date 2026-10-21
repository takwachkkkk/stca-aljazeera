// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 5_chef_degustateur/tableau_de_bord/widgets/home_panel_coi_section.dart
// PURPOSE : Tableau de bord du chef — « Résultat du panel (méthode COI) ».
//           Combien d'échantillons dans chaque catégorie selon la MÉDIANE du
//           panel (pas une évaluation isolée), combien sont fiables, mois par
//           mois ; toucher un échantillon ouvre sa fiche détaillée.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../panel_coi/fiche_resultat_panel.dart';
import '../../panel_coi/resultat_panel.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);
const Color _rouge = Color(0xFFC0392B);

const _moisCourts = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Juin',
  'Juil',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

class PanelCoiSection extends StatefulWidget {
  final ResultatPanelService? service;

  const PanelCoiSection({super.key, this.service});

  @override
  State<PanelCoiSection> createState() => PanelCoiSectionState();
}

class PanelCoiSectionState extends State<PanelCoiSection> {
  late final ResultatPanelService _service =
      widget.service ?? ResultatPanelService();
  List<ResultatPanel> _resultats = const [];
  bool _chargement = true;
  bool _erreur = false;

  /// Mois choisi (année, mois) ; null = tous.
  (int, int)? _mois;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  Future<void> recharger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final resultats = await _service.fetchTous();
      if (!mounted) return;
      setState(() {
        _resultats = resultats;
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

  (int, int)? _moisDe(ResultatPanel r) {
    final d = r.derniereSoumission;
    return d == null ? null : (d.year, d.month);
  }

  List<(int, int)> get _moisDisponibles {
    final mois = <(int, int)>{};
    for (final r in _resultats) {
      final m = _moisDe(r);
      if (m != null) mois.add(m);
    }
    final liste = mois.toList()
      ..sort((a, b) => b.$1 != a.$1 ? b.$1 - a.$1 : b.$2 - a.$2);
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final choisis = _mois == null
        ? _resultats
        : _resultats.where((r) => _moisDe(r) == _mois).toList();
    int compte(ClassificationHuile c) =>
        choisis.where((r) => r.classification == c).length;
    final fiables = choisis.where((r) => r.fiable).length;

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
          const Row(
            children: [
              Icon(Icons.functions, size: 18, color: _green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Résultat du panel (méthode COI)',
                  style: TextStyle(
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
            'Catégorie de chaque échantillon selon la médiane de tous les '
            'dégustateurs, comme le fichier de calcul du COI.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
            _message('Impossible de charger le résultat du panel.')
          else if (_resultats.isEmpty)
            _message('Aucune évaluation soumise pour le moment.')
          else ...[
            _choixMois(),
            const SizedBox(height: 10),
            Row(
              children: [
                _tuile(
                  'Extra vierge',
                  compte(ClassificationHuile.extraVierge),
                  ClassificationHuile.extraVierge,
                ),
                const SizedBox(width: 6),
                _tuile(
                  'Vierge',
                  compte(ClassificationHuile.vierge),
                  ClassificationHuile.vierge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _tuile(
                  'Vierge ordinaire',
                  compte(ClassificationHuile.viergeOrdinaire),
                  ClassificationHuile.viergeOrdinaire,
                ),
                const SizedBox(width: 6),
                _tuile(
                  'Lampante',
                  compte(ClassificationHuile.lampante),
                  ClassificationHuile.lampante,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: _green),
                const SizedBox(width: 4),
                Text(
                  '$fiables fiable${fiables > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: _rouge,
                ),
                const SizedBox(width: 4),
                Text(
                  '${choisis.length - fiables} à refaire (CVr > 20 %)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _rouge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            for (final r in choisis.take(5)) _ligne(r),
            if (choisis.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '… et ${choisis.length - 5} autre${choisis.length - 5 > 1 ? 's' : ''} '
                  '(voir « Vue d\'ensemble évaluations »).',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _choixMois() {
    Widget puce(String libelle, (int, int)? valeur) {
      final actif = _mois == valeur;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(libelle),
          selected: actif,
          onSelected: (_) => setState(() => _mois = valeur),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: actif ? Colors.white : const Color(0xFF616161),
          ),
          selectedColor: _green,
          backgroundColor: const Color(0xFFF0F0F0),
          side: BorderSide.none,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          puce('Tous les mois', null),
          for (final m in _moisDisponibles)
            puce('${_moisCourts[m.$2 - 1]} ${m.$1}', m),
        ],
      ),
    );
  }

  Widget _tuile(String libelle, int nombre, ClassificationHuile c) {
    final couleur = Color(c.colorValue);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(
              '$nombre',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: couleur,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                libelle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligne(ResultatPanel r) {
    final c = r.classification;
    return InkWell(
      onTap: () => afficherResultatPanel(context, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${r.numero ?? r.referenceBouteille} · '
                '${r.nombreDegustateurs} dégust.',
                style: const TextStyle(fontSize: 12, color: _dark),
              ),
            ),
            Text(
              c?.label ?? '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c == null ? Colors.grey : Color(c.colorValue),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              r.fiable ? Icons.verified_outlined : Icons.warning_amber_rounded,
              size: 16,
              color: r.fiable ? _green : _rouge,
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

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
