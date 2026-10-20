// Tâche 59 : date de livraison en deux boutons, champ « Variété d'olive » multiple.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/2_collecteur/mes_echantillons/widgets/dialogs/date_livraison_section.dart';
import 'package:project3/core/widgets/champ_varietes.dart';

Widget _cadre(Widget enfant) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: enfant),
  ),
);

void main() {
  group('date de livraison', () {
    Widget section({
      ModePlanificationUI mode = ModePlanificationUI.dateExacte,
      DateTime? dateExacte,
      ValueChanged<ModePlanificationUI>? onMode,
    }) => _cadre(
      DateLivraisonSection(
        mode: mode,
        onModeChanged: onMode ?? (_) {},
        dateExacte: dateExacte,
        periodeDebut: null,
        periodeFin: null,
        onDateExacteChanged: (_) {},
        onPeriodeDebutChanged: (_) {},
        onPeriodeFinChanged: (_) {},
      ),
    );

    testWidgets("plus de case « Date d'arrivage prévue »", (tester) async {
      await tester.pumpWidget(section());
      expect(find.text("Date d'arrivage prévue"), findsNothing);
      expect(find.text('Sélectionner une date'), findsNothing);
      expect(find.text('À partir du'), findsNothing);
    });

    testWidgets('« Date précise » ouvre directement le calendrier', (
      tester,
    ) async {
      await tester.pumpWidget(section());
      await tester.tap(find.text('Date précise'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('« Période estimée » ouvre le calendrier de période', (
      tester,
    ) async {
      ModePlanificationUI? choisi;
      await tester.pumpWidget(section(onMode: (m) => choisi = m));
      await tester.tap(find.text('Période estimée'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      // Annuler ne change pas le mode.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(choisi, isNull);
    });

    testWidgets('la date choisie s\'affiche sous les boutons', (tester) async {
      await tester.pumpWidget(section(dateExacte: DateTime(2030, 3, 4)));
      expect(find.text('Livraison prévue le 04/03/2030'), findsOneWidget);
    });
  });

  group('variété d\'olive', () {
    testWidgets('plusieurs variétés, séparées par des virgules', (
      tester,
    ) async {
      final ctrl = TextEditingController(text: 'Chemlali');
      await tester.pumpWidget(
        _cadre(
          ChampVarietes(
            controller: ctrl,
            chargerVarietes: () async => const [],
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Oueslati');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 300));

      expect(ctrl.text, 'Chemlali, Oueslati');
      expect(find.byType(InputChip), findsNWidgets(2));
    });

    testWidgets('une saisie non validée par « + » est quand même gardée', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _cadre(
          ChampVarietes(
            controller: ctrl,
            chargerVarietes: () async => const [],
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Sayali');
      await tester.pump(const Duration(milliseconds: 300));

      expect(ctrl.text, 'Sayali');
    });

    testWidgets('un nom proche affiche « Vouliez-vous dire … ? »', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _cadre(
          ChampVarietes(
            controller: ctrl,
            chargerVarietes: () async => ['Chemlali', 'Chétoui', 'Oueslati'],
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'chemlasi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.textContaining('Vouliez-vous dire'), findsOneWidget);
      expect(find.textContaining('Chemlali'), findsWidgets);
    });

    testWidgets('pré-remplissage externe (étiquette) refait les puces', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _cadre(
          ChampVarietes(
            controller: ctrl,
            chargerVarietes: () async => const [],
          ),
        ),
      );
      ctrl.text = 'Chétoui, Gerboui';
      await tester.pump();
      expect(find.byType(InputChip), findsNWidgets(2));
    });
  });
}
