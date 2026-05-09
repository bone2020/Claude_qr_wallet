# Phase 6 Step 10 — Arabic Batch 2 — KYC Core Flow

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 2 of 9
> **Scope:** KYC Core Flow — 92 keys, 5 ICU
> **Predecessor:** `phase6-step10-ar-batch-1-complete` @ `4fa408d3`
> **Branch name to create:** `phase6-step10-ar-batch-2`
> **Tag to apply after merge:** `phase6-step10-ar-batch-2-complete`

---

## 1. Scope

This batch translates 92 Arabic keys covering the KYC core flow (mirroring the exact key set from French Batch 2):

- KYC main verification screen (19 keys, 2 ICU) — verify identity, document captured, verification status
- Document capture descriptions (2 keys)
- Photo capture options (9 keys) — take photo, upload, gallery, face scan
- Biometric error keys (11 keys, 1 ICU) — auth failure, lockout, no enrollment, passcode missing
- Smile ID result keys (12 keys) — face match, liveness, expired doc, mismatch, etc.
- KYC error keys (12 keys) — document upload, image size, session expired
- Generic error keys (11 keys) — auth, camera permission, document, server, timeout
- ID type & verification method (4 keys)
- ID number form (5 keys)
- Date of birth (2 keys)
- Country selector (3 keys, 1 ICU) — select country, search hint, dial code format

**Out of scope for this batch:**
- Auth & onboarding → Batch 1 (shipped)
- KYC ID-specific screens (Ghana Card, Passport, Driver's License, etc.) → Batch 3
- Wallet, send, receive screens → Batch 4 / Batch 5
- Transactions and disputes → Batch 6
- Profile, FAQ, settings, security → Batch 7
- Generic UI buttons, splash, app metadata → Batch 8

**Files this batch modifies:** `lib/l10n/app_ar.arb` only.

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_2_KYC_CORE.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-1-complete|phase6-step10-ar-batch-2-complete"
```

Expected:
- `phase6-step10-ar-batch-1-complete` MUST be present
- `phase6-step10-ar-batch-2-complete` MUST NOT be present

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
print(f"AR currently filled: {filled} keys (expected 91 = 1 itemCount + 90 from Batch 1)")
print(f"AR total: {len(ar_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 91 keys (expected 91 = 1 itemCount + 90 from Batch 1)`
- `AR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-2
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_ar_batch_2.py`, run, then verify and commit.

### 3.1 Translation data

The 92 Arabic translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (Arabic punctuation `؟ ،`, Latin brand tokens) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- KYC main verification screen (19 keys, 2 ICU) ---
    "verify": "تحقّق",
    "verifyButton": "تحقّق",
    "verifyIdentityDefaultDescription": "التحقّق من هويتك",
    "verifyYourIdentityTitle": "تحقّق من هويتك",
    "verifyYourDocumentTitle": "تحقّق من {documentType}",
    "documentCapturedTitle": "تم التقاط المستند",
    "documentCapturedBody": "تم التقاط {documentType}. ستبدأ عملية التحقّق عند المتابعة.",
    "verificationDescription": "سنلتقط مستندك ونأخذ صورة سيلفي للتحقّق من هويتك",
    "verificationDoNotCloseApp": "ستتم إعادة توجيهك تلقائيًا عند اكتمال التحقّق. لا تغلق التطبيق.",
    "verificationFailed": "فشل التحقّق. يُرجى المحاولة مجددًا.",
    "verificationFailedAgainError": "فشل التحقّق. يُرجى المحاولة مجددًا.",
    "verificationFailedMessage": "لم تنجح عملية التحقّق من هويتك. قد يكون السبب عدم تطابق الوجه أو مشكلة في المستند. يُرجى المحاولة مجددًا.",
    "verificationFailedTitle": "فشل التحقّق",
    "verificationFailedWithError": "فشل التحقّق: {error}",
    "verificationInProgressMessage": "جارٍ التحقّق من مستندات هويتك. تستغرق هذه العملية عادةً بضع ثوانٍ وقد تستغرق بضع دقائق.",
    "verificationInProgressTitle": "جارٍ التحقّق",
    "verificationSuccessful": "تم التحقّق بنجاح!",
    "startVerification": "بدء التحقّق",
    "checkingAutomatically": "جارٍ التحقّق تلقائيًا...",

    # --- Document capture descriptions (2 keys) ---
    "documentBothSidesAndSelfieDescription": "سنلتقط كلا وجهي مستند هويتك ونأخذ صورة سيلفي",
    "idAndSelfieVerificationDescription": "سنتحقّق من رقم هويتك ونأخذ صورة سيلفي للتأكيد",

    # --- Photo capture options (9 keys) ---
    "takePhoto": "التقط صورة",
    "takePhotoOption": "التقط صورة",
    "chooseFromGalleryOption": "اختر من المعرض",
    "uploadPhoto": "تحميل صورة",
    "uploadFront": "تحميل الوجه الأمامي",
    "uploadBack": "تحميل الوجه الخلفي",
    "uploadMainPage": "تحميل الصفحة الرئيسية",
    "faceScan": "مسح الوجه",
    "faceScanInstructions": "ضع وجهك داخل الإطار",

    # --- Biometric errors (11 keys, 1 ICU at biometricReasonConfirmPayment) ---
    "biometricErrorAuthenticationFailed": "فشل المصادقة",
    "biometricErrorFallback": "تعذّرت المصادقة. يُرجى المحاولة مجددًا.",
    "biometricErrorLockedOut": "عدد كبير من المحاولات الفاشلة. يُرجى المحاولة لاحقًا",
    "biometricErrorNoBiometricsEnrolled": "لا توجد بيانات بصمة مسجّلة على هذا الجهاز",
    "biometricErrorNotAvailable": "المصادقة البيومترية غير متاحة",
    "biometricErrorNotEnrolled": "لا توجد بيانات بصمة مسجّلة. يُرجى إعداد بصمة الإصبع أو التعرّف على الوجه في إعدادات الجهاز",
    "biometricErrorNotSupported": "المصادقة البيومترية غير مدعومة",
    "biometricErrorOtherOperatingSystem": "المصادقة البيومترية غير مدعومة على هذا الجهاز",
    "biometricErrorPasscodeNotSet": "يُرجى ضبط رمز مرور الجهاز لاستخدام المصادقة البيومترية",
    "biometricErrorPermanentlyLockedOut": "المصادقة البيومترية مقفلة. يُرجى إلغاء قفل الجهاز أولًا",
    "noBiometricsEnrolledToast": "لا توجد بيانات بصمة مسجّلة على هذا الجهاز. يُرجى إعداد بصمة الإصبع أو Face ID في إعدادات الجهاز.",
    "biometricReasonChangeSecurity": "استخدم بصمتك لتغيير إعدادات الأمان",
    "biometricReasonConfirmPayment": "استخدم بصمتك لتأكيد دفع {currencySymbol}{amount} إلى {recipient}",

    # --- Smile ID result keys (12 keys) ---
    "smileIdParseError": "تعذّر قراءة نتيجة التحقّق. يُرجى المحاولة مجددًا.",
    "smileIdResultCouldNotComplete": "تعذّر إكمال التحقّق. يُرجى المحاولة مجددًا.",
    "smileIdResultExpiredDoc": "المستند منتهي الصلاحية. يُرجى استخدام هوية سارية المفعول.",
    "smileIdResultFaceMatchFailed": "فشل التحقّق من الوجه. صورة السيلفي لا تتطابق مع صورة الهوية.",
    "smileIdResultFaceNotDetected": "لم يتم اكتشاف الوجه. يُرجى التأكد من ظهور وجهك بوضوح وإضاءة جيّدة.",
    "smileIdResultIdDocFailed": "تعذّر التحقّق من مستند الهوية. يُرجى المحاولة بمستند آخر.",
    "smileIdResultInfoMismatch": "معلومات الهوية غير متطابقة. يُرجى التأكد من إدخال المعلومات الصحيحة.",
    "smileIdResultLivenessFailed": "فشل اختبار الحيوية. يُرجى اتّباع التعليمات على الشاشة بدقّة.",
    "smileIdResultMultipleFacesDetected": "تم اكتشاف أكثر من وجه. يُرجى التأكد من وجود وجهك فقط داخل الإطار.",
    "smileIdResultPoorImageQuality": "جودة الصورة منخفضة. يُرجى التأكد من إضاءة جيّدة وصورة واضحة.",
    "smileIdResultUnsupportedDoc": "نوع المستند غير مدعوم. يُرجى المحاولة بنوع هوية آخر.",
    "smileIdResultVerified": "تم التحقّق بنجاح!",

    # --- KYC errors (12 keys) ---
    "kycErrorDocumentUploadGeneric": "فشل تحميل المستند. يُرجى المحاولة مجددًا.",
    "kycErrorDocumentUploadNetwork": "فشل تحميل المستند. يُرجى التحقّق من الاتصال والمحاولة مجددًا.",
    "kycErrorImageTooLarge": "ملف الصورة كبير جدًا. يُرجى استخدام صورة أصغر.",
    "kycErrorNotSignedIn": "أنت غير مسجّل الدخول. يُرجى تسجيل الدخول والمحاولة مجددًا.",
    "kycErrorPhoneVerificationEnter6DigitCode": "يُرجى إدخال الرمز المكوّن من 6 أرقام",
    "kycErrorPhoneVerificationNoPhoneNumber": "لم يتم العثور على رقم هاتف في حسابك. يُرجى الرجوع وإدخاله مرة أخرى.",
    "kycErrorPleaseCompleteSmileId": "يُرجى إكمال التحقّق عبر Smile ID",
    "kycErrorPleaseEnterCardNumber": "يُرجى إدخال رقم البطاقة",
    "kycErrorPleaseSelectDateOfBirth": "يُرجى تحديد تاريخ ميلادك",
    "kycErrorPleaseSelectDateOfBirthBeforeSelfie": "يُرجى تحديد تاريخ ميلادك قبل التقاط السيلفي",
    "kycErrorSomethingWentWrong": "حدث خطأ ما. يُرجى المحاولة مجددًا.",
    "kycErrorVerificationSessionExpired": "انتهت صلاحية جلسة التحقّق. يُرجى إعادة التقاط السيلفي.",

    # --- Generic errors (11 keys) ---
    "genericErrorAuth": "انتهت صلاحية جلستك. يُرجى تسجيل الدخول مجددًا للمتابعة.",
    "genericErrorCameraPermission": "الوصول إلى الكاميرا مطلوب للتحقّق. يُرجى تفعيل أذونات الكاميرا في إعدادات الجهاز.",
    "genericErrorDocument": "تعذّر علينا قراءة مستندك بوضوح. يُرجى التأكد من إضاءة المستند بشكل جيد، وأنه مسطّح، وأن جميع النصوص مرئية.",
    "genericErrorFaceDetection": "تعذّر علينا اكتشاف وجهك بوضوح. يُرجى التأكد من إضاءة جيّدة ووضع وجهك داخل الإطار.",
    "genericErrorFaceMismatch": "فشل التحقّق من الوجه. صورة السيلفي لا تتطابق مع صورة الهوية. يُرجى التأكد من استخدام مستند هويتك الشخصية.",
    "genericErrorFallback": "حدث خطأ. يُرجى المحاولة مجددًا أو الاتصال بالدعم إذا استمرت المشكلة.",
    "genericErrorIdVerification": "فشل التحقّق من الهوية. يُرجى التأكد من أن مستند هويتك ساري المفعول وغير منتهي الصلاحية وأن المعلومات المُدخلة صحيحة.",
    "genericErrorNetwork": "تعذّر الاتصال. يُرجى التحقّق من اتصالك بالإنترنت والمحاولة مجددًا.",
    "genericErrorServer": "خدمة التحقّق لدينا غير متاحة مؤقتًا. يُرجى المحاولة مرة أخرى خلال بضع دقائق.",
    "genericErrorTimeout": "استغرقت العملية وقتًا طويلًا. يُرجى التحقّق من اتصالك والمحاولة مجددًا.",
    "genericErrorUserCancelled": "تم إلغاء التحقّق. يمكنك المحاولة مجددًا عندما تكون جاهزًا.",

    # --- ID type & verification method (4 keys) ---
    "selectIdType": "اختر نوع الهوية",
    "selectVerificationMethod": "اختر طريقة التحقّق",
    "selectVerificationMethodSubtitle": "اختر نوع الهوية المفضّل لديك للتحقّق من هويتك",
    "governmentId": "هوية حكومية رسمية",

    # --- ID number form (5 keys) ---
    "idNumberLabel": "رقم الهوية",
    "idNumberRequired": "رقم الهوية مطلوب للتحقّق",
    "enterIdNumber": "أدخل رقم الهوية",
    "enterIdNumberHint": "أدخل رقم هويتك المكوّن من 13 رقمًا",
    "invalidIdNumberFallback": "رقم الهوية غير صحيح",

    # --- Date of birth (2 keys) ---
    "dateOfBirth": "تاريخ الميلاد",
    "selectDate": "اختر التاريخ",

    # --- Country selector (3 keys, 1 ICU) ---
    "selectCountryTitle": "اختر البلد",
    "searchCountryHint": "ابحث عن بلد...",
    "countryDisplayFormat": "{dialCode} • {symbol} {code}",
}

assert len(TRANSLATIONS) == 92, f"Spec dict has {len(TRANSLATIONS)} entries, expected 92"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_2.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 2 - KYC Core Flow
Applies 92 Arabic translations to lib/l10n/app_ar.arb.
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
    # Sanity: dict size
    assert len(TRANSLATIONS) == 92, f"Expected 92 translations, got {len(TRANSLATIONS)}"

    # Load files
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

    # Verify: ICU placeholder preservation (5 ICU keys)
    assert "{documentType}" in ar["verifyYourDocumentTitle"], "verifyYourDocumentTitle lost {documentType}"
    assert "{documentType}" in ar["documentCapturedBody"], "documentCapturedBody lost {documentType}"
    assert "{error}" in ar["verificationFailedWithError"], "verificationFailedWithError lost {error}"
    assert "{currencySymbol}" in ar["biometricReasonConfirmPayment"], \
        "biometricReasonConfirmPayment lost {currencySymbol}"
    assert "{amount}" in ar["biometricReasonConfirmPayment"], \
        "biometricReasonConfirmPayment lost {amount}"
    assert "{recipient}" in ar["biometricReasonConfirmPayment"], \
        "biometricReasonConfirmPayment lost {recipient}"
    assert "{dialCode}" in ar["countryDisplayFormat"], "countryDisplayFormat lost {dialCode}"
    assert "{symbol}" in ar["countryDisplayFormat"], "countryDisplayFormat lost {symbol}"
    assert "{code}" in ar["countryDisplayFormat"], "countryDisplayFormat lost {code}"

    # Verify: brand names preserved in Latin script
    assert "Smile ID" in ar["kycErrorPleaseCompleteSmileId"], \
        "kycErrorPleaseCompleteSmileId lost Smile ID brand"
    assert "Face ID" in ar["noBiometricsEnrolledToast"], \
        "noBiometricsEnrolledToast lost Face ID brand"

    # Verify: bullet character • preserved in countryDisplayFormat
    assert "•" in ar["countryDisplayFormat"], "countryDisplayFormat lost • bullet"

    # Verify: Arabic Unicode characters present (sanity check)
    assert any('\u0600' <= ch <= '\u06FF' for ch in ar["verify"]), \
        "verify appears to have no Arabic characters"
    assert any('\u0600' <= ch <= '\u06FF' for ch in ar["verificationFailed"]), \
        "verificationFailed appears to have no Arabic characters"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for Arabic)
    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 91, expected {91 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_2.py
```

Expected output:
```
OK — applied 92 translations
AR filled: 183/701 (was 91, expected 183)
AR empty: 518
```

If any assertion fires, STOP and report.

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

Expected: EN=701, AR=701, Match=True, AR filled=183.

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
    "verify": "تحقّق",
    "verifyYourIdentityTitle": "تحقّق من هويتك",
    "verifyYourDocumentTitle": "تحقّق من {documentType}",
    "documentCapturedBody": "تم التقاط {documentType}. ستبدأ عملية التحقّق عند المتابعة.",
    "verificationFailedWithError": "فشل التحقّق: {error}",
    "verificationSuccessful": "تم التحقّق بنجاح!",
    "takePhoto": "التقط صورة",
    "uploadFront": "تحميل الوجه الأمامي",
    "biometricErrorAuthenticationFailed": "فشل المصادقة",
    "biometricReasonConfirmPayment": "استخدم بصمتك لتأكيد دفع {currencySymbol}{amount} إلى {recipient}",
    "noBiometricsEnrolledToast": "لا توجد بيانات بصمة مسجّلة على هذا الجهاز. يُرجى إعداد بصمة الإصبع أو Face ID في إعدادات الجهاز.",
    "smileIdResultVerified": "تم التحقّق بنجاح!",
    "kycErrorPleaseCompleteSmileId": "يُرجى إكمال التحقّق عبر Smile ID",
    "genericErrorCameraPermission": "الوصول إلى الكاميرا مطلوب للتحقّق. يُرجى تفعيل أذونات الكاميرا في إعدادات الجهاز.",
    "selectIdType": "اختر نوع الهوية",
    "idNumberLabel": "رقم الهوية",
    "dateOfBirth": "تاريخ الميلاد",
    "selectCountryTitle": "اختر البلد",
    "countryDisplayFormat": "{dialCode} • {symbol} {code}",
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

Confirm staged files are exactly: `lib/l10n/app_ar.arb`. Nothing else. Unstage `lib/generated/l10n/` or any `.py` file at the repo root if they appear.

```bash
cat > /tmp/commit_msg.txt << 'EOF'
10.ar-batch-2: Arabic translations for KYC core flow (92 keys)

Translates 92 Arabic keys covering the KYC core flow, mirroring the
exact key set from French Batch 2:
- KYC main verification screen (19 keys, 2 ICU)
- Document capture descriptions (2 keys)
- Photo capture options (9 keys) — take photo, upload, gallery, face scan
- Biometric error keys (11 keys, 1 ICU at biometricReasonConfirmPayment)
- Smile ID result keys (12 keys)
- KYC error keys (12 keys)
- Generic error keys (11 keys)
- ID type & verification method (4 keys)
- ID number form (5 keys)
- Date of birth (2 keys)
- Country selector (3 keys, 1 ICU)

ICU placeholders preserved (verified by apply-script assertions, 5 ICU
keys with 9 placeholder positions): verifyYourDocumentTitle
({documentType}), documentCapturedBody ({documentType}),
verificationFailedWithError ({error}), biometricReasonConfirmPayment
({currencySymbol}, {amount}, {recipient}), countryDisplayFormat
({dialCode}, {symbol}, {code}).

Convention notes:
- "تحقّق" / "التحقّق" for verify/verification (with shadda)
- "هوية" for identity, "مستند" for document
- "سيلفي" for selfie (transliteration, common in Arabic UI)
- "بصمة" for biometric/fingerprint
- "كاميرا" for camera (transliteration)
- "بيومتري" for biometric (adjective form)
- "حيوية" for liveness (medical/technical term)
- "Face ID" kept Latin (brand)
- "Smile ID" kept Latin (brand)
- "ساري المفعول" for "valid" (legal context for IDs)
- "منتهي الصلاحية" for "expired"
- "هوية حكومية رسمية" for "Government ID"
- "تاريخ الميلاد" for date of birth
- "ضع وجهك داخل الإطار" for "place your face in the frame"
- "•" bullet preserved in countryDisplayFormat (matches EN/FR format)

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_2_KYC_CORE.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-2
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-2`
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

1. Pull the branch:
   ```bash
   git fetch origin
   git checkout phase6-step10-ar-batch-2
   git pull
   ```

2. Run gen-l10n:
   ```bash
   flutter gen-l10n
   ```

3. Confirm gen-l10n only modified `lib/generated/l10n/`:
   ```bash
   git diff --stat
   ```

4. Run analyzer + build:
   ```bash
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```
   Expected: 204 issues, build green.

5. Sync guard, discard generated, ff-merge, tag, push:
   ```bash
   git fetch origin
   local_main=$(git rev-parse main)
   origin_main=$(git rev-parse origin/main)
   [ "$local_main" = "$origin_main" ] || { echo "FAIL — sync"; exit 1; }
   git checkout -- lib/generated/l10n/
   git checkout main
   git merge --ff-only phase6-step10-ar-batch-2
   git tag phase6-step10-ar-batch-2-complete
   git push origin main
   git push origin phase6-step10-ar-batch-2-complete
   git push origin :phase6-step10-ar-batch-2
   git branch -d phase6-step10-ar-batch-2
   ```

---

## 10. Translation conventions (extension to AR Batch 1)

Adds the KYC-specific terms to the Arabic conventions table from AR Batch 1.

| Convention | Decision |
|---|---|
| (Batch 1) Register | Formal MSA |
| (Batch 1) Brand names | Stay in Latin script |
| **NEW (Batch 2)** Verify (verb / noun) | "تحقّق" / "التحقّق" |
| **NEW (Batch 2)** Identity | "هوية" |
| **NEW (Batch 2)** Document | "مستند" |
| **NEW (Batch 2)** Selfie | "سيلفي" (transliteration) |
| **NEW (Batch 2)** Biometric (adj) | "بيومتري" |
| **NEW (Batch 2)** Biometric / fingerprint (noun) | "بصمة" |
| **NEW (Batch 2)** Authentication | "مصادقة" / "المصادقة" |
| **NEW (Batch 2)** Camera | "كاميرا" |
| **NEW (Batch 2)** Photo | "صورة" |
| **NEW (Batch 2)** Gallery | "المعرض" |
| **NEW (Batch 2)** Face | "الوجه" / "وجه" |
| **NEW (Batch 2)** Frame (camera) | "الإطار" |
| **NEW (Batch 2)** Liveness | "اختبار الحيوية" |
| **NEW (Batch 2)** Upload | "تحميل" |
| **NEW (Batch 2)** Front (of ID) | "الوجه الأمامي" |
| **NEW (Batch 2)** Back (of ID) | "الوجه الخلفي" |
| **NEW (Batch 2)** Government ID | "هوية حكومية رسمية" |
| **NEW (Batch 2)** ID number | "رقم الهوية" |
| **NEW (Batch 2)** Date of birth | "تاريخ الميلاد" |
| **NEW (Batch 2)** Country | "بلد" / "البلد" |
| **NEW (Batch 2)** Search hint | "ابحث عن..." |
| **NEW (Batch 2)** Valid (legal/IDs) | "ساري المفعول" |
| **NEW (Batch 2)** Expired (legal/IDs) | "منتهي الصلاحية" |
| **NEW (Batch 2)** "in progress" | "جارٍ" (with sukun on the ya) |
| **NEW (Batch 2)** "automatically" | "تلقائيًا" (with tanwin) |
| **NEW (Batch 2)** "Could not [X]" | "تعذّر [X]" |
| **NEW (Batch 2)** "Failed to [X]" | "فشل [X]" |
| **NEW (Batch 2)** Smile ID, Face ID | Stay Latin (brands) |
