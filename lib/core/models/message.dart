class Message {
  final String id;
  final String expediteur;
  final String destinataire;
  final String expediteurNom;
  final String destinataireNom;
  final String contenu;
  final String? photoUrl;
  final String? echantillonId;
  final String? echantillonNumero;
  final String? echantillonReferenceBouteille;
  final String? echantillonFournisseurNom;
  final bool modifie;
  final String? modifieLe;
  bool lu;
  String? luLe;
  final String dateEnvoi;

  Message({
    required this.id,
    required this.expediteur,
    required this.destinataire,
    required this.expediteurNom,
    required this.destinataireNom,
    required this.contenu,
    this.photoUrl,
    this.echantillonId,
    this.echantillonNumero,
    this.echantillonReferenceBouteille,
    this.echantillonFournisseurNom,
    this.modifie = false,
    this.modifieLe,
    this.lu = false,
    this.luLe,
    required this.dateEnvoi,
  });

  /// Le texte court montré dans une alerte, même si le message n'a pas de texte.
  String get apercu {
    final texte = contenu.trim();
    if (texte.isNotEmpty) return texte;
    if (photoUrl?.trim().isNotEmpty == true) return 'Photo';
    return 'Échantillon cité';
  }

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    expediteur: json['expediteur'] as String,
    destinataire: json['destinataire'] as String,
    expediteurNom: (json['expediteur_nom'] as String?) ?? '',
    destinataireNom: (json['destinataire_nom'] as String?) ?? '',
    contenu: (json['contenu'] as String?) ?? '',
    photoUrl: json['photo_url'] as String?,
    echantillonId: json['echantillon'] as String?,
    echantillonNumero: json['echantillon_numero'] as String?,
    echantillonReferenceBouteille:
        json['echantillon_reference_bouteille'] as String?,
    echantillonFournisseurNom: json['echantillon_fournisseur_nom'] as String?,
    modifie: (json['modifie'] as bool?) ?? false,
    modifieLe: json['modifie_le'] as String?,
    lu: (json['lu'] as bool?) ?? (json['is_read'] as bool?) ?? false,
    luLe: json['lu_le'] as String?,
    dateEnvoi:
        (json['date_envoi'] as String?) ??
        (json['horodatage'] as String?) ??
        '',
  );

  static List<Message> fromJsonList(Map<String, dynamic> json) =>
      (json['results'] as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();

  Map<String, dynamic> toJson() => toCreateJson();

  Map<String, dynamic> toCreateJson() => {
    'destinataire': destinataire,
    'contenu': contenu,
    if (echantillonId != null) 'echantillon': echantillonId,
  };
}
