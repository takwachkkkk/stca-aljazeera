// Service achat : achats confirmés, livraison prévue, rien de la dégustation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/6_service_achat/achats/achats_service_achat_page.dart';
import 'package:project3/6_service_achat/achats/models/achat_service_achat.dart';
import 'package:project3/6_service_achat/achats/services/achats_service_achat_service.dart';
import 'package:project3/core/models/enums.dart';
import 'package:project3/core/widgets/statut_chip.dart';

class _FauxService extends AchatsServiceAchatService {
  final List<AchatServiceAchat> achats;
  _FauxService(this.achats);

  bool echec = false;
  final List<String> factures = [];

  @override
  Future<List<AchatServiceAchat>> fetchAchats() async => achats;

  @override
  Future<AchatServiceAchat> facturer(String id) async {
    if (echec) throw Exception('serveur injoignable');
    factures.add(id);
    return _achat(
      id,
      null,
      facture: true,
      dateFacture: DateTime(2026, 11, 1),
      factureParNom: 'Ichrak C',
    );
  }
}

AchatServiceAchat _achat(
  String ref,
  DateTime? livraison, {
  bool facture = false,
  DateTime? dateFacture,
  String? factureParNom,
}) => AchatServiceAchat(
  id: ref,
  numero: '2026/$ref',
  referenceBouteille: ref,
  fournisseurNom: 'hami',
  fournisseurLieu: 'Gabès',
  gouvernorat: 'Gabès',
  quantiteCibleT: 12,
  dateLivraisonPrevue: livraison,
  facture: facture,
  dateFacture: dateFacture,
  factureParNom: factureParNom,
);

Widget _page(_FauxService service) =>
    MaterialApp(home: AchatsServiceAchatPage(service: service));

Finder _boutonFacturer() => find.widgetWithText(FilledButton, 'Facturer');

void main() {
  test('le rôle Service achat est lu depuis le serveur', () {
    expect(
      RoleUtilisateurX.fromJson('service_achat'),
      RoleUtilisateur.serviceAchat,
    );
    expect(RoleUtilisateur.serviceAchat.toJson, 'service_achat');
    expect(RoleUtilisateur.serviceAchat.label, 'Service achat');
  });

  test('état de la livraison selon la date prévue', () {
    final maintenant = DateTime(2026, 10, 27);
    expect(
      _achat('A', DateTime(2026, 11, 2)).etatLivraison(maintenant),
      EtatLivraison.aVenir,
    );
    expect(
      _achat('B', DateTime(2026, 10, 20)).etatLivraison(maintenant),
      EtatLivraison.enRetard,
    );
    expect(_achat('C', null).etatLivraison(maintenant), EtatLivraison.sansDate);
  });

  test('la facturation est lue depuis le serveur', () {
    final achat = AchatServiceAchat.fromJson({
      'id': 'a',
      'facture': true,
      'date_facture': '2026-11-01T10:00:00Z',
      'facture_par_nom': 'Ichrak C',
    });
    expect(achat.facture, isTrue);
    expect(achat.dateFacture, isNotNull);
    expect(achat.factureParNom, 'Ichrak C');
    expect(AchatServiceAchat.fromJson({'id': 'b'}).facture, isFalse);
  });

  testWidgets('liste, date prévue, et plus de filtre « En retard »', (
    tester,
  ) async {
    final demain = DateTime.now().add(const Duration(days: 3));
    final passe = DateTime.now().subtract(const Duration(days: 5));
    await tester.pumpWidget(
      _page(_FauxService([_achat('FUTUR', demain), _achat('PASSE', passe)])),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 achats confirmés'), findsOneWidget);
    expect(find.textContaining('Livraison prévue le'), findsNWidgets(2));
    expect(find.text('La date prévue est dépassée.'), findsOneWidget);
    // Aucune donnée de dégustation ni de laboratoire sur cette page.
    expect(find.textContaining('Classification'), findsNothing);
    expect(find.textContaining('Analyse'), findsNothing);

    expect(find.text('En retard'), findsNothing);
  });

  testWidgets('le filtre Facturer ne garde que les stocks facturés', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        _FauxService([
          _achat('FAIT', null, facture: true),
          _achat('RESTE', null),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 achats confirmés'), findsOneWidget);

    await tester.tap(find.widgetWithText(StatutChip, 'Facturer'));
    await tester.pumpAndSettle();

    expect(find.text('1 achat confirmé'), findsOneWidget);
    expect(find.text('FAIT'), findsWidgets);
    expect(find.text('RESTE'), findsNothing);
  });

  testWidgets('Facturer demande confirmation puis marque le stock', (
    tester,
  ) async {
    final service = _FauxService([_achat('A', null)]);
    await tester.pumpWidget(_page(service));
    await tester.pumpAndSettle();

    await tester.tap(_boutonFacturer());
    await tester.pumpAndSettle();
    expect(find.text('Facturer ce stock ?'), findsOneWidget);
    expect(service.factures, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Facturer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.factures, ['A']);
    expect(find.textContaining('Facturé le 01/11/2026'), findsOneWidget);
    expect(find.textContaining('par Ichrak C'), findsOneWidget);
    expect(_boutonFacturer(), findsNothing);
  });

  testWidgets('Annuler ne facture rien', (tester) async {
    final service = _FauxService([_achat('A', null)]);
    await tester.pumpWidget(_page(service));
    await tester.pumpAndSettle();

    await tester.tap(_boutonFacturer());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(service.factures, isEmpty);
    expect(_boutonFacturer(), findsOneWidget);
  });

  testWidgets('en cas d\'échec, le bouton reste et un message s\'affiche', (
    tester,
  ) async {
    final service = _FauxService([_achat('A', null)])..echec = true;
    await tester.pumpWidget(_page(service));
    await tester.pumpAndSettle();

    await tester.tap(_boutonFacturer());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Facturer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("n'a pas été facturé"), findsOneWidget);
    expect(_boutonFacturer(), findsOneWidget);
  });
}
