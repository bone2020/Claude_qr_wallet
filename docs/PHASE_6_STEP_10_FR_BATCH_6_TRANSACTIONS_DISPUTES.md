# Phase 6 Step 10 — French Batch 6 — Transactions & Disputes

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 6 of 9
> **Scope:** Transactions list, transaction details, disputes — 39 keys
> **Predecessor:** `phase6-step10-fr-batch-5-complete` @ `8773641c`
> **Branch name to create:** `phase6-step10-fr-batch-6`
> **Tag to apply after merge:** `phase6-step10-fr-batch-6-complete`

---

## 1. Scope

This batch translates 39 keys covering the transactions list, transaction details, and dispute screens:

- Transaction list (8 keys) — screen title, recent transactions, empty state, "View All", "Load More", "All" filter
- Transaction status labels (5 keys) — pending/completed/failed, generic + transaction-specific variants
- Transaction direction (2 keys) — sent / received
- Transaction details (10 keys) — title, ID, items label, PIN label, not-found, date/time/status/from/to
- "How it works" info section (1 key)
- Disputes (13 keys, 2 ICU) — my disputes, active/resolved tabs with count, filed-by-me/against-me filters, empty states, dispute not found, capping notice, Review button, Report Issue

**Out of scope for this batch:**
- Transaction error resolvers (`transactionError*` — 10 keys) → already done in Batch 5 (used in send context)
- Transaction fee → already done in Batch 5
- Transaction Alerts notification setting (`transactionAlertsLabel`, `transactionAlertsSubtitle`) → Batch 7
- Notifications screen (`notifications`, `noNotifications`, `markAllAsRead`, `youreAllCaughtUp`, `failedToLoadNotifications`) → Batch 7
- Account block/unblock surfaces → Batch 7

**Files this batch modifies:** `lib/l10n/app_fr.arb` only.

---

## 2. Pre-work checks

Before any modification, the agent runs these checks. If any fail, **STOP and report — do not improvise.**

### 2.1 Sync to predecessor

```bash
cd ~/Development/Projects/qr_wallet || exit 1
git fetch origin
git checkout main
git pull
```

### 2.2 Confirm spec doc is committed to main

```bash
test -f docs/PHASE_6_STEP_10_FR_BATCH_6_TRANSACTIONS_DISPUTES.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-5-complete|phase6-step10-fr-batch-6-complete"
```

Expected:
- `phase6-step10-fr-batch-5-complete` MUST be present
- `phase6-step10-fr-batch-6-complete` MUST NOT be present

### 2.4 Confirm app_fr.arb baseline state

```bash
python3 << 'PYEOF'
import json
fr = json.load(open('lib/l10n/app_fr.arb'))
en = json.load(open('lib/l10n/app_en.arb'))

fr_keys = {k for k in fr if not k.startswith('@')}
en_keys = {k for k in en if not k.startswith('@')}

assert len(fr_keys) == 701, f"FR has {len(fr_keys)} keys, expected 701"
assert fr_keys == en_keys, f"FR/EN key sets differ"

filled = sum(1 for k in fr_keys if fr[k] != '')
print(f"FR currently filled: {filled} keys (expected 430 = 1 itemCount + 90 + 92 + 52 + 35 + 73 + 87 from Batches 1-5)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 430 keys (expected 430 = 1 itemCount + 90 + 92 + 52 + 35 + 73 + 87 from Batches 1-5)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-6
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_6.py`, run, then verify and commit.

### 3.1 Translation data

The 39 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Transaction list (8 keys) ---
    "transactions": "Transactions",
    "transactionsSection": "Transactions",
    "recentTransactions": "Transactions récentes",
    "noTransactions": "Aucune transaction pour l'instant",
    "noTransactionsSubtitle": "Votre historique de transactions apparaîtra ici",
    "allTransactions": "Toutes",
    "viewAll": "Voir tout",
    "loadMore": "Charger plus",

    # --- Transaction status (5 keys) ---
    "pending": "En attente",
    "completed": "Terminée",
    "failed": "Échouée",
    "transactionStatusFailed": "Échouée",
    "transactionStatusPending": "En attente",

    # --- Transaction direction (2 keys) ---
    "sent": "Envoyée",
    "received": "Reçue",

    # --- Transaction details (10 keys) ---
    "transactionDetails": "Détails de la transaction",
    "transactionId": "ID de transaction",
    "transactionItemsLabel": "Articles",
    "transactionPin": "Code PIN de transaction",
    "transactionNotFound": "Transaction introuvable",
    "date": "Date",
    "time": "Heure",
    "status": "Statut",
    "from": "De",
    "to": "À",

    # --- How it works (1 key) ---
    "howItWorksLabel": "Comment ça marche",

    # --- Disputes (13 keys, 2 ICU) ---
    "myDisputes": "Mes litiges",
    "myDisputesTitle": "Mes litiges",
    "activeTabWithCount": "Actifs ({count})",
    "resolvedTabWithCount": "Résolus ({count})",
    "filedByMeTab": "Déposés par moi",
    "againstMeTab": "Contre moi",
    "noActiveDisputesAgainstYou": "Aucun litige actif contre vous.",
    "noActiveDisputesFiled": "Aucun litige actif déposé.",
    "noResolvedDisputes": "Aucun litige résolu.",
    "disputeNotFoundError": "Litige introuvable",
    "disputesCappedNotice": "Affichage des 50 derniers litiges. Les entrées plus anciennes peuvent ne pas apparaître.",
    "review": "Examiner",
    "reportIssue": "Signaler un problème",
}

assert len(TRANSLATIONS) == 39, f"Spec dict has {len(TRANSLATIONS)} entries, expected 39"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_6.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 6 - Transactions & Disputes
Applies 39 French translations to lib/l10n/app_fr.arb.
Modifies ONLY app_fr.arb. Does not touch app_en.arb or app_ar.arb.
"""

import json
from pathlib import Path

ARB_PATH = Path("lib/l10n/app_fr.arb")
EN_PATH = Path("lib/l10n/app_en.arb")

TRANSLATIONS = {
    # PASTE THE FULL DICT FROM SECTION 3.1 ABOVE HERE.
    # The agent should copy the dict literal verbatim from the spec.
}

def main():
    # Sanity: dict size
    assert len(TRANSLATIONS) == 39, f"Expected 39 translations, got {len(TRANSLATIONS)}"

    # Load files
    fr = json.loads(ARB_PATH.read_text(encoding="utf-8"))
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))

    # Verify baseline: every spec key exists in both en and fr
    missing_in_en = [k for k in TRANSLATIONS if k not in en]
    missing_in_fr = [k for k in TRANSLATIONS if k not in fr]
    assert not missing_in_en, f"Spec keys missing in en: {missing_in_en}"
    assert not missing_in_fr, f"Spec keys missing in fr: {missing_in_fr}"

    # Verify baseline: every spec key is currently empty in fr
    not_empty = [k for k in TRANSLATIONS if fr[k] != ""]
    assert not not_empty, f"Spec keys already have non-empty values in fr: {not_empty}"

    # Apply translations
    for key, value in TRANSLATIONS.items():
        fr[key] = value

    # Verify: each spec key now has its spec value
    for key, expected in TRANSLATIONS.items():
        assert fr[key] == expected, f"Mismatch on {key}: got {fr[key]!r}, expected {expected!r}"

    # Verify: total key count unchanged
    fr_keys = {k for k in fr if not k.startswith('@')}
    en_keys = {k for k in en if not k.startswith('@')}
    assert len(fr_keys) == 701, f"FR has {len(fr_keys)} keys after apply, expected 701"
    assert fr_keys == en_keys, "FR/EN key sets diverged"

    # Verify: ICU placeholder preservation for the 2 ICU keys in this batch
    assert "{count}" in fr["activeTabWithCount"], "activeTabWithCount lost {count}"
    assert "{count}" in fr["resolvedTabWithCount"], "resolvedTabWithCount lost {count}"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 430, expected {430 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_6.py
```

Expected output (approximately):
```
OK — applied 39 translations
FR filled: 469/701 (was 430, expected 469)
FR empty: 232
```

If any assertion fires, STOP and report.

---

## 4. Verification

After the script runs:

### 4.1 Confirm only app_fr.arb changed

```bash
git status
```

Expected: only `modified: lib/l10n/app_fr.arb`. The PHASE_*.py untracked stragglers are normal and remain untracked.

### 4.2 Confirm key parity en/fr

```bash
python3 << 'PYEOF'
import json
en = json.load(open('lib/l10n/app_en.arb'))
fr = json.load(open('lib/l10n/app_fr.arb'))
en_keys = {k for k in en if not k.startswith('@')}
fr_keys = {k for k in fr if not k.startswith('@')}
print(f"EN keys: {len(en_keys)}")
print(f"FR keys: {len(fr_keys)}")
print(f"Match: {en_keys == fr_keys}")
print(f"FR filled: {sum(1 for k in fr_keys if fr[k] != '')}")
PYEOF
```

Expected:
- EN keys: 701
- FR keys: 701
- Match: True
- FR filled: 469

### 4.3 Confirm ar and en files untouched

```bash
git diff --stat lib/l10n/app_ar.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty output for both.

### 4.4 Confirm spec keys hold spec values + ICU preservation

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "transactions": "Transactions",
    "recentTransactions": "Transactions récentes",
    "noTransactions": "Aucune transaction pour l'instant",
    "viewAll": "Voir tout",
    "completed": "Terminée",
    "failed": "Échouée",
    "sent": "Envoyée",
    "received": "Reçue",
    "transactionDetails": "Détails de la transaction",
    "transactionPin": "Code PIN de transaction",
    "from": "De",
    "to": "À",
    "howItWorksLabel": "Comment ça marche",
    "myDisputes": "Mes litiges",
    "activeTabWithCount": "Actifs ({count})",
    "resolvedTabWithCount": "Résolus ({count})",
    "filedByMeTab": "Déposés par moi",
    "disputesCappedNotice": "Affichage des 50 derniers litiges. Les entrées plus anciennes peuvent ne pas apparaître.",
    "reportIssue": "Signaler un problème",
}

fr = json.load(open('lib/l10n/app_fr.arb'))
all_ok = True
for k, expected in SPOT_CHECK.items():
    actual = fr.get(k, "<MISSING>")
    if actual != expected:
        print(f"FAIL {k}: got {actual!r}, expected {expected!r}")
        all_ok = False
    else:
        print(f"OK   {k}")

print()
print(f"OVERALL: {'PASS' if all_ok else 'FAIL'}")
PYEOF
```

Expected: all `OK`, `OVERALL: PASS`.

---

## 5. Commit

```bash
git status
git diff --stat lib/l10n/app_fr.arb
```

Stage **only** the modified ARB file:

```bash
git add lib/l10n/app_fr.arb
git status
```

Confirm staged files are exactly:
- `lib/l10n/app_fr.arb`

Nothing else. If `lib/generated/l10n/` shows up in staging, UNSTAGE IT. If any `.py` file at the repo root shows up, UNSTAGE IT.

Commit with the message in `/tmp/commit_msg.txt`:

```bash
cat > /tmp/commit_msg.txt << 'EOF'
10.fr-batch-6: French translations for Transactions & Disputes (39 keys)

Translates 39 keys covering transactions list, transaction details, and
dispute screens:
- Transaction list (8 keys) — screen title, recent transactions, empty
  state, "View All", "Load More", "All" filter
- Transaction status labels (5 keys) — pending/completed/failed, generic
  + transaction-specific variants
- Transaction direction (2 keys) — sent / received
- Transaction details (10 keys) — title, ID, items label, PIN label,
  not-found, date/time/status/from/to
- "How it works" info section (1 key)
- Disputes (13 keys, 2 ICU) — my disputes, active/resolved tabs with
  count, filed-by-me / against-me filters, empty states, dispute not
  found, capping notice, Review button, Report Issue

ICU placeholders preserved (verified by apply-script assertions):
  activeTabWithCount: {count}
  resolvedTabWithCount: {count}

Convention notes:
- "Litige" for "dispute" (banking standard French — vs "réclamation"
  which means general complaint, or "contestation" which is more legal)
- Past participle agreement on status labels uses feminine to agree with
  implicit "transaction" (feminine): "Terminée", "Échouée", "Envoyée",
  "Reçue"
- Plural masculine agreement for disputes (masculine "litiges"):
  "Actifs", "Résolus", "Déposés"
- "Comment ça marche" for "How it works" (conversational, common in
  French apps)
- "Voir tout" for "View All", "Charger plus" for "Load More"
- "Signaler un problème" for "Report Issue"
- "ID de transaction" for "Transaction ID" (matches "ID du portefeuille"
  pattern from Batch 4b)
- "Code PIN de transaction" for "Transaction PIN" (matches "code PIN"
  convention from Batch 1)
- "{X} introuvable" for "{X} not found" (matches Batch 5 pattern)

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_6_TRANSACTIONS_DISPUTES.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-6
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-6-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-6`
2. **Final commit SHA** (from `git rev-parse HEAD`)
3. **Output of all verification steps** (Sections 4.1, 4.2, 4.3, 4.4)
4. **Output of the apply script** (Section 3.2 run command)
5. **`git diff --stat HEAD~1 HEAD`** to confirm only `lib/l10n/app_fr.arb` was touched
6. **Confirm `lib/generated/l10n/` was NOT staged or committed**
7. **Confirm no `.py` file at repo root was staged or committed**
8. **Any deviations from this spec** with reasoning

---

## 8. STOP and report (do NOT improvise) if:

- Any pre-work check (Section 2) fails
- Any assertion in the apply script (Section 3.2) fires
- Any verification check (Section 4) fails
- Reality contradicts spec literal text in non-trivial ways
- The spec dict turns out to have wrong key count, missing keys, or duplicate keys

---

## 9. After agent reports back — operator's tasks

1. Pull the branch locally:
   ```bash
   git fetch origin
   git checkout phase6-step10-fr-batch-6
   git pull
   ```

2. Run gen-l10n to regenerate the language classes:
   ```bash
   flutter gen-l10n
   ```

3. Confirm gen-l10n only modified `lib/generated/l10n/` files (not the source ARB):
   ```bash
   git diff --stat
   ```

   Expected: only `lib/generated/l10n/app_localizations_fr.dart` (and possibly `app_localizations.dart`) shows changes.

4. **Per established workflow:** generated files are NOT committed. Do NOT `git add` anything under `lib/generated/l10n/`.

5. Run analyzer + build:
   ```bash
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```

   Expected: 204 analyzer issues (baseline), build green.

6. Run sync guard:
   ```bash
   git fetch origin
   local_main=$(git rev-parse main)
   origin_main=$(git rev-parse origin/main)
   if [ "$local_main" != "$origin_main" ]; then
     echo "FAIL — sync local main with origin/main before merging"
     exit 1
   fi
   echo "PASS — synced at $local_main"
   ```

7. Discard the gen-l10n changes:
   ```bash
   git checkout -- lib/generated/l10n/
   ```

8. Merge with `--ff-only`:
   ```bash
   git checkout main
   git merge --ff-only phase6-step10-fr-batch-6
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-6-complete
   git push origin main
   git push origin phase6-step10-fr-batch-6-complete
   git push origin :phase6-step10-fr-batch-6
   git branch -d phase6-step10-fr-batch-6
   ```

---

## 10. Translation conventions (extension to Batches 1-5)

These conventions apply to ALL French batches in Step 10, with transaction/dispute-specific additions for Batch 6.

| Convention | Decision |
|---|---|
| (Batches 1-5) Register | Formal (vous, not tu) |
| (Batches 1-5) Brand names | Stay in English |
| (Batches 1-5) Punctuation | French typography (space before ! ? : ;) |
| **NEW (Batch 6)** Dispute | "litige" (m.) — banking standard |
| **NEW (Batch 6)** Disputes (plural) | "litiges" |
| **NEW (Batch 6)** Pending (status) | "En attente" |
| **NEW (Batch 6)** Completed (status, transaction context) | "Terminée" (feminine — agrees with "transaction") |
| **NEW (Batch 6)** Failed (status, transaction context) | "Échouée" (feminine) |
| **NEW (Batch 6)** Sent (transaction direction) | "Envoyée" (feminine) |
| **NEW (Batch 6)** Received (transaction direction) | "Reçue" (feminine) |
| **NEW (Batch 6)** Transaction details | "Détails de la transaction" |
| **NEW (Batch 6)** Transaction ID | "ID de transaction" |
| **NEW (Batch 6)** Transaction PIN | "Code PIN de transaction" |
| **NEW (Batch 6)** Date / Time / Status | "Date" / "Heure" / "Statut" |
| **NEW (Batch 6)** From / To | "De" / "À" |
| **NEW (Batch 6)** Recent (transactions) | "récentes" (feminine plural) |
| **NEW (Batch 6)** All (filter, transactions) | "Toutes" (feminine plural) |
| **NEW (Batch 6)** View All | "Voir tout" |
| **NEW (Batch 6)** Load More | "Charger plus" |
| **NEW (Batch 6)** Active (disputes) | "Actifs" (masculine plural) |
| **NEW (Batch 6)** Resolved (disputes) | "Résolus" (masculine plural) |
| **NEW (Batch 6)** Filed by me | "Déposés par moi" |
| **NEW (Batch 6)** Against me | "Contre moi" |
| **NEW (Batch 6)** Review (button) | "Examiner" |
| **NEW (Batch 6)** Report Issue | "Signaler un problème" |
| **NEW (Batch 6)** "How it works" | "Comment ça marche" |
| **NEW (Batch 6)** "{X} not found" | "{X} introuvable" (continues Batch 5 pattern) |
