# Phase 6 Step 10 — French Batch 1 — Auth & Onboarding

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 1 of 8
> **Scope:** Auth & onboarding surface — 90 keys
> **Predecessor:** `phase6-step9-cleanup-4-c5-complete` @ `64a3eb5d`
> **Branch name to create:** `phase6-step10-fr-batch-1`
> **Tag to apply after merge:** `phase6-step10-fr-batch-1-complete`

---

## 1. Scope

This batch translates 90 keys covering the auth and onboarding surfaces of the app:

- Welcome screen entry buttons (`getStarted`, `skip`)
- Sign up screen (form fields, terms checkbox, social sign-in divider)
- Log in screen (form fields, biometric login, welcome back)
- Forgot password / reset password flow (email send, link sent confirmation, password changed confirmation)
- Email verification flow (post-signup verify-email screen)
- Phone OTP flow (auth signup verification — NOT transaction OTP, NOT PIN reset OTP)
- Complete-profile screen (post-phone-signup detail capture)
- Social sign-in (Apple coming-soon notice)
- App lock screen (password / PIN / biometric unlock)
- Auth success snackbars (account created, logged in)

**Out of scope for this batch:**
- KYC verification flows → Batch 2 / Batch 3
- Wallet, send, receive screens → Batch 4 / Batch 5
- Transactions and disputes → Batch 6
- Profile, FAQ, settings, security (including PIN reset, change PIN, change password from profile) → Batch 7
- Generic error resolvers (auth/firebase/biometric error keys), success snackbars not in auth, generic buttons (OK/Cancel/Save), splash, app metadata → Batch 8

**Files this batch modifies:** `lib/l10n/app_fr.arb` only. Nothing else.

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
git rev-parse origin/main
git --no-pager log --oneline -5
```

The spec doc file `docs/PHASE_6_STEP_10_FR_BATCH_1_AUTH_ONBOARDING.md` MUST exist in `origin/main` (Eric commits and pushes it before the agent runs). If not present, STOP.

```bash
test -f docs/PHASE_6_STEP_10_FR_BATCH_1_AUTH_ONBOARDING.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step9-cleanup-4-c5-complete|phase6-step10-fr-batch-1-complete"
```

Expected output:
- `phase6-step9-cleanup-4-c5-complete` MUST be present
- `phase6-step10-fr-batch-1-complete` MUST NOT be present (this batch hasn't merged yet)

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

filled = [k for k in fr_keys if fr[k] != '']
print(f"FR currently filled: {len(filled)} keys: {filled}")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected output:
- `FR currently filled: 1 keys: ['itemCount']` — `itemCount` was set to the English value during framework setup; we will NOT touch it in this batch (Batch 8 handles it).
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-1
```

---

## 3. Implementation

Single Python script. Save the script to `/tmp/apply_fr_batch_1.py`, run it, then verify and commit.

### 3.1 Translation data

The 90 French translations are in the dict below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** If a value contains an ICU placeholder (e.g. `{seconds}`, `{email}`), the placeholder MUST be preserved exactly as written here. If a value contains `\n`, it MUST be preserved as a literal newline escape in the JSON.

```python
TRANSLATIONS = {
    # --- Welcome / onboarding entry buttons ---
    "getStarted": "Commencer",
    "skip": "Passer pour l'instant",

    # --- Sign up screen ---
    "signUp": "S'inscrire",
    "signUpSubtitle": "Inscrivez-vous et passez à la vitesse supérieure",
    "createAccount": "Créer un compte",
    "alreadyHaveAccount": "Vous avez déjà un compte ?",
    "dontHaveAccount": "Vous n'avez pas de compte ?",
    "orSignUpWith": "Ou inscrivez-vous avec",
    "orLogInWith": "Ou connectez-vous avec",

    # --- Log in screen ---
    "logIn": "Se connecter",
    "logInSubtitle": "Bon retour ! Connectez-vous pour continuer",
    "welcomeBack": "Bon retour",
    "welcomeBackTitle": "Bon retour",

    # --- Common auth form fields ---
    "fullName": "Nom complet",
    "fullNameHint": "Entrez votre nom complet",
    "email": "Adresse e-mail",
    "emailHint": "Entrez votre adresse e-mail",
    "emailLabel": "E-mail",
    "enterEmailHint": "Entrez votre e-mail",
    "password": "Mot de passe",
    "passwordHint": "Entrez votre mot de passe",
    "passwordLabel": "Mot de passe",
    "enterPasswordHint": "Entrez votre mot de passe",
    "enterYourPasswordHint": "Entrez votre mot de passe",
    "enterYourPasswordTitle": "Entrez votre mot de passe",
    "passwordMustContainLabel": "Le mot de passe doit contenir :",
    "confirmPassword": "Confirmer le mot de passe",
    "confirmPasswordHint": "Confirmez votre mot de passe",
    "phoneNumber": "Numéro de téléphone",
    "phoneNumberHint": "Entrez votre numéro de téléphone",
    "phoneNumberLabel": "Numéro de téléphone",
    "enterPhoneNumberHint": "Entrez le numéro de téléphone",

    # --- Terms (signup checkbox) ---
    "pleaseAgreeToTerms": "Veuillez accepter les conditions d'utilisation et la politique de confidentialité",
    "termsAgreement": "J'accepte",
    "termsAndPrivacy": "les conditions et la politique de confidentialité",
    "termsOfServiceLink": "Conditions d'utilisation",
    "privacyPolicyLink": "Politique de confidentialité",

    # --- Forgot password / reset password flow ---
    "forgotPassword": "Mot de passe oublié ?",
    "forgotPasswordTitle": "Mot de passe oublié",
    "resetPassword": "Réinitialiser le mot de passe",
    "resetYourPasswordTitle": "Réinitialisez votre mot de passe",
    "createNewPasswordSubtitle": "Créez un nouveau mot de passe",
    "enterEmailForResetLink": "Entrez votre adresse e-mail et nous vous enverrons un lien pour réinitialiser votre mot de passe.",
    "sendResetLink": "Envoyer le lien de réinitialisation",
    "emailResetLinkSent": "Nous avons envoyé un lien de réinitialisation à :\n{email}",
    "emailSentTitle": "E-mail envoyé !",
    "checkEmailForInstructions": "Veuillez consulter votre messagerie et suivre les instructions pour réinitialiser votre mot de passe.",
    "didntReceiveTheEmail": "Vous n'avez pas reçu l'e-mail ?",
    "didntReceiveEmailTryAgain": "Pas d'e-mail reçu ? Réessayez",
    "weveSentVerificationLinkTo": "Nous avons envoyé un lien de vérification à :",
    "backToLogin": "Retour à la connexion",
    "successPasswordReset": "Lien de réinitialisation envoyé !",

    # --- Password changed confirmation (shown after forgot-password reset) ---
    "passwordChangedTitle": "Mot de passe modifié !",
    "passwordChangedBody": "Votre mot de passe a été mis à jour avec succès.",

    # --- Email verification flow ---
    "accountCreatedVerifyEmail": "Compte créé ! Veuillez vérifier votre e-mail.",
    "verifyEmail": "Vérifier l'e-mail",
    "verifyYourEmailTitle": "Vérifiez votre e-mail",
    "verificationEmailSent": "E-mail de vérification envoyé !",
    "emailVerifiedSuccessfully": "E-mail vérifié avec succès !",

    # --- Phone OTP flow (auth signup verification) ---
    "otpSentTo": "Nous avons envoyé un code de vérification à",
    "otpSentToPhone": "OTP envoyé sur votre téléphone",
    "weSent6DigitCode": "Nous avons envoyé un code à 6 chiffres à",
    "enterOtp": "Saisir l'OTP",
    "enterOtpTitle": "Saisir l'OTP",
    "verifyCodeButton": "Vérifier le code",
    "sendVerificationCodeButton": "Envoyer le code de vérification",
    "resendCode": "Renvoyer le code",
    "resendCodeButton": "Renvoyer le code",
    "resendCodeIn": "Renvoyer le code dans {seconds}s",
    "resendIn": "Renvoyer dans",
    "didntReceiveCode": "Vous n'avez pas reçu le code ?",
    "phoneVerifiedSuccessfully": "Téléphone vérifié avec succès !",
    "verifyPhone": "Vérifier le téléphone",
    "verifyPhoneTitle": "Vérifier le téléphone",
    "verifyYourPhone": "Vérifiez votre téléphone",
    "incorrectCodeError": "Code incorrect. Veuillez réessayer.",
    "failedToSendOtpError": "Échec de l'envoi de l'OTP. Veuillez réessayer.",
    "otpVerificationFailedError": "Échec de la vérification de l'OTP",
    "tooManyAttemptsError": "Trop de tentatives. Veuillez réessayer plus tard.",

    # --- Complete profile (post phone signup) ---
    "completeProfile": "Compléter le profil",
    "completeProfileSubtitle": "Nous avons besoin de quelques informations supplémentaires pour sécuriser votre compte",

    # --- Social sign-in ---
    "appleSignInComingSoon": "Connexion avec Apple bientôt disponible",

    # --- App lock screen ---
    "enterPasswordToUnlock": "Entrez votre mot de passe pour déverrouiller",
    "enterPinToUnlock": "Entrez votre code PIN pour déverrouiller",
    "unlockButton": "Déverrouiller",
    "biometricReasonAuthenticate": "Authentifiez-vous pour accéder à votre QR Wallet",
    "biometricLogin": "Connexion biométrique",
    "useBiometric": "Utiliser la biométrie",

    # --- Auth success snackbars ---
    "successAccountCreated": "Compte créé avec succès !",
    "successLoggedIn": "Bon retour !",
}

assert len(TRANSLATIONS) == 90, f"Spec dict has {len(TRANSLATIONS)} entries, expected 90"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_1.py`. The script is self-contained — it embeds the `TRANSLATIONS` dict above, validates everything, and writes the result back to `lib/l10n/app_fr.arb`.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 1 - Auth & Onboarding
Applies 90 French translations to lib/l10n/app_fr.arb.
Modifies ONLY app_fr.arb. Does not touch app_en.arb or app_ar.arb.
"""

import json
import sys
from pathlib import Path

ARB_PATH = Path("lib/l10n/app_fr.arb")
EN_PATH = Path("lib/l10n/app_en.arb")

TRANSLATIONS = {
    # PASTE THE FULL DICT FROM SECTION 3.1 ABOVE HERE.
    # The agent should copy the dict literal verbatim from the spec.
}

def main():
    # Sanity: dict size
    assert len(TRANSLATIONS) == 90, f"Expected 90 translations, got {len(TRANSLATIONS)}"

    # Load files
    fr = json.loads(ARB_PATH.read_text(encoding="utf-8"))
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))

    # Verify baseline: every spec key exists in both en and fr
    missing_in_en = [k for k in TRANSLATIONS if k not in en]
    missing_in_fr = [k for k in TRANSLATIONS if k not in fr]
    assert not missing_in_en, f"Spec keys missing in en: {missing_in_en}"
    assert not missing_in_fr, f"Spec keys missing in fr: {missing_in_fr}"

    # Verify baseline: every spec key is currently empty in fr
    # (allow exception for itemCount which we don't touch — but it's not in our spec)
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

    # Verify: ICU placeholder preservation in spec values
    # (Spot-checks for the two ICU keys in this batch)
    assert "{email}" in fr["emailResetLinkSent"], "emailResetLinkSent lost {email} placeholder"
    assert "{seconds}" in fr["resendCodeIn"], "resendCodeIn lost {seconds} placeholder"
    assert "\n" in fr["emailResetLinkSent"], "emailResetLinkSent lost newline"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 1, expected {1 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_1.py
```

Expected output (approximately):
```
OK — applied 90 translations
FR filled: 91/701 (was 1, expected 91)
FR empty: 610
```

If any assertion fires, STOP and report.

---

## 4. Verification

After the script runs, the agent runs these independent verifications:

### 4.1 Confirm only app_fr.arb changed

```bash
git status
```

Expected:
- `modified: lib/l10n/app_fr.arb`
- No other modifications. No untracked spec-related files (the agent's `/tmp/` script doesn't get committed).

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
- FR filled: 91

### 4.3 Confirm ar file untouched

```bash
git diff --stat lib/l10n/app_ar.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: no output (no changes) for either.

### 4.4 Confirm spec keys all hold spec values

```bash
python3 << 'PYEOF'
import json

# Spec values for spot-check
SPOT_CHECK = {
    "signUp": "S'inscrire",
    "logIn": "Se connecter",
    "createAccount": "Créer un compte",
    "forgotPassword": "Mot de passe oublié ?",
    "biometricReasonAuthenticate": "Authentifiez-vous pour accéder à votre QR Wallet",
    "successAccountCreated": "Compte créé avec succès !",
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

Nothing else. If `lib/generated/l10n/` shows up in staging, UNSTAGE IT.

Commit with the message in `/tmp/commit_msg.txt`:

```bash
cat > /tmp/commit_msg.txt << 'EOF'
10.fr-batch-1: French translations for auth & onboarding (90 keys)

Translates 90 keys covering the auth and onboarding surface:
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

Convention notes:
- Brand names stay English: QR Wallet, Apple
- OTP retained as 'OTP' for francophone fintech parity
- PIN translated as 'code PIN' for clarity
- Formal register throughout (vous, not tu)
- French typography (space before ! ? : ;)
- ICU placeholders preserved: {email} in emailResetLinkSent, {seconds} in resendCodeIn

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_1_AUTH_ONBOARDING.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-1
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-1-complete` — that is Eric's job after merge.

---

## 7. Reporting (agent → Eric)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-1`
2. **Final commit SHA:** (from `git rev-parse HEAD`)
3. **Output of all verification steps** (sections 4.1, 4.2, 4.3, 4.4)
4. **Output of the apply script** (section 3.2 run command)
5. **`git diff --stat HEAD~1 HEAD`** to confirm only `lib/l10n/app_fr.arb` was touched
6. **Confirm `lib/generated/l10n/` was NOT staged or committed**
7. **Any deviations from this spec** with reasoning

---

## 8. STOP and report (do NOT improvise) if:

- Any pre-work check (Section 2) fails
- Any assertion in the apply script (Section 3.2) fires
- Any verification check (Section 4) fails
- Reality contradicts spec literal text in non-trivial ways
- The spec dict turns out to have wrong key count, missing keys, or duplicate keys

---

## 9. After agent reports back — Eric's tasks

(Not for the agent — these are documented here for traceability.)

1. Pull the branch locally:
   ```bash
   git fetch origin
   git checkout phase6-step10-fr-batch-1
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

   Expected: only `lib/generated/l10n/app_localizations_fr.dart` (and possibly `app_localizations.dart`) shows changes. The ARB files should not appear.

4. **Per established workflow:** generated files are NOT committed. They are regenerated locally on every pull and left as untracked/ignored changes. Do NOT `git add` anything under `lib/generated/l10n/`.

5. Run analyzer + build:
   ```bash
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```

   Expected: 204 analyzer issues (baseline), build green. If analyzer count goes up, STOP — likely an ICU placeholder mismatch in the ARB.

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

7. Merge with `--ff-only`:
   ```bash
   git checkout main
   git merge --ff-only phase6-step10-fr-batch-1
   ```

8. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-1-complete
   git push origin main
   git push origin phase6-step10-fr-batch-1-complete
   git push origin :phase6-step10-fr-batch-1
   git branch -d phase6-step10-fr-batch-1
   ```

---

## 10. Translation conventions (reference for French reviewer)

These conventions apply to ALL French batches in Step 10, not just Batch 1. Documented here for the reviewer's reference.

| Convention | Decision |
|---|---|
| Register | Formal (vous, not tu) |
| Email | "e-mail" with hyphen |
| OTP | Kept as "OTP" (familiar in francophone fintech) |
| PIN | "code PIN" (clearer than just "PIN" alone) |
| Wallet (generic) | "portefeuille" |
| Wallet (brand "QR Wallet") | Stays in English |
| Brand names | Stay in English: QR Wallet, MTN MoMo, Apple, Paystack, WhatsApp |
| Send money | "envoyer de l'argent" |
| Withdraw | "retirer" |
| Balance | "solde" |
| Transaction | "transaction" |
| Punctuation | French typography: space before ! ? : ; |
| Imperative for hints | "Entrez..." (active voice for placeholder hints) |
| Imperative for screen titles | "Vérifiez votre..." (second-person imperative for verb-leading titles) |

---


