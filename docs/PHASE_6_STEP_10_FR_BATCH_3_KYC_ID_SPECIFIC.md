# Phase 6 Step 10 — French Batch 3 — KYC ID-Specific Screens

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 3 of 8
> **Scope:** Country/ID-specific KYC screens — 52 keys
> **Predecessor:** `phase6-step10-fr-batch-2-complete` @ `9301a174`
> **Branch name to create:** `phase6-step10-fr-batch-3`
> **Tag to apply after merge:** `phase6-step10-fr-batch-3-complete`

---

## 1. Scope

This batch translates 52 keys covering the country-specific and ID-specific KYC verification screens that ride on the KYC core machinery from Batch 2:

- NIN — Nigerian National Identification Number (5 keys)
- BVN — Nigerian Bank Verification Number (5 keys)
- SSNIT — Ghana social security number (5 keys)
- Driver's License (3 keys)
- Passport (3 keys)
- Voter's Card (3 keys)
- National ID (3 keys, including 1 ICU)
- Uganda NIN — Uganda's NIN flow with card number (8 keys)
- TPIN — Zambian Taxpayer PIN (4 keys)
- Verify-X entry buttons (7 keys)
- Country-specific labels (6 keys) — Alien ID, International Passport, South African ID, Zambian Taxpayer

**Out of scope for this batch:**
- KYC core flow (the verification machinery itself) → already done in Batch 2
- Wallet flows → Batch 4
- Send/receive → Batch 5
- Transactions → Batch 6
- Profile/settings → Batch 7
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
test -f docs/PHASE_6_STEP_10_FR_BATCH_3_KYC_ID_SPECIFIC.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-2-complete|phase6-step10-fr-batch-3-complete"
```

Expected:
- `phase6-step10-fr-batch-2-complete` MUST be present
- `phase6-step10-fr-batch-3-complete` MUST NOT be present

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
print(f"FR currently filled: {filled} keys (expected 183 = 1 itemCount + 90 from Batch 1 + 92 from Batch 2)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 183 keys (expected 183 = 1 itemCount + 90 from Batch 1 + 92 from Batch 2)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-3
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_3.py`, run, then verify and commit.

### 3.1 Translation data

The 52 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters, em-dashes) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- NIN — Nigerian National Identification Number (5 keys) ---
    "ninDescription": "Numéro d'identification national (11 chiffres)",
    "ninFullLabel": "Numéro d'identification national (NIN)",
    "ninHelperText": "Votre numéro d'identification national tel qu'indiqué sur votre fiche NIN",
    "ninLengthError": "Le NIN doit comporter exactement 11 chiffres",
    "ninVerificationTitle": "Vérification du NIN",

    # --- BVN — Nigerian Bank Verification Number (5 keys) ---
    "bvnDescription": "Numéro de vérification bancaire (11 chiffres)",
    "bvnFullLabel": "Numéro de vérification bancaire (BVN)",
    "bvnHelperText": "Votre numéro de vérification bancaire lié à vos comptes bancaires",
    "bvnLengthError": "Le BVN doit comporter exactement 11 chiffres",
    "bvnVerificationTitle": "Vérification du BVN",

    # --- SSNIT — Ghana social security (5 keys) ---
    "ssnitDescription": "Numéro SSNIT (1 lettre + 12 chiffres)",
    "ssnitFormatError": "Le SSNIT doit comporter 1 lettre suivie de 12 chiffres",
    "ssnitHelperText": "Votre numéro SSNIT : 1 lettre suivie de 12 chiffres",
    "ssnitLabel": "SSNIT",
    "ssnitVerificationTitle": "Vérification du SSNIT",

    # --- Driver's License (3 keys) ---
    "driversLicense": "Permis de conduire",
    "driversLicenseDescription": "Vérification du permis de conduire",
    "driversLicenseVerificationTitle": "Vérification du permis de conduire",

    # --- Passport (3 keys) ---
    "passport": "Passeport",
    "passportDescription": "Vérification du passeport international",
    "passportVerificationTitle": "Vérification du passeport",

    # --- Voter's Card (3 keys) ---
    "votersCardDescription": "Vérification de la carte d'électeur",
    "votersCardVerificationTitle": "Vérification de la carte d'électeur",
    "votersIdLabel": "Carte d'électeur",

    # --- National ID (3 keys, 1 ICU) ---
    "nationalId": "Carte nationale d'identité",
    "nationalIdDescription": "Vérification de la carte nationale d'identité",
    "nationalIdVerificationTitleWithCountry": "Vérification — {countryName}",

    # --- Uganda NIN flow (8 keys) ---
    "ugandaNationalIdAppBarTitle": "Carte nationale d'identité ougandaise",
    "ugandaNationalIdDescription": "Vérifiez votre identité avec votre numéro d'identification national ougandais (NIN) et votre numéro de carte.",
    "ugandaNationalIdHeading": "Vérification de la carte nationale d'identité",
    "ugandaNationalIdLabel": "Carte nationale d'identité (NIN)",
    "ugandaNinCardNumberHelperText": "Le numéro imprimé sur votre carte d'identité physique",
    "ugandaNinDescription": "Vérifiez votre identité avec votre numéro d'identification national ougandais",
    "ugandaNinFormatError": "Le NIN ougandais doit comporter exactement 14 caractères alphanumériques",
    "ugandaNinHelperText": "Votre NIN comporte 14 caractères alphanumériques",

    # --- TPIN — Zambian Taxpayer PIN (4 keys) ---
    "tpinDescription": "Vérifiez votre identité avec votre PIN du contribuable zambien",
    "tpinFullLabel": "PIN du contribuable (TPIN)",
    "tpinLabel": "TPIN",
    "tpinLengthError": "Le TPIN doit comporter exactement 10 chiffres",

    # --- Verify-X entry buttons (7 keys) ---
    "verifyBvn": "Vérifier le BVN",
    "verifyDriversLicense": "Vérifier le permis de conduire",
    "verifyNationalId": "Vérifier la carte d'identité nationale",
    "verifyNin": "Vérifier le NIN",
    "verifyPassport": "Vérifier le passeport",
    "verifySsnit": "Vérifier le SSNIT",
    "verifyVotersCard": "Vérifier la carte d'électeur",

    # --- Country-specific labels (6 keys) ---
    "alienIdLabel": "Carte d'étranger",
    "internationalPassportLabel": "Passeport international",
    "southAfricanIdHelperText": "Votre numéro de carte d'identité sud-africaine",
    "southAfricanIdLengthError": "La carte d'identité sud-africaine doit comporter exactement 13 chiffres",
    "taxpayerPinLabel": "PIN du contribuable (TPIN)",
    "zambianTaxpayerHelperText": "Votre numéro d'identification fiscale zambien",
}

assert len(TRANSLATIONS) == 52, f"Spec dict has {len(TRANSLATIONS)} entries, expected 52"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_3.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 3 - KYC ID-Specific Screens
Applies 52 French translations to lib/l10n/app_fr.arb.
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
    assert len(TRANSLATIONS) == 52, f"Expected 52 translations, got {len(TRANSLATIONS)}"

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

    # Verify: ICU placeholder preservation for the 1 ICU key in this batch
    assert "{countryName}" in fr["nationalIdVerificationTitleWithCountry"], \
        "nationalIdVerificationTitleWithCountry lost {countryName}"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 183, expected {183 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_3.py
```

Expected output (approximately):
```
OK — applied 52 translations
FR filled: 235/701 (was 183, expected 235)
FR empty: 466
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
- FR filled: 235

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
    "ninFullLabel": "Numéro d'identification national (NIN)",
    "bvnVerificationTitle": "Vérification du BVN",
    "ssnitFormatError": "Le SSNIT doit comporter 1 lettre suivie de 12 chiffres",
    "driversLicense": "Permis de conduire",
    "passport": "Passeport",
    "votersIdLabel": "Carte d'électeur",
    "nationalIdVerificationTitleWithCountry": "Vérification — {countryName}",
    "ugandaNinFormatError": "Le NIN ougandais doit comporter exactement 14 caractères alphanumériques",
    "tpinFullLabel": "PIN du contribuable (TPIN)",
    "verifyBvn": "Vérifier le BVN",
    "alienIdLabel": "Carte d'étranger",
    "zambianTaxpayerHelperText": "Votre numéro d'identification fiscale zambien",
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
10.fr-batch-3: French translations for KYC ID-specific screens (52 keys)

Translates 52 keys covering country/ID-specific KYC verification screens:
- NIN — Nigerian National Identification Number (5 keys)
- BVN — Nigerian Bank Verification Number (5 keys)
- SSNIT — Ghana social security number (5 keys)
- Driver's License (3 keys)
- Passport (3 keys)
- Voter's Card (3 keys)
- National ID (3 keys, including 1 ICU)
- Uganda NIN flow with card number (8 keys)
- TPIN — Zambian Taxpayer PIN (4 keys)
- Verify-X entry buttons (7 keys)
- Country-specific labels (6 keys) — Alien ID, International Passport,
  South African ID, Zambian Taxpayer

ICU placeholders preserved (verified by apply-script assertion):
  nationalIdVerificationTitleWithCountry: {countryName}

Convention notes:
- Acronyms BVN, NIN, SSNIT, TPIN kept as-is (recognized in francophone
  fintech), all masculine ("le BVN", "le NIN", etc.)
- "Carte nationale d'identité" for National ID
- "Permis de conduire" for Driver's License
- "Carte d'électeur" for Voter's Card / Voter's ID
- "Carte d'étranger" for Alien ID (Ghana non-citizen residency)
- "PIN du contribuable" for Taxpayer PIN
- "Vérification — {countryName}" with em-dash for the country-prefixed
  verification title (avoids ungrammatical "Country Verification" pattern
  in French)

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_3_KYC_ID_SPECIFIC.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-3
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-3-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-3`
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
   git checkout phase6-step10-fr-batch-3
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
   git merge --ff-only phase6-step10-fr-batch-3
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-3-complete
   git push origin main
   git push origin phase6-step10-fr-batch-3-complete
   git push origin :phase6-step10-fr-batch-3
   git branch -d phase6-step10-fr-batch-3
   ```

---

## 10. Translation conventions (extension to Batches 1 & 2)

These conventions apply to ALL French batches in Step 10, with additions for ID-specific vocabulary in Batch 3.

| Convention | Decision |
|---|---|
| (Batch 1) Register | Formal (vous, not tu) |
| (Batch 1) Brand names | Stay in English: QR Wallet, MTN MoMo, Apple, Paystack, WhatsApp, Smile ID, Face ID |
| (Batch 1) Punctuation | French typography (space before ! ? : ;) |
| (Batch 2) Verify (verb) | "vérifier" |
| (Batch 2) Verification (noun) | "vérification" |
| (Batch 2) ID document | "pièce d'identité" |
| (Batch 2) ID number | "numéro d'identification" |
| **NEW (Batch 3)** Acronyms BVN, NIN, SSNIT, TPIN | Kept as-is, all masculine ("le BVN", "le NIN") |
| **NEW (Batch 3)** National ID (the card) | "Carte nationale d'identité" |
| **NEW (Batch 3)** Government ID (general) | "Pièce d'identité officielle" (set in Batch 2) |
| **NEW (Batch 3)** Driver's License | "Permis de conduire" |
| **NEW (Batch 3)** Passport | "Passeport" |
| **NEW (Batch 3)** Voter's Card / Voter's ID | "Carte d'électeur" |
| **NEW (Batch 3)** Alien ID (Ghana non-citizen) | "Carte d'étranger" |
| **NEW (Batch 3)** International Passport | "Passeport international" |
| **NEW (Batch 3)** Taxpayer PIN (Zambia) | "PIN du contribuable" |
| **NEW (Batch 3)** Bank Verification Number | "Numéro de vérification bancaire" |
| **NEW (Batch 3)** National Identification Number | "Numéro d'identification national" |
| **NEW (Batch 3)** Country adjective: Ugandan | "ougandais" (m) / "ougandaise" (f) |
| **NEW (Batch 3)** Country adjective: South African | "sud-africain" (m) / "sud-africaine" (f) |
| **NEW (Batch 3)** Country adjective: Zambian | "zambien" (m) / "zambienne" (f) |
| **NEW (Batch 3)** Alphanumeric | "alphanumérique" (m) / "alphanumériques" (pl) |
| **NEW (Batch 3)** Country-prefixed verification title | "Vérification — {countryName}" with em-dash |
| **NEW (Batch 3)** "X must be exactly N digits" | "Le [X] doit comporter exactement N chiffres" |
