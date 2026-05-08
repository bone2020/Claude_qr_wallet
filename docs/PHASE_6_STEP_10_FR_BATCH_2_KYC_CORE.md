# Phase 6 Step 10 — French Batch 2 — KYC Core Flow

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 2 of 8
> **Scope:** KYC core flow — 92 keys
> **Predecessor:** `phase6-step10-fr-batch-1-complete` @ `007dff75`
> **Branch name to create:** `phase6-step10-fr-batch-2`
> **Tag to apply after merge:** `phase6-step10-fr-batch-2-complete`

---

## 1. Scope

This batch translates 92 keys covering the KYC core flow:

- KYC main verification screen (19 keys) — verify buttons, document capture, verification in-progress/success/failed states
- Document capture (11 keys) — take photo, upload front/back, gallery, face scan
- Biometric (13 keys) — 10 device-state error keys + no-biometrics toast + 2 prompt-reason keys (orphan `biometricReasonChangeSecurity` + ICU `biometricReasonConfirmPayment`)
- Smile ID errors (12 keys) — all 12 result codes from smile_id_localization_resolver
- KYC error keys (12 keys) — the `kycError*` family
- Generic error keys (11 keys) — the `genericError*` family (KYC-context errors)
- ID type selector (11 keys) — verification method, government ID, ID number entry, date of birth picker
- Country picker (3 keys) — title, search hint, display format ICU

**Out of scope for this batch:**
- Country-specific ID verification screens (NIN, BVN, passport, drivers license, voters card, SSNIT, Uganda NIN, TPIN) → Batch 3
- `couldNotVerifyAccountError` (wallet account verification) → Batch 4
- `verifyingPaymentBody`, `verifyingPaymentTitle` (payment flow) → Batch 5
- `verifyOtpToPhoneSubtitle`, `verifyByCredentialsBody`, `emailAndPasswordMethod`, `emailAndPasswordSubtitle` (PIN reset verification under profile/security) → Batch 7
- `nameVerifiedKycCannotChange` (profile screen UI) → Batch 7

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
test -f docs/PHASE_6_STEP_10_FR_BATCH_2_KYC_CORE.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-1-complete|phase6-step10-fr-batch-2-complete"
```

Expected:
- `phase6-step10-fr-batch-1-complete` MUST be present
- `phase6-step10-fr-batch-2-complete` MUST NOT be present

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
print(f"FR currently filled: {filled} keys (expected 91 = 1 itemCount + 90 from Batch 1)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 91 keys (expected 91 = 1 itemCount + 90 from Batch 1)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-2
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_2.py`, run, then verify and commit.

### 3.1 Translation data

The 92 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- KYC main verification screen (19 keys) ---
    "verify": "Vérifier",
    "verifyButton": "Vérifier",
    "verifyIdentityDefaultDescription": "Vérifier votre identité",
    "verifyYourIdentityTitle": "Vérifiez votre identité",
    "verifyYourDocumentTitle": "Vérifiez votre {documentType}",
    "documentCapturedTitle": "Document capturé",
    "documentCapturedBody": "Votre {documentType} a été capturé. La vérification commencera lorsque vous continuerez.",
    "verificationDescription": "Nous allons capturer votre document et prendre un selfie pour vérifier votre identité",
    "verificationDoNotCloseApp": "Vous serez automatiquement redirigé une fois la vérification terminée. Ne fermez pas l'application.",
    "verificationFailed": "Échec de la vérification. Veuillez réessayer.",
    "verificationFailedAgainError": "Échec de la vérification. Veuillez réessayer.",
    "verificationFailedMessage": "Votre vérification d'identité n'a pas réussi. Cela peut être dû à une non-correspondance du visage ou à un problème de document. Veuillez réessayer.",
    "verificationFailedTitle": "Échec de la vérification",
    "verificationFailedWithError": "Échec de la vérification : {error}",
    "verificationInProgressMessage": "Vos documents d'identité sont en cours de vérification. Cela prend généralement quelques secondes mais peut prendre jusqu'à quelques minutes.",
    "verificationInProgressTitle": "Vérification en cours",
    "verificationSuccessful": "Vérification effectuée avec succès !",
    "startVerification": "Commencer la vérification",
    "checkingAutomatically": "Vérification automatique...",

    # --- Document capture (11 keys) ---
    "documentBothSidesAndSelfieDescription": "Nous capturerons les deux côtés de votre pièce d'identité et prendrons un selfie",
    "idAndSelfieVerificationDescription": "Nous vérifierons votre numéro d'identification et prendrons un selfie pour confirmation",
    "takePhoto": "Prendre une photo",
    "takePhotoOption": "Prendre une photo",
    "chooseFromGalleryOption": "Choisir depuis la galerie",
    "uploadPhoto": "Téléverser une photo",
    "uploadFront": "Téléverser le recto",
    "uploadBack": "Téléverser le verso",
    "uploadMainPage": "Téléverser la page principale",
    "faceScan": "Scan du visage",
    "faceScanInstructions": "Placez votre visage dans le cadre",

    # --- Biometric (13 keys) ---
    "biometricErrorAuthenticationFailed": "Échec de l'authentification",
    "biometricErrorFallback": "Authentification impossible. Veuillez réessayer.",
    "biometricErrorLockedOut": "Trop de tentatives échouées. Veuillez réessayer plus tard",
    "biometricErrorNoBiometricsEnrolled": "Aucune biométrie enregistrée sur cet appareil",
    "biometricErrorNotAvailable": "L'authentification biométrique n'est pas disponible",
    "biometricErrorNotEnrolled": "Aucune biométrie enregistrée. Veuillez configurer l'empreinte digitale ou la reconnaissance faciale dans les paramètres de l'appareil",
    "biometricErrorNotSupported": "Authentification biométrique non prise en charge",
    "biometricErrorOtherOperatingSystem": "L'authentification biométrique n'est pas prise en charge sur cet appareil",
    "biometricErrorPasscodeNotSet": "Veuillez configurer un code d'accès sur l'appareil pour utiliser l'authentification biométrique",
    "biometricErrorPermanentlyLockedOut": "L'authentification biométrique est verrouillée. Veuillez d'abord déverrouiller votre appareil",
    "noBiometricsEnrolledToast": "Aucune biométrie enregistrée sur cet appareil. Veuillez configurer l'empreinte digitale ou Face ID dans les paramètres de l'appareil.",
    "biometricReasonChangeSecurity": "Authentifiez-vous pour modifier les paramètres de sécurité",
    "biometricReasonConfirmPayment": "Confirmer le paiement de {currencySymbol}{amount} à {recipient}",

    # --- Smile ID errors (12 keys) ---
    "smileIdParseError": "Impossible de lire le résultat de la vérification. Veuillez réessayer.",
    "smileIdResultCouldNotComplete": "La vérification n'a pas pu être effectuée. Veuillez réessayer.",
    "smileIdResultExpiredDoc": "Le document est expiré. Veuillez utiliser une pièce d'identité valide et non expirée.",
    "smileIdResultFaceMatchFailed": "Échec de la vérification faciale. Le selfie ne correspond pas à la photo de la pièce d'identité.",
    "smileIdResultFaceNotDetected": "Visage non détecté. Veuillez vous assurer que votre visage est clairement visible et bien éclairé.",
    "smileIdResultIdDocFailed": "Le document d'identité n'a pas pu être vérifié. Veuillez essayer avec un autre document.",
    "smileIdResultInfoMismatch": "Les informations de la pièce d'identité ne correspondent pas. Veuillez vous assurer d'avoir saisi les bonnes informations.",
    "smileIdResultLivenessFailed": "Échec du test de vivacité. Veuillez suivre attentivement les instructions à l'écran.",
    "smileIdResultMultipleFacesDetected": "Plusieurs visages détectés. Veuillez vous assurer que seul votre visage est dans le cadre.",
    "smileIdResultPoorImageQuality": "Mauvaise qualité d'image. Veuillez vous assurer d'un bon éclairage et d'une photo nette.",
    "smileIdResultUnsupportedDoc": "Document non pris en charge. Veuillez essayer avec un autre type de pièce d'identité.",
    "smileIdResultVerified": "Vérification réussie !",

    # --- KYC error keys (12 keys) ---
    "kycErrorDocumentUploadGeneric": "Échec du téléversement du document. Veuillez réessayer.",
    "kycErrorDocumentUploadNetwork": "Échec du téléversement du document. Veuillez vérifier votre connexion et réessayer.",
    "kycErrorImageTooLarge": "Le fichier image est trop volumineux. Veuillez utiliser une image plus petite.",
    "kycErrorNotSignedIn": "Vous n'êtes pas connecté. Veuillez vous connecter et réessayer.",
    "kycErrorPhoneVerificationEnter6DigitCode": "Veuillez saisir le code à 6 chiffres",
    "kycErrorPhoneVerificationNoPhoneNumber": "Aucun numéro de téléphone trouvé sur votre compte. Veuillez revenir en arrière et le saisir à nouveau.",
    "kycErrorPleaseCompleteSmileId": "Veuillez compléter la vérification avec Smile ID",
    "kycErrorPleaseEnterCardNumber": "Veuillez saisir votre numéro de carte",
    "kycErrorPleaseSelectDateOfBirth": "Veuillez sélectionner votre date de naissance",
    "kycErrorPleaseSelectDateOfBirthBeforeSelfie": "Veuillez sélectionner votre date de naissance avant de prendre le selfie",
    "kycErrorSomethingWentWrong": "Une erreur s'est produite. Veuillez réessayer.",
    "kycErrorVerificationSessionExpired": "La session de vérification a expiré. Veuillez reprendre votre selfie.",

    # --- Generic error keys (11 keys, KYC-context despite the prefix) ---
    "genericErrorAuth": "Votre session a expiré. Veuillez vous reconnecter pour continuer.",
    "genericErrorCameraPermission": "L'accès à la caméra est requis pour la vérification. Veuillez activer les autorisations de la caméra dans les paramètres de votre appareil.",
    "genericErrorDocument": "Nous n'avons pas pu lire votre document clairement. Veuillez vous assurer que le document est bien éclairé, à plat et que tout le texte est visible.",
    "genericErrorFaceDetection": "Nous n'avons pas pu détecter votre visage clairement. Veuillez vous assurer d'un bon éclairage et placer votre visage dans le cadre.",
    "genericErrorFaceMismatch": "Échec de la vérification faciale. Le selfie ne correspond pas à la photo de la pièce d'identité. Veuillez vous assurer d'utiliser votre propre document d'identité.",
    "genericErrorFallback": "Une erreur s'est produite. Veuillez réessayer ou contacter le support si le problème persiste.",
    "genericErrorIdVerification": "Échec de la vérification d'identité. Veuillez vous assurer que votre pièce d'identité est valide, non expirée, et que les informations saisies sont correctes.",
    "genericErrorNetwork": "Connexion impossible. Veuillez vérifier votre connexion Internet et réessayer.",
    "genericErrorServer": "Notre service de vérification est temporairement indisponible. Veuillez réessayer dans quelques minutes.",
    "genericErrorTimeout": "La requête a pris trop de temps. Veuillez vérifier votre connexion et réessayer.",
    "genericErrorUserCancelled": "La vérification a été annulée. Vous pouvez réessayer quand vous serez prêt.",

    # --- ID type selector (11 keys) ---
    "selectIdType": "Sélectionnez le type de pièce d'identité",
    "selectVerificationMethod": "Sélectionnez la méthode de vérification",
    "selectVerificationMethodSubtitle": "Choisissez votre type de pièce d'identité préféré pour vérifier votre identité",
    "governmentId": "Pièce d'identité officielle",
    "idNumberLabel": "Numéro d'identification",
    "idNumberRequired": "Le numéro d'identification est requis pour la vérification",
    "enterIdNumber": "Saisir le numéro d'identification",
    "enterIdNumberHint": "Saisissez votre numéro d'identification à 13 chiffres",
    "invalidIdNumberFallback": "Numéro d'identification invalide",
    "dateOfBirth": "Date de naissance",
    "selectDate": "Sélectionner la date",

    # --- Country picker (3 keys) ---
    "selectCountryTitle": "Sélectionner le pays",
    "searchCountryHint": "Rechercher un pays...",
    "countryDisplayFormat": "{dialCode} • {symbol} {code}",
}

assert len(TRANSLATIONS) == 92, f"Spec dict has {len(TRANSLATIONS)} entries, expected 92"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_2.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 2 - KYC Core Flow
Applies 92 French translations to lib/l10n/app_fr.arb.
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
    assert len(TRANSLATIONS) == 92, f"Expected 92 translations, got {len(TRANSLATIONS)}"

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

    # Verify: ICU placeholder preservation for all 5 ICU keys in this batch
    assert "{documentType}" in fr["verifyYourDocumentTitle"], "verifyYourDocumentTitle lost {documentType}"
    assert "{documentType}" in fr["documentCapturedBody"], "documentCapturedBody lost {documentType}"
    assert "{error}" in fr["verificationFailedWithError"], "verificationFailedWithError lost {error}"
    assert "{currencySymbol}" in fr["biometricReasonConfirmPayment"], "biometricReasonConfirmPayment lost {currencySymbol}"
    assert "{amount}" in fr["biometricReasonConfirmPayment"], "biometricReasonConfirmPayment lost {amount}"
    assert "{recipient}" in fr["biometricReasonConfirmPayment"], "biometricReasonConfirmPayment lost {recipient}"
    assert "{dialCode}" in fr["countryDisplayFormat"], "countryDisplayFormat lost {dialCode}"
    assert "{symbol}" in fr["countryDisplayFormat"], "countryDisplayFormat lost {symbol}"
    assert "{code}" in fr["countryDisplayFormat"], "countryDisplayFormat lost {code}"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 91, expected {91 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_2.py
```

Expected output (approximately):
```
OK — applied 92 translations
FR filled: 183/701 (was 91, expected 183)
FR empty: 518
```

If any assertion fires, STOP and report.

---

## 4. Verification

After the script runs:

### 4.1 Confirm only app_fr.arb changed

```bash
git status
```

Expected: only `modified: lib/l10n/app_fr.arb`. No other modifications. The PHASE_*.py untracked stragglers are normal and remain untracked.

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
- FR filled: 183

### 4.3 Confirm ar and en files untouched

```bash
git diff --stat lib/l10n/app_ar.arb
git diff --stat lib/l10n/app_en.arb
```

Expected: empty output for both.

### 4.4 Confirm spec keys hold spec values + ICU preservation

```bash
python3 << 'PYEOF'
import json

SPOT_CHECK = {
    "verify": "Vérifier",
    "verifyYourDocumentTitle": "Vérifiez votre {documentType}",
    "documentCapturedBody": "Votre {documentType} a été capturé. La vérification commencera lorsque vous continuerez.",
    "verificationFailedWithError": "Échec de la vérification : {error}",
    "biometricReasonConfirmPayment": "Confirmer le paiement de {currencySymbol}{amount} à {recipient}",
    "smileIdResultVerified": "Vérification réussie !",
    "kycErrorVerificationSessionExpired": "La session de vérification a expiré. Veuillez reprendre votre selfie.",
    "genericErrorFallback": "Une erreur s'est produite. Veuillez réessayer ou contacter le support si le problème persiste.",
    "countryDisplayFormat": "{dialCode} • {symbol} {code}",
    "biometricReasonChangeSecurity": "Authentifiez-vous pour modifier les paramètres de sécurité",
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
10.fr-batch-2: French translations for KYC core flow (92 keys)

Translates 92 keys covering the KYC core surface:
- KYC main verification screen (19 keys) — verify, document captured,
  verification in-progress / success / failed states
- Document capture (11 keys) — take photo, upload front/back, gallery,
  face scan
- Biometric (13 keys) — 10 device-state error keys, no-biometrics toast,
  and 2 prompt-reason keys (orphan biometricReasonChangeSecurity +
  ICU biometricReasonConfirmPayment)
- Smile ID errors (12 keys) — all 12 result codes from the
  smile_id_localization_resolver
- KYC error keys (12 keys) — kycError* family
- Generic error keys (11 keys) — genericError* family (KYC-context
  despite the generic prefix)
- ID type selector (11 keys) — verification method, government ID,
  ID number entry, date of birth picker
- Country picker (3 keys) — title, search hint, display format ICU

ICU placeholders preserved (verified by apply-script assertions):
  verifyYourDocumentTitle: {documentType}
  documentCapturedBody: {documentType}
  verificationFailedWithError: {error}
  biometricReasonConfirmPayment: {currencySymbol}, {amount}, {recipient}
  countryDisplayFormat: {dialCode}, {symbol}, {code}

Convention notes:
- "Téléverser" (formal Quebec/EU French) for "upload"
- "Pièce d'identité" for "ID document"
- "Selfie" retained as-is (now standard French)
- "Test de vivacité" for "liveness check"
- Brand names stay English: Smile ID, Face ID, QR Wallet
- Formal register throughout (vous, not tu)
- French typography preserved (space before ! ? : ;)

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_2_KYC_CORE.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-2
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-2-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-2`
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
   git checkout phase6-step10-fr-batch-2
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

4. **Per established workflow:** generated files are NOT committed. Do NOT `git add` anything under `lib/generated/l10n/`.

5. Run analyzer + build:
   ```bash
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```

   Expected: 204 analyzer issues (baseline), build green. If analyzer count goes up, STOP — likely an ICU placeholder mismatch.

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
   git merge --ff-only phase6-step10-fr-batch-2
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-2-complete
   git push origin main
   git push origin phase6-step10-fr-batch-2-complete
   git push origin :phase6-step10-fr-batch-2
   git branch -d phase6-step10-fr-batch-2
   ```

---

## 10. Translation conventions (extension to Batch 1)

These conventions apply to ALL French batches in Step 10, with additions for KYC vocabulary specific to Batch 2.

| Convention | Decision |
|---|---|
| (from Batch 1) Register | Formal (vous, not tu) |
| (from Batch 1) Email | "e-mail" with hyphen |
| (from Batch 1) OTP | Kept as "OTP" |
| (from Batch 1) PIN | "code PIN" |
| (from Batch 1) Brand names | Stay in English: QR Wallet, MTN MoMo, Apple, Paystack, WhatsApp, **Smile ID**, **Face ID** |
| (from Batch 1) Punctuation | French typography (space before ! ? : ;) |
| **NEW** Verify (verb) | "vérifier" |
| **NEW** Verification (noun) | "vérification" |
| **NEW** Verification failed | "Échec de la vérification" |
| **NEW** ID document | "pièce d'identité" |
| **NEW** ID number | "numéro d'identification" |
| **NEW** Document | "document" |
| **NEW** Selfie | "selfie" (kept as-is, now standard French) |
| **NEW** Upload (verb) | "téléverser" (formal register, used in Quebec/EU French) |
| **NEW** Front (of card) | "recto" |
| **NEW** Back (of card) | "verso" |
| **NEW** Take a photo | "prendre une photo" |
| **NEW** Choose from gallery | "choisir depuis la galerie" |
| **NEW** Liveness check | "test de vivacité" |
| **NEW** Face match / mismatch | "correspondance faciale" / "non-correspondance du visage" |
| **NEW** Biometric (adj.) | "biométrique" |
| **NEW** Biometrics (noun) | "biométrie" |
| **NEW** Authentication | "authentification" |
| **NEW** Passcode | "code d'accès" |
| **NEW** Date of birth | "date de naissance" |
| **NEW** Country | "pays" |
| **NEW** Government ID | "pièce d'identité officielle" |
| **NEW** Camera | "caméra" |
| **NEW** Session expired | "session expirée" / "la session a expiré" |
