# Phase 6 Step 10 — French Batch 4b — Wallet, Money Flows, Mobile Money, Currency

> **Phase:** 6 (App-wide localization)
> **Step:** 10 (Engage translators — French + Arabic)
> **Sub-batch:** French Batch 4b of 9
> **Scope:** Wallet display, money flows, payment methods, currency formatters — 73 keys
> **Predecessor:** `phase6-step10-fr-batch-4a-complete` @ `8fa03cf0`
> **Branch name to create:** `phase6-step10-fr-batch-4b`
> **Tag to apply after merge:** `phase6-step10-fr-batch-4b-complete`

---

## 1. Scope

This batch translates 73 keys covering the wallet display, money flows, payment methods, and currency formatters:

- Wallet display & balance (10 keys)
- Add money flow (8 keys)
- Withdraw flow (10 keys, 3 ICU)
- Generic amount entry & insufficient balance (9 keys)
- Currency display formatters (5 ICU keys)
- Exchange rate (4 keys, 2 ICU)
- Mobile Money + MTN MoMo + Paystack (15 keys, 1 ICU)
- Virtual account (3 keys)
- Wallet error resolvers (4 keys)
- Wallet UI errors not in 4a (5 keys)

**Out of scope for this batch:**
- Bank account management → already done in Batch 4a
- Send/receive flows, recipient wallet ID, scan QR, payment requests → Batch 5
- Transactions list, details, disputes → Batch 6
- Profile / settings / currency selector / notifications → Batch 7
- Generic UI buttons (OK/Cancel/Save), splash, app metadata → Batch 8

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
test -f docs/PHASE_6_STEP_10_FR_BATCH_4B_WALLET_MONEY_FLOWS.md && echo "SPEC PRESENT" || echo "SPEC MISSING — STOP"
git --no-pager log --oneline -5
```

### 2.3 Confirm predecessor tag

```bash
git tag -l | grep -E "phase6-step10-fr-batch-4a-complete|phase6-step10-fr-batch-4b-complete"
```

Expected:
- `phase6-step10-fr-batch-4a-complete` MUST be present
- `phase6-step10-fr-batch-4b-complete` MUST NOT be present

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
print(f"FR currently filled: {filled} keys (expected 270 = 1 itemCount + 90 + 92 + 52 + 35 from Batches 1-4a)")
print(f"FR total: {len(fr_keys)}")
print(f"EN total: {len(en_keys)}")
print(f"Key sets match: {fr_keys == en_keys}")
PYEOF
```

Expected:
- `FR currently filled: 270 keys (expected 270 = 1 itemCount + 90 + 92 + 52 + 35 from Batches 1-4a)`
- `FR total: 701`
- `EN total: 701`
- `Key sets match: True`

If any assertion fails, STOP.

### 2.5 Create feature branch

```bash
git checkout -b phase6-step10-fr-batch-4b
```

---

## 3. Implementation

Single Python script. Save to `/tmp/apply_fr_batch_4b.py`, run, then verify and commit.

### 3.1 Translation data

The 73 French translations are below. **The agent MUST use these exact values verbatim — no creative re-translation, no encoding changes.** ICU placeholders MUST be preserved exactly. Special characters (apostrophes, accented letters) MUST be preserved as written.

```python
TRANSLATIONS = {
    # --- Wallet display & balance (10 keys) ---
    "availableBalance": "Solde disponible",
    "availableBalanceFull": "Solde disponible",
    "availableBalanceLabel": "Disponible",
    "hideBalance": "Masquer le solde",
    "showBalance": "Afficher le solde",
    "newBalanceLabel": "Nouveau solde",
    "onHoldBalanceLabel": "En attente",
    "totalBalance": "Solde total",
    "walletId": "ID du portefeuille",
    "walletIdCopied": "ID du portefeuille copié !",

    # --- Add money flow (8 keys) ---
    "addMoney": "Ajouter de l'argent",
    "addMoneyTitle": "Ajouter de l'argent",
    "bankTransferTabLabel": "Virement bancaire",
    "cardTabLabel": "Carte",
    "continueToPaymentButton": "Continuer vers le paiement",
    "hasBeenAddedToWallet": "a été ajouté à votre portefeuille",
    "successMoneyAdded": "Argent ajouté avec succès !",
    "transferFrom": "Transférer depuis",

    # --- Withdraw flow (10 keys, 3 ICU) ---
    "amountToWithdrawLabel": "Montant à retirer",
    "confirmWithdrawalTitle": "Confirmer le retrait",
    "enterOtpBody": "Veuillez saisir l'OTP envoyé à votre téléphone/e-mail enregistré pour finaliser le retrait de {symbol}{amount}",
    "iveApproved": "J'ai approuvé",
    "refLine": "Réf : {reference}",
    "withdraw": "Retirer",
    "withdrawAction": "Retirer",
    "withdrawalBeingProcessed": "{symbol}{amount} est en cours de traitement",
    "withdrawalFailedError": "Échec du retrait",
    "withdrawalInitiatedTitle": "Retrait initié",

    # --- Generic amount entry & insufficient balance (9 keys) ---
    "amount": "Montant",
    "amountHint": "Saisir le montant",
    "amountLabel": "Montant",
    "enterAmountLabel": "Saisir le montant",
    "errorInsufficientBalance": "Solde insuffisant",
    "errorInvalidAmount": "Veuillez saisir un montant valide",
    "insufficientBalance": "Solde insuffisant pour ce transfert",
    "pleaseEnterAmount": "Veuillez saisir un montant",
    "pleaseEnterValidAmount": "Veuillez saisir un montant valide",

    # --- Currency display formatters (5 ICU keys) ---
    "amountWithCurrency": "Montant : {symbol}{amount}",
    "currencyAmount": "{currency} {amount}",
    "currencyCodeWithSymbol": "{symbol} ({code})",
    "signedCurrencyAmount": "{prefix}{currency}{amount}",
    "symbolAmount": "{symbol}{amount}",

    # --- Exchange rate (4 keys, 2 ICU) ---
    "exchangeRateErrorUnsupportedCurrency": "Devise non prise en charge",
    "exchangeRateErrorUnsupportedCurrencyPair": "Devise non prise en charge : {from} ou {to}",
    "exchangeRateLabel": "Taux de change",
    "exchangeRateLine": "1 {fromCurrency} = {rate} {toCurrency}",

    # --- Mobile Money + MTN MoMo + Paystack (15 keys, 1 ICU) ---
    "mobileMoneyNotAvailablePaymentsBody": "Les paiements Mobile Money ne sont pas disponibles dans votre région. Veuillez utiliser la carte ou le virement bancaire.",
    "mobileMoneyNotAvailableTitle": "Mobile Money non disponible",
    "mobileMoneyNotAvailableWithdrawalsBody": "Les retraits Mobile Money ne sont pas disponibles dans votre région. Veuillez utiliser le virement bancaire.",
    "mobileMoneyProviderLabel": "Opérateur Mobile Money",
    "mobileMoneyTabLabel": "Mobile Money",
    "momoErrorInsufficientFunds": "Fonds insuffisants sur votre compte Mobile Money.",
    "momoErrorInvalidPhone": "Numéro de téléphone invalide. Veuillez vérifier et réessayer.",
    "momoErrorNotConfigured": "Mobile Money sera bientôt disponible ! Cette fonctionnalité n'est pas encore disponible. Veuillez utiliser la carte ou le virement bancaire à la place.",
    "momoErrorPaymentDeclined": "Le paiement a été refusé. Veuillez vérifier votre solde Mobile Money et réessayer.",
    "momoErrorPaymentTimeout": "La demande de paiement a expiré. Veuillez vérifier votre téléphone pour l'invite d'approbation et réessayer.",
    "mtnMomoApprovePromptBody": "Veuillez approuver le paiement de {symbol}{amount} sur votre téléphone MTN MoMo.",
    "mtnMomoPaymentFailedError": "Échec du paiement MTN MoMo",
    "checkPhoneForApprovalPrompt": "Vérifiez votre téléphone pour l'invite d'approbation.",
    "payWithMobileMoneyButton": "Payer avec Mobile Money",
    "paystackSecurityNote": "Propulsé par Paystack. Vos informations de paiement sont sécurisées.",

    # --- Virtual account (3 keys) ---
    "virtualAccountTitle": "Compte virtuel",
    "virtualAccountInfoBody": "Ce compte vous est unique. Tout virement vers ce compte crédite automatiquement votre portefeuille.",
    "yourVirtualAccountLabel": "Votre compte virtuel",

    # --- Wallet error resolvers (4 keys) ---
    "walletErrorFailedToFetchTransaction": "Échec de la récupération de la transaction",
    "walletErrorFailedToLookupWallet": "Échec de la recherche du portefeuille",
    "walletErrorFallback": "L'opération du portefeuille a échoué. Veuillez réessayer.",
    "walletErrorTooManyRequests": "Trop de requêtes. Veuillez réessayer plus tard.",

    # --- Wallet UI errors not in 4a (5 keys) ---
    "walletUiErrorPaymentStillPending": "Paiement toujours en attente. Veuillez vérifier votre téléphone et réessayer.",
    "walletUiErrorPleaseEnter6DigitOtp": "Veuillez saisir un OTP valide à 6 chiffres",
    "walletUiErrorPleaseSelectMomoProvider": "Veuillez sélectionner un opérateur Mobile Money",
    "walletUiErrorUserNotFound": "Utilisateur introuvable. Veuillez vous reconnecter.",
    "walletUiErrorWithdrawalFailedRefunded": "Échec du retrait. Votre solde a été remboursé.",
}

assert len(TRANSLATIONS) == 73, f"Spec dict has {len(TRANSLATIONS)} entries, expected 73"
```

### 3.2 Apply script

The agent saves and runs this script as `/tmp/apply_fr_batch_4b.py`. Self-contained — embeds the dict, validates everything, writes the result back.

```python
#!/usr/bin/env python3
"""
Phase 6 Step 10 - French Batch 4b - Wallet, Money Flows, Mobile Money, Currency
Applies 73 French translations to lib/l10n/app_fr.arb.
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
    assert len(TRANSLATIONS) == 73, f"Expected 73 translations, got {len(TRANSLATIONS)}"

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
    # Withdraw flow ICU (3 keys)
    assert "{symbol}" in fr["enterOtpBody"], "enterOtpBody lost {symbol}"
    assert "{amount}" in fr["enterOtpBody"], "enterOtpBody lost {amount}"
    assert "{reference}" in fr["refLine"], "refLine lost {reference}"
    assert "{symbol}" in fr["withdrawalBeingProcessed"], "withdrawalBeingProcessed lost {symbol}"
    assert "{amount}" in fr["withdrawalBeingProcessed"], "withdrawalBeingProcessed lost {amount}"
    # Currency formatter ICU (5 keys)
    assert "{symbol}" in fr["amountWithCurrency"], "amountWithCurrency lost {symbol}"
    assert "{amount}" in fr["amountWithCurrency"], "amountWithCurrency lost {amount}"
    assert "{currency}" in fr["currencyAmount"], "currencyAmount lost {currency}"
    assert "{amount}" in fr["currencyAmount"], "currencyAmount lost {amount}"
    assert "{symbol}" in fr["currencyCodeWithSymbol"], "currencyCodeWithSymbol lost {symbol}"
    assert "{code}" in fr["currencyCodeWithSymbol"], "currencyCodeWithSymbol lost {code}"
    assert "{prefix}" in fr["signedCurrencyAmount"], "signedCurrencyAmount lost {prefix}"
    assert "{currency}" in fr["signedCurrencyAmount"], "signedCurrencyAmount lost {currency}"
    assert "{amount}" in fr["signedCurrencyAmount"], "signedCurrencyAmount lost {amount}"
    assert "{symbol}" in fr["symbolAmount"], "symbolAmount lost {symbol}"
    assert "{amount}" in fr["symbolAmount"], "symbolAmount lost {amount}"
    # Exchange rate ICU (2 keys)
    assert "{from}" in fr["exchangeRateErrorUnsupportedCurrencyPair"], \
        "exchangeRateErrorUnsupportedCurrencyPair lost {from}"
    assert "{to}" in fr["exchangeRateErrorUnsupportedCurrencyPair"], \
        "exchangeRateErrorUnsupportedCurrencyPair lost {to}"
    assert "{fromCurrency}" in fr["exchangeRateLine"], "exchangeRateLine lost {fromCurrency}"
    assert "{rate}" in fr["exchangeRateLine"], "exchangeRateLine lost {rate}"
    assert "{toCurrency}" in fr["exchangeRateLine"], "exchangeRateLine lost {toCurrency}"
    # MoMo ICU (1 key)
    assert "{symbol}" in fr["mtnMomoApprovePromptBody"], "mtnMomoApprovePromptBody lost {symbol}"
    assert "{amount}" in fr["mtnMomoApprovePromptBody"], "mtnMomoApprovePromptBody lost {amount}"

    # Write back, preserving original JSON style (2-space indent, ensure_ascii=False for accents)
    ARB_PATH.write_text(
        json.dumps(fr, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8"
    )

    # Final report
    filled_after = sum(1 for k in fr_keys if fr[k] != "")
    empty_after = sum(1 for k in fr_keys if fr[k] == "")
    print(f"OK — applied {len(TRANSLATIONS)} translations")
    print(f"FR filled: {filled_after}/{len(fr_keys)} (was 270, expected {270 + len(TRANSLATIONS)})")
    print(f"FR empty: {empty_after}")

if __name__ == "__main__":
    main()
```

**Run command:**
```bash
python3 /tmp/apply_fr_batch_4b.py
```

Expected output (approximately):
```
OK — applied 73 translations
FR filled: 343/701 (was 270, expected 343)
FR empty: 358
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
- FR filled: 343

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
    "availableBalance": "Solde disponible",
    "totalBalance": "Solde total",
    "onHoldBalanceLabel": "En attente",
    "addMoney": "Ajouter de l'argent",
    "withdraw": "Retirer",
    "withdrawalBeingProcessed": "{symbol}{amount} est en cours de traitement",
    "enterOtpBody": "Veuillez saisir l'OTP envoyé à votre téléphone/e-mail enregistré pour finaliser le retrait de {symbol}{amount}",
    "refLine": "Réf : {reference}",
    "currencyAmount": "{currency} {amount}",
    "exchangeRateLine": "1 {fromCurrency} = {rate} {toCurrency}",
    "exchangeRateErrorUnsupportedCurrencyPair": "Devise non prise en charge : {from} ou {to}",
    "mtnMomoApprovePromptBody": "Veuillez approuver le paiement de {symbol}{amount} sur votre téléphone MTN MoMo.",
    "paystackSecurityNote": "Propulsé par Paystack. Vos informations de paiement sont sécurisées.",
    "virtualAccountInfoBody": "Ce compte vous est unique. Tout virement vers ce compte crédite automatiquement votre portefeuille.",
    "walletUiErrorWithdrawalFailedRefunded": "Échec du retrait. Votre solde a été remboursé.",
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
10.fr-batch-4b: French translations for wallet/money flows/MoMo/currency (73 keys)

Translates 73 keys covering wallet display, money flows, payment
methods, and currency formatters:
- Wallet display & balance (10 keys)
- Add money flow (8 keys)
- Withdraw flow (10 keys, 3 ICU)
- Generic amount entry & insufficient balance (9 keys)
- Currency display formatters (5 ICU keys)
- Exchange rate (4 keys, 2 ICU)
- Mobile Money + MTN MoMo + Paystack (15 keys, 1 ICU)
- Virtual account (3 keys)
- Wallet error resolvers (4 keys)
- Wallet UI errors not in 4a (5 keys)

ICU placeholders preserved (verified by apply-script assertions, 11 keys
total): enterOtpBody, refLine, withdrawalBeingProcessed,
amountWithCurrency, currencyAmount, currencyCodeWithSymbol,
signedCurrencyAmount, symbolAmount, exchangeRateErrorUnsupportedCurrencyPair,
exchangeRateLine, mtnMomoApprovePromptBody.

Convention notes:
- "Solde" for balance (banking standard)
- "Mobile Money" kept as-is (brand-like in francophone Africa fintech;
  used by MTN/Orange in their French interfaces)
- "Opérateur" for MoMo provider
- "Fonds" for funds (banking)
- "En attente" for "On Hold" (user-friendly vs "Bloqué")
- "Propulsé par Paystack" for "Powered by Paystack"
- "Devise" for currency (financial precision over generic "monnaie")
- "Compte virtuel" for "Virtual Account"
- "ID du portefeuille" for "Wallet ID" (short form)
- "Réf :" for "Ref:" (French typography, space before colon)
- Currency formatter keys (5) are pure placeholder concatenations —
  English and French values are nearly identical, format preserved
  (symbol-first matches francophone-Africa fintech convention)
- Brand names stay English: QR Wallet, MTN MoMo, Paystack

Files modified: lib/l10n/app_fr.arb only.
Reference: docs/PHASE_6_STEP_10_FR_BATCH_4B_WALLET_MONEY_FLOWS.md
EOF
git commit -F /tmp/commit_msg.txt
```

---

## 6. Push (branch only, NOT main)

```bash
git push -u origin phase6-step10-fr-batch-4b
```

**DO NOT** push to `main`. **DO NOT** create the tag `phase6-step10-fr-batch-4b-complete` — that is the operator's job after merge.

---

## 7. Reporting (agent → operator)

Report back with:

1. **Branch name:** `phase6-step10-fr-batch-4b`
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
   git checkout phase6-step10-fr-batch-4b
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

   Expected: 204 analyzer issues (baseline), build green. If analyzer count goes up, STOP — likely an ICU placeholder mismatch (this batch has 11 ICU keys, the most so far — placeholder integrity is critical).

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
   git merge --ff-only phase6-step10-fr-batch-4b
   ```

9. Tag, push, delete branch:
   ```bash
   git tag phase6-step10-fr-batch-4b-complete
   git push origin main
   git push origin phase6-step10-fr-batch-4b-complete
   git push origin :phase6-step10-fr-batch-4b
   git branch -d phase6-step10-fr-batch-4b
   ```

---

## 10. Translation conventions (extension to Batches 1-4a)

These conventions apply to ALL French batches in Step 10, with wallet/money/currency-specific additions for Batch 4b.

| Convention | Decision |
|---|---|
| (Batch 1) Register | Formal (vous, not tu) |
| (Batch 1) Brand names | Stay in English |
| (Batch 1) Punctuation | French typography (space before ! ? : ;) |
| (Batch 1) OTP | Kept as "OTP" |
| (Batch 4a) Bank account / Account | "compte bancaire" / "compte" |
| **NEW (Batch 4b)** Wallet (generic) | "portefeuille" |
| **NEW (Batch 4b)** Wallet ID | "ID du portefeuille" |
| **NEW (Batch 4b)** Balance (financial) | "solde" (banking standard) |
| **NEW (Batch 4b)** Available balance | "Solde disponible" |
| **NEW (Batch 4b)** Total balance | "Solde total" |
| **NEW (Batch 4b)** On Hold (balance) | "En attente" (user-friendly vs "Bloqué") |
| **NEW (Batch 4b)** Hide / Show balance | "Masquer / Afficher le solde" |
| **NEW (Batch 4b)** Amount | "montant" |
| **NEW (Batch 4b)** Insufficient balance | "Solde insuffisant" |
| **NEW (Batch 4b)** Add money | "Ajouter de l'argent" |
| **NEW (Batch 4b)** Withdraw (verb) | "retirer" |
| **NEW (Batch 4b)** Withdrawal (noun) | "retrait" |
| **NEW (Batch 4b)** Card (payment method) | "carte" |
| **NEW (Batch 4b)** Bank Transfer | "Virement bancaire" |
| **NEW (Batch 4b)** Mobile Money | "Mobile Money" (kept as-is — brand-like in francophone Africa) |
| **NEW (Batch 4b)** Mobile Money provider | "Opérateur Mobile Money" |
| **NEW (Batch 4b)** Funds | "fonds" (banking) |
| **NEW (Batch 4b)** Currency | "devise" (financial precision over "monnaie") |
| **NEW (Batch 4b)** Exchange rate | "taux de change" |
| **NEW (Batch 4b)** Unsupported (currency) | "non prise en charge" |
| **NEW (Batch 4b)** Virtual account | "Compte virtuel" |
| **NEW (Batch 4b)** Approval prompt | "invite d'approbation" |
| **NEW (Batch 4b)** Approve (verb) | "approuver" |
| **NEW (Batch 4b)** Refund / refunded | "rembourser" / "remboursé" |
| **NEW (Batch 4b)** Powered by | "Propulsé par" |
| **NEW (Batch 4b)** Decline (a payment) | "refuser" |
| **NEW (Batch 4b)** Time out | "expirer" / "a expiré" |
| **NEW (Batch 4b)** Pending (payment) | "en attente" |
| **NEW (Batch 4b)** Processing (transaction) | "en cours de traitement" |
| **NEW (Batch 4b)** Reference (Ref:) | "Réf :" (with French typography colon spacing) |
| **NEW (Batch 4b)** "User not found" | "Utilisateur introuvable" |
| **NEW (Batch 4b)** "Please log in again" | "Veuillez vous reconnecter" |
