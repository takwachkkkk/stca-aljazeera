// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/classification/classification_interne.dart
// PURPOSE : Classification sensorielle à deux niveaux.
//
//   Niveau 1 — catégorie réglementaire COI (extra vierge → lampante)
//   Niveau 2 — classe interne PR-48, réservée aux huiles extra vierges (§6)
//
// Ce fichier est le miroir Dart de backend_new/evaluations/classification.py.
// Le client calcule en direct pendant la saisie, le serveur revalide ce qu'il
// reçoit. Les deux implémentations partagent le même jeu de cas de test :
// test/classification_interne_test.dart et evaluations/tests.py.
//
// La logique vivait auparavant dupliquée dans trois formulaires, qui avaient
// divergé. Elle n'existe plus qu'ici.
// ═════════════════════════════════════════════════════════════════════════════

import '../models/enums.dart';

// ── Échelles de saisie ───────────────────────────────────────────────────────
/// Fruité, amertume, piquant — échelle 0–10. La grille PR-48 reste écrite
/// pour 0–5 ; les seuils de classe ne sont pas modifiés ici.
const double kMaxPositif = 10.0;

/// Défauts — échelle COI, absente du PR-48, donc inchangée.
const double kMaxDefaut = 10.0;

const double kPasSlider = 0.1;

/// Classes que le PR-48 §9 interdit à une huile au profil non harmonieux.
const List<ClasseInterne> kClassesSoumisesAHarmonie = [
  ClasseInterne.extraAPlus,
  ClasseInterne.extraA,
];

/// Ordre de la grille §8 — de la meilleure à la plus faible.
const List<ClasseInterne> kClassesGrille = [
  ClasseInterne.extraAPlus,
  ClasseInterne.extraA,
  ClasseInterne.extraBPlus,
  ClasseInterne.extraB,
  ClasseInterne.extraBMoins,
  ClasseInterne.extraC,
];

/// Toutes les classes proposables à la main, « Extra déséquilibrée » incluse.
const List<ClasseInterne> kClassesManuelles = [
  ...kClassesGrille,
  ClasseInterne.extraDesequilibre,
];

// ═════════════════════════════════════════════════════════════════════════════
// NIVEAU 1 — CATÉGORIE COI
// ═════════════════════════════════════════════════════════════════════════════

/// Intensité du défaut dominant — le plus fort des six (méthode COI).
double medianeDefauts({
  double chome = 0,
  double moisi = 0,
  double vinaigre = 0,
  double rance = 0,
  double gele = 0,
  double autresDefaut = 0,
}) {
  final valeurs = [chome, moisi, vinaigre, rance, gele, autresDefaut];
  return valeurs.reduce((a, b) => a > b ? a : b);
}

/// Catégorie réglementaire COI/T.20/Doc. nº 15/Rév. 11.
///
/// Retourne `null` quand rien n'a encore été saisi (aucun défaut ET aucun
/// fruité) ; le formulaire affiche alors « En attente d'évaluation ».
/// Ce comportement existait avant le PR-48 et n'est pas modifié.
ClassificationHuile? calculerClassificationCoi({
  required double mediane,
  required double fruite,
}) {
  if (mediane == 0.0 && fruite == 0.0) return null;
  if (mediane == 0.0 && fruite > 0.0) return ClassificationHuile.extraVierge;
  if (mediane > 0.0 && mediane <= 3.5 && fruite > 0.0) {
    return ClassificationHuile.vierge;
  }
  if (mediane > 6.0) return ClassificationHuile.lampante;
  return ClassificationHuile.viergeOrdinaire;
}

/// Justification affichée sous la catégorie COI.
String descriptionCoi(ClassificationHuile? coi) {
  switch (coi) {
    case ClassificationHuile.extraVierge:
      return 'Médiane des défauts = 0.0 et fruité > 0.0';
    case ClassificationHuile.vierge:
      return '0.0 < médiane des défauts ≤ 3.5 et fruité > 0.0';
    case ClassificationHuile.viergeOrdinaire:
      return 'Médiane des défauts entre 3.5 et 6.0';
    case ClassificationHuile.lampante:
      return 'Médiane des défauts > 6.0 — non comestible en l\'état';
    case null:
      return 'Saisir au moins le fruité pour classifier';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NIVEAU 2 — CLASSE INTERNE PR-48 §8
// ═════════════════════════════════════════════════════════════════════════════

/// Une ligne de la grille §8.
class _LigneGrille {
  final ClasseInterne classe;
  final bool Function(double f, TypeFruite t, double a, double p) correspond;
  const _LigneGrille(this.classe, this.correspond);
}

/// Grille du PR-48 §8, lue de haut en bas — la première ligne qui correspond
/// gagne. Cet ordre est la règle de résolution des chevauchements (fruité pile
/// 3, ou fruité ≤ 2 tout plat) ; le document source ne la précise pas.
const List<_LigneGrille> _grille = [
  // Extra A+ : Fruité ≥5 (vert) ; 3 < Amertume < 4.5 ; 3 ≤ piquant ≤ 5
  _LigneGrille(ClasseInterne.extraAPlus, _extraAPlus),
  // Extra A : 3.5 < Fruité < 4.5 (vert) ; 2.5 < Amertume < 4 ; 2.5 ≤ piquant ≤ 5
  _LigneGrille(ClasseInterne.extraA, _extraA),
  // Extra B+ : 3 ≤ Fruité ≤ 3.5 (vert) ; 2.5 < Amertume < 3.5 ; 3 ≤ piquant ≤ 5
  _LigneGrille(ClasseInterne.extraBPlus, _extraBPlus),
  // Extra B : 2.5 ≤ Fruité ≤ 3 (vert ou vert-mûre) ; 2.5 < Amertume < 3.5 ; 2 ≤ piquant ≤ 3.5
  _LigneGrille(ClasseInterne.extraB, _extraB),
  // Extra B− : Fruité ≤ 2 (majoritairement mûre) ; Amertume et piquant ≤ 2.5
  _LigneGrille(ClasseInterne.extraBMoins, _extraBMoins),
  // Extra C : Fruité ≤ 2 ; Amertume et piquant ≤ 2
  _LigneGrille(ClasseInterne.extraC, _extraC),
];

bool _extraAPlus(double f, TypeFruite t, double a, double p) =>
    f >= 5 && t == TypeFruite.vert && a > 3 && a < 4.5 && p >= 3 && p <= 5;

bool _extraA(double f, TypeFruite t, double a, double p) =>
    f > 3.5 && f < 4.5 && t == TypeFruite.vert && a > 2.5 && a < 4 && p >= 2.5 && p <= 5;

bool _extraBPlus(double f, TypeFruite t, double a, double p) =>
    f >= 3 && f <= 3.5 && t == TypeFruite.vert && a > 2.5 && a < 3.5 && p >= 3 && p <= 5;

bool _extraB(double f, TypeFruite t, double a, double p) =>
    f >= 2.5 &&
    f <= 3 &&
    (t == TypeFruite.vert || t == TypeFruite.vertMur) &&
    a > 2.5 &&
    a < 3.5 &&
    p >= 2 &&
    p <= 3.5;

bool _extraBMoins(double f, TypeFruite t, double a, double p) =>
    f <= 2 && t == TypeFruite.mur && a <= 2.5 && p <= 2.5;

bool _extraC(double f, TypeFruite t, double a, double p) =>
    f <= 2 && a <= 2 && p <= 2;

/// Classe interne PR-48.
///
/// Retourne `null` — « hors grille » — dans trois cas :
///   - l'huile n'est pas extra vierge au sens COI (§6) ;
///   - aucune ligne de la grille §8 ne correspond ;
///   - le profil est déclaré non harmonieux et la grille rendait une classe
///     haute (§9).
///
/// Un `null` impose au dégustateur de choisir la classe à la main.
ClasseInterne? calculerClasseInterne({
  required ClassificationHuile? coi,
  required double fruite,
  required TypeFruite typeFruite,
  required double amertume,
  required double piquant,
  bool profilNonHarmonieux = false,
}) {
  if (coi != ClassificationHuile.extraVierge) return null;

  for (final ligne in _grille) {
    if (ligne.correspond(fruite, typeFruite, amertume, piquant)) {
      if (profilNonHarmonieux && kClassesSoumisesAHarmonie.contains(ligne.classe)) {
        return null;
      }
      return ligne.classe;
    }
  }
  return null;
}

/// Vrai pour les deux classes que le §9 refuse à un profil non harmonieux.
/// La case à cocher n'est proposée que sur celles-là.
bool classeSoumiseAHarmonie(ClasseInterne classe) =>
    kClassesSoumisesAHarmonie.contains(classe);

/// Liste proposée au dégustateur quand la classe est hors grille.
List<ClasseInterne> classesChoisissablesManuellement({
  bool profilNonHarmonieux = false,
}) {
  if (!profilNonHarmonieux) return kClassesManuelles;
  return kClassesManuelles
      .where((c) => !kClassesSoumisesAHarmonie.contains(c))
      .toList();
}

/// Explique pourquoi aucune ligne de la grille ne s'applique.
///
/// Le texte est affiché sous le badge « Hors grille » et figé dans
/// `classe_interne_motif` au moment du choix manuel, pour la traçabilité §14.
String motifHorsGrille({
  required ClassificationHuile? coi,
  required double fruite,
  required TypeFruite typeFruite,
  required double amertume,
  required double piquant,
  bool profilNonHarmonieux = false,
}) {
  if (coi != ClassificationHuile.extraVierge) {
    return 'Réservée aux huiles extra vierges — un défaut a été perçu (§6)';
  }

  if (profilNonHarmonieux) {
    final sansHarmonie = calculerClasseInterne(
      coi: coi,
      fruite: fruite,
      typeFruite: typeFruite,
      amertume: amertume,
      piquant: piquant,
    );
    if (sansHarmonie != null && classeSoumiseAHarmonie(sansHarmonie)) {
      return 'Profil déclaré non harmonieux : ${sansHarmonie.label} est interdite (§9)';
    }
  }

  final f = _n(fruite);

  // Les deux trous de la grille sur l'axe du fruité.
  if (fruite >= 4.5 && fruite < 5) {
    return 'Fruité $f : au-dessus d\'Extra A (< 4.5), en dessous d\'Extra A+ (≥ 5)';
  }
  if (fruite > 2 && fruite < 2.5) {
    return 'Fruité $f : au-dessus d\'Extra B− (≤ 2), en dessous d\'Extra B (≥ 2.5)';
  }

  // Cas §9 : les attributs de structure écrasent le fruité.
  if (fruite <= 2 && (amertume > 2.5 || piquant > 2.5)) {
    return 'Amertume ${_n(amertume)} et piquant ${_n(piquant)} très élevés pour un '
        'fruité de $f — orienter vers Extra déséquilibrée (§9)';
  }

  // Le fruité tombe dans une plage connue : c'est un autre attribut qui bloque.
  if (typeFruite != TypeFruite.vert && fruite > 3) {
    return 'Fruité $f attendu vert pour cette plage ; type saisi : '
        '${typeFruite.label.toLowerCase()}';
  }
  return 'Fruité $f · amertume ${_n(amertume)} · piquant ${_n(piquant)} : aucune '
      'ligne du tableau §8 ne correspond';
}

// ═════════════════════════════════════════════════════════════════════════════
// RÉSULTAT CONSOLIDÉ — ce que le formulaire affiche et ce qu'il envoie
// ═════════════════════════════════════════════════════════════════════════════

/// Les deux niveaux de classification pour un jeu de valeurs donné.
///
/// Le formulaire en construit un seul par saisie et s'en sert à la fois pour
/// l'affichage et pour le corps de la requête, ce qui garantit que l'écran et
/// la base disent la même chose.
class ResultatClassification {
  /// Niveau 1. `null` tant que rien n'est saisi.
  final ClassificationHuile? coi;

  /// Ce que la grille §8 rend en ignorant la case d'harmonie.
  /// Sert à décider si la case doit être proposée — sans quoi elle
  /// disparaîtrait dès qu'on la coche.
  final ClasseInterne? classeGrille;

  final bool profilNonHarmonieux;

  /// Classe retenue par le dégustateur quand la grille ne rend rien.
  final ClasseInterne? classeManuelle;

  const ResultatClassification._({
    required this.coi,
    required this.classeGrille,
    required this.profilNonHarmonieux,
    required this.classeManuelle,
  });

  factory ResultatClassification({
    required double fruite,
    required TypeFruite typeFruite,
    required double amertume,
    required double piquant,
    required double mediane,
    bool profilNonHarmonieux = false,
    ClasseInterne? classeManuelle,
  }) {
    final coi = calculerClassificationCoi(mediane: mediane, fruite: fruite);
    final grille = calculerClasseInterne(
      coi: coi,
      fruite: fruite,
      typeFruite: typeFruite,
      amertume: amertume,
      piquant: piquant,
    );
    return ResultatClassification._(
      coi: coi,
      classeGrille: grille,
      profilNonHarmonieux: profilNonHarmonieux,
      classeManuelle: classeManuelle,
    );
  }

  /// Le §6 ferme la classification interne aux huiles non extra vierges.
  bool get interneApplicable => coi == ClassificationHuile.extraVierge;

  /// La case d'harmonie n'est proposée que sur les deux classes hautes (§9).
  bool get harmonieProposable =>
      classeGrille != null && classeSoumiseAHarmonie(classeGrille!);

  /// Classe rendue automatiquement, case d'harmonie appliquée.
  ClasseInterne? get classeAuto =>
      profilNonHarmonieux && harmonieProposable ? null : classeGrille;

  /// Vrai quand aucune ligne ne s'applique et qu'un choix manuel est requis.
  bool get horsGrille => interneApplicable && classeAuto == null;

  /// Ce qui part en base : la grille si elle répond, sinon le choix manuel.
  ClasseInterne? get classeRetenue =>
      !interneApplicable ? null : (classeAuto ?? classeManuelle);

  bool get estManuelle => horsGrille && classeManuelle != null;

  /// Classes proposées au dégustateur dans le sélecteur manuel.
  List<ClasseInterne> get classesProposees => classesChoisissablesManuellement(
        profilNonHarmonieux: profilNonHarmonieux && harmonieProposable,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// INTENSITÉ — dépend de l'échelle, donc de la nature de l'attribut
// ═════════════════════════════════════════════════════════════════════════════

/// Étiquette d'intensité COI, rebasée sur l'échelle de l'attribut.
///
/// Les défauts gardent les seuils historiques 3 et 6 sur 0–10 ; les attributs
/// positifs, passés en 0–5, prennent 1.5 et 3. Sans ce recalage, un fruité au
/// maximum s'afficherait « Moyen » et rien ne serait jamais « Robuste ».
String intensiteLabel(double valeur, {required bool positif}) {
  if (valeur == 0.0) return '';
  final seuilBas = positif ? 1.5 : 3.0;
  final seuilHaut = positif ? 3.0 : 6.0;
  if (valeur <= seuilBas) return 'Délicat';
  if (valeur <= seuilHaut) return 'Moyen';
  return 'Robuste';
}

String _n(double v) => v.toStringAsFixed(1);
