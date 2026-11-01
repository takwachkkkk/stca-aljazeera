import 'package:flutter_test/flutter_test.dart';
import 'package:project3/core/utils/montant_achat.dart';

void main() {
  group('MontantAchat', () {
    test('lit un prix sans unité comme un prix par kilo', () {
      expect(MontantAchat.prixParKg('8.75'), 8.75);
      expect(MontantAchat.calculer('8.75', '30'), closeTo(262500, 0.0001));
      expect(MontantAchat.formater('8.75', '30'), '262 500 DT');
    });

    test('affiche le prix par kilo et le prix par tonne qui en découle', () {
      expect(MontantAchat.formaterPrixParKg('8.75'), '8.750 DT/kg');
      expect(MontantAchat.formaterPrixParTonne('8.75'), '8 750 DT/tonne');
    });

    test('accepte la virgule comme séparateur décimal', () {
      expect(MontantAchat.formaterPrixParTonne('8,125'), '8 125 DT/tonne');
    });

    test('garde la valeur d’un ancien prix explicite par tonne', () {
      expect(MontantAchat.formaterPrixParKg('8 000 TND/T'), '8.000 DT/kg');
    });

    test('conserve le total d’un ancien prix explicite par litre', () {
      expect(
        MontantAchat.calculer('9.50 TND/L', '30'),
        closeTo(311135.3711790393, 0.0001),
      );
    });

    test('ne renvoie rien pour un prix vide ou illisible', () {
      expect(MontantAchat.formaterPrixParKg(''), isNull);
      expect(MontantAchat.formaterPrixParTonne('abc'), isNull);
    });
  });
}
