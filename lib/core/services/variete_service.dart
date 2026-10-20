// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/services/variete_service.dart
// PURPOSE : The varieties already used, for suggesting as the user types.
//
//           Unlike the supplier, the variety is NOT an entity and never will be
//           a closed dropdown: the collector writes it himself. Suggestions only
//           save keystrokes and keep spellings from drifting.
//
//           Why it is safe to leave free: the variety appears nowhere in
//           lib/1_ceo/tableau_de_bord/, so it enters no dashboard calculation.
//           It is used for display, filtering and search. If that ever changes,
//           this decision has to be reopened.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;

import '../api_client.dart';
import 'resultat_service.dart';

class VarieteService {
  VarieteService._();
  static final VarieteService instance = VarieteService._();

  Resultat<List<String>>? _cache;

  /// Known Tunisian varieties plus every variety already used on a sample
  /// (a stored value « Chemlali, Chétoui » counts as two), alphabetical.
  Future<Resultat<List<String>>> fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    _cache = await avecSecours(() async {
      final items = await apiClient.getList('/api/echantillons/');
      final vues = <String, String>{};
      for (final v in _varietesConnues) {
        vues[normaliser(v)] = v;
      }
      for (final item in items) {
        final v = (item as Map<String, dynamic>)['variete'] as String?;
        if (v == null) continue;
        for (final valeur in v.split(',')) {
          final propre = valeur.trim();
          if (propre.isNotEmpty) {
            vues.putIfAbsent(normaliser(propre), () => propre);
          }
        }
      }
      final liste = vues.values.toList()
        ..sort((a, b) => normaliser(a).compareTo(normaliser(b)));
      return liste;
    }, () => _varietesConnues);
    return _cache!;
  }

  /// Suggestions for what has been typed so far, best match first.
  ///
  /// An empty query returns the first known varieties so the user can pick
  /// from existing values as soon as the field opens.
  Future<Resultat<List<String>>> suggest(
    String saisie, {
    int limite = 6,
  }) async {
    final resultat = await fetchAll();
    return Resultat(
      suggestionsPour(saisie, resultat.donnees, limite: limite),
      estDemonstration: resultat.estDemonstration,
      messageErreur: resultat.messageErreur,
    );
  }

  /// Pure filtering behind [suggest]: names starting with the input first,
  /// then names containing it, case and accents ignored. An empty input
  /// returns the first varieties of the list.
  static List<String> suggestionsPour(
    String saisie,
    List<String> varietes, {
    int limite = 6,
  }) {
    final q = normaliser(saisie.trim());
    if (q.isEmpty) return varietes.take(limite).toList();
    final debut = <String>[];
    final ailleurs = <String>[];
    for (final v in varietes) {
      final n = normaliser(v);
      if (n == q) continue; // already typed in full — nothing to suggest
      if (n.startsWith(q)) {
        debut.add(v);
      } else if (n.contains(q)) {
        ailleurs.add(v);
      }
    }
    return [...debut, ...ailleurs].take(limite).toList();
  }

  /// Returns the closest known variety when the edit distance is at most 2.
  static String? varieteProche(String saisie, List<String> connues) {
    final cible = normaliser(saisie.trim());
    if (cible.isEmpty) return null;
    String? meilleure;
    var distanceMin = 3;
    for (final connue in connues) {
      final distance = _distance(cible, normaliser(connue));
      if (distance < distanceMin) {
        distanceMin = distance;
        meilleure = connue;
      }
    }
    return meilleure;
  }

  /// Lowercase without accents — « Chétoui » and « chetoui » compare equal.
  static String normaliser(String valeur) {
    const accents = 'ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖòóôõöÙÚÛÜùúûüÝýÿ';
    const simples = 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOoooooUUUUuuuuYyy';
    var resultat = valeur.toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      resultat = resultat.replaceAll(
        accents[i].toLowerCase(),
        simples[i].toLowerCase(),
      );
    }
    return resultat;
  }

  static int _distance(String a, String b) {
    final ligne = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var diagonal = ligne[0];
      ligne[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final dessus = ligne[j];
        ligne[j] = math.min(
          math.min(ligne[j] + 1, ligne[j - 1] + 1),
          diagonal + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
        diagonal = dessus;
      }
    }
    return ligne[b.length];
  }

  /// The main Tunisian olive varieties — a starting list, not a closed field.
  static const List<String> _varietesConnues = [
    'Chemlali',
    'Chemlali Sfax',
    'Chemlali Zarzis',
    'Chemlali Tataouine',
    'Chétoui',
    'Oueslati',
    'Sayali',
    'Gerboui',
    'Zalmati',
    'Zarrazi',
    'Rkhami',
    'Meski',
    'Tounsi',
    'Besbessi',
    'Beldi',
    'Fouja',
    'Chemchali',
    'Zarbout',
    'Jemri',
    'Fakhari',
    'Marsaline',
    'Limouni',
    'Neb Jmel',
    'Toffahi',
  ];

  void invalidateCache() => _cache = null;
}
