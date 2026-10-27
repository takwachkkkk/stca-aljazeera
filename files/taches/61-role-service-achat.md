# Tâche 61 — Nouveau rôle « Service achat »

Écrit et fait le 27/10/2026 par Claude (exécutant : Claude).

## Demande

Un nouveau compte pour le **Service achat** (un service de l'entreprise, pas un acheteur
externe) : il voit seulement les achats confirmés, les dates de livraison prévues du stock et le
détail de chaque produit. Aucune évaluation, aucun travail du laboratoire.

Décisions de l'utilisatrice : la date de livraison **réelle** n'est enregistrée par personne pour
l'instant (aucun champ ne la stocke ; `stock_arrive` n'est jamais mis à vrai) — le Service achat
voit la date **prévue**. Le compte est créé comme les autres, par le chef, depuis « Utilisateurs ».

## RAPPORT

- **Serveur** : rôle `service_achat` (« Service achat », migration `users/0008`), permission
  `IsServiceAchat`, application `service_achat` avec `/api/service-achat/achats/` en lecture
  seule. Réponse propre au rôle, limitée aux champs d'achat (produit, fournisseur, lieu, variété,
  citerne, collecteur, quantité, prix, camion, remarque du collecteur, livraison prévue) — pas
  de classification, remarques de dégustation, statuts dégustateur / labo ni note interne.
  `/api/echantillons/`, `/api/evaluations/`, `/api/analyses/` restent refusés (403).
- **Application** : `RoleUtilisateur.serviceAchat`, ouverture directe sur
  `lib/6_service_achat/achats/achats_service_achat_page.dart` après connexion. Recherche, filtres
  « Tous / Livraison à venir / En retard / Stock livré », compteur, cartes avec le détail du
  produit et la date de livraison prévue mise en avant (bleu à venir, orange dépassée). Menu :
  Achats confirmés, Changer le mot de passe (fenêtre commune), Déconnexion.
- **Utilisateurs** (chef / direction) : « Service achat » dans la liste des rôles à la création
  et dans les filtres.
- Migration appliquée sur la base locale après sauvegarde
  `backend_new/db_avant_tache61_20261027_1220.sqlite3`.
- Tests : Django `service_achat.tests` (5) ; Flutter `test/service_achat_test.dart` (3).

## Reste possible

- Enregistrer la livraison réelle (date + qui confirme) quand l'utilisatrice le décidera.
- Notifications au Service achat quand un achat est confirmé.
