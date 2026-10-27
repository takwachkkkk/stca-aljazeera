// Service achat : achats confirmés, livraison prévue, rien de la dégustation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/6_service_achat/achats/achats_service_achat_page.dart';
import 'package:project3/6_service_achat/achats/models/achat_service_achat.dart';
import 'package:project3/6_service_achat/achats/services/achats_service_achat_service.dart';
import 'package:project3/core/models/enums.dart';

class _FauxService extends AchatsServiceAchatService {
  final List<AchatServiceAchat> achats;
  _FauxService(this.achats);

  @override
  Future<List<AchatServiceAchat>> fetchAchats() async => achats;
}

AchatServiceAchat _achat(String ref, DateTime? livraison) => AchatServiceAchat(
  id: ref,
  numero: '2026/$ref',
  referenceBouteille: ref,
  fournisseurNom: 'hami',
  fournisseurLieu: 'Gabès',
  gouvernorat: 'Gabès',
  quantiteCibleT: 12,
  dateLivraisonPrevue: livraison,
);

void main() {
  test('le rôle Service achat est lu depuis le serveur', () {
    expect(RoleUtilisateurX.fromJson('service_achat'), RoleUtilisateur.serviceAchat);
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

  testWidgets('liste, date prévue et filtre « En retard »', (tester) async {
    final demain = DateTime.now().add(const Duration(days: 3));
    final passe = DateTime.now().subtract(const Duration(days: 5));
    await tester.pumpWidget(
      MaterialApp(
        home: AchatsServiceAchatPage(
          service: _FauxService([_achat('FUTUR', demain), _achat('PASSE', passe)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 achats confirmés'), findsOneWidget);
    expect(find.textContaining('Livraison prévue le'), findsNWidgets(2));
    expect(find.text('La date prévue est dépassée.'), findsOneWidget);
    // Aucune donnée de dégustation ni de laboratoire sur cette page.
    expect(find.textContaining('Classification'), findsNothing);
    expect(find.textContaining('Analyse'), findsNothing);

    await tester.tap(find.text('En retard'));
    await tester.pumpAndSettle();
    expect(find.text('1 achat confirmé'), findsOneWidget);
  });
}
