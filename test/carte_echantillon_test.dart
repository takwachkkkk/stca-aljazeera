// En-tête de carte d'échantillon — tests de débordement.
//
// Le bug d'origine : le badge « reçu physiquement » se déplie au clic sur le
// texte « Échantillon présent dans la société », qui poussait tout l'en-tête
// hors de la carte (29 px) et écrasait la référence en une colonne d'un
// caractère par ligne.
//
// Un débordement fait échouer un test Flutter tout seul : il suffit donc de
// rendre la carte sur un écran étroit et de déplier le badge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/1_ceo/analyse_organoleptique/widgets/panel_widgets.dart'
    show RecuPhysiqueIndicator;
import 'package:project3/1_ceo/widgets/base_sample_card.dart';
import 'package:project3/core/widgets/grille_details.dart';

/// Largeur d'un téléphone courant. Le bug ne se voyait pas sur un écran large.
const Size _ecranTelephone = Size(360, 780);

Future<void> _rendre(
  WidgetTester tester, {
  required String reference,
  required String id,
  required bool recu,
}) async {
  tester.view.physicalSize = _ecranTelephone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            BaseSampleCard(
              referenceBouteille: reference,
              id: id,
              tintColor: Colors.white,
              accentColor: const Color(0xFF38835A),
              badge: CardBadgeRow(
                badges: [
                  const CardBadge(label: 'Qté : 12T', color: Color(0xFF6B8143)),
                  RecuPhysiqueIndicator(recuPhysiquement: recu),
                ],
              ),
              detailItems: const [
                DetailItem('Gouvernorat', 'Sfax — Sfax Sud'),
                DetailItem('Variété', 'Chemlali'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('En-tête de carte sur écran étroit', () {
    testWidgets('tient sans déborder au repos', (tester) async {
      await _rendre(
        tester,
        reference: 'CHEMLALI-C4',
        id: '2026/0002',
        recu: true,
      );
      expect(find.text('CHEMLALI-C4'), findsOneWidget);
      expect(find.text('2026/0002'), findsOneWidget);
    });

    testWidgets('tient quand le badge « reçu » se déplie', (tester) async {
      await _rendre(
        tester,
        reference: 'CHEMLALI-C4',
        id: '2026/0002',
        recu: true,
      );

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();

      // Le texte long apparaît — et rien ne déborde, sinon le test échouerait.
      expect(
        find.text('Réception physique confirmée'),
        findsOneWidget,
      );
    });

    testWidgets('non reçu : pas de coche grise du tout', (tester) async {
      await _rendre(
        tester,
        reference: 'CHEMLALI-C4',
        id: '2026/0002',
        recu: false,
      );

      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('une référence très longue est coupée, pas débordée',
        (tester) async {
      await _rendre(
        tester,
        reference: 'COOPERATIVE-OLEICOLE-SIDI-BOUZID-NORD-2026',
        id: '2026/0002-EXTENSION-TRES-LONGUE',
        recu: true,
      );
      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();
    });
  });
}
