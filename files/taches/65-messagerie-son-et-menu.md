# Tâche 65 — Messagerie : alerte avec son et bouton menu

Rôles concernés : direction, collecteur, chef de dégustation (les seuls qui ont la messagerie).

## Demande

1. Une notification avec un son agréable à chaque nouveau message.
2. Le bouton menu à la place de la flèche de retour dans la messagerie.

## Ce qui a été fait

### Alerte

- `lib/core/services/alerte_message_service.dart` vérifie toutes les 15 secondes les messages reçus.
  Démarré à la connexion, arrêté à la déconnexion et à l'expiration de la session.
- Appli ouverte : son + bandeau en haut de l'écran (`alerte_message_hote.dart`). Toucher le bandeau
  ouvre la conversation ; le glisser vers le haut le ferme.
- Appli en arrière-plan sur le téléphone : notification du téléphone avec le même son.
- Pas d'alerte pour la conversation déjà affichée : le message y apparaît directement.
- Pas de son pour les messages déjà là à la connexion : le badge suffit.
- Serveur : `/api/messages/non-lus/` renvoie aussi `derniers`, les 5 derniers non-lus de
  l'utilisateur connecté uniquement. **Le serveur Render doit être redéployé** pour que l'alerte marche.
- Son : `assets/sons/message.wav` (web, appli ouverte) et sa copie
  `android/app/src/main/res/raw/message.wav` (notification Android). Garder les deux identiques.

### Menu

- `ConversationsPage` reçoit le menu du rôle (`menu:`) et s'ouvre comme les autres pages du menu.
- La conversation avec une personne garde sa flèche : c'est le chemin pour revenir à la liste.

### Correction en plus

- Direction, tableau de bord : « Déconnexion » n'effaçait pas la session. Corrigé.

## Limites

- Appli complètement fermée, ou téléphone en veille depuis longtemps : pas de notification.
  Il faudrait Firebase Cloud Messaging (projet Firebase de la société, `google-services.json`,
  envoi côté serveur).
- iOS : son standard du téléphone pour la notification. `message.wav` n'est pas dans le projet Xcode.
- Web : son + bandeau, pas de notification du navigateur.

## Vérification

- `flutter analyze` : aucune erreur. `flutter test` : 233 tests passent.
- Tests Django `messages_chat` et `core` : passent.
- **Pas encore essayé sur le téléphone** : à vérifier, le son, la notification en arrière-plan et la
  demande d'autorisation Android.
