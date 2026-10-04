import '../api_client.dart';
import '../services/resultat_service.dart';
import 'ligne_analyse_labo.dart';
import 'rapport_labo.dart';

class LigneAnalyseLaboService {
  Future<Resultat<List<LigneAnalyseLabo>>> fetchAnalyses() => avecSecours(
    () async {
      final data = await apiClient.getList('/api/analyses/echantillons/');
      return data.map((e) => ligneFromApi(e as Map<String, dynamic>)).toList();
    },
    () => List.of(_analysesDemonstration),
  );

  Future<void> sendUrgentAnalyseLabo(
    String echantillonId,
    String echantillonNom,
  ) async {
    await apiClient.post('/api/notifications/analyse-urgente/', {
      'echantillon': echantillonId,
    });
  }

  /// Transforme l'échantillon imbriqué renvoyé par
  /// `GET /api/analyses/echantillons/` en ligne de consultation.
  LigneAnalyseLabo ligneFromApi(Map<String, dynamic> json) {
    final analyse = json['analyse'] as Map<String, dynamic>?;
    final sampleId = json['id'] as String;
    final numero = (json['numero'] ?? '').toString();
    final reference =
        (analyse?['echantillon_ref'] ?? json['reference_bouteille'] ?? '')
            .toString();
    final variete = (json['variete'] ?? '').toString();
    final gouvernorat = (json['gouvernorat'] ?? '').toString();
    final displayParts = [
      if (variete.isNotEmpty) variete,
      if (reference.isNotEmpty) reference,
      if (gouvernorat.isNotEmpty) gouvernorat,
    ];
    final statutAnalyse = switch (analyse?['statut']) {
      'soumis' => StatutAnalyse.soumise,
      'en_cours' => StatutAnalyse.enCours,
      _ =>
        json['statut_labo'] == 'soumis'
            ? StatutAnalyse.soumise
            : StatutAnalyse.enAttente,
    };
    final estSoumise = statutAnalyse == StatutAnalyse.soumise;
    final rapport = analyse == null ? null : RapportLabo.fromJson(analyse);

    return LigneAnalyseLabo(
      id: (analyse?['id'] ?? sampleId).toString(),
      echantillonId: sampleId,
      numero: numero,
      referenceBouteille: reference,
      echantillonNom: displayParts.isEmpty ? numero : displayParts.join(' - '),
      technicienNom:
          (analyse?['technicien_nom'] as String?) ?? 'En attente laboratoire',
      statut: statutAnalyse,
      fournisseurNom:
          json['fournisseur_nom'] as String? ??
          json['fournisseur_nom'] as String?,
      gouvernorat: json['gouvernorat'] as String?,
      delegation: json['delegation'] as String?,
      collecteurNom: json['collecteur_nom'] as String?,
      variete: json['variete'] as String?,
      quantiteEstimee: json['quantite_estimee']?.toString(),
      dateAjout: json['date_ajout']?.toString(),
      dateArriveeEchantillon: _formaterDate(json['date_arrivee_echantillon']),
      dateReceptionEchantillon: json['date_reception_echantillon']?.toString(),
      recuPhysiquement: json['recu_physiquement'] as bool? ?? false,
      numCiterne: json['num_citerne'] as String?,
      dateLivraisonStock: json['date_livraison_stock']?.toString(),
      rapport: estSoumise ? rapport : null,
    );
  }

  static String? _formaterDate(dynamic valeur) {
    if (valeur == null) return null;
    final texte = valeur.toString();
    final date = DateTime.tryParse(texte);
    if (date == null) return texte;
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }
}

const Map<String, double?> _valeursCertificat188 = {
  'acidite': 0.30,
  'indice_peroxyde': 9.71,
  'k232': 2.02,
  'k270': 0.12,
  'delta_k': 0.003,
  'humidite': 0.06,
  'impuretes': 0.03,
  'ecn42': 0.052,
  'cholesterol': 0.09,
  'brassicasterol': 0.00,
  'campesterol': 3.30,
  'stigmasterol': 0.64,
  'beta_sitosterol_apparent': 95.00,
  'delta_7_stigmastenol': 0.36,
  'delta_7_avenasterol': 0.61,
  'erythrodiol_uvaol': 2.00,
  'acide_palmitique': 14.65,
  'acide_palmitoleique': 1.61,
  'acide_heptadecanoique': 0.05,
  'acide_heptadecenoique': 0.09,
  'acide_stearique': 2.56,
  'acide_oleique': 64.06,
  'acide_linoleique': 15.68,
  'acide_linolenique': 0.66,
  'acide_arachidique': 0.39,
  'acide_gadoleique': 0.21,
  'trans_c18_1': 0.02,
  'trans_c18_2_c18_3': 0.02,
};

const List<LigneAnalyseLabo> _analysesDemonstration = [
  LigneAnalyseLabo(
    id: 'ANL-188-2026',
    echantillonId: '2026/0001',
    numero: '2026/0001',
    referenceBouteille: 'S.T_C3_30T',
    echantillonNom: 'Chemlali - Lot A - Sfax',
    technicienNom: 'Karim B.',
    statut: StatutAnalyse.soumise,
    fournisseurNom: 'Domaine Bel-Air',
    gouvernorat: 'Sfax',
    delegation: 'Sfax Sud',
    collecteurNom: 'Ahmed Dridi',
    variete: 'Chemlali',
    quantiteEstimee: '25',
    dateAjout: '01/03/2026',
    dateArriveeEchantillon: '10/03/2026',
    dateReceptionEchantillon: '15/03/2026',
    rapport: RapportLabo(
      valeurs: _valeursCertificat188,
      numeroCertificat: '188-2026',
      numeroLot: 'COM142-0426',
      dateAnalyse: '18/03/2026',
      notes: 'Analyse conforme aux normes COI',
    ),
  ),
  LigneAnalyseLabo(
    id: 'ECH-EN-ATTENTE',
    echantillonId: '2026/0004',
    numero: '2026/0004',
    referenceBouteille: 'K.N_C1_18T',
    echantillonNom: 'Zalmati - Gafsa',
    technicienNom: 'En attente laboratoire',
    statut: StatutAnalyse.enAttente,
    fournisseurNom: 'Green Valley',
    gouvernorat: 'Kairouan',
    delegation: 'Kairouan Nord',
    collecteurNom: 'Rania Hammami',
    variete: 'Oueslati',
    quantiteEstimee: '18',
    dateAjout: '23/02/2026',
    dateArriveeEchantillon: '01/03/2026',
    dateReceptionEchantillon: '05/03/2026',
  ),
];
