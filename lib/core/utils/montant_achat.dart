// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/utils/montant_achat.dart
// PURPOSE : What a purchase actually costs — unit price × quantity.
//
//           The company negotiates in DT/kg; the price per tonne is always
//           derived from it, never typed or stored. The quantity is in tonnes,
//           so the two have to be reconciled before they can be multiplied.
//           That reconciliation lives here and nowhere else: the confirmation
//           dialog and the proposal details must never be able to show two
//           different totals for the same purchase.
// ═════════════════════════════════════════════════════════════════════════════

/// Olive oil is lighter than water: about 0.916 kg per litre at 20 °C.
///
/// Only used for a legacy price that explicitly says it is per litre.
const double kDensiteHuileOlive = 0.916;

class MontantAchat {
  /// Total cost, or null when either figure is missing or unreadable.
  ///
  /// [prixUnitaire] is the stored price, e.g. "8.750".
  /// [quantiteTonnes] is the stored quantity in tonnes, e.g. "28".
  static double? calculer(String? prixUnitaire, String? quantiteTonnes) {
    final tonnes = _nombre(quantiteTonnes);
    final prix = prixParTonne(prixUnitaire);
    if (prix == null || tonnes == null) return null;
    return prix * tonnes;
  }

  /// Price in DT/kg. A price with no unit is a price per kilo; explicit `/L`
  /// and `/T` values remain supported for existing text.
  static double? prixParKg(String? prixUnitaire) {
    final prix = _nombre(prixUnitaire);
    if (prix == null || prixUnitaire == null) return null;
    switch (_unite(prixUnitaire)) {
      case _Unite.parLitre:
        return prix / kDensiteHuileOlive;
      case _Unite.parKilo:
        return prix;
      case _Unite.parTonne:
        return prix / 1000;
    }
  }

  /// Price in DT/tonne, always derived from the price per kilo.
  static double? prixParTonne(String? prixUnitaire) {
    final prix = prixParKg(prixUnitaire);
    return prix == null ? null : prix * 1000;
  }

  /// "8.750 DT/kg" — three decimals, the millime being the dinar's subunit.
  static String? formaterPrixParKg(String? prixUnitaire) {
    final prix = prixParKg(prixUnitaire);
    if (prix == null) return null;
    return '${prix.toStringAsFixed(3)} DT/kg';
  }

  /// "8 750 DT/tonne" — grouped by thousands.
  static String? formaterPrixParTonne(String? prixUnitaire) {
    final prix = prixParTonne(prixUnitaire);
    if (prix == null) return null;
    return '${_espacerMilliers(prix.round())} DT/tonne';
  }

  /// "243 015 DT" — grouped by thousands, no decimals.
  ///
  /// A purchase total runs into the hundreds of thousands; centimes would only
  /// add noise to a figure read at a glance before committing.
  static String? formater(String? prixUnitaire, String? quantiteTonnes) {
    final total = calculer(prixUnitaire, quantiteTonnes);
    if (total == null) return null;
    return formaterMontant(total);
  }

  /// "243 015 DT" for an amount already computed.
  static String formaterMontant(double montant) =>
      '${_espacerMilliers(montant.round())} DT';

  // ── Parsing ─────────────────────────────────────────────────────────────────

  /// First number in the text, comma or dot as decimal separator.
  static double? _nombre(String? texte) {
    if (texte == null) return null;
    final m = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(texte.replaceAll(' ', ''));
    if (m == null) return null;
    return double.tryParse(m.group(0)!.replaceAll(',', '.'));
  }

  static _Unite _unite(String prixUnitaire) {
    final t = prixUnitaire.toLowerCase();
    if (t.contains('/kg') || t.contains('/ kg')) return _Unite.parKilo;
    if (t.contains('/t')) return _Unite.parTonne;
    if (t.contains('/l') || t.contains('/ l')) return _Unite.parLitre;
    // The company quotes its prices by kilo. Any other unit must say so.
    return _Unite.parKilo;
  }

  static String _espacerMilliers(int n) {
    final chiffres = n.abs().toString();
    final buffer = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < chiffres.length; i++) {
      if (i > 0 && (chiffres.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(chiffres[i]);
    }
    return buffer.toString();
  }
}

enum _Unite { parLitre, parKilo, parTonne }
