class EvaluationUrgenteCeoChef {
  final String id;
  final String reference;
  final String collecteurNom;
  final String fournisseurNom;

  const EvaluationUrgenteCeoChef({
    required this.id,
    required this.reference,
    required this.collecteurNom,
    required this.fournisseurNom,
  });

  factory EvaluationUrgenteCeoChef.fromJson(Map<String, dynamic> json) =>
      EvaluationUrgenteCeoChef(
        id: json['id'] as String,
        reference: json['reference'] as String,
        collecteurNom: json['collecteur_nom'] as String,
        fournisseurNom: json['fournisseur_nom'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'collecteur_nom': collecteurNom,
    'fournisseur_nom': fournisseurNom,
  };
}

class PresenceChefData {
  final int present;
  final int manquee;
  final String? prochaineTitre;
  final String? prochaineDate;
  final String? prochaineLieu;
  final String? prochaineCountdown;

  const PresenceChefData({
    required this.present,
    required this.manquee,
    this.prochaineTitre,
    this.prochaineDate,
    this.prochaineLieu,
    this.prochaineCountdown,
  });

  int get total => present + manquee;
  double get taux => total == 0 ? 0 : present / total;

  factory PresenceChefData.fromJson(Map<String, dynamic> json) =>
      PresenceChefData(
        present: json['present'] as int,
        manquee: json['manquee'] as int,
        prochaineTitre: json['prochaine_titre'] as String?,
        prochaineDate: json['prochaine_date'] as String?,
        prochaineLieu: json['prochaine_lieu'] as String?,
        prochaineCountdown: json['prochaine_countdown'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'present': present,
    'manquee': manquee,
    'prochaine_titre': prochaineTitre,
    'prochaine_date': prochaineDate,
    'prochaine_lieu': prochaineLieu,
    'prochaine_countdown': prochaineCountdown,
  };
}

class ActiviteItemChef {
  final String id;
  final String action;
  final String horodatage;
  final String type;

  const ActiviteItemChef({
    required this.id,
    required this.action,
    required this.horodatage,
    required this.type,
  });

  factory ActiviteItemChef.fromJson(Map<String, dynamic> json) =>
      ActiviteItemChef(
        id: json['id'] as String,
        action: json['action'] as String,
        horodatage: json['horodatage'] as String,
        type: json['type'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'horodatage': horodatage,
    'type': type,
  };
}

class PipelineChefData {
  final int receptionne;
  final int enAttenteEval;
  final int enCours;
  final int soumis;

  const PipelineChefData({
    required this.receptionne,
    required this.enAttenteEval,
    required this.enCours,
    required this.soumis,
  });

  factory PipelineChefData.fromJson(Map<String, dynamic> json) =>
      PipelineChefData(
        receptionne: json['receptionne'] as int,
        enAttenteEval: json['en_attente_eval'] as int,
        enCours: json['en_cours'] as int,
        soumis: json['soumis'] as int,
      );

  Map<String, dynamic> toJson() => {
    'receptionne': receptionne,
    'en_attente_eval': enAttenteEval,
    'en_cours': enCours,
    'soumis': soumis,
  };
}

class EvaluationUrgenteChef {
  final String id;
  final String reference;
  final String collecteurNom;
  final String fournisseurNom;
  final int joursEnAttente;

  const EvaluationUrgenteChef({
    required this.id,
    required this.reference,
    required this.collecteurNom,
    required this.fournisseurNom,
    required this.joursEnAttente,
  });

  factory EvaluationUrgenteChef.fromJson(Map<String, dynamic> json) =>
      EvaluationUrgenteChef(
        id: json['id'] as String,
        reference: json['reference'] as String,
        collecteurNom: json['collecteur_nom'] as String,
        fournisseurNom: json['fournisseur_nom'] as String,
        joursEnAttente: json['jours_en_attente'] as int,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'collecteur_nom': collecteurNom,
    'fournisseur_nom': fournisseurNom,
    'jours_en_attente': joursEnAttente,
  };
}

class SessionEnAttente {
  final String id;
  final String titre;
  final String date;
  final String heure;
  final String lieu;
  final String proposePar;

  const SessionEnAttente({
    required this.id,
    required this.titre,
    required this.date,
    required this.heure,
    required this.lieu,
    required this.proposePar,
  });

  bool get estPassee {
    final heureValide = heure.isEmpty ? '23:59' : heure;
    final dateHeure = DateTime.tryParse('${date}T$heureValide');
    return dateHeure != null && dateHeure.isBefore(DateTime.now());
  }

  factory SessionEnAttente.fromJson(Map<String, dynamic> json) =>
      SessionEnAttente(
        id: json['id'] as String,
        titre: json['titre'] as String,
        date: json['date'] as String,
        heure: json['heure'] as String? ?? '',
        lieu: json['lieu'] as String? ?? '',
        proposePar: json['propose_par'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titre': titre,
    'date': date,
    'heure': heure,
    'lieu': lieu,
    'propose_par': proposePar,
  };
}

class DelaiMembre {
  final String nom;
  final double delaiMoyen;
  final double panelMoyen;

  const DelaiMembre({
    required this.nom,
    required this.delaiMoyen,
    required this.panelMoyen,
  });

  factory DelaiMembre.fromJson(Map<String, dynamic> json) => DelaiMembre(
    nom: json['nom'] as String,
    delaiMoyen: (json['delai_moyen'] as num).toDouble(),
    panelMoyen: (json['panel_moyen'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'delai_moyen': delaiMoyen,
    'panel_moyen': panelMoyen,
  };
}

class DelaiPanelData {
  final List<DelaiMembre> membres;
  final double panelMoyen;

  const DelaiPanelData({required this.membres, required this.panelMoyen});

  factory DelaiPanelData.fromJson(Map<String, dynamic> json) => DelaiPanelData(
    membres: (json['membres'] as List)
        .map((e) => DelaiMembre.fromJson(e))
        .toList(),
    panelMoyen: (json['panel_moyen'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'membres': membres.map((m) => m.toJson()).toList(),
    'panel_moyen': panelMoyen,
  };
}

class AlignementMembre {
  final String nom;
  final double divergencePct;

  const AlignementMembre({required this.nom, required this.divergencePct});

  factory AlignementMembre.fromJson(Map<String, dynamic> json) =>
      AlignementMembre(
        nom: json['nom'] as String,
        divergencePct: (json['divergence_pct'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'divergence_pct': divergencePct,
  };
}

class AlignementPanelData {
  final List<AlignementMembre> membres;

  const AlignementPanelData({required this.membres});

  factory AlignementPanelData.fromJson(Map<String, dynamic> json) =>
      AlignementPanelData(
        membres: (json['membres'] as List)
            .map((e) => AlignementMembre.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'membres': membres.map((m) => m.toJson()).toList(),
  };
}

class ClassificationPoint {
  final String label;
  final int extraVierge;
  final int vierge;
  final int lampante;

  /// Année et mois (1–12) du groupe, quand le serveur les envoie.
  final int? annee;
  final int? mois;

  const ClassificationPoint({
    required this.label,
    required this.extraVierge,
    required this.vierge,
    required this.lampante,
    this.annee,
    this.mois,
  });

  int get total => extraVierge + vierge + lampante;

  static const _moisCourts = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  /// « Oct 2026 » en français ; le libellé serveur est en anglais.
  String get libelleMois {
    final a = annee;
    final m = mois;
    if (a == null || m == null || m < 1 || m > 12) return label;
    return '${_moisCourts[m - 1]} $a';
  }

  factory ClassificationPoint.fromJson(Map<String, dynamic> json) =>
      ClassificationPoint(
        label: json['label'] as String,
        extraVierge: json['extra_vierge'] as int,
        vierge: json['vierge'] as int,
        lampante: json['lampante'] as int,
        annee: json['annee'] as int?,
        mois: json['mois'] as int?,
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'extra_vierge': extraVierge,
    'vierge': vierge,
    'lampante': lampante,
  };
}
