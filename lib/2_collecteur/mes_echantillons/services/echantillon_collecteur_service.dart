// ═════════════════════════════════════════════════════════════════════════════
// FILE : collecteur/mes_echantillons/services/echantillon_collecteur_service.dart
// ═════════════════════════════════════════════════════════════════════════════

import '../models/echantillon_collecteur.dart';
import '../../../../core/api_client.dart';
import '../../../../core/models/enums.dart' show StatutCollecteurX;
import '../../../../core/services/resultat_service.dart';
import 'echantillon_mock_data.dart';

class EchantillonCollecteurService {
  final ApiClient _api;
  bool _usingMockData = false;

  EchantillonCollecteurService({ApiClient? api}) : _api = api ?? apiClient;
  // ── Field mapping: Django API → Flutter fromJson ───────────────────────────
  //
  // The Django API returns field names that differ from what fromJson() expects.
  // We build an intermediate map that satisfies the model's fromJson contract.
  //
  // Key renames:
  //   numero                   -> numero
  //   statut_collecteur        → statut  (+ value conversion to Dart enum name)
  //   collecteur               → collecteur_id
  //   camion_reserve           → camion_livraison
  //   budget_negociation       → budget_negociation  (Decimal/null → String?/null)
  //   prix_final               → prix_final          (Decimal/null → String?/null)
  //
  //   date_livraison_stock(_fin) → livraison (date de livraison du stock)
  // ──────────────────────────────────────────────────────────────────────────

  /// Converts a Django `statut_collecteur` snake_case value to the Dart enum
  /// identifier name used by `StatutCollecteur.values.byName()`.
  ///
  /// Django   → Dart enum name
  /// receptionne    → receptionne
  /// en_negociation → enNegociation
  /// achat_confirme → achatConfirme
  /// achat_non_conclu → achatNonConclu
  String _mapStatut(String djangoStatut) {
    switch (djangoStatut) {
      case 'receptionne':
        return 'receptionne';
      case 'en_negociation':
        return 'enNegociation';
      case 'achat_confirme':
        return 'achatConfirme';
      case 'achat_non_conclu':
        return 'achatNonConclu';
      default:
        return djangoStatut;
    }
  }

  /// Converts the Django API response map to the intermediate map that
  /// `EchantillonCollecteur.fromJson()` expects.
  Map<String, dynamic> _toFlutterMap(Map<String, dynamic> api) {
    final statutCollecteur =
        api['statut_collecteur'] as String? ?? 'receptionne';
    return {
      'id': api['id'],
      'numero': api['numero'],
      'gouvernorat': api['gouvernorat'] ?? '',
      'delegation': api['delegation'],
      'cite': api['cite'],
      'fournisseur': api['fournisseur'],
      'fournisseur_nom': api['fournisseur_nom'],
      'reference_bouteille': api['reference_bouteille'] ?? '',
      'num_citerne': api['num_citerne'],
      'quantite_estimee': api['quantite_estimee'],
      'variete': api['variete'],
      'achat_confirme': statutCollecteur == 'achat_confirme',
      'livraison': _livraisonFromApi(api['date_livraison_stock']),
      'date_arrivee_echantillon': api['date_arrivee_echantillon'],
      'recu_physiquement': api['recu_physiquement'] ?? false,
      'date_reception_echantillon': api['date_reception_echantillon'],
      'budget_negociation': api['budget_negociation']?.toString(),
      'quantite_cible_t': api['quantite_cible_t']?.toString(),
      'date_stock_souhaitee_debut': null,
      'date_stock_souhaitee_fin': null,
      'prix_final': api['prix_final']?.toString(),
      'camion_livraison': api['camion_reserve'],
      'remarque_collecteur': api['remarque_collecteur'],
      'remarques': api['remarques'],
      'date_ajout': api['date_ajout'],
      'image_url': api['image_url'],
      'collecteur_id': api['collecteur'] ?? '',
      'collecteur_nom': api['collecteur_nom'] ?? '',
      'statut_collecteur': _mapStatut(statutCollecteur),
      'statut': _mapStatut(statutCollecteur),
    };
  }

  /// Converts `EchantillonCollecteur.toJson()` back to Django field names for
  /// POST/PATCH requests.
  Map<String, dynamic> _toDjangoMap(EchantillonCollecteur e) {
    final json = e.toJson();
    final nom = e.fournisseurNom?.trim() ?? '';
    return {
      'gouvernorat': json['gouvernorat'],
      'delegation': json['delegation'],
      'cite': json['cite'],
      if (nom.isEmpty) 'fournisseur_nom': e.fournisseurTexte,
      // Only sent when present so legacy edits don't accidentally override
      // the supplier match with an empty string.
      if (nom.isNotEmpty) 'fournisseur_nom': nom,
      'reference_bouteille': json['reference_bouteille'],
      'num_citerne': json['num_citerne'],
      'quantite_estimee': json['quantite_estimee'],
      'variete': json['variete'],
      'date_arrivee_echantillon': json['date_arrivee_echantillon'],
      'budget_negociation': json['budget_negociation'],
      'quantite_cible_t': json['quantite_cible_t'],
      'prix_final': json['prix_final'],
      'camion_reserve': json['camion_reserve'],
      'remarque_collecteur': json['remarque_collecteur'],
      'remarques': json['remarques'],
      'image_url': json['image_url'],
      'statut_collecteur': e.statut.toJson,
    };
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches all echantillons for the current collector.
  ///
  /// Optional filters:
  ///   [statut] — Django snake_case value ('receptionne', 'en_negociation', 'achat_confirme')
  ///   [search] — free-text search string
  Future<Resultat<List<EchantillonCollecteur>>> fetchEchantillons({
    String? statut,
    String? search,
  }) => avecSecours(
    () async {
      final params = <String, String>{};
      if (statut != null && statut.isNotEmpty) params['statut'] = statut;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri(
        path: '/api/echantillons/',
        queryParameters: params.isEmpty ? null : params,
      );
      final items = await _api.getList(uri.toString());
      _usingMockData = false;
      return items
          .map(
            (e) => EchantillonCollecteur.fromJson(
              _toFlutterMap(e as Map<String, dynamic>),
            ),
          )
          .toList();
    },
    () {
      _usingMockData = true;
      final all = mockEchantillons();
      return all.where((e) {
        if (statut != null && statut.isNotEmpty && e.statut.toJson != statut) {
          return false;
        }
        if (search != null && search.isNotEmpty) {
          final q = search.toLowerCase();
          if (!e.numero.toLowerCase().contains(q) &&
              !e.referenceBouteille.toLowerCase().contains(q) &&
              !e.fournisseurTexte.toLowerCase().contains(q) &&
              !(e.fournisseurNom?.toLowerCase().contains(q) ?? false) &&
              !(e.variete?.toLowerCase().contains(q) ?? false)) {
            return false;
          }
        }
        return true;
      }).toList();
    },
  );

  /// Creates a new echantillon and returns the saved record from the server.
  Future<EchantillonCollecteur> createEchantillon(
    EchantillonCollecteur e,
  ) async {
    if (_usingMockData) {
      return e;
    }
    final response = await _api.post('/api/echantillons/', _toDjangoMap(e));
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  /// Creates a new echantillon AND uploads its bottle photo in one request.
  /// The photo is stored on the on-premise server and shown to tasters later.
  Future<EchantillonCollecteur> createEchantillonWithImage(
    EchantillonCollecteur e, {
    required List<int> imageBytes,
    required String filename,
  }) async {
    if (_usingMockData) {
      return e;
    }
    final dj = _toDjangoMap(e);
    final fields = <String, String>{};
    dj.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) fields[k] = v.toString();
    });
    final response = await _api.postMultipart(
      '/api/echantillons/',
      bytes: imageBytes,
      filename: filename,
      fields: fields,
    );
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  /// Edits an echantillon AND replaces its bottle photo in one request.
  Future<EchantillonCollecteur> updateEchantillonWithImage(
    EchantillonCollecteur e, {
    required List<int> imageBytes,
    required String filename,
  }) async {
    if (_usingMockData) {
      return e;
    }
    final fields = <String, String>{};
    _toDjangoMap(e).forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) fields[k] = v.toString();
    });
    final response = await _api.patchMultipart(
      '/api/echantillons/${e.id}/',
      bytes: imageBytes,
      filename: filename,
      fields: fields,
    );
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  /// Updates an existing echantillon via PATCH and returns the updated record.
  Future<EchantillonCollecteur> updateEchantillon(
    EchantillonCollecteur e,
  ) async {
    if (_usingMockData) {
      return e;
    }
    final response = await _api.patch(
      '/api/echantillons/${e.id}/',
      _toDjangoMap(e),
    );
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  /// Deletes an echantillon by ID.
  Future<void> deleteEchantillon(String id) async {
    if (_usingMockData) {
      return;
    }
    await _api.delete('/api/echantillons/$id/');
  }

  /// La date de livraison du stock revient du serveur : sans elle, la date
  /// saisie par le collecteur disparaissait au rechargement.
  Map<String, dynamic>? _livraisonFromApi(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return null;
    return PlanificationLivraison.exact(
      date: date,
      heure: '',
      lieu: '',
    ).toJson();
  }

  Map<String, dynamic> _corpsAchat(AchatSaisi achat) => {
    'prix_final': achat.prixFinal,
    'remarque_collecteur': achat.remarqueCollecteur,
    if (achat.numCiterne != null) 'num_citerne': achat.numCiterne,
    if (achat.livraisonDebut != null)
      'date_livraison_stock': achat.livraisonDebut!.toUtc().toIso8601String(),
    if (achat.livraisonFin != null)
      'date_livraison_stock_fin': achat.livraisonFin!.toUtc().toIso8601String(),
  };

  /// Le collecteur conclut la négociation : l'achat est confirmé tout de
  /// suite, sans validation de la direction (qui est notifiée).
  ///
  /// Calls `PATCH /api/echantillons/<id>/confirmer-achat/`.
  Future<EchantillonCollecteur> confirmerAchat(
    String id,
    AchatSaisi achat,
  ) async {
    if (_usingMockData) {
      throw StateError(
        'Confirmation indisponible avec les données de démonstration.',
      );
    }
    final response = await _api.patch(
      '/api/echantillons/$id/confirmer-achat/',
      _corpsAchat(achat),
    );
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  /// La négociation n'a pas abouti. La raison est facultative ; la direction
  /// est notifiée et peut rouvrir la négociation.
  ///
  /// Calls `POST /api/echantillons/<id>/non-conclu/`.
  Future<EchantillonCollecteur> declarerNonConclu(
    String id, {
    String? raison,
  }) async {
    if (_usingMockData) {
      throw StateError(
        'Action indisponible avec les données de démonstration.',
      );
    }
    final response = await _api.post('/api/echantillons/$id/non-conclu/', {
      'raison_non_conclu': raison ?? '',
    });
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  /// Après confirmation, le collecteur peut encore corriger le prix, la
  /// citerne, la date de livraison ou sa remarque.
  Future<EchantillonCollecteur> modifierAchat(
    String id,
    AchatSaisi achat,
  ) async {
    if (_usingMockData) {
      throw StateError(
        'Action indisponible avec les données de démonstration.',
      );
    }
    final response = await _api.patch(
      '/api/echantillons/$id/',
      _corpsAchat(achat),
    );
    return EchantillonCollecteur.fromJson(_toFlutterMap(response));
  }

  String messageFor(Object error) {
    if (error is ApiException) return error.message;
    return 'Impossible de joindre le serveur. Les donnees de demonstration restent affichees.';
  }
}
