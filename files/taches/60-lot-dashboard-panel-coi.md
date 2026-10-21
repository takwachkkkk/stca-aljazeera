# Tâche 60 — Intensités, filtres, vue d'ensemble, tableaux de bord, résultat du panel (COI)

Écrit et fait le 21/10/2026 par Claude (exécutant : Claude).

## Demandes et décisions

- Choix de l'utilisatrice : résultat COI **par échantillon + vue d'ensemble par mois** ;
  messagerie remontée **pour le chef seulement** (le dégustateur n'a pas de messagerie) ;
  carte des gouvernorats **chez le chef et la direction**.

## RAPPORT

1. **Intensité** : « Léger / Moyen / Intense » (au lieu de Délicat / Moyen / Robuste), seuils
   à 30 % et 60 % de l'échelle (3 et 6 sur 0–10, attributs positifs compris depuis la tâche 59).
   La direction utilise la même fonction (`intensiteLabel`) au lieu de sa copie.
2. **Page Évaluation** (dégustateur + chef) : seulement les échantillons dont la réception est
   confirmée (`?recu_physiquement=true`). Filtres : ouvrir un échantillon ne le passe plus en
   « Évaluation en cours » ; au retour, le vrai statut est relu sur le serveur.
3. **Formulaire d'évaluation** : règles écrites en français simple (plus de « ≤ », « > 0.0 »,
   « §6 », « §9 », « §8 ») ; si le numéro manque, « Échantillon » au lieu de l'identifiant.
4. **Gestion des échantillons** (dégustateur + chef) : les boutons « Évaluation en cours » et
   « Évaluation soumise » ne trouvaient jamais rien (« En cours » ≠ « Évaluation en cours ») ;
   comparaison par statut (`libelleFiltre`). Le statut affiché est celui de **l'évaluation de
   l'utilisateur connecté** (avant : statut global de l'échantillon, changé dès qu'un collègue
   commençait — règle 2). Option `statutPersonnel` du service, la messagerie ne l'utilise pas.
5. **Vue d'ensemble évaluations** (chef) et **Analyse organoleptique** (direction, même widget
   `PanelList`) : plus de pastille d'initiale, nom en entier (police 12, deux lignes), catégorie
   COI + classe interne, icône « fiche » au lieu de « Formulaire ». La fiche ouverte depuis la vue
   d'ensemble contient maintenant les défauts, le type de fruité et la classe interne (le serveur
   `/api/chef/evaluations/` les renvoie). Copies mortes `_PanelList`, `_DecisionButton`,
   `_RecuPhysiqueIndicator` supprimées de la page direction.
6. **Menu du chef** : Messagerie (avec son badge) juste sous Accueil.
7. **Délai de soumission** retiré des tableaux de bord chef et dégustateur (plus chargé).
8. **« Niveau d'harmonisation avec le panel »** (ancien « Alignement ») : affiche 100 % −
   divergence ; plus c'est haut, mieux c'est.
9. **Classifications du panel** : choix du mois (« Tous les mois » + chaque mois), tuiles avec
   les nombres exacts, nombre au-dessus de chaque barre, mois en français (le serveur envoie
   `annee` et `mois`).
10. **Échantillons par gouvernorat** : `core/dashboard_calculations.repartition_par_gouvernorat`,
    `/api/chef/dashboard/regions/` et `/api/ceo/dashboard/regions/` ; carte partagée
    `lib/core/widgets/repartition_regions_card.dart` (ce mois, 3 mois, cette année, tout).
11. **Résultat du panel (méthode COI_CALC)** : `evaluations/statistiques_panel.py` reproduit les
    formules du fichier du COI (médiane, moyenne, écart-type, IQR, S*, CVr %, intervalle 95 %) ;
    catégorie par la même règle que l'évaluation individuelle ; fiable si CVr ≤ 20 %.
    `/api/chef/panel-coi/` (chef seulement). Flutter : section du tableau de bord chef (par mois,
    nombres par catégorie, fiables / à refaire, 5 derniers) et bouton « Résultat du panel » sur
    chaque carte de la vue d'ensemble → fiche détaillée.

Tests : Django `PanelCoiEtRegionsTests` (exemple 1 du fichier COI : médiane 5, IQR 1.25,
CVr 8.2 %, vierge ordinaire) ; Flutter `test/tache_60_test.dart`, tests d'intensité et de motifs
mis à jour.

Reste : les méthodes `_buildX` des deux `home_body.dart` (≈ 1 300 lignes chacune) ne sont plus
appelées depuis le découpage en sections — à supprimer dans une tâche de nettoyage.
