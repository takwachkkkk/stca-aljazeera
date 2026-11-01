import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/core/fonctionnalites.dart';
import 'package:project3/core/utils/montant_achat.dart';
import '../models/dashboard_models.dart';

const Color _fond = Color(0xFF3D5C49);
const Color _texteDoux = Color(0xFFC6DACE);

/// La couleur de chaque huile, du plus doré au plus sombre : c'est la même
/// dans la barre des quantités et dans la liste en dessous.
const Map<String, Color> _couleursCategories = {
  'extra_vierge': Color(0xFFEBC765),
  'vierge': Color(0xFFA8D6BC),
  'vierge_ordinaire': Color(0xFFE9A15B),
  'lampante': Color(0xFFE5806A),
};
const Color _couleurNonClasse = Color(0xFF8FA598);

/// Ce que la direction a acheté sur la période : combien d'argent, quelle
/// quantité de chaque huile, et à quel prix pour les derniers achats.
class InvestissementCard extends StatelessWidget {
  final SyntheseAchats achats;
  final int submittedAnalyses;
  final Widget dateChip;

  const InvestissementCard({
    super.key,
    required this.achats,
    required this.submittedAnalyses,
    required this.dateChip,
  });

  static const _explication =
      "Pour chaque achat confirmé : prix convenu en DT/kg × quantité achetée. "
      "Un achat compte à la date où il a été confirmé.";

  /// « 50 t », « 12,5 t ».
  String _tonnes(double valeur) {
    final texte = valeur == valeur.roundToDouble()
        ? valeur.toStringAsFixed(0)
        : valeur.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return '${texte.replaceAll('.', ',')} t';
  }

  String get _resume {
    if (achats.nombre == 0) return 'Aucun achat confirmé sur cette période';
    final nombre = achats.nombre > 1
        ? '${achats.nombre} achats confirmés'
        : '1 achat confirmé';
    return "${_tonnes(achats.quantiteTotaleT)} d'huile, en $nombre";
  }

  @override
  Widget build(BuildContext context) {
    // Une catégorie vide reste listée : « 0 t de lampante » est une information.
    final categories = achats.categories
        .where((c) => c.cle != 'non_classe' || c.nombre > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _fond,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Investissement achats',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Tooltip(
                      message: _explication,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: Duration(seconds: 6),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.info_outline,
                          size: 15,
                          color: _texteDoux,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              dateChip,
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MontantAchat.formaterMontant(achats.montantTotal),
              style: GoogleFonts.domine(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _resume,
            style: const TextStyle(fontSize: 12, color: _texteDoux),
          ),
          if (achats.sansQuantite > 0) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Color(0xFFEBC765),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    achats.sansQuantite > 1
                        ? "${achats.sansQuantite} achats n'ont pas de quantité : ils ne sont pas dans ce montant."
                        : "1 achat n'a pas de quantité : il n'est pas dans ce montant.",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEBC765),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (achats.quantiteTotaleT > 0) ...[
            const SizedBox(height: 14),
            _BarreQuantites(categories: categories),
          ],
          const SizedBox(height: 12),
          for (final categorie in categories)
            _LigneCategorie(categorie, _tonnes(categorie.quantiteT)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Dernier prix d'achat",
                  style: TextStyle(fontSize: 11, color: _texteDoux),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DernierPrixVue(
                        'extra_vierge',
                        'Extra vierge',
                        achats.dernierPrixExtra,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DernierPrixVue(
                        'vierge',
                        'Vierge',
                        achats.dernierPrixVierge,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (kLaboActif) ...[
            const SizedBox(height: 10),
            Text(
              "Analyses soumises : $submittedAnalyses",
              style: const TextStyle(fontSize: 11, color: _texteDoux),
            ),
          ],
        ],
      ),
    );
  }
}

/// La part de chaque huile dans le tonnage acheté, d'un seul coup d'œil.
class _BarreQuantites extends StatelessWidget {
  final List<AchatCategorie> categories;

  const _BarreQuantites({required this.categories});

  @override
  Widget build(BuildContext context) {
    final presentes = categories.where((c) => c.quantiteT > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 12,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < presentes.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: (presentes[i].quantiteT * 100).round().clamp(1, 1 << 30),
                child: ColoredBox(
                  color:
                      _couleursCategories[presentes[i].cle] ??
                      _couleurNonClasse,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LigneCategorie extends StatelessWidget {
  final AchatCategorie categorie;
  final String quantite;

  const _LigneCategorie(this.categorie, this.quantite);

  @override
  Widget build(BuildContext context) {
    final vide = categorie.nombre == 0;
    final couleurTexte = vide
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _couleursCategories[categorie.cle] ?? _couleurNonClasse,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              categorie.libelle,
              style: TextStyle(fontSize: 12, color: couleurTexte),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              quantite,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: couleurTexte,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              MontantAchat.formaterMontant(categorie.montant),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                color: vide ? couleurTexte : _texteDoux,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DernierPrixVue extends StatelessWidget {
  final String cle;
  final String libelle;
  final DernierPrix? dernierPrix;

  const _DernierPrixVue(this.cle, this.libelle, this.dernierPrix);

  @override
  Widget build(BuildContext context) {
    final prix = dernierPrix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _couleursCategories[cle],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                libelle,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (prix == null)
          const Text(
            'Aucun achat sur la période',
            style: TextStyle(fontSize: 11, color: _texteDoux),
          )
        else ...[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MontantAchat.formaterPrixParKg(prix.prix.toString())!,
              style: GoogleFonts.domine(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'le ${dateCourte(prix.date)}',
            style: const TextStyle(fontSize: 10.5, color: _texteDoux),
          ),
        ],
      ],
    );
  }
}
