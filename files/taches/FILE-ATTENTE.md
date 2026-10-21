# File d'attente — l'ordre des travaux

Règle : **on finit toujours la tâche du haut avant de commencer la suivante.**
Une nouvelle demande de la propriétaire va **en bas** de la liste, jamais devant une
tâche déjà commencée. Une tâche n'est « terminée » que quand elle est vérifiée
(`flutter analyze`, `flutter test`), approuvée par la propriétaire et commitée.

Claude tient cette liste à jour. Codex ne travaille que sur la tâche marquée « EN COURS ».

| # | Demande | Qui | État |
|---|---------|-----|------|
| 1 | Dates de livraison sur la carte dégustateur / chef | Claude | Terminée et commitée |
| 2 | Suppression des données de démonstration | Claude | Terminée et commitée |
| 3 | Tâche 36 : session expirée, photo en grand, suggestions, bouton Ajouter | Codex | Terminée et commitée |
| 4 | Écran rouge en cherchant par date (collecteur, « Jour exact ») | Claude | Terminée et commitée |
| 5 | Tâche 37 : les formulaires ne se ferment plus en touchant à côté | Codex | Terminée et commitée |
| 6 | Rester connecté : 8 h sans utilisation, puis reconnexion | Claude | Terminée et commitée |
| 7 | Tâche 38 : suggestions fournisseur / variété visibles + ordre réf, citerne, quantité, variété | Codex | Terminée et commitée |
| 8 | Suppression des données d'essai de la base (4 fournisseurs, 5 échantillons) — sauvegarde : `backend_new/sauvegarde_avant_nettoyage_2026-09-25.json` | Claude | Terminée |
| 9 | Tâche 39 : plus de fenêtre « fournisseurs proches », référence avec le nom, fenêtre « ancienne / nouvelle référence » en modification | Codex | Terminée et commitée |
| 10 | Message « Impossible de charger les données » remplacé : cause claire (session, serveur) ; liste vide = « le système est tout neuf » | Claude | Terminée et commitée |
| 11 | Tâche 40 : (1) variété même couleur que les autres champs ; (2) suggestions limitées aux fournisseurs / variétés du collecteur ; (3) titres et indications plus foncés ; (4) obligatoires = 1 bouteille, fournisseur, référence ; (5) nom du fournisseur au lieu de F-000x | Codex | Terminée et commitée |
| 12 | Tâche 41 : filtre « Livraison échantillon » = date annoncée même après achat conclu ; fenêtres d'erreur du changement de mot de passe ; numéro après 2026/9999 → 2026/10000 (bug de tri) | Codex | Terminée et commitée |
| 13 | Tâche 42 : mot de passe oublié — code à 6 chiffres envoyé à l'email du compte, 15 min, 4 essais | Codex | Terminée et commitée — adresse d'envoi à configurer (docs/MISE-EN-SERVICE.md) |
| 14 | Tâche 43 : fournisseur = nom + gouvernorat + délégation (« hami — Gabès »), deux homonymes restent distincts ; suppression du code fournisseur F-000x | Codex | Terminée et commitée (migration appliquée après sauvegarde ; « omarr » séparé en deux fournisseurs, un par lieu) |
| 15 | Tâche 44 : messagerie — citer une bouteille : recherche sur le serveur (tous les champs), 15 plus récentes, détails (référence, fournisseur, lieu, citerne, quantité, variété), fenêtre qui ne passe plus sous la barre du téléphone | Codex + Claude | Terminée et commitée (tests de la fenêtre ajoutés par Claude) |
| 16 | Mot de passe du compte direction@stca.tn remis à « test123 » | Claude | Terminée |
| 17 | Tâche 45 : message vertical → bandeau 3 s ; compteurs « total » retirés (tous rôles) ; phrase « Consultation seule » retirée ; Utilisateurs : toucher = fiche, statut dans la fiche, date lisible ; utilisateur supprimé gardé dans la liste ; profil : retour au tableau de bord + « Mot de passe oublié ? » | Codex + Claude | Terminée et commitée (Codex coupé par sa limite ; fini par Claude) |
| 18 | Chef : tableau de bord « Bad state: No element » + « Un problème est survenu » sur Gestion des échantillons (classification vide) | Claude | Terminée et commitée |
| 19 | Deux comptes de test : test1@stca.tn et test2@stca.tn (dégustateurs, mot de passe test123) | Claude | Terminée |
| 20 | Tâche 46 : déconnexion qui ferme tout ; valeurs vides sans plantage ; suggestions dégustateurs ; enregistrement impossible en dégustateur ; formulaire dégustateur = collecteur (+ collecteur facultatif avec suggestions) ; évaluation (numéro, date, photo, débordement) ; textes longs ; sessions (obligatoires, date) ; chef : sans Membres du panel, Utilisateurs inchangée sauf total, rôle en liste, fenêtre de succès, email unique ; mot de passe généré envoyé par email | Codex | Partie 1 terminée et commitée (A, B, I, J) |
| 21 | Dégustateur : Gestion des échantillons vide (filtre « reçus » sur la page qui confirme la réception) ; sessions sans UUID + nom de l'organisateur ; évaluation : numéro et date lisibles | Claude | Terminée et commitée |
| 22 | Serveur du téléphone séparé du code en cours : il tourne depuis `../project3-serveur` (dernier commit vérifié), plus depuis les fichiers que Codex modifie | Claude | Terminée |
| 23 | **Tâche 47 : audit du câblage de bout en bout (PRIORITAIRE, avant 43-46)** : parcours réel d'un échantillon sur tous les rôles, lecture de chaque réponse par l'application, plus aucun UUID ni date brute à l'écran, même chose = même nom, pages vides expliquées | Codex + Claude | Partie 1 terminée et commitée (0 défaut sur 567 réponses ; plantage des nombres et dates brutes corrigés) |
| 24 | Tâche 47b : un seul nom par idée côté Flutter (`ref` supprimé), un test par écran principal, champs serveur inutilisés listés | Codex + Claude | Terminée et commitée (153 tests ; 9 écrans vérifiés à 360 px) |
| 25 | Tâche 46b : suite de la 46 — C suggestions dégustateurs, D enregistrement en dégustateur, E formulaire aligné sur le collecteur, F photo et débordement de l'évaluation, G textes longs, H sessions, nombre d'utilisateurs du chef, tests A et B | Codex + Claude | Terminée et commitée (photo à la modification ajoutée pour les 3 rôles ; carte d'évaluation qui débordait corrigée) |
| 26 | Tâche 46c : tests restants — déconnexion (pile vide), envoi de la photo en création et en modification | Codex | Terminée et commitée (171 tests) |

**Accord git (25/09/2026) :** la propriétaire a donné son accord pour commiter les
lignes 1 à 6 en une seule fois, quand la tâche 37 est finie et que `flutter analyze` +
`flutter test` passent. Si un test échoue, on corrige d'abord, on ne commite pas.

## Prochaines demandes

Écris une demande par ligne, dans l'ordre voulu. Claude en fait une tâche, dans l'ordre.
Pendant la nuit, voir `BOUCLE-NUIT.md`.

| 27 | Tâche 48 — sessions : nombre, visibilité, droits, notifications, dates passées | fait |
| 28 | Tâche 49 — sessions : ordre récent → ancien, statut écrit, filtres | fait |
| 29 | Tâche 50 — photo d'échantillon identique (3 rôles) + OCR Azure prêt à activer | fait |
| 30 | Tâche 50b — OCR : Azure Document Intelligence (sans ML Kit) | en cours |
| 31 | Tâche 51 — lot de 7 corrections (OCR + photo par échantillon, carte direction, notifications, sessions passées, réception physique direction, message évaluation, bordereau PDF) — fait par le PC secondaire sur la branche `pc2-lot-51`, vérifié par le PC principal | fait |
| 32 | Tâche 52 — « Enregistré le » (date d'enregistrement dans l'application) sur toutes les cartes d'échantillon, tous les rôles — exécutant Copilot | fait |
| 33 | Tâche 53 — Bordereau : période, aperçu, partager / imprimer, mise en page proche du papier avec logo — exécutant Copilot | fait |
| 34 | Tâche 54 — Session : seuls titre et date obligatoires, message visible dans le formulaire, vrais participants chez le chef — exécutant Copilot | fait |
| 35 | Tâche 55 — Analyse laboratoire (dégustateur + chef) : voir tous les échantillons, même non reçus ou sans analyse — exécutant Copilot | fait |
| 36 | Tâche 56 — Direction : approbation réparée (numéro au lieu de l'identifiant), approuver sans réception ni dégustation, carte organoleptique (Qté sur une ligne, cloche seule, ✓ en bas), Utilisateurs (sans « effacer les filtres », couleurs neutres, recherche sans rôle), textes d'aide de recherche, chef dans la messagerie — exécutant Copilot | fait |
| 37 | Tâche 57 — Dates lisibles partout (formulaire « Date d'arrivée » : ISO brut + mauvaise date), plus de bouton « effacer les filtres » dans toute l'application — exécutant Copilot | fait |
| 38 | Tâche 58 — Menus : chaque entrée (dont « Accueil ») ouvre la bonne page, depuis chaque page, pour les 5 rôles — exécutant Copilot | fait |
| 39 | Tâche 59 — lot démo : boutons de débogage retirés, variétés multiples + liste tunisienne + suggestion proche, date de livraison en 2 boutons, « Confirmation réception d'échantillon », flèche retour messagerie, mot de passe lettres + chiffres, chef anonyme pour les dégustateurs, droits de modification, numéro lisible + échelle 0–10 pas 0,1 dans l'évaluation ; bug d'enregistrement en modification corrigé par Claude — exécutant Claude | fait |
| 40 | Tâche 60 — Léger/Moyen/Intense, page Évaluation (reçus seulement, filtres), textes du formulaire, filtres Gestion (statut personnel), vue d'ensemble (nom, fiche, classe interne), messagerie en haut du menu chef, délai retiré, niveau d'harmonisation, classifications par mois en nombres, carte par gouvernorat (chef + direction), résultat du panel méthode COI — exécutant Claude | fait |
