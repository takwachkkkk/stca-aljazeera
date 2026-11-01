# Tâche 62 — Masquer le laboratoire sans le supprimer

Demande du 31/10/2026 : retirer de l'application tout ce qui touche au labo (pages, compte, rôle),
sans effacer le code, pour pouvoir le réutiliser.

## Réactiver le labo

Les deux interrupteurs doivent changer ensemble :

- application : `flutter run --dart-define=LABO_ACTIF=true` (ou la valeur par défaut de `kLaboActif`
  dans `lib/core/fonctionnalites.dart`) ;
- serveur : `LABO_ACTIF=True` dans `backend_new/.env` (et sur Render).

Aucune migration à faire : les tables, les comptes et les analyses sont restés en base.

## Ce que l'interrupteur coupe

Application :
- menus CEO, dégustateur et chef : entrée « Analyse laboratoire » ;
- tableau de bord CEO : case « Analyses soumises » ;
- page Utilisateurs : filtre « Laboratoire » et rôle dans le formulaire ;
- connexion et reprise de session : un compte labo est refusé (« Ce compte est désactivé. ») ;
- écran Échantillons CEO : plus d'appel à `/api/analyses/`.

Serveur :
- connexion refusée pour le rôle labo, et `IsLaboratoire` toujours faux (bloque aussi les sessions
  déjà ouvertes) ;
- `/api/users/` ne liste plus les comptes labo ; création d'un compte labo refusée ;
- aucune notification envoyée au labo ; anciennes notifications de la section ANALYSES cachées
  (toujours en base) ;
- `/api/notifications/analyse-urgente/` renvoie 404 ;
- `seed_auth_users` ne crée plus `labo@stca.tn`.

## Tests

- `backend_new/core/tests_labo_masque.py` et `test/labo_masque_test.dart` vérifient le masquage.
- Les anciens tests du labo tournent avec `@override_settings(LABO_ACTIF=True)`. Le test de parcours
  en a besoin : il réécrit `test/fixtures/` à chaque lancement.
