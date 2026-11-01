import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/core/models/enums.dart';
import 'package:project3/core/models/message.dart';
import 'package:project3/core/services/alerte_message_service.dart';
import 'package:project3/core/widgets/messagerie/alerte_message_hote.dart';
import 'package:project3/core/widgets/messagerie/conversations_page.dart';

Message _message(
  String id, {
  String expediteur = 'ali',
  String contenu = 'Bonjour',
}) => Message(
  id: id,
  expediteur: expediteur,
  destinataire: 'moi',
  expediteurNom: 'Ali Trabelsi',
  destinataireNom: 'Moi',
  contenu: contenu,
  dateEnvoi: '2026-11-01T10:00:00Z',
);

class _Banc {
  List<Message> nonLus = [];
  int sons = 0;
  bool visible = true;
  final notifications = <Message>[];

  late final service = AlerteMessageService(
    chargerNonLus: () async => nonLus,
    jouerSon: () async => sons++,
    notifierTelephone: (message) async => notifications.add(message),
    appliVisible: () => visible,
  );
}

void main() {
  group('alerte de nouveau message', () {
    test('ne sonne pas pour ce qui était déjà là à la connexion', () async {
      final banc = _Banc()..nonLus = [_message('1')];

      await banc.service.verifier();

      expect(banc.sons, 0);
      expect(banc.service.alerte.value, isNull);
    });

    test('un nouveau message sonne une seule fois', () async {
      final banc = _Banc();
      await banc.service.verifier();

      banc.nonLus = [_message('1')];
      await banc.service.verifier();
      await banc.service.verifier();

      expect(banc.sons, 1);
      expect(banc.service.alerte.value?.id, '1');
    });

    test(
      'rien pour la conversation déjà affichée, mais la page est prévenue',
      () async {
        final banc = _Banc();
        await banc.service.verifier();
        banc.service.conversationOuverte = 'ali';
        var prevenue = 0;
        final abonnement = banc.service.nouveauxMessages.listen(
          (_) => prevenue++,
        );

        banc.nonLus = [_message('1')];
        await banc.service.verifier();
        await pumpEventQueue();

        expect(banc.sons, 0);
        expect(banc.service.alerte.value, isNull);
        expect(prevenue, 1);
        await abonnement.cancel();
      },
    );

    test(
      'appli en arrière-plan : notification du téléphone, pas de bandeau',
      () async {
        final banc = _Banc();
        await banc.service.verifier();
        banc.visible = false;

        banc.nonLus = [_message('1')];
        await banc.service.verifier();

        expect(banc.notifications.single.id, '1');
        expect(banc.sons, 0);
        expect(banc.service.alerte.value, isNull);
      },
    );

    test(
      'un compte ne reçoit pas l\'alerte en attente du compte précédent',
      () async {
        final banc = _Banc();
        await banc.service.verifier();
        banc.nonLus = [_message('1')];
        await banc.service.verifier();

        banc.service.arreter();
        expect(banc.service.alerte.value, isNull);

        // Le compte suivant repart de zéro : ses non-lus servent de référence.
        banc.nonLus = [_message('2')];
        await banc.service.verifier();
        expect(banc.sons, 1);
        expect(banc.service.alerte.value, isNull);
      },
    );

    test('une réponse arrivée après la déconnexion est ignorée', () async {
      final banc = _Banc();
      await banc.service.verifier();
      banc.nonLus = [_message('1')];

      final enCours = banc.service.verifier();
      banc.service.arreter();
      await enCours;

      expect(banc.sons, 0);
      expect(banc.service.alerte.value, isNull);
    });

    test('un rôle sans messagerie n\'est pas surveillé', () async {
      var appels = 0;
      final service = AlerteMessageService(
        chargerNonLus: () async {
          appels++;
          return [];
        },
      );

      service.demarrer(RoleUtilisateur.degustateur);
      await pumpEventQueue();

      expect(appels, 0);
      service.arreter();
    });

    test('un message sans texte garde un aperçu lisible', () {
      expect(_message('1', contenu: ' ').apercu, 'Échantillon cité');
      expect(
        Message(
          id: '2',
          expediteur: 'ali',
          destinataire: 'moi',
          expediteurNom: 'Ali',
          destinataireNom: 'Moi',
          contenu: '',
          photoUrl: '/media/photo.jpg',
          dateEnvoi: '2026-11-01T10:00:00Z',
        ).apercu,
        'Photo',
      );
    });
  });

  group('bandeau', () {
    Future<_Banc> afficher(
      WidgetTester tester, {
      ValueChanged<String>? onOuvrir,
    }) async {
      final banc = _Banc();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AlerteMessageHote(
            service: banc.service,
            onOuvrir: onOuvrir ?? (_) {},
            child: child!,
          ),
          home: const Scaffold(body: Text('Page')),
        ),
      );
      return banc;
    }

    testWidgets('montre l\'expéditeur et ouvre sa conversation au toucher', (
      tester,
    ) async {
      final ouverts = <String>[];
      final banc = await afficher(tester, onOuvrir: ouverts.add);

      banc.service.alerte.value = _message('1');
      await tester.pumpAndSettle();
      expect(find.text('Ali Trabelsi'), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);

      await tester.tap(find.text('Bonjour'));
      await tester.pumpAndSettle();

      expect(ouverts, ['ali']);
      expect(find.text('Bonjour'), findsNothing);
    });

    testWidgets('disparaît seul après quelques secondes', (tester) async {
      final banc = await afficher(tester);

      banc.service.alerte.value = _message('1');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      final ignore = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('Bonjour'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignore.ignoring, isTrue);
    });
  });

  testWidgets('la messagerie montre le menu à la place de la flèche', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConversationsPage(
                  menu: Drawer(child: Text('Menu du rôle')),
                ),
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Menu du rôle'), findsOneWidget);
  });
}
