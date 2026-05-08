# Phase 6 Step 10 — French Batch 4a — Bank Accounts & Withdrawal Account Setup

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 4a of 9 (the original Batch 4 was split into 4a + 4b for safer review)
> **Scope:** Bank account management & withdrawal account setup — 35 keys
> **Predecessor:** `phase6-step10-fr-batch-3-complete` @ `17674209`
> **Branch name to create:** `phase6-step10-fr-batch-4a`
> **Tag to apply after merge:** `phase6-step10-fr-batch-4a-complete`

---

## 1. Scope

This batch translates 35 keys covering the bank account management and withdrawal account setup surfaces:

- Bank picker — select a bank from the list (3 keys)
- Linked banks/accounts — display of saved bank accounts (4 keys)
- Add bank account flow — form fields, action buttons (3 keys)
- Bank account form — name, holder name, account number entry (8 keys)
- Account verification — verify account ownership before saving (5 keys, including 2 ICU)
- Generate dedicated account — virtual account number generation (3 keys)
- Remove bank account — confirmation dialog (3 keys)
- Empty state — when user has no bank accounts (2 keys)
- Bank account validation errors (4 keys)

**Out of scope for this batch:**
- Wallet display, balance, add-money/withdraw flows, mobile money, MTN MoMo, Paystack, exchange rates, currency formatters, virtual account body → Batch 4b
- Send/receive flows → Batch 5
- Transactions → Batch 6
- Profile/settings/currency selector → Batch 7
- Generic UI → Batch 8

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
test -f docs/PHASE_6_STEP_10_FR_BATCH_4A_BANK_ACCOUNTS.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-3-complete|phase6-step10-fr-batch-4a-complete"
```

Expected:
- `phase6-step10-fr-batch-3-complete` MUST be present
- `phase6-step10-fr-batch-4a-complete` MUST NOT be present

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
print(f"FR currently filled: {filled} keys (expected 235 = 1 itemCount + 90 + 92 + 52 from Batches 1-3)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 235 keys (expected 235 = 1 itemCount + 90 + 92 + 52 from Batches 1-3)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-4a
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_4a.py`, run, then verify and commit.

### 3.1 Translation data

The 35 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Bank picker (3 keys) ---
    "selectBank": "Sélectionner une banque",
    "selectBankLabel": "Sélectionner une banque",
    "selectABankHint": "Sélectionnez une banque",

    # --- Linked banks/accounts display (4 keys) ---
    "linkedBanks": "Banques liées",
    "linkedAccounts": "Comptes liés",
    "linkedBankAccountsTitle": "Comptes bancaires liés",
    "bankAccountFallback": "Compte bancaire",

    # --- Add bank account flow (3 keys) ---
    "addBankAccountAction": "Ajouter un compte bancaire",
    "addNewBank": "Ajouter une nouvelle banque",
    "linkBank": "Lier une banque",

    # --- Bank account form fields (8 keys) ---
    "bankName": "Nom de la banque",
    "bankNameLabel": "Nom de la banque",
    "bankNameHint": "ex. GCB Bank",
    "accountName": "Nom du titulaire",
    "accountNameLabel": "Nom du titulaire",
    "accountNumber": "Numéro de compte",
    "accountNumberLabel": "Numéro de compte",
    "nameOnAccountHint": "Nom sur le compte",

    # --- Account verification (5 keys, 2 ICU) ---
    "enterAccountHolderNameHint": "Saisissez le nom du titulaire",
    "enterAccountNumberHint": "Saisissez le numéro de compte",
    "accountVerifiedLabel": "Compte vérifié",
    "couldNotVerifyAccountError": "Impossible de vérifier le compte",
    "enterAtLeastDigitsToVerify": "Saisissez au moins {count} chiffres pour vérifier",

    # --- Generate dedicated account (3 keys) ---
    "generateAccountButton": "Générer le compte",
    "loadingAccountDetails": "Chargement des détails du compte...",
    "tapToGenerateAccountPrompt": "Appuyez pour générer votre numéro de compte dédié",

    # --- Remove bank account confirmation (3 keys) ---
    "removeAccountConfirmTitle": "Supprimer le compte ?",
    "removeAccountConfirmBody": "Êtes-vous sûr de vouloir supprimer ce compte bancaire ?",
    "accountRemovedToast": "Compte supprimé",

    # --- Empty state (2 keys) ---
    "noBankAccountsEmptyTitle": "Aucun compte bancaire",
    "noBankAccountsEmptySubtitle": "Ajoutez un compte bancaire pour faciliter les retraits",

    # --- Bank account validation errors (4 keys) ---
    "walletUiErrorAccountNumberTooShort": "Le numéro de compte doit comporter au moins {minDigits} chiffres",
    "walletUiErrorPleaseEnterAccountName": "Veuillez saisir le nom du titulaire",
    "walletUiErrorPleaseSelectBank": "Veuillez sélectionner une banque",
    "walletUiErrorPleaseVerifyAccount": "Veuillez d'abord vérifier votre compte",
}

assert len(TRANSLATIONS) == 35, f"Spec dict has {len(TRANSLATIONS)} entries, expected 35"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_4a.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 4a - Bank Accounts & Withdrawal Account Setup
Applies 35 French translations to lib/l10n/app_fr.arb.
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
    assert len(TRANSLATIONS) == 35, f"Expected 35 translations, got {len(TRANSLATIONS)}"

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
    assert "{count}" in fr["enterAtLeastDigitsToVerify"], \
        "enterAtLeastDigitsToVerify lost {count}"
    assert "{minDigits}" in fr["walletUiErrorAccountNumberTooShort"], \
        "walletUiErrorAccountNumberTooShort lost {minDigits}"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 235, expected {235 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_4a.py
```

Expected output (approximately):
```
OK — applied 35 translations
FR filled: 270/701 (was 235, expected 270)
FR empty: 431
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
- FR filled: 270

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
    "selectBank": "Sélectionner une banque",
    "linkedBankAccountsTitle": "Comptes bancaires liés",
    "addBankAccountAction": "Ajouter un compte bancaire",
    "bankNameHint": "ex. GCB Bank",
    "accountName": "Nom du titulaire",
    "accountNumber": "Numéro de compte",
    "enterAtLeastDigitsToVerify": "Saisissez au moins {count} chiffres pour vérifier",
    "couldNotVerifyAccountError": "Impossible de vérifier le compte",
    "tapToGenerateAccountPrompt": "Appuyez pour générer votre numéro de compte dédié",
    "removeAccountConfirmBody": "Êtes-vous sûr de vouloir supprimer ce compte bancaire ?",
    "noBankAccountsEmptySubtitle": "Ajoutez un compte bancaire pour faciliter les retraits",
    "walletUiErrorAccountNumberTooShort": "Le numéro de compte doit comporter au moins {minDigits} chiffres",
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
10.fr-batch-4a: French translations for bank accounts & withdrawal setup (35 keys)

Translates 35 keys covering bank account management and withdrawal
account setup surfaces:
- Bank picker (3 keys) — select bank from list
- Linked banks/accounts display (4 keys)
- Add bank account flow (3 keys)
- Bank account form fields (8 keys)
- Account verification (5 keys, 2 ICU)
- Generate dedicated account (3 keys)
- Remove bank account confirmation (3 keys)
- Empty state (2 keys)
- Bank account validation errors (4 keys)

ICU placeholders preserved (verified by apply-script assertions):
  enterAtLeastDigitsToVerify: {count}
  walletUiErrorAccountNumberTooShort: {minDigits}

Convention notes:
- "Compte bancaire" for bank account
- "Banque" for bank
- "Nom du titulaire" for account holder name (banking standard, more
  precise than literal "Nom du compte")
- "Numéro de compte" for account number
- "Lier" for "link" (a bank to user account)
- "Vérifier" / "vérifié" for verify / verified (per Batch 2 convention)
- "ex." for "e.g." in hint placeholders
- Bank brand names stay as-is (GCB Bank, etc.)

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_4A_BANK_ACCOUNTS.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-4a
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-4a-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-4a`
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
   git checkout phase6-step10-fr-batch-4a
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

   Expected: 204 analyzer issues (baseline), build green. If analyzer count goes up, STOP — likely an ICU placeholder mismatch.

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
   git merge --ff-only phase6-step10-fr-batch-4a
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-4a-complete
   git push origin main
   git push origin phase6-step10-fr-batch-4a-complete
   git push origin :phase6-step10-fr-batch-4a
   git branch -d phase6-step10-fr-batch-4a
   ```

---

## 10. Translation conventions (extension to Batches 1-3)

These conventions apply to ALL French batches in Step 10, with banking-specific additions for Batch 4a.

| Convention | Decision |
|---|---|
| (Batch 1) Register | Formal (vous, not tu) |
| (Batch 1) Brand names | Stay in English |
| (Batch 1) Punctuation | French typography (space before ! ? : ;) |
| (Batch 2) Verify (verb) | "vérifier" |
| (Batch 2) Verification (noun) | "vérification" |
| **NEW (Batch 4a)** Bank | "banque" |
| **NEW (Batch 4a)** Bank account | "compte bancaire" |
| **NEW (Batch 4a)** Account (financial) | "compte" |
| **NEW (Batch 4a)** Account holder name | "Nom du titulaire" (banking standard) |
| **NEW (Batch 4a)** Account number | "numéro de compte" |
| **NEW (Batch 4a)** Linked (bank account) | "lié" / "liée" |
| **NEW (Batch 4a)** Link (verb, action) | "lier" |
| **NEW (Batch 4a)** Add (an account) | "ajouter" |
| **NEW (Batch 4a)** Remove (delete) | "supprimer" |
| **NEW (Batch 4a)** Generate (create dedicated) | "générer" |
| **NEW (Batch 4a)** Tap (action verb) | "appuyer" |
| **NEW (Batch 4a)** Dedicated (account) | "dédié" / "dédiée" |
| **NEW (Batch 4a)** Withdrawal | "retrait" (noun), "retirer" (verb) |
| **NEW (Batch 4a)** "e.g." in hints | "ex." |
| **NEW (Batch 4a)** "Are you sure you want to..." | "Êtes-vous sûr de vouloir..." |
| **NEW (Batch 4a)** "Please first..." | "Veuillez d'abord..." |
