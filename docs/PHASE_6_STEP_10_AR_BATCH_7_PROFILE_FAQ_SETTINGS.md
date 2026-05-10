# Phase 6 Step 10 — Arabic Batch 7 — Profile / FAQ / Settings / Security

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** Arabic Batch 7 of 9
> **Scope:** Profile, FAQ, Help & Support, About, App Settings (theme/language/currency/notifications), Security (PIN/password/block account/logout), Business logo — 152 keys, 9 ICU
> **Predecessor:** `phase6-step10-ar-batch-6-complete` @ `3e9a2a9f`
> **Branch name to create:** `phase6-step10-ar-batch-7`
> **Tag to apply after merge:** `phase6-step10-ar-batch-7-complete`

---

## 1. Scope

This batch translates 152 Arabic keys covering profile, FAQ, settings, and security screens (mirroring the exact key set from French Batch 7) — the largest batch in the run.

- Profile screen (11 keys, 2 ICU) — title, photo, edit, KYC name lock, hello user, save state
- FAQ Q&A pairs (12 keys + section header) — add money, change PIN, forgot password, money safety, send money, withdrawal time
- Help & Support (13 keys) — sections, email/WhatsApp support, share/rate links, errors
- About screen (5 keys) — title, app description, copyright, made-in-Ghana with emoji, version line with ICU
- Settings sections (5 keys) — general/preferences/security/account-settings/account-safety
- Theme (8 keys) — appearance, theme label, dark/light/system options + subtitles, preview
- Language (7 keys, 1 implicit) — label, description, English/French/Arabic options, select, changed, first-launch prompt
- Currency (6 keys, 2 ICU) — label, select title, description, change confirmation, name+symbol format, error
- Notifications (16 keys) — section title, screen title, empty state, mark-all-read, push/email/transaction/security/promotional/payment-reminder toggles + subtitles
- Settings save (2 keys, 1 ICU) — saved toast, error
- PIN management (15 keys) — section, change/reset PIN actions, forgot link, step titles, success states, security note, reset flow
- Auth methods for PIN reset (4 keys) — email/password method label/subtitle, body, OTP subtitle
- Password change (6 keys) — label, action, current/new/confirm fields + hints
- Account blocking (10 keys) — block/unblock labels, confirm body, success toasts, subtitles, blocked-by-support state
- Logout (2 keys) — log out, confirm body
- Phone OTP (2 keys, 1 ICU) — no-phone-linked subtitle, enter-6-digit-code with {phone}
- Business logo (15 keys, 2 ICU) — label, upload/remove flows, captions, errors

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
test -f docs/PHASE_6_STEP_10_AR_BATCH_7_PROFILE_FAQ_SETTINGS.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-ar-batch-6-complete|phase6-step10-ar-batch-7-complete"
```

Expected:
- `phase6-step10-ar-batch-6-complete` MUST be present
- `phase6-step10-ar-batch-7-complete` MUST NOT be present

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
print(f"AR currently filled: {filled} keys (expected 469 = Batches 1-6 + itemCount)")
print(f"AR total: {len(ar_keys)}")
print(f"Key sets match: {ar_keys == en_keys}")
PYEOF
```

Expected:
- `AR currently filled: 469 keys`
- `AR total: 701`
- `Key sets match: True`

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-ar-batch-7
```

---

## 3. Implementation

### 3.1 Translation data

The 152 Arabic translations are below. **The agent MUST use these exact values verbatim.** ICU placeholders MUST be preserved exactly. Brand names, emojis, multi-paragraph `\n\n` newlines, em-dashes, bullets `•`, and the literal email address `qrwallet.support@bongroups.co` MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Profile screen (11 keys, 2 ICU) ---
    "profile": "الملف الشخصي",
    "profilePhoto": "صورة الملف الشخصي",
    "editProfile": "تعديل الملف الشخصي",
    "changePhotoButton": "تغيير الصورة",
    "changeButton": "تغيير",
    "defaultUserName": "المستخدم",
    "nameVerifiedKycCannotChange": "تم التحقّق من الاسم عبر KYC — لا يمكن تغييره",
    "helloUser": "مرحبًا، {userName} 👋",
    "saving": "جارٍ الحفظ...",
    "successProfileUpdated": "تم تحديث الملف الشخصي بنجاح!",
    "errorUpdatingProfile": "خطأ أثناء تحديث الملف الشخصي: {error}",

    # --- FAQ section header (1) ---
    "faqSection": "الأسئلة الشائعة",

    # --- FAQ Q&A pairs (12) ---
    "faqAddMoneyQuestion": "كيف أضيف أموالًا إلى محفظتي؟",
    "faqAddMoneyAnswer": "يمكنك إضافة الأموال عبر البطاقة أو Mobile Money أو التحويل المصرفي. اذهب إلى الرئيسية ← إضافة أموال واختر الطريقة المفضّلة لديك.",
    "faqChangePinQuestion": "كيف أغيّر رمز PIN الخاص بي؟",
    "faqChangePinAnswer": "اذهب إلى الملف الشخصي ← تغيير رمز PIN. أدخل رمز PIN الحالي، ثم أنشئ وأكّد رمز PIN الجديد.",
    "faqForgotPasswordQuestion": "ماذا أفعل إذا نسيت كلمة المرور؟",
    "faqForgotPasswordAnswer": "في شاشة تسجيل الدخول، اضغط على «هل نسيت كلمة المرور؟» وأدخل بريدك الإلكتروني. سنرسل لك رابط إعادة التعيين.",
    "faqMoneySafeQuestion": "هل أموالي آمنة؟",
    "faqMoneySafeAnswer": "نعم! نستخدم تشفيرًا بمستوى مصرفي ومعالجات دفع آمنة. أموالك محمية في جميع الأوقات.",
    "faqSendMoneyQuestion": "كيف أرسل أموالًا إلى شخص ما؟",
    "faqSendMoneyAnswer": "اضغط على «إرسال» في الشاشة الرئيسية، أدخل رقم تعريف محفظة المستلم أو امسح رمز QR الخاص به، أدخل المبلغ، ثم أكّد.",
    "faqWithdrawalTimeQuestion": "كم تستغرق عمليات السحب؟",
    "faqWithdrawalTimeAnswer": "تستغرق التحويلات المصرفية عادةً من يوم إلى 3 أيام عمل. أما عمليات السحب عبر Mobile Money فتكون فورية عادةً.",

    # --- Help & Support (13 keys) ---
    "helpAndSupportTitle": "المساعدة والدعم",
    "helpSupport": "المساعدة والدعم",
    "contactUsSection": "اتّصل بنا",
    "followUsSection": "تابعنا",
    "supportSection": "الدعم",
    "emailSupportLabel": "الدعم عبر البريد الإلكتروني",
    "emailSupportSubject": "طلب دعم QR Wallet",
    "whatsappSupportLabel": "الدعم عبر WhatsApp",
    "whatsappSupportSubtitle": "تحدّث معنا عبر WhatsApp",
    "couldNotOpenEmailToast": "تعذّر فتح تطبيق البريد الإلكتروني. يُرجى مراسلتنا على qrwallet.support@bongroups.co",
    "shareAppLink": "مشاركة التطبيق",
    "rateUsLink": "قيّم التطبيق",
    "rateUsToast": "قيّمنا على App Store!",
    "shareComingSoonToast": "ميزة المشاركة قريبًا!",

    # --- About (5 keys, 1 ICU) ---
    "about": "حول",
    "aboutTitle": "حول",
    "aboutAppDescription": "QR Wallet هو محفظة رقمية آمنة وسهلة الاستخدام تتيح لك إرسال واستلام وإدارة الأموال بمسحة واحدة. اكتشف مستقبل المدفوعات اليوم.",
    "copyrightLine": "© 2024 QR Wallet. جميع الحقوق محفوظة.",
    "madeInGhanaLine": "صُنع بـ ❤️ في غانا",
    "versionAndBuild": "الإصدار {version} (Build {buildNumber})",

    # --- Settings sections (5 keys) ---
    "generalSection": "عام",
    "preferencesSection": "التفضيلات",
    "securityAndUpdatesSection": "الأمان والتحديثات",
    "accountSettings": "إعدادات الحساب",
    "accountSafetySection": "أمان الحساب",

    # --- Theme (8 keys) ---
    "appearanceMenuItem": "المظهر",
    "themeLabel": "السمة",
    "darkMode": "الوضع الداكن",
    "darkThemeLabel": "داكن",
    "darkThemeSubtitle": "خلفية داكنة مع نص فاتح",
    "lightThemeLabel": "فاتح",
    "lightThemeSubtitle": "خلفية فاتحة مع نص داكن",
    "systemThemeLabel": "النظام",
    "systemThemeSubtitle": "اتّباع إعدادات النظام",
    "previewLabel": "معاينة",

    # --- Language (8 keys) ---
    "language": "اللغة",
    "languageDescription": "اختر اللغة التي ترغب في استخدامها في جميع أنحاء التطبيق وفي الإشعارات.",
    "languageEnglish": "الإنجليزية",
    "languageFrench": "الفرنسية",
    "languageArabic": "العربية",
    "selectLanguage": "اختر اللغة",
    "languageChanged": "تم تغيير اللغة",
    "firstLaunchLanguagePrompt": "اختر لغتك",

    # --- Currency (6 keys, 2 ICU) ---
    "currencyLabel": "العملة",
    "selectCurrencyTitle": "اختر العملة",
    "currencySelectorDescription": "اختر عملتك المفضّلة لعرض الأرصدة والمعاملات.",
    "currencyChangedTo": "تم تغيير العملة إلى {currencyName}",
    "currencyNameAndSymbol": "{name} ({symbol})",
    "failedToChangeCurrency": "فشل تغيير العملة",

    # --- Notifications (16 keys) ---
    "notifications": "الإشعارات",
    "notificationSettingsTitle": "إعدادات الإشعارات",
    "notificationsScreenTitle": "الإشعارات",
    "noNotifications": "لا توجد إشعارات",
    "failedToLoadNotifications": "فشل تحميل الإشعارات",
    "markAllAsRead": "وضع علامة على الكل كمقروء",
    "youreAllCaughtUp": "أنت على اطّلاع كامل!",
    "pushNotificationsLabel": "الإشعارات الفورية",
    "pushNotificationsSubtitle": "استلم إشعارات على جهازك",
    "emailNotificationsLabel": "إشعارات البريد الإلكتروني",
    "emailNotificationsSubtitle": "استلم التحديثات عبر البريد الإلكتروني",
    "transactionAlertsLabel": "تنبيهات المعاملات",
    "transactionAlertsSubtitle": "تلقَّ إشعارًا بكل المعاملات",
    "securityAlertsLabel": "تنبيهات الأمان",
    "securityAlertsSubtitle": "إشعارات أمان مهمّة",
    "securityAlertsCannotBeDisabledNote": "لا يمكن تعطيل تنبيهات الأمان حمايةً لك.",
    "promotionalUpdatesLabel": "التحديثات الترويجية",
    "promotionalUpdatesSubtitle": "العروض والأخبار والترويج",
    "paymentRemindersLabel": "تذكيرات الدفع",
    "paymentRemindersSubtitle": "تذكيرات للمدفوعات المعلّقة",

    # --- Settings save (2, 1 ICU) ---
    "settingsSavedToast": "تم حفظ الإعدادات",
    "failedToSaveError": "فشل الحفظ: {error}",

    # --- Security & PIN (15 keys) ---
    "security": "الأمان",
    "changePin": "تغيير رمز PIN",
    "changePinAction": "تغيير رمز PIN",
    "resetPinAction": "إعادة تعيين رمز PIN",
    "forgotPinLink": "هل نسيت رمز PIN؟",
    "enterNewPinStepTitle": "أدخل رمز PIN الجديد",
    "confirmNewPinStepTitle": "أكّد رمز PIN الجديد",
    "createNewPinSubtitle": "أنشئ رمز PIN معاملات جديدًا مكوّنًا من 6 أرقام",
    "reenterNewPinSubtitle": "أدخل رمز PIN الجديد مرة أخرى للتأكيد",
    "pinChangedTitle": "تم تغيير رمز PIN!",
    "pinChangedBody": "تم تحديث رمز PIN المعاملات الخاص بك بنجاح.",
    "pinResetTitle": "تم إعادة تعيين رمز PIN!",
    "pinResetBody": "تم إعادة تعيين رمز PIN المعاملات الخاص بك بنجاح.",
    "pinSecurityNote": "رمز PIN الخاص بك مُشفَّر بشكل آمن ويُستخدم لتفويض المعاملات.",
    "resetPinVerifyIdentityBody": "لإعادة تعيين رمز PIN، يُرجى التحقّق من هويتك باستخدام أحد الخيارات أدناه.",
    "resetPinSecurityAssurance": "يضمن هذا التحقّق أنك وحدك من يستطيع إعادة تعيين رمز PIN الخاص بك.",

    # --- PIN reset auth methods (4 keys) ---
    "emailAndPasswordMethod": "البريد الإلكتروني وكلمة المرور",
    "emailAndPasswordSubtitle": "التحقّق باستخدام بيانات تسجيل الدخول",
    "verifyByCredentialsBody": "تحقّق من هويتك بإدخال بيانات تسجيل الدخول.",
    "verifyOtpToPhoneSubtitle": "التحقّق عبر OTP المُرسل إلى هاتفك",

    # --- Password change (6 keys) ---
    "changePassword": "تغيير كلمة المرور",
    "changePasswordAction": "تغيير كلمة المرور",
    "currentPasswordLabel": "كلمة المرور الحالية",
    "newPasswordLabel": "كلمة المرور الجديدة",
    "confirmNewPasswordLabel": "تأكيد كلمة المرور الجديدة",
    "enterCurrentPasswordHint": "أدخل كلمة المرور الحالية",
    "enterNewPasswordHint": "أدخل كلمة المرور الجديدة",
    "reenterNewPasswordHint": "أدخل كلمة المرور الجديدة مرة أخرى",

    # --- Account blocking (10 keys) ---
    "blockAccountLabel": "حظر الحساب",
    "unblockAccountLabel": "إلغاء حظر الحساب",
    "blockAccountConfirmBody": "هل أنت متأكّد من رغبتك في حظر حسابك؟\n\nسيمنع ذلك جميع المعاملات، بما في ذلك:\n• إرسال الأموال\n• سحب الأموال\n• إضافة الأموال\n\nيمكنك إلغاء الحظر في أي وقت برمز PIN الخاص بك.",
    "accountBlockedSuccessToast": "تم حظر الحساب بنجاح. تم تعطيل جميع المعاملات.",
    "accountUnblockedSuccessToast": "تم إلغاء حظر الحساب بنجاح. تم تفعيل جميع المعاملات مجددًا.",
    "accountBlockedSubtitle": "حسابك محظور حاليًا",
    "temporarilyDisableSubtitle": "تعطيل جميع المعاملات مؤقتًا",
    "accountBlockedBySupportTitle": "الحساب محظور من قِبل الدعم",
    "accountBlockedBySupportBody": "تم حظر حسابك من قِبل خدمة العملاء لأسباب أمنية.\n\nيُرجى التواصل مع فريق الدعم للتحقّق من هويتك وإلغاء حظر حسابك.",
    "blockedBySupportSubtitle": "محظور من قِبل الدعم — اتّصل بنا لإلغاء الحظر",

    # --- Logout (2 keys) ---
    "logOut": "تسجيل الخروج",
    "logoutConfirmBody": "هل أنت متأكّد من رغبتك في تسجيل الخروج؟",

    # --- Phone OTP (2 keys, 1 ICU) ---
    "noPhoneNumberLinkedSubtitle": "لا يوجد رقم هاتف مرتبط بحسابك",
    "enter6DigitCodePhone": "أدخل الرمز المكوّن من 6 أرقام المُرسل إلى {phone}",

    # --- Business logo (15 keys, 2 ICU) ---
    "businessLabel": "الشركة",
    "businessLogoLabel": "شعار الشركة",
    "businessLogoUploadedToast": "تم تحميل شعار الشركة بنجاح",
    "businessLogoRemovedToast": "تم حذف شعار الشركة",
    "removeLogoTitle": "حذف الشعار",
    "removeLogoConfirmBody": "هل أنت متأكّد من رغبتك في حذف شعار شركتك؟",
    "uploadBusinessLogoTitle": "تحميل شعار الشركة",
    "addBusinessLogoSubtitle": "أضف شعار شركتك",
    "logoUploadedSubtitle": "تم تحميل الشعار",
    "logoAppearInQrCaption": "سيظهر هذا الشعار في رموز QR للدفع الخاصة بك",
    "logoEmbeddedInQrCaption": "سيتم تضمين هذا الشعار في رموز QR للدفع الخاصة بك",
    "removeButton": "حذف",
    "uploadButton": "تحميل",
    "errorUploadingLogo": "خطأ أثناء تحميل الشعار: {error}",
    "errorRemovingLogo": "خطأ أثناء حذف الشعار: {error}",
}

assert len(TRANSLATIONS) == 152, f"Spec dict has {len(TRANSLATIONS)} entries, expected 152"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_ar_batch_7.py`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - Arabic Batch 7 - Profile / FAQ / Settings / Security
Applies 152 Arabic translations to lib/l10n/app_ar.arb.
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
    assert len(TRANSLATIONS) == 152, f"Expected 152 translations, got {len(TRANSLATIONS)}"

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

    # ICU placeholder preservation (9 ICU keys)
    assert "{userName}" in ar["helloUser"], "helloUser lost {userName}"
    assert "{error}" in ar["errorUpdatingProfile"], "errorUpdatingProfile lost {error}"
    assert "{version}" in ar["versionAndBuild"], "versionAndBuild lost {version}"
    assert "{buildNumber}" in ar["versionAndBuild"], "versionAndBuild lost {buildNumber}"
    assert "{currencyName}" in ar["currencyChangedTo"], "currencyChangedTo lost {currencyName}"
    assert "{name}" in ar["currencyNameAndSymbol"], "currencyNameAndSymbol lost {name}"
    assert "{symbol}" in ar["currencyNameAndSymbol"], "currencyNameAndSymbol lost {symbol}"
    assert "{error}" in ar["failedToSaveError"], "failedToSaveError lost {error}"
    assert "{phone}" in ar["enter6DigitCodePhone"], "enter6DigitCodePhone lost {phone}"
    assert "{error}" in ar["errorUploadingLogo"], "errorUploadingLogo lost {error}"
    assert "{error}" in ar["errorRemovingLogo"], "errorRemovingLogo lost {error}"

    # Brand names preserved (Latin)
    assert "QR Wallet" in ar["emailSupportSubject"], "emailSupportSubject lost QR Wallet"
    assert "QR Wallet" in ar["aboutAppDescription"], "aboutAppDescription lost QR Wallet"
    assert "QR Wallet" in ar["copyrightLine"], "copyrightLine lost QR Wallet"
    assert "WhatsApp" in ar["whatsappSupportLabel"], "whatsappSupportLabel lost WhatsApp"
    assert "WhatsApp" in ar["whatsappSupportSubtitle"], "whatsappSupportSubtitle lost WhatsApp"
    assert "App Store" in ar["rateUsToast"], "rateUsToast lost App Store"
    assert "Mobile Money" in ar["faqAddMoneyAnswer"], "faqAddMoneyAnswer lost Mobile Money"
    assert "Mobile Money" in ar["faqWithdrawalTimeAnswer"], "faqWithdrawalTimeAnswer lost Mobile Money"
    assert "Build" in ar["versionAndBuild"], "versionAndBuild lost Build (Latin)"
    assert "PIN" in ar["changePin"], "changePin lost PIN"
    assert "PIN" in ar["pinChangedTitle"], "pinChangedTitle lost PIN"
    assert "PIN" in ar["faqChangePinQuestion"], "faqChangePinQuestion lost PIN"
    assert "OTP" in ar["verifyOtpToPhoneSubtitle"], "verifyOtpToPhoneSubtitle lost OTP"
    assert "KYC" in ar["nameVerifiedKycCannotChange"], "nameVerifiedKycCannotChange lost KYC"

    # Email address preserved
    assert "qrwallet.support@bongroups.co" in ar["couldNotOpenEmailToast"], \
        "couldNotOpenEmailToast lost support email"

    # Emojis preserved
    assert "👋" in ar["helloUser"], "helloUser lost wave emoji"
    assert "❤️" in ar["madeInGhanaLine"], "madeInGhanaLine lost heart emoji"

    # Multi-paragraph newlines preserved (\n\n)
    assert "\n\n" in ar["blockAccountConfirmBody"], "blockAccountConfirmBody lost paragraph break"
    assert "\n\n" in ar["accountBlockedBySupportBody"], "accountBlockedBySupportBody lost paragraph break"

    # Bullet character • preserved in blockAccountConfirmBody
    assert "•" in ar["blockAccountConfirmBody"], "blockAccountConfirmBody lost bullet •"

    # Em-dash preserved in nameVerifiedKycCannotChange and blockedBySupportSubtitle
    assert "—" in ar["nameVerifiedKycCannotChange"], "nameVerifiedKycCannotChange lost em-dash"
    assert "—" in ar["blockedBySupportSubtitle"], "blockedBySupportSubtitle lost em-dash"

    # Arabic question mark in question keys
    for k in ["faqAddMoneyQuestion", "faqChangePinQuestion", "faqForgotPasswordQuestion",
              "faqMoneySafeQuestion", "faqSendMoneyQuestion", "faqWithdrawalTimeQuestion",
              "forgotPinLink", "logoutConfirmBody", "removeLogoConfirmBody"]:
        assert "؟" in ar[k], f"{k} missing Arabic question mark ؟"

    # Arabic exclamations
    assert "!" in ar["pinChangedTitle"], "pinChangedTitle lost !"
    assert "!" in ar["successProfileUpdated"], "successProfileUpdated lost !"
    assert "!" in ar["rateUsToast"], "rateUsToast lost !"

    # Arrow ← preserved (used in FAQ instructions)
    assert "←" in ar["faqAddMoneyAnswer"], "faqAddMoneyAnswer lost arrow ←"
    assert "←" in ar["faqChangePinAnswer"], "faqChangePinAnswer lost arrow ←"

    # Guillemets « » preserved in faqForgotPasswordAnswer and faqSendMoneyAnswer
    assert "«" in ar["faqForgotPasswordAnswer"] and "»" in ar["faqForgotPasswordAnswer"], \
        "faqForgotPasswordAnswer lost guillemets"
    assert "«" in ar["faqSendMoneyAnswer"] and "»" in ar["faqSendMoneyAnswer"], \
        "faqSendMoneyAnswer lost guillemets"

    # Arabic Unicode characters present in sample keys
    for k in ["profile", "security", "language", "notifications", "logOut"]:
        assert any('\u0600' <= ch <= '\u06FF' for ch in ar[k]), \
            f"{k} appears to have no Arabic characters"

    ARB_PATH.write_text(
        json.dumps(ar, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    filled_after = sum(1 for k in ar_keys if ar[k] != "")
    empty_after = sum(1 for k in ar_keys if ar[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"AR filled: {filled_after}/{len(ar_keys)} (was 469, expected {469 + len(TRANSLATIONS)})")
    print(f"AR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_ar_batch_7.py
```

Expected:
```
OK — applied 152 translations
AR filled: 621/701 (was 469, expected 621)
AR empty: 80
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

Expected: 701, 701, True, 621.

### 4.3 Confirm fr and en files untouched

```bash
git diff --stat lib/l10n/app_fr.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty for both.

### 4.4 Spot-check + ICU + brand + special chars

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "profile": "الملف الشخصي",
    "helloUser": "مرحبًا، {userName} 👋",
    "saving": "جارٍ الحفظ...",
    "successProfileUpdated": "تم تحديث الملف الشخصي بنجاح!",
    "errorUpdatingProfile": "خطأ أثناء تحديث الملف الشخصي: {error}",
    "faqSection": "الأسئلة الشائعة",
    "faqChangePinQuestion": "كيف أغيّر رمز PIN الخاص بي؟",
    "faqMoneySafeAnswer": "نعم! نستخدم تشفيرًا بمستوى مصرفي ومعالجات دفع آمنة. أموالك محمية في جميع الأوقات.",
    "couldNotOpenEmailToast": "تعذّر فتح تطبيق البريد الإلكتروني. يُرجى مراسلتنا على qrwallet.support@bongroups.co",
    "rateUsToast": "قيّمنا على App Store!",
    "aboutAppDescription": "QR Wallet هو محفظة رقمية آمنة وسهلة الاستخدام تتيح لك إرسال واستلام وإدارة الأموال بمسحة واحدة. اكتشف مستقبل المدفوعات اليوم.",
    "copyrightLine": "© 2024 QR Wallet. جميع الحقوق محفوظة.",
    "madeInGhanaLine": "صُنع بـ ❤️ في غانا",
    "versionAndBuild": "الإصدار {version} (Build {buildNumber})",
    "darkThemeLabel": "داكن",
    "language": "اللغة",
    "languageEnglish": "الإنجليزية",
    "languageFrench": "الفرنسية",
    "languageArabic": "العربية",
    "currencyChangedTo": "تم تغيير العملة إلى {currencyName}",
    "currencyNameAndSymbol": "{name} ({symbol})",
    "youreAllCaughtUp": "أنت على اطّلاع كامل!",
    "securityAlertsCannotBeDisabledNote": "لا يمكن تعطيل تنبيهات الأمان حمايةً لك.",
    "failedToSaveError": "فشل الحفظ: {error}",
    "changePin": "تغيير رمز PIN",
    "forgotPinLink": "هل نسيت رمز PIN؟",
    "pinChangedTitle": "تم تغيير رمز PIN!",
    "verifyOtpToPhoneSubtitle": "التحقّق عبر OTP المُرسل إلى هاتفك",
    "logOut": "تسجيل الخروج",
    "logoutConfirmBody": "هل أنت متأكّد من رغبتك في تسجيل الخروج؟",
    "enter6DigitCodePhone": "أدخل الرمز المكوّن من 6 أرقام المُرسل إلى {phone}",
    "businessLogoLabel": "شعار الشركة",
    "errorUploadingLogo": "خطأ أثناء تحميل الشعار: {error}",
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
10.ar-batch-7: Arabic translations for profile/FAQ/settings/security (152 keys)

Translates 152 Arabic keys covering profile, FAQ, settings, and
security screens, mirroring FR Batch 7 (the largest batch in this run):
- Profile screen (11 keys, 2 ICU)
- FAQ Q&A pairs (12 + section header)
- Help & Support (13 keys)
- About (5 keys, 1 ICU)
- Settings sections (5 keys)
- Theme (8 keys)
- Language (8 keys)
- Currency (6 keys, 2 ICU)
- Notifications (16 keys)
- Settings save (2 keys, 1 ICU)
- Security & PIN management (15 keys)
- PIN reset auth methods (4 keys)
- Password change (6 keys)
- Account blocking (10 keys)
- Logout (2 keys)
- Phone OTP (2 keys, 1 ICU)
- Business logo (15 keys, 2 ICU)

ICU placeholders preserved (verified by apply-script assertions, 9 ICU
keys with 11 placeholder positions): helloUser ({userName}),
errorUpdatingProfile ({error}), versionAndBuild ({version}, {buildNumber}),
currencyChangedTo ({currencyName}), currencyNameAndSymbol ({name},
{symbol}), failedToSaveError ({error}), enter6DigitCodePhone ({phone}),
errorUploadingLogo ({error}), errorRemovingLogo ({error}).

Convention notes:
- "الملف الشخصي" for profile (literally "personal file")
- "الأسئلة الشائعة" for FAQ (literally "frequent questions")
- "السمة" for theme, "المظهر" for appearance
- "داكن / فاتح" for dark / light
- "اللغة" for language
- "الإشعارات" for notifications, "الإشعارات الفورية" for push
- "السمة" / "المظهر" theme/appearance distinction
- "تنبيهات" for alerts (vs إشعارات for notifications)
- "حظر / إلغاء حظر" for block / unblock
- "تسجيل الخروج" for log out
- "الشركة" for business
- "شعار" for logo
- "تحميل / حذف" for upload / remove
- "الإصدار" for version, Latin "Build" preserved
- "← arrow" preserved in FAQ instructions (UI navigation)
- Guillemets « » preserved (consistent with Batch 5)
- Em-dash — preserved in 2 keys
- Multi-paragraph \\n\\n preserved in 2 long bodies (account block dialogs)
- Bullet • preserved in blockAccountConfirmBody
- Heart emoji ❤️ + Ghana for "Made in Ghana"
- Wave emoji 👋 in helloUser
- Brand/acronym preservation: QR Wallet, WhatsApp, App Store,
  Mobile Money, PIN, OTP, KYC, Build (in version line)
- Literal email address qrwallet.support@bongroups.co preserved
- Arabic question mark ؟ in 9 question keys
- Counted noun rule: "1 إلى 3 أيام عمل" (3-10 paucal plural for "days")

Files modified: lib/l10n/app_ar.arb only.
Reference: docs/PHASE_6_STEP_10_AR_BATCH_7_PROFILE_FAQ_SETTINGS.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-ar-batch-7
```

---

## 7. Reporting (agent → operator)

Report back with:

1. Branch name: `phase6-step10-ar-batch-7`
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
   git checkout phase6-step10-ar-batch-7
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
   git merge --ff-only phase6-step10-ar-batch-7
   git tag phase6-step10-ar-batch-7-complete
   git push origin main
   git push origin phase6-step10-ar-batch-7-complete
   git push origin :phase6-step10-ar-batch-7
   git branch -d phase6-step10-ar-batch-7
   ```

---

## 10. Translation conventions (extension to AR Batches 1-6)

| Convention | Decision |
|---|---|
| (Earlier batches) Established conventions | Carry forward |
| **NEW (Batch 7)** Profile | "الملف الشخصي" |
| **NEW (Batch 7)** FAQ | "الأسئلة الشائعة" |
| **NEW (Batch 7)** Help / Support | "المساعدة" / "الدعم" |
| **NEW (Batch 7)** About | "حول" |
| **NEW (Batch 7)** Theme | "السمة" |
| **NEW (Batch 7)** Appearance | "المظهر" |
| **NEW (Batch 7)** Dark / Light (theme) | "داكن" / "فاتح" |
| **NEW (Batch 7)** Language | "اللغة" |
| **NEW (Batch 7)** English / French / Arabic | "الإنجليزية" / "الفرنسية" / "العربية" |
| **NEW (Batch 7)** Notifications | "الإشعارات" |
| **NEW (Batch 7)** Push notifications | "الإشعارات الفورية" |
| **NEW (Batch 7)** Alert | "تنبيه" / "تنبيهات" |
| **NEW (Batch 7)** Settings | "الإعدادات" |
| **NEW (Batch 7)** Block / unblock | "حظر" / "إلغاء حظر" |
| **NEW (Batch 7)** Log out | "تسجيل الخروج" |
| **NEW (Batch 7)** Business | "الشركة" |
| **NEW (Batch 7)** Logo | "شعار" |
| **NEW (Batch 7)** Upload / remove | "تحميل" / "حذف" |
| **NEW (Batch 7)** Version | "الإصدار" |
| **NEW (Batch 7)** "Build N" | Latin "Build N" preserved (technical term) |
| **NEW (Batch 7)** Update | "تحديث" |
| **NEW (Batch 7)** Encryption | "تشفير" |
| **NEW (Batch 7)** Bank-level | "بمستوى مصرفي" |
| **NEW (Batch 7)** Caught up (notifications) | "على اطّلاع كامل" |
| **NEW (Batch 7)** "Mark all as read" | "وضع علامة على الكل كمقروء" |
| **NEW (Batch 7)** Reminders | "تذكيرات" |
| **NEW (Batch 7)** Promotional | "ترويجي / ترويجية" |
| **NEW (Batch 7)** Customer service | "خدمة العملاء" |
| **NEW (Batch 7)** UI navigation arrow ← | Preserved (matches FR pattern) |
| **NEW (Batch 7)** Heart emoji ❤️ | Preserved in "صُنع بـ ❤️ في غانا" |
| **NEW (Batch 7)** Wave emoji 👋 | Preserved in helloUser |
