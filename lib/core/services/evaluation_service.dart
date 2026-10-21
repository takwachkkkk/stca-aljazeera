import 'package:project3/core/api_client.dart';
import 'package:project3/core/models/echantillon_evaluation.dart';
import 'package:project3/core/models/mock_echantillons_evaluation.dart';
import 'package:project3/core/services/resultat_service.dart';

class EvaluationService {
  bool _usingMockData = false;
  final Map<String, Map<String, dynamic>> _cachedEvaluationsBySample = {};

  Future<Resultat<List<Echantillon>>> fetchEchantillons() => avecSecours(
    () async {
      // Seuls les échantillons dont la réception est confirmée peuvent être
      // évalués : les autres ne sont pas encore dans la société.
      final sampleItems = await apiClient.getList(
        '/api/echantillons/?recu_physiquement=true',
      );
      final evaluationItems = await apiClient.getList('/api/evaluations/');
      _usingMockData = false;
      _cachedEvaluationsBySample
        ..clear()
        ..addEntries(
          evaluationItems.map((item) {
            final evaluation = item as Map<String, dynamic>;
            return MapEntry(evaluation['echantillon'] as String, evaluation);
          }),
        );
      return sampleItems
          .map(
            (item) => Echantillon.fromJson(
              _toFlutterSampleMap(item as Map<String, dynamic>),
            ),
          )
          .toList();
    },
    () {
      _usingMockData = true;
      _cachedEvaluationsBySample.clear();
      return List.of(mockEchantillonsEvaluation);
    },
  );

  Future<Resultat<Map<String, dynamic>?>> fetchEvaluation(
    String echantillonId,
  ) async {
    if (_usingMockData) {
      return Resultat(
        _cachedEvaluationsBySample[echantillonId],
        estDemonstration: true,
        messageErreur: 'Le chargement des échantillons a utilisé le secours.',
      );
    }
    final cached = _cachedEvaluationsBySample[echantillonId];
    if (cached != null) return Resultat(cached);
    return avecSecours(
      () async {
        final items = await apiClient.getList(
          '/api/evaluations/?echantillon=$echantillonId',
        );
        if (items.isEmpty) return null;
        final evaluation = items.first as Map<String, dynamic>;
        _cachedEvaluationsBySample[echantillonId] = evaluation;
        return evaluation;
      },
      () {
        _usingMockData = true;
        return null;
      },
    );
  }

  Future<Map<String, dynamic>> createEvaluation(
    Map<String, dynamic> data,
  ) async {
    if (_usingMockData) {
      throw StateError(
        'Enregistrement indisponible avec les données de démonstration.',
      );
    }
    final saved = await apiClient.post('/api/evaluations/', data);
    _cachedEvaluationsBySample[saved['echantillon'] as String] = saved;
    return saved;
  }

  Future<Map<String, dynamic>> updateEvaluation(
    String id,
    Map<String, dynamic> data,
  ) async {
    if (_usingMockData) {
      throw StateError(
        'Modification indisponible avec les données de démonstration.',
      );
    }
    final saved = await apiClient.patch('/api/evaluations/$id/', data);
    _cachedEvaluationsBySample[saved['echantillon'] as String] = saved;
    return saved;
  }

  Future<Map<String, dynamic>> soumettre(String evaluationId) async {
    if (_usingMockData) {
      throw StateError(
        'Soumission indisponible avec les données de démonstration.',
      );
    }
    final saved = await apiClient.post(
      '/api/evaluations/$evaluationId/soumettre/',
      {},
    );
    _cachedEvaluationsBySample[saved['echantillon'] as String] = saved;
    return saved;
  }

  String messageFor(Object error) {
    if (error is ApiException) {
      final erreurEchantillon = error.champs?['echantillon'];
      if (erreurEchantillon is List && erreurEchantillon.isNotEmpty) {
        return erreurEchantillon.first.toString();
      }
      return error.message;
    }
    return 'Impossible de joindre le serveur. Les donnees de demonstration restent affichees.';
  }

  Map<String, dynamic> _toFlutterSampleMap(Map<String, dynamic> api) {
    final id = api['id'] as String;
    final evaluation = _cachedEvaluationsBySample[id];
    final status = evaluation?['statut'] as String?;
    final classification = evaluation?['classification'] as String?;
    return {
      'id': id,
      'reference_bouteille': api['reference_bouteille'] ?? api['numero'] ?? '',
      'numero': api['numero'],
      'fournisseur': api['fournisseur_nom'] ?? 'Non specifie',
      'date_ajout': api['date_ajout'],
      'date_arrivee_echantillon': api['date_arrivee_echantillon'] ?? '',
      'date_reception_echantillon': api['date_reception_echantillon'],
      'variete': api['variete'] ?? '',
      'gouvernorat': api['gouvernorat'],
      'delegation': api['delegation'],
      'photo_url': api['image_url'],
      'quantite': api['quantite_estimee'],
      'collecteur': api['collecteur_nom'],
      'recu_physiquement': api['recu_physiquement'] == true,
      'num_citerne': api['num_citerne'],
      'date_livraison_stock': api['date_livraison_stock'],
      'statut': status ?? 'en_attente',
      'classification': _classificationLabel(classification),
    };
  }

  String? _classificationLabel(String? value) {
    switch (value) {
      case 'extra_vierge':
        return 'Extra Vierge';
      case 'vierge':
        return 'Vierge';
      case 'vierge_ordinaire':
        return 'Vierge Ordinaire';
      case 'lampante':
        return 'Lampante';
      default:
        return value;
    }
  }
}
