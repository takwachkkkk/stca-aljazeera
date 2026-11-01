import '../../../core/api_client.dart';
import '../../../core/services/resultat_service.dart';
import '../models/dashboard_chef_degustateur.dart';

typedef PageActiviteChef = ({List<ActiviteItemChef> items, int total});

class DashboardChefDegustateurService {
  final ApiClient _api;

  DashboardChefDegustateurService({ApiClient? api}) : _api = api ?? apiClient;

  Future<Resultat<PipelineChefData>> fetchPipeline() => avecSecours(
    () async => PipelineChefData.fromJson(
      await _api.get('/api/chef/dashboard/pipeline/'),
    ),
    () => const PipelineChefData(
      receptionne: 12,
      enAttenteEval: 5,
      enCours: 3,
      soumis: 4,
    ),
  );

  Future<Resultat<List<EvaluationUrgenteChef>>> fetchUrgentes() => avecSecours(
    () async => (await _api.getList('/api/chef/dashboard/urgentes/'))
        .map((json) => EvaluationUrgenteChef.fromJson(json as Map<String, dynamic>))
        .toList(),
    () => [
      const EvaluationUrgenteChef(
        id: 'aaa00000-0000-0000-0000-000000000001',
        reference: 'Chemlali · 2026/0001',
        collecteurNom: 'Ahmed Dridi',
        fournisseurNom: 'Domaine Bel-Air',
        joursEnAttente: 14,
      ),
      const EvaluationUrgenteChef(
        id: 'aaa00000-0000-0000-0000-000000000004',
        reference: 'Oueslati · 2026/0004',
        collecteurNom: 'Nour Messaoud',
        fournisseurNom: 'Green Valley',
        joursEnAttente: 8,
      ),
      const EvaluationUrgenteChef(
        id: 'aaa00000-0000-0000-0000-000000000005',
        reference: 'Chemlali · 2026/0005',
        collecteurNom: 'Ahmed Dridi',
        fournisseurNom: 'Domaine Bel-Air',
        joursEnAttente: 6,
      ),
    ],
  );

  Future<Resultat<List<SessionEnAttente>>> fetchSessionsEnAttente() => avecSecours(
    () async => (await _api.getList('/api/chef/dashboard/sessions-en-attente/'))
        .map((json) => SessionEnAttente.fromJson(json as Map<String, dynamic>))
        .toList(),
    () => const [
      SessionEnAttente(
        id: 'SES-005',
        titre: 'Session Oueslati - Lot C',
        date: '28/04/2026',
        heure: '09:00',
        lieu: 'Salle de dégustation A',
        proposePar: 'Lobna E.',
      ),
      SessionEnAttente(
        id: 'SES-006',
        titre: 'Session Rkhami - Sfax',
        date: '02/05/2026',
        heure: '11:00',
        lieu: 'Salle de dégustation B',
        proposePar: 'Ichrak C.',
      ),
    ],
  );

  Future<Resultat<DelaiPanelData>> fetchDelai({DateTime? dateDebut, DateTime? dateFin}) => avecSecours(
    () async => DelaiPanelData.fromJson(
      await _api.get(_cheminAvecDates(
        '/api/chef/dashboard/delai/',
        dateDebut: dateDebut,
        dateFin: dateFin,
      )),
    ),
    () => const DelaiPanelData(
      panelMoyen: 3.1,
      membres: [
        DelaiMembre(nom: 'Ichrak C.',  delaiMoyen: 2.1, panelMoyen: 3.1),
        DelaiMembre(nom: 'Lobna E.',   delaiMoyen: 3.5, panelMoyen: 3.1),
        DelaiMembre(nom: 'Maha O.',    delaiMoyen: 2.8, panelMoyen: 3.1),
        DelaiMembre(nom: 'Nayrouz F.', delaiMoyen: 3.9, panelMoyen: 3.1),
        DelaiMembre(nom: 'Yosra S.',   delaiMoyen: 2.5, panelMoyen: 3.1),
      ],
    ),
  );

  Future<Resultat<AlignementPanelData>> fetchAlignement({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) => avecSecours(
    () async => AlignementPanelData.fromJson(
      await _api.get(_cheminAvecDates(
        '/api/chef/dashboard/alignement/',
        dateDebut: dateDebut,
        dateFin: dateFin,
      )),
    ),
    () => const AlignementPanelData(
      membres: [
        AlignementMembre(nom: 'Ichrak C.',  divergencePct: 5.2),
        AlignementMembre(nom: 'Lobna E.',   divergencePct: 12.8),
        AlignementMembre(nom: 'Maha O.',    divergencePct: 8.1),
        AlignementMembre(nom: 'Nayrouz F.', divergencePct: 18.4),
        AlignementMembre(nom: 'Yosra S.',   divergencePct: 6.7),
      ],
    ),
  );

  Future<Resultat<List<ClassificationPoint>>> fetchClassifications({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) => avecSecours(
    () async => (await _api.getList(_cheminAvecDates(
      '/api/chef/dashboard/classifications/',
      dateDebut: dateDebut,
      dateFin: dateFin,
    )))
        .map((json) => ClassificationPoint.fromJson(json as Map<String, dynamic>))
        .toList(),
    () => const [
      ClassificationPoint(label: 'Jan', extraVierge: 5, vierge: 3, lampante: 2),
      ClassificationPoint(label: 'Fév', extraVierge: 4, vierge: 4, lampante: 2),
      ClassificationPoint(label: 'Mar', extraVierge: 7, vierge: 2, lampante: 1),
      ClassificationPoint(label: 'Avr', extraVierge: 6, vierge: 3, lampante: 1),
    ],
  );

  Future<Resultat<List<EvaluationUrgenteCeoChef>>> fetchUrgentesCeo() => avecSecours(
    () async => (await _api.getList('/api/chef/dashboard/urgentes-ceo/'))
        .map((json) => EvaluationUrgenteCeoChef.fromJson(json as Map<String, dynamic>))
        .toList(),
    () => const [
      EvaluationUrgenteCeoChef(
        id: 'aaa00000-0000-0000-0000-000000000002',
        reference: 'Chemlali · 2026/0002',
        collecteurNom: 'Ahmed Dridi',
        fournisseurNom: 'SF-17',
      ),
    ],
  );

  Future<Resultat<PresenceChefData>> fetchPresence({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) => avecSecours(
    () async => PresenceChefData.fromJson(
      await _api.get(_cheminAvecDates(
        '/api/chef/dashboard/presence/',
        dateDebut: dateDebut,
        dateFin: dateFin,
      )),
    ),
    () => const PresenceChefData(
      present: 9,
      manquee: 1,
      prochaineTitre: 'Session Oueslati - Lot C',
      prochaineDate: '18/05/2026',
      prochaineLieu: 'Salle de dégustation B',
      prochaineCountdown: 'Dans 11 jours',
    ),
  );

  Future<Resultat<PageActiviteChef>> fetchActivite({
    DateTime? dateDebut,
    DateTime? dateFin,
    int offset = 0,
    int pageSize = 5,
  }) => avecSecours(
    () async {
      final json = await _api.get(_cheminAvecDates(
        '/api/chef/dashboard/activite/',
        dateDebut: dateDebut,
        dateFin: dateFin,
        autresParametres: {'offset': '$offset', 'limit': '$pageSize'},
      ));
      return (
        items: (json['results'] as List<dynamic>)
            .map((item) => ActiviteItemChef.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: json['count'] as int,
      );
    },
    () {
      const all = [
        ActiviteItemChef(id: '0', action: 'Session approuvée — Session Chemlali Lot A',   horodatage: '05 Mai · 10h00', type: 'session_approuvee'),
        ActiviteItemChef(id: '1', action: 'Divergence détectée — OUESLATI-C2 (Nayrouz)', horodatage: '04 Mai · 15h30', type: 'divergence'),
        ActiviteItemChef(id: '2', action: 'Session refusée — Session Rkhami (modifiée)',   horodatage: '03 Mai · 09h10', type: 'session_refusee'),
        ActiviteItemChef(id: '3', action: 'Classification validée — CHETOUI-C3',          horodatage: '01 Mai · 11h45', type: 'evaluation'),
        ActiviteItemChef(id: '4', action: 'Session approuvée — Session Zalmati',          horodatage: '28 Avr · 08h30', type: 'session_approuvee'),
        ActiviteItemChef(id: '5', action: 'Divergence signalée — ZARAZI-C1 (Lobna)',      horodatage: '25 Avr · 14h00', type: 'divergence'),
        ActiviteItemChef(id: '6', action: 'Classification validée — CHEMLALI-C1',         horodatage: '22 Avr · 10h20', type: 'evaluation'),
      ];
      return (items: all.skip(offset).take(pageSize).toList(), total: all.length);
    },
  );

  String _cheminAvecDates(
    String chemin, {
    DateTime? dateDebut,
    DateTime? dateFin,
    Map<String, String> autresParametres = const {},
  }) {
    final parametres = <String, String>{
      ...autresParametres,
      if (dateDebut != null) 'date_debut': _dateApi(dateDebut),
      if (dateFin != null) 'date_fin': _dateApi(dateFin),
    };
    if (parametres.isEmpty) return chemin;
    return Uri(path: chemin, queryParameters: parametres).toString();
  }

  String _dateApi(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
