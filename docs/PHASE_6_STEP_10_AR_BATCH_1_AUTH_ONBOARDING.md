# Phase 6 Step 10 — Arabic Batch 1 — Auth & Onboarding

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 1 of 9
> **Scope:** Auth & onboarding surface — 90 keys + `itemCount` plural fix (replaces English placeholder with proper 6-form Arabic plural)
> **Predecessor:** `phase6-step10-fr-translations-complete` @ `c3832016` (French complete; Arabic begins)
> **Branch name to create:** `phase6-step10-ar-batch-1`
> **Tag to apply after merge:** `phase6-step10-ar-batch-1-complete`

---

## 1. Scope

This batch translates 90 Arabic keys covering the auth and onboarding surface (mirroring the exact key set from French Batch 1), AND replaces the `itemCount` plural string in `app_ar.arb` from its English-placeholder value to a proper Arabic plural with all 6 plural forms (zero/one/two/few/many/other).

**Translation coverage (90 keys):**
- Welcome screen entry buttons (`getStarted`, `skip`)
- Sign up screen (form fields, terms checkbox, social sign-in divider)
- Log in screen (form fields, biometric login, welcome back)
- Forgot password / reset password flow
- Email verification flow (post-signup verify-email screen)
- Phone OTP flow (auth signup verification — NOT transaction OTP, NOT PIN reset OTP)
- Complete-profile screen (post-phone-signup detail capture)
- Social sign-in (Apple coming-soon notice)
- App lock screen (password / PIN / biometric unlock)
- Auth success snackbars (account created, logged in)

**Special handling — `itemCount`:**
- Currently set in `app_ar.arb` to its English source value (`'{count, plural, =1{1 item} other{{count} items}}'`) from framework setup
- This batch replaces it with a proper Arabic plural using all 6 CLDR plural categories required for Arabic
- The apply script verifies the OLD value matches expected English before replacing — extra safety check

**Out of scope for this batch:**
- KYC verification flows → Batch 2 / Batch 3
- Wallet, send, receive screens → Batch 4 / Batch 5
- Transactions and disputes → Batch 6
- Profile, FAQ, settings, security → Batch 7
- Generic error resolvers, generic UI buttons, splash, app metadata → Batch 8

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_1_AUTH_ONBOARDING.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-translations-complete|phase6-step10-ar-batch-1-complete"
```

Expected:
- `phase6-step10-fr-translations-complete` MUST be present (French complete)
- `phase6-step10-ar-batch-1-complete` MUST NOT be present (this batch hasn't merged yet)

### 2.4 Confirm app_ar.arb baseline state

```bash
python3 << 'PYEOF'
import json
ar = json.load(open('lib/l10n/app_ar.arb'))
en = json.load(open('lib/l10n/app_en.arb'))
fr = json.load(open('lib/l10n/app_fr.arb'))

ar_keys = {k for k in ar if not k.startswith('@')}
en_keys = {k for k in en if not k.startswith('@')}
fr_keys = {k for k in fr if not k.startswith('@')}

assert len(ar_keys) == 701, f"AR has {len(ar_keys)} keys, expected 701"
assert ar_keys == en_keys, "AR/EN key sets differ"

ar_filled = sum(1 for k in ar_keys if ar[k] != '')
ar_empty = sum(1 for k in ar_keys if ar[k] == '')
fr_filled = sum(1 for k in fr_keys if fr[k] != '')

print(f"AR currently filled: {ar_filled} (expected 1: only itemCount as English placeholder)")
print(f"AR currently empty:  {ar_empty} (expected 700)")
print(f"FR currently filled: {fr_filled} (expected 701: French complete)")

# Verify itemCount AR is the English placeholder (we will replace it)
expected_itemcount_en = '{count, plural, =1{1 item} other{{count} items}}'
ar_itemcount = ar.get('itemCount', '')
assert ar_itemcount == expected_itemcount_en, \
    f"AR itemCount unexpected. Got: {ar_itemcount!r}. Expected: {expected_itemcount_en!r}"
print(f"AR itemCount holds expected English placeholder: True")
PYEOF
```

Expected:
- `AR currently filled: 1 (expected 1: only itemCount as English placeholder)`
- `AR currently empty:  700 (expected 700)`
- `FR currently filled: 701 (expected 701: French complete)`
- `AR itemCount holds expected English placeholder: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-1
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_ar_batch_1.py`, run, then verify and commit.

### 3.1 Translation data

The 90 Arabic translations + 1 itemCount replacement are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (Arabic punctuation `؟ ،`, literal `\n` newlines, Latin-script brand names) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Welcome / onboarding entry buttons (2) ---
    "getStarted": "ابدأ",
    "skip": "تخطّى الآن",

    # --- Sign up screen (7) ---
    "signUp": "إنشاء حساب",
    "signUpSubtitle": "سجّل وانطلق إلى المستوى التالي",
    "createAccount": "إنشاء حساب",
    "alreadyHaveAccount": "لديك حساب بالفعل؟",
    "dontHaveAccount": "ليس لديك حساب؟",
    "orSignUpWith": "أو سجّل عبر",
    "orLogInWith": "أو سجّل الدخول عبر",

    # --- Log in screen (4) ---
    "logIn": "تسجيل الدخول",
    "logInSubtitle": "مرحبًا بعودتك! سجّل الدخول للمتابعة",
    "welcomeBack": "مرحبًا بعودتك",
    "welcomeBackTitle": "مرحبًا بعودتك",

    # --- Common auth form fields (19) ---
    "fullName": "الاسم الكامل",
    "fullNameHint": "أدخل اسمك الكامل",
    "email": "البريد الإلكتروني",
    "emailHint": "أدخل بريدك الإلكتروني",
    "emailLabel": "البريد الإلكتروني",
    "enterEmailHint": "أدخل بريدك الإلكتروني",
    "password": "كلمة المرور",
    "passwordHint": "أدخل كلمة المرور",
    "passwordLabel": "كلمة المرور",
    "enterPasswordHint": "أدخل كلمة المرور",
    "enterYourPasswordHint": "أدخل كلمة المرور",
    "enterYourPasswordTitle": "أدخل كلمة المرور",
    "passwordMustContainLabel": "يجب أن تحتوي كلمة المرور على:",
    "confirmPassword": "تأكيد كلمة المرور",
    "confirmPasswordHint": "أكّد كلمة المرور",
    "phoneNumber": "رقم الهاتف",
    "phoneNumberHint": "أدخل رقم هاتفك",
    "phoneNumberLabel": "رقم الهاتف",
    "enterPhoneNumberHint": "أدخل رقم الهاتف",

    # --- Terms (signup checkbox) (5) ---
    "pleaseAgreeToTerms": "يُرجى الموافقة على شروط الخدمة وسياسة الخصوصية",
    "termsAgreement": "أوافق على",
    "termsAndPrivacy": "الشروط وسياسة الخصوصية",
    "termsOfServiceLink": "شروط الخدمة",
    "privacyPolicyLink": "سياسة الخصوصية",

    # --- Forgot password / reset password flow (15) ---
    "forgotPassword": "هل نسيت كلمة المرور؟",
    "forgotPasswordTitle": "نسيت كلمة المرور",
    "resetPassword": "إعادة تعيين كلمة المرور",
    "resetYourPasswordTitle": "أعد تعيين كلمة المرور",
    "createNewPasswordSubtitle": "أنشئ كلمة مرور جديدة",
    "enterEmailForResetLink": "أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.",
    "sendResetLink": "إرسال رابط إعادة التعيين",
    "emailResetLinkSent": "أرسلنا رابط إعادة التعيين إلى:\n{email}",
    "emailSentTitle": "تم إرسال البريد الإلكتروني!",
    "checkEmailForInstructions": "يُرجى مراجعة بريدك الإلكتروني واتّباع التعليمات لإعادة تعيين كلمة المرور.",
    "didntReceiveTheEmail": "لم تستلم البريد الإلكتروني؟",
    "didntReceiveEmailTryAgain": "لم تستلم بريدًا إلكترونيًا؟ حاول مرة أخرى",
    "weveSentVerificationLinkTo": "أرسلنا رابط تحقّق إلى:",
    "backToLogin": "العودة إلى تسجيل الدخول",
    "successPasswordReset": "تم إرسال رابط إعادة التعيين!",

    # --- Password changed confirmation (2) ---
    "passwordChangedTitle": "تم تغيير كلمة المرور!",
    "passwordChangedBody": "تم تحديث كلمة المرور بنجاح.",

    # --- Email verification flow (5) ---
    "accountCreatedVerifyEmail": "تم إنشاء الحساب! يُرجى التحقّق من بريدك الإلكتروني.",
    "verifyEmail": "التحقّق من البريد الإلكتروني",
    "verifyYourEmailTitle": "تحقّق من بريدك الإلكتروني",
    "verificationEmailSent": "تم إرسال بريد التحقّق!",
    "emailVerifiedSuccessfully": "تم التحقّق من البريد الإلكتروني بنجاح!",

    # --- Phone OTP flow (auth signup verification) (20) ---
    "otpSentTo": "أرسلنا رمز التحقّق إلى",
    "otpSentToPhone": "تم إرسال OTP إلى هاتفك",
    "weSent6DigitCode": "أرسلنا رمزًا من 6 أرقام إلى",
    "enterOtp": "أدخل OTP",
    "enterOtpTitle": "أدخل OTP",
    "verifyCodeButton": "التحقّق من الرمز",
    "sendVerificationCodeButton": "إرسال رمز التحقّق",
    "resendCode": "إعادة إرسال الرمز",
    "resendCodeButton": "إعادة إرسال الرمز",
    "resendCodeIn": "إعادة الإرسال خلال {seconds} ثانية",
    "resendIn": "إعادة الإرسال خلال",
    "didntReceiveCode": "لم تستلم الرمز؟",
    "phoneVerifiedSuccessfully": "تم التحقّق من الهاتف بنجاح!",
    "verifyPhone": "التحقّق من الهاتف",
    "verifyPhoneTitle": "التحقّق من الهاتف",
    "verifyYourPhone": "تحقّق من هاتفك",
    "incorrectCodeError": "رمز غير صحيح. يُرجى المحاولة مجددًا.",
    "failedToSendOtpError": "فشل إرسال OTP. يُرجى المحاولة مجددًا.",
    "otpVerificationFailedError": "فشل التحقّق من OTP",
    "tooManyAttemptsError": "عدد كبير من المحاولات. يُرجى المحاولة لاحقًا.",

    # --- Complete profile (post phone signup) (2) ---
    "completeProfile": "إكمال الملف الشخصي",
    "completeProfileSubtitle": "نحتاج إلى بعض المعلومات الإضافية لتأمين حسابك",

    # --- Social sign-in (1) ---
    "appleSignInComingSoon": "تسجيل الدخول عبر Apple قريبًا",

    # --- App lock screen (6) ---
    "enterPasswordToUnlock": "أدخل كلمة المرور لإلغاء القفل",
    "enterPinToUnlock": "أدخل رمز PIN لإلغاء القفل",
    "unlockButton": "إلغاء القفل",
    "biometricReasonAuthenticate": "استخدم بصمتك للوصول إلى QR Wallet",
    "biometricLogin": "تسجيل الدخول بالبصمة",
    "useBiometric": "استخدام البصمة",

    # --- Auth success snackbars (2) ---
    "successAccountCreated": "تم إنشاء الحساب بنجاح!",
    "successLoggedIn": "مرحبًا بعودتك!",
}

assert len(TRANSLATIONS) == 90, f"Spec dict has {len(TRANSLATIONS)} entries, expected 90"

# Replacement for itemCount (was set to English placeholder during framework setup)
# Uses all 6 Arabic CLDR plural categories: zero, one, two, few, many, other
REPLACE_EXISTING = {
    "itemCount": "{count, plural, zero{لا توجد عناصر} one{عنصر واحد} two{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}",
}

assert len(REPLACE_EXISTING) == 1, f"REPLACE_EXISTING has {len(REPLACE_EXISTING)} entries, expected 1"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_1.py`. Self-contained — embeds both dicts, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 1 - Auth & Onboarding
Applies 90 Arabic translations to lib/l10n/app_ar.arb,
plus replaces the itemCount English placeholder with proper Arabic plural.
Modifies ONLY app_ar.arb. Does not touch app_en.arb or app_fr.arb.
"""

import json
from pathlib import Path

ARB_PATH = Path("lib/l10n/app_ar.arb")
EN_PATH = Path("lib/l10n/app_en.arb")

TRANSLATIONS = {
    # PASTE THE FULL TRANSLATIONS DICT FROM SECTION 3.1 ABOVE HERE.
}

REPLACE_EXISTING = {
    # PASTE THE FULL REPLACE_EXISTING DICT FROM SECTION 3.1 ABOVE HERE.
}

EXPECTED_OLD_VALUES = {
    "itemCount": "{count, plural, =1{1 item} other{{count} items}}",
}

def main():
    # Sanity: dict sizes
    assert len(TRANSLATIONS) == 90, f"Expected 90 translations, got {len(TRANSLATIONS)}"
    assert len(REPLACE_EXISTING) == 1, f"Expected 1 replace-existing, got {len(REPLACE_EXISTING)}"
    assert set(REPLACE_EXISTING.keys()) == set(EXPECTED_OLD_VALUES.keys()), \
        "REPLACE_EXISTING keys must match EXPECTED_OLD_VALUES keys"

    # Load files
    ar = json.loads(ARB_PATH.read_text(encoding="utf-8"))
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))

    # Verify baseline: every TRANSLATIONS key exists in both en and ar
    missing_in_en = [k for k in TRANSLATIONS if k not in en]
    missing_in_ar = [k for k in TRANSLATIONS if k not in ar]
    assert not missing_in_en, f"TRANSLATIONS keys missing in en: {missing_in_en}"
    assert not missing_in_ar, f"TRANSLATIONS keys missing in ar: {missing_in_ar}"

    # Verify baseline: every TRANSLATIONS key is currently empty in ar
    not_empty = [k for k in TRANSLATIONS if ar[k] != ""]
    assert not not_empty, f"TRANSLATIONS keys already non-empty in ar: {not_empty}"

    # Verify baseline: every REPLACE_EXISTING key currently holds the expected old value
    for key, expected_old in EXPECTED_OLD_VALUES.items():
        assert ar.get(key) == expected_old, \
            f"REPLACE_EXISTING[{key}] expected old value {expected_old!r}, got {ar.get(key)!r}"

    # Apply translations (empty → filled)
    for key, value in TRANSLATIONS.items():
        ar[key] = value

    # Apply replacements (English placeholder → proper Arabic)
    for key, value in REPLACE_EXISTING.items():
        ar[key] = value

    # Verify: each TRANSLATIONS key now has its spec value
    for key, expected in TRANSLATIONS.items():
        assert ar[key] == expected, f"Mismatch on {key}: got {ar[key]!r}, expected {expected!r}"

    # Verify: each REPLACE_EXISTING key now has its new spec value
    for key, expected in REPLACE_EXISTING.items():
        assert ar[key] == expected, f"Replace mismatch on {key}: got {ar[key]!r}, expected {expected!r}"

    # Verify: total key count unchanged
    ar_keys = {k for k in ar if not k.startswith('@')}
    en_keys = {k for k in en if not k.startswith('@')}
    assert len(ar_keys) == 701, f"AR has {len(ar_keys)} keys after apply, expected 701"
    assert ar_keys == en_keys, "AR/EN key sets diverged"

    # Verify: ICU placeholder preservation (2 ICU keys in TRANSLATIONS + itemCount plural)
    assert "{email}" in ar["emailResetLinkSent"], "emailResetLinkSent lost {email}"
    assert "{seconds}" in ar["resendCodeIn"], "resendCodeIn lost {seconds}"
    assert "\n" in ar["emailResetLinkSent"], "emailResetLinkSent lost newline"

    # Verify: itemCount has all 6 Arabic plural categories
    itc = ar["itemCount"]
    for cat in ["zero{", "one{", "two{", "few{", "many{", "other{"]:
        assert cat in itc, f"itemCount missing plural category: {cat[:-1]}"
    assert "{count}" in itc, "itemCount lost {count} placeholder"

    # Verify: itemCount uses Arabic letters (sanity check that we didn't keep English)
    # Check for at least one Arabic letter in the value
    assert any('\u0600' <= ch <= '\u06FF' for ch in itc), \
        "itemCount appears to have no Arabic characters — replacement may have failed"

    # Verify: Arabic question mark (؟) used in question keys (sanity check)
    assert "؟" in ar["alreadyHaveAccount"], "alreadyHaveAccount missing Arabic question mark ؟"
    assert "؟" in ar["dontHaveAccount"], "dontHaveAccount missing Arabic question mark ؟"
    assert "؟" in ar["forgotPassword"], "forgotPassword missing Arabic question mark ؟"

    # Verify: brand names preserved in Latin script
    assert "Apple" in ar["appleSignInComingSoon"], "appleSignInComingSoon lost Apple brand"
    assert "QR Wallet" in ar["biometricReasonAuthenticate"], "biometricReasonAuthenticate lost QR Wallet brand"
    assert "OTP" in ar["enterOtp"], "enterOtp lost OTP token"
    assert "PIN" in ar["enterPinToUnlock"], "enterPinToUnlock lost PIN token"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for Arabic)
    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations + {len(REPLACE_EXISTING)} itemCount replacement")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 1, expected {1 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_1.py
```

Expected output (approximately):
```
OK — applied 90 translations + 1 itemCount replacement
AR filled: 91/701 (was 1, expected 91)
AR empty: 610
```

If any assertion fires, STOP and report.

---

## 4. Verification

After the script runs:

### 4.1 Confirm only app_ar.arb changed

```bash
git status
```

Expected: only `modified: lib/l10n/app_ar.arb`. The PHASE_*.py untracked stragglers are normal and remain untracked.

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

Expected:
- EN keys: 701
- AR keys: 701
- Match: True
- AR filled: 91

### 4.3 Confirm fr and en files untouched

```bash
git diff --stat lib/l10n/app_fr.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty output for both.

### 4.4 Confirm spec keys hold spec values + ICU + itemCount

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "getStarted": "ابدأ",
    "signUp": "إنشاء حساب",
    "logIn": "تسجيل الدخول",
    "welcomeBack": "مرحبًا بعودتك",
    "fullName": "الاسم الكامل",
    "email": "البريد الإلكتروني",
    "password": "كلمة المرور",
    "phoneNumber": "رقم الهاتف",
    "alreadyHaveAccount": "لديك حساب بالفعل؟",
    "forgotPassword": "هل نسيت كلمة المرور؟",
    "emailResetLinkSent": "أرسلنا رابط إعادة التعيين إلى:\n{email}",
    "resendCodeIn": "إعادة الإرسال خلال {seconds} ثانية",
    "appleSignInComingSoon": "تسجيل الدخول عبر Apple قريبًا",
    "enterPinToUnlock": "أدخل رمز PIN لإلغاء القفل",
    "biometricReasonAuthenticate": "استخدم بصمتك للوصول إلى QR Wallet",
    "successAccountCreated": "تم إنشاء الحساب بنجاح!",
    "itemCount": "{count, plural, zero{لا توجد عناصر} one{عنصر واحد} two{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}",
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
```

Stage **only** the modified ARB file:

```bash
git add lib/l10n/app_ar.arb
git status
```

Confirm staged files are exactly:
- `lib/l10n/app_ar.arb`

Nothing else. If `lib/generated/l10n/` shows up in staging, UNSTAGE IT. If any `.py` file at the repo root shows up, UNSTAGE IT.

Commit with the message in `/tmp/commit_msg.txt`:

```bash
cat > /tmp/commit_msg.txt << 'EOF'
10.ar-batch-1: Arabic translations for auth & onboarding (90 keys + itemCount fix)

Translates 90 Arabic keys covering the auth and onboarding surface,
mirroring the exact key set from French Batch 1. Also replaces the
itemCount plural in app_ar.arb from its English-placeholder value
(set during framework setup) to a proper Arabic plural with all 6
CLDR plural categories (zero/one/two/few/many/other).

Coverage (90 keys):
- Welcome screen entry (getStarted, skip)
- Sign up screen (form fields, terms, social sign-in divider)
- Log in screen (form fields, biometric login, welcome back)
- Forgot password / reset password flow (15 keys)
- Email verification flow (5 keys)
- Phone OTP flow — auth signup variant (20 keys)
- Complete profile (post phone signup, 2 keys)
- Apple sign-in coming-soon notice
- App lock screen (password / PIN / biometric unlock, 6 keys)
- Auth success snackbars (account created, logged in)

itemCount: replaces '{count, plural, =1{1 item} other{{count} items}}'
with proper Arabic plural using all 6 CLDR plural categories required
for Arabic grammar:
  zero  → لا توجد عناصر          (no items)
  one   → عنصر واحد              (one item)
  two   → عنصران                 (two items, dual form)
  few   → {count} عناصر          (3-10 items, broken plural)
  many  → {count} عنصرًا         (11-99, counted noun with tanwin)
  other → {count} عنصر           (100+, fractions)

ICU placeholders preserved (verified by apply-script assertions, 2 ICU
keys + 1 plural): emailResetLinkSent ({email}, newline), resendCodeIn
({seconds}), itemCount ({count} in 3 plural branches).

Convention notes:
- Formal MSA (الفصحى) register throughout
- Brand names stay Latin script: QR Wallet, Apple, OTP, PIN
- Arabic question mark ؟ for question forms
- Masculine verb forms used as default (standard for mixed-audience UI)
- "كلمة المرور" for password
- "البريد الإلكتروني" for email
- "رقم الهاتف" for phone number
- "رمز" for code (verification code, PIN)
- "OTP" kept as Latin acronym (recognized in Arabic fintech)
- "PIN" kept as Latin acronym, prefixed with "رمز" (code) when needed:
  "رمز PIN"
- "تحقّق" / "التحقّق" for verify/verification
- "إعادة تعيين" for reset
- "بصمة" for biometric/fingerprint
- "يُرجى" (formal passive) for "please" in instructions
- "بنجاح" for "successfully"

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_1_AUTH_ONBOARDING.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-1
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-ar-batch-1-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-ar-batch-1`
2. **Final commit SHA** (from `git rev-parse HEAD`)
3. **Output of all verification steps** (Sections 4.1, 4.2, 4.3, 4.4)
4. **Output of the apply script** (Section 3.2 run command)
5. **`git diff --stat HEAD~1 HEAD`** to confirm only `lib/l10n/app_ar.arb` was touched
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
   git checkout phase6-step10-ar-batch-1
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

   Expected: only `lib/generated/l10n/app_localizations_ar.dart` (and possibly `app_localizations.dart`) shows changes.

4. **Per established workflow:** generated files are NOT committed.

5. Run analyzer + build:
   ```bash
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```

   Expected: 204 analyzer issues (baseline), build green. Arabic plural in itemCount uses all 6 CLDR categories — gen-l10n must accept this without errors. If analyzer count goes up, STOP — likely an ICU plural format mismatch.

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
   git merge --ff-only phase6-step10-ar-batch-1
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-ar-batch-1-complete
   git push origin main
   git push origin phase6-step10-ar-batch-1-complete
   git push origin :phase6-step10-ar-batch-1
   git branch -d phase6-step10-ar-batch-1
   ```

---

## 10. Translation conventions (Arabic — establishes baseline for AR Batches 1-9)

These conventions apply to ALL Arabic batches in Step 10. Documented here for the Arabic reviewer's reference.

| Convention | Decision |
|---|---|
| Register | Formal MSA (الفصحى) — no dialect |
| Verb form (default) | Masculine 2nd person (أدخل, سجّل) — UI convention |
| Brand names | Stay in Latin script: QR Wallet, MTN MoMo, Apple, Google, Paystack, WhatsApp, Smile ID, Face ID, Mobile Money, App Store |
| OTP | Kept as "OTP" (Latin, recognized in Arabic fintech) |
| PIN | Kept as "PIN" (Latin); prefix "رمز PIN" when needing the noun |
| Email | "البريد الإلكتروني" (definite) / "بريد إلكتروني" (indefinite) |
| Password | "كلمة المرور" |
| Phone number | "رقم الهاتف" |
| Wallet (generic) | "محفظة" |
| Question mark | "؟" (Arabic question mark, RTL) |
| Comma | "،" (Arabic comma) |
| Exclamation, colon | "!" / ":" (Latin glyphs) |
| "Please [do X]" | "يُرجى [X]" (formal passive) |
| "Welcome back" | "مرحبًا بعودتك" |
| "successfully" | "بنجاح" |
| "Verify / verification" | "تحقّق" / "التحقّق" |
| "Reset" | "إعادة تعيين" |
| "Confirm" | "تأكيد" / "أكّد" (verb) |
| "Code" (verification, PIN) | "رمز" |
| Biometric / fingerprint | "بصمة" |
| "Sign up" | "إنشاء حساب" / "سجّل" (verb) |
| "Log in" | "تسجيل الدخول" / "سجّل الدخول" (verb) |
| Diacritics (تشكيل) | Avoided in modern UI; minimal use only where grammatically essential (e.g. tanwin in counted noun "عنصرًا") |
| Numbers in placeholders | Flutter renders {count} / {seconds} per locale (Arabic-Indic ٠١٢ for ar) — translation strings remain agnostic |
