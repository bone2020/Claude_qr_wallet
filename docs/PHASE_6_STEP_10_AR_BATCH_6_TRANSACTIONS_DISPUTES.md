# Phase 6 Step 10 — Arabic Batch 6 — Transactions & Disputes

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 6 of 9
> **Scope:** Transaction list, transaction details, transaction status, disputes management — 39 keys, 2 ICU
> **Predecessor:** `phase6-step10-ar-batch-5-complete` @ `34256bd0`
> **Branch name to create:** `phase6-step10-ar-batch-6`
> **Tag to apply after merge:** `phase6-step10-ar-batch-6-complete`

---

## 1. Scope

This batch translates 39 Arabic keys covering transactions and disputes (mirroring the exact key set from French Batch 6):

- Transactions section header (3 keys)
- Empty state (2 keys)
- List actions (3 keys) — view all, load more, all transactions
- Transaction status (7 keys) — pending, completed, failed, sent, received
- Transaction details (5 keys) — details title, ID, items, PIN, not-found
- Date / time / status labels (3 keys)
- From / to (2 keys)
- "How it works" label (1 key)
- Disputes (5 keys) — my disputes, tabs (active/resolved with count, filed by me, against me)
- Dispute empty states (3 keys)
- Dispute errors / notice (2 keys)
- Action buttons (2 keys) — review, report issue

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_6_TRANSACTIONS_DISPUTES.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-5-complete|phase6-step10-ar-batch-6-complete"
```

Expected:
- `phase6-step10-ar-batch-5-complete` MUST be present
- `phase6-step10-ar-batch-6-complete` MUST NOT be present

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
print(f"AR currently filled: {filled} keys (expected 430 = Batches 1-5 + itemCount)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 430 keys`
- `AR total: 701`
- `Key sets match: True`

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-6
```

---

## 3. Implementation

### 3.1 Translation data

The 39 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Arabic question mark `؟` and Arabic period `.` MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Transactions header (3) ---
    "transactions": "المعاملات",
    "transactionsSection": "المعاملات",
    "recentTransactions": "المعاملات الأخيرة",

    # --- Empty state (2) ---
    "noTransactions": "لا توجد معاملات بعد",
    "noTransactionsSubtitle": "سيظهر سجل معاملاتك هنا",

    # --- List actions (3) ---
    "allTransactions": "الكل",
    "viewAll": "عرض الكل",
    "loadMore": "تحميل المزيد",

    # --- Transaction status (7) ---
    "pending": "قيد الانتظار",
    "completed": "مكتملة",
    "failed": "فاشلة",
    "transactionStatusFailed": "فاشلة",
    "transactionStatusPending": "قيد الانتظار",
    "sent": "مُرسلة",
    "received": "مُستلمة",

    # --- Transaction details (5) ---
    "transactionDetails": "تفاصيل المعاملة",
    "transactionId": "رقم تعريف المعاملة",
    "transactionItemsLabel": "العناصر",
    "transactionPin": "رمز PIN المعاملة",
    "transactionNotFound": "المعاملة غير موجودة",

    # --- Date / time / status (3) ---
    "date": "التاريخ",
    "time": "الوقت",
    "status": "الحالة",

    # --- From / to (2) ---
    "from": "من",
    "to": "إلى",

    # --- How it works (1) ---
    "howItWorksLabel": "كيف يعمل",

    # --- Disputes (5, 2 ICU) ---
    "myDisputes": "نزاعاتي",
    "myDisputesTitle": "نزاعاتي",
    "activeTabWithCount": "نشطة ({count})",
    "resolvedTabWithCount": "محلولة ({count})",
    "filedByMeTab": "مقدّمة منّي",
    "againstMeTab": "ضدّي",

    # --- Dispute empty states (3) ---
    "noActiveDisputesAgainstYou": "لا توجد نزاعات نشطة ضدّك.",
    "noActiveDisputesFiled": "لا توجد نزاعات نشطة مقدّمة.",
    "noResolvedDisputes": "لا توجد نزاعات محلولة.",

    # --- Dispute errors / notice (2) ---
    "disputeNotFoundError": "النزاع غير موجود",
    "disputesCappedNotice": "عرض آخر 50 نزاعًا. قد لا تظهر الإدخالات الأقدم.",

    # --- Action buttons (2) ---
    "review": "مراجعة",
    "reportIssue": "الإبلاغ عن مشكلة",
}

assert len(TRANSLATIONS) == 39, f"Spec dict has {len(TRANSLATIONS)} entries, expected 39"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_6.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 6 - Transactions & Disputes
Applies 39 Arabic translations to lib/l10n/app_ar.arb.
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
    assert len(TRANSLATIONS) == 39, f"Expected 39 translations, got {len(TRANSLATIONS)}"

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
    assert len(ar_keys) == 701
    assert ar_keys == en_keys

    # ICU placeholder preservation (2 ICU keys)
    assert "{count}" in ar["activeTabWithCount"], "activeTabWithCount lost {count}"
    assert "{count}" in ar["resolvedTabWithCount"], "resolvedTabWithCount lost {count}"

    # Latin token PIN preserved
    assert "PIN" in ar["transactionPin"], "transactionPin lost PIN token"

    # Arabic Unicode characters present in sample keys
    for k in ["transactions", "pending", "completed", "myDisputes", "review"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 430, expected {430 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_6.py
```

Expected:
```
OK — applied 39 translations
AR filled: 469/701 (was 430, expected 469)
AR empty: 232
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

Expected: 701, 701, True, 469.

### 4.3 Confirm fr and en files untouched

```bash
git diff --stat lib/l10n/app_fr.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty for both.

### 4.4 Spot-check + ICU + brand preservation

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "transactions": "المعاملات",
    "recentTransactions": "المعاملات الأخيرة",
    "noTransactions": "لا توجد معاملات بعد",
    "viewAll": "عرض الكل",
    "loadMore": "تحميل المزيد",
    "pending": "قيد الانتظار",
    "completed": "مكتملة",
    "failed": "فاشلة",
    "sent": "مُرسلة",
    "received": "مُستلمة",
    "transactionDetails": "تفاصيل المعاملة",
    "transactionId": "رقم تعريف المعاملة",
    "transactionPin": "رمز PIN المعاملة",
    "transactionNotFound": "المعاملة غير موجودة",
    "date": "التاريخ",
    "time": "الوقت",
    "status": "الحالة",
    "from": "من",
    "to": "إلى",
    "howItWorksLabel": "كيف يعمل",
    "myDisputes": "نزاعاتي",
    "activeTabWithCount": "نشطة ({count})",
    "resolvedTabWithCount": "محلولة ({count})",
    "againstMeTab": "ضدّي",
    "noActiveDisputesAgainstYou": "لا توجد نزاعات نشطة ضدّك.",
    "disputesCappedNotice": "عرض آخر 50 نزاعًا. قد لا تظهر الإدخالات الأقدم.",
    "review": "مراجعة",
    "reportIssue": "الإبلاغ عن مشكلة",
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
10.ar-batch-6: Arabic translations for transactions & disputes (39 keys)

Translates 39 Arabic keys covering transaction list, transaction
details, transaction status, and disputes management screens,
mirroring FR Batch 6:
- Transactions section header (3 keys)
- Empty state (2 keys)
- List actions (3 keys)
- Transaction status (7 keys)
- Transaction details (5 keys)
- Date / time / status (3 keys)
- From / to (2 keys)
- "How it works" label (1 key)
- Disputes (5 keys, 2 ICU)
- Dispute empty states (3 keys)
- Dispute errors / notice (2 keys)
- Action buttons (2 keys)

ICU placeholders preserved (verified by apply-script assertions, 2 ICU
keys): activeTabWithCount ({count}), resolvedTabWithCount ({count}).

Convention notes:
- "المعاملة / المعاملات" for transaction / transactions
- "النزاع / نزاعات" for dispute / disputes
- "قيد الانتظار" for pending (consistent with Batch 4b)
- "مكتملة / فاشلة / مُرسلة / مُستلمة" all in feminine form
  (transaction is a feminine noun in Arabic — agreement with المعاملة)
- "نشطة" for active (feminine, agrees with نزاعات)
- "محلولة" for resolved (feminine, agrees with نزاعات)
- "مقدّمة منّي" for "filed by me" (literally "submitted from me")
- "ضدّي" for "against me" (with shadda on the dad)
- "آخر 50 نزاعًا" — counted noun rule (11-99 → singular + tanwin)
- "الإدخالات" for entries
- "الإبلاغ عن مشكلة" for "report issue"
- "كيف يعمل" for "how it works" (literally "how it works")
- "PIN" kept as Latin acronym
- "تفاصيل" for details
- "غير موجودة / غير موجود" for "not found" (feminine/masculine
  agreement with respective subjects)

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_6_TRANSACTIONS_DISPUTES.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-6
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-6`
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
   git checkout phase6-step10-ar-batch-6
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
   git merge --ff-only phase6-step10-ar-batch-6
   git tag phase6-step10-ar-batch-6-complete
   git push origin main
   git push origin phase6-step10-ar-batch-6-complete
   git push origin :phase6-step10-ar-batch-6
   git branch -d phase6-step10-ar-batch-6
   ```

---

## 10. Translation conventions (extension to AR Batches 1-5)

| Convention | Decision |
|---|---|
| (Earlier batches) Established conventions | Carry forward |
| **NEW (Batch 6)** Transaction (financial) | "المعاملة" / "معاملات" |
| **NEW (Batch 6)** Recent | "الأخيرة" |
| **NEW (Batch 6)** Pending | "قيد الانتظار" (consistent with Batch 4b) |
| **NEW (Batch 6)** Completed (transaction) | "مكتملة" (feminine) |
| **NEW (Batch 6)** Failed (transaction) | "فاشلة" (feminine) |
| **NEW (Batch 6)** Sent (transaction) | "مُرسلة" (feminine) |
| **NEW (Batch 6)** Received (transaction) | "مُستلمة" (feminine) |
| **NEW (Batch 6)** Dispute / disputes | "نزاع" / "نزاعات" |
| **NEW (Batch 6)** Active (disputes) | "نشطة" (feminine, agrees with نزاعات) |
| **NEW (Batch 6)** Resolved | "محلولة" (feminine) |
| **NEW (Batch 6)** Filed by me | "مقدّمة منّي" |
| **NEW (Batch 6)** Against me | "ضدّي" (shadda) |
| **NEW (Batch 6)** Date | "التاريخ" |
| **NEW (Batch 6)** Time (clock) | "الوقت" |
| **NEW (Batch 6)** Status | "الحالة" |
| **NEW (Batch 6)** From / to (origin/destination) | "من" / "إلى" |
| **NEW (Batch 6)** "How it works" | "كيف يعمل" |
| **NEW (Batch 6)** Review (verb) | "مراجعة" |
| **NEW (Batch 6)** "Report issue" | "الإبلاغ عن مشكلة" |
| **NEW (Batch 6)** "Show last N entries" | "عرض آخر N [counted noun]" |
| **NEW (Batch 6)** Older entries | "الإدخالات الأقدم" |
| **NEW (Batch 6)** Counted noun rule | 50 → "50 نزاعًا" (11-99 → singular + tanwin) |
| **NEW (Batch 6)** Feminine agreement | All transaction-status adjectives feminine because المعاملة is feminine |
