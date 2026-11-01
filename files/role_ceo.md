# role_ceo.md — Direction / CEO (`1_ceo/`)

Cannot register or modify samples directly.

---

## Pages

- **Échantillons** — all samples grouped by collector, filterable by date. Status badges: `Réceptionné`, `En négociation`, `Achat confirmé`, `Achat non conclu`. Click → full details including delivery info and purchase details.
- **Analyse Organoleptique** — all samples with each panel member's completed sensory evaluation. CEO approves a sample for purchase from this page → sets `budgetNegociation` (price in DT/kg; the DT/tonne price is derived, never stored) and `dateLivraisonStockSouhaitee`. After an `Achat non conclu`, the same button reads **Rouvrir** and reopens the negotiation. A confirmed purchase cannot be reopened.
- **No purchase validation page.** The collector concludes the purchase himself (confirmed, or not concluded with an optional reason); the CEO is notified and only sees the result.
- **Analyse Laboratoire** — samples with linked lab analysis results, filterable by date.
- **Achats Confirmés** — confirmed purchases in two sub-states: **Stock en transit** (purchased, not yet arrived) and **Stock reçu** (physically arrived). Filterable by date.
- **Carte** — map showing per collector which Tunisian delegations have been visited vs not reached.
- **Dashboard** — KPIs (TBD).
- **Utilisateurs** — all app users with contact info. CEO can view details, delete a user, activate/deactivate an account.
- **Profile** — edit name, phone, email, password.

---

## What CEO Sees on a Sample

All samples from all collectors. Status badge. Approve/refuse action from Analyse Organoleptique page. Negotiation details after approval. Purchase details after confirmation.

## Decision Log (`ceo.DecisionDirection`)

Each `approuver` / `refuser` adds one row with the CEO account, the type (`negociation`, `reouverture`, `refus`), the offer or reason at that moment, and the date. Rows are never edited, so a reopening keeps the earlier decision. `GET /api/echantillons/` returns them as `decisions_direction`, newest first, and only to `direction` accounts (empty list for other roles). `statut_ceo`, `budget_negociation`, `budget_negociation_max`, `quantite_cible_t`, `note_interne` and `raison_refus` are read-only on the ordinary edit route: they change only through those two actions (statuses also change when the collector concludes a purchase). Decisions made before this table existed have no author.

---

## Delivery Display Rules (expanded sample card / `SampleDetails`)

Display as gray `— sentence —` text. No chips or icons.

**`StatutCeo.selectionne` (Enregistré):**

| Condition | Text |
|---|---|
| `recuPhysiquement == true` | `— Échantillon réceptionné le [dateArriveeEchantillon] —` |
| `dateLivraisonPrevue != null && dateLivraisonPrevueFin != null` | `— Échantillon attendu entre le [d1] et le [d2] —` |
| `dateLivraisonPrevue != null` | `— Échantillon attendu le [dateLivraisonPrevue] —` |
| none | `— Livraison de l'échantillon non planifiée —` |

**`StatutCeo.enNegociation` / `StatutCeo.achatNonConclu`:**
- `— Échantillon réceptionné le [dateArriveeEchantillon] —`
- `achatNonConclu` also shows the collector's reason in a grey box (or "aucune raison donnée").

**`StatutCeo.achatConfirme`** — two lines:
- Line 1: `— Échantillon réceptionné le [dateArriveeEchantillon] —`
- Line 2:

| Condition | Text |
|---|---|
| `stockArrive == true` | `— Stock réceptionné le [dateLivraisonStock] —` |
| `dateLivraisonStock != null && dateLivraisonStockFin != null` | `— Stock attendu entre le [d1] et le [d2] —` |
| `dateLivraisonStock != null` | `— Stock attendu pour le [dateLivraisonStock] —` |
| none | `— Livraison du stock non encore planifiée —` |

**`StatutCeo.refuse`:** No delivery section — show refusal reason instead.

**Date format:** Exact dates include time: `"03/03/2026 à 09h15"`. Date ranges: date only, no time.

---

## Notification System

Sent automatically to all active CEO accounts (`role='direction'`) via Django signals.

### Types & triggers

| Type | Trigger | Deep-link |
|---|---|---|
| `NOUVEL_ECHANTILLON` | Collector or taster creates a sample | ECHANTILLONS |
| `ECHANTILLON_MODIFIE` | Any field edited (not a status transition) | ECHANTILLONS |
| `ECHANTILLON_SUPPRIME` | Sample deleted (fires on `pre_delete`) | ECHANTILLONS |
| `ECHANTILLON_RECU` | Taster toggles `recu_physiquement` False → True | ECHANTILLONS |
| `PREMIERE_EVALUATION` | First taster submits evaluation (count 0 → 1) | EVALUATIONS |
| `TOUTES_EVALUATIONS` | All active tasters submitted for that sample | EVALUATIONS |
| `ANALYSE_SOUMISE` | Lab technician submits lab analysis | ANALYSES |
| `ACHAT_CONFIRME` | `statut_collecteur` transitions to `achat_confirme` (collector, with price) | ACHATS |
| `ACHAT_NON_CONCLU` | `statut_collecteur` transitions to `achat_non_conclu` (collector, with reason if given) — opens Analyse Organoleptique | ACHATS |

### Signal logic
- `pre_save` stores `_old_recu_physiquement` and `_old_statut_collecteur` so `post_save` can diff.
- `ECHANTILLON_MODIFIE` fires on any save that is NOT a creation, NOT a `recu_physiquement` flip, and NOT an `achat_confirme` transition.
- `ECHANTILLON_SUPPRIME` fires on `pre_delete` so `numero` and `reference_bouteille` can still be read before the record is gone.
- "All evaluations" check: count `EvaluationOrganoleptique` with `statut=soumis` and compare to `User.objects.filter(role='degustateur', is_active=True).count()`.

### Deep-link navigation

| `section` | Navigates to |
|---|---|
| `ECHANTILLONS` | `EchantillonsCeoPage` |
| `EVALUATIONS` | `AnalyseOrganoleptiqueCeoPage` |
| `ANALYSES` | `AnalyseLaboratoireCeoPage` |
| `ACHATS` | `AchatsConfirmesCeoPage` |

### Flutter files
- `lib/1_ceo/notifications/models/notification_ceo.dart`
- `lib/1_ceo/notifications/services/notification_ceo_service.dart`
- `lib/1_ceo/notifications/notifications_ceo_page.dart` — date grouping, filter chips, per-type icons, unread accent bar
- Bell icon in `lib/1_ceo/tableau_de_bord/tableau_de_bord.dart` AppBar — live unread count badge, navigates to notifications page, refreshes count on return.

### Backend files
- `backend_new/notifications/models.py` — `Notification` model (UUID PK, destinataire FK, type, titre, message, echantillon FK SET_NULL, section, is_read, date_creation)
- `backend_new/notifications/signals.py`
- `backend_new/notifications/views.py` — list, mark-one-read, mark-all-read, unread-count
- `backend_new/notifications/urls.py` — mounted at `api/notifications/`
