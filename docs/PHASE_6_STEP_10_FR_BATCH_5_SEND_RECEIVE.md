# Phase 6 Step 10 — French Batch 5 — Send & Receive Money Flows

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 5 of 9
> **Scope:** Send & Receive Money flows — 87 keys
> **Predecessor:** `phase6-step10-fr-batch-4b-complete` @ `76f46c28`
> **Branch name to create:** `phase6-step10-fr-batch-5`
> **Tag to apply after merge:** `phase6-step10-fr-batch-5-complete`

---

## 1. Scope

This batch translates 87 keys covering the Send and Receive Money flows:

**Send flow (49 keys):**
- Send buttons & screens (5 keys, 1 ICU)
- Recipient wallet ID lookup (4 keys)
- PIN entry & secure payment (3 keys)
- Fee, amount, currency conversion (7 keys, 1 ICU)
- Recipient response, sent confirmation, seller-requested labels (4 keys, 1 ICU)
- Send UI errors (4 keys)
- Transaction error resolvers from `transaction_localization_resolver` (10 keys)
- Verifying / approving payment (3 keys)
- Payment success / failed states (5 keys)
- Scan QR (4 keys)

**Receive flow (38 keys):**
- Receive entry / payment request entry (6 keys)
- Create payment request (2 keys)
- Payment request items & notes (6 keys)
- QR generation, sharing, saving (10 keys, 3 ICU)
- Pay-to-user QR center text (2 ICU keys)
- Share wallet (2 keys)
- WhatsApp share (4 keys)
- Copy-to-clipboard helpers (3 keys, 2 ICU)
- Reference labels (3 keys, 1 ICU)

**Out of scope for this batch:**
- Wallet display, withdraw, add money, mobile money → already done in Batch 4b
- Bank account management → already done in Batch 4a
- Transactions list, details, disputes → Batch 6
- Profile, FAQ, settings, security → Batch 7
- Generic UI buttons, splash, app metadata → Batch 8

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
test -f docs/PHASE_6_STEP_10_FR_BATCH_5_SEND_RECEIVE.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-4b-complete|phase6-step10-fr-batch-5-complete"
```

Expected:
- `phase6-step10-fr-batch-4b-complete` MUST be present
- `phase6-step10-fr-batch-5-complete` MUST NOT be present

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
print(f"FR currently filled: {filled} keys (expected 343 = 1 itemCount + 90 + 92 + 52 + 35 + 73 from Batches 1-4b)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 343 keys (expected 343 = 1 itemCount + 90 + 92 + 52 + 35 + 73 from Batches 1-4b)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-5
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_5.py`, run, then verify and commit.

### 3.1 Translation data

The 87 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters, French guillemets « », literal `\n` newlines, em-dash `—`) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Send buttons & screens (5 keys, 1 ICU) ---
    "send": "Envoyer",
    "sendMoney": "Envoyer de l'argent",
    "confirmSend": "Confirmer et envoyer",
    "sendButtonAmount": "Envoyer {currency}{amount}",
    "sendingTo": "Envoi à",

    # --- Recipient wallet ID lookup (4 keys) ---
    "enterWalletId": "Saisir l'ID du portefeuille",
    "pleaseEnterValidWalletId": "Veuillez saisir un ID de portefeuille valide",
    "walletIdHint": "Saisissez l'ID du portefeuille du destinataire",
    "lookingUpWallet": "Recherche du portefeuille...",

    # --- PIN entry & secure payment (3 keys) ---
    "enterPinToConfirm": "Saisissez votre code PIN à 6 chiffres pour confirmer ce transfert",
    "successMoneySent": "Argent envoyé avec succès !",
    "securePaymentLabel": "Paiement sécurisé",

    # --- Fee, amount, currency conversion (7 keys, 1 ICU) ---
    "feeApproximateError": "Les frais sont approximatifs — {error}",
    "transactionFee": "Frais de transaction",
    "totalAmount": "Montant total",
    "pleaseVerifyDetailsCorrect": "Veuillez vérifier que les détails sont corrects",
    "originalAmount": "Montant original",
    "convertedAmount": "Montant converti",
    "currencyConversion": "Conversion de devise",

    # --- Recipient response / sent confirmation (4 keys, 1 ICU) ---
    "amountSentTo": "{currency}{amount} envoyé à {recipient}",
    "recipientReceivesLabel": "Le destinataire reçoit :",
    "recipientResponseLabel": "Réponse du destinataire",
    "sellerRequestedLabel": "Le vendeur a demandé :",

    # --- Send UI errors (4 keys) ---
    "sendUiErrorCouldNotReadQrCode": "Impossible de lire le QR code",
    "sendUiErrorCouldNotVerifyRecipientWallet": "Impossible de vérifier le portefeuille du destinataire",
    "sendUiErrorPreviewTimedOut": "Aperçu expiré",
    "sendUiErrorRequestTimedOut": "Délai de la requête expiré. Veuillez vérifier votre connexion et réessayer.",

    # --- Transaction error resolvers (10 keys) ---
    "transactionErrorDepositFailed": "Échec du dépôt",
    "transactionErrorFallback": "Impossible de finaliser la transaction. Veuillez réessayer.",
    "transactionErrorInsufficientBalance": "Solde insuffisant",
    "transactionErrorInvalidRequest": "Requête invalide",
    "transactionErrorPaymentAlreadyProcessed": "Paiement déjà traité",
    "transactionErrorPaymentVerificationFailed": "Échec de la vérification du paiement",
    "transactionErrorPleaseLogInToSendMoney": "Veuillez vous connecter pour envoyer de l'argent",
    "transactionErrorRecipientWalletNotFound": "Portefeuille du destinataire introuvable",
    "transactionErrorTransactionFailed": "Échec de la transaction",
    "transactionErrorUserNotAuthenticated": "Utilisateur non authentifié",

    # --- Verifying / approving payment (3 keys) ---
    "verifyingPaymentTitle": "Vérification du paiement...",
    "verifyingPaymentBody": "Veuillez patienter pendant que nous confirmons votre paiement",
    "approvePaymentTitle": "Approuver le paiement",

    # --- Payment success / failed states (5 keys) ---
    "paymentSuccessful": "Paiement réussi",
    "paymentSuccessfulHero": "Paiement réussi !",
    "paymentFailed": "Échec du paiement",
    "paymentFailedError": "Échec du paiement",
    "paymentFailedOrRejectedError": "Le paiement a échoué ou a été rejeté",

    # --- Scan QR (4 keys) ---
    "scanQrCode": "Scanner le QR code",
    "scanRecipientQrToSend": "Scannez le QR code du destinataire pour envoyer de l'argent",
    "positionQrCodeInFrame": "Placez le QR code dans le cadre",
    "startScan": "Démarrer le scan",

    # --- Receive entry / payment request entry (6 keys) ---
    "receive": "Recevoir",
    "receiveMoney": "Recevoir de l'argent",
    "paymentRequestLabel": "Demande de paiement",
    "requestPaymentTitle": "Demander un paiement",
    "createNewRequest": "Créer une nouvelle demande",
    "newRequestTooltip": "Nouvelle demande",

    # --- Create payment request (2 keys) ---
    "createPaymentRequestTitle": "Créer une demande de paiement",
    "createPaymentRequestDescription": "Saisissez le montant et ajoutez des articles. Les clients peuvent scanner le QR code pour vous payer instantanément.",

    # --- Payment request items & notes (6 keys) ---
    "itemsHint": "ex. : riz jollof, poulet, boissons",
    "itemsOptional": "Articles (facultatifs)",
    "maximum20ItemsAllowed": "Maximum 20 articles autorisés",
    "note": "Note (facultative)",
    "noteHint": "Ajoutez une note",
    "descriptionLabel": "Description",

    # --- QR generation, sharing, saving (10 keys, 3 ICU) ---
    "generateQrCode": "Générer le QR code",
    "myQrCode": "Mon QR code",
    "qrCodeInfoForCustomer": "Présentez ce QR code au client.\nIl le scanne, confirme le montant, et paie instantanément !",
    "qrCodeSavedToGallery": "QR code enregistré dans la galerie !",
    "downloadQrCode": "Télécharger le QR code",
    "shareQrCode": "Partager le QR code",
    "errorSavingQrCode": "Erreur lors de l'enregistrement du QR code : {error}",
    "errorGeneratingQr": "Erreur lors de la génération du QR : {error}",
    "errorSharingQr": "Erreur lors du partage du QR : {error}",
    "storagePermissionRequired": "Autorisation de stockage requise pour enregistrer le QR code",

    # --- Pay-to-user QR center text (2 ICU keys) ---
    "payToUser": "Payer à : {userName}",
    "payRequestShareText": "Payez {symbol}{amount} à {userName}",

    # --- Share wallet (2 keys) ---
    "shareWalletIdSubject": "Mon ID QR Wallet",
    "qrWalletAppName": "QR Wallet",

    # --- WhatsApp share (4 keys) ---
    "chatOnWhatsAppDialogTitle": "Discuter sur WhatsApp",
    "openWhatsAppButton": "Ouvrir WhatsApp",
    "couldNotOpenWhatsAppToast": "Impossible d'ouvrir WhatsApp. Veuillez vérifier que WhatsApp est installé.",
    "scanWithAnotherPhoneCaption": "Scannez avec un autre téléphone\nou appuyez sur « Ouvrir WhatsApp » ci-dessous",

    # --- Copy-to-clipboard helpers (3 keys, 2 ICU) ---
    "copiedToClipboard": "{label} copié",
    "labelCopiedToClipboard": "{label} copié dans le presse-papiers",
    "tapToCopy": "Appuyez pour copier",

    # --- Reference labels (3 keys, 1 ICU) ---
    "referenceColon": "Référence : ",
    "referenceLabel": "Référence",
    "referenceWithValue": "Référence : {reference}",
}

assert len(TRANSLATIONS) == 87, f"Spec dict has {len(TRANSLATIONS)} entries, expected 87"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_5.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 5 - Send & Receive Money Flows
Applies 87 French translations to lib/l10n/app_fr.arb.
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
    assert len(TRANSLATIONS) == 87, f"Expected 87 translations, got {len(TRANSLATIONS)}"

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

    # Verify: ICU placeholder preservation for all 11 ICU keys in this batch
    # Send button (1 key, 2 placeholders)
    assert "{currency}" in fr["sendButtonAmount"], "sendButtonAmount lost {currency}"
    assert "{amount}" in fr["sendButtonAmount"], "sendButtonAmount lost {amount}"
    # Fee error (1 key, 1 placeholder)
    assert "{error}" in fr["feeApproximateError"], "feeApproximateError lost {error}"
    # Recipient sent confirmation (1 key, 3 placeholders)
    assert "{currency}" in fr["amountSentTo"], "amountSentTo lost {currency}"
    assert "{amount}" in fr["amountSentTo"], "amountSentTo lost {amount}"
    assert "{recipient}" in fr["amountSentTo"], "amountSentTo lost {recipient}"
    # QR error keys (3 keys, 1 placeholder each)
    assert "{error}" in fr["errorSavingQrCode"], "errorSavingQrCode lost {error}"
    assert "{error}" in fr["errorGeneratingQr"], "errorGeneratingQr lost {error}"
    assert "{error}" in fr["errorSharingQr"], "errorSharingQr lost {error}"
    # Pay-to-user (2 keys, 1 + 3 placeholders)
    assert "{userName}" in fr["payToUser"], "payToUser lost {userName}"
    assert "{symbol}" in fr["payRequestShareText"], "payRequestShareText lost {symbol}"
    assert "{amount}" in fr["payRequestShareText"], "payRequestShareText lost {amount}"
    assert "{userName}" in fr["payRequestShareText"], "payRequestShareText lost {userName}"
    # Copy helpers (2 keys, 1 placeholder each)
    assert "{label}" in fr["copiedToClipboard"], "copiedToClipboard lost {label}"
    assert "{label}" in fr["labelCopiedToClipboard"], "labelCopiedToClipboard lost {label}"
    # Reference (1 key, 1 placeholder)
    assert "{reference}" in fr["referenceWithValue"], "referenceWithValue lost {reference}"

    # Verify: literal newline preserved in qrCodeInfoForCustomer + scanWithAnotherPhoneCaption
    assert "\n" in fr["qrCodeInfoForCustomer"], "qrCodeInfoForCustomer lost newline"
    assert "\n" in fr["scanWithAnotherPhoneCaption"], "scanWithAnotherPhoneCaption lost newline"

    # Verify: French guillemets in scanWithAnotherPhoneCaption
    assert "« Ouvrir WhatsApp »" in fr["scanWithAnotherPhoneCaption"], \
        "scanWithAnotherPhoneCaption lost French guillemets"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 343, expected {343 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_5.py
```

Expected output (approximately):
```
OK — applied 87 translations
FR filled: 430/701 (was 343, expected 430)
FR empty: 271
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
- FR filled: 430

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
    "send": "Envoyer",
    "sendMoney": "Envoyer de l'argent",
    "sendButtonAmount": "Envoyer {currency}{amount}",
    "amountSentTo": "{currency}{amount} envoyé à {recipient}",
    "feeApproximateError": "Les frais sont approximatifs — {error}",
    "sellerRequestedLabel": "Le vendeur a demandé :",
    "transactionErrorRecipientWalletNotFound": "Portefeuille du destinataire introuvable",
    "scanQrCode": "Scanner le QR code",
    "receive": "Recevoir",
    "createPaymentRequestDescription": "Saisissez le montant et ajoutez des articles. Les clients peuvent scanner le QR code pour vous payer instantanément.",
    "itemsHint": "ex. : riz jollof, poulet, boissons",
    "itemsOptional": "Articles (facultatifs)",
    "qrCodeInfoForCustomer": "Présentez ce QR code au client.\nIl le scanne, confirme le montant, et paie instantanément !",
    "errorSavingQrCode": "Erreur lors de l'enregistrement du QR code : {error}",
    "payToUser": "Payer à : {userName}",
    "payRequestShareText": "Payez {symbol}{amount} à {userName}",
    "scanWithAnotherPhoneCaption": "Scannez avec un autre téléphone\nou appuyez sur « Ouvrir WhatsApp » ci-dessous",
    "copiedToClipboard": "{label} copié",
    "labelCopiedToClipboard": "{label} copié dans le presse-papiers",
    "referenceWithValue": "Référence : {reference}",
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
10.fr-batch-5: French translations for Send & Receive money flows (87 keys)

Translates 87 keys covering send and receive money flows:

Send flow (49 keys):
- Send buttons & screens (5 keys, 1 ICU)
- Recipient wallet ID lookup (4 keys)
- PIN entry & secure payment (3 keys)
- Fee, amount, currency conversion (7 keys, 1 ICU)
- Recipient response, sent confirmation, seller-requested labels
  (4 keys, 1 ICU)
- Send UI errors (4 keys)
- Transaction error resolvers from transaction_localization_resolver
  (10 keys)
- Verifying / approving payment (3 keys)
- Payment success / failed states (5 keys)
- Scan QR (4 keys)

Receive flow (38 keys):
- Receive entry / payment request entry (6 keys)
- Create payment request (2 keys)
- Payment request items & notes (6 keys)
- QR generation, sharing, saving (10 keys, 3 ICU)
- Pay-to-user QR center text (2 ICU keys)
- Share wallet (2 keys)
- WhatsApp share (4 keys)
- Copy-to-clipboard helpers (3 keys, 2 ICU)
- Reference labels (3 keys, 1 ICU)

ICU placeholders preserved (verified by apply-script assertions, 11 ICU
keys total): sendButtonAmount, feeApproximateError, amountSentTo,
errorSavingQrCode, errorGeneratingQr, errorSharingQr, payToUser,
payRequestShareText, copiedToClipboard, labelCopiedToClipboard,
referenceWithValue.

Special character preservation verified by assertions:
- Literal newlines in qrCodeInfoForCustomer + scanWithAnotherPhoneCaption
- French guillemets « » in scanWithAnotherPhoneCaption

Convention notes:
- "Destinataire" for recipient (banking standard)
- "Vendeur" for seller, "Client" for customer
- "Demande de paiement" for "Payment Request"
- "Articles" for "items" with gender agreement (facultatifs / facultative)
- "Frais de transaction" for "Transaction Fee"
- "Échec du paiement" for "Payment Failed" (matches earlier batches'
  pattern of "Échec de [X]")
- "QR code" kept as English-style for parallel with QR Wallet brand
- "Scanner" / "scan" for scan verb/noun
- "Presse-papiers" for clipboard
- "copié" masculine default for {label} agreement (UX simplification —
  label values are mixed gender in source)
- French guillemets « » with surrounding spaces for inline quoted button
  names (proper French typography)
- French typography colon spacing: "Référence :" (space before colon)
- Brand names stay English: QR Wallet, WhatsApp

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_5_SEND_RECEIVE.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-5
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-5-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-5`
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
   git checkout phase6-step10-fr-batch-5
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

   Expected: 204 analyzer issues (baseline), build green. If analyzer count goes up, STOP — likely an ICU placeholder mismatch (this batch has 11 ICU keys plus newlines and guillemets — placeholder & special-character integrity is critical).

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
   git merge --ff-only phase6-step10-fr-batch-5
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-5-complete
   git push origin main
   git push origin phase6-step10-fr-batch-5-complete
   git push origin :phase6-step10-fr-batch-5
   git branch -d phase6-step10-fr-batch-5
   ```

---

## 10. Translation conventions (extension to Batches 1-4b)

These conventions apply to ALL French batches in Step 10, with send/receive-specific additions for Batch 5.

| Convention | Decision |
|---|---|
| (Batches 1-4b) Register | Formal (vous, not tu) |
| (Batches 1-4b) Brand names | Stay in English |
| (Batches 1-4b) Punctuation | French typography (space before ! ? : ;) |
| (Batches 1-4b) OTP | Kept as "OTP" |
| (Batch 4b) Wallet | "portefeuille" |
| (Batch 4b) Balance | "solde" |
| (Batch 4b) Currency | "devise" |
| **NEW (Batch 5)** Send (verb) | "envoyer" |
| **NEW (Batch 5)** Receive (verb) | "recevoir" |
| **NEW (Batch 5)** Recipient | "destinataire" (banking standard) |
| **NEW (Batch 5)** Seller | "vendeur" |
| **NEW (Batch 5)** Customer | "client" |
| **NEW (Batch 5)** Note | "note" |
| **NEW (Batch 5)** Payment request | "demande de paiement" |
| **NEW (Batch 5)** Items | "articles" |
| **NEW (Batch 5)** "(optional)" | "(facultatif)" / "(facultative)" / "(facultatifs)" with gender agreement |
| **NEW (Batch 5)** Reference | "référence" |
| **NEW (Batch 5)** Transaction Fee | "frais de transaction" |
| **NEW (Batch 5)** Total amount | "montant total" |
| **NEW (Batch 5)** Original amount | "montant original" |
| **NEW (Batch 5)** Converted amount | "montant converti" |
| **NEW (Batch 5)** Currency conversion | "conversion de devise" |
| **NEW (Batch 5)** Successful (payment) | "réussi" |
| **NEW (Batch 5)** Failed (payment/transaction) | "Échec de [X]" / "a échoué" |
| **NEW (Batch 5)** Approve / approved | "approuver" / "approuvé" |
| **NEW (Batch 5)** QR code | "QR code" (kept English-style for parallel with QR Wallet) |
| **NEW (Batch 5)** Tap (action) | "appuyer" / "appuyez" (formal command) |
| **NEW (Batch 5)** Scan (verb) | "scanner" |
| **NEW (Batch 5)** Scan (noun) | "scan" |
| **NEW (Batch 5)** Frame (camera) | "cadre" |
| **NEW (Batch 5)** Description | "description" |
| **NEW (Batch 5)** Clipboard | "presse-papiers" |
| **NEW (Batch 5)** Copied | "copié" (masculine default for mixed-gender label values) |
| **NEW (Batch 5)** Allowed (max items) | "autorisé" / "autorisés" with agreement |
| **NEW (Batch 5)** Storage permission | "autorisation de stockage" |
| **NEW (Batch 5)** Gallery (photo) | "galerie" |
| **NEW (Batch 5)** Inline quoted button name | French guillemets « » with surrounding spaces |
| **NEW (Batch 5)** "Could not [X]" | "Impossible de [X]" |
| **NEW (Batch 5)** "User not authenticated" | "Utilisateur non authentifié" |
| **NEW (Batch 5)** "{X} not found" | "{X} introuvable" |
