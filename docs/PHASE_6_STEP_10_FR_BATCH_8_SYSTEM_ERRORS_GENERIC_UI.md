# Phase 6 Step 10 — French Batch 8 — System Errors, Generic UI, Cleanup (FINAL)

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 8 of 9 — **FINAL FRENCH BATCH**
> **Scope:** Auth/Firebase/user error resolvers, generic UI buttons, generic errors, app metadata, misc UI, `enterTpinHint` cleanup — 80 keys
> **Predecessor:** `phase6-step10-fr-batch-7-complete` @ `6b203e70`
> **Branch name to create:** `phase6-step10-fr-batch-8`
> **Tag to apply after merge:** `phase6-step10-fr-batch-8-complete`
> **After this batch:** French 100% complete. Operator additionally tags `phase6-step10-fr-translations-complete` aggregate marker. Then move to Arabic batches.

---

## 1. Scope

This batch translates the final 80 empty keys in `app_fr.arb`, completing French translations for Step 10:

- App metadata (2 keys) — `appName`, `appTagline`
- Auth error resolver (23 keys) — all `authError*` keys (Apple/Google sign-in, Firebase auth wrappers, OTP verification, user data lookup)
- Generic UI buttons (18 keys) — back, cancel, close, confirm, continue, done, download, share, next, ok, retry, save, try again, plus button-suffixed duplicates and `checkNowButton`
- Generic errors (12 keys, 1 ICU) — field required, network, invalid email/OTP/phone, password mismatch/weak, wrong password, user not found, errorWithMessage ICU, errorGeneric, somethingWentWrongTryAgain
- `failedToRemoveError` (1 key, 1 ICU) — generic remove failure
- Firebase auth error resolver (12 keys) — `firebaseAuthError*` (separate from auth resolver)
- Misc generic UI (7 keys, 1 ICU) — home, loading placeholder, page-not-found ICU, phone verification app bar title, please wait, quick select, youAreOffline
- `enterTpinHint` cleanup (1 key) — was missed from Batch 3 (KYC ID-specific); the only KYC-related orphan
- User error resolver (4 keys) — `userError*` (fallback, ID image required, no updates provided, not authenticated)

**No keys are out of scope** — this batch contains every remaining empty key in `app_fr.arb`. After this lands, all 701 French keys are filled.

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
test -f docs/PHASE_6_STEP_10_FR_BATCH_8_SYSTEM_ERRORS_GENERIC_UI.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-7-complete|phase6-step10-fr-batch-8-complete"
```

Expected:
- `phase6-step10-fr-batch-7-complete` MUST be present
- `phase6-step10-fr-batch-8-complete` MUST NOT be present

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
empty = sum(1 for k in fr_keys if fr[k] == '')
print(f"FR currently filled: {filled} keys (expected 621 = 1 itemCount + 90 + 92 + 52 + 35 + 73 + 87 + 39 + 152 from Batches 1-7)")
print(f"FR currently empty:  {empty} keys (expected 80)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 621 keys (expected 621 = ...)`
- `FR currently empty:  80 keys (expected 80)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-8
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_8.py`, run, then verify and commit.

### 3.1 Translation data

The 80 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters, French typography colon spacing) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- App metadata (2 keys) ---
    "appName": "QR Wallet",
    "appTagline": "Paiements fluides, partout",

    # --- Auth error resolver (23 keys) ---
    "authErrorAppleSignInCancelled": "Connexion Apple annulée",
    "authErrorAppleSignInFailed": "Échec de la connexion Apple",
    "authErrorFailedToCreateUser": "Échec de la création de l'utilisateur",
    "authErrorFailedToSignIn": "Échec de la connexion",
    "authErrorFailedToSignInWithApple": "Échec de la connexion avec Apple",
    "authErrorFailedToSignInWithGoogle": "Échec de la connexion avec Google",
    "authErrorFailedToVerifyOtp": "Échec de la vérification de l'OTP",
    "authErrorFallback": "Une erreur est survenue. Veuillez réessayer",
    "authErrorFirebaseAccountNotFound": "Aucun compte trouvé avec cette adresse e-mail",
    "authErrorFirebaseCredentialAlreadyInUse": "Ce numéro de téléphone est déjà lié à un autre compte",
    "authErrorFirebaseEmailAlreadyInUse": "Un compte existe déjà avec cette adresse e-mail",
    "authErrorFirebaseInvalidEmail": "Veuillez saisir une adresse e-mail valide",
    "authErrorFirebaseInvalidVerificationCode": "Code OTP invalide. Veuillez réessayer",
    "authErrorFirebaseInvalidVerificationId": "Session de vérification expirée. Veuillez demander un nouveau code",
    "authErrorFirebaseNetworkRequestFailed": "Erreur réseau. Veuillez vérifier votre connexion",
    "authErrorFirebaseTooManyRequests": "Trop de tentatives. Veuillez réessayer plus tard",
    "authErrorFirebaseWeakPassword": "Le mot de passe doit comporter au moins 6 caractères",
    "authErrorFirebaseWrongPassword": "Mot de passe incorrect",
    "authErrorGoogleSignInCancelled": "Connexion Google annulée",
    "authErrorNoUserLoggedIn": "Aucun utilisateur connecté",
    "authErrorNoVerificationId": "Aucun ID de vérification. Veuillez redemander l'OTP.",
    "authErrorUserDataNotFound": "Données utilisateur introuvables",
    "authErrorUserNotFound": "Utilisateur introuvable",

    # --- Generic UI buttons (18 keys) ---
    "back": "Retour",
    "cancel": "Annuler",
    "checkNowButton": "Vérifier maintenant",
    "close": "Fermer",
    "closeButton": "Fermer",
    "confirm": "Confirmer",
    "confirmButton": "Confirmer",
    "continueText": "Continuer",
    "done": "Terminé",
    "doneButton": "Terminé",
    "downloadButton": "Télécharger",
    "goBackButton": "Retour",
    "next": "Suivant",
    "ok": "OK",
    "retry": "Réessayer",
    "save": "Enregistrer",
    "shareButton": "Partager",
    "tryAgainButton": "Réessayer",

    # --- Generic errors (12 keys, 1 ICU) ---
    "errorFieldRequired": "Ce champ est obligatoire",
    "errorGeneric": "Une erreur s'est produite. Veuillez réessayer.",
    "errorInvalidEmail": "Veuillez saisir une adresse e-mail valide",
    "errorInvalidOtp": "OTP invalide. Veuillez réessayer.",
    "errorInvalidPhone": "Veuillez saisir un numéro de téléphone valide",
    "errorNetwork": "Aucune connexion Internet. Veuillez vérifier votre réseau.",
    "errorPasswordMismatch": "Les mots de passe ne correspondent pas",
    "errorPasswordWeak": "Le mot de passe doit comporter au moins 8 caractères",
    "errorUserNotFound": "Utilisateur introuvable",
    "errorWithMessage": "Erreur : {message}",
    "errorWrongPassword": "Mot de passe incorrect",
    "somethingWentWrongTryAgain": "Une erreur s'est produite. Veuillez réessayer.",

    # --- Failed to remove (1 key, 1 ICU) ---
    "failedToRemoveError": "Échec de la suppression : {error}",

    # --- Firebase auth error resolver (12 keys) ---
    "firebaseAuthErrorEmailAlreadyInUse": "Cette adresse e-mail est déjà enregistrée. Veuillez vous connecter à la place.",
    "firebaseAuthErrorFallback": "Une erreur s'est produite. Veuillez réessayer.",
    "firebaseAuthErrorInvalidEmail": "Veuillez saisir une adresse e-mail valide.",
    "firebaseAuthErrorInvalidPhone": "Veuillez saisir un numéro de téléphone valide.",
    "firebaseAuthErrorInvalidVerificationCode": "Code de vérification invalide. Veuillez vérifier et réessayer.",
    "firebaseAuthErrorNetwork": "Impossible de se connecter. Veuillez vérifier votre connexion Internet.",
    "firebaseAuthErrorOperationNotAllowed": "Vous n'avez pas la permission d'effectuer cette action.",
    "firebaseAuthErrorServiceUnavailable": "Service temporairement indisponible. Veuillez réessayer plus tard.",
    "firebaseAuthErrorTooManyRequests": "Trop de tentatives. Veuillez patienter quelques minutes et réessayer.",
    "firebaseAuthErrorUserNotFound": "Compte introuvable. Veuillez vérifier vos identifiants ou créer un compte.",
    "firebaseAuthErrorWeakPassword": "Mot de passe trop faible. Veuillez utiliser au moins 6 caractères.",
    "firebaseAuthErrorWrongPassword": "Mot de passe incorrect. Veuillez réessayer.",

    # --- Misc generic UI (7 keys, 1 ICU) ---
    "home": "Accueil",
    "loadingPlaceholder": "Chargement...",
    "pageNotFound": "Page introuvable : {uri}",
    "phoneVerificationAppBarTitle": "Vérification du téléphone",
    "pleaseWait": "Veuillez patienter...",
    "quickSelectLabel": "Sélection rapide",
    "youAreOffline": "Vous êtes hors ligne",

    # --- KYC TPIN cleanup (1 key) ---
    "enterTpinHint": "Saisissez votre TPIN à 10 chiffres",

    # --- User error resolver (4 keys) ---
    "userErrorFallback": "Impossible de finaliser l'action. Veuillez réessayer.",
    "userErrorIdFrontImageRequired": "L'image recto de la pièce d'identité est obligatoire",
    "userErrorNoUpdatesProvided": "Aucune mise à jour fournie",
    "userErrorUserNotAuthenticated": "Utilisateur non authentifié",
}

assert len(TRANSLATIONS) == 80, f"Spec dict has {len(TRANSLATIONS)} entries, expected 80"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_8.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 8 - System Errors, Generic UI, Cleanup (FINAL)
Applies 80 French translations to lib/l10n/app_fr.arb.
After this batch, all 701 keys in app_fr.arb are filled.
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
    assert len(TRANSLATIONS) == 80, f"Expected 80 translations, got {len(TRANSLATIONS)}"

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

    # Verify baseline: this batch should cover ALL remaining empty keys
    fr_keys = {k for k in fr if not k.startswith('@')}
    currently_empty = {k for k in fr_keys if fr[k] == ""}
    spec_keys = set(TRANSLATIONS.keys())
    assert currently_empty == spec_keys, \
        f"Spec keys do not match currently-empty set.\n" \
        f"In spec but not empty: {spec_keys - currently_empty}\n" \
        f"Empty but not in spec: {currently_empty - spec_keys}"

    # Apply translations
    for key, value in TRANSLATIONS.items():
        fr[key] = value

    # Verify: each spec key now has its spec value
    for key, expected in TRANSLATIONS.items():
        assert fr[key] == expected, f"Mismatch on {key}: got {fr[key]!r}, expected {expected!r}"

    # Verify: total key count unchanged
    en_keys = {k for k in en if not k.startswith('@')}
    assert len(fr_keys) == 701, f"FR has {len(fr_keys)} keys after apply, expected 701"
    assert fr_keys == en_keys, "FR/EN key sets diverged"

    # Verify: ICU placeholder preservation for all 3 ICU keys in this batch
    assert "{message}" in fr["errorWithMessage"], "errorWithMessage lost {message}"
    assert "{error}" in fr["failedToRemoveError"], "failedToRemoveError lost {error}"
    assert "{uri}" in fr["pageNotFound"], "pageNotFound lost {uri}"

    # Verify: ZERO empty keys remain after this batch (French is 100% complete)
    final_empty = sum(1 for k in fr_keys if fr[k] == "")
    assert final_empty == 0, f"After batch 8, FR still has {final_empty} empty keys (expected 0)"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 621, expected 701)")
    print(f"FR empty: {final_empty}")
    print(f"")
    print(f"🎉 FRENCH TRANSLATIONS COMPLETE — all 701 keys translated.")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_8.py
```

Expected output:
```
OK — applied 80 translations
FR filled: 701/701 (was 621, expected 701)
FR empty: 0

🎉 FRENCH TRANSLATIONS COMPLETE — all 701 keys translated.
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

### 4.2 Confirm key parity en/fr + 100% completion

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
print(f"FR empty:  {sum(1 for k in fr_keys if fr[k] == '')}")
PYEOF
```

Expected:
- EN keys: 701
- FR keys: 701
- Match: True
- FR filled: 701
- FR empty:  0

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
    "appName": "QR Wallet",
    "appTagline": "Paiements fluides, partout",
    "authErrorFallback": "Une erreur est survenue. Veuillez réessayer",
    "authErrorFirebaseEmailAlreadyInUse": "Un compte existe déjà avec cette adresse e-mail",
    "authErrorUserNotFound": "Utilisateur introuvable",
    "back": "Retour",
    "cancel": "Annuler",
    "ok": "OK",
    "save": "Enregistrer",
    "tryAgainButton": "Réessayer",
    "errorFieldRequired": "Ce champ est obligatoire",
    "errorWithMessage": "Erreur : {message}",
    "failedToRemoveError": "Échec de la suppression : {error}",
    "firebaseAuthErrorOperationNotAllowed": "Vous n'avez pas la permission d'effectuer cette action.",
    "firebaseAuthErrorUserNotFound": "Compte introuvable. Veuillez vérifier vos identifiants ou créer un compte.",
    "home": "Accueil",
    "loadingPlaceholder": "Chargement...",
    "pageNotFound": "Page introuvable : {uri}",
    "youAreOffline": "Vous êtes hors ligne",
    "enterTpinHint": "Saisissez votre TPIN à 10 chiffres",
    "userErrorIdFrontImageRequired": "L'image recto de la pièce d'identité est obligatoire",
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
10.fr-batch-8: French translations for system errors, generic UI, cleanup (80 keys) — FRENCH COMPLETE

Final French batch. Translates the last 80 empty keys in app_fr.arb,
completing French translations for Step 10. After this commit, all 701
French keys are filled.

Coverage:
- App metadata (2 keys) — appName (kept English brand), appTagline
- Auth error resolver (23 keys) — all authError* keys
- Generic UI buttons (18 keys) — back, cancel, close, confirm,
  continue, done, download, share, next, ok, retry, save, try again,
  plus -Button suffixed duplicates and checkNowButton
- Generic errors (12 keys, 1 ICU) — field required, network, invalid
  email/OTP/phone, password mismatch/weak, wrong password, user not
  found, errorWithMessage ICU, errorGeneric, somethingWentWrongTryAgain
- failedToRemoveError (1 key, 1 ICU) — generic remove failure
- Firebase auth error resolver (12 keys) — firebaseAuthError*
- Misc generic UI (7 keys, 1 ICU) — home, loading, page-not-found ICU,
  phone verification app bar title, please wait, quick select,
  youAreOffline
- enterTpinHint (1 key) — KYC cleanup, was missed from Batch 3
- User error resolver (4 keys) — userError*

ICU placeholders preserved (verified by apply-script assertions, 3 ICU
keys total): errorWithMessage ({message}), failedToRemoveError ({error}),
pageNotFound ({uri}).

Apply-script also asserts that this batch covers ALL remaining empty
keys (the spec key set must equal the currently-empty set in app_fr.arb)
and that ZERO empty keys remain after the batch is applied.

Convention notes:
- "QR Wallet" kept as English brand name in appName
- "Paiements fluides, partout" for "Seamless payments, anywhere"
- "Échec de [X]" pattern for failure messages (matches earlier batches)
- "Une erreur s'est produite. Veuillez réessayer." for generic
  "Something went wrong. Please try again." (used 3x for triple-key
  identical English source)
- "Mot de passe incorrect" for "Wrong password" / "Incorrect password"
  (used 3x)
- "Veuillez saisir une adresse e-mail valide" for "Please enter a valid
  email address" (used 3x — generic, auth resolver, firebase resolver)
- "introuvable" for "not found" (continues Batch 5/6 pattern)
- "Retour" for both "Back" and "Go Back" — French apps don't typically
  distinguish; "Retourner"/"Revenir" sound awkward as button labels
- "Réessayer" for both "Retry" and "Try Again" — same target French verb
- "Confirmer" for both "Confirm" and "confirmButton" — same word
- "Fermer" for "Close" / "closeButton", "Terminé" for "Done"/"doneButton"
- "Saisissez votre TPIN à 10 chiffres" for enterTpinHint (matches
  Batch 3 TPIN convention)
- "L'image recto de la pièce d'identité" for "ID front image" (matches
  Batch 2 KYC convention: recto = front, pièce d'identité = ID document)
- French typography colon spacing: "Erreur : {message}", "Page
  introuvable : {uri}" (space before colon)

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_8_SYSTEM_ERRORS_GENERIC_UI.md

🇫🇷 French translations complete: 701/701 keys.
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-8
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-8-complete` — that is the operator's job after merge. **DO NOT** create the aggregate tag `phase6-step10-fr-translations-complete` — that is also the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-8`
2. **Final commit SHA** (from `git rev-parse HEAD`)
3. **Output of all verification steps** (Sections 4.1, 4.2, 4.3, 4.4)
4. **Output of the apply script** (Section 3.2 run command — should include the "🎉 FRENCH TRANSLATIONS COMPLETE" line)
5. **`git diff --stat HEAD~1 HEAD`** to confirm only `lib/l10n/app_fr.arb` was touched
6. **Confirm `lib/generated/l10n/` was NOT staged or committed**
7. **Confirm no `.py` file at repo root was staged or committed**
8. **Any deviations from this spec** with reasoning

---

## 8. STOP and report (do NOT improvise) if:

- Any pre-work check (Section 2) fails
- Any assertion in the apply script (Section 3.2) fires — including the new "spec covers all empty keys" assertion and the "zero empty keys after apply" assertion
- Any verification check (Section 4) fails
- Reality contradicts spec literal text in non-trivial ways
- The spec dict turns out to have wrong key count, missing keys, or duplicate keys

---

## 9. After agent reports back — operator's tasks

1. Pull the branch locally:
   ```bash
   git fetch origin
   git checkout phase6-step10-fr-batch-8
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

4. **Per established workflow:** generated files are NOT committed.

5. Run analyzer + build:
   ```bash
   flutter analyze 2>&1 | tail -5
   flutter build apk --debug --no-pub 2>&1 | tail -5
   ```

   Expected: 204 analyzer issues (baseline), build green.

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
   git merge --ff-only phase6-step10-fr-batch-8
   ```

9. Tag both batch-8-complete AND aggregate French-complete tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-8-complete
   git tag phase6-step10-fr-translations-complete
   git push origin main
   git push origin phase6-step10-fr-batch-8-complete
   git push origin phase6-step10-fr-translations-complete
   git push origin :phase6-step10-fr-batch-8
   git branch -d phase6-step10-fr-batch-8
   ```

10. Final celebration check:
    ```bash
    python3 << 'PYEOF'
    import json
    fr = json.load(open('lib/l10n/app_fr.arb'))
    fr_keys = {k for k in fr if not k.startswith('@')}
    filled = sum(1 for k in fr_keys if fr[k] != '')
    print(f"FR filled: {filled}/{len(fr_keys)}")
    assert filled == len(fr_keys), "French is NOT 100% complete"
    print("🇫🇷 French complete — all 701 keys translated.")
    PYEOF
    ```

---

## 10. Translation conventions (extension to Batches 1-7)

Final extension to the conventions table. After this batch, French Step 10 is complete.

| Convention | Decision |
|---|---|
| (Batches 1-7) Register | Formal (vous, not tu) |
| (Batches 1-7) Brand names | Stay in English |
| (Batches 1-7) Punctuation | French typography (space before ! ? : ;) |
| (Batches 1-7) "{X} not found" | "{X} introuvable" |
| (Batches 1-7) "Échec de [X]" | failure message pattern |
| **NEW (Batch 8)** "QR Wallet" brand name | "QR Wallet" (kept English) |
| **NEW (Batch 8)** App tagline | "Paiements fluides, partout" |
| **NEW (Batch 8)** "Back" / "Go Back" | "Retour" (both — no natural French distinction) |
| **NEW (Batch 8)** "Retry" / "Try Again" | "Réessayer" (both) |
| **NEW (Batch 8)** "Confirm" / "confirmButton" | "Confirmer" |
| **NEW (Batch 8)** "Close" / "closeButton" | "Fermer" |
| **NEW (Batch 8)** "Done" / "doneButton" | "Terminé" |
| **NEW (Batch 8)** "Cancel" | "Annuler" |
| **NEW (Batch 8)** "Save" (action button) | "Enregistrer" |
| **NEW (Batch 8)** "Next" | "Suivant" |
| **NEW (Batch 8)** "Continue" | "Continuer" |
| **NEW (Batch 8)** "OK" | "OK" (kept) |
| **NEW (Batch 8)** "Share" (button) | "Partager" |
| **NEW (Batch 8)** "Download" (button) | "Télécharger" |
| **NEW (Batch 8)** "Check Now" | "Vérifier maintenant" |
| **NEW (Batch 8)** "Home" (nav) | "Accueil" |
| **NEW (Batch 8)** "Loading..." | "Chargement..." |
| **NEW (Batch 8)** "Please wait..." | "Veuillez patienter..." |
| **NEW (Batch 8)** "Quick Select" | "Sélection rapide" |
| **NEW (Batch 8)** "You are offline" | "Vous êtes hors ligne" |
| **NEW (Batch 8)** "Page not found" | "Page introuvable" |
| **NEW (Batch 8)** "This field is required" | "Ce champ est obligatoire" |
| **NEW (Batch 8)** "Wrong password" / "Incorrect password" | "Mot de passe incorrect" |
| **NEW (Batch 8)** "Apple sign in" | "Connexion Apple" |
| **NEW (Batch 8)** "Google sign in" | "Connexion Google" |
| **NEW (Batch 8)** "Sign in" (auth resolver) | "Connexion" / "se connecter" |
| **NEW (Batch 8)** Generic "Something went wrong. Please try again." | "Une erreur s'est produite. Veuillez réessayer." |
| **NEW (Batch 8)** Generic "An error occurred. Please try again" | "Une erreur est survenue. Veuillez réessayer" |
| **NEW (Batch 8)** "Service temporarily unavailable" | "Service temporairement indisponible" |
| **NEW (Batch 8)** "Account not found" | "Compte introuvable" |
| **NEW (Batch 8)** "Phone Verification" (app bar) | "Vérification du téléphone" |
| **NEW (Batch 8)** "10-digit TPIN" | "TPIN à 10 chiffres" (matches "à N chiffres" pattern) |
