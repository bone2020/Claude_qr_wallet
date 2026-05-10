# Phase 6 Step 10 — Arabic Batch 8 — System Errors, Generic UI, Cleanup

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 8 of 9 — **FINAL ARABIC BATCH**
> **Scope:** App name/tagline, Auth errors (provider-level + Firebase), Generic UI buttons, Generic errors, Firebase auth error fallbacks, Splash/loading, User errors — 80 keys, 3 ICU
> **Predecessor:** `phase6-step10-ar-batch-7-complete` @ `5b4ccff3`
> **Branch name to create:** `phase6-step10-ar-batch-8`
> **Tag to apply after merge:** `phase6-step10-ar-batch-8-complete`
> **Aggregate tag (operator only, after merge):** `phase6-step10-ar-translations-complete`

---

## 1. Scope

This batch translates the final 80 Arabic keys (mirroring the exact key set from French Batch 8). After this lands, Arabic will be 701/701 — complete.

- App identity (2 keys) — name, tagline
- Auth provider errors (23 keys) — Apple/Google sign-in, Firebase auth errors, OTP, fallbacks
- Generic UI buttons (16 keys) — back, cancel, close, confirm, continue, done, download, next, OK, retry, save, share, try again
- Generic form errors (10 keys, 1 ICU) — required, invalid email/OTP/phone, network, password mismatch/weak, user-not-found, with-message
- Failed-to-remove error (1 key, 1 ICU)
- Firebase auth error UX (11 keys) — friendlier user-facing messages
- Splash / loading (4 keys) — home, loading placeholder, please wait, quick select
- Page-not-found (1 key, 1 ICU)
- Phone verification (1 key)
- Offline state (1 key)
- TPIN hint (1 key)
- User errors (4 keys) — fallback, ID front image required, no updates, not authenticated

After this batch ships, the operator creates the aggregate tag `phase6-step10-ar-translations-complete`.

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_8_SYSTEM_CLEANUP.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-7-complete|phase6-step10-ar-batch-8-complete|phase6-step10-ar-translations-complete"
```

Expected:
- `phase6-step10-ar-batch-7-complete` MUST be present
- `phase6-step10-ar-batch-8-complete` MUST NOT be present
- `phase6-step10-ar-translations-complete` MUST NOT be present

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
empty = sum(1 for k in ar_keys if ar[k] == '')
print(f"AR currently filled: {filled} keys (expected 621 = Batches 1-7 + itemCount)")
print(f"AR currently empty:  {empty} keys (expected 80 — this batch fills them all)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 621 keys`
- `AR currently empty:  80 keys`
- `AR total: 701`
- `Key sets match: True`

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-8
```

---

## 3. Implementation

### 3.1 Translation data

The 80 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Brand names (QR Wallet, Apple, Google), Latin acronyms (OTP, TPIN), and Arabic punctuation MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- App identity (2) ---
    "appName": "QR Wallet",
    "appTagline": "مدفوعات سلسة، في كل مكان",

    # --- Auth provider errors (23) ---
    "authErrorAppleSignInCancelled": "تم إلغاء تسجيل الدخول عبر Apple",
    "authErrorAppleSignInFailed": "فشل تسجيل الدخول عبر Apple",
    "authErrorFailedToCreateUser": "فشل إنشاء المستخدم",
    "authErrorFailedToSignIn": "فشل تسجيل الدخول",
    "authErrorFailedToSignInWithApple": "فشل تسجيل الدخول عبر Apple",
    "authErrorFailedToSignInWithGoogle": "فشل تسجيل الدخول عبر Google",
    "authErrorFailedToVerifyOtp": "فشل التحقّق من OTP",
    "authErrorFallback": "حدث خطأ. يُرجى المحاولة مجددًا",
    "authErrorFirebaseAccountNotFound": "لم يتم العثور على حساب بهذا البريد الإلكتروني",
    "authErrorFirebaseCredentialAlreadyInUse": "رقم الهاتف هذا مرتبط بالفعل بحساب آخر",
    "authErrorFirebaseEmailAlreadyInUse": "يوجد حساب بالفعل بهذا البريد الإلكتروني",
    "authErrorFirebaseInvalidEmail": "يُرجى إدخال بريد إلكتروني صحيح",
    "authErrorFirebaseInvalidVerificationCode": "رمز OTP غير صحيح. يُرجى المحاولة مجددًا",
    "authErrorFirebaseInvalidVerificationId": "انتهت صلاحية جلسة التحقّق. يُرجى طلب رمز جديد",
    "authErrorFirebaseNetworkRequestFailed": "خطأ في الشبكة. يُرجى التحقّق من اتصالك",
    "authErrorFirebaseTooManyRequests": "عدد كبير من المحاولات. يُرجى المحاولة لاحقًا",
    "authErrorFirebaseWeakPassword": "يجب أن تتكوّن كلمة المرور من 6 أحرف على الأقل",
    "authErrorFirebaseWrongPassword": "كلمة المرور غير صحيحة",
    "authErrorGoogleSignInCancelled": "تم إلغاء تسجيل الدخول عبر Google",
    "authErrorNoUserLoggedIn": "لا يوجد مستخدم مسجّل الدخول",
    "authErrorNoVerificationId": "لا يوجد رقم تعريف للتحقّق. يُرجى طلب OTP مجددًا.",
    "authErrorUserDataNotFound": "بيانات المستخدم غير موجودة",
    "authErrorUserNotFound": "المستخدم غير موجود",

    # --- Generic UI buttons (16) ---
    "back": "رجوع",
    "cancel": "إلغاء",
    "checkNowButton": "تحقّق الآن",
    "close": "إغلاق",
    "closeButton": "إغلاق",
    "confirm": "تأكيد",
    "confirmButton": "تأكيد",
    "continueText": "متابعة",
    "done": "تم",
    "doneButton": "تم",
    "downloadButton": "تنزيل",
    "goBackButton": "رجوع",
    "next": "التالي",
    "ok": "موافق",
    "retry": "إعادة المحاولة",
    "save": "حفظ",
    "shareButton": "مشاركة",
    "tryAgainButton": "إعادة المحاولة",

    # --- Generic form errors (10, 1 ICU) ---
    "errorFieldRequired": "هذا الحقل مطلوب",
    "errorGeneric": "حدث خطأ. يُرجى المحاولة مجددًا.",
    "errorInvalidEmail": "يُرجى إدخال بريد إلكتروني صحيح",
    "errorInvalidOtp": "OTP غير صحيح. يُرجى المحاولة مجددًا.",
    "errorInvalidPhone": "يُرجى إدخال رقم هاتف صحيح",
    "errorNetwork": "لا يوجد اتصال بالإنترنت. يُرجى التحقّق من شبكتك.",
    "errorPasswordMismatch": "كلمتا المرور غير متطابقتين",
    "errorPasswordWeak": "يجب أن تتكوّن كلمة المرور من 8 أحرف على الأقل",
    "errorUserNotFound": "المستخدم غير موجود",
    "errorWithMessage": "خطأ: {message}",
    "errorWrongPassword": "كلمة المرور غير صحيحة",
    "somethingWentWrongTryAgain": "حدث خطأ. يُرجى المحاولة مجددًا.",

    # --- Failed-to-remove (1, 1 ICU) ---
    "failedToRemoveError": "فشل الحذف: {error}",

    # --- Firebase auth UX errors (11) ---
    "firebaseAuthErrorEmailAlreadyInUse": "هذا البريد الإلكتروني مسجّل بالفعل. يُرجى تسجيل الدخول بدلًا من ذلك.",
    "firebaseAuthErrorFallback": "حدث خطأ. يُرجى المحاولة مجددًا.",
    "firebaseAuthErrorInvalidEmail": "يُرجى إدخال بريد إلكتروني صحيح.",
    "firebaseAuthErrorInvalidPhone": "يُرجى إدخال رقم هاتف صحيح.",
    "firebaseAuthErrorInvalidVerificationCode": "رمز التحقّق غير صحيح. يُرجى التحقّق والمحاولة مجددًا.",
    "firebaseAuthErrorNetwork": "تعذّر الاتصال. يُرجى التحقّق من اتصالك بالإنترنت.",
    "firebaseAuthErrorOperationNotAllowed": "ليس لديك إذن بتنفيذ هذا الإجراء.",
    "firebaseAuthErrorServiceUnavailable": "الخدمة غير متاحة مؤقتًا. يُرجى المحاولة لاحقًا.",
    "firebaseAuthErrorTooManyRequests": "عدد كبير من المحاولات. يُرجى الانتظار بضع دقائق والمحاولة مجددًا.",
    "firebaseAuthErrorUserNotFound": "الحساب غير موجود. يُرجى التحقّق من بيانات الدخول أو إنشاء حساب.",
    "firebaseAuthErrorWeakPassword": "كلمة المرور ضعيفة جدًا. يُرجى استخدام 6 أحرف على الأقل.",
    "firebaseAuthErrorWrongPassword": "كلمة المرور غير صحيحة. يُرجى المحاولة مجددًا.",

    # --- Splash / loading / nav (4) ---
    "home": "الرئيسية",
    "loadingPlaceholder": "جارٍ التحميل...",
    "pleaseWait": "يُرجى الانتظار...",
    "quickSelectLabel": "اختيار سريع",

    # --- Page not found (1, 1 ICU) ---
    "pageNotFound": "الصفحة غير موجودة: {uri}",

    # --- Phone verification title (1) ---
    "phoneVerificationAppBarTitle": "التحقّق من الهاتف",

    # --- Offline state (1) ---
    "youAreOffline": "أنت غير متّصل بالإنترنت",

    # --- TPIN hint (1) ---
    "enterTpinHint": "أدخل TPIN المكوّن من 10 أرقام",

    # --- User errors (4) ---
    "userErrorFallback": "تعذّر إكمال الإجراء. يُرجى المحاولة مجددًا.",
    "userErrorIdFrontImageRequired": "صورة الوجه الأمامي للهوية مطلوبة",
    "userErrorNoUpdatesProvided": "لم يتم تقديم أي تحديثات",
    "userErrorUserNotAuthenticated": "المستخدم غير مُصادَق عليه",
}

assert len(TRANSLATIONS) == 80, f"Spec dict has {len(TRANSLATIONS)} entries, expected 80"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_8.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 8 - System Errors, Generic UI, Cleanup
FINAL ARABIC BATCH. Applies 80 Arabic translations to lib/l10n/app_ar.arb.
After this commit, AR is 100% translated.
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
    assert len(TRANSLATIONS) == 80, f"Expected 80 translations, got {len(TRANSLATIONS)}"

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

    # ICU placeholder preservation (3 ICU keys)
    assert "{message}" in ar["errorWithMessage"], "errorWithMessage lost {message}"
    assert "{error}" in ar["failedToRemoveError"], "failedToRemoveError lost {error}"
    assert "{uri}" in ar["pageNotFound"], "pageNotFound lost {uri}"

    # Brand names preserved (Latin)
    assert ar["appName"] == "QR Wallet", "appName must remain Latin 'QR Wallet'"
    assert "Apple" in ar["authErrorAppleSignInCancelled"], "authErrorAppleSignInCancelled lost Apple"
    assert "Apple" in ar["authErrorAppleSignInFailed"], "authErrorAppleSignInFailed lost Apple"
    assert "Apple" in ar["authErrorFailedToSignInWithApple"], "authErrorFailedToSignInWithApple lost Apple"
    assert "Google" in ar["authErrorFailedToSignInWithGoogle"], "authErrorFailedToSignInWithGoogle lost Google"
    assert "Google" in ar["authErrorGoogleSignInCancelled"], "authErrorGoogleSignInCancelled lost Google"
    assert "OTP" in ar["authErrorFailedToVerifyOtp"], "authErrorFailedToVerifyOtp lost OTP"
    assert "OTP" in ar["authErrorFirebaseInvalidVerificationCode"], "authErrorFirebaseInvalidVerificationCode lost OTP"
    assert "OTP" in ar["authErrorNoVerificationId"], "authErrorNoVerificationId lost OTP"
    assert "OTP" in ar["errorInvalidOtp"], "errorInvalidOtp lost OTP"
    assert "TPIN" in ar["enterTpinHint"], "enterTpinHint lost TPIN"

    # Arabic Unicode characters present in sample keys
    for k in ["appTagline", "back", "cancel", "home", "youAreOffline"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 621, expected 701 — 100%)")
    print(f"AR empty: {empty_after} (expected 0)")
    if filled_after == len(ar_keys) and empty_after == 0:
        print("ARABIC TRANSLATION 100% COMPLETE")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_8.py
```

Expected:
```
OK — applied 80 translations
AR filled: 701/701 (was 621, expected 701 — 100%)
AR empty: 0 (expected 0)
ARABIC TRANSLATION 100% COMPLETE
```

---

## 4. Verification

### 4.1 Confirm only app_ar.arb changed

```bash
git status
```

### 4.2 Confirm key parity en/ar AND 100% completeness

```bash
python3 << 'PYEOF'
import json
en = json.load(open('lib/l10n/app_en.arb'))
ar = json.load(open('lib/l10n/app_ar.arb'))
fr = json.load(open('lib/l10n/app_fr.arb'))
en_keys = {k for k in en if not k.startswith('@')}
ar_keys = {k for k in ar if not k.startswith('@')}
fr_keys = {k for k in fr if not k.startswith('@')}
ar_filled = sum(1 for k in ar_keys if ar[k] != '')
fr_filled = sum(1 for k in fr_keys if fr[k] != '')
print(f"EN keys: {len(en_keys)}")
print(f"AR keys: {len(ar_keys)}")
print(f"FR keys: {len(fr_keys)}")
print(f"Match: {en_keys == ar_keys}")
print(f"AR filled: {ar_filled}/{len(ar_keys)}")
print(f"FR filled: {fr_filled}/{len(fr_keys)}")
if ar_filled == len(ar_keys):
    print("AR IS 100% COMPLETE")
PYEOF
```

Expected: 701, 701, 701, True, AR=701/701, FR=701/701, "AR IS 100% COMPLETE".

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
    "appName": "QR Wallet",
    "appTagline": "مدفوعات سلسة، في كل مكان",
    "authErrorAppleSignInCancelled": "تم إلغاء تسجيل الدخول عبر Apple",
    "authErrorFailedToSignInWithGoogle": "فشل تسجيل الدخول عبر Google",
    "authErrorFailedToVerifyOtp": "فشل التحقّق من OTP",
    "authErrorFallback": "حدث خطأ. يُرجى المحاولة مجددًا",
    "authErrorFirebaseEmailAlreadyInUse": "يوجد حساب بالفعل بهذا البريد الإلكتروني",
    "back": "رجوع",
    "cancel": "إلغاء",
    "ok": "موافق",
    "save": "حفظ",
    "tryAgainButton": "إعادة المحاولة",
    "errorFieldRequired": "هذا الحقل مطلوب",
    "errorWithMessage": "خطأ: {message}",
    "failedToRemoveError": "فشل الحذف: {error}",
    "firebaseAuthErrorOperationNotAllowed": "ليس لديك إذن بتنفيذ هذا الإجراء.",
    "firebaseAuthErrorUserNotFound": "الحساب غير موجود. يُرجى التحقّق من بيانات الدخول أو إنشاء حساب.",
    "home": "الرئيسية",
    "loadingPlaceholder": "جارٍ التحميل...",
    "pageNotFound": "الصفحة غير موجودة: {uri}",
    "youAreOffline": "أنت غير متّصل بالإنترنت",
    "enterTpinHint": "أدخل TPIN المكوّن من 10 أرقام",
    "userErrorIdFrontImageRequired": "صورة الوجه الأمامي للهوية مطلوبة",
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
10.ar-batch-8: Arabic translations for system errors, generic UI, cleanup (80 keys) — ARABIC COMPLETE

Translates the final 80 Arabic keys for Phase 6 Step 10, mirroring
FR Batch 8. After this commit, app_ar.arb is 701/701 — Arabic
translation is complete.

Coverage:
- App identity (2 keys) — name (kept Latin), tagline
- Auth provider errors (23 keys)
- Generic UI buttons (16 keys)
- Generic form errors (10 keys, 1 ICU)
- Failed-to-remove error (1 key, 1 ICU)
- Firebase auth UX errors (11 keys)
- Splash / loading / nav (4 keys)
- Page not found (1 key, 1 ICU)
- Phone verification title (1 key)
- Offline state (1 key)
- TPIN hint (1 key)
- User errors (4 keys)

ICU placeholders preserved (verified by apply-script assertions, 3 ICU
keys): errorWithMessage ({message}), failedToRemoveError ({error}),
pageNotFound ({uri}).

Convention notes:
- "QR Wallet" appName kept verbatim Latin (brand)
- "مدفوعات سلسة، في كل مكان" for "Seamless payments, everywhere"
  (Arabic comma ، used)
- "Apple" / "Google" kept Latin (brands)
- "OTP" / "TPIN" kept Latin (acronyms)
- "الرئيسية" for home (literally "the main", standard for nav home)
- "رجوع" for back (verb), distinct from "العودة" (noun "return")
- "موافق" for OK (literally "agreed/agree")
- "إعادة المحاولة" for retry / try again
- "حفظ" for save
- "متابعة" for continue (verb)
- "تنزيل" for download
- "مشاركة" for share
- "إلغاء" for cancel
- "تأكيد" for confirm
- "تم" for done (perfective verb)
- "كلمتا المرور" — dual form for "two passwords" in mismatch error
- "الحساب غير موجود" for "account not found" (consistent with Batch 5)
- "ليس لديك إذن" for "you don't have permission"
- "الخدمة غير متاحة مؤقتًا" for "service temporarily unavailable"
- "أنت غير متّصل بالإنترنت" for "you are offline"
- "حدث خطأ" used consistently for "an error occurred"
- "تعذّر" / "فشل" distinction maintained (soft vs hard failure)
- Counted noun: "10 أرقام" (paucal plural for 3-10), "8 أحرف" / "6 أحرف"
  (paucal for letters/characters)

Files modified: lib/l10n/app_ar.arb only.

After this batch ships:
- AR: 701/701 (100%)
- FR: 701/701 (100%)
- Aggregate tag: phase6-step10-ar-translations-complete

Reference: docs/PHASE_6_STEP_10_AR_BATCH_8_SYSTEM_CLEANUP.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-8
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-8`
2. Final commit SHA
3. Output of all verification steps (4.1, 4.2, 4.3, 4.4)
4. Output of the apply script (should report 100% complete)
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

## 9. After agent reports back — operator's tasks (extended for final batch)

1. Pull, regen, analyze, build:
   ```bash
   git fetch origin
   git checkout phase6-step10-ar-batch-8
   git pull
   flutter gen-l10n
   git diff --stat
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```
   Expected: 204 issues, build green.

2. Sync guard, discard generated, ff-merge, **TWO TAGS** (batch + aggregate), push:
   ```bash
   git fetch origin
   local_main=$(git rev-parse main)
   origin_main=$(git rev-parse origin/main)
   [ "$local_main" = "$origin_main" ] || { echo "FAIL — sync"; exit 1; }
   git checkout -- lib/generated/l10n/
   git checkout main
   git merge --ff-only phase6-step10-ar-batch-8
   git tag phase6-step10-ar-batch-8-complete
   git tag phase6-step10-ar-translations-complete
   git push origin main
   git push origin phase6-step10-ar-batch-8-complete
   git push origin phase6-step10-ar-translations-complete
   git push origin :phase6-step10-ar-batch-8
   git branch -d phase6-step10-ar-batch-8
   ```

3. Final celebration check:
   ```bash
   python3 << 'PYEOF'
   import json
   ar = json.load(open('lib/l10n/app_ar.arb'))
   fr = json.load(open('lib/l10n/app_fr.arb'))
   en = json.load(open('lib/l10n/app_en.arb'))
   ar_keys = {k for k in ar if not k.startswith('@')}
   fr_keys = {k for k in fr if not k.startswith('@')}
   en_keys = {k for k in en if not k.startswith('@')}
   ar_filled = sum(1 for k in ar_keys if ar[k] != '')
   fr_filled = sum(1 for k in fr_keys if fr[k] != '')
   print(f"EN: {len(en_keys)}/{len(en_keys)} (source)")
   print(f"FR: {fr_filled}/{len(fr_keys)}")
   print(f"AR: {ar_filled}/{len(ar_keys)}")
   if ar_filled == len(ar_keys) and fr_filled == len(fr_keys):
       print()
       print("Phase 6 Step 10: BOTH TRANSLATIONS COMPLETE")
   PYEOF
   ```

---

## 10. Translation conventions (extension to AR Batches 1-7) — FINAL

| Convention | Decision |
|---|---|
| (Earlier batches) Established conventions | Carry forward |
| **NEW (Batch 8)** App name | Stay Latin "QR Wallet" |
| **NEW (Batch 8)** Tagline | "مدفوعات سلسة، في كل مكان" (Arabic comma ، used) |
| **NEW (Batch 8)** Apple / Google | Stay Latin (brands) |
| **NEW (Batch 8)** OTP / TPIN | Stay Latin (acronyms) |
| **NEW (Batch 8)** Home (nav) | "الرئيسية" |
| **NEW (Batch 8)** Back (button) | "رجوع" |
| **NEW (Batch 8)** OK | "موافق" |
| **NEW (Batch 8)** Cancel | "إلغاء" |
| **NEW (Batch 8)** Confirm | "تأكيد" |
| **NEW (Batch 8)** Save | "حفظ" |
| **NEW (Batch 8)** Continue | "متابعة" |
| **NEW (Batch 8)** Done | "تم" |
| **NEW (Batch 8)** Download | "تنزيل" |
| **NEW (Batch 8)** Share | "مشاركة" |
| **NEW (Batch 8)** Next | "التالي" |
| **NEW (Batch 8)** Retry / Try again | "إعادة المحاولة" |
| **NEW (Batch 8)** "Field is required" | "الحقل مطلوب" |
| **NEW (Batch 8)** "Passwords don't match" | "كلمتا المرور غير متطابقتين" (dual form) |
| **NEW (Batch 8)** "An error occurred" | "حدث خطأ" |
| **NEW (Batch 8)** "Service unavailable" | "الخدمة غير متاحة مؤقتًا" |
| **NEW (Batch 8)** "You are offline" | "أنت غير متّصل بالإنترنت" |
| **NEW (Batch 8)** "Loading..." | "جارٍ التحميل..." |
| **NEW (Batch 8)** "Please wait..." | "يُرجى الانتظار..." |
| **NEW (Batch 8)** "Page not found: {uri}" | "الصفحة غير موجودة: {uri}" |
| **NEW (Batch 8)** "You don't have permission" | "ليس لديك إذن" |
| **NEW (Batch 8)** "No {X} provided" | "لم يتم تقديم {X}" |
