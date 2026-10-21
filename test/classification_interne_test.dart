// Grille de classification interne PR-48 §8.
//
// Ce jeu de cas est le même que celui de backend_new/evaluations/tests.py
// (classe GrillePr48Tests) : les deux implémentations doivent rendre exactement
// les mêmes résultats.

import 'package:flutter_test/flutter_test.dart';
import 'package:project3/core/classification/classification_interne.dart';
import 'package:project3/core/models/enums.dart';

ClasseInterne? classe(
  double fruite,
  TypeFruite type,
  double amertume,
  double piquant, {
  double mediane = 0.0,
  bool nonHarmonieux = false,
}) {
  final coi = calculerClassificationCoi(mediane: mediane, fruite: fruite);
  return calculerClasseInterne(
    coi: coi,
    fruite: fruite,
    typeFruite: type,
    amertume: amertume,
    piquant: piquant,
    profilNonHarmonieux: nonHarmonieux,
  );
}

void main() {
  group('Un cas nominal par classe', () {
    test('Extra A+', () {
      expect(classe(5.0, TypeFruite.vert, 3.5, 4.0), ClasseInterne.extraAPlus);
    });
    test('Extra A', () {
      expect(classe(4.0, TypeFruite.vert, 3.0, 3.5), ClasseInterne.extraA);
    });
    test('Extra B+', () {
      expect(classe(3.5, TypeFruite.vert, 3.0, 3.5), ClasseInterne.extraBPlus);
    });
    test('Extra B', () {
      expect(classe(2.5, TypeFruite.vertMur, 3.0, 3.0), ClasseInterne.extraB);
    });
    test('Extra B−', () {
      expect(classe(2.0, TypeFruite.mur, 2.5, 2.0), ClasseInterne.extraBMoins);
    });
    test('Extra C', () {
      expect(classe(1.5, TypeFruite.vert, 1.5, 1.5), ClasseInterne.extraC);
    });
  });

  group('Cas hors grille', () {
    test('fruité 4.7 : entre Extra A et Extra A+', () {
      expect(classe(4.7, TypeFruite.vert, 3.5, 4.0), isNull);
    });
    test('fruité 2.3 : entre Extra B− et Extra B', () {
      expect(classe(2.3, TypeFruite.vert, 3.0, 3.0), isNull);
    });
    test('amertume pile 3.0 : Extra A+ exige strictement plus de 3', () {
      expect(classe(5.0, TypeFruite.vert, 3.0, 4.0), isNull);
    });
    test('amertume et piquant écrasent le fruité (cas §9)', () {
      expect(classe(2.0, TypeFruite.vert, 4.5, 5.0), isNull);
    });
  });

  group('Chevauchements résolus par l\'ordre de lecture', () {
    test('fruité pile 3 donne Extra B+, pas Extra B', () {
      expect(classe(3.0, TypeFruite.vert, 3.0, 3.5), ClasseInterne.extraBPlus);
    });
    test('profil plat et mûr donne Extra B−, pas Extra C', () {
      expect(classe(1.5, TypeFruite.mur, 1.5, 1.5), ClasseInterne.extraBMoins);
    });
  });

  group('Condition préalable §6', () {
    test('un défaut à 2.0 ferme la classification interne', () {
      expect(classe(5.0, TypeFruite.vert, 3.5, 4.0, mediane: 2.0), isNull);
    });
    test('fruité nul ferme la classification interne', () {
      final coi = calculerClassificationCoi(mediane: 2.0, fruite: 0.0);
      expect(coi, ClassificationHuile.viergeOrdinaire);
      expect(
        calculerClasseInterne(
          coi: coi,
          fruite: 0.0,
          typeFruite: TypeFruite.vert,
          amertume: 0.0,
          piquant: 0.0,
        ),
        isNull,
      );
    });
  });

  group('Critère « profil harmonieux » §8 et §9', () {
    test('annule Extra A+', () {
      expect(classe(5.0, TypeFruite.vert, 3.5, 4.0, nonHarmonieux: true), isNull);
    });
    test('annule Extra A', () {
      expect(classe(4.0, TypeFruite.vert, 3.0, 3.5, nonHarmonieux: true), isNull);
    });
    test('laisse Extra B+ intacte — le §9 ne vise que les deux classes hautes', () {
      expect(
        classe(3.5, TypeFruite.vert, 3.0, 3.5, nonHarmonieux: true),
        ClasseInterne.extraBPlus,
      );
    });
    test('la liste manuelle exclut les classes hautes', () {
      final proposees =
          classesChoisissablesManuellement(profilNonHarmonieux: true);
      expect(proposees, isNot(contains(ClasseInterne.extraAPlus)));
      expect(proposees, isNot(contains(ClasseInterne.extraA)));
      expect(proposees, contains(ClasseInterne.extraDesequilibre));
    });
    test('la liste manuelle est complète par défaut', () {
      final proposees = classesChoisissablesManuellement();
      expect(proposees.length, 7);
      expect(proposees, contains(ClasseInterne.extraAPlus));
    });
    test('la case ne concerne que Extra A+ et Extra A', () {
      expect(classeSoumiseAHarmonie(ClasseInterne.extraAPlus), isTrue);
      expect(classeSoumiseAHarmonie(ClasseInterne.extraA), isTrue);
      expect(classeSoumiseAHarmonie(ClasseInterne.extraBPlus), isFalse);
    });
  });

  group('Catégorie COI — inchangée par le PR-48', () {
    test('rien saisi', () {
      expect(calculerClassificationCoi(mediane: 0.0, fruite: 0.0), isNull);
    });
    test('extra vierge', () {
      expect(
        calculerClassificationCoi(mediane: 0.0, fruite: 3.0),
        ClassificationHuile.extraVierge,
      );
    });
    test('vierge', () {
      expect(
        calculerClassificationCoi(mediane: 2.0, fruite: 3.0),
        ClassificationHuile.vierge,
      );
    });
    test('vierge ordinaire', () {
      expect(
        calculerClassificationCoi(mediane: 5.0, fruite: 3.0),
        ClassificationHuile.viergeOrdinaire,
      );
    });
    test('lampante', () {
      expect(
        calculerClassificationCoi(mediane: 7.0, fruite: 3.0),
        ClassificationHuile.lampante,
      );
    });
    test('la médiane est le plus fort des six défauts', () {
      expect(
        medianeDefauts(
          chome: 0.0,
          moisi: 1.5,
          vinaigre: 0.0,
          rance: 3.0,
          gele: 0.0,
          autresDefaut: 0.5,
        ),
        3.0,
      );
    });
  });

  group('Intensité : Léger / Moyen / Intense', () {
    test('attributs positifs sur 0–10 : seuils 3 et 6', () {
      expect(intensiteLabel(10.0, positif: true), 'Intense');
      expect(intensiteLabel(7.0, positif: true), 'Intense');
      expect(intensiteLabel(5.0, positif: true), 'Moyen');
      expect(intensiteLabel(1.0, positif: true), 'Léger');
      expect(intensiteLabel(0.0, positif: true), '');
    });
    test('défauts : seuils 3 et 6 sur 0–10', () {
      expect(intensiteLabel(3.0, positif: false), 'Léger');
      expect(intensiteLabel(5.0, positif: false), 'Moyen');
      expect(intensiteLabel(8.0, positif: false), 'Intense');
    });
  });

  group('Motif hors grille', () {
    test('nomme le trou entre Extra A et Extra A+', () {
      final motif = motifHorsGrille(
        coi: ClassificationHuile.extraVierge,
        fruite: 4.7,
        typeFruite: TypeFruite.vert,
        amertume: 3.5,
        piquant: 4.0,
      );
      expect(motif, contains('4.7'));
      expect(motif, contains('Extra A+'));
    });
    test('nomme le §6 quand l\'huile n\'est pas extra vierge', () {
      final motif = motifHorsGrille(
        coi: ClassificationHuile.vierge,
        fruite: 5.0,
        typeFruite: TypeFruite.vert,
        amertume: 3.5,
        piquant: 4.0,
      );
      expect(motif, contains('extra vierges'));
    });
    test('nomme le §9 quand la case harmonie est cochée', () {
      final motif = motifHorsGrille(
        coi: ClassificationHuile.extraVierge,
        fruite: 5.0,
        typeFruite: TypeFruite.vert,
        amertume: 3.5,
        piquant: 4.0,
        profilNonHarmonieux: true,
      );
      expect(motif, contains('non harmonieux'));
      expect(motif, contains('Extra A+'));
    });
  });
}
