# Tâche 64 — Service achat : bouton « Facturer »

## Demande

Sur chaque stock du compte Service achat, un bouton de validation « Facturer » : la personne a
établi la facture dans son logiciel et le signale ici. Le filtre « En retard » est retiré et
remplacé par un filtre « Facturer ».

## Fait

- **Serveur** : champs `facture`, `date_facture`, `facture_par` sur `Echantillon` (migration
  `echantillons/0017`). Nouvelle URL `POST /api/service-achat/achats/<id>/facturer/`, réservée au
  rôle `service_achat` et aux achats confirmés.
- **Une seule facturation** : si deux personnes facturent le même stock, la date et l'auteur de la
  première restent. Les champs ne passent pas par `/api/echantillons/` : les autres rôles ne les
  voient pas et ne peuvent pas les modifier.
- **Application** : bouton vert sur chaque carte avec confirmation, puis « Facturé le … par … ».
  Le filtre « Facturer » montre les stocks déjà facturés.

## Limites

- La facturation est définitive : aucun bouton pour l'annuler.
- L'état « en retard » reste calculé : la carte affiche toujours « La date prévue est dépassée. »,
  et ces stocks restent visibles dans « Tous ».
- Après `git pull` : `python manage.py migrate`, sinon le serveur répond 500.
