# Phase 6 Step 10 — Arabic Batch 4a — Bank Accounts & Withdrawal Setup

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 4a of 9
> **Scope:** Bank account add/edit/remove screens, withdrawal setup, account verification — 35 keys, 2 ICU
> **Predecessor:** `phase6-step10-ar-batch-3-complete` @ `cac0442f`
> **Branch name to create:** `phase6-step10-ar-batch-4a`
> **Tag to apply after merge:** `phase6-step10-ar-batch-4a-complete`

---

## 1. Scope

This batch translates 35 Arabic keys covering the bank account management surface (mirroring the exact key set from French Batch 4a):

- Bank selection (4 keys)
- Linked accounts (3 keys)
- Add bank actions (3 keys)
- Bank name field (3 keys, including "e.g." example placeholder)
- Account holder name field (4 keys)
- Account number field (3 keys)
- Account verification (3 keys, 1 ICU at enterAtLeastDigitsToVerify)
- Generate account (3 keys) — for inbound payment account number
- Remove account confirmation (3 keys)
- Empty state (2 keys)
- Wallet UI errors (4 keys, 1 ICU at walletUiErrorAccountNumberTooShort)

**Out of scope for this batch:**
- Auth & onboarding → Batch 1 (shipped)
- KYC core flow → Batch 2 (shipped)
- KYC ID-specific screens → Batch 3 (shipped)
- Wallet/Money flows/Mobile Money/Currency → Batch 4b
- Send & Receive Money flows → Batch 5
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
test -f docs/PHASE_6_STEP_10_AR_BATCH_4A_BANK_ACCOUNTS.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-3-complete|phase6-step10-ar-batch-4a-complete"
```

Expected:
- `phase6-step10-ar-batch-3-complete` MUST be present
- `phase6-step10-ar-batch-4a-complete` MUST NOT be present

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
print(f"AR currently filled: {filled} keys (expected 235 = 1 itemCount + 90 + 92 + 52 from Batches 1-3)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 235 keys`
- `AR total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-4a
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_ar_batch_4a.py`, run, then verify and commit.

### 3.1 Translation data

The 35 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Brand "GCB Bank" stays Latin.

```python
TRANSLATIONS = {
    # --- Bank selection (4) ---
    "selectBank": "اختر بنكًا",
    "selectBankLabel": "اختر بنكًا",
    "selectABankHint": "اختر بنكًا",
    "linkedBanks": "البنوك المرتبطة",

    # --- Linked accounts (3) ---
    "linkedAccounts": "الحسابات المرتبطة",
    "linkedBankAccountsTitle": "الحسابات المصرفية المرتبطة",
    "bankAccountFallback": "حساب مصرفي",

    # --- Add bank actions (3) ---
    "addBankAccountAction": "إضافة حساب مصرفي",
    "addNewBank": "إضافة بنك جديد",
    "linkBank": "ربط بنك",

    # --- Bank name (3) ---
    "bankName": "اسم البنك",
    "bankNameLabel": "اسم البنك",
    "bankNameHint": "مثال: GCB Bank",

    # --- Account holder name (4) ---
    "accountName": "اسم صاحب الحساب",
    "accountNameLabel": "اسم صاحب الحساب",
    "nameOnAccountHint": "الاسم على الحساب",
    "enterAccountHolderNameHint": "أدخل اسم صاحب الحساب",

    # --- Account number (3) ---
    "accountNumber": "رقم الحساب",
    "accountNumberLabel": "رقم الحساب",
    "enterAccountNumberHint": "أدخل رقم الحساب",

    # --- Verification (3, 1 ICU at enterAtLeastDigitsToVerify) ---
    "accountVerifiedLabel": "تم التحقّق من الحساب",
    "couldNotVerifyAccountError": "تعذّر التحقّق من الحساب",
    "enterAtLeastDigitsToVerify": "أدخل {count} أرقام على الأقل للتحقّق",

    # --- Generate account (3) ---
    "generateAccountButton": "إنشاء الحساب",
    "loadingAccountDetails": "جارٍ تحميل تفاصيل الحساب...",
    "tapToGenerateAccountPrompt": "اضغط لإنشاء رقم حسابك المخصّص",

    # --- Remove account (3) ---
    "removeAccountConfirmTitle": "حذف الحساب؟",
    "removeAccountConfirmBody": "هل أنت متأكّد من رغبتك في حذف هذا الحساب المصرفي؟",
    "accountRemovedToast": "تم حذف الحساب",

    # --- Empty state (2) ---
    "noBankAccountsEmptyTitle": "لا توجد حسابات مصرفية",
    "noBankAccountsEmptySubtitle": "أضف حسابًا مصرفيًا لتسهيل عمليات السحب",

    # --- Wallet UI errors (4, 1 ICU at walletUiErrorAccountNumberTooShort) ---
    "walletUiErrorAccountNumberTooShort": "يجب أن يتكوّن رقم الحساب من {minDigits} أرقام على الأقل",
    "walletUiErrorPleaseEnterAccountName": "يُرجى إدخال اسم صاحب الحساب",
    "walletUiErrorPleaseSelectBank": "يُرجى اختيار بنك",
    "walletUiErrorPleaseVerifyAccount": "يُرجى التحقّق من حسابك أولًا",
}

assert len(TRANSLATIONS) == 35, f"Spec dict has {len(TRANSLATIONS)} entries, expected 35"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_4a.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 4a - Bank Accounts & Withdrawal Setup
Applies 35 Arabic translations to lib/l10n/app_ar.arb.
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
    assert len(TRANSLATIONS) == 35, f"Expected 35 translations, got {len(TRANSLATIONS)}"

    ar = json.loads(ARB_PATH.read_text(encoding="utf-8"))
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))

    missing_in_en = [k for k in TRANSLATIONS if k not in en]
    missing_in_ar = [k for k in TRANSLATIONS if k not in ar]
    assert not missing_in_en, f"Spec keys missing in en: {missing_in_en}"
    assert not missing_in_ar, f"Spec keys missing in ar: {missing_in_ar}"

    not_empty = [k for k in TRANSLATIONS if ar[k] != ""]
    assert not not_empty, f"Spec keys already non-empty in ar: {not_empty}"

    for key, value in TRANSLATIONS.items():
        ar[key] = value

    for key, expected in TRANSLATIONS.items():
        assert ar[key] == expected, f"Mismatch on {key}: got {ar[key]!r}, expected {expected!r}"

    ar_keys = {k for k in ar if not k.startswith('@')}
    en_keys = {k for k in en if not k.startswith('@')}
    assert len(ar_keys) == 701, f"AR has {len(ar_keys)} keys after apply, expected 701"
    assert ar_keys == en_keys, "AR/EN key sets diverged"

    # ICU placeholder preservation (2 ICU keys)
    assert "{count}" in ar["enterAtLeastDigitsToVerify"], \
        "enterAtLeastDigitsToVerify lost {count}"
    assert "{minDigits}" in ar["walletUiErrorAccountNumberTooShort"], \
        "walletUiErrorAccountNumberTooShort lost {minDigits}"

    # Brand "GCB Bank" preserved in Latin script
    assert "GCB Bank" in ar["bankNameHint"], "bankNameHint lost GCB Bank"

    # Arabic question mark in confirm title
    assert "؟" in ar["removeAccountConfirmTitle"], \
        "removeAccountConfirmTitle missing Arabic question mark ؟"
    assert "؟" in ar["removeAccountConfirmBody"], \
        "removeAccountConfirmBody missing Arabic question mark ؟"

    # Arabic Unicode characters present in sample keys
    for k in ["selectBank", "bankName", "accountNumber", "accountVerifiedLabel"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 235, expected {235 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_4a.py
```

Expected:
```
OK — applied 35 translations
AR filled: 270/701 (was 235, expected 270)
AR empty: 431
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

Expected: 701, 701, True, 270.

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
    "selectBank": "اختر بنكًا",
    "linkedBanks": "البنوك المرتبطة",
    "linkedBankAccountsTitle": "الحسابات المصرفية المرتبطة",
    "addBankAccountAction": "إضافة حساب مصرفي",
    "addNewBank": "إضافة بنك جديد",
    "linkBank": "ربط بنك",
    "bankName": "اسم البنك",
    "bankNameHint": "مثال: GCB Bank",
    "accountName": "اسم صاحب الحساب",
    "accountNumber": "رقم الحساب",
    "accountVerifiedLabel": "تم التحقّق من الحساب",
    "enterAtLeastDigitsToVerify": "أدخل {count} أرقام على الأقل للتحقّق",
    "tapToGenerateAccountPrompt": "اضغط لإنشاء رقم حسابك المخصّص",
    "removeAccountConfirmTitle": "حذف الحساب؟",
    "removeAccountConfirmBody": "هل أنت متأكّد من رغبتك في حذف هذا الحساب المصرفي؟",
    "noBankAccountsEmptySubtitle": "أضف حسابًا مصرفيًا لتسهيل عمليات السحب",
    "walletUiErrorAccountNumberTooShort": "يجب أن يتكوّن رقم الحساب من {minDigits} أرقام على الأقل",
    "walletUiErrorPleaseSelectBank": "يُرجى اختيار بنك",
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
10.ar-batch-4a: Arabic translations for bank accounts & withdrawal setup (35 keys)

Translates 35 Arabic keys covering the bank account management surface,
mirroring the exact key set from French Batch 4a:
- Bank selection (4 keys)
- Linked accounts (3 keys)
- Add bank actions (3 keys)
- Bank name field (3 keys, includes "e.g. GCB Bank" placeholder)
- Account holder name field (4 keys)
- Account number field (3 keys)
- Account verification (3 keys, 1 ICU)
- Generate inbound account (3 keys)
- Remove account confirmation (3 keys)
- Empty state (2 keys)
- Wallet UI errors (4 keys, 1 ICU)

ICU placeholders preserved (verified by apply-script assertions, 2 ICU
keys): enterAtLeastDigitsToVerify ({count}),
walletUiErrorAccountNumberTooShort ({minDigits}).

Convention notes:
- "بنك" for bank, "حساب مصرفي" for bank account
- "رقم الحساب" for account number
- "صاحب الحساب" for account holder
- "ربط" / "مرتبط" for link / linked
- "إضافة" for add, "حذف" for remove/delete
- "إنشاء" for generate
- "السحب" for withdrawal
- "GCB Bank" preserved Latin (brand)
- "مثال:" for "e.g." in placeholder hints
- Arabic question mark ؟ in confirm dialog title and body
- Counted noun: "أرقام" (paucal plural, 3-10) used for digit-count
  contexts since typical bank account length validations target 6-10
  digits (e.g. "{count} أرقام على الأقل")

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_4A_BANK_ACCOUNTS.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-4a
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-4a`
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
   git checkout phase6-step10-ar-batch-4a
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
   git merge --ff-only phase6-step10-ar-batch-4a
   git tag phase6-step10-ar-batch-4a-complete
   git push origin main
   git push origin phase6-step10-ar-batch-4a-complete
   git push origin :phase6-step10-ar-batch-4a
   git branch -d phase6-step10-ar-batch-4a
   ```

---

## 10. Translation conventions (extension to AR Batches 1-3)

| Convention | Decision |
|---|---|
| (Batches 1-3) Established conventions | Carry forward |
| **NEW (Batch 4a)** Bank | "بنك" |
| **NEW (Batch 4a)** Bank account | "حساب مصرفي" |
| **NEW (Batch 4a)** Account number | "رقم الحساب" |
| **NEW (Batch 4a)** Account holder | "صاحب الحساب" |
| **NEW (Batch 4a)** Linked / link (verb) | "مرتبط" / "ربط" |
| **NEW (Batch 4a)** Add | "إضافة" |
| **NEW (Batch 4a)** Remove / delete | "حذف" |
| **NEW (Batch 4a)** Generate | "إنشاء" |
| **NEW (Batch 4a)** Withdrawal (operations) | "السحب" / "عمليات السحب" |
| **NEW (Batch 4a)** Dedicated (account) | "مخصّص" |
| **NEW (Batch 4a)** "Tap to..." | "اضغط لـ..." |
| **NEW (Batch 4a)** "e.g." / "ex." | "مثال:" |
| **NEW (Batch 4a)** "at least N [digits]" | "N [counted noun] على الأقل" |
| **NEW (Batch 4a)** "Are you sure?" | "هل أنت متأكّد؟" |
| **NEW (Batch 4a)** GCB Bank | Stay Latin (brand) |
