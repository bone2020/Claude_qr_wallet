# Phase 6 Step 10 — French Batch 7 — Profile, FAQ, Settings, Security

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 7 of 9
> **Scope:** Profile, FAQ, Help & Support, About, Settings (theme/language/currency/notifications), Security (PIN/password/account block), Business profile/logo — 152 keys
> **Predecessor:** `phase6-step10-fr-batch-6-complete` @ `8b764a5d`
> **Branch name to create:** `phase6-step10-fr-batch-7`
> **Tag to apply after merge:** `phase6-step10-fr-batch-7-complete`

---

## 1. Scope

This batch translates 152 keys covering profile, FAQ, settings, and security surfaces. **Largest batch in Step 10** — combines all profile/settings/security content into one shipping unit.

- Profile screens (8 keys, 1 ICU) — profile, edit profile, photo controls, KYC name lock, hello-user
- Edit profile result (3 keys, 1 ICU) — saving state, success snackbar, error snackbar
- FAQ (13 keys) — section header + 6 long Q&A pairs
- Help & Support (14 keys) — help screens, contact us, email/whatsapp support, share, rate
- About (6 keys, 1 ICU) — about screen, app description, copyright, version
- Settings sections (5 keys) — section headers across settings
- Theme (10 keys) — appearance, theme labels, dark/light/system + subtitles, preview
- Language (8 keys) — language picker, English/French/Arabic, first-launch prompt
- Currency selector (6 keys, 2 ICU) — selector, change confirmation, currency name format
- Notifications (22 keys, 1 ICU) — settings, notification types (push/email/transaction/security/promo/reminders), toasts
- Security section header (1 key)
- PIN management (15 keys) — change PIN, reset PIN, success states, security note, identity verify
- PIN reset verification methods (4 keys) — email/password method, OTP method
- Password change (8 keys) — current/new/confirm fields and hints
- Account block/unblock (10 keys) — block confirmation with bullet list, blocked-by-support states
- Logout (2 keys) — log out + confirmation
- Phone management (2 keys, 1 ICU) — no-phone-linked subtitle + 6-digit code with phone placeholder
- Business profile/logo (15 keys, 2 ICU) — upload, remove, embed-in-QR captions, error toasts

**Out of scope for this batch:**
- System error resolvers (auth*, firebaseAuth*, generic error keys), generic UI buttons (OK/Cancel/Save/Close/Done/Retry/Back/etc.), splash, app metadata, `enterTpinHint` cleanup → Batch 8

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
test -f docs/PHASE_6_STEP_10_FR_BATCH_7_PROFILE_SETTINGS_SECURITY.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-6-complete|phase6-step10-fr-batch-7-complete"
```

Expected:
- `phase6-step10-fr-batch-6-complete` MUST be present
- `phase6-step10-fr-batch-7-complete` MUST NOT be present

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
print(f"FR currently filled: {filled} keys (expected 469 = 1 itemCount + 90 + 92 + 52 + 35 + 73 + 87 + 39 from Batches 1-6)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 469 keys (expected 469 = 1 itemCount + 90 + 92 + 52 + 35 + 73 + 87 + 39 from Batches 1-6)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-7
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_7.py`, run, then verify and commit.

### 3.1 Translation data

The 152 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters, emoji, bullet characters `•`, arrow `→`, French guillemets `« »`, literal `\n` newlines) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Profile screens (8 keys, 1 ICU) ---
    "profile": "Profil",
    "profilePhoto": "Photo de profil",
    "editProfile": "Modifier le profil",
    "changePhotoButton": "Changer la photo",
    "changeButton": "Modifier",
    "defaultUserName": "Utilisateur",
    "nameVerifiedKycCannotChange": "Nom vérifié via KYC — ne peut pas être modifié",
    "helloUser": "Bonjour, {userName} 👋",

    # --- Edit profile result (3 keys, 1 ICU) ---
    "saving": "Enregistrement...",
    "successProfileUpdated": "Profil mis à jour avec succès !",
    "errorUpdatingProfile": "Erreur lors de la mise à jour du profil : {error}",

    # --- FAQ (13 keys) ---
    "faqSection": "Questions fréquentes",
    "faqAddMoneyQuestion": "Comment ajouter de l'argent à mon portefeuille ?",
    "faqAddMoneyAnswer": "Vous pouvez ajouter de l'argent par carte, Mobile Money ou virement bancaire. Allez dans Accueil → Ajouter de l'argent et choisissez votre méthode préférée.",
    "faqChangePinQuestion": "Comment modifier mon code PIN ?",
    "faqChangePinAnswer": "Allez dans Profil → Modifier le code PIN. Saisissez votre code PIN actuel, puis créez et confirmez votre nouveau code PIN.",
    "faqForgotPasswordQuestion": "Que faire si j'oublie mon mot de passe ?",
    "faqForgotPasswordAnswer": "Sur l'écran de connexion, appuyez sur « Mot de passe oublié ? » et saisissez votre e-mail. Nous vous enverrons un lien de réinitialisation.",
    "faqMoneySafeQuestion": "Mon argent est-il en sécurité ?",
    "faqMoneySafeAnswer": "Oui ! Nous utilisons un chiffrement de niveau bancaire et des processeurs de paiement sécurisés. Vos fonds sont protégés en permanence.",
    "faqSendMoneyQuestion": "Comment envoyer de l'argent à quelqu'un ?",
    "faqSendMoneyAnswer": "Appuyez sur « Envoyer » sur l'écran d'accueil, saisissez l'ID du portefeuille du destinataire ou scannez son QR code, saisissez le montant, et confirmez.",
    "faqWithdrawalTimeQuestion": "Combien de temps prennent les retraits ?",
    "faqWithdrawalTimeAnswer": "Les virements bancaires prennent généralement 1 à 3 jours ouvrables. Les retraits Mobile Money sont généralement instantanés.",

    # --- Help & Support (14 keys) ---
    "helpAndSupportTitle": "Aide et support",
    "helpSupport": "Aide et support",
    "contactUsSection": "Nous contacter",
    "followUsSection": "Suivez-nous",
    "supportSection": "Support",
    "emailSupportLabel": "Support par e-mail",
    "emailSupportSubject": "Demande de support QR Wallet",
    "whatsappSupportLabel": "Support WhatsApp",
    "whatsappSupportSubtitle": "Discutez avec nous sur WhatsApp",
    "couldNotOpenEmailToast": "Impossible d'ouvrir l'application de messagerie. Veuillez nous écrire à qrwallet.support@bongroups.co",
    "shareAppLink": "Partager l'application",
    "rateUsLink": "Évaluer l'application",
    "rateUsToast": "Évaluez-nous sur l'App Store !",
    "shareComingSoonToast": "Fonctionnalité de partage bientôt disponible !",

    # --- About (6 keys, 1 ICU) ---
    "about": "À propos",
    "aboutTitle": "À propos",
    "aboutAppDescription": "QR Wallet est un portefeuille numérique sécurisé et facile à utiliser qui vous permet d'envoyer, recevoir et gérer de l'argent en un seul scan. Découvrez l'avenir des paiements dès aujourd'hui.",
    "copyrightLine": "© 2024 QR Wallet. Tous droits réservés.",
    "madeInGhanaLine": "Fait avec ❤️ au Ghana",
    "versionAndBuild": "Version {version} (Build {buildNumber})",

    # --- Settings sections (5 keys) ---
    "generalSection": "Général",
    "preferencesSection": "Préférences",
    "securityAndUpdatesSection": "Sécurité et mises à jour",
    "accountSettings": "Paramètres du compte",
    "accountSafetySection": "Sécurité du compte",

    # --- Theme (10 keys) ---
    "appearanceMenuItem": "Apparence",
    "themeLabel": "Thème",
    "darkMode": "Mode sombre",
    "darkThemeLabel": "Sombre",
    "darkThemeSubtitle": "Fond sombre avec texte clair",
    "lightThemeLabel": "Clair",
    "lightThemeSubtitle": "Fond clair avec texte sombre",
    "systemThemeLabel": "Système",
    "systemThemeSubtitle": "Suivre les paramètres du système",
    "previewLabel": "Aperçu",

    # --- Language (8 keys) ---
    "language": "Langue",
    "languageDescription": "Choisissez la langue que vous souhaitez utiliser dans toute l'application et dans les notifications.",
    "languageEnglish": "Anglais",
    "languageFrench": "Français",
    "languageArabic": "Arabe",
    "selectLanguage": "Sélectionner la langue",
    "languageChanged": "Langue modifiée",
    "firstLaunchLanguagePrompt": "Choisissez votre langue",

    # --- Currency selector (6 keys, 2 ICU) ---
    "currencyLabel": "Devise",
    "selectCurrencyTitle": "Sélectionner la devise",
    "currencySelectorDescription": "Choisissez votre devise préférée pour afficher les soldes et les transactions.",
    "currencyChangedTo": "Devise modifiée pour {currencyName}",
    "currencyNameAndSymbol": "{name} ({symbol})",
    "failedToChangeCurrency": "Échec du changement de devise",

    # --- Notifications (22 keys, 1 ICU) ---
    "notifications": "Notifications",
    "notificationSettingsTitle": "Paramètres de notification",
    "notificationsScreenTitle": "Notifications",
    "noNotifications": "Aucune notification",
    "failedToLoadNotifications": "Échec du chargement des notifications",
    "markAllAsRead": "Tout marquer comme lu",
    "youreAllCaughtUp": "Vous êtes à jour !",
    "pushNotificationsLabel": "Notifications push",
    "pushNotificationsSubtitle": "Recevoir des notifications sur votre appareil",
    "emailNotificationsLabel": "Notifications par e-mail",
    "emailNotificationsSubtitle": "Recevoir des mises à jour par e-mail",
    "transactionAlertsLabel": "Alertes de transaction",
    "transactionAlertsSubtitle": "Soyez notifié pour toutes les transactions",
    "securityAlertsLabel": "Alertes de sécurité",
    "securityAlertsSubtitle": "Notifications de sécurité importantes",
    "securityAlertsCannotBeDisabledNote": "Les alertes de sécurité ne peuvent pas être désactivées pour votre protection.",
    "promotionalUpdatesLabel": "Mises à jour promotionnelles",
    "promotionalUpdatesSubtitle": "Offres, actualités et promotions",
    "paymentRemindersLabel": "Rappels de paiement",
    "paymentRemindersSubtitle": "Rappels pour les paiements en attente",
    "settingsSavedToast": "Paramètres enregistrés",
    "failedToSaveError": "Échec de l'enregistrement : {error}",

    # --- Security section header (1 key) ---
    "security": "Sécurité",

    # --- PIN management (15 keys) ---
    "changePin": "Modifier le code PIN",
    "changePinAction": "Modifier le code PIN",
    "resetPinAction": "Réinitialiser le code PIN",
    "forgotPinLink": "Code PIN oublié ?",
    "enterNewPinStepTitle": "Saisir le nouveau code PIN",
    "confirmNewPinStepTitle": "Confirmer le nouveau code PIN",
    "createNewPinSubtitle": "Créez un nouveau code PIN de transaction à 6 chiffres",
    "reenterNewPinSubtitle": "Saisissez à nouveau votre nouveau code PIN pour confirmer",
    "pinChangedTitle": "Code PIN modifié !",
    "pinChangedBody": "Votre code PIN de transaction a été mis à jour avec succès.",
    "pinResetTitle": "Code PIN réinitialisé !",
    "pinResetBody": "Votre code PIN de transaction a été réinitialisé avec succès.",
    "pinSecurityNote": "Votre code PIN est chiffré de manière sécurisée et utilisé pour autoriser les transactions.",
    "resetPinVerifyIdentityBody": "Pour réinitialiser votre code PIN, veuillez vérifier votre identité en utilisant l'une des options ci-dessous.",
    "resetPinSecurityAssurance": "Cette vérification garantit que vous seul pouvez réinitialiser votre code PIN.",

    # --- PIN reset verification methods (4 keys) ---
    "emailAndPasswordMethod": "E-mail et mot de passe",
    "emailAndPasswordSubtitle": "Vérifier en utilisant vos identifiants de connexion",
    "verifyByCredentialsBody": "Vérifiez votre identité en saisissant vos identifiants de connexion.",
    "verifyOtpToPhoneSubtitle": "Vérifier via OTP envoyé à votre téléphone",

    # --- Password change (8 keys) ---
    "changePassword": "Modifier le mot de passe",
    "changePasswordAction": "Modifier le mot de passe",
    "currentPasswordLabel": "Mot de passe actuel",
    "newPasswordLabel": "Nouveau mot de passe",
    "confirmNewPasswordLabel": "Confirmer le nouveau mot de passe",
    "enterCurrentPasswordHint": "Saisissez le mot de passe actuel",
    "enterNewPasswordHint": "Saisissez le nouveau mot de passe",
    "reenterNewPasswordHint": "Saisissez à nouveau le nouveau mot de passe",

    # --- Account block/unblock (10 keys) ---
    "blockAccountLabel": "Bloquer le compte",
    "unblockAccountLabel": "Débloquer le compte",
    "blockAccountConfirmBody": "Êtes-vous sûr de vouloir bloquer votre compte ?\n\nCela empêchera toutes les transactions, notamment :\n• Envoi d'argent\n• Retrait de fonds\n• Ajout d'argent\n\nVous pouvez débloquer à tout moment avec votre code PIN.",
    "accountBlockedSuccessToast": "Compte bloqué avec succès. Toutes les transactions sont désactivées.",
    "accountUnblockedSuccessToast": "Compte débloqué avec succès. Toutes les transactions sont à nouveau activées.",
    "accountBlockedSubtitle": "Votre compte est actuellement bloqué",
    "temporarilyDisableSubtitle": "Désactiver temporairement toutes les transactions",
    "accountBlockedBySupportTitle": "Compte bloqué par le support",
    "accountBlockedBySupportBody": "Votre compte a été bloqué par le service client pour des raisons de sécurité.\n\nVeuillez contacter notre équipe de support pour vérifier votre identité et débloquer votre compte.",
    "blockedBySupportSubtitle": "Bloqué par le support — contactez-nous pour débloquer",

    # --- Logout (2 keys) ---
    "logOut": "Se déconnecter",
    "logoutConfirmBody": "Êtes-vous sûr de vouloir vous déconnecter ?",

    # --- Phone management (2 keys, 1 ICU) ---
    "noPhoneNumberLinkedSubtitle": "Aucun numéro de téléphone lié à votre compte",
    "enter6DigitCodePhone": "Saisissez le code à 6 chiffres envoyé à {phone}",

    # --- Business profile/logo (15 keys, 2 ICU) ---
    "businessLabel": "Entreprise",
    "businessLogoLabel": "Logo de l'entreprise",
    "businessLogoUploadedToast": "Logo de l'entreprise téléversé avec succès",
    "businessLogoRemovedToast": "Logo de l'entreprise supprimé",
    "removeLogoTitle": "Supprimer le logo",
    "removeLogoConfirmBody": "Êtes-vous sûr de vouloir supprimer le logo de votre entreprise ?",
    "uploadBusinessLogoTitle": "Téléverser le logo de l'entreprise",
    "addBusinessLogoSubtitle": "Ajoutez le logo de votre entreprise",
    "logoUploadedSubtitle": "Logo téléversé",
    "logoAppearInQrCaption": "Ce logo apparaîtra dans vos QR codes de paiement",
    "logoEmbeddedInQrCaption": "Ce logo sera intégré dans vos QR codes de paiement",
    "removeButton": "Supprimer",
    "uploadButton": "Téléverser",
    "errorUploadingLogo": "Erreur lors du téléversement du logo : {error}",
    "errorRemovingLogo": "Erreur lors de la suppression du logo : {error}",
}

assert len(TRANSLATIONS) == 152, f"Spec dict has {len(TRANSLATIONS)} entries, expected 152"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_7.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 7 - Profile, FAQ, Settings, Security
Applies 152 French translations to lib/l10n/app_fr.arb.
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
    assert len(TRANSLATIONS) == 152, f"Expected 152 translations, got {len(TRANSLATIONS)}"

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

    # Verify: ICU placeholder preservation for all 9 ICU keys in this batch
    assert "{userName}" in fr["helloUser"], "helloUser lost {userName}"
    assert "{error}" in fr["errorUpdatingProfile"], "errorUpdatingProfile lost {error}"
    assert "{version}" in fr["versionAndBuild"], "versionAndBuild lost {version}"
    assert "{buildNumber}" in fr["versionAndBuild"], "versionAndBuild lost {buildNumber}"
    assert "{currencyName}" in fr["currencyChangedTo"], "currencyChangedTo lost {currencyName}"
    assert "{name}" in fr["currencyNameAndSymbol"], "currencyNameAndSymbol lost {name}"
    assert "{symbol}" in fr["currencyNameAndSymbol"], "currencyNameAndSymbol lost {symbol}"
    assert "{error}" in fr["failedToSaveError"], "failedToSaveError lost {error}"
    assert "{phone}" in fr["enter6DigitCodePhone"], "enter6DigitCodePhone lost {phone}"
    assert "{error}" in fr["errorUploadingLogo"], "errorUploadingLogo lost {error}"
    assert "{error}" in fr["errorRemovingLogo"], "errorRemovingLogo lost {error}"

    # Verify: emoji preservation
    assert "👋" in fr["helloUser"], "helloUser lost 👋 emoji"
    assert "❤️" in fr["madeInGhanaLine"], "madeInGhanaLine lost ❤️ emoji"

    # Verify: bullet character + literal newlines in blockAccountConfirmBody
    assert "•" in fr["blockAccountConfirmBody"], "blockAccountConfirmBody lost • bullet"
    assert "\n" in fr["blockAccountConfirmBody"], "blockAccountConfirmBody lost newline"
    # Count bullets: should be 3 (matches en source)
    bullet_count = fr["blockAccountConfirmBody"].count("•")
    assert bullet_count == 3, f"blockAccountConfirmBody has {bullet_count} bullets, expected 3"

    # Verify: literal newlines in accountBlockedBySupportBody
    assert "\n" in fr["accountBlockedBySupportBody"], "accountBlockedBySupportBody lost newline"

    # Verify: arrow character → preserved in FAQ answers (matches en source)
    assert "→" in fr["faqAddMoneyAnswer"], "faqAddMoneyAnswer lost → arrow"
    assert "→" in fr["faqChangePinAnswer"], "faqChangePinAnswer lost → arrow"

    # Verify: French guillemets preserved in FAQ answers
    assert "« Mot de passe oublié ? »" in fr["faqForgotPasswordAnswer"], \
        "faqForgotPasswordAnswer lost French guillemets"
    assert "« Envoyer »" in fr["faqSendMoneyAnswer"], \
        "faqSendMoneyAnswer lost French guillemets"

    # Verify: support email address preserved exactly in couldNotOpenEmailToast
    assert "qrwallet.support@bongroups.co" in fr["couldNotOpenEmailToast"], \
        "couldNotOpenEmailToast lost support email address"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 469, expected {469 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_7.py
```

Expected output (approximately):
```
OK — applied 152 translations
FR filled: 621/701 (was 469, expected 621)
FR empty: 80
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
- FR filled: 621

### 4.3 Confirm ar and en files untouched

```bash
git diff --stat lib/l10n/app_ar.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty output for both.

### 4.4 Confirm spec keys hold spec values + ICU + special chars

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "profile": "Profil",
    "editProfile": "Modifier le profil",
    "helloUser": "Bonjour, {userName} 👋",
    "errorUpdatingProfile": "Erreur lors de la mise à jour du profil : {error}",
    "faqSection": "Questions fréquentes",
    "faqMoneySafeAnswer": "Oui ! Nous utilisons un chiffrement de niveau bancaire et des processeurs de paiement sécurisés. Vos fonds sont protégés en permanence.",
    "faqSendMoneyAnswer": "Appuyez sur « Envoyer » sur l'écran d'accueil, saisissez l'ID du portefeuille du destinataire ou scannez son QR code, saisissez le montant, et confirmez.",
    "helpAndSupportTitle": "Aide et support",
    "couldNotOpenEmailToast": "Impossible d'ouvrir l'application de messagerie. Veuillez nous écrire à qrwallet.support@bongroups.co",
    "aboutAppDescription": "QR Wallet est un portefeuille numérique sécurisé et facile à utiliser qui vous permet d'envoyer, recevoir et gérer de l'argent en un seul scan. Découvrez l'avenir des paiements dès aujourd'hui.",
    "madeInGhanaLine": "Fait avec ❤️ au Ghana",
    "versionAndBuild": "Version {version} (Build {buildNumber})",
    "darkThemeSubtitle": "Fond sombre avec texte clair",
    "languageFrench": "Français",
    "currencyChangedTo": "Devise modifiée pour {currencyName}",
    "youreAllCaughtUp": "Vous êtes à jour !",
    "securityAlertsCannotBeDisabledNote": "Les alertes de sécurité ne peuvent pas être désactivées pour votre protection.",
    "changePin": "Modifier le code PIN",
    "pinSecurityNote": "Votre code PIN est chiffré de manière sécurisée et utilisé pour autoriser les transactions.",
    "blockAccountConfirmBody": "Êtes-vous sûr de vouloir bloquer votre compte ?\n\nCela empêchera toutes les transactions, notamment :\n• Envoi d'argent\n• Retrait de fonds\n• Ajout d'argent\n\nVous pouvez débloquer à tout moment avec votre code PIN.",
    "logoutConfirmBody": "Êtes-vous sûr de vouloir vous déconnecter ?",
    "enter6DigitCodePhone": "Saisissez le code à 6 chiffres envoyé à {phone}",
    "logoEmbeddedInQrCaption": "Ce logo sera intégré dans vos QR codes de paiement",
    "errorUploadingLogo": "Erreur lors du téléversement du logo : {error}",
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
10.fr-batch-7: French translations for Profile, FAQ, Settings, Security (152 keys)

Translates 152 keys covering profile, FAQ, help & support, about,
settings (theme/language/currency/notifications), security (PIN/password
/account block), and business profile surfaces. Largest batch in
Step 10 — combines all profile/settings/security content into one
shipping unit.

Coverage:
- Profile screens (8 keys, 1 ICU) — profile, edit profile, photo
  controls, KYC name lock, hello-user
- Edit profile result (3 keys, 1 ICU)
- FAQ (13 keys) — section header + 6 long Q&A pairs
- Help & Support (14 keys)
- About (6 keys, 1 ICU) — version ICU, copyright, made-in-Ghana
- Settings sections (5 keys)
- Theme (10 keys)
- Language (8 keys) — picker, French/English/Arabic, first-launch
- Currency selector (6 keys, 2 ICU)
- Notifications (22 keys, 1 ICU) — settings + 6 notification types
- Security section header (1 key)
- PIN management (15 keys) — change/reset PIN, success states
- PIN reset verification methods (4 keys)
- Password change (8 keys)
- Account block/unblock (10 keys) — with bullet list + multi-paragraph
- Logout (2 keys)
- Phone management (2 keys, 1 ICU)
- Business profile/logo (15 keys, 2 ICU)

ICU placeholders preserved (verified by apply-script assertions, 9 ICU
keys with 11 placeholder positions): helloUser, errorUpdatingProfile,
versionAndBuild, currencyChangedTo, currencyNameAndSymbol,
failedToSaveError, enter6DigitCodePhone, errorUploadingLogo,
errorRemovingLogo.

Special character preservation verified by assertions:
- 👋 emoji in helloUser
- ❤️ emoji in madeInGhanaLine
- • bullet characters (3 of them) in blockAccountConfirmBody
- Literal newlines in blockAccountConfirmBody and
  accountBlockedBySupportBody
- → arrow in faqAddMoneyAnswer and faqChangePinAnswer
- French guillemets « » in faqForgotPasswordAnswer and
  faqSendMoneyAnswer
- Support email address qrwallet.support@bongroups.co preserved
  literally in couldNotOpenEmailToast

Convention notes:
- "Profil" for profile, "Paramètres" for settings
- "Modifier" for "Change" in PIN/password/profile contexts (modify
  existing value), "Changer" for photo (swap one for another)
- "Code PIN" for PIN throughout (matches Batch 1 convention)
- "Devise" for currency (matches Batch 4b)
- "Solde" for balance (matches Batch 4b)
- "Téléverser" for upload (matches Batch 2 convention)
- "Aide et support" for "Help & Support"
- "Questions fréquentes" for FAQ section
- "Sécurité" for security
- "Sombre / Clair / Système" for dark/light/system theme
- "Anglais / Français / Arabe" for language names
- "Mode sombre" for "Dark Mode"
- "À propos" for About
- "Tous droits réservés" for copyright phrase
- "Bloquer / Débloquer" for block/unblock account
- "Se déconnecter" for log out
- Brand names stay English: QR Wallet, MTN MoMo, Mobile Money,
  WhatsApp, App Store, Paystack

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_7_PROFILE_SETTINGS_SECURITY.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-7
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-7-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-7`
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
   git checkout phase6-step10-fr-batch-7
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

   Expected: 204 analyzer issues (baseline), build green. If analyzer count goes up, STOP — likely an ICU placeholder mismatch or special-character integrity failure (this batch has 9 ICU keys, emoji, bullet characters, multi-paragraph newlines, French guillemets, and arrow characters — special-character integrity is critical).

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
   git merge --ff-only phase6-step10-fr-batch-7
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-7-complete
   git push origin main
   git push origin phase6-step10-fr-batch-7-complete
   git push origin :phase6-step10-fr-batch-7
   git branch -d phase6-step10-fr-batch-7
   ```

---

## 10. Translation conventions (extension to Batches 1-6)

These conventions apply to ALL French batches in Step 10, with profile/settings/security additions for Batch 7.

| Convention | Decision |
|---|---|
| (Batches 1-6) Register | Formal (vous, not tu) |
| (Batches 1-6) Brand names | Stay in English |
| (Batches 1-6) Punctuation | French typography (space before ! ? : ;) |
| **NEW (Batch 7)** Profile | "Profil" |
| **NEW (Batch 7)** Settings | "Paramètres" |
| **NEW (Batch 7)** "Change" (modify a value) | "Modifier" (used for PIN, password, profile info) |
| **NEW (Batch 7)** "Change" (swap/replace) | "Changer" (used for photo, language, currency) |
| **NEW (Batch 7)** "Edit profile" | "Modifier le profil" |
| **NEW (Batch 7)** FAQ | "Questions fréquentes" |
| **NEW (Batch 7)** Help & Support | "Aide et support" |
| **NEW (Batch 7)** About | "À propos" |
| **NEW (Batch 7)** "All rights reserved" | "Tous droits réservés" |
| **NEW (Batch 7)** Theme labels | "Sombre" / "Clair" / "Système" |
| **NEW (Batch 7)** Language names | "Anglais" / "Français" / "Arabe" |
| **NEW (Batch 7)** Currency name | "Devise" (matches Batch 4b) |
| **NEW (Batch 7)** Notifications | "Notifications" |
| **NEW (Batch 7)** Push notifications | "Notifications push" |
| **NEW (Batch 7)** Email notifications | "Notifications par e-mail" |
| **NEW (Batch 7)** Promotional updates | "Mises à jour promotionnelles" |
| **NEW (Batch 7)** Security alerts | "Alertes de sécurité" |
| **NEW (Batch 7)** Security | "Sécurité" |
| **NEW (Batch 7)** Block account | "Bloquer le compte" |
| **NEW (Batch 7)** Unblock account | "Débloquer le compte" |
| **NEW (Batch 7)** Log out | "Se déconnecter" |
| **NEW (Batch 7)** Reset PIN | "Réinitialiser le code PIN" |
| **NEW (Batch 7)** "X has been updated" | "X a été mis à jour" / "mise à jour" with agreement |
| **NEW (Batch 7)** Business | "Entreprise" |
| **NEW (Batch 7)** Business logo | "Logo de l'entreprise" |
| **NEW (Batch 7)** "Are you sure you want to..." | "Êtes-vous sûr de vouloir..." (matches Batch 4a) |
| **NEW (Batch 7)** Saving... | "Enregistrement..." |
| **NEW (Batch 7)** Settings saved | "Paramètres enregistrés" |
| **NEW (Batch 7)** Mark all as read | "Tout marquer comme lu" |
| **NEW (Batch 7)** "All caught up" idiom | "Vous êtes à jour" |
| **NEW (Batch 7)** Made in Ghana phrase | "Fait avec ❤️ au Ghana" (preserve emoji) |
