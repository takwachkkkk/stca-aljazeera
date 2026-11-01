import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/5_chef_degustateur/tableau_de_bord/widgets/app_drawer.dart';
import 'package:project3/core/fonctionnalites.dart';

void main() {
  test('le laboratoire est masqué par défaut', () {
    expect(kLaboActif, isFalse);
  });

  testWidgets('le menu ne propose plus le laboratoire', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(drawer: const AppDrawer(), appBar: AppBar()),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Analyse de laboratoire'), findsNothing);
  });
}
