import 'package:project3/core/utils/date_utils.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project3/1_ceo/notifications/models/notification_ceo.dart';
import 'package:project3/1_ceo/tableau_de_bord/models/dashboard_models.dart';
import 'package:project3/2_collecteur/mes_echantillons/models/echantillon_collecteur.dart';
import 'package:project3/2_collecteur/notifications/models/notification_collecteur.dart';
import 'package:project3/4_laboratoire/echantillons_labo/models/echantillon_labo.dart';
import 'package:project3/4_laboratoire/notifications/models/notification_labo.dart';
import 'package:project3/core/analyses/ligne_analyse_labo.dart';
import 'package:project3/core/analyses/ligne_analyse_labo_service.dart';
import 'package:project3/core/analyses/rapport_labo.dart';
import 'package:project3/core/models/contact_messagerie.dart';
import 'package:project3/core/models/echantillon.dart' as gestion;
import 'package:project3/core/models/fournisseur.dart';
import 'package:project3/core/models/membre_panel.dart';
import 'package:project3/core/models/message.dart';
import 'package:project3/core/models/notification_degustateur.dart';
import 'package:project3/core/models/session_degustation.dart';
import 'package:project3/core/models/user_profile.dart';
import 'package:project3/core/services/gestion_echantillons_service.dart';

final _uuid = RegExp(
  r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
);
final _isoDate = RegExp(r'\b20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}');

final List<String> _defauts = [];

void main() {
  test(
    'les fixtures API du parcours se lisent sans UUID ni date ISO affiches',
    () {
      // CABLAGE_FIXTURES lets Claude replay real-database answers too.
      final root = Directory(
        Platform.environment['CABLAGE_FIXTURES'] ?? 'test/fixtures/api',
      );
      expect(
        root.existsSync(),
        isTrue,
        reason:
            'Lancer le test Django core.tests_parcours pour generer les fixtures.',
      );

      final files = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      expect(files, isNotEmpty);

      for (final file in files) {
        final payload =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final statusCode = payload['status_code'] as int;
        final route = payload['route'] as String;
        final data = payload['data'];
        if (statusCode == 403) continue;
        expect(statusCode, 200, reason: file.path);

        final List<Object> parsedObjects;
        try {
          parsedObjects = _parseRoute(route, data, file.path);
        } catch (erreur) {
          // A reading crash empties the whole screen: record it and keep going.
          _defauts.add(
            'CRASH | ${file.path} | ${erreur.toString().split('\n').first}',
          );
          continue;
        }
        for (final parsed in parsedObjects) {
          _assertNoRawDisplayIds(parsed, file.path);
        }
      }

      // Every defect at once, not only the first one.
      final uniques = _defauts.toSet().toList()..sort();
      expect(
        uniques,
        isEmpty,
        reason: '${uniques.length} défaut(s) :\n${uniques.join('\n')}',
      );
    },
  );
}

List<Object> _parseRoute(String route, dynamic data, String source) {
  if (route == '/api/users/me/') return [UserProfile.fromJson(_map(data))];
  if (route == '/api/users/') {
    return _items(data).map((e) => UserProfile.fromJson(_map(e))).toList();
  }
  if (route == '/api/users/panel-members/') {
    return _items(data).map((e) => MembrePanel.fromJson(_map(e))).toList();
  }
  if (route == '/api/fournisseurs/') {
    return _items(data).map((e) => Fournisseur.fromJson(_map(e))).toList();
  }
  if (route == '/api/echantillons/' ||
      route == '/api/echantillons/?recu_physiquement=true') {
    return _items(data)
        .map((e) => _map(e))
        .expand<Object>(
          (json) => [
            EchantillonCollecteur.fromJson(json),
            gestion.Echantillon.fromJson(
              echantillonApiToGestionFlutterMap(json),
            ),
          ],
        )
        .toList();
  }
  if (route == '/api/analyses/') {
    return _items(data).map((e) => RapportLabo.fromJson(_map(e))).toList();
  }
  if (route == '/api/analyses/echantillons/') {
    final service = LigneAnalyseLaboService();
    return _items(data)
        .map((e) => _map(e))
        .expand<Object>(
          (json) => [
            EchantillonLabo.fromJson(json),
            service.ligneFromApi(json),
          ],
        )
        .toList();
  }
  if (route == '/api/sessions/') {
    return _items(
      data,
    ).map((e) => SessionDegustation.fromJson(_map(e))).toList();
  }
  if (route == '/api/messages/') {
    return _items(data).map((e) => Message.fromJson(_map(e))).toList();
  }
  if (route == '/api/messages/contacts/') {
    return _items(
      data,
    ).map((e) => ContactMessagerie.fromJson(_map(e))).toList();
  }
  if (route == '/api/notifications/') {
    final role = source
        .split(RegExp(r'[\\/]api[\\/]'))
        .last
        .split(RegExp(r'[\\/]'))
        .first;
    return _items(
      data,
    ).map((e) => _notificationForRole(role, _map(e))).toList();
  }
  if (route == '/api/ceo/dashboard/') {
    return [DashboardCeoSnapshot.fromJson(_map(data))];
  }

  return [_SerializableFixture(route, data)];
}

Object _notificationForRole(String role, Map<String, dynamic> json) {
  if (role == 'direction') return NotificationCeo.fromJson(json);
  if (role == 'collecteur') return NotificationCollecteur.fromJson(json);
  if (role == 'laboratoire') return NotificationLabo.fromJson(json);
  return NotificationDegustateur.fromJson(json);
}

List<dynamic> _items(dynamic data) {
  if (data is Map && data['results'] is List) return data['results'] as List;
  if (data is List) return data;
  return const [];
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return {};
}

void _assertNoRawDisplayIds(Object parsed, String source) {
  final displayValues = <String>[
    if (parsed is EchantillonCollecteur) ...[
      parsed.numero,
      parsed.referenceBouteille,
      parsed.fournisseurAffichage,
      parsed.collecteurNom,
    ],
    if (parsed is gestion.Echantillon) ...[
      parsed.referenceBouteille,
      parsed.referenceBouteille,
      parsed.fournisseurAffichage,
      parsed.collecteurNom ?? '',
    ],
    if (parsed is EchantillonLabo) ...[
      parsed.referenceBouteille,
      parsed.referenceBouteille,
      parsed.fournisseurTexte,
      parsed.collecteurNom,
      parsed.dateArrivee,
    ],
    if (parsed is SessionDegustation) ...[
      parsed.titre,
      parsed.createdByNom ?? '',
      parsed.date,
      parsed.heure,
    ],
    if (parsed is Message) ...[
      parsed.expediteurNom,
      parsed.destinataireNom,
      parsed.echantillonNumero ?? '',
      parsed.echantillonReferenceBouteille ?? '',
    ],
    if (parsed is ContactMessagerie) '${parsed.prenom} ${parsed.nom}',
    if (parsed is MembrePanel) '${parsed.prenom} ${parsed.nom}',
    if (parsed is NotificationCeo) ...[
      parsed.titre,
      parsed.message,
      parsed.echantillonReference ?? '',
    ],
    if (parsed is NotificationCollecteur) ...[
      parsed.titre,
      parsed.message,
      parsed.echantillonReference ?? '',
    ],
    if (parsed is NotificationDegustateur) ...[
      parsed.titre,
      parsed.message,
      parsed.echantillonReference ?? '',
    ],
    if (parsed is NotificationLabo) ...[
      parsed.titre,
      parsed.message,
      parsed.echantillonReference ?? '',
    ],
    if (parsed is LigneAnalyseLabo) ...[
      parsed.numero,
      parsed.referenceBouteille,
      parsed.echantillonNom,
      parsed.technicienNom,
      parsed.fournisseurNom ?? '',
      parsed.collecteurNom ?? '',
      // Dates are kept whole (with the time) and formatted on display.
      DegDateUtils.formaterDateHeure(parsed.dateAjout),
      parsed.dateArriveeEchantillon ?? '',
      DegDateUtils.formaterDateHeure(parsed.dateReceptionEchantillon),
    ],
  ];

  for (final value in displayValues.where((value) => value.trim().isNotEmpty)) {
    if (_uuid.hasMatch(value)) _defauts.add('UUID  | $source | $value');
    if (_isoDate.hasMatch(value)) _defauts.add('DATE  | $source | $value');
  }
}

class _SerializableFixture {
  final String route;
  final dynamic data;
  const _SerializableFixture(this.route, this.data);
}
