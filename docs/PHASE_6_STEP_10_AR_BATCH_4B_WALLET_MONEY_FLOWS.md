# Phase 6 Step 10 — Arabic Batch 4b — Wallet / Money Flows / Mobile Money / Currency

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 4b of 9
> **Scope:** Wallet home, balance, add money, withdraw, currency, Mobile Money, virtual account, wallet errors — 73 keys, 11 ICU
> **Predecessor:** `phase6-step10-ar-batch-4a-complete` @ `6a2ca03c`
> **Branch name to create:** `phase6-step10-ar-batch-4b`
> **Tag to apply after merge:** `phase6-step10-ar-batch-4b-complete`

---

## 1. Scope

This batch translates 73 Arabic keys covering wallet, money flows, currency, Mobile Money, and virtual account screens (mirroring the exact key set from French Batch 4b):

- Balance display (8 keys) — available, total, on-hold, hide/show, new balance, wallet ID
- Add money flow (7 keys) — title, bank transfer / card tabs, success messages
- Withdraw flow (8 keys, 2 ICU) — confirm withdrawal, OTP, withdrawal status
- Amount input (8 keys) — amount field, error messages, hints
- Currency formatting (5 keys, 5 ICU) — currency-with-symbol, signed amount, exchange rate
- Mobile Money (12 keys, 1 ICU) — availability errors, provider label, MoMo errors, MTN MoMo
- Paystack security notice (1 key)
- Virtual account (3 keys)
- Wallet errors (8 keys, 1 ICU error variant)

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_4B_WALLET_MONEY_FLOWS.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-4a-complete|phase6-step10-ar-batch-4b-complete"
```

Expected:
- `phase6-step10-ar-batch-4a-complete` MUST be present
- `phase6-step10-ar-batch-4b-complete` MUST NOT be present

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
print(f"AR currently filled: {filled} keys (expected 270 = Batches 1-4a + itemCount)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 270 keys`
- `AR total: 701`
- `Key sets match: True`

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-4b
```

---

## 3. Implementation

### 3.1 Translation data

The 73 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Brand names (Mobile Money, MTN MoMo, Paystack) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Balance display (8) ---
    "availableBalance": "الرصيد المتاح",
    "availableBalanceFull": "الرصيد المتاح",
    "availableBalanceLabel": "متاح",
    "hideBalance": "إخفاء الرصيد",
    "showBalance": "إظهار الرصيد",
    "newBalanceLabel": "الرصيد الجديد",
    "onHoldBalanceLabel": "قيد الانتظار",
    "totalBalance": "الرصيد الإجمالي",

    # --- Wallet ID (2) ---
    "walletId": "رقم تعريف المحفظة",
    "walletIdCopied": "تم نسخ رقم تعريف المحفظة!",

    # --- Add money flow (7) ---
    "addMoney": "إضافة أموال",
    "addMoneyTitle": "إضافة أموال",
    "bankTransferTabLabel": "تحويل مصرفي",
    "cardTabLabel": "بطاقة",
    "continueToPaymentButton": "المتابعة إلى الدفع",
    "hasBeenAddedToWallet": "تم إضافته إلى محفظتك",
    "successMoneyAdded": "تمت إضافة الأموال بنجاح!",

    # --- Withdraw flow (8, 2 ICU) ---
    "transferFrom": "تحويل من",
    "amountToWithdrawLabel": "المبلغ المراد سحبه",
    "confirmWithdrawalTitle": "تأكيد السحب",
    "enterOtpBody": "يُرجى إدخال OTP المُرسل إلى هاتفك / بريدك الإلكتروني المسجّل لإتمام سحب {symbol}{amount}",
    "iveApproved": "لقد وافقت",
    "refLine": "المرجع: {reference}",
    "withdraw": "سحب",
    "withdrawAction": "سحب",
    "withdrawalBeingProcessed": "{symbol}{amount} قيد المعالجة",
    "withdrawalFailedError": "فشل السحب",
    "withdrawalInitiatedTitle": "تم بدء السحب",

    # --- Amount input (8) ---
    "amount": "المبلغ",
    "amountHint": "أدخل المبلغ",
    "amountLabel": "المبلغ",
    "enterAmountLabel": "أدخل المبلغ",
    "errorInsufficientBalance": "رصيد غير كافٍ",
    "errorInvalidAmount": "يُرجى إدخال مبلغ صحيح",
    "insufficientBalance": "الرصيد غير كافٍ لهذا التحويل",
    "pleaseEnterAmount": "يُرجى إدخال مبلغ",
    "pleaseEnterValidAmount": "يُرجى إدخال مبلغ صحيح",

    # --- Currency formatting (5, 5 ICU) ---
    "amountWithCurrency": "المبلغ: {symbol}{amount}",
    "currencyAmount": "{currency} {amount}",
    "currencyCodeWithSymbol": "{symbol} ({code})",
    "signedCurrencyAmount": "{prefix}{currency}{amount}",
    "symbolAmount": "{symbol}{amount}",

    # --- Exchange rate (3, 2 ICU) ---
    "exchangeRateErrorUnsupportedCurrency": "العملة غير مدعومة",
    "exchangeRateErrorUnsupportedCurrencyPair": "زوج العملات غير مدعوم: {from} أو {to}",
    "exchangeRateLabel": "سعر الصرف",
    "exchangeRateLine": "1 {fromCurrency} = {rate} {toCurrency}",

    # --- Mobile Money (12, 1 ICU at mtnMomoApprovePromptBody) ---
    "mobileMoneyNotAvailablePaymentsBody": "مدفوعات Mobile Money غير متاحة في منطقتك. يُرجى استخدام البطاقة أو التحويل المصرفي.",
    "mobileMoneyNotAvailableTitle": "Mobile Money غير متاح",
    "mobileMoneyNotAvailableWithdrawalsBody": "عمليات السحب عبر Mobile Money غير متاحة في منطقتك. يُرجى استخدام التحويل المصرفي.",
    "mobileMoneyProviderLabel": "مزوّد Mobile Money",
    "mobileMoneyTabLabel": "Mobile Money",
    "momoErrorInsufficientFunds": "أموال غير كافية في حسابك على Mobile Money.",
    "momoErrorInvalidPhone": "رقم هاتف غير صحيح. يُرجى التحقّق والمحاولة مجددًا.",
    "momoErrorNotConfigured": "خدمة Mobile Money قريبًا! هذه الميزة غير متاحة بعد. يُرجى استخدام البطاقة أو التحويل المصرفي بدلًا من ذلك.",
    "momoErrorPaymentDeclined": "تم رفض الدفع. يُرجى التحقّق من رصيدك على Mobile Money والمحاولة مجددًا.",
    "momoErrorPaymentTimeout": "انتهت مهلة طلب الدفع. يُرجى التحقّق من هاتفك لإشعار الموافقة والمحاولة مجددًا.",
    "mtnMomoApprovePromptBody": "يُرجى الموافقة على دفع {symbol}{amount} على هاتفك عبر MTN MoMo.",
    "mtnMomoPaymentFailedError": "فشل الدفع عبر MTN MoMo",

    # --- Mobile Money UI (2) ---
    "checkPhoneForApprovalPrompt": "تحقّق من هاتفك للموافقة على الإشعار.",
    "payWithMobileMoneyButton": "ادفع عبر Mobile Money",

    # --- Paystack notice (1) ---
    "paystackSecurityNote": "مدعوم بواسطة Paystack. معلومات الدفع الخاصة بك آمنة.",

    # --- Virtual account (3) ---
    "virtualAccountTitle": "الحساب الافتراضي",
    "virtualAccountInfoBody": "هذا الحساب خاص بك وحدك. أي تحويل إلى هذا الحساب يضاف تلقائيًا إلى محفظتك.",
    "yourVirtualAccountLabel": "حسابك الافتراضي",

    # --- Wallet errors (8) ---
    "walletErrorFailedToFetchTransaction": "فشل في استرجاع المعاملة",
    "walletErrorFailedToLookupWallet": "فشل في البحث عن المحفظة",
    "walletErrorFallback": "فشلت عملية المحفظة. يُرجى المحاولة مجددًا.",
    "walletErrorTooManyRequests": "عدد كبير من الطلبات. يُرجى المحاولة لاحقًا.",
    "walletUiErrorPaymentStillPending": "الدفع لا يزال قيد الانتظار. يُرجى التحقّق من هاتفك والمحاولة مجددًا.",
    "walletUiErrorPleaseEnter6DigitOtp": "يُرجى إدخال OTP صالح مكوّن من 6 أرقام",
    "walletUiErrorPleaseSelectMomoProvider": "يُرجى اختيار مزوّد Mobile Money",
    "walletUiErrorUserNotFound": "المستخدم غير موجود. يُرجى تسجيل الدخول مجددًا.",
    "walletUiErrorWithdrawalFailedRefunded": "فشل السحب. تمت إعادة رصيدك.",
}

assert len(TRANSLATIONS) == 73, f"Spec dict has {len(TRANSLATIONS)} entries, expected 73"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_4b.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 4b - Wallet / Money Flows / MoMo / Currency
Applies 73 Arabic translations to lib/l10n/app_ar.arb.
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
    assert len(TRANSLATIONS) == 73, f"Expected 73 translations, got {len(TRANSLATIONS)}"

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

    # ICU placeholder preservation (11 ICU keys)
    # 1. enterOtpBody {symbol}{amount}
    assert "{symbol}" in ar["enterOtpBody"], "enterOtpBody lost {symbol}"
    assert "{amount}" in ar["enterOtpBody"], "enterOtpBody lost {amount}"
    # 2. refLine {reference}
    assert "{reference}" in ar["refLine"], "refLine lost {reference}"
    # 3. withdrawalBeingProcessed {symbol}{amount}
    assert "{symbol}" in ar["withdrawalBeingProcessed"], "withdrawalBeingProcessed lost {symbol}"
    assert "{amount}" in ar["withdrawalBeingProcessed"], "withdrawalBeingProcessed lost {amount}"
    # 4. amountWithCurrency {symbol}{amount}
    assert "{symbol}" in ar["amountWithCurrency"], "amountWithCurrency lost {symbol}"
    assert "{amount}" in ar["amountWithCurrency"], "amountWithCurrency lost {amount}"
    # 5. currencyAmount {currency} {amount}
    assert "{currency}" in ar["currencyAmount"], "currencyAmount lost {currency}"
    assert "{amount}" in ar["currencyAmount"], "currencyAmount lost {amount}"
    # 6. currencyCodeWithSymbol {symbol} ({code})
    assert "{symbol}" in ar["currencyCodeWithSymbol"], "currencyCodeWithSymbol lost {symbol}"
    assert "{code}" in ar["currencyCodeWithSymbol"], "currencyCodeWithSymbol lost {code}"
    # 7. signedCurrencyAmount {prefix}{currency}{amount}
    assert "{prefix}" in ar["signedCurrencyAmount"], "signedCurrencyAmount lost {prefix}"
    assert "{currency}" in ar["signedCurrencyAmount"], "signedCurrencyAmount lost {currency}"
    assert "{amount}" in ar["signedCurrencyAmount"], "signedCurrencyAmount lost {amount}"
    # 8. symbolAmount {symbol}{amount}
    assert "{symbol}" in ar["symbolAmount"], "symbolAmount lost {symbol}"
    assert "{amount}" in ar["symbolAmount"], "symbolAmount lost {amount}"
    # 9. exchangeRateErrorUnsupportedCurrencyPair {from} {to}
    assert "{from}" in ar["exchangeRateErrorUnsupportedCurrencyPair"], \
        "exchangeRateErrorUnsupportedCurrencyPair lost {from}"
    assert "{to}" in ar["exchangeRateErrorUnsupportedCurrencyPair"], \
        "exchangeRateErrorUnsupportedCurrencyPair lost {to}"
    # 10. exchangeRateLine {fromCurrency} {rate} {toCurrency}
    assert "{fromCurrency}" in ar["exchangeRateLine"], "exchangeRateLine lost {fromCurrency}"
    assert "{rate}" in ar["exchangeRateLine"], "exchangeRateLine lost {rate}"
    assert "{toCurrency}" in ar["exchangeRateLine"], "exchangeRateLine lost {toCurrency}"
    # 11. mtnMomoApprovePromptBody {symbol}{amount}
    assert "{symbol}" in ar["mtnMomoApprovePromptBody"], "mtnMomoApprovePromptBody lost {symbol}"
    assert "{amount}" in ar["mtnMomoApprovePromptBody"], "mtnMomoApprovePromptBody lost {amount}"

    # Brand names preserved (Latin)
    assert "Mobile Money" in ar["mobileMoneyNotAvailableTitle"], \
        "mobileMoneyNotAvailableTitle lost Mobile Money brand"
    assert "Mobile Money" in ar["mobileMoneyTabLabel"], \
        "mobileMoneyTabLabel lost Mobile Money brand"
    assert "Mobile Money" in ar["payWithMobileMoneyButton"], \
        "payWithMobileMoneyButton lost Mobile Money brand"
    assert "MTN MoMo" in ar["mtnMomoApprovePromptBody"], \
        "mtnMomoApprovePromptBody lost MTN MoMo brand"
    assert "MTN MoMo" in ar["mtnMomoPaymentFailedError"], \
        "mtnMomoPaymentFailedError lost MTN MoMo brand"
    assert "Paystack" in ar["paystackSecurityNote"], \
        "paystackSecurityNote lost Paystack brand"
    assert "OTP" in ar["enterOtpBody"], "enterOtpBody lost OTP token"
    assert "OTP" in ar["walletUiErrorPleaseEnter6DigitOtp"], \
        "walletUiErrorPleaseEnter6DigitOtp lost OTP token"

    # Arabic exclamation/punctuation
    assert "!" in ar["walletIdCopied"], "walletIdCopied lost exclamation"
    assert "!" in ar["successMoneyAdded"], "successMoneyAdded lost exclamation"

    # Arabic Unicode characters present in sample keys
    for k in ["availableBalance", "addMoney", "withdraw", "exchangeRateLabel"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 270, expected {270 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_4b.py
```

Expected:
```
OK — applied 73 translations
AR filled: 343/701 (was 270, expected 343)
AR empty: 358
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

Expected: 701, 701, True, 343.

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
    "availableBalance": "الرصيد المتاح",
    "hideBalance": "إخفاء الرصيد",
    "totalBalance": "الرصيد الإجمالي",
    "walletIdCopied": "تم نسخ رقم تعريف المحفظة!",
    "addMoney": "إضافة أموال",
    "successMoneyAdded": "تمت إضافة الأموال بنجاح!",
    "enterOtpBody": "يُرجى إدخال OTP المُرسل إلى هاتفك / بريدك الإلكتروني المسجّل لإتمام سحب {symbol}{amount}",
    "refLine": "المرجع: {reference}",
    "withdrawalBeingProcessed": "{symbol}{amount} قيد المعالجة",
    "amount": "المبلغ",
    "errorInsufficientBalance": "رصيد غير كافٍ",
    "amountWithCurrency": "المبلغ: {symbol}{amount}",
    "currencyAmount": "{currency} {amount}",
    "signedCurrencyAmount": "{prefix}{currency}{amount}",
    "exchangeRateLine": "1 {fromCurrency} = {rate} {toCurrency}",
    "mobileMoneyNotAvailableTitle": "Mobile Money غير متاح",
    "mobileMoneyProviderLabel": "مزوّد Mobile Money",
    "mtnMomoApprovePromptBody": "يُرجى الموافقة على دفع {symbol}{amount} على هاتفك عبر MTN MoMo.",
    "mtnMomoPaymentFailedError": "فشل الدفع عبر MTN MoMo",
    "paystackSecurityNote": "مدعوم بواسطة Paystack. معلومات الدفع الخاصة بك آمنة.",
    "virtualAccountTitle": "الحساب الافتراضي",
    "walletErrorFallback": "فشلت عملية المحفظة. يُرجى المحاولة مجددًا.",
    "walletUiErrorPleaseEnter6DigitOtp": "يُرجى إدخال OTP صالح مكوّن من 6 أرقام",
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
10.ar-batch-4b: Arabic translations for wallet/money flows/MoMo/currency (73 keys)

Translates 73 Arabic keys covering wallet, money flows, currency,
Mobile Money, and virtual account screens, mirroring FR Batch 4b:
- Balance display (8 keys) — available, total, on-hold, hide/show
- Wallet ID (2 keys)
- Add money flow (7 keys) — bank transfer / card tabs, success
- Withdraw flow (8 keys, 2 ICU)
- Amount input (8 keys)
- Currency formatting (5 keys, 5 ICU placeholder positions)
- Exchange rate (3 keys, 2 ICU)
- Mobile Money (12 keys, 1 ICU)
- Mobile Money UI (2 keys)
- Paystack security note (1 key)
- Virtual account (3 keys)
- Wallet errors (8 keys, 1 ICU)

ICU placeholders preserved (verified by apply-script assertions, 11 ICU
keys with ~17 placeholder positions): enterOtpBody, refLine,
withdrawalBeingProcessed, amountWithCurrency, currencyAmount,
currencyCodeWithSymbol, signedCurrencyAmount, symbolAmount,
exchangeRateErrorUnsupportedCurrencyPair, exchangeRateLine,
mtnMomoApprovePromptBody.

Convention notes:
- "رصيد" for balance, "الرصيد المتاح" for available balance
- "محفظة" for wallet, "رقم تعريف المحفظة" for wallet ID
- "أموال" for money/funds, "إضافة أموال" for add money
- "سحب" for withdraw (verb / noun)
- "مبلغ" for amount, "كافٍ" for sufficient
- "تحويل مصرفي" for bank transfer, "تحويل" for transfer
- "بطاقة" for card
- "العملة" for currency, "سعر الصرف" for exchange rate
- "المعاملة" for transaction (financial sense)
- "الحساب الافتراضي" for virtual account (افتراضي = virtual/default)
- Brand names kept Latin: Mobile Money, MTN MoMo, Paystack, OTP
- "بنجاح" for "successfully"
- "قيد الانتظار" for "on hold/pending"
- "قيد المعالجة" for "being processed"
- "تعذّر" / "فشل" distinction maintained from earlier batches

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_4B_WALLET_MONEY_FLOWS.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-4b
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-4b`
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
   git checkout phase6-step10-ar-batch-4b
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
   git merge --ff-only phase6-step10-ar-batch-4b
   git tag phase6-step10-ar-batch-4b-complete
   git push origin main
   git push origin phase6-step10-ar-batch-4b-complete
   git push origin :phase6-step10-ar-batch-4b
   git branch -d phase6-step10-ar-batch-4b
   ```

---

## 10. Translation conventions (extension to AR Batches 1-4a)

| Convention | Decision |
|---|---|
| (Earlier batches) Established conventions | Carry forward |
| **NEW (Batch 4b)** Balance | "رصيد" |
| **NEW (Batch 4b)** Available balance | "الرصيد المتاح" |
| **NEW (Batch 4b)** On hold / pending | "قيد الانتظار" |
| **NEW (Batch 4b)** Total balance | "الرصيد الإجمالي" |
| **NEW (Batch 4b)** Wallet ID | "رقم تعريف المحفظة" |
| **NEW (Batch 4b)** Money / funds | "أموال" |
| **NEW (Batch 4b)** Add money | "إضافة أموال" |
| **NEW (Batch 4b)** Withdraw / withdrawal | "سحب" / "السحب" |
| **NEW (Batch 4b)** Amount | "مبلغ" / "المبلغ" |
| **NEW (Batch 4b)** Sufficient (negation) | "كافٍ" (used as "غير كافٍ" — insufficient) |
| **NEW (Batch 4b)** Bank transfer | "تحويل مصرفي" |
| **NEW (Batch 4b)** Card | "بطاقة" |
| **NEW (Batch 4b)** Currency | "العملة" / "عملة" |
| **NEW (Batch 4b)** Exchange rate | "سعر الصرف" |
| **NEW (Batch 4b)** Transaction (financial) | "معاملة" / "المعاملة" |
| **NEW (Batch 4b)** Virtual account | "الحساب الافتراضي" |
| **NEW (Batch 4b)** Provider (MoMo) | "مزوّد" |
| **NEW (Batch 4b)** Region | "منطقة" |
| **NEW (Batch 4b)** Reference (transaction ref) | "المرجع" |
| **NEW (Batch 4b)** Powered by | "مدعوم بواسطة" |
| **NEW (Batch 4b)** Refunded | "تمت إعادة [X]" |
| **NEW (Batch 4b)** Mobile Money / MTN MoMo / Paystack | Stay Latin (brands) |
| **NEW (Batch 4b)** "being processed" | "قيد المعالجة" |
| **NEW (Batch 4b)** "still pending" | "لا يزال قيد الانتظار" |
| **NEW (Batch 4b)** "in your region" | "في منطقتك" |
| **NEW (Batch 4b)** "approval prompt" | "إشعار الموافقة" |
