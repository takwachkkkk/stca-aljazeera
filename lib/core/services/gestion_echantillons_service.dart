import 'package:project3/core/api_client.dart';
import 'package:project3/core/models/echantillon.dart';
import 'package:project3/core/models/enums.dart';
import 'package:project3/core/models/mock_echantillons_gestion.dart';
import 'package:project3/core/services/resultat_service.dart';

Map<String, dynamic> echantillonApiToGestionFlutterMap(
  Map<String, dynamic> api,
) {
  return {
    'id': api['id'],
    'numero': api['numero'] ?? '',
    'fournisseur_id': api['fournisseur'] ?? '',
    'collecteur_id': api['collecteur'] ?? '',
    'fournisseur_nom': api['fournisseur_nom'],
    'collecteur_nom': api['collecteur_nom'],
    'gouvernorat': api['gouvernorat'] ?? '',
    'delegation': api['delegation'],
    'cite': api['cite'],
    'reference_bouteille': api['reference_bouteille'] ?? '',
    'num_citerne': api['num_citerne'],
    'variete': api['variete'],
    'quantite_estimee': api['quantite_estimee'],
    'image_url': api['image_url'],
    'statut_collecteur': api['statut_collecteur'] ?? 'receptionne',
    'statut_degustateur': api['statut_degustateur'],
    'statut_labo': api['statut_labo'],
    'statut_ceo': api['statut_ceo'],
    'recu_physiquement': api['recu_physiquement'] ?? false,
    'date_arrivee_echantillon': api['date_arrivee_echantillon'],
    'date_reception_echantillon': api['date_reception_echantillon'],
    'budget_negociation': api['budget_negociation'],
    'quantite_cible_t': api['quantite_cible_t'],
    'camion_reserve': api['camion_reserve'],
    'note_interne': api['note_interne'],
    'raison_refus': api['raison_refus'],
    'stock_arrive': api['stock_arrive'] ?? false,
    'date_livraison_stock': api['date_livraison_stock'],
    'classification': api['classification'],
    'remarques': api['remarques'],
    'remarque_collecteur': api['remarque_collecteur'],
    // Calculé par le serveur pour l'utilisateur connecté (droits de modification).
    'modifiable': api['modifiable'] ?? false,
    'date_ajout': api['date_ajout'] ?? '',
    'updated_at': api['updated_at'],
  };
}

class GestionEchantillonsService {
  final bool uniquementRecusPhysiquement;
  final ApiClient _api;

  GestionEchantillonsService({
    this.uniquementRecusPhysiquement = true,
    ApiClient? api,
  }) : _api = api ?? apiClient;

  // ── Field mapping: Django API → Echantillon.fromJson ─────────────────────
  //
  // Django returns:   numero, fournisseur (UUID), collecteur (UUID), ...
  // fromJson expects: numero, fournisseur_id,      collecteur_id, ...
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _toFlutterMap(Map<String, dynamic> api) {
    return echantillonApiToGestionFlutterMap(api);
  }

  /// Converts the shared Flutter sample model to the Django serializer payload.
  Map<String, dynamic> _toDjangoMap(Echantillon e) {
    final code = e.fournisseurTexte?.trim() ?? '';
    final nom = e.fournisseurNom?.trim() ?? '';
    final collecteurId = e.collecteurId.trim();
    final dateArrivee = e.dateArriveeEchantillon?.trim();
    return {
      'gouvernorat': e.gouvernorat,
      'delegation': e.delegation,
      'cite': e.cite,
      if (nom.isEmpty && code.isNotEmpty) 'fournisseur_nom': code,
      if (nom.isNotEmpty) 'fournisseur_nom': nom,
      if (collecteurId.isNotEmpty && !collecteurId.endsWith('-placeholder'))
        'collecteur': collecteurId,
      'reference_bouteille': e.referenceBouteille,
      'num_citerne': e.numCiterne,
      'quantite_estimee': e.quantiteEstimee,
      'variete': e.variete,
      if (dateArrivee != null && dateArrivee.isNotEmpty)
        'date_arrivee_echantillon': dateArrivee,
      'remarques': e.remarques,
      'image_url': e.imageUrl,
      'statut_collecteur': e.statutCollecteur.toJson,
    };
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches all physically received echantillons visible to the degustateur.
  Future<Resultat<List<Echantillon>>> fetchEchantillons({
    String? recherche,
    int? limite,
  }) => avecSecours(() async {
    final query = <String, String>{
      if (uniquementRecusPhysiquement) 'recu_physiquement': 'true',
      'recherche': ?recherche,
      if (limite != null) 'limite': '$limite',
    };
    final path = query.isEmpty
        ? '/api/echantillons/'
        : Uri(path: '/api/echantillons/', queryParameters: query).toString();
    final items = await _api.getList(path);
    return items
        .map(
          (e) => Echantillon.fromJson(_toFlutterMap(e as Map<String, dynamic>)),
        )
        .toList();
  }, () => List.of(mockEchantillonsGestion));

  /// Updates an existing echantillon via PATCH and returns the updated record.
  Future<Echantillon> updateEchantillon(Echantillon e) async {
    final photo = e.photoAEnvoyer;
    final response = photo == null
        ? await _api.patch('/api/echantillons/${e.id}/', _toDjangoMap(e))
        : await _api.patchMultipart(
            '/api/echantillons/${e.id}/',
            bytes: photo,
            filename: e.photoNomFichier ?? 'bouteille.jpg',
            fields: _champsTexte(e),
          );
    return Echantillon.fromJson(_toFlutterMap(response));
  }

  Future<Echantillon> createEchantillon(Echantillon e) async {
    final photo = e.photoAEnvoyer;
    final response = photo == null
        ? await _api.post('/api/echantillons/', _toDjangoMap(e))
        : await _api.postMultipart(
            '/api/echantillons/',
            bytes: photo,
            filename: e.photoNomFichier ?? 'bouteille.jpg',
            fields: _champsTexte(e),
          );
    return Echantillon.fromJson(_toFlutterMap(response));
  }

  /// Multipart requests carry text only: same fields as the JSON body, as strings.
  Map<String, String> _champsTexte(Echantillon e) => {
    for (final entry in _toDjangoMap(e).entries)
      if (entry.value != null && entry.value.toString().isNotEmpty)
        entry.key: entry.value.toString(),
  };

  Future<void> deleteEchantillon(String id) async {
    await _api.delete('/api/echantillons/$id/');
  }

  /// Toggles physical reception of an echantillon at the company.
  ///
  /// Calls the backend endpoint that matches the requested state.
  Future<void> toggleRecuPhysiquement(String id, bool value) async {
    final action = value ? 'confirmer-reception' : 'annuler-reception';
    await _api.patch('/api/echantillons/$id/$action/', {});
  }
}
