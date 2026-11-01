import '../../../core/api_client.dart';
import '../../../core/fonctionnalites.dart';
import '../../../core/services/resultat_service.dart';
import '../../utilisateurs/models/echantillon_ceo_view.dart';

class EchantillonCeoService {
  /// Ouvre la négociation, ou la rouvre après un achat non conclu. L'achat
  /// lui-même est conclu (ou non) par le collecteur, pas par la direction.
  Future<void> approuver(
    String id, {
    String? budgetNegociation,
    String? quantiteCibleT,
    String? noteInterne,
  }) async {
    final body = <String, dynamic>{};
    if (budgetNegociation != null) {
      body['budget_negociation'] = budgetNegociation;
    }
    if (quantiteCibleT != null) body['quantite_cible_t'] = quantiteCibleT;
    if (noteInterne != null) body['note_interne'] = noteInterne;
    await apiClient.patch('/api/echantillons/$id/approuver/', body);
  }

  Future<void> refuser(String id, String raisonRefus) async {
    await apiClient.patch('/api/echantillons/$id/refuser/', {
      'raison_refus': raisonRefus,
    });
  }

  Future<List<dynamic>> fetchEchantillons() async {
    return await apiClient.getList('/api/echantillons/');
  }

  Future<Resultat<List<EchantillonCeoView>>> fetchCeoViews(
    List<EchantillonCeoView> Function() secours,
  ) => avecSecours(() async {
    final samples = await apiClient.getList('/api/echantillons/');
    final evaluations = await _fetchEvaluationsBySample();
    final analyses = kLaboActif
        ? await _fetchAnalysesBySample()
        : <String, RapportLabo>{};
    final panelCount = await _fetchPanelCount();

    return samples
        .map(
          (sample) => _toCeoView(
            sample as Map<String, dynamic>,
            evaluations,
            analyses,
            panelCount,
          ),
        )
        .toList();
  }, secours);

  Future<Map<String, List<EvaluationOrganoleptique>>>
  _fetchEvaluationsBySample() async {
    final items = await apiClient.getList('/api/evaluations/');
    final grouped = <String, List<EvaluationOrganoleptique>>{};
    for (final item in items) {
      final evaluation = item as Map<String, dynamic>;
      if (evaluation['classification'] == null) continue;
      if (evaluation['statut'] != 'soumis') continue;
      final sampleId = evaluation['echantillon'] as String;
      grouped
          .putIfAbsent(sampleId, () => [])
          .add(_evaluationFromApi(evaluation));
    }
    return grouped;
  }

  Future<Map<String, RapportLabo>> _fetchAnalysesBySample() async {
    final items = await apiClient.getList('/api/analyses/');
    return {
      for (final item in items)
        if ((item as Map<String, dynamic>)['echantillon_id'] != null)
          item['echantillon_id'] as String: _analyseFromApi(item),
    };
  }

  Future<int> _fetchPanelCount() async {
    final panel = await apiClient.getList('/api/users/panel-members/');
    return panel.length;
  }

  EchantillonCeoView _toCeoView(
    Map<String, dynamic> sample,
    Map<String, List<EvaluationOrganoleptique>> evaluations,
    Map<String, RapportLabo> analyses,
    int panelCount,
  ) {
    final id = sample['id'] as String;
    return EchantillonCeoView(
      id: id,
      numero: sample['numero'] as String? ?? id,
      referenceBouteille:
          sample['reference_bouteille'] as String? ??
          sample['numero'] as String? ??
          '',
      gouvernorat: sample['gouvernorat'] as String? ?? '',
      delegation: sample['delegation'] as String?,
      fournisseurTexte: sample['fournisseur_nom'] as String? ?? '',
      fournisseurNom: sample['fournisseur_nom'] as String?,
      numCiterne: sample['num_citerne'] as String?,
      variete: sample['variete'] as String?,
      quantiteEstimee: sample['quantite_estimee']?.toString(),
      dateAjout: sample['date_ajout']?.toString() ?? '',
      dateArriveeEchantillon: _formatDate(sample['date_arrivee_echantillon']),
      dateReceptionEchantillon: _formatDate(
        sample['date_reception_echantillon'],
      ),
      collecteurNom: sample['collecteur_nom'] as String?,
      recuPhysiquement: sample['recu_physiquement'] as bool? ?? false,
      statut: _statutFromApi(sample['statut_ceo'] as String?),
      totalTasteurs: panelCount,
      evaluations: evaluations[id] ?? const [],
      analyse: analyses[id],
      raisonRefus: sample['raison_refus'] as String?,
      budgetNegociation: sample['budget_negociation']?.toString(),
      budgetNegociationMax: sample['budget_negociation_max']?.toString(),
      nbRenegociations: (sample['nb_renegociations'] as num?)?.toInt() ?? 0,
      quantiteCibleT: sample['quantite_cible_t']?.toString(),
      camionReserve: sample['camion_reserve'] as String?,
      noteInterne: sample['note_interne'] as String?,
      prixFinal: sample['prix_final']?.toString(),
      remarqueCollecteur: sample['remarque_collecteur'] as String?,
      raisonNonConclu: sample['raison_non_conclu'] as String?,
      stockArrive: sample['stock_arrive'] as bool? ?? false,
      dateLivraisonStock: _formatDate(sample['date_livraison_stock']),
      dateLivraisonStockFin: _formatDate(sample['date_livraison_stock_fin']),
      remarques: sample['remarques'] as String?,
    );
  }

  EvaluationOrganoleptique _evaluationFromApi(Map<String, dynamic> json) {
    return EvaluationOrganoleptique.fromJson({
      'id': json['id'],
      'echantillon_id': json['echantillon'],
      'tasteur_id': json['degustateur'],
      'session_id': json['session'],
      'tasteur_nom': json['degustateur_nom'],
      'classification': json['classification'],
      'soumis_le': json['soumis_le'] ?? '',
      'fruite': _double(json['fruite']),
      'type_fruite': json['type_fruite'],
      'classe_interne': json['classe_interne'],
      'classe_interne_manuelle': json['classe_interne_manuelle'] ?? false,
      'classe_interne_motif': json['classe_interne_motif'],
      'profil_non_harmonieux': json['profil_non_harmonieux'] ?? false,
      'amertume': _double(json['amertume']),
      'piquant': _double(json['piquant']),
      'chome': _double(json['chome']),
      'moisi': _double(json['moisi']),
      'vinaigre': _double(json['vinaigre']),
      'gele': _double(json['gele']),
      'rance': _double(json['rance']),
      'autres_defaut': _double(json['autres_defaut']),
      'autres_defaut_nom': json['autres_defaut_nom'],
      'commentaire': json['commentaire'],
    });
  }

  RapportLabo _analyseFromApi(Map<String, dynamic> json) =>
      RapportLabo.fromJson(json);

  StatutCeo _statutFromApi(String? value) {
    try {
      return StatutCeoX.fromJson(value ?? 'selectionne');
    } catch (_) {
      return StatutCeo.selectionne;
    }
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }
}
