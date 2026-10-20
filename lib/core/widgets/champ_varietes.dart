// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/widgets/champ_varietes.dart
// PURPOSE : « Variété d'olive » dans les 3 formulaires d'échantillon
//           (collecteur, dégustateur, chef) — un seul widget pour les trois.
//
//           - plusieurs variétés par échantillon, affichées en puces ;
//           - liste des variétés connues + saisie libre ;
//           - « Vouliez-vous dire Chemlali ? » sous le champ quand la saisie
//             ressemble à une variété connue (simple indication, ignorable).
//
//           Le controller reçu reste la source de vérité : il contient les
//           variétés jointes par « , » (champ `variete` du serveur). Le texte
//           en cours de saisie y est inclus aussi, pour qu'une variété tapée
//           sans appuyer sur « + » ne soit pas perdue à l'enregistrement.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/variete_service.dart';

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);

class ChampVarietes extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Widget? titre;
  final InputDecoration? decoration;
  final TextStyle? styleTexte;
  final bool enabled;

  /// Source des variétés connues — par défaut [VarieteService] (serveur +
  /// liste tunisienne). Remplaçable dans les tests.
  final Future<List<String>> Function()? chargerVarietes;

  const ChampVarietes({
    super.key,
    required this.controller,
    this.label = "Variété d'olive",
    this.hint = 'Chemlali, Chétoui...',
    this.titre,
    this.decoration,
    this.styleTexte,
    this.enabled = true,
    this.chargerVarietes,
  });

  @override
  State<ChampVarietes> createState() => _ChampVarietesState();
}

class _ChampVarietesState extends State<ChampVarietes> {
  final _saisie = TextEditingController();
  final _focus = FocusNode();
  List<String> _choisies = [];
  List<String> _suggestions = const [];
  String? _proche;
  Timer? _attente;
  bool _ecritureInterne = false;

  @override
  void initState() {
    super.initState();
    _choisies = _decouper(widget.controller.text);
    widget.controller.addListener(_relireController);
    _saisie.addListener(_surSaisie);
    _focus.addListener(_programmerRecherche);
  }

  @override
  void dispose() {
    _attente?.cancel();
    widget.controller.removeListener(_relireController);
    _saisie.dispose();
    _focus.dispose();
    super.dispose();
  }

  static Future<List<String>> _varietesDuService() async =>
      (await VarieteService.instance.fetchAll()).donnees;

  static List<String> _decouper(String texte) =>
      texte.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();

  bool _dejaChoisie(String valeur) {
    final n = VarieteService.normaliser(valeur);
    return _choisies.any((v) => VarieteService.normaliser(v) == n);
  }

  // Le controller a été rempli de l'extérieur (pré-remplissage, lecture
  // d'étiquette) : on reconstruit les puces.
  void _relireController() {
    if (_ecritureInterne) return;
    setState(() {
      _choisies = _decouper(widget.controller.text);
      _saisie.clear();
    });
  }

  void _ecrireController() {
    final enCours = _saisie.text.trim();
    _ecritureInterne = true;
    widget.controller.text = [
      ..._choisies,
      if (enCours.isNotEmpty && !_dejaChoisie(enCours)) enCours,
    ].join(', ');
    _ecritureInterne = false;
  }

  void _surSaisie() {
    _ecrireController();
    _programmerRecherche();
  }

  void _programmerRecherche() {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 150), _chercher);
  }

  Future<void> _chercher() async {
    if (!mounted || !_focus.hasFocus || !widget.enabled) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    final texte = _saisie.text;
    List<String> toutes;
    try {
      toutes = await (widget.chargerVarietes ?? _varietesDuService)();
    } catch (_) {
      return; // pas de liste : la saisie libre reste possible
    }
    if (!mounted || texte != _saisie.text) return;
    final suggestions = VarieteService.suggestionsPour(
      texte,
      toutes,
    ).where((v) => !_dejaChoisie(v)).toList();
    final proche = VarieteService.varieteProche(texte, toutes);
    setState(() {
      _suggestions = suggestions;
      // L'indication ne sert que quand la liste ne propose rien : sinon
      // l'utilisateur voit déjà la bonne variété juste en dessous.
      _proche =
          suggestions.isEmpty &&
              proche != null &&
              !_dejaChoisie(proche) &&
              VarieteService.normaliser(proche) !=
                  VarieteService.normaliser(texte)
          ? proche
          : null;
    });
  }

  void _ajouter(String valeur) {
    final texte = valeur.trim();
    setState(() {
      if (texte.isNotEmpty && !_dejaChoisie(texte)) _choisies.add(texte);
      _proche = null;
      _suggestions = const [];
    });
    _saisie.clear(); // déclenche _surSaisie → controller à jour
    _ecrireController();
  }

  void _retirer(String valeur) {
    setState(() => _choisies.remove(valeur));
    _ecrireController();
  }

  InputDecoration _decoration() {
    final base =
        widget.decoration ??
        InputDecoration(
          labelText: widget.titre == null ? widget.label : null,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );
    return base.copyWith(
      hintText: _choisies.isEmpty ? widget.hint : 'Ajouter une variété',
      suffixIcon: IconButton(
        tooltip: 'Ajouter',
        icon: const Icon(Icons.add_circle_outline, color: _green),
        onPressed: widget.enabled ? () => _ajouter(_saisie.text) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.titre != null) ...[widget.titre!, const SizedBox(height: 6)],
        if (_choisies.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in _choisies)
                InputChip(
                  label: Text(v),
                  labelStyle: const TextStyle(fontSize: 12, color: _dark),
                  backgroundColor: const Color(0xFFE6F4ED),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  deleteIconColor: _dark,
                  onDeleted: widget.enabled ? () => _retirer(v) : null,
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: _saisie,
          focusNode: _focus,
          enabled: widget.enabled,
          style:
              widget.styleTexte ?? const TextStyle(fontSize: 13, color: _dark),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: _ajouter,
          decoration: _decoration(),
        ),
        if (_proche != null)
          InkWell(
            onTap: () => _ajouter(_proche!),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  children: [
                    const TextSpan(text: 'Vouliez-vous dire '),
                    TextSpan(
                      text: _proche,
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' ?'),
                  ],
                ),
              ),
            ),
          ),
        if (_focus.hasFocus && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final v in _suggestions)
                  InkWell(
                    onTap: () => _ajouter(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              v,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _dark,
                              ),
                            ),
                          ),
                          const Icon(Icons.add, size: 16, color: _green),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
