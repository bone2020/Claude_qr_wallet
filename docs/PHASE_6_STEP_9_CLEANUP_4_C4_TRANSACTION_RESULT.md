# Phase 6 Step 9 — Cleanup-4 (Sub-batch C.4): TransactionResult Localization

**Status:** READY TO IMPLEMENT
**Companion to:** `docs/PHASE_6_LOCALIZATION_SPEC.md`, `docs/PHASE_6_STEP_9_CLEANUP_4_C3_USER_SURFACE_AND_KYC_UI.md`
**Predecessor commit:** `8f420afe` (cleanup-4 C.3, recovery cherry-pick)
**Predecessor tag (C.3):** `phase6-step9-cleanup-4-c3-complete` @ `8f420afe`
**Target tag:** `phase6-step9-cleanup-4-c4-complete`

## Background

Cleanup-4 sub-batch C.3 shipped the user surface + KYC UI sweep. **C.4 covers TransactionResult localization** — the result type produced by `wallet_service.dart`'s `sendMoney` and `addMoney` methods.

C.4 covers:
- 9 hardcoded English strings inside or around `TransactionResult.failure(...)` calls in `wallet_service.dart`, including a 5-case inline `switch` block on FirebaseFunctionsException codes
- 1 UI consumer migration: `confirm_send_screen.dart:434` (the `result.error ?? 'Transaction failed'` pattern)

After C.4: when a French- or Arabic-locale user sends money or hits any send-flow / deposit-flow error path, they'll see translated text once Step 10 fills the fr/ar values.

## Out of scope for C.4 (deferred to C.5)

- **BiometricResult migration.** Has 16 hardcoded strings in `biometric_service.dart` split into three groups (biometric type names, BiometricResult.failure messages, and what looks like a `_getBiometricErrorMessage` switch); needs deeper investigation before scoping. C.5 picks it up.
- **Pure-UI hardcoded strings** in `add_money_screen.dart`, `withdraw_screen.dart`, `confirm_send_screen.dart` (other than the L434 site), `scan_qr_screen.dart`. These don't require schema migrations — pure ARB key additions and direct `loc.X` substitutions. C.5 sweeps them.
- **PaymentResult / WithdrawalResult / MomoPaymentResult / MobileMoneyPaymentResult / VirtualAccountResult / PaymentVerificationResult.** None of these have hardcoded English in their producer side (`payment_service.dart` and `momo_service.dart` chain through `ErrorHandler.getUserFriendlyMessage(e)` for all error paths). They have UI fallback patterns in `add_money_screen.dart` and `withdraw_screen.dart` that read `result.error ?? loc.someKey` — already-localized fallbacks but not using the resolver pattern. C.5 absorbs those refactors as part of the UI sweep.
- **WalletException localization.** Same blocker as C.3 — zero `on WalletException catch` sites, requiring catcher refactoring. C.5.
- **`exchange_rate_service.dart` exception localization.** 4 `throw Exception('Unsupported currency...')` sites. C.5.
- **Transitional `error: String` collapse and orphaned `failedToCompleteVerification` ARB key removal.** C.5 hygiene.

## Architectural decisions (locked)

1. **Single nullable `errorKey` field on TransactionResult.** Mirrors C.2/C.3 pattern. TransactionResult gains `errorKey: TransactionErrorKey?` alongside the existing `error: String?`. The old String stays for backward compat (transitional, collapsed in C.5).

2. **One unified `TransactionErrorKey` enum** with 10 values (9 specific + 1 fallback). Every TransactionResult.failure site populates both fields.

3. **No reuse of UserErrorKey from C.3.** TransactionErrorKey gets its own `userNotAuthenticated` value rather than reusing `UserErrorKey.userNotAuthenticated`. Per-domain pattern, consistent with C.2's "keep originals" decision.

4. **The inline switch at L218-235 is rewritten in place**, NOT extracted to a helper. The switch is used at exactly one site (sendMoney's FirebaseFunctionsException catch), so a helper would only add indirection. Inline expansion adds an `errorKey` assignment alongside each `errorMessage` assignment in each case branch.

5. **Server messages are preserved in the `error: String` field** where the original code did so. The current code uses `data['error'] as String? ?? 'Hardcoded English'` and `e.message ?? 'Hardcoded English'` patterns — these prefer server-provided messages when present, fall back to hardcoded English when null. Migration keeps this behavior: `errorMessage` retains the same `?? 'English'` shape so backend-provided diagnostic text is not lost. The `errorKey` is set unconditionally based on the switch case.

6. **Interpolation strings (`'Transaction failed: $e'`, `'Deposit failed: $e'`) drop the technical interpolation** from the user-visible message and preserve the technical detail in `debugPrint` for engineers. Same precedent as cleanup-3 (smile_id parse error), C.1, and C.2 (Apple sign-in failed).

7. **Mandatory `loc` capture pattern applied to `confirm_send_screen.dart`.** The L434 migration must capture `final loc = AppLocalizations.of(context);` near the top of the enclosing method body, before any `await`.

8. **`addMoney` method's TransactionResult.failure sites get migrated despite being dead code.** Investigation found zero callers of `wallet_service.addMoney`, but migration is still applied for consistency and to prevent future drift. The `addMoney` method may be reactivated later (e.g., for a non-Paystack deposit flow); having the errorKey infrastructure already in place will make that reactivation seamless.

## Scope summary

- **1 file edited (schema + 9 sites):** `lib/core/services/wallet_service.dart`
- **1 new file:** `lib/core/services/transaction_localization_resolver.dart`
- **1 UI file edited (1 site):** `lib/features/send/screens/confirm_send_screen.dart`
- **3 ARB files modified:** `app_en.arb` (10 new keys with @-metadata), `app_fr.arb` and `app_ar.arb` (10 placeholders each)

**File count: 6.** Smallest sub-batch in C.4 series.

**Total string migrations:** 9 service-layer + 1 UI = 10.

## Pre-flight check

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c4_preflight.sh << 'PREFLIGHT_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== Capture analyzer baseline (must match post-fix exactly) ===="
flutter analyze 2>&1 | tail -3

echo ""
echo "==== Confirm origin/main is at C.3 cherry-pick commit (8f420afe) ===="
git fetch origin
git rev-parse origin/main

echo ""
echo "==== Confirm local main is in sync with origin/main ===="
local_main=$(git rev-parse main)
origin_main=$(git rev-parse origin/main)
if [ "$local_main" != "$origin_main" ]; then
  echo "FAIL — local main and origin/main differ. Sync before merging."
  echo "  Local main:  $local_main"
  echo "  Origin main: $origin_main"
  exit 1
fi
echo "PASS — local main matches origin/main at $local_main"

echo ""
echo "==== Confirm C.3 infrastructure is in place ===="
[ -f lib/core/services/user_localization_resolver.dart ] && echo "PASS: user_localization_resolver.dart exists" || echo "FAIL: missing"
grep -nE "^enum UserErrorKey" lib/core/services/user_localization_resolver.dart && echo "PASS: UserErrorKey enum exists" || echo "FAIL: missing"

echo ""
echo "==== Confirm TransactionResult class is unchanged (3-field shape, no errorKey) ===="
sed -n '/^class TransactionResult/,/^}/p' lib/core/services/wallet_service.dart

echo ""
echo "==== Confirm new resolver file does not yet exist ===="
[ -f lib/core/services/transaction_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "Does not exist yet — OK"

echo ""
echo "==== Working tree must be clean ===="
git status --short
PREFLIGHT_EOF

bash /tmp/cleanup4_c4_preflight.sh
```

**Expected:** analyzer at 204; origin/main at `8f420afe`; local main matches origin/main; C.3 resolver file exists with UserErrorKey enum; TransactionResult class shows existing 3-field shape; new resolver file does not yet exist; working tree clean.

---

## Step 1 — Add 10 new keys to `lib/l10n/app_en.arb`

```bash
python3 << 'PYEOF'
import json

ARB_PATH = "lib/l10n/app_en.arb"

NEW_KEYS = [
    ("transactionErrorUserNotAuthenticated",
     "User not authenticated",
     "Shown when a transaction is attempted but the user is not signed in."),
    ("transactionErrorPleaseLogInToSendMoney",
     "Please log in to send money",
     "Shown when sendMoney's Cloud Function returns an 'unauthenticated' error code."),
    ("transactionErrorRecipientWalletNotFound",
     "Recipient wallet not found",
     "Shown when sendMoney's Cloud Function returns a 'not-found' error code."),
    ("transactionErrorInsufficientBalance",
     "Insufficient balance",
     "Shown when sendMoney's Cloud Function returns a 'failed-precondition' error code, indicating not enough wallet balance."),
    ("transactionErrorInvalidRequest",
     "Invalid request",
     "Shown when sendMoney's Cloud Function returns an 'invalid-argument' error code without a more specific server message."),
    ("transactionErrorTransactionFailed",
     "Transaction failed",
     "Generic transaction-failure message — used when the server returns no specific error or the error code is not specifically classified."),
    ("transactionErrorPaymentAlreadyProcessed",
     "Payment already processed",
     "Shown when addMoney detects that the payment has already been credited (idempotency check)."),
    ("transactionErrorPaymentVerificationFailed",
     "Payment verification failed",
     "Shown when addMoney's verification step fails or returns no specific error message."),
    ("transactionErrorDepositFailed",
     "Deposit failed",
     "Shown when addMoney throws a generic exception. Technical detail is logged separately via debugPrint."),
    ("transactionErrorFallback",
     "Couldn't complete the transaction. Please try again.",
     "Generic TransactionResult fallback when no specific case applies."),
]

assert len(NEW_KEYS) == 10, f"Expected 10, got {len(NEW_KEYS)}"

with open(ARB_PATH, "r", encoding="utf-8") as f:
    arb = json.load(f)

added = []
skipped = []
for key, value, description in NEW_KEYS:
    if key in arb:
        skipped.append(key)
        continue
    arb[key] = value
    arb[f"@{key}"] = {"description": description}
    added.append(key)

with open(ARB_PATH, "w", encoding="utf-8") as f:
    json.dump(arb, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Added {len(added)} keys")
print(f"Skipped {len(skipped)} keys: {skipped}")
PYEOF
```

**Expected:** `Added 10 keys`, `Skipped 0 keys: []`.

---

## Step 2 — Add 10 placeholder keys to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb`

```bash
python3 << 'PYEOF'
import json

NEW_KEY_NAMES = [
    "transactionErrorUserNotAuthenticated",
    "transactionErrorPleaseLogInToSendMoney",
    "transactionErrorRecipientWalletNotFound",
    "transactionErrorInsufficientBalance",
    "transactionErrorInvalidRequest",
    "transactionErrorTransactionFailed",
    "transactionErrorPaymentAlreadyProcessed",
    "transactionErrorPaymentVerificationFailed",
    "transactionErrorDepositFailed",
    "transactionErrorFallback",
]

assert len(NEW_KEY_NAMES) == 10, f"Expected 10, got {len(NEW_KEY_NAMES)}"

for arb_path in ["lib/l10n/app_fr.arb", "lib/l10n/app_ar.arb"]:
    with open(arb_path, "r", encoding="utf-8") as f:
        arb = json.load(f)
    added = []
    skipped = []
    for key in NEW_KEY_NAMES:
        if key in arb:
            skipped.append(key)
            continue
        arb[key] = ""
        added.append(key)
    with open(arb_path, "w", encoding="utf-8") as f:
        json.dump(arb, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{arb_path}: added {len(added)}, skipped {len(skipped)}")
PYEOF
```

**Expected:** both files report `added 10, skipped 0`.

---

## Step 3 — `flutter gen-l10n` (SKIPPED BY THE AGENT)

The human reviewer runs this locally after pulling the feature branch.

---

## Step 4 — Create new file `lib/core/services/transaction_localization_resolver.dart`

```dart
import '../../generated/l10n/app_localizations.dart';
import 'wallet_service.dart';

/// Identifies the kind of transaction error carried by [TransactionResult.errorKey].
///
/// Mirrors the C.2/C.3 pattern: a single enum captures every error path produced
/// by wallet_service.dart's TransactionResult-returning methods (sendMoney and
/// addMoney), with a single resolver function and a single field on the result
/// class.
enum TransactionErrorKey {
  // Send-flow keys
  userNotAuthenticated,
  pleaseLogInToSendMoney,
  recipientWalletNotFound,
  insufficientBalance,
  invalidRequest,
  transactionFailed,

  // Deposit-flow keys
  paymentAlreadyProcessed,
  paymentVerificationFailed,
  depositFailed,

  // Catch-all
  fallback,
}

/// Resolves a [TransactionErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch — adding a new enum value without
/// a matching case here is a compile error.
String resolveTransactionErrorMessage(AppLocalizations loc, TransactionErrorKey key) {
  return switch (key) {
    TransactionErrorKey.userNotAuthenticated => loc.transactionErrorUserNotAuthenticated,
    TransactionErrorKey.pleaseLogInToSendMoney => loc.transactionErrorPleaseLogInToSendMoney,
    TransactionErrorKey.recipientWalletNotFound => loc.transactionErrorRecipientWalletNotFound,
    TransactionErrorKey.insufficientBalance => loc.transactionErrorInsufficientBalance,
    TransactionErrorKey.invalidRequest => loc.transactionErrorInvalidRequest,
    TransactionErrorKey.transactionFailed => loc.transactionErrorTransactionFailed,
    TransactionErrorKey.paymentAlreadyProcessed => loc.transactionErrorPaymentAlreadyProcessed,
    TransactionErrorKey.paymentVerificationFailed => loc.transactionErrorPaymentVerificationFailed,
    TransactionErrorKey.depositFailed => loc.transactionErrorDepositFailed,
    TransactionErrorKey.fallback => loc.transactionErrorFallback,
  };
}

/// One-line resolver for UI consumers. Picks the best message available:
///
///   1. If [TransactionResult.errorKey] is non-null, resolve via [resolveTransactionErrorMessage].
///   2. Else if [TransactionResult.error] is non-null (transitional during C.4-C.5),
///      return it as-is.
///   3. Else return the generic transaction fallback.
///
/// UI screens should call this rather than reading [TransactionResult.error] directly.
String resolveTransactionResultError(AppLocalizations loc, TransactionResult result) {
  if (result.errorKey != null) {
    return resolveTransactionErrorMessage(loc, result.errorKey!);
  }
  return result.error ?? loc.transactionErrorFallback;
}
```

---

## Step 5 — Edit `lib/core/services/wallet_service.dart`

The agent should view the file in full first (it's ~523 lines) before applying edits.

### 5.1 — Add resolver import at top of file

Locate the existing import block. Add the new resolver import alongside.

**Search:** the agent should grep for the existing imports and add `import 'transaction_localization_resolver.dart';` after the last `import 'X.dart'` line that imports a sibling service file. If the file imports `error_handler.dart`, add immediately after:

**Search:**
```dart
import '../utils/error_handler.dart';
```

**Replace:**
```dart
import '../utils/error_handler.dart';
import 'transaction_localization_resolver.dart';
```

If that anchor is not present, agent uses an alternate unambiguous anchor based on the actual import block.

### 5.2 — Add `package:flutter/foundation.dart` import for debugPrint

The interpolation-drop migration in Steps 5.3.h and 5.3.k requires `debugPrint`. Check if it's already imported:

```bash
grep -n "package:flutter/foundation\|debugPrint" lib/core/services/wallet_service.dart
```

If `package:flutter/foundation.dart` is NOT imported, add it alongside the other imports at the top of the file. If it IS already imported, skip.

### 5.3 — Update `TransactionResult` class to add `errorKey` field

**Search:**
```dart
class TransactionResult {
  final bool success;
  final TransactionModel? transaction;
  final String? error;

  TransactionResult._({
    required this.success,
    this.transaction,
    this.error,
  });

  factory TransactionResult.success(TransactionModel transaction) {
    return TransactionResult._(success: true, transaction: transaction);
  }

  factory TransactionResult.failure(String error) {
    return TransactionResult._(success: false, error: error);
  }
}
```

**Replace:**
```dart
class TransactionResult {
  final bool success;
  final TransactionModel? transaction;
  final String? error;
  final TransactionErrorKey? errorKey;

  TransactionResult._({
    required this.success,
    this.transaction,
    this.error,
    this.errorKey,
  });

  factory TransactionResult.success(TransactionModel transaction) {
    return TransactionResult._(success: true, transaction: transaction);
  }

  factory TransactionResult.failure(String error, {TransactionErrorKey? errorKey}) {
    return TransactionResult._(success: false, error: error, errorKey: errorKey);
  }
}
```

### 5.4 — Migrate the 9 TransactionResult.failure() sites

Line numbers are approximate. Agent uses `grep -n "TransactionResult\.failure"` to confirm exact lines before each str_replace. Sites are migrated top-down to avoid line drift.

**5.4.a — sendMoney auth check (approximate line 171)**

**Search:**
```dart
      return TransactionResult.failure('User not authenticated');
```

If 'User not authenticated' appears at multiple lines (sendMoney L171 and addMoney L249), use `replace_all=true` since the migration is identical for both.

**Replace:**
```dart
      return TransactionResult.failure('User not authenticated', errorKey: TransactionErrorKey.userNotAuthenticated);
```

(Use `replace_all=true` — there are 2 identical occurrences across sendMoney and addMoney.)

**5.4.b — sendMoney server error fallback (approximate line 215)**

**Search:**
```dart
        return TransactionResult.failure(data['error'] as String? ?? 'Transaction failed');
```

**Replace:**
```dart
        return TransactionResult.failure(
          data['error'] as String? ?? 'Transaction failed',
          errorKey: TransactionErrorKey.transactionFailed,
        );
```

**5.4.c — sendMoney FirebaseFunctionsException inline switch (lines 217-235)**

This is the largest single migration in C.4. The entire switch block is rewritten to populate both `errorMessage` and a new `errorKey` local variable, then both are passed to `TransactionResult.failure(...)`.

**Search:**
```dart
    } on FirebaseFunctionsException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'Please log in to send money';
          break;
        case 'not-found':
          errorMessage = 'Recipient wallet not found';
          break;
        case 'failed-precondition':
          errorMessage = 'Insufficient balance';
          break;
        case 'invalid-argument':
          errorMessage = e.message ?? 'Invalid request';
          break;
        default:
          errorMessage = e.message ?? 'Transaction failed';
      }
      return TransactionResult.failure(errorMessage);
    } catch (e) {
      return TransactionResult.failure('Transaction failed: $e');
    }
```

**Replace:**
```dart
    } on FirebaseFunctionsException catch (e) {
      String errorMessage;
      TransactionErrorKey errorKey;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'Please log in to send money';
          errorKey = TransactionErrorKey.pleaseLogInToSendMoney;
          break;
        case 'not-found':
          errorMessage = 'Recipient wallet not found';
          errorKey = TransactionErrorKey.recipientWalletNotFound;
          break;
        case 'failed-precondition':
          errorMessage = 'Insufficient balance';
          errorKey = TransactionErrorKey.insufficientBalance;
          break;
        case 'invalid-argument':
          errorMessage = e.message ?? 'Invalid request';
          errorKey = TransactionErrorKey.invalidRequest;
          break;
        default:
          errorMessage = e.message ?? 'Transaction failed';
          errorKey = TransactionErrorKey.transactionFailed;
      }
      return TransactionResult.failure(errorMessage, errorKey: errorKey);
    } catch (e) {
      debugPrint('Transaction failed: $e');
      return TransactionResult.failure(
        'Transaction failed',
        errorKey: TransactionErrorKey.transactionFailed,
      );
    }
```

This single str_replace handles both the inline switch (5 cases) AND the generic catch's interpolation drop in one shot. The interpolation `'Transaction failed: $e'` becomes a `debugPrint` for engineers + a clean translated message for users.

**5.4.d — addMoney auth check (approximate line 249)**

This is the second occurrence of `'User not authenticated'`. If you used `replace_all=true` in step 5.4.a, this is already migrated. Verify:

```bash
grep -n "TransactionResult\.failure('User not authenticated'" lib/core/services/wallet_service.dart
```

Should return zero matches (because `replace_all=true` got both). If any match remains, apply the same str_replace as 5.4.a.

**5.4.e — addMoney already-processed (approximate line 297)**

**Search:**
```dart
        return TransactionResult.failure('Payment already processed');
```

**Replace:**
```dart
        return TransactionResult.failure('Payment already processed', errorKey: TransactionErrorKey.paymentAlreadyProcessed);
```

**5.4.f — addMoney server error fallback (approximate line 299)**

**Search:**
```dart
        return TransactionResult.failure(data['error'] as String? ?? 'Payment verification failed');
```

**Replace:**
```dart
        return TransactionResult.failure(
          data['error'] as String? ?? 'Payment verification failed',
          errorKey: TransactionErrorKey.paymentVerificationFailed,
        );
```

**5.4.g — addMoney FirebaseFunctionsException catch (approximate line 302)**

**Search:**
```dart
    } on FirebaseFunctionsException catch (e) {
      return TransactionResult.failure(e.message ?? 'Payment verification failed');
    } catch (e) {
      return TransactionResult.failure('Deposit failed: $e');
    }
```

**Replace:**
```dart
    } on FirebaseFunctionsException catch (e) {
      return TransactionResult.failure(
        e.message ?? 'Payment verification failed',
        errorKey: TransactionErrorKey.paymentVerificationFailed,
      );
    } catch (e) {
      debugPrint('Deposit failed: $e');
      return TransactionResult.failure(
        'Deposit failed',
        errorKey: TransactionErrorKey.depositFailed,
      );
    }
```

This handles the addMoney FirebaseFunctionsException catch AND the generic catch (with interpolation drop) in one str_replace.

### 5.5 — Verification of Step 5

Before moving to Step 6, the agent runs:

```bash
echo "==== All TransactionResult.failure calls ===="
grep -nE "TransactionResult\.failure" lib/core/services/wallet_service.dart

echo ""
echo "==== Bare TransactionResult.failure calls (no errorKey) ===="
python3 << 'PYINNER'
import re
content = open('lib/core/services/wallet_service.dart').read()
# Find TransactionResult.failure(...) calls — multi-line aware
matches = list(re.finditer(r'TransactionResult\.failure\((.+?)\)\s*;', content, re.DOTALL))
total = len(matches)
with_key = sum(1 for m in matches if 'errorKey:' in m.group(1))
without_key = total - with_key
print(f'Total: {total}')
print(f'With errorKey: {with_key}')
print(f'Without errorKey: {without_key} (expected 0 — but may include factory definition self-reference)')
if without_key > 0:
    for m in matches:
        if 'errorKey:' not in m.group(1):
            line_no = content[:m.start()].count('\n') + 1
            print(f'  L{line_no}: TransactionResult.failure({m.group(1).strip()[:60]}...)')
PYINNER
```

**Expected:** every `TransactionResult.failure(...)` call (besides the factory definition itself, which doesn't count as a call) has `errorKey:`. Count is approximately 9 calls + 1 factory = 10 occurrences total.

---

## Step 6 — Migrate UI consumer in `confirm_send_screen.dart` (1 site)

The site is at approximately line 434. The agent should view the surrounding ~30 lines to identify the enclosing method and apply the mandatory `loc` capture rule.

**Add import** (relative path from `lib/features/send/screens/`):
```dart
import '../../../core/services/transaction_localization_resolver.dart';
```

The exact placement: alongside other relative imports in the file. Agent uses an unambiguous anchor like the existing wallet_service or auth_service import to position it.

### 6.1 — `loc` capture in the enclosing method

The L434 site is inside a method that starts somewhere before L405 (visible in the investigation Section B output). The agent identifies the method and ensures `final loc = AppLocalizations.of(context);` is declared at the top of the method body, before any `await`. Add if missing.

### 6.2 — Migrate the L434 site

**Search:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Transaction failed'),
            backgroundColor: AppColors.error,
          ),
        );
```

**Replace:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveTransactionResultError(loc, result)),
            backgroundColor: AppColors.error,
          ),
        );
```

---

## Step 7 — Verification (skip Flutter calls; run all greps)

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c4_verify.sh << 'VERIFY_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== A. Resolver file exists with correct shape ===="
ls -la lib/core/services/transaction_localization_resolver.dart
echo "Enum values (expect exactly 10):"
python3 << 'PYINNER'
import re
content = open('lib/core/services/transaction_localization_resolver.dart').read()
m = re.search(r'enum TransactionErrorKey \{(.*?)\n\}', content, re.DOTALL)
if not m:
    print("  FAIL — couldn't locate enum block")
else:
    body = m.group(1)
    values = []
    for line in body.split('\n'):
        line = line.strip()
        if not line or line.startswith('//'):
            continue
        m2 = re.match(r'^([a-zA-Z_]\w*),', line)
        if m2:
            values.append(m2.group(1))
    print(f'  Found: {len(values)} ({values})')
    print(f'  {"PASS" if len(values) == 10 else "FAIL"}')
PYINNER
echo "Resolver functions (expect 2):"
grep -nE "^String resolve" lib/core/services/transaction_localization_resolver.dart

echo ""
echo "==== B. TransactionResult schema has new errorKey field ===="
sed -n '/^class TransactionResult /,/^}$/p' lib/core/services/wallet_service.dart

echo ""
echo "==== C. wallet_service.dart imports added ===="
grep -n "transaction_localization_resolver\|package:flutter/foundation" lib/core/services/wallet_service.dart

echo ""
echo "==== D. All TransactionResult.failure sites use errorKey ===="
python3 << 'PYINNER'
import re
content = open('lib/core/services/wallet_service.dart').read()
matches = list(re.finditer(r'TransactionResult\.failure\((.+?)\)\s*;', content, re.DOTALL))
total = len(matches)
with_key = sum(1 for m in matches if 'errorKey:' in m.group(1))
without_key = [(content[:m.start()].count('\n') + 1, m.group(1).strip()[:80]) for m in matches if 'errorKey:' not in m.group(1)]
print(f'  Total TransactionResult.failure call-sites: {total}')
print(f'  With errorKey: {with_key} (expected 9)')
print(f'  Without errorKey: {len(without_key)} (expected 0)')
for line, snippet in without_key:
    print(f'    L{line}: {snippet}...')
PYINNER

echo ""
echo "==== E. ARB integrity vs C.3 baseline ===="
git show phase6-step9-cleanup-4-c3-complete:lib/l10n/app_en.arb 2>/dev/null | python3 -c "import json,sys; arb=json.load(sys.stdin); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'Pre-C.4 baseline: total={len(arb)}, value={v}, meta={m}')"
python3 -c "import json; arb=json.load(open('lib/l10n/app_en.arb')); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'Post-C.4: total={len(arb)}, value={v}, meta={m}')"
echo "(Difference must be exactly +10 value, +10 meta, +20 total)"
python3 << 'PYINNER'
import json, subprocess
old = json.loads(subprocess.check_output(['git','show','phase6-step9-cleanup-4-c3-complete:lib/l10n/app_en.arb']))
new = json.load(open('lib/l10n/app_en.arb'))
lost = [k for k in old if k not in new]
mutated = [k for k in old if k in new and old[k] != new[k]]
print(f'  Lost keys: {len(lost)} {lost[:5] if lost else ""}')
print(f'  Mutated values: {len(mutated)} {mutated[:5] if mutated else ""}')
print('  PASS' if not (lost or mutated) else '  FAIL')
PYINNER

echo ""
echo "==== F. fr/ar placeholders all empty ===="
for lang in fr ar; do
  echo "  -- app_${lang}.arb --"
  python3 - "$lang" << 'PYINNER'
import json, sys
lang = sys.argv[1]
arb = json.load(open(f'lib/l10n/app_{lang}.arb'))
new_keys = ["transactionErrorUserNotAuthenticated","transactionErrorPleaseLogInToSendMoney","transactionErrorRecipientWalletNotFound","transactionErrorInsufficientBalance","transactionErrorInvalidRequest","transactionErrorTransactionFailed","transactionErrorPaymentAlreadyProcessed","transactionErrorPaymentVerificationFailed","transactionErrorDepositFailed","transactionErrorFallback"]
missing = [k for k in new_keys if k not in arb]
non_empty = [k for k in new_keys if k in arb and arb[k] != ""]
print(f'    Missing: {len(missing)}')
print(f'    Non-empty: {len(non_empty)}')
PYINNER
done

echo ""
echo "==== G. confirm_send_screen.dart UI consumer migrated ===="
echo "  -- resolveTransactionResultError calls (expect 1) --"
grep -nE "resolveTransactionResultError" lib/features/send/screens/confirm_send_screen.dart
echo ""
echo "  -- transaction_localization_resolver import (expect 1) --"
grep -n "transaction_localization_resolver" lib/features/send/screens/confirm_send_screen.dart
echo ""
echo "  -- ZERO leftover 'Transaction failed' hardcoded fallback in result.error pattern --"
grep -nE "result\.error \?\? 'Transaction failed'" lib/features/send/screens/confirm_send_screen.dart && echo "FAIL — leftover fallback" || echo "PASS — no leftover"
echo ""
echo "  -- 'final loc = AppLocalizations' present in the migrated method (expect 1+) --"
grep -cE "final loc = AppLocalizations" lib/features/send/screens/confirm_send_screen.dart

echo ""
echo "==== H. debugPrint added for interpolation cases ===="
echo "Expect 2 new debugPrint calls in wallet_service.dart sendMoney + addMoney generic catches:"
grep -nE "debugPrint\('Transaction failed:|debugPrint\('Deposit failed:" lib/core/services/wallet_service.dart

echo ""
echo "==== I. Final commit ===="
git log -1 --stat HEAD | head -25
VERIFY_EOF

bash /tmp/cleanup4_c4_verify.sh
```

**Pass criteria:**
- A: 10 enum values, 2 resolver functions
- B: TransactionResult class shows 4-field shape with errorKey
- C: 1 import line for transaction_localization_resolver, 1 import line for foundation.dart
- D: 9 errorKey-using calls, 0 without errorKey
- E: +10 value, +10 meta, +20 total; 0 lost, 0 mutated
- F: 0 missing, 0 non-empty in fr/ar
- G: 1 resolver call in confirm_send_screen, 1 import, 0 leftover hardcoded fallback, ≥1 loc capture
- H: 2 debugPrint calls (one for sendMoney's catch, one for addMoney's catch)
- I: commit shows 6 source files

If any check fails, STOP and report.

---

## Step 8 — Commit on feature branch

```bash
git add lib/core/services/wallet_service.dart \
        lib/core/services/transaction_localization_resolver.dart \
        lib/features/send/screens/confirm_send_screen.dart \
        lib/l10n/app_en.arb \
        lib/l10n/app_fr.arb \
        lib/l10n/app_ar.arb

git commit -m "9.cleanup-4-C4: TransactionResult localization

- Add TransactionErrorKey enum (10 values: 6 send-flow + 3 deposit-flow + 1 fallback)
  and 2 resolver functions in new file
  lib/core/services/transaction_localization_resolver.dart
- TransactionResult gains errorKey: TransactionErrorKey? field alongside existing
  error: String? for backward compatibility (transitional duplication, collapsed in C.5)
- 9 service-layer TransactionResult.failure() sites in wallet_service.dart
  migrated to populate both error String and errorKey enum
- sendMoney FirebaseFunctionsException inline switch (5 cases) rewritten to
  populate both errorMessage and errorKey local variables in each branch;
  inline rather than extracted because the switch is used at exactly one site
- 2 generic-catch interpolation cases ('Transaction failed: \$e' and
  'Deposit failed: \$e') drop the technical interpolation from user-visible
  message; preserved in debugPrint for engineers (matches cleanup-3 / C.1 / C.2
  precedent)
- Server-provided messages (data['error'] as String?, e.message) preserved in
  the transitional error: String field per design decision 5
- 1 UI consumer migrated: confirm_send_screen.dart line 434
  ('result.error ?? \"Transaction failed\"' -> 'resolveTransactionResultError(loc, result)')
- Mandatory loc capture pattern enforced in the migrated method
- 10 new ARB keys added with @-metadata; fr/ar placeholders ready for Step 10
- Per-domain enum: TransactionErrorKey.userNotAuthenticated NOT reused from
  C.3's UserErrorKey.userNotAuthenticated (consistent with C.2's 'keep originals'
  decision)
- Note: addMoney method's TransactionResult.failure sites migrated despite
  zero current callers (dead code) for forward consistency

Fourth sub-batch of cleanup-4 (5 sub-batches total). BiometricResult, pure-UI
sweep, WalletException localization with catcher refactoring, and transitional
duplication collapse all deferred to C.5.
Predecessor: phase6-step9-cleanup-4-c3-complete @ 8f420afe."

git push -u origin cleanup-4-c4-transaction-result
```

**Do NOT push to main. Do NOT merge. Do NOT create the tag — the human reviewer does both after verification.**

---

## Verification checklist (for the human reviewer after the agent finishes)

```bash
cd ~/Development/Projects/qr_wallet
git fetch origin
git checkout cleanup-4-c4-transaction-result
git pull

flutter gen-l10n
git add lib/generated/l10n/
git commit --amend --no-edit

flutter analyze 2>&1 | tail -3
# Expected: 204 issues, 0 errors

bash /tmp/cleanup4_c4_verify.sh

flutter build apk --debug

# After all checks pass — and after confirming local main matches origin/main:
git fetch origin
local_main=$(git rev-parse main)
origin_main=$(git rev-parse origin/main)
if [ "$local_main" != "$origin_main" ]; then
  echo "FAIL — sync local main with origin/main before merging"
  exit 1
fi

git checkout main
git merge --ff-only cleanup-4-c4-transaction-result
git tag -a phase6-step9-cleanup-4-c4-complete -m "Phase 6 Step 9 cleanup-4 sub-batch C.4 complete — TransactionResult localization. TransactionResult.errorKey field added; 10 new ARB keys; 9 service-layer migrations + 1 UI consumer migration. BiometricResult, pure-UI sweep, WalletException, and transitional collapse all deferred to C.5. Predecessor: phase6-step9-cleanup-4-c3-complete @ 8f420afe."
git push origin main
git push origin phase6-step9-cleanup-4-c4-complete

git branch -D cleanup-4-c4-transaction-result
git push origin --delete cleanup-4-c4-transaction-result
```

---

## Out of scope — for C.5

- BiometricResult migration (~16 hardcoded sites in biometric_service.dart, plus 2-3 UI consumers in app_lock_screen, confirm_send_screen, profile_screen)
- Pure-UI hardcoded strings in `add_money_screen.dart`, `withdraw_screen.dart`, the rest of `confirm_send_screen.dart`, `scan_qr_screen.dart` (~15-20 sites)
- WalletException localization with catcher refactoring (zero `on WalletException catch` sites currently; need to rewrite generic `catch (e)` blocks to type-narrow first)
- `exchange_rate_service.dart` exception localization (4 sites)
- Removal of orphaned `failedToCompleteVerification` ARB key (unreferenced after C.3)
- Collapse of transitional `error: String` field on AuthResult, UserResult, TransactionResult once errorKey-based resolution is fully adopted everywhere

## End of C.4 spec
