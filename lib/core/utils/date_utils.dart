class DegDateUtils {
  static DateTime? parseDate(String s) {
    // Server ISO 8601 text (e.g. date_ajout) as well as JJ/MM/AAAA.
    final iso = DateTime.tryParse(s.trim());
    if (iso != null) {
      final local = iso.toLocal();
      return DateTime(local.year, local.month, local.day);
    }
    try {
      final datePart = s.split(' ').first;
      final p = datePart.split('/');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  /// Formats a server date (ISO 8601, e.g. "2026-09-07T11:25:21.385451+01:00")
  /// for display as "07/09/2026". Returns the original text unchanged if it
  /// isn't a parseable date, and an empty string for null/empty input.
  static String formaterAffichage(dynamic valeur) {
    if (valeur == null) return '';
    final texte = valeur.toString();
    if (texte.isEmpty) return '';
    final parsed = DateTime.tryParse(texte)?.toLocal();
    if (parsed == null) return texte;
    final jour = parsed.day.toString().padLeft(2, '0');
    final mois = parsed.month.toString().padLeft(2, '0');
    return '$jour/$mois/${parsed.year}';
  }

  static String formaterSaisie(dynamic valeur) {
    final texte = formaterAffichage(valeur);
    return texte;
  }

  static String? dateSaisieVersIso(String valeur) {
    final texte = valeur.trim();
    if (texte.isEmpty) return null;
    final dejaIso = DateTime.tryParse(texte);
    if (dejaIso != null && texte.contains('-')) {
      return dejaIso.toIso8601String();
    }
    final morceaux = texte.split('/');
    if (morceaux.length != 3) return null;
    final jour = int.tryParse(morceaux[0]);
    final mois = int.tryParse(morceaux[1]);
    final annee = int.tryParse(morceaux[2]);
    if (jour == null || mois == null || annee == null) return null;
    return DateTime(annee, mois, jour).toIso8601String();
  }

  static String? dateSaisieVersDateIso(String valeur) {
    final iso = dateSaisieVersIso(valeur);
    return iso == null ? null : iso.substring(0, 10);
  }

  static String formaterDateHeure(dynamic valeur) {
    if (valeur == null) return '';
    final texte = valeur.toString().trim();
    if (texte.isEmpty) return '';

    final parsed = DateTime.tryParse(texte);
    if (parsed != null) {
      final local = parsed.toLocal();
      final jour = local.day.toString().padLeft(2, '0');
      final mois = local.month.toString().padLeft(2, '0');
      final date = '$jour/$mois/${local.year}';
      if (!texte.contains('T') && !texte.contains(':')) return date;
      final heure = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$date $heure:$minute';
    }

    final dejaFormatee = RegExp(
      r'^(\d{2}/\d{2}/\d{4})(?: (\d{2}:\d{2}))?$',
    ).firstMatch(texte);
    if (dejaFormatee != null) {
      return dejaFormatee.group(2) == null
          ? dejaFormatee.group(1)!
          : '${dejaFormatee.group(1)} ${dejaFormatee.group(2)}';
    }
    return '';
  }

  static String formaterDateHeureOuTiret(dynamic valeur) {
    final texte = formaterDateHeure(valeur);
    return texte.isEmpty ? '—' : texte;
  }

  /// Most recently registered first. Same date or unreadable date: keeps the
  /// incoming order (stable), so the server order is never scrambled.
  static List<T> plusRecentsDabord<T>(
    Iterable<T> items,
    String? Function(T) dateAjout,
  ) {
    DateTime? lire(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s.trim()) ?? parseDate(s);
    }

    final indexes = items.toList().asMap().entries.toList();
    indexes.sort((a, b) {
      final da = lire(dateAjout(a.value));
      final db = lire(dateAjout(b.value));
      if (da != null && db != null && da != db) return db.compareTo(da);
      if (da == null && db != null) return 1;
      if (da != null && db == null) return -1;
      return a.key.compareTo(b.key);
    });
    return [for (final e in indexes) e.value];
  }
}
