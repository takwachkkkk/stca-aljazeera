// ─────────────────────────────────────────────────────────────────────────────
// FILE : core/fonctionnalites.dart
// PURPOSE : Interrupteurs des fonctionnalités masquées de l'application.
// ─────────────────────────────────────────────────────────────────────────────

/// Laboratoire : pages, rôle, comptes et notifications. Masqué, pas supprimé :
/// tout le code reste en place. Pour le réactiver :
/// `flutter run --dart-define=LABO_ACTIF=true` (ou changer la valeur par défaut
/// ici) et mettre `LABO_ACTIF=True` dans le `.env` du serveur.
const bool kLaboActif = bool.fromEnvironment('LABO_ACTIF');
