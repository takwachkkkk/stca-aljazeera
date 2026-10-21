// ═════════════════════════════════════════════════════════════════════════════
// FILE    : core/models/enums.dart
// PURPOSE : All shared enums used across roles.
//           JSON string values match the Django backend conventions (snake_case).
// ═════════════════════════════════════════════════════════════════════════════

// ── User roles ────────────────────────────────────────────────────────────────
enum RoleUtilisateur {
  direction,
  collecteur,
  degustateur,
  laboratoire,
  chefDegustation,
}

extension RoleUtilisateurX on RoleUtilisateur {
  String get toJson {
    switch (this) {
      case RoleUtilisateur.direction:
        return 'direction';
      case RoleUtilisateur.collecteur:
        return 'collecteur';
      case RoleUtilisateur.degustateur:
        return 'degustateur';
      case RoleUtilisateur.laboratoire:
        return 'laboratoire';
      case RoleUtilisateur.chefDegustation:
        return 'chef_degustation';
    }
  }

  String get label {
    switch (this) {
      case RoleUtilisateur.direction:
        return 'Direction';
      case RoleUtilisateur.collecteur:
        return 'Collecteur';
      case RoleUtilisateur.degustateur:
        return 'Dégustateur';
      case RoleUtilisateur.laboratoire:
        return 'Technicien Labo';
      case RoleUtilisateur.chefDegustation:
        return 'Chef de Dégustation';
    }
  }

  static RoleUtilisateur fromJson(String s) {
    switch (s) {
      case 'direction':
        return RoleUtilisateur.direction;
      case 'collecteur':
        return RoleUtilisateur.collecteur;
      case 'degustateur':
        return RoleUtilisateur.degustateur;
      case 'laboratoire':
        return RoleUtilisateur.laboratoire;
      case 'chef_degustation':
        return RoleUtilisateur.chefDegustation;
      default:
        return RoleUtilisateur.degustateur;
    }
  }
}

// ── Sample statuses — one per actor view ─────────────────────────────────────

/// Collector-facing sample status (statut_collecteur on echantillons table).
enum StatutCollecteur { receptionne, enNegociation, achatConfirme }

extension StatutCollecteurX on StatutCollecteur {
  String get toJson {
    switch (this) {
      case StatutCollecteur.receptionne:
        return 'receptionne';
      case StatutCollecteur.enNegociation:
        return 'en_negociation';
      case StatutCollecteur.achatConfirme:
        return 'achat_confirme';
    }
  }

  String get label {
    switch (this) {
      case StatutCollecteur.receptionne:
        return 'Échantillon enregistré';
      case StatutCollecteur.enNegociation:
        return 'Prix en négociation';
      case StatutCollecteur.achatConfirme:
        return 'Achat conclu';
    }
  }

  static StatutCollecteur fromJson(String s) {
    switch (s) {
      case 'receptionne':
        return StatutCollecteur.receptionne;
      case 'en_negociation':
        return StatutCollecteur.enNegociation;
      case 'achat_confirme':
        return StatutCollecteur.achatConfirme;
      default:
        return StatutCollecteur.receptionne;
    }
  }
}

/// Taster-facing sample status (statut_degustateur on echantillons table).
enum StatutDegustateur { nonEvaluee, enCours, soumis }

extension StatutDegustateurX on StatutDegustateur {
  String get toJson {
    switch (this) {
      case StatutDegustateur.nonEvaluee:
        return 'non_evaluee';
      case StatutDegustateur.enCours:
        return 'en_cours';
      case StatutDegustateur.soumis:
        return 'soumis';
    }
  }

  String get label {
    switch (this) {
      case StatutDegustateur.nonEvaluee:
        return 'Non évaluée';
      case StatutDegustateur.enCours:
        return 'En cours';
      case StatutDegustateur.soumis:
        return 'Soumis';
    }
  }

  /// Texte des boutons de filtre « Gestion des échantillons ». Les filtres
  /// comparaient ces textes à [label] (« En cours », « Soumis ») : les boutons
  /// « Évaluation en cours » et « Évaluation soumise » ne trouvaient jamais rien.
  String get libelleFiltre {
    switch (this) {
      case StatutDegustateur.nonEvaluee:
        return 'Non évaluée';
      case StatutDegustateur.enCours:
        return 'Évaluation en cours';
      case StatutDegustateur.soumis:
        return 'Évaluation soumise';
    }
  }

  static StatutDegustateur fromJson(String s) {
    switch (s) {
      case 'non_evaluee':
        return StatutDegustateur.nonEvaluee;
      case 'en_cours':
        return StatutDegustateur.enCours;
      case 'soumis':
        return StatutDegustateur.soumis;
      default:
        return StatutDegustateur.nonEvaluee;
    }
  }
}

/// Lab-facing sample status (statut_labo on echantillons table AND statut on
/// analyses_labo table — same values, same enum).
enum StatutLabo { enAttente, enCours, soumis }

extension StatutLaboX on StatutLabo {
  String get toJson {
    switch (this) {
      case StatutLabo.enAttente:
        return 'en_attente';
      case StatutLabo.enCours:
        return 'en_cours';
      case StatutLabo.soumis:
        return 'soumis';
    }
  }

  String get label {
    switch (this) {
      case StatutLabo.enAttente:
        return 'En attente';
      case StatutLabo.enCours:
        return 'En cours';
      case StatutLabo.soumis:
        return 'Soumis';
    }
  }

  static StatutLabo fromJson(String s) {
    switch (s) {
      case 'en_attente':
        return StatutLabo.enAttente;
      case 'en_cours':
        return StatutLabo.enCours;
      case 'soumis':
        return StatutLabo.soumis;
      default:
        return StatutLabo.enAttente;
    }
  }
}

/// CEO-facing sample status (statut_ceo on echantillons table).
enum StatutCeo { selectionne, enNegociation, achatConfirme, refuse }

extension StatutCeoX on StatutCeo {
  String get toJson {
    switch (this) {
      case StatutCeo.selectionne:
        return 'selectionne';
      case StatutCeo.enNegociation:
        return 'en_negociation';
      case StatutCeo.achatConfirme:
        return 'achat_confirme';
      case StatutCeo.refuse:
        return 'refuse';
    }
  }

  String get label {
    switch (this) {
      case StatutCeo.selectionne:
        return 'Enregistré';
      case StatutCeo.enNegociation:
        return 'En négociation';
      case StatutCeo.achatConfirme:
        return 'Achat confirmé';
      case StatutCeo.refuse:
        return 'Refusé';
    }
  }

  static StatutCeo fromJson(String s) {
    switch (s) {
      case 'selectionne':
        return StatutCeo.selectionne;
      case 'en_negociation':
        return StatutCeo.enNegociation;
      case 'achat_confirme':
        return StatutCeo.achatConfirme;
      case 'refuse':
        return StatutCeo.refuse;
      default:
        return StatutCeo.selectionne;
    }
  }
}

// ── Oil classification (COI standard) ─────────────────────────────────────────
enum ClassificationHuile { extraVierge, vierge, viergeOrdinaire, lampante }

extension ClassificationHuileX on ClassificationHuile {
  String get toJson {
    switch (this) {
      case ClassificationHuile.extraVierge:
        return 'extra_vierge';
      case ClassificationHuile.vierge:
        return 'vierge';
      case ClassificationHuile.viergeOrdinaire:
        return 'vierge_ordinaire';
      case ClassificationHuile.lampante:
        return 'lampante';
    }
  }

  String get label {
    switch (this) {
      case ClassificationHuile.extraVierge:
        return 'Extra Vierge';
      case ClassificationHuile.vierge:
        return 'Vierge';
      case ClassificationHuile.viergeOrdinaire:
        return 'Vierge Ordinaire';
      case ClassificationHuile.lampante:
        return 'Lampante';
    }
  }

  /// Brand color for this classification tier.
  int get colorValue {
    switch (this) {
      case ClassificationHuile.extraVierge:
        return 0xFF38835A;
      case ClassificationHuile.vierge:
        return 0xFFF57C00;
      case ClassificationHuile.viergeOrdinaire:
        return 0xFFE64A19;
      case ClassificationHuile.lampante:
        return 0xFFD32F2F;
    }
  }

  static ClassificationHuile fromJson(String s) {
    switch (s) {
      case 'extra_vierge':
        return ClassificationHuile.extraVierge;
      case 'vierge':
        return ClassificationHuile.vierge;
      case 'vierge_ordinaire':
        return ClassificationHuile.viergeOrdinaire;
      case 'lampante':
        return ClassificationHuile.lampante;
      default:
        return ClassificationHuile.extraVierge;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TYPE DE FRUITÉ — PR-48 §5 et §8
// Remplace l'ancien booléen `fruiteVert` : le §8 distingue « vert-mûre » de
// « mûre » pour séparer Extra B d'Extra B−.
// ═════════════════════════════════════════════════════════════════════════════
enum TypeFruite { vert, vertMur, mur }

extension TypeFruiteX on TypeFruite {
  String get toJson {
    switch (this) {
      case TypeFruite.vert:
        return 'vert';
      case TypeFruite.vertMur:
        return 'vert_mur';
      case TypeFruite.mur:
        return 'mur';
    }
  }

  String get label {
    switch (this) {
      case TypeFruite.vert:
        return 'Vert';
      case TypeFruite.vertMur:
        return 'Vert-mûr';
      case TypeFruite.mur:
        return 'Mûr';
    }
  }

  String get emoji {
    switch (this) {
      case TypeFruite.vert:
        return '🌿';
      case TypeFruite.vertMur:
        return '🫒';
      case TypeFruite.mur:
        return '🟤';
    }
  }

  static TypeFruite fromJson(String? s) {
    switch (s) {
      case 'vert_mur':
        return TypeFruite.vertMur;
      case 'mur':
        return TypeFruite.mur;
      default:
        return TypeFruite.vert;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CLASSE INTERNE — PR-48 §8, plus « Extra déséquilibrée » (§6 et §9)
// Classification maison, distincte de la catégorie réglementaire COI
// (`ClassificationHuile`). Elle ne s'applique qu'aux huiles extra vierges.
// ═════════════════════════════════════════════════════════════════════════════
enum ClasseInterne {
  extraAPlus,
  extraA,
  extraBPlus,
  extraB,
  extraBMoins,
  extraC,
  extraDesequilibre,
}

extension ClasseInterneX on ClasseInterne {
  String get toJson {
    switch (this) {
      case ClasseInterne.extraAPlus:
        return 'extra_a_plus';
      case ClasseInterne.extraA:
        return 'extra_a';
      case ClasseInterne.extraBPlus:
        return 'extra_b_plus';
      case ClasseInterne.extraB:
        return 'extra_b';
      case ClasseInterne.extraBMoins:
        return 'extra_b_moins';
      case ClasseInterne.extraC:
        return 'extra_c';
      case ClasseInterne.extraDesequilibre:
        return 'extra_desequilibre';
    }
  }

  String get label {
    switch (this) {
      case ClasseInterne.extraAPlus:
        return 'Extra A+';
      case ClasseInterne.extraA:
        return 'Extra A';
      case ClasseInterne.extraBPlus:
        return 'Extra B+';
      case ClasseInterne.extraB:
        return 'Extra B';
      case ClasseInterne.extraBMoins:
        return 'Extra B−';
      case ClasseInterne.extraC:
        return 'Extra C';
      case ClasseInterne.extraDesequilibre:
        return 'Extra déséquilibrée';
    }
  }

  /// Dégradé du vert de marque vers le gris, du profil le plus expressif au plus plat.
  /// « Extra déséquilibrée » sort du dégradé : ce n'est pas un rang, c'est un écart.
  int get colorValue {
    switch (this) {
      case ClasseInterne.extraAPlus:
        return 0xFF38835A;
      case ClasseInterne.extraA:
        return 0xFF4E9A6B;
      case ClasseInterne.extraBPlus:
        return 0xFF6B8143;
      case ClasseInterne.extraB:
        return 0xFF8A9A5B;
      case ClasseInterne.extraBMoins:
        return 0xFFA8A878;
      case ClasseInterne.extraC:
        return 0xFF9E9E9E;
      case ClasseInterne.extraDesequilibre:
        return 0xFFE64A19;
    }
  }

  /// Description sensorielle du PR-48 §8, affichée sous la classe.
  String get description {
    switch (this) {
      case ClasseInterne.extraAPlus:
        return 'Très expressive et équilibrée, fortement valorisable. Fruité vert '
            'intense, amertume maîtrisée, piquant présent.';
      case ClasseInterne.extraA:
        return 'Équilibrée et agréable, fruité vert marqué, intensité moyenne en '
            'amertume et en piquant.';
      case ClasseInterne.extraBPlus:
        return 'Équilibrée, fruité vert moyen, amertume et piquant modérés. '
            'Conforme, moins expressive que les classes supérieures.';
      case ClasseInterne.extraB:
        return 'Conforme, fruité moyen ou vert-mûre, expression sensorielle limitée.';
      case ClasseInterne.extraBMoins:
        return 'Conforme, à dominante mûre, faible expression aromatique. '
            'Peut être destinée au coupage.';
      case ClasseInterne.extraC:
        return 'Profil plat et peu aromatique, faible structure sensorielle. '
            'Plus sensible à l\'évolution au cours du stockage. Sans défaut.';
      case ClasseInterne.extraDesequilibre:
        return 'Amertume ou piquant très élevé par rapport au fruité. Conforme COI '
            'mais déséquilibrée.';
    }
  }

  static ClasseInterne? fromJson(String? s) {
    switch (s) {
      case 'extra_a_plus':
        return ClasseInterne.extraAPlus;
      case 'extra_a':
        return ClasseInterne.extraA;
      case 'extra_b_plus':
        return ClasseInterne.extraBPlus;
      case 'extra_b':
        return ClasseInterne.extraB;
      case 'extra_b_moins':
        return ClasseInterne.extraBMoins;
      case 'extra_c':
        return ClasseInterne.extraC;
      case 'extra_desequilibre':
        return ClasseInterne.extraDesequilibre;
      default:
        return null;
    }
  }
}

// ── Planification mode (shared by arrivage + livraison) ──────────────────────
enum ModePlanification { dateExacte, periode }

extension ModePlanificationX on ModePlanification {
  String get toJson {
    switch (this) {
      case ModePlanification.dateExacte:
        return 'date_exacte';
      case ModePlanification.periode:
        return 'periode';
    }
  }

  static ModePlanification fromJson(String s) {
    switch (s) {
      case 'date_exacte':
        return ModePlanification.dateExacte;
      case 'periode':
        return ModePlanification.periode;
      default:
        return ModePlanification.dateExacte;
    }
  }
}

// ── Session status ────────────────────────────────────────────────────────────
enum StatutSession { enAttenteValidation, planifiee, enCours, terminee, refusee }

extension StatutSessionX on StatutSession {
  String get toJson {
    switch (this) {
      case StatutSession.enAttenteValidation:
        return 'en_attente_validation';
      case StatutSession.planifiee:
        return 'planifiee';
      case StatutSession.enCours:
        return 'en_cours';
      case StatutSession.terminee:
        return 'terminee';
      case StatutSession.refusee:
        return 'refusee';
    }
  }

  String get label {
    switch (this) {
      case StatutSession.enAttenteValidation:
        return 'En attente';
      case StatutSession.planifiee:
        return 'Planifiée';
      case StatutSession.enCours:
        return 'En cours';
      case StatutSession.terminee:
        return 'Terminée';
      case StatutSession.refusee:
        return 'Refusée';
    }
  }

  static StatutSession fromJson(String s) {
    switch (s) {
      case 'en_attente_validation':
        return StatutSession.enAttenteValidation;
      case 'planifiee':
        return StatutSession.planifiee;
      case 'en_cours':
        return StatutSession.enCours;
      case 'terminee':
        return StatutSession.terminee;
      case 'refusee':
        return StatutSession.refusee;
      default:
        return StatutSession.planifiee;
    }
  }
}

// ── Lab analysis priority ─────────────────────────────────────────────────────
enum PrioriteAnalyse { normale, urgente }

extension PrioriteAnalyseX on PrioriteAnalyse {
  String get toJson {
    switch (this) {
      case PrioriteAnalyse.normale:
        return 'normale';
      case PrioriteAnalyse.urgente:
        return 'urgente';
    }
  }

  String get label {
    switch (this) {
      case PrioriteAnalyse.normale:
        return 'Normale';
      case PrioriteAnalyse.urgente:
        return 'Urgente';
    }
  }

  static PrioriteAnalyse fromJson(String s) {
    switch (s) {
      case 'normale':
        return PrioriteAnalyse.normale;
      case 'urgente':
        return PrioriteAnalyse.urgente;
      default:
        return PrioriteAnalyse.normale;
    }
  }
}
