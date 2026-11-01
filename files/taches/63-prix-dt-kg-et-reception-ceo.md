# Tâche 63 — Prix en DT/kg, prix par tonne calculé, coche de réception direction

## Demande

Prix en DT/kg au lieu de DT/tonne, prix DT/tonne calculé à partir du DT/kg pour la négociation
(direction et collecteur), et débordement de la coche « réception physique » de la direction.

## Fait

- `MontantAchat` : un prix sans unité est un prix au kilo ; le prix par tonne en découle (× 1000).
- Nouveau champ partagé `lib/core/widgets/champ_prix_kg.dart` : saisie en DT/kg, prix par tonne
  affiché en direct. Utilisé par `ApprovalDialog` et le dialogue de confirmation d'achat.
- Prix affiché en DT/kg et DT/tonne : cartes direction, collecteur, service achat, notifications.
- Serveur : `budget_negociation`, `budget_negociation_max` et `prix_final` passent à 3 décimales
  (millimes) ; messages de notification en DT/kg. Le prix par tonne n'est pas stocké.
- Carte direction : la coche a sa propre ligne, comme chez le dégustateur, et les boutons de
  décision rétrécissent sur petit écran. Test à 320 px : `test/prix_et_reception_ceo_test.dart`.

## Limites

- Les prix existants en base ne sont pas convertis : leurs valeurs (10 à 255) sont lues en DT/kg.
- `investissement_total` du tableau de bord additionne les prix unitaires sans les multiplier par
  la quantité (déjà le cas avant cette tâche).
