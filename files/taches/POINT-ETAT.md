# Point d'état — à lire en premier sur un autre PC

Mis à jour le 28/09/2026 par Claude (PC principal). Ce fichier explique où en est le projet,
les règles de travail et ce qu'il reste à faire. Lis-le avant toute modification.

## 1. Dépôt GitHub et deux PC

- Dépôt : **https://github.com/mohamed-chammakhi/stca-aljazeera** (privé, transféré à Mohamed ;
  `takwachkkkk` garde le droit d'écriture). Remote git : `origin`.
- Branche principale : `main` — toujours stable, tests verts.
- Travail pas fini : dans une branche à part (aujourd'hui : `tache-50b-en-cours`).
- **Deux PC travaillent sur le même dépôt. Règles :**
  1. Avant de commencer et avant chaque envoi : `git pull --rebase origin main`.
  2. **Jamais** `git push --force`.
  3. En cas de conflit : s'arrêter et expliquer à l'utilisatrice, ne pas choisir seul.
- L'ancien dépôt `flutter-echantillons-app` est **périmé** (140 commits de retard) : ne plus l'utiliser.

### Routine obligatoire (les deux PC, et Claude)

**Au début, avant de toucher au code :**
1. `git remote -v` → `origin` doit être `https://github.com/mohamed-chammakhi/stca-aljazeera.git`.
   Sinon : `git remote set-url origin https://github.com/mohamed-chammakhi/stca-aljazeera.git`.
2. `git pull --rebase origin main`.
3. `git status` → doit dire « Your branch is up to date with 'origin/main' ».

**Après chaque commit (pas seulement en fin de journée) :**
4. `git pull --rebase origin main` puis `git push origin main`.
5. Vérifier : `git status` → « up to date with 'origin/main' » et **rien** « ahead ».
   Un commit non envoyé n'existe **que sur ce PC** : l'autre PC ne le verra jamais.

**Avant d'éteindre ou de changer de PC :**
6. `git status` doit être propre et à jour. S'il reste des changements pas finis :
   les commiter dans une branche (`git checkout -b travail-en-cours`) et
   `git push -u origin travail-en-cours`, puis noter la branche dans ce fichier.

**Jamais :** `git push --force`, travailler dans un vieux dossier copié à la main, ou dans
l'ancien dépôt `flutter-echantillons-app`.

**Claude :** après chaque commit, faire les étapes 4 et 5 sans attendre qu'on le demande, et
dire à l'utilisatrice « envoyé sur GitHub » seulement si l'étape 5 est vérifiée.

## 2. Règles de travail (demandées par l'utilisatrice)

- Réponses **en français simple et court**. Ne dire « fait » qu'après vérification réelle.
- **Depuis le 21/10/2026 : Claude code lui-même** (demande de l'utilisatrice) — ne plus lancer
  Copilot ni Codex sauf demande explicite. Ancienne règle, pour mémoire :
  **Copilot (ou Codex) code, Claude vérifie** : Claude écrit une fiche de tâche dans `files/taches/NN-….md`,
  lance **GitHub Copilot CLI** (abonnement étudiant, modèle auto) :
  `bash files/taches/lancer_copilot.sh NN fichier.md` (journal `files/taches/copilot_NN.log`),
  puis relit, teste et commite. Copilot n'a pas le droit de commiter ni de pousser.
  Variante visible dans la fenêtre VS Code (panneau Copilot Chat, mode agent) :
  `bash files/taches/lancer_copilot_vscode.sh NN fichier.md` — attend « FIN RAPPORT » dans la fiche.
  Codex (`lancer_codex.sh`) reste possible s'il remarche.
  Claude ne code lui-même que les petites corrections (≤ 20 lignes) — sauf si l'utilisatrice
  dit « fais-le toi-même ».
- Les nouvelles demandes vont **en bas** de `files/taches/FILE-ATTENTE.md` et se font dans l'ordre.
- **Même correction pour tous les rôles** qui partagent un écran (collecteur, dégustateur, chef,
  laboratoire, direction).
- Pas de fausses données : tout est branché sur le vrai serveur.
- Commiter quand les tests passent. Vérifier l'encodage (pas de « Ã© », pas de BOM).
- **OCR : uniquement Azure Document Intelligence côté serveur. Jamais ML Kit** ni autre OCR
  sur le téléphone (décision définitive).
- Ne jamais afficher de code d'erreur technique (« 400 », « 500 »…) à l'utilisateur.

## 3. Vérifications avant chaque commit

```
flutter analyze            # regarder les lignes « error - » (il reste des « info »/« warning » anciens)
flutter test               # 177 tests aujourd'hui
cd backend_new && python manage.py test      # tests Django
python manage.py makemigrations --check --dry-run
```

## 4. Ce qu'il reste à faire

0. **Tâche 51 (PC secondaire)** — fiche `files/taches/51-lot-pc-secondaire.md`, branche
   `pc2-lot-51` (jamais `main`). Le PC secondaire code et pousse ; le PC principal récupère la
   branche, lance `flutter analyze`, `flutter test`, les tests Django, essaie sur le téléphone,
   corrige puis fusionne dans `main`. Le point 1 ci-dessous (50b) fait partie de ce lot.
1. **Tâche 50b** — branche `tache-50b-en-cours`, fiche
   `files/taches/50b-ocr-document-intelligence-et-mlkit.md` (section « REPRISE » à la fin) :
   le service serveur passe déjà par Azure Document Intelligence ; reste à mettre à jour les
   tests `EchantillonOcrApiTests`, la section Azure de `docs/MISE-EN-SERVICE.md`, lancer les
   tests, puis fusionner dans `main`.
   → Avant de commencer : `git checkout tache-50b-en-cours && git merge main`
   (la branche a été créée avant les deux derniers correctifs de connexion).
2. **Codex bloqué** depuis le 27/09 : « le modèle gpt-5.5 n'existe pas ou pas d'accès ».
   Vérifier l'abonnement ChatGPT / se reconnecter dans l'extension Codex.
3. Optionnel (à confirmer par l'utilisatrice) :
   - notifier le collecteur quand un achat est confirmé ou refusé ;
   - notifier le dégustateur quand sa session est approuvée ou refusée (fait en tâche 48 — à vérifier) ;
   - afficher la fin de la plage de dates de livraison dans le stock.
4. Côté société : configurer l'envoi d'emails Gmail (mot de passe d'application) et plus tard
   la clé Azure — voir `docs/MISE-EN-SERVICE.md`.

## 5. Dernières tâches faites (voir `git log`)

- 48 : sessions — nombre prévu, visibilité, droits du créateur, notifications, dates passées.
- 49 : sessions triées de la plus récente à la plus ancienne, statut écrit, filtres.
- Réception physique : plus de bandeau en double.
- 50 : même bloc photo par échantillon pour les 3 rôles (appareil photo / galerie) + bouton
  « Lire l'étiquette » (grisé tant qu'Azure n'est pas configuré).
- Connexion : messages clairs, plus aucun code HTTP affiché.

## 6. Installer le projet sur un nouveau PC

Ces éléments **ne sont pas sur GitHub** (volontairement) et doivent être recréés ou copiés :

- `backend_new/venv` : `python -m venv venv` puis `venv\Scripts\pip install -r requirements.txt`.
- `backend_new/.env` : partir de `backend_new/.env.example`.
- `backend_new/db.sqlite3` (la base) et `backend_new/media/` (photos) : à copier depuis le PC
  principal si on veut les mêmes données ; sinon `python manage.py migrate` crée une base vide.
- `lib/config.dart` : adresse du serveur pour l'application — fichier ignoré par git, à copier
  depuis le PC principal (avec le téléphone en USB + `adb reverse`, l'adresse est
  `http://127.0.0.1:8000`).
- Téléphone branché en USB : `adb reverse tcp:8000 tcp:8000`, puis
  `python manage.py runserver 0.0.0.0:8000`.

## 7. Comptes de test (base du PC principal)

- Direction : `direction@stca.tn` / `Test@123455`.
- Les autres comptes : voir la page Utilisateurs (direction ou chef).
