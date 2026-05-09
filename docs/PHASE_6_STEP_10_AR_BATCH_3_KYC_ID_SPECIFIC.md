# Phase 6 Step 10 — Arabic Batch 3 — KYC ID-Specific Screens

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 3 of 9
> **Scope:** KYC ID-specific verification screens — 52 keys, 1 ICU
> **Predecessor:** `phase6-step10-ar-batch-2-complete` @ `60c0cecf`
> **Branch name to create:** `phase6-step10-ar-batch-3`
> **Tag to apply after merge:** `phase6-step10-ar-batch-3-complete`

---

## 1. Scope

This batch translates 52 Arabic keys covering ID-specific KYC verification screens (mirroring the exact key set from French Batch 3):

- NIN (Nigeria National Identification Number) — 5 keys
- BVN (Bank Verification Number) — 5 keys
- SSNIT (Ghana Social Security & National Insurance Trust) — 5 keys
- Driver's License — 3 keys
- Passport — 3 keys
- Voter's Card — 3 keys
- National ID generic — 3 keys, 1 ICU at nationalIdVerificationTitleWithCountry
- Uganda National ID / NIN — 8 keys
- Zambia TPIN (Taxpayer Identification Number) — 4 keys
- Verify buttons (per-document verify CTAs) — 7 keys
- Misc labels (alien ID, international passport, South African ID, taxpayer) — 6 keys

**Out of scope for this batch:**
- Auth & onboarding → Batch 1 (shipped)
- KYC core flow (verify identity, document captured, biometric errors) → Batch 2 (shipped)
- Wallet, send, receive screens → Batch 4 / Batch 5
- Transactions and disputes → Batch 6
- Profile, FAQ, settings, security → Batch 7
- Generic UI buttons, splash, app metadata → Batch 8

**Files this batch modifies:** `lib/l10n/app_ar.arb` only.

---

## 2. Pre-work checks

### 2.1 Sync to predecessor

```bash
cd ~/Development/Projects/qr_wallet || exit 1
git fetch origin
git checkout main
git pull
```

### 2.2 Confirm spec doc is committed to main

```bash
test -f docs/PHASE_6_STEP_10_AR_BATCH_3_KYC_ID_SPECIFIC.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-2-complete|phase6-step10-ar-batch-3-complete"
```

Expected:
- `phase6-step10-ar-batch-2-complete` MUST be present
- `phase6-step10-ar-batch-3-complete` MUST NOT be present

### 2.4 Confirm app_ar.arb baseline state

```bash
python3 << 'PYEOF'
import json
ar = json.load(open('lib/l10n/app_ar.arb'))
en = json.load(open('lib/l10n/app_en.arb'))

ar_keys = {k for k in ar if not k.startswith('@')}
en_keys = {k for k in en if not k.startswith('@')}

assert len(ar_keys) == 701, f"AR has {len(ar_keys)} keys, expected 701"
assert ar_keys == en_keys, "AR/EN key sets differ"

filled = sum(1 for k in ar_keys if ar[k] != '')
print(f"AR currently filled: {filled} keys (expected 183 = 1 itemCount + 90 + 92 from Batches 1-2)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 183 keys`
- `AR total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-3
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_ar_batch_3.py`, run, then verify and commit.

### 3.1 Translation data

The 52 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Special characters (em-dash `—`, Arabic numerals/letters, Latin acronyms NIN/BVN/SSNIT/TPIN) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- NIN (Nigeria National Identification Number) — 5 keys ---
    "ninDescription": "رقم التعريف الوطني (11 رقمًا)",
    "ninFullLabel": "رقم التعريف الوطني (NIN)",
    "ninHelperText": "رقم تعريفك الوطني كما هو موضّح على بطاقة NIN الخاصة بك",
    "ninLengthError": "يجب أن يتكوّن NIN من 11 رقمًا بالضبط",
    "ninVerificationTitle": "التحقّق من NIN",

    # --- BVN (Bank Verification Number) — 5 keys ---
    "bvnDescription": "رقم التحقّق المصرفي (11 رقمًا)",
    "bvnFullLabel": "رقم التحقّق المصرفي (BVN)",
    "bvnHelperText": "رقم التحقّق المصرفي المرتبط بحساباتك المصرفية",
    "bvnLengthError": "يجب أن يتكوّن BVN من 11 رقمًا بالضبط",
    "bvnVerificationTitle": "التحقّق من BVN",

    # --- SSNIT (Ghana) — 5 keys ---
    "ssnitDescription": "رقم SSNIT (حرف واحد + 12 رقمًا)",
    "ssnitFormatError": "يجب أن يتكوّن SSNIT من حرف واحد متبوعًا بـ 12 رقمًا",
    "ssnitHelperText": "رقم SSNIT الخاص بك: حرف واحد متبوعًا بـ 12 رقمًا",
    "ssnitLabel": "SSNIT",
    "ssnitVerificationTitle": "التحقّق من SSNIT",

    # --- Driver's License — 3 keys ---
    "driversLicense": "رخصة القيادة",
    "driversLicenseDescription": "التحقّق من رخصة القيادة",
    "driversLicenseVerificationTitle": "التحقّق من رخصة القيادة",

    # --- Passport — 3 keys ---
    "passport": "جواز السفر",
    "passportDescription": "التحقّق من جواز السفر الدولي",
    "passportVerificationTitle": "التحقّق من جواز السفر",

    # --- Voter's Card — 3 keys ---
    "votersCardDescription": "التحقّق من بطاقة الناخب",
    "votersCardVerificationTitle": "التحقّق من بطاقة الناخب",
    "votersIdLabel": "بطاقة الناخب",

    # --- National ID generic — 3 keys, 1 ICU ---
    "nationalId": "بطاقة الهوية الوطنية",
    "nationalIdDescription": "التحقّق من بطاقة الهوية الوطنية",
    "nationalIdVerificationTitleWithCountry": "التحقّق — {countryName}",

    # --- Uganda National ID / NIN — 8 keys ---
    "ugandaNationalIdAppBarTitle": "بطاقة الهوية الوطنية الأوغندية",
    "ugandaNationalIdDescription": "تحقّق من هويتك باستخدام رقم التعريف الوطني الأوغندي (NIN) ورقم البطاقة.",
    "ugandaNationalIdHeading": "التحقّق من بطاقة الهوية الوطنية",
    "ugandaNationalIdLabel": "بطاقة الهوية الوطنية (NIN)",
    "ugandaNinCardNumberHelperText": "الرقم المطبوع على بطاقة هويتك الفعلية",
    "ugandaNinDescription": "تحقّق من هويتك باستخدام رقم التعريف الوطني الأوغندي",
    "ugandaNinFormatError": "يجب أن يتكوّن NIN الأوغندي من 14 حرفًا أبجديًا رقميًا بالضبط",
    "ugandaNinHelperText": "يتكوّن NIN الخاص بك من 14 حرفًا أبجديًا رقميًا",

    # --- Zambia TPIN — 4 keys ---
    "tpinDescription": "تحقّق من هويتك باستخدام رقم تعريف دافع الضرائب الزامبي",
    "tpinFullLabel": "رقم تعريف دافع الضرائب (TPIN)",
    "tpinLabel": "TPIN",
    "tpinLengthError": "يجب أن يتكوّن TPIN من 10 أرقام بالضبط",

    # --- Verify buttons — 7 keys ---
    "verifyBvn": "التحقّق من BVN",
    "verifyDriversLicense": "التحقّق من رخصة القيادة",
    "verifyNationalId": "التحقّق من بطاقة الهوية الوطنية",
    "verifyNin": "التحقّق من NIN",
    "verifyPassport": "التحقّق من جواز السفر",
    "verifySsnit": "التحقّق من SSNIT",
    "verifyVotersCard": "التحقّق من بطاقة الناخب",

    # --- Misc labels — 6 keys ---
    "alienIdLabel": "بطاقة الأجنبي",
    "internationalPassportLabel": "جواز السفر الدولي",
    "southAfricanIdHelperText": "رقم بطاقة هويتك الجنوب إفريقية",
    "southAfricanIdLengthError": "يجب أن تتكوّن بطاقة الهوية الجنوب إفريقية من 13 رقمًا بالضبط",
    "taxpayerPinLabel": "رقم تعريف دافع الضرائب (TPIN)",
    "zambianTaxpayerHelperText": "رقم تعريفك الضريبي الزامبي",
}

assert len(TRANSLATIONS) == 52, f"Spec dict has {len(TRANSLATIONS)} entries, expected 52"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_3.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 3 - KYC ID-Specific Screens
Applies 52 Arabic translations to lib/l10n/app_ar.arb.
Modifies ONLY app_ar.arb. Does not touch app_en.arb or app_fr.arb.
"""

import json
from pathlib import Path

ARB_PATH = Path("lib/l10n/app_ar.arb")
EN_PATH = Path("lib/l10n/app_en.arb")

TRANSLATIONS = {
    # PASTE THE FULL DICT FROM SECTION 3.1 ABOVE HERE.
}

def main():
    assert len(TRANSLATIONS) == 52, f"Expected 52 translations, got {len(TRANSLATIONS)}"

    ar = json.loads(ARB_PATH.read_text(encoding="utf-8"))
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))

    # Verify baseline: every spec key exists in both en and ar
    missing_in_en = [k for k in TRANSLATIONS if k not in en]
    missing_in_ar = [k for k in TRANSLATIONS if k not in ar]
    assert not missing_in_en, f"Spec keys missing in en: {missing_in_en}"
    assert not missing_in_ar, f"Spec keys missing in ar: {missing_in_ar}"

    # Verify baseline: every spec key is currently empty in ar
    not_empty = [k for k in TRANSLATIONS if ar[k] != ""]
    assert not not_empty, f"Spec keys already non-empty in ar: {not_empty}"

    # Apply translations
    for key, value in TRANSLATIONS.items():
        ar[key] = value

    # Verify: each spec key now has its spec value
    for key, expected in TRANSLATIONS.items():
        assert ar[key] == expected, f"Mismatch on {key}: got {ar[key]!r}, expected {expected!r}"

    # Verify: total key count unchanged
    ar_keys = {k for k in ar if not k.startswith('@')}
    en_keys = {k for k in en if not k.startswith('@')}
    assert len(ar_keys) == 701, f"AR has {len(ar_keys)} keys after apply, expected 701"
    assert ar_keys == en_keys, "AR/EN key sets diverged"

    # Verify: ICU placeholder preservation (1 ICU key in this batch)
    assert "{countryName}" in ar["nationalIdVerificationTitleWithCountry"], \
        "nationalIdVerificationTitleWithCountry lost {countryName}"
    assert "—" in ar["nationalIdVerificationTitleWithCountry"], \
        "nationalIdVerificationTitleWithCountry lost em-dash"

    # Verify: Latin acronyms preserved
    assert "NIN" in ar["ninFullLabel"], "ninFullLabel lost NIN"
    assert "BVN" in ar["bvnFullLabel"], "bvnFullLabel lost BVN"
    assert "SSNIT" in ar["ssnitLabel"], "ssnitLabel lost SSNIT"
    assert "TPIN" in ar["tpinFullLabel"], "tpinFullLabel lost TPIN"

    # Verify: Arabic Unicode characters present in sample keys
    for k in ["ninDescription", "passport", "driversLicense", "votersIdLabel"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 183, expected {183 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_3.py
```

Expected:
```
OK — applied 52 translations
AR filled: 235/701 (was 183, expected 235)
AR empty: 466
```

---

## 4. Verification

### 4.1 Confirm only app_ar.arb changed

```bash
git status
```

### 4.2 Confirm key parity en/ar

```bash
python3 << 'PYEOF'
import json
en = json.load(open('lib/l10n/app_en.arb'))
ar = json.load(open('lib/l10n/app_ar.arb'))
en_keys = {k for k in en if not k.startswith('@')}
ar_keys = {k for k in ar if not k.startswith('@')}
print(f"EN keys: {len(en_keys)}")
print(f"AR keys: {len(ar_keys)}")
print(f"Match: {en_keys == ar_keys}")
print(f"AR filled: {sum(1 for k in ar_keys if ar[k] != '')}")
PYEOF
```

Expected: 701, 701, True, 235.

### 4.3 Confirm fr and en files untouched

```bash
git diff --stat lib/l10n/app_fr.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty for both.

### 4.4 Spot-check + ICU preservation

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "ninFullLabel": "رقم التعريف الوطني (NIN)",
    "ninLengthError": "يجب أن يتكوّن NIN من 11 رقمًا بالضبط",
    "bvnVerificationTitle": "التحقّق من BVN",
    "ssnitFormatError": "يجب أن يتكوّن SSNIT من حرف واحد متبوعًا بـ 12 رقمًا",
    "driversLicense": "رخصة القيادة",
    "passport": "جواز السفر",
    "votersIdLabel": "بطاقة الناخب",
    "nationalId": "بطاقة الهوية الوطنية",
    "nationalIdVerificationTitleWithCountry": "التحقّق — {countryName}",
    "ugandaNationalIdAppBarTitle": "بطاقة الهوية الوطنية الأوغندية",
    "ugandaNinFormatError": "يجب أن يتكوّن NIN الأوغندي من 14 حرفًا أبجديًا رقميًا بالضبط",
    "tpinLengthError": "يجب أن يتكوّن TPIN من 10 أرقام بالضبط",
    "verifyPassport": "التحقّق من جواز السفر",
    "alienIdLabel": "بطاقة الأجنبي",
    "internationalPassportLabel": "جواز السفر الدولي",
    "southAfricanIdLengthError": "يجب أن تتكوّن بطاقة الهوية الجنوب إفريقية من 13 رقمًا بالضبط",
    "zambianTaxpayerHelperText": "رقم تعريفك الضريبي الزامبي",
}

ar = json.load(open('lib/l10n/app_ar.arb'))
all_ok = True
for k, expected in SPOT_CHECK.items():
    actual = ar.get(k, "<MISSING>")
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
git diff --stat lib/l10n/app_ar.arb
git add lib/l10n/app_ar.arb
git status
```

```bash
cat > /tmp/commit_msg.txt << 'EOF'
10.ar-batch-3: Arabic translations for KYC ID-specific screens (52 keys)

Translates 52 Arabic keys covering ID-specific KYC verification screens,
mirroring the exact key set from French Batch 3:
- NIN (Nigeria) — 5 keys
- BVN (Bank Verification Number) — 5 keys
- SSNIT (Ghana) — 5 keys
- Driver's License — 3 keys
- Passport — 3 keys
- Voter's Card — 3 keys
- National ID generic — 3 keys, 1 ICU
- Uganda National ID / NIN — 8 keys
- Zambia TPIN — 4 keys
- Verify buttons (per-document) — 7 keys
- Misc labels (alien ID, intl passport, South African, taxpayer) — 6 keys

ICU placeholders preserved (verified by apply-script assertions, 1 ICU
key): nationalIdVerificationTitleWithCountry ({countryName}).
Em-dash — preserved in same key.

Convention notes:
- Latin acronyms preserved: NIN, BVN, SSNIT, TPIN (recognized in Arabic
  fintech for these specific country contexts)
- "بطاقة" for card, "هوية" for identity, "وطني" for national
- "رخصة القيادة" for driver's license
- "جواز السفر" for passport
- "بطاقة الناخب" for voter's card
- "بطاقة الأجنبي" for alien ID
- "دافع الضرائب" for taxpayer
- "أوغندا/أوغندي" for Uganda/Ugandan
- "زامبيا/زامبي" for Zambia/Zambian
- "جنوب إفريقي/إفريقية" for South African (hamza-on-alif form, formal MSA)
- Arabic counted noun rules applied:
  - 11/12/13/14 → singular noun + tanwin: "11 رقمًا", "14 حرفًا"
  - 10 → paucal plural: "10 أرقام"
- "بالضبط" for "exactly" in length errors
- "أبجدي رقمي" for alphanumeric

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_3_KYC_ID_SPECIFIC.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-3
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-3`
2. Final commit SHA
3. Output of all verification steps (4.1, 4.2, 4.3, 4.4)
4. Output of the apply script
5. `git diff --stat HEAD~1 HEAD`
6. Confirm `lib/generated/l10n/` was NOT staged or committed
7. Confirm no `.py` file at repo root was staged or committed
8. Any deviations from this spec with reasoning

---

## 8. STOP and report (do NOT improvise) if:

- Any pre-work check (Section 2) fails
- Any assertion in the apply script (Section 3.2) fires
- Any verification check (Section 4) fails
- Reality contradicts spec literal text in non-trivial ways
- The spec dict turns out to have wrong key count, missing keys, or duplicate keys

---

## 9. After agent reports back — operator's tasks

1. Pull, regen, analyze, build:
   ```bash
   git fetch origin
   git checkout phase6-step10-ar-batch-3
   git pull
   flutter gen-l10n
   git diff --stat
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```
   Expected: 204 issues, build green.

2. Sync guard, discard generated, ff-merge, tag, push:
   ```bash
   git fetch origin
   local_main=$(git rev-parse main)
   origin_main=$(git rev-parse origin/main)
   [ "$local_main" = "$origin_main" ] || { echo "FAIL — sync"; exit 1; }
   git checkout -- lib/generated/l10n/
   git checkout main
   git merge --ff-only phase6-step10-ar-batch-3
   git tag phase6-step10-ar-batch-3-complete
   git push origin main
   git push origin phase6-step10-ar-batch-3-complete
   git push origin :phase6-step10-ar-batch-3
   git branch -d phase6-step10-ar-batch-3
   ```

---

## 10. Translation conventions (extension to AR Batches 1-2)

| Convention | Decision |
|---|---|
| (Batches 1-2) Register | Formal MSA |
| (Batches 1-2) Brand names | Latin script |
| **NEW (Batch 3)** Latin acronyms (NIN, BVN, SSNIT, TPIN) | Kept as Latin (recognized in country-specific Arabic fintech) |
| **NEW (Batch 3)** Card | "بطاقة" |
| **NEW (Batch 3)** ID number | "رقم تعريف" / "رقم تعريفي" |
| **NEW (Batch 3)** National ID | "بطاقة الهوية الوطنية" |
| **NEW (Batch 3)** Driver's License | "رخصة القيادة" |
| **NEW (Batch 3)** Passport | "جواز السفر" |
| **NEW (Batch 3)** International passport | "جواز السفر الدولي" |
| **NEW (Batch 3)** Voter's Card | "بطاقة الناخب" |
| **NEW (Batch 3)** Alien (foreign resident) | "أجنبي" |
| **NEW (Batch 3)** Alien ID | "بطاقة الأجنبي" |
| **NEW (Batch 3)** Taxpayer | "دافع الضرائب" |
| **NEW (Batch 3)** Tax / fiscal | "ضريبي / ضرائب" |
| **NEW (Batch 3)** Uganda / Ugandan | "أوغندا / أوغندي" |
| **NEW (Batch 3)** Zambia / Zambian | "زامبيا / زامبي" |
| **NEW (Batch 3)** South African | "جنوب إفريقي / إفريقية" |
| **NEW (Batch 3)** Counted noun (11-99) | Singular + tanwin: "11 رقمًا" |
| **NEW (Batch 3)** Paucal plural (3-10) | Plural noun: "10 أرقام" |
| **NEW (Batch 3)** "exactly N" | "N [counted noun] بالضبط" |
| **NEW (Batch 3)** Alphanumeric | "أبجدي رقمي" |
| **NEW (Batch 3)** Bank Verification | "تحقّق مصرفي" |
