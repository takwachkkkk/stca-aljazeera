import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/1_ceo/analyse_organoleptique/widgets/panel_section.dart';
import 'package:project3/1_ceo/analyse_organoleptique/widgets/panel_widgets.dart';
import 'package:project3/1_ceo/utilisateurs/models/echantillon_ceo_view.dart';
import 'package:project3/core/widgets/champ_prix_kg.dart';

EchantillonCeoView _echantillon() => EchantillonCeoView(
  id: 'id-1',
  numero: '2026/0001',
  referenceBouteille: 'CHEMLALI-C4',
  gouvernorat: 'Sfax',
  fournisseurTexte: 'Fournisseur',
  dateAjout: '2026-10-01',
  dateArriveeEchantillon: '01/10/2026',
  recuPhysiquement: true,
  statut: StatutCeo.selectionne,
  totalTasteurs: 4,
);

void main() {
  testWidgets('la réception physique ne déborde pas à côté des décisions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: PanelSection(
              echantillon: _echantillon(),
              isExpanded: false,
              onToggle: () {},
              onViewForm: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecuPhysiqueIndicator));
    await tester.pumpAndSettle();

    expect(find.text('Réception physique confirmée'), findsOneWidget);
    final texte = tester.getRect(find.text('Réception physique confirmée'));
    expect(texte.width, greaterThan(120));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });

  testWidgets('le prix par tonne suit le prix saisi au kilo', (tester) async {
    final controleur = TextEditingController();
    addTearDown(controleur.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChampPrixKg(
            controller: controleur,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    expect(find.text('DT/kg'), findsOneWidget);
    expect(find.text('Prix par tonne'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '8,125');
    await tester.pump();

    expect(find.text('8 125 DT/tonne'), findsOneWidget);
  });

  testWidgets('la direction ne voit que le prix au kilo', (tester) async {
    final controleur = TextEditingController();
    addTearDown(controleur.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChampPrixKg(
            controller: controleur,
            decoration: const InputDecoration(),
            afficherPrixTonne: false,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '8,125');
    await tester.pump();

    expect(find.text('DT/kg'), findsOneWidget);
    expect(find.text('Prix par tonne'), findsNothing);
    expect(find.text('8 125 DT/tonne'), findsNothing);
  });
}
