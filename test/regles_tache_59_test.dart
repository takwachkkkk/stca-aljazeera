// Tâche 59 : mot de passe « lettres + chiffres » et indication de variété proche.

import 'package:flutter_test/flutter_test.dart';
import 'package:project3/core/password_validation.dart';
import 'package:project3/core/services/variete_service.dart';

void main() {
  group('mot de passe', () {
    test('lettres + chiffres suffisent', () {
      expect(validatePassword('abc123'), isNull);
      expect(validatePassword('Olive2026'), isNull);
    });

    test('il faut au moins une lettre et un chiffre', () {
      expect(validatePassword('abcdef'), isNotNull);
      expect(validatePassword('123456'), isNotNull);
      expect(validatePassword('ab1'), isNotNull);
    });
  });

  group('variété proche', () {
    const connues = ['Chemlali', 'Chétoui', 'Oueslati'];

    test('une faute de frappe propose la variété connue', () {
      expect(VarieteService.varieteProche('chemlasi', connues), 'Chemlali');
      expect(VarieteService.varieteProche('chetoui', connues), 'Chétoui');
    });

    test('rien de proche : aucune indication', () {
      expect(VarieteService.varieteProche('Picholine', connues), isNull);
      expect(VarieteService.varieteProche('', connues), isNull);
    });

    test('la comparaison ignore casse et accents', () {
      expect(
        VarieteService.normaliser('Chétoui'),
        VarieteService.normaliser('CHETOUI'),
      );
    });
  });
}
