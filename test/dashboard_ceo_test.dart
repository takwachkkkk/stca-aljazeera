import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project3/1_ceo/tableau_de_bord/models/dashboard_models.dart';
import 'package:project3/1_ceo/tableau_de_bord/widgets/investissement_card.dart';

void main() {
  group('CardDateRange.label', () {
    String label(DateTime debut, DateTime fin) =>
        CardDateRange(debut, fin).label;

    test('une plage partielle garde ses jours', () {
      expect(
        label(DateTime(2026, 3, 3), DateTime(2026, 3, 20)),
        '3 – 20 Mar 2026',
      );
      expect(
        label(DateTime(2025, 11, 5), DateTime(2026, 2, 10)),
        '5 Nov 2025 – 10 Fév 2026',
      );
    });

    test('des mois entiers restent courts', () {
      expect(label(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), 'Mar 2026');
      expect(
        label(DateTime(2026, 1, 1), DateTime(2026, 6, 30)),
        'Jan – Jun 2026',
      );
    });

    test('un seul jour', () {
      expect(label(DateTime(2026, 3, 3), DateTime(2026, 3, 3)), '3 Mar 2026');
    });
  });

  test('deux périodes identiques sont une seule période', () {
    expect(
      {
        CardDateRange(DateTime(2026, 1, 1), DateTime(2026, 2, 1)),
        CardDateRange(DateTime(2026, 1, 1), DateTime(2026, 2, 1)),
      }.length,
      1,
    );
  });

  test('nom de fournisseur abrégé', () {
    expect(nomFournisseurCourt('James Nasri'), 'James.N');
    expect(nomFournisseurCourt('Mohamed Ali Ben Salah'), 'Mohamed.S');
    expect(nomFournisseurCourt('  Sami  '), 'Sami');
  });

  test('lit la synthèse des achats du serveur', () {
    final snapshot = DashboardCeoSnapshot.fromJson({
      'achats': {
        'montant_total': 1200000.0,
        'quantite_totale_t': 50.0,
        'nombre': 1,
        'sans_quantite': 0,
        'categories': [
          {
            'cle': 'extra_vierge',
            'quantite_t': 50.0,
            'montant': 1200000.0,
            'nombre': 1,
          },
        ],
        'dernier_prix': {
          'extra_vierge': {'prix': 24.0, 'date': '2026-10-20'},
          'vierge': null,
        },
      },
    });

    expect(snapshot.achats.montantTotal, 1200000);
    expect(snapshot.achats.categories.single.libelle, 'Extra vierge');
    expect(snapshot.achats.dernierPrixExtra!.prix, 24);
    expect(snapshot.achats.dernierPrixVierge, isNull);
  });

  group('InvestissementCard', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> afficher(WidgetTester tester, SyntheseAchats achats) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InvestissementCard(
                achats: achats,
                submittedAnalyses: 0,
                dateChip: const SizedBox(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('montre montant, quantités et derniers prix', (tester) async {
      await afficher(
        tester,
        SyntheseAchats(
          montantTotal: 1200000,
          quantiteTotaleT: 50,
          nombre: 1,
          sansQuantite: 1,
          categories: const [
            AchatCategorie('extra_vierge', 50, 1200000, 1),
            AchatCategorie('lampante', 0, 0, 0),
            AchatCategorie('non_classe', 0, 0, 1),
          ],
          dernierPrixExtra: DernierPrix(24, DateTime(2026, 10, 20)),
          dernierPrixVierge: null,
        ),
      );
      tester.takeException();

      expect(find.text('Extra vierge'), findsNWidgets(2));
      expect(find.text('50 t'), findsOneWidget);
      expect(find.text('Lampante'), findsOneWidget);
      expect(find.text('Non classé'), findsOneWidget);
      expect(find.text('le 20 Oct 2026'), findsOneWidget);
      expect(find.text('Aucun achat sur la période'), findsOneWidget);
      expect(
        find.text(
          "1 achat n'a pas de quantité : il n'est pas dans ce montant.",
        ),
        findsOneWidget,
      );
    });
  });
}
