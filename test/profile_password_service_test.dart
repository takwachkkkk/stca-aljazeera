import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/core/api_client.dart';
import 'package:project3/core/password_validation.dart';
import 'package:project3/core/services/profile_service.dart';
import 'package:project3/core/widgets/change_password_dialog.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://test.invalid');

  String? path;
  Map<String, dynamic>? body;
  final completer = Completer<void>();

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    this.path = path;
    this.body = Map<String, dynamic>.from(body);
    await completer.future;
    return {'detail': 'Mot de passe changé avec succès.'};
  }
}

class _FailingProfileService extends ProfileService {
  _FailingProfileService(this.error)
    : super(api: ApiClient(baseUrl: 'http://test.invalid'));

  final Object error;

  @override
  Future<void> changerMotDePasse({
    required String ancien,
    required String nouveau,
  }) async {
    throw error;
  }
}

void main() {
  test(
    'le service attend la réponse et envoie les deux mots de passe',
    () async {
      final api = _RecordingApiClient();
      final service = ProfileService(api: api);
      var completed = false;

      final request = service
          .changerMotDePasse(ancien: 'Ancien@123', nouveau: 'Nouveau@456')
          .then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(api.path, '/api/users/me/changer-mot-de-passe/');
      expect(api.body, {
        'ancien_mot_de_passe': 'Ancien@123',
        'nouveau_mot_de_passe': 'Nouveau@456',
      });
      expect(completed, isFalse);

      api.completer.complete();
      await request;
      expect(completed, isTrue);
    },
  );

  test('le mauvais ancien mot de passe reçoit un message clair', () {
    final service = ProfileService(api: _RecordingApiClient());

    expect(
      service.messageFor(
        ApiException(
          400,
          'Mot de passe actuel incorrect.',
          code: 'password_incorrect',
        ),
      ),
      'Mot de passe actuel incorrect.',
    );
  });

  test('le validateur exige 6 caractères, des lettres et des chiffres', () {
    expect(validatePassword('Ab@1'), isNotNull);
    expect(validatePassword('Nouveau@'), isNotNull);
    // Lettres + chiffres suffisent : le caractère spécial est facultatif.
    expect(validatePassword('Nouveau1'), isNull);
    expect(validatePassword('Nouveau@1'), isNull);
  });

  testWidgets(
    "l'ancien mot de passe incorrect ouvre une fenêtre dédiée",
    (tester) async {
      await _openDialog(
        tester,
        service: _FailingProfileService(
          ApiException(
            400,
            'Mot de passe actuel incorrect.',
            code: 'password_incorrect',
          ),
        ),
      );
      await _fillPasswords(tester);

      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Ancien mot de passe incorrect'), findsOneWidget);
      expect(
        find.text('Le mot de passe actuel saisi est incorrect.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('change-password-error')), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'le nouveau mot de passe trop faible ouvre une fenêtre avec les règles',
    (tester) async {
      await _openDialog(tester);
      await _fillPasswords(tester, nouveau: '123', confirmation: '123');

      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe trop faible'), findsOneWidget);
      expect(find.textContaining('Au moins 6 caractères.'), findsOneWidget);
      expect(find.textContaining('Au moins une lettre.'), findsOneWidget);
      // Les caractères spéciaux ne sont plus obligatoires.
      expect(find.textContaining('caractère spécial'), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'la confirmation différente ouvre une fenêtre dédiée',
    (tester) async {
      await _openDialog(tester);
      await _fillPasswords(tester, confirmation: 'Autre@456');

      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
      expect(
        find.text('La confirmation doit être identique au nouveau mot de passe.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un autre refus serveur ouvre une fenêtre avec son message',
    (tester) async {
      await _openDialog(
        tester,
        service: _FailingProfileService(
          ApiException(400, 'Le serveur refuse ce changement.'),
        ),
      );
      await _fillPasswords(tester);

      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Changement refusé'), findsOneWidget);
      expect(find.text('Le serveur refuse ce changement.'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Mot de passe actuel'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _openDialog(
  WidgetTester tester, {
  ProfileService? service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => ChangePasswordDialog(
                accentColor: Colors.green,
                labelColor: Colors.green,
                titleColor: Colors.black,
                service: service,
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> _fillPasswords(
  WidgetTester tester, {
  String ancien = 'Ancien@123',
  String nouveau = 'Nouveau@456',
  String confirmation = 'Nouveau@456',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Mot de passe actuel'),
    ancien,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
    nouveau,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
    confirmation,
  );
}
