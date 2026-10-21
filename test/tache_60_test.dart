// Tâche 60 : filtres des statuts, mois en français, résultat du panel (COI).

import 'package:flutter_test/flutter_test.dart';
import 'package:project3/5_chef_degustateur/panel_coi/resultat_panel.dart';
import 'package:project3/5_chef_degustateur/tableau_de_bord/models/dashboard_chef_degustateur.dart';
import 'package:project3/core/models/enums.dart';

void main() {
  test('les boutons de filtre correspondent aux statuts', () {
    // Les boutons affichent ces textes : avant, « En cours » ≠ « Évaluation en
    // cours » et le filtre ne trouvait jamais rien.
    expect(StatutDegustateur.nonEvaluee.libelleFiltre, 'Non évaluée');
    expect(StatutDegustateur.enCours.libelleFiltre, 'Évaluation en cours');
    expect(StatutDegustateur.soumis.libelleFiltre, 'Évaluation soumise');
  });

  test('le mois des classifications est en français', () {
    final point = ClassificationPoint.fromJson({
      'label': 'Oct 2026',
      'annee': 2026,
      'mois': 10,
      'extra_vierge': 3,
      'vierge': 2,
      'lampante': 1,
    });
    expect(point.libelleMois, 'Oct 2026');
    expect(point.total, 6);
    final juillet = ClassificationPoint.fromJson({
      'label': 'Jul 2026',
      'annee': 2026,
      'mois': 7,
      'extra_vierge': 0,
      'vierge': 0,
      'lampante': 0,
    });
    expect(juillet.libelleMois, 'Juil 2026');
  });

  test('résultat du panel lu depuis le serveur', () {
    final r = ResultatPanel.fromJson({
      'echantillon_id': 'e1',
      'numero': '2026/0012',
      'reference_bouteille': 'REF',
      'derniere_soumission': '2026-10-20T10:00:00Z',
      'nombre_degustateurs': 8,
      'attributs': [
        {
          'champ': 'rance',
          'libelle': 'Rance',
          'positif': false,
          'mediane': 5.0,
          'moyenne': 5.63,
          'ecart_type': 0.92,
          'iqr': 1.25,
          'cvr': 8.2,
          'ic_bas': 4.2,
          'ic_haut': 5.8,
        },
      ],
      'defaut_principal': 'Rance',
      'mediane_defaut_principal': 5.0,
      'mediane_fruite': 2.85,
      'classification': 'vierge_ordinaire',
      'fiable': true,
      'cvr_max': 20.0,
      'type_fruite_majoritaire': 'vert',
    });
    expect(r.classification, ClassificationHuile.viergeOrdinaire);
    expect(r.fiable, isTrue);
    expect(r.attributs.single.cvr, 8.2);
    expect(r.typeFruiteMajoritaire, TypeFruite.vert);
  });
}
