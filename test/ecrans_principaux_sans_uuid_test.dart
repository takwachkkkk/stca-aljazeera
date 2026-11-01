import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project3/1_ceo/echantillons/echantillons_ceo_page.dart'
    as ceo_page;
import 'package:project3/1_ceo/echantillons/services/echantillon_ceo_service.dart';
import 'package:project3/1_ceo/utilisateurs/models/echantillon_ceo_view.dart';
import 'package:project3/2_collecteur/mes_echantillons/mes_echantillons_page.dart'
    as collecteur_page;
import 'package:project3/2_collecteur/mes_echantillons/models/echantillon_collecteur.dart'
    as collecteur_model;
import 'package:project3/2_collecteur/mes_echantillons/services/echantillon_collecteur_service.dart';
import 'package:project3/2_collecteur/notifications/services/notification_collecteur_service.dart';
import 'package:project3/3_degustateur/evaluation_echantillons/evaluation_echantillons_page.dart'
    as degustateur_eval_page;
import 'package:project3/3_degustateur/gestion_echantillons/gestion_echantillons_page.dart'
    as degustateur_gestion_page;
import 'package:project3/3_degustateur/sessions_degustation/sessions_degustation_page.dart'
    as degustateur_sessions_page;
import 'package:project3/4_laboratoire/echantillons_labo/echantillons_labo_page.dart'
    as labo_page;
import 'package:project3/4_laboratoire/echantillons_labo/models/echantillon_labo.dart'
    as labo_model;
import 'package:project3/4_laboratoire/echantillons_labo/services/labo_service.dart';
import 'package:project3/4_laboratoire/notifications/services/notification_labo_service.dart';
import 'package:project3/5_chef_degustateur/evaluation_echantillons/evaluation_echantillons_page.dart'
    as chef_eval_page;
import 'package:project3/5_chef_degustateur/gestion_echantillons/gestion_echantillons_page.dart'
    as chef_gestion_page;
import 'package:project3/5_chef_degustateur/sessions_degustation/sessions_degustation_page.dart'
    as chef_sessions_page;
import 'package:project3/core/models/echantillon.dart' as gestion_model;
import 'package:project3/core/models/echantillon_evaluation.dart'
    as evaluation_model;
import 'package:project3/core/models/session_degustation.dart';
import 'package:project3/core/services/evaluation_service.dart';
import 'package:project3/core/services/gestion_echantillons_service.dart';
import 'package:project3/core/services/resultat_service.dart';
import 'package:project3/core/services/sessions_service.dart';

final _uuidPattern = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);
final _isoDatePattern = RegExp(r'\d{4}-\d{2}-\d{2}T');

// Synchronous on purpose: real async file I/O never completes inside the
// fake clock of testWidgets, and the test would hang forever.
Future<List<Map<String, dynamic>>> _results(String path) async {
  final json = jsonDecode(File(path).readAsStringSync());
  final data = json['data'] as Map<String, dynamic>;
  return (data['results'] as List).cast<Map<String, dynamic>>();
}

String _dateAffichage(dynamic value) {
  if (value == null) return '';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}

evaluation_model.Echantillon _evaluationDepuisFixture(
  Map<String, dynamic> json,
) {
  return evaluation_model.Echantillon.fromJson({
    'id': json['id'],
    'reference_bouteille': json['reference_bouteille'] ?? '',
    'numero': json['numero'],
    'fournisseur': json['fournisseur_nom'] ?? 'Non specifie',
    'date_arrivee_echantillon':
        json['date_arrivee_echantillon'] ?? json['date_ajout'],
    'date_ajout': json['date_ajout'],
    'date_reception_echantillon': json['date_reception_echantillon'],
    'variete': json['variete'] ?? '',
    'gouvernorat': json['gouvernorat'],
    'delegation': json['delegation'],
    'photo_url': json['image_url'],
    'quantite': json['quantite_estimee'],
    'collecteur': json['collecteur_nom'],
    'statut': 'en_attente',
    'classification': null,
  });
}

EchantillonCeoView _ceoDepuisFixture(Map<String, dynamic> json) {
  return EchantillonCeoView(
    id: json['id'] as String,
    numero: json['numero'] as String,
    referenceBouteille: json['reference_bouteille'] as String,
    gouvernorat: json['gouvernorat'] as String? ?? '',
    delegation: json['delegation'] as String?,
    fournisseurTexte: json['fournisseur_nom'] as String? ?? '',
    fournisseurNom: json['fournisseur_nom'] as String?,
    numCiterne: json['num_citerne'] as String?,
    variete: json['variete'] as String?,
    quantiteEstimee: json['quantite_estimee']?.toString(),
    dateAjout: _dateAffichage(json['date_ajout']),
    dateArriveeEchantillon: _dateAffichage(json['date_arrivee_echantillon']),
    dateReceptionEchantillon: _dateAffichage(
      json['date_reception_echantillon'],
    ),
    collecteurNom: json['collecteur_nom'] as String?,
    recuPhysiquement: json['recu_physiquement'] as bool? ?? false,
    statut: StatutCeoX.fromJson(json['statut_ceo'] as String? ?? 'selectionne'),
    totalTasteurs: 0,
    stockArrive: json['stock_arrive'] as bool? ?? false,
    dateLivraisonStock: _dateAffichage(json['date_livraison_stock']),
    remarques: json['remarques'] as String?,
  );
}

Future<void> _pomper360(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(360, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: page));
  // A fixed amount of time, not pumpAndSettle: spinners and the 30 s
  // auto-refresh never let the screen become fully idle.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  final exception = tester.takeException();
  expect(exception, isNull);

  final textes = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .toList();
  expect(textes.where(_uuidPattern.hasMatch), isEmpty);
  expect(textes.where(_isoDatePattern.hasMatch), isEmpty);

  // Unmount so the page's periodic timers are cancelled before the test ends.
  await tester.pumpWidget(const SizedBox());
}

class _CollecteurService extends EchantillonCollecteurService {
  final List<collecteur_model.EchantillonCollecteur> data;

  _CollecteurService(this.data);

  @override
  Future<Resultat<List<collecteur_model.EchantillonCollecteur>>>
  fetchEchantillons({String? statut, String? search}) async => Resultat(data);
}

class _CollecteurNotifications extends NotificationCollecteurService {
  @override
  Future<Resultat<int>> fetchUnreadCount() async => const Resultat(0);
}

class _GestionService extends GestionEchantillonsService {
  final List<gestion_model.Echantillon> data;

  _GestionService(this.data) : super(uniquementRecusPhysiquement: false);

  @override
  Future<Resultat<List<gestion_model.Echantillon>>> fetchEchantillons({
    String? recherche,
    int? limite,
  }) async => Resultat(data);
}

class _EvaluationService extends EvaluationService {
  final List<evaluation_model.Echantillon> data;

  _EvaluationService(this.data);

  @override
  Future<Resultat<List<evaluation_model.Echantillon>>>
  fetchEchantillons() async => Resultat(data);
}

class _SessionsService extends SessionsService {
  final List<SessionDegustation> data;

  const _SessionsService(this.data, {super.peutValider});

  @override
  Future<Resultat<List<SessionDegustation>>> fetchSessions() async =>
      Resultat(data);
}

class _LaboService extends LaboService {
  final List<labo_model.EchantillonLabo> data;

  _LaboService(this.data);

  @override
  Future<Resultat<List<labo_model.EchantillonLabo>>>
  fetchEchantillons() async => Resultat(data);
}

class _LaboNotifications extends NotificationLaboService {
  @override
  Future<Resultat<int>> fetchUnreadCount() async => const Resultat(0);
}

class _CeoService extends EchantillonCeoService {
  final List<EchantillonCeoView> data;

  _CeoService(this.data);

  @override
  Future<Resultat<List<EchantillonCeoView>>> fetchCeoViews(
    List<EchantillonCeoView> Function() secours,
  ) async => Resultat(data);
}

void main() {
  testWidgets('collecteur - Mes echantillons sans UUID ni date ISO', (
    tester,
  ) async {
    final data = (await _results(
      'test/fixtures/api/collecteur/06_achat_confirme/api__echantillons.json',
    )).map(collecteur_model.EchantillonCollecteur.fromJson).toList();

    await _pomper360(
      tester,
      collecteur_page.MesEchantillonsPage(
        service: _CollecteurService(data),
        notificationService: _CollecteurNotifications(),
      ),
    );
  });

  testWidgets('degustateur - Gestion des echantillons sans UUID ni date ISO', (
    tester,
  ) async {
    final data =
        (await _results(
              'test/fixtures/api/degustateur/02_reception_degustateur/api__echantillons.json',
            ))
            .map(echantillonApiToGestionFlutterMap)
            .map(gestion_model.Echantillon.fromJson)
            .toList();

    await _pomper360(
      tester,
      degustateur_gestion_page.GestionEchantillonsPage(
        service: _GestionService(data),
      ),
    );
  });

  testWidgets('degustateur - Evaluation des echantillons sans UUID ni date ISO', (
    tester,
  ) async {
    final data = (await _results(
      'test/fixtures/api/degustateur/02_reception_degustateur/api__echantillons.json',
    )).map(_evaluationDepuisFixture).toList();

    await _pomper360(
      tester,
      degustateur_eval_page.EvaluationEchantillonsPage(
        service: _EvaluationService(data),
      ),
    );
  });

  testWidgets('degustateur - Sessions sans UUID ni date ISO', (tester) async {
    final data = (await _results(
      'test/fixtures/api/degustateur/03_session_approuvee_presence/api__sessions.json',
    )).map(SessionDegustation.fromJson).toList();

    await _pomper360(
      tester,
      degustateur_sessions_page.SessionsDegustationPage(
        service: _SessionsService(data),
      ),
    );
  });

  testWidgets('chef - Gestion des echantillons sans UUID ni date ISO', (
    tester,
  ) async {
    final data =
        (await _results(
              'test/fixtures/api/chef_degustation/02_reception_degustateur/api__echantillons.json',
            ))
            .map(echantillonApiToGestionFlutterMap)
            .map(gestion_model.Echantillon.fromJson)
            .toList();

    await _pomper360(
      tester,
      chef_gestion_page.GestionEchantillonsPage(service: _GestionService(data)),
    );
  });

  testWidgets('chef - Evaluation des echantillons sans UUID ni date ISO', (
    tester,
  ) async {
    final data = (await _results(
      'test/fixtures/api/chef_degustation/02_reception_degustateur/api__echantillons.json',
    )).map(_evaluationDepuisFixture).toList();

    await _pomper360(
      tester,
      chef_eval_page.EvaluationEchantillonsPage(
        service: _EvaluationService(data),
      ),
    );
  });

  testWidgets('chef - Sessions sans UUID ni date ISO', (tester) async {
    final data = (await _results(
      'test/fixtures/api/chef_degustation/03_session_approuvee_presence/api__sessions.json',
    )).map(SessionDegustation.fromJson).toList();

    await _pomper360(
      tester,
      chef_sessions_page.SessionsDegustationPage(
        service: _SessionsService(data, peutValider: true),
      ),
    );
  });

  testWidgets('laboratoire - Echantillons sans UUID ni date ISO', (
    tester,
  ) async {
    final data = (await _results(
      'test/fixtures/api/laboratoire/02_reception_degustateur/api__analyses__echantillons.json',
    )).map(labo_model.EchantillonLabo.fromJson).toList();

    await _pomper360(
      tester,
      labo_page.EchantillonsLaboPage(
        service: _LaboService(data),
        notificationService: _LaboNotifications(),
      ),
    );
  });

  testWidgets('direction - Echantillons sans UUID ni date ISO', (tester) async {
    final data = (await _results(
      'test/fixtures/api/direction/02_reception_degustateur/api__echantillons.json',
    )).map(_ceoDepuisFixture).toList();

    await _pomper360(
      tester,
      ceo_page.EchantillonsCeoPage(service: _CeoService(data)),
    );
  });
}
