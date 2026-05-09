# Phase 6 Step 10 — Arabic Batch 5 — Send & Receive Money Flows

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 5 of 9
> **Scope:** Peer-to-peer send/receive flow, QR scan/generate, payment requests, transaction errors, WhatsApp share — 87 keys, 11 ICU
> **Predecessor:** `phase6-step10-ar-batch-4b-complete` @ `29fbad77`
> **Branch name to create:** `phase6-step10-ar-batch-5`
> **Tag to apply after merge:** `phase6-step10-ar-batch-5-complete`

---

## 1. Scope

This batch translates 87 Arabic keys covering peer-to-peer send and receive money flows (mirroring the exact key set from French Batch 5):

- Send button & confirmation (5 keys, 1 ICU)
- Recipient lookup (4 keys)
- PIN confirmation (1 key)
- Send success & details (4 keys, 1 ICU)
- Currency conversion display (3 keys, 1 ICU)
- Recipient labels (3 keys)
- Send UI errors (4 keys)
- Transaction errors (10 keys) — failure modes
- Payment verification (3 keys)
- Approve payment (1 key)
- Payment success/failure (4 keys)
- QR scan flow (4 keys)
- Receive flow (3 keys)
- Payment request creation (8 keys)
- QR code download/share (5 keys, 3 ICU at error keys)
- Storage permission (1 key)
- Pay-to-user labels (3 keys, 2 ICU)
- WhatsApp share (3 keys)
- Scan caption (1 key)
- Clipboard / labels (3 keys, 2 ICU)
- Reference labels (3 keys, 1 ICU)

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_5_SEND_RECEIVE.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-4b-complete|phase6-step10-ar-batch-5-complete"
```

Expected:
- `phase6-step10-ar-batch-4b-complete` MUST be present
- `phase6-step10-ar-batch-5-complete` MUST NOT be present

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
print(f"AR currently filled: {filled} keys (expected 343 = Batches 1-4b + itemCount)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 343 keys`
- `AR total: 701`
- `Key sets match: True`

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-5
```

---

## 3. Implementation

### 3.1 Translation data

The 87 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Special characters (literal `\n` newlines, French guillemets `«»` in Arabic context, brand names QR Wallet/WhatsApp, Arabic punctuation) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Send button & confirmation (5, 1 ICU) ---
    "send": "إرسال",
    "sendMoney": "إرسال أموال",
    "confirmSend": "تأكيد وإرسال",
    "sendButtonAmount": "إرسال {currency}{amount}",
    "sendingTo": "إرسال إلى",

    # --- Recipient lookup (4) ---
    "enterWalletId": "أدخل رقم تعريف المحفظة",
    "pleaseEnterValidWalletId": "يُرجى إدخال رقم تعريف محفظة صحيح",
    "walletIdHint": "أدخل رقم تعريف محفظة المستلم",
    "lookingUpWallet": "جارٍ البحث عن المحفظة...",

    # --- PIN confirmation (1) ---
    "enterPinToConfirm": "أدخل رمز PIN المكوّن من 6 أرقام لتأكيد هذا التحويل",

    # --- Send success & details (4, 1 ICU) ---
    "successMoneySent": "تم إرسال الأموال بنجاح!",
    "securePaymentLabel": "دفع آمن",
    "feeApproximateError": "الرسوم تقريبية — {error}",
    "transactionFee": "رسوم المعاملة",

    # --- Total + verify details (2) ---
    "totalAmount": "المبلغ الإجمالي",
    "pleaseVerifyDetailsCorrect": "يُرجى التحقّق من صحة التفاصيل",

    # --- Currency conversion display (3, 1 ICU at amountSentTo) ---
    "originalAmount": "المبلغ الأصلي",
    "convertedAmount": "المبلغ المُحوَّل",
    "currencyConversion": "تحويل العملة",

    # --- Recipient labels (3) ---
    "amountSentTo": "تم إرسال {currency}{amount} إلى {recipient}",
    "recipientReceivesLabel": "يستلم المستلم:",
    "recipientResponseLabel": "ردّ المستلم",
    "sellerRequestedLabel": "طلب البائع:",

    # --- Send UI errors (4) ---
    "sendUiErrorCouldNotReadQrCode": "تعذّر قراءة رمز QR",
    "sendUiErrorCouldNotVerifyRecipientWallet": "تعذّر التحقّق من محفظة المستلم",
    "sendUiErrorPreviewTimedOut": "انتهت مهلة المعاينة",
    "sendUiErrorRequestTimedOut": "انتهت مهلة الطلب. يُرجى التحقّق من اتصالك والمحاولة مجددًا.",

    # --- Transaction errors (10) ---
    "transactionErrorDepositFailed": "فشل الإيداع",
    "transactionErrorFallback": "تعذّر إكمال المعاملة. يُرجى المحاولة مجددًا.",
    "transactionErrorInsufficientBalance": "رصيد غير كافٍ",
    "transactionErrorInvalidRequest": "طلب غير صحيح",
    "transactionErrorPaymentAlreadyProcessed": "تمت معالجة الدفع بالفعل",
    "transactionErrorPaymentVerificationFailed": "فشل التحقّق من الدفع",
    "transactionErrorPleaseLogInToSendMoney": "يُرجى تسجيل الدخول لإرسال الأموال",
    "transactionErrorRecipientWalletNotFound": "محفظة المستلم غير موجودة",
    "transactionErrorTransactionFailed": "فشلت المعاملة",
    "transactionErrorUserNotAuthenticated": "المستخدم غير مُصادَق عليه",

    # --- Payment verification (3) ---
    "verifyingPaymentTitle": "جارٍ التحقّق من الدفع...",
    "verifyingPaymentBody": "يُرجى الانتظار بينما نؤكّد الدفع",
    "approvePaymentTitle": "الموافقة على الدفع",

    # --- Payment success/failure (4) ---
    "paymentSuccessful": "تم الدفع بنجاح",
    "paymentSuccessfulHero": "تم الدفع بنجاح!",
    "paymentFailed": "فشل الدفع",
    "paymentFailedError": "فشل الدفع",
    "paymentFailedOrRejectedError": "فشل الدفع أو تم رفضه",

    # --- QR scan flow (4) ---
    "scanQrCode": "مسح رمز QR",
    "scanRecipientQrToSend": "امسح رمز QR للمستلم لإرسال الأموال",
    "positionQrCodeInFrame": "ضع رمز QR داخل الإطار",
    "startScan": "بدء المسح",

    # --- Receive flow (3) ---
    "receive": "استلام",
    "receiveMoney": "استلام الأموال",
    "paymentRequestLabel": "طلب الدفع",

    # --- Payment request creation (8) ---
    "requestPaymentTitle": "طلب الدفع",
    "createNewRequest": "إنشاء طلب جديد",
    "newRequestTooltip": "طلب جديد",
    "createPaymentRequestTitle": "إنشاء طلب دفع",
    "createPaymentRequestDescription": "أدخل المبلغ وأضف العناصر. يمكن للعملاء مسح رمز QR للدفع لك فورًا.",
    "itemsHint": "مثال: أرز جولوف، دجاج، مشروبات",
    "itemsOptional": "العناصر (اختيارية)",
    "maximum20ItemsAllowed": "الحد الأقصى 20 عنصرًا مسموح",

    # --- Note + description (3) ---
    "note": "ملاحظة (اختيارية)",
    "noteHint": "أضف ملاحظة",
    "descriptionLabel": "الوصف",

    # --- QR code generation (5, 3 ICU) ---
    "generateQrCode": "إنشاء رمز QR",
    "myQrCode": "رمز QR الخاص بي",
    "qrCodeInfoForCustomer": "اعرض رمز QR هذا للعميل.\nيقوم بمسحه، ويؤكّد المبلغ، ثم يدفع فورًا!",
    "qrCodeSavedToGallery": "تم حفظ رمز QR في المعرض!",
    "downloadQrCode": "تنزيل رمز QR",
    "shareQrCode": "مشاركة رمز QR",
    "errorSavingQrCode": "خطأ أثناء حفظ رمز QR: {error}",
    "errorGeneratingQr": "خطأ أثناء إنشاء QR: {error}",
    "errorSharingQr": "خطأ أثناء مشاركة QR: {error}",

    # --- Storage permission (1) ---
    "storagePermissionRequired": "إذن التخزين مطلوب لحفظ رمز QR",

    # --- Pay-to-user (3, 2 ICU) ---
    "payToUser": "ادفع إلى: {userName}",
    "payRequestShareText": "ادفع {symbol}{amount} إلى {userName}",
    "shareWalletIdSubject": "رقم تعريف QR Wallet الخاص بي",

    # --- App name in share (1) ---
    "qrWalletAppName": "QR Wallet",

    # --- WhatsApp share (3) ---
    "chatOnWhatsAppDialogTitle": "الدردشة عبر WhatsApp",
    "openWhatsAppButton": "فتح WhatsApp",
    "couldNotOpenWhatsAppToast": "تعذّر فتح WhatsApp. يُرجى التأكد من تثبيت WhatsApp.",

    # --- Scan caption (1) ---
    "scanWithAnotherPhoneCaption": "امسح بهاتف آخر\nأو اضغط على «فتح WhatsApp» أدناه",

    # --- Clipboard / labels (3, 2 ICU) ---
    "copiedToClipboard": "تم نسخ {label}",
    "labelCopiedToClipboard": "تم نسخ {label} إلى الحافظة",
    "tapToCopy": "اضغط للنسخ",

    # --- Reference labels (3, 1 ICU) ---
    "referenceColon": "المرجع: ",
    "referenceLabel": "المرجع",
    "referenceWithValue": "المرجع: {reference}",
}

assert len(TRANSLATIONS) == 87, f"Spec dict has {len(TRANSLATIONS)} entries, expected 87"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_5.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 5 - Send & Receive Money Flows
Applies 87 Arabic translations to lib/l10n/app_ar.arb.
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
    assert len(TRANSLATIONS) == 87, f"Expected 87 translations, got {len(TRANSLATIONS)}"

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
    # 1. sendButtonAmount {currency}{amount}
    assert "{currency}" in ar["sendButtonAmount"], "sendButtonAmount lost {currency}"
    assert "{amount}" in ar["sendButtonAmount"], "sendButtonAmount lost {amount}"
    # 2. feeApproximateError {error}
    assert "{error}" in ar["feeApproximateError"], "feeApproximateError lost {error}"
    # 3. amountSentTo {currency}{amount}{recipient}
    assert "{currency}" in ar["amountSentTo"], "amountSentTo lost {currency}"
    assert "{amount}" in ar["amountSentTo"], "amountSentTo lost {amount}"
    assert "{recipient}" in ar["amountSentTo"], "amountSentTo lost {recipient}"
    # 4. errorSavingQrCode {error}
    assert "{error}" in ar["errorSavingQrCode"], "errorSavingQrCode lost {error}"
    # 5. errorGeneratingQr {error}
    assert "{error}" in ar["errorGeneratingQr"], "errorGeneratingQr lost {error}"
    # 6. errorSharingQr {error}
    assert "{error}" in ar["errorSharingQr"], "errorSharingQr lost {error}"
    # 7. payToUser {userName}
    assert "{userName}" in ar["payToUser"], "payToUser lost {userName}"
    # 8. payRequestShareText {symbol}{amount}{userName}
    assert "{symbol}" in ar["payRequestShareText"], "payRequestShareText lost {symbol}"
    assert "{amount}" in ar["payRequestShareText"], "payRequestShareText lost {amount}"
    assert "{userName}" in ar["payRequestShareText"], "payRequestShareText lost {userName}"
    # 9. copiedToClipboard {label}
    assert "{label}" in ar["copiedToClipboard"], "copiedToClipboard lost {label}"
    # 10. labelCopiedToClipboard {label}
    assert "{label}" in ar["labelCopiedToClipboard"], "labelCopiedToClipboard lost {label}"
    # 11. referenceWithValue {reference}
    assert "{reference}" in ar["referenceWithValue"], "referenceWithValue lost {reference}"

    # Brand names preserved (Latin)
    assert "QR Wallet" in ar["shareWalletIdSubject"], "shareWalletIdSubject lost QR Wallet brand"
    assert "QR Wallet" in ar["qrWalletAppName"], "qrWalletAppName lost QR Wallet brand"
    assert "WhatsApp" in ar["chatOnWhatsAppDialogTitle"], "chatOnWhatsAppDialogTitle lost WhatsApp brand"
    assert "WhatsApp" in ar["openWhatsAppButton"], "openWhatsAppButton lost WhatsApp brand"
    assert "WhatsApp" in ar["couldNotOpenWhatsAppToast"], "couldNotOpenWhatsAppToast lost WhatsApp brand"
    assert "WhatsApp" in ar["scanWithAnotherPhoneCaption"], "scanWithAnotherPhoneCaption lost WhatsApp brand"
    assert "PIN" in ar["enterPinToConfirm"], "enterPinToConfirm lost PIN token"

    # Literal newlines preserved
    assert "\n" in ar["qrCodeInfoForCustomer"], "qrCodeInfoForCustomer lost newline"
    assert "\n" in ar["scanWithAnotherPhoneCaption"], "scanWithAnotherPhoneCaption lost newline"

    # Arabic guillemets « » preserved (Arabic punctuation can use these for inline quotes)
    assert "«" in ar["scanWithAnotherPhoneCaption"], "scanWithAnotherPhoneCaption lost «"
    assert "»" in ar["scanWithAnotherPhoneCaption"], "scanWithAnotherPhoneCaption lost »"

    # Em-dash — preserved in feeApproximateError
    assert "—" in ar["feeApproximateError"], "feeApproximateError lost em-dash"

    # Arabic exclamation
    assert "!" in ar["successMoneySent"], "successMoneySent lost exclamation"
    assert "!" in ar["paymentSuccessfulHero"], "paymentSuccessfulHero lost exclamation"

    # Arabic Unicode characters present in sample keys
    for k in ["send", "sendMoney", "receive", "scanQrCode"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 343, expected {343 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_5.py
```

Expected:
```
OK — applied 87 translations
AR filled: 430/701 (was 343, expected 430)
AR empty: 271
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

Expected: 701, 701, True, 430.

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
    "send": "إرسال",
    "sendMoney": "إرسال أموال",
    "sendButtonAmount": "إرسال {currency}{amount}",
    "enterWalletId": "أدخل رقم تعريف المحفظة",
    "enterPinToConfirm": "أدخل رمز PIN المكوّن من 6 أرقام لتأكيد هذا التحويل",
    "successMoneySent": "تم إرسال الأموال بنجاح!",
    "feeApproximateError": "الرسوم تقريبية — {error}",
    "amountSentTo": "تم إرسال {currency}{amount} إلى {recipient}",
    "recipientReceivesLabel": "يستلم المستلم:",
    "scanQrCode": "مسح رمز QR",
    "receive": "استلام",
    "createPaymentRequestDescription": "أدخل المبلغ وأضف العناصر. يمكن للعملاء مسح رمز QR للدفع لك فورًا.",
    "itemsHint": "مثال: أرز جولوف، دجاج، مشروبات",
    "qrCodeInfoForCustomer": "اعرض رمز QR هذا للعميل.\nيقوم بمسحه، ويؤكّد المبلغ، ثم يدفع فورًا!",
    "errorSavingQrCode": "خطأ أثناء حفظ رمز QR: {error}",
    "payRequestShareText": "ادفع {symbol}{amount} إلى {userName}",
    "shareWalletIdSubject": "رقم تعريف QR Wallet الخاص بي",
    "qrWalletAppName": "QR Wallet",
    "couldNotOpenWhatsAppToast": "تعذّر فتح WhatsApp. يُرجى التأكد من تثبيت WhatsApp.",
    "scanWithAnotherPhoneCaption": "امسح بهاتف آخر\nأو اضغط على «فتح WhatsApp» أدناه",
    "copiedToClipboard": "تم نسخ {label}",
    "referenceWithValue": "المرجع: {reference}",
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
10.ar-batch-5: Arabic translations for send & receive money flows (87 keys)

Translates 87 Arabic keys covering peer-to-peer send/receive flows,
QR scan/generate, payment requests, transaction errors, and WhatsApp
share, mirroring FR Batch 5:
- Send button & confirmation (5 keys, 1 ICU)
- Recipient lookup (4 keys)
- PIN confirmation (1 key)
- Send success & details (4 keys, 1 ICU)
- Total + verify details (2 keys)
- Currency conversion display (3 keys)
- Recipient labels (3 keys, 1 ICU)
- Send UI errors (4 keys)
- Transaction errors (10 keys)
- Payment verification (3 keys)
- Approve payment (1 key)
- Payment success/failure (4 keys)
- QR scan flow (4 keys)
- Receive flow (3 keys)
- Payment request creation (8 keys)
- Note + description (3 keys)
- QR code generation (5 keys, 3 ICU error keys)
- Storage permission (1 key)
- Pay-to-user labels (3 keys, 2 ICU)
- App name in share (1 key)
- WhatsApp share (3 keys)
- Scan caption (1 key)
- Clipboard / labels (3 keys, 2 ICU)
- Reference labels (3 keys, 1 ICU)

ICU placeholders preserved (verified by apply-script assertions, 11 ICU
keys with ~16 placeholder positions).

Convention notes:
- "إرسال" for send (verb / noun), "استلام" for receive
- "أموال" for money/funds
- "محفظة" for wallet, "رقم تعريف المحفظة" for wallet ID
- "المستلم" for recipient
- "رمز QR" for QR code (Latin "QR" preserved as universal acronym)
- "مسح" for scan (verb / noun), "امسح" for "scan!" imperative
- "إنشاء" for create/generate
- "العميل" for customer, "البائع" for seller
- "العنصر" / "العناصر" for item/items
- "ملاحظة" for note
- "الوصف" for description
- "اختياري/اختيارية" for optional
- "الحافظة" for clipboard
- "إذن التخزين" for storage permission
- "المعاينة" for preview
- "الإيداع" for deposit
- "مُصادَق عليه" for authenticated (passive participle)
- "ردّ" for response/reply (with shadda)
- "المرجع" for reference
- Latin guillemets « » preserved in scanWithAnotherPhoneCaption (used
  for inline quoted UI strings, common in Arabic-language UI)
- Em-dash — preserved in feeApproximateError
- Literal \\n newlines preserved in qrCodeInfoForCustomer and
  scanWithAnotherPhoneCaption
- Brand names kept Latin: QR Wallet, WhatsApp, QR (acronym), PIN

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_5_SEND_RECEIVE.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-5
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-5`
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
   git checkout phase6-step10-ar-batch-5
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
   git merge --ff-only phase6-step10-ar-batch-5
   git tag phase6-step10-ar-batch-5-complete
   git push origin main
   git push origin phase6-step10-ar-batch-5-complete
   git push origin :phase6-step10-ar-batch-5
   git branch -d phase6-step10-ar-batch-5
   ```

---

## 10. Translation conventions (extension to AR Batches 1-4b)

| Convention | Decision |
|---|---|
| (Earlier batches) Established conventions | Carry forward |
| **NEW (Batch 5)** Send (verb / noun) | "إرسال" |
| **NEW (Batch 5)** Receive | "استلام" |
| **NEW (Batch 5)** Recipient | "المستلم" |
| **NEW (Batch 5)** Customer | "العميل" |
| **NEW (Batch 5)** Seller / merchant | "البائع" |
| **NEW (Batch 5)** QR code | "رمز QR" |
| **NEW (Batch 5)** Scan (verb) | "مسح" / "امسح" (imperative) |
| **NEW (Batch 5)** Item / items | "عنصر / عناصر" |
| **NEW (Batch 5)** Optional | "اختياري / اختيارية" |
| **NEW (Batch 5)** Note | "ملاحظة" |
| **NEW (Batch 5)** Description | "الوصف" |
| **NEW (Batch 5)** Reference | "المرجع" |
| **NEW (Batch 5)** Clipboard | "الحافظة" |
| **NEW (Batch 5)** Permission | "إذن" |
| **NEW (Batch 5)** Storage | "التخزين" |
| **NEW (Batch 5)** Preview | "المعاينة" |
| **NEW (Batch 5)** Deposit | "الإيداع" |
| **NEW (Batch 5)** Authenticated | "مُصادَق عليه" |
| **NEW (Batch 5)** Response / reply | "ردّ" (with shadda) |
| **NEW (Batch 5)** Approximate (fees) | "تقريبي / تقريبية" |
| **NEW (Batch 5)** Generate / create | "إنشاء" |
| **NEW (Batch 5)** "Tap to copy" | "اضغط للنسخ" |
| **NEW (Batch 5)** Inline quoted UI label | French guillemets «...» (Arabic UI common usage) |
| **NEW (Batch 5)** QR Wallet, WhatsApp, QR, PIN | Stay Latin (brands/acronyms) |
| **NEW (Batch 5)** Jollof rice example | "أرز جولوف" (transliteration) |
