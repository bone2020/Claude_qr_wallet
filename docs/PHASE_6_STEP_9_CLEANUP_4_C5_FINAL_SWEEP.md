# Phase 6 Step 9 — Cleanup-4 (Sub-batch C.5): BiometricResult + WalletException + Exchange Rate + UI Sweep + Orphan Cleanup

**Status:** READY TO IMPLEMENT
**Predecessor commit:** `c070c268` (cleanup-4 C.4)
**Predecessor tag (C.4):** `phase6-step9-cleanup-4-c4-complete` @ `c070c268`
**Target tag:** `phase6-step9-cleanup-4-c5-complete`

## Background

Final sub-batch of cleanup-4. Largest in scope by far — combines BiometricResult migration, WalletException migration with catcher refactoring (the architectural piece), exchange_rate_service exception localization, the wallet/send pure-UI sweep, and orphaned ARB key removal.

After C.5: cleanup-4 is fully done. Eric proceeds to Step 10 (fr/ar translations).

## Stage-based execution

C.5 is split into **7 stages** with verification gates between them. The agent runs each stage end-to-end, verifies, then proceeds. If any stage fails, work pauses at that stable point.

| Stage | Focus | Risk |
|---|---|---|
| 1 | ARB additions (32 keys) + 3 new resolver files | Low |
| 2 | BiometricResult migration + delete authenticateForX wrappers | Medium |
| 3 | WalletException migration in wallet_service.dart | Low |
| 4 | ExchangeRateException creation in exchange_rate_service.dart | Low |
| 5 | UI consumer migration (BiometricResult) + catcher refactoring | **High** |
| 6 | Pure-UI hardcoded string sweep | Low |
| 7 | Orphan ARB key removal | Trivial |

## Architectural decisions (locked)

1. **BiometricResult schema**: gains `errorKey: BiometricErrorKey?` (mirrors C.2/C.3/C.4 pattern). 10 enum values.
2. **WalletException schema**: gains both `walletErrorKey: WalletErrorKey?` AND `genericErrorKey: GenericErrorKey?` (cross-category — wallet-specific errors use the former; ErrorHandler-classified errors use the latter). 4 wallet enum values + reuses C.1's GenericErrorKey.
3. **ExchangeRateException is a NEW class** with `errorKey: ExchangeRateErrorKey?`. 2 enum values + 1 fallback. Mirrors WalletException shape.
4. **`authenticateForLogin/Transaction/Settings` wrappers DELETED.** UI consumers call `authenticate(reason: localizedString)` directly. The reason strings move to the call site where AppLocalizations is available.
5. **ICU placeholders** for 3 keys: `biometricReasonConfirmPayment` (currencySymbol, amount, recipient), `walletUiErrorAccountNumberTooShort` (minDigits), `exchangeRateErrorUnsupportedCurrencyPair` (from, to).
6. **Catcher refactoring is conservative**: only generic `catch (e)` blocks where a WalletException or ExchangeRateException can actually flow get the type-narrowed `on X catch (e)` branch. Spec lists each one explicitly per-file.
7. **Mandatory `loc` capture pattern** applied to every UI method touched.
8. **Interpolation drops** (`'Failed to lookup wallet: $e'` etc.) follow established cleanup-3/C.1/C.2/C.4 pattern: clean translated message + `debugPrint` for engineers.
9. **Transitional `error: String` field collapse is OUT OF SCOPE.** That's a separate hygiene cleanup. C.5 ships the user-visible localization complete.
10. **getBiometricTypeDescription() at L52-67 left untouched.** It's dead code (zero callers); migrating it would add 4 ARB keys for nothing. If reactivated later, migrate then.

## Scope summary

**~16 files:**
- `lib/core/services/biometric_service.dart` — schema + 11 sites + delete 3 wrapper methods
- `lib/core/services/biometric_localization_resolver.dart` — NEW
- `lib/core/services/wallet_service.dart` — WalletException schema + 4 site migrations
- `lib/core/services/wallet_localization_resolver.dart` — NEW
- `lib/core/services/exchange_rate_service.dart` — 4 throw site migrations + NEW ExchangeRateException class
- `lib/core/services/exchange_rate_localization_resolver.dart` — NEW
- `lib/providers/wallet_provider.dart` — catcher refactoring (3-5 sites)
- `lib/features/auth/screens/app_lock_screen.dart` — BiometricResult consumer
- `lib/features/profile/screens/profile_screen.dart` — BiometricResult consumer
- `lib/features/send/screens/confirm_send_screen.dart` — BiometricResult ICU + 2 onTimeout drops
- `lib/features/wallet/screens/add_money_screen.dart` — pure-UI sweep (4 sites)
- `lib/features/wallet/screens/withdraw_screen.dart` — pure-UI sweep (8 sites)
- `lib/features/send/screens/scan_qr_screen.dart` — pure-UI sweep (2 sites)
- `lib/l10n/app_en.arb` — +32 keys, -1 (orphan)
- `lib/l10n/app_fr.arb` — +32 placeholders, -1 (orphan)
- `lib/l10n/app_ar.arb` — +32 placeholders, -1 (orphan)

**Total string migrations:** ~50 (11 BiometricResult + 4 WalletException + 4 exchange_rate + 16 pure-UI + 3 reason strings + ~12 partial-migration cleanup if needed).

**Net ARB delta:** +32, -1 = +31 keys.

---

## Pre-flight check

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c5_preflight.sh << 'PREFLIGHT_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== Capture analyzer baseline (must match post-fix exactly) ===="
flutter analyze 2>&1 | tail -3

echo ""
echo "==== Sync guard ===="
git fetch origin
local_main=$(git rev-parse main)
origin_main=$(git rev-parse origin/main)
if [ "$local_main" != "$origin_main" ]; then
  echo "FAIL — local main and origin/main differ. Sync before proceeding."
  exit 1
fi
echo "PASS — local main matches origin/main at $local_main"

echo ""
echo "==== Confirm C.4 infrastructure is in place ===="
[ -f lib/core/services/transaction_localization_resolver.dart ] && echo "PASS: transaction_localization_resolver.dart exists" || echo "FAIL: missing"
grep -q "^enum TransactionErrorKey" lib/core/services/transaction_localization_resolver.dart && echo "PASS: TransactionErrorKey enum exists" || echo "FAIL: missing"
grep -q "^enum GenericErrorKey" lib/core/utils/error_handler_localization_resolver.dart && echo "PASS: C.1 GenericErrorKey enum exists" || echo "FAIL: missing"

echo ""
echo "==== Confirm C.5 target classes are unchanged ===="
grep -A6 "^class BiometricResult" lib/core/services/biometric_service.dart
echo ""
grep -A4 "^class WalletException" lib/core/services/wallet_service.dart

echo ""
echo "==== Confirm new resolver files do not yet exist ===="
[ -f lib/core/services/biometric_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "biometric: OK"
[ -f lib/core/services/wallet_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "wallet: OK"
[ -f lib/core/services/exchange_rate_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "exchange_rate: OK"

echo ""
echo "==== Working tree must be clean ===="
git status --short
PREFLIGHT_EOF

bash /tmp/cleanup4_c5_preflight.sh
```

**Expected:** analyzer at 204; local main matches origin/main at `c070c268`; C.4 infrastructure present; BiometricResult and WalletException classes unchanged; new resolver files don't exist yet; working tree clean.

---

# STAGE 1 — ARB additions + new resolver files

## 1.1 — Add 32 new keys to `lib/l10n/app_en.arb`

```bash
python3 << 'PYEOF'
import json

ARB_PATH = "lib/l10n/app_en.arb"

# Plain (non-ICU) keys — 29
PLAIN_KEYS = [
    # BiometricErrorKey enum (10 keys)
    ("biometricErrorNotAvailable",
     "Biometric authentication is not available",
     "Biometric authentication unavailable on this device (PlatformException 'NotAvailable')."),
    ("biometricErrorNotEnrolled",
     "No biometrics enrolled. Please set up fingerprint or face in device settings",
     "No biometrics enrolled (PlatformException 'NotEnrolled')."),
    ("biometricErrorLockedOut",
     "Too many failed attempts. Please try again later",
     "Biometric locked out due to repeated failures (PlatformException 'LockedOut')."),
    ("biometricErrorPermanentlyLockedOut",
     "Biometric authentication is locked. Please unlock your device first",
     "Biometric permanently locked (PlatformException 'PermanentlyLockedOut')."),
    ("biometricErrorPasscodeNotSet",
     "Please set up a device passcode to use biometric authentication",
     "Device passcode not set (PlatformException 'PasscodeNotSet')."),
    ("biometricErrorOtherOperatingSystem",
     "Biometric authentication is not supported on this device",
     "OS does not support biometric (PlatformException 'OtherOperatingSystem')."),
    ("biometricErrorAuthenticationFailed",
     "Authentication failed",
     "Generic biometric authentication failure — also default for unknown PlatformException codes."),
    ("biometricErrorNotSupported",
     "Biometric authentication not supported",
     "Shown when canCheckBiometrics returns false (early-return path before authenticate())."),
    ("biometricErrorNoBiometricsEnrolled",
     "No biometrics enrolled on this device",
     "Shown when getAvailableBiometrics returns empty (different code path from PlatformException NotEnrolled)."),
    ("biometricErrorFallback",
     "Couldn't authenticate. Please try again.",
     "Generic BiometricResult fallback when no specific case applies."),

    # BiometricReason (3 keys total — see ICU section for the placeholder one)
    ("biometricReasonAuthenticate",
     "Authenticate to access your QR Wallet",
     "Reason text shown in OS biometric prompt during app login."),
    ("biometricReasonChangeSecurity",
     "Authenticate to change security settings",
     "Reason text shown in OS biometric prompt when changing security settings."),

    # WalletErrorKey enum (4 keys)
    ("walletErrorTooManyRequests",
     "Too many requests. Please try again later.",
     "Wallet lookup throttled (Cloud Functions resource-exhausted)."),
    ("walletErrorFailedToLookupWallet",
     "Failed to look up wallet",
     "Wallet lookup failed for reasons other than throttling. Technical detail logged via debugPrint."),
    ("walletErrorFailedToFetchTransaction",
     "Failed to fetch transaction",
     "Transaction fetch failed. Technical detail logged via debugPrint."),
    ("walletErrorFallback",
     "Wallet operation failed. Please try again.",
     "Generic WalletException fallback when no specific case applies."),

    # ExchangeRateErrorKey enum (2 keys total — 1 plain + 1 ICU below)
    ("exchangeRateErrorUnsupportedCurrency",
     "Unsupported currency",
     "Exchange rate request for an unrecognized currency."),

    # Pure-UI keys (13 keys total — 12 plain + 1 ICU below)
    ("walletUiErrorUserNotFound",
     "User not found. Please log in again.",
     "Shown when add_money_screen detects no current user."),
    ("walletUiErrorPleaseSelectMomoProvider",
     "Please select a mobile money provider",
     "Validation message shown in add_money/withdraw screens."),
    ("walletUiErrorPaymentStillPending",
     "Payment still pending. Please check your phone and try again.",
     "Shown when momo polling times out without resolution."),
    ("walletUiErrorPleaseSelectBank",
     "Please select a bank",
     "Validation message shown in withdraw screen."),
    ("walletUiErrorPleaseVerifyAccount",
     "Please verify your account first",
     "Withdraw flow validation: account verification step required."),
    ("walletUiErrorPleaseEnterAccountName",
     "Please enter account name",
     "Validation message shown in withdraw screen."),
    ("walletUiErrorWithdrawalFailedRefunded",
     "Withdrawal failed. Your balance has been refunded.",
     "Shown when a withdrawal fails after balance was deducted; the refund is automatic."),
    ("walletUiErrorPleaseEnter6DigitOtp",
     "Please enter a valid 6-digit OTP",
     "OTP input validation in withdraw flow."),
    ("sendUiErrorCouldNotVerifyRecipientWallet",
     "Could not verify recipient wallet",
     "Shown when scan_qr fails to verify the recipient wallet."),
    ("sendUiErrorCouldNotReadQrCode",
     "Could not read QR code",
     "Shown when QR scanning fails."),
    ("sendUiErrorPreviewTimedOut",
     "Preview timed out",
     "Shown when send-preview fetch exceeds its timeout in confirm_send_screen."),
    ("sendUiErrorRequestTimedOut",
     "Request timed out. Please check your connection and try again.",
     "Shown when sendMoney exceeds its 30-second timeout in confirm_send_screen."),
]

# ICU-placeholder keys — 3
ICU_KEYS = [
    ("biometricReasonConfirmPayment",
     "Confirm payment of {currencySymbol}{amount} to {recipient}",
     "Reason text shown in OS biometric prompt when confirming a payment.",
     {
         "currencySymbol": {"type": "String"},
         "amount": {"type": "String"},
         "recipient": {"type": "String"},
     }),
    ("walletUiErrorAccountNumberTooShort",
     "Account number must be at least {minDigits} digits",
     "Withdraw flow validation: account number too short.",
     {
         "minDigits": {"type": "int"},
     }),
    ("exchangeRateErrorUnsupportedCurrencyPair",
     "Unsupported currency: {from} or {to}",
     "Exchange rate conversion involves at least one unrecognized currency.",
     {
         "from": {"type": "String"},
         "to": {"type": "String"},
     }),
]

assert len(PLAIN_KEYS) == 29, f"Expected 29 plain keys, got {len(PLAIN_KEYS)}"
assert len(ICU_KEYS) == 3, f"Expected 3 ICU keys, got {len(ICU_KEYS)}"

with open(ARB_PATH, "r", encoding="utf-8") as f:
    arb = json.load(f)

added = []
skipped = []

for key, value, description in PLAIN_KEYS:
    if key in arb:
        skipped.append(key)
        continue
    arb[key] = value
    arb[f"@{key}"] = {"description": description}
    added.append(key)

for key, value, description, placeholders in ICU_KEYS:
    if key in arb:
        skipped.append(key)
        continue
    arb[key] = value
    arb[f"@{key}"] = {"description": description, "placeholders": placeholders}
    added.append(key)

with open(ARB_PATH, "w", encoding="utf-8") as f:
    json.dump(arb, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Added {len(added)} keys (29 plain + 3 ICU)")
print(f"Skipped {len(skipped)} keys: {skipped}")
PYEOF
```

**Expected:** `Added 32 keys`, `Skipped 0 keys: []`.

## 1.2 — Add 32 placeholder keys to fr/ar

```bash
python3 << 'PYEOF'
import json

NEW_KEY_NAMES = [
    "biometricErrorNotAvailable", "biometricErrorNotEnrolled", "biometricErrorLockedOut",
    "biometricErrorPermanentlyLockedOut", "biometricErrorPasscodeNotSet",
    "biometricErrorOtherOperatingSystem", "biometricErrorAuthenticationFailed",
    "biometricErrorNotSupported", "biometricErrorNoBiometricsEnrolled", "biometricErrorFallback",
    "biometricReasonAuthenticate", "biometricReasonChangeSecurity", "biometricReasonConfirmPayment",
    "walletErrorTooManyRequests", "walletErrorFailedToLookupWallet",
    "walletErrorFailedToFetchTransaction", "walletErrorFallback",
    "exchangeRateErrorUnsupportedCurrency", "exchangeRateErrorUnsupportedCurrencyPair",
    "walletUiErrorUserNotFound", "walletUiErrorPleaseSelectMomoProvider",
    "walletUiErrorPaymentStillPending", "walletUiErrorPleaseSelectBank",
    "walletUiErrorAccountNumberTooShort", "walletUiErrorPleaseVerifyAccount",
    "walletUiErrorPleaseEnterAccountName", "walletUiErrorWithdrawalFailedRefunded",
    "walletUiErrorPleaseEnter6DigitOtp",
    "sendUiErrorCouldNotVerifyRecipientWallet", "sendUiErrorCouldNotReadQrCode",
    "sendUiErrorPreviewTimedOut", "sendUiErrorRequestTimedOut",
]

assert len(NEW_KEY_NAMES) == 32

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

**Expected:** both files report `added 32, skipped 0`.

## 1.3 — Create `lib/core/services/biometric_localization_resolver.dart`

```dart
import '../../generated/l10n/app_localizations.dart';
import 'biometric_service.dart';

/// Identifies the kind of biometric error carried by [BiometricResult.errorKey].
enum BiometricErrorKey {
  // PlatformException-derived (from _classifyPlatformException)
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  passcodeNotSet,
  otherOperatingSystem,
  authenticationFailed,

  // Service-layer (from BiometricResult.failure call sites)
  notSupported,
  noBiometricsEnrolled,

  // Catch-all
  fallback,
}

/// Resolves a [BiometricErrorKey] into a translated, user-visible message.
String resolveBiometricErrorMessage(AppLocalizations loc, BiometricErrorKey key) {
  return switch (key) {
    BiometricErrorKey.notAvailable => loc.biometricErrorNotAvailable,
    BiometricErrorKey.notEnrolled => loc.biometricErrorNotEnrolled,
    BiometricErrorKey.lockedOut => loc.biometricErrorLockedOut,
    BiometricErrorKey.permanentlyLockedOut => loc.biometricErrorPermanentlyLockedOut,
    BiometricErrorKey.passcodeNotSet => loc.biometricErrorPasscodeNotSet,
    BiometricErrorKey.otherOperatingSystem => loc.biometricErrorOtherOperatingSystem,
    BiometricErrorKey.authenticationFailed => loc.biometricErrorAuthenticationFailed,
    BiometricErrorKey.notSupported => loc.biometricErrorNotSupported,
    BiometricErrorKey.noBiometricsEnrolled => loc.biometricErrorNoBiometricsEnrolled,
    BiometricErrorKey.fallback => loc.biometricErrorFallback,
  };
}

/// One-line resolver for UI consumers.
String resolveBiometricResultError(AppLocalizations loc, BiometricResult result) {
  if (result.errorKey != null) {
    return resolveBiometricErrorMessage(loc, result.errorKey!);
  }
  return result.error ?? loc.biometricErrorFallback;
}
```

## 1.4 — Create `lib/core/services/wallet_localization_resolver.dart`

```dart
import '../../generated/l10n/app_localizations.dart';
import '../utils/error_handler_localization_resolver.dart';
import 'wallet_service.dart';

/// Wallet-specific error keys carried by [WalletException.walletErrorKey].
///
/// Cross-category note: WalletException can also carry a [GenericErrorKey] via
/// its [WalletException.genericErrorKey] field for ErrorHandler-classified
/// errors that don't have a specific wallet meaning.
enum WalletErrorKey {
  tooManyRequests,
  failedToLookupWallet,
  failedToFetchTransaction,
  fallback,
}

/// Resolves a [WalletErrorKey] into a translated, user-visible message.
String resolveWalletErrorMessage(AppLocalizations loc, WalletErrorKey key) {
  return switch (key) {
    WalletErrorKey.tooManyRequests => loc.walletErrorTooManyRequests,
    WalletErrorKey.failedToLookupWallet => loc.walletErrorFailedToLookupWallet,
    WalletErrorKey.failedToFetchTransaction => loc.walletErrorFailedToFetchTransaction,
    WalletErrorKey.fallback => loc.walletErrorFallback,
  };
}

/// One-line resolver for UI consumers catching a [WalletException].
///
/// Resolution priority:
///   1. walletErrorKey (specific wallet error)
///   2. genericErrorKey (ErrorHandler-classified error)
///   3. message String (transitional)
///   4. Generic wallet fallback
String resolveWalletExceptionError(AppLocalizations loc, WalletException e) {
  if (e.walletErrorKey != null) {
    return resolveWalletErrorMessage(loc, e.walletErrorKey!);
  }
  if (e.genericErrorKey != null) {
    return resolveGenericErrorMessage(loc, e.genericErrorKey!);
  }
  return e.message.isNotEmpty ? e.message : loc.walletErrorFallback;
}
```

## 1.5 — Create `lib/core/services/exchange_rate_localization_resolver.dart`

```dart
import '../../generated/l10n/app_localizations.dart';
import 'exchange_rate_service.dart';

enum ExchangeRateErrorKey {
  unsupportedCurrency,
  unsupportedCurrencyPair,
  fallback,
}

/// Resolves an [ExchangeRateErrorKey] into a translated message.
///
/// For [unsupportedCurrencyPair], the caller MUST supply [from] and [to] for
/// ICU placeholder substitution. For other variants those parameters are unused.
String resolveExchangeRateErrorMessage(
  AppLocalizations loc,
  ExchangeRateErrorKey key, {
  String from = '',
  String to = '',
}) {
  return switch (key) {
    ExchangeRateErrorKey.unsupportedCurrency => loc.exchangeRateErrorUnsupportedCurrency,
    ExchangeRateErrorKey.unsupportedCurrencyPair => loc.exchangeRateErrorUnsupportedCurrencyPair(from, to),
    ExchangeRateErrorKey.fallback => loc.exchangeRateErrorUnsupportedCurrency,
  };
}

/// One-line resolver for UI consumers catching an [ExchangeRateException].
String resolveExchangeRateExceptionError(AppLocalizations loc, ExchangeRateException e) {
  return resolveExchangeRateErrorMessage(
    loc,
    e.errorKey,
    from: e.from,
    to: e.to,
  );
}
```

## STAGE 1 verification

```bash
echo "==== Stage 1 verification ===="
echo "ARB delta (expect +32 value, +32 meta on en):"
python3 -c "
import json, subprocess
old = json.loads(subprocess.check_output(['git','show','phase6-step9-cleanup-4-c4-complete:lib/l10n/app_en.arb']))
new = json.load(open('lib/l10n/app_en.arb'))
v_old = sum(1 for k in old if not k.startswith(chr(64)))
m_old = sum(1 for k in old if k.startswith(chr(64)))
v_new = sum(1 for k in new if not k.startswith(chr(64)))
m_new = sum(1 for k in new if k.startswith(chr(64)))
print(f'  Value: {v_new - v_old} (expect +32)')
print(f'  Meta: {m_new - m_old} (expect +32)')
"
echo ""
echo "Three new resolver files exist:"
ls lib/core/services/*_localization_resolver.dart 2>/dev/null
echo ""
echo "Each has expected enum:"
grep -l "^enum BiometricErrorKey" lib/core/services/biometric_localization_resolver.dart && echo "PASS biometric"
grep -l "^enum WalletErrorKey" lib/core/services/wallet_localization_resolver.dart && echo "PASS wallet"
grep -l "^enum ExchangeRateErrorKey" lib/core/services/exchange_rate_localization_resolver.dart && echo "PASS exchange"
```

**Stop and report if any check fails before proceeding to Stage 2.**

---

# STAGE 2 — BiometricResult migration

## 2.1 — Edit `lib/core/services/biometric_service.dart`

Agent views the file in full first. Then:

### 2.1.a — Add resolver import + foundation.dart import

Check current imports. Add at the top of imports:
```dart
import 'package:flutter/foundation.dart';
import 'biometric_localization_resolver.dart';
```

(If `foundation.dart` already present, skip that line.)

### 2.1.b — Update `BiometricResult` class to add `errorKey` field

**Search:**
```dart
class BiometricResult {
  final bool success;
  final String? error;
  final bool cancelled;

  BiometricResult._({
    required this.success,
    this.error,
    this.cancelled = false,
  });

  factory BiometricResult.success() {
    return BiometricResult._(success: true);
  }

  factory BiometricResult.failure(String error) {
    return BiometricResult._(success: false, error: error);
  }

  factory BiometricResult.cancelled() {
    return BiometricResult._(success: false, cancelled: true);
  }
}
```

**Replace:**
```dart
class BiometricResult {
  final bool success;
  final String? error;
  final BiometricErrorKey? errorKey;
  final bool cancelled;

  BiometricResult._({
    required this.success,
    this.error,
    this.errorKey,
    this.cancelled = false,
  });

  factory BiometricResult.success() {
    return BiometricResult._(success: true);
  }

  factory BiometricResult.failure(String error, {BiometricErrorKey? errorKey}) {
    return BiometricResult._(success: false, error: error, errorKey: errorKey);
  }

  factory BiometricResult.cancelled() {
    return BiometricResult._(success: false, cancelled: true);
  }
}
```

### 2.1.c — Migrate the 4 `BiometricResult.failure` sites

| Line (approx) | Old | New |
|---|---|---|
| 83 | `return BiometricResult.failure('Biometric authentication not supported');` | `return BiometricResult.failure('Biometric authentication not supported', errorKey: BiometricErrorKey.notSupported);` |
| 88 | `return BiometricResult.failure('No biometrics enrolled on this device');` | `return BiometricResult.failure('No biometrics enrolled on this device', errorKey: BiometricErrorKey.noBiometricsEnrolled);` |
| 104 | `return BiometricResult.failure('Authentication failed');` | `return BiometricResult.failure('Authentication failed', errorKey: BiometricErrorKey.authenticationFailed);` |
| 109 | `return BiometricResult.failure('An error occurred: $e');` | (See below — interpolation drop with debugPrint) |

Site 109 special handling:

**Search:**
```dart
    } catch (e) {
      return BiometricResult.failure('An error occurred: $e');
    }
```

**Replace:**
```dart
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return BiometricResult.failure(
        'Authentication failed',
        errorKey: BiometricErrorKey.authenticationFailed,
      );
    }
```

### 2.1.d — Refactor `_getErrorMessage(PlatformException e)` into `_classifyPlatformException` + `_englishOf`

The existing `_getErrorMessage` at L155-174 is replaced with TWO helpers (mirrors C.2's `_getAuthErrorMessage` refactor pattern):

**Search:**
```dart
  /// Get user-friendly error message
  String _getErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available';
      case 'NotEnrolled':
        return 'No biometrics enrolled. Please set up fingerprint or face in device settings';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is locked. Please unlock your device first';
      case 'PasscodeNotSet':
        return 'Please set up a device passcode to use biometric authentication';
      case 'OtherOperatingSystem':
        return 'Biometric authentication is not supported on this device';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}
```

**Replace:**
```dart
  /// Maps a PlatformException code to a [BiometricErrorKey] enum value.
  BiometricErrorKey _classifyPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricErrorKey.notAvailable;
      case 'NotEnrolled':
        return BiometricErrorKey.notEnrolled;
      case 'LockedOut':
        return BiometricErrorKey.lockedOut;
      case 'PermanentlyLockedOut':
        return BiometricErrorKey.permanentlyLockedOut;
      case 'PasscodeNotSet':
        return BiometricErrorKey.passcodeNotSet;
      case 'OtherOperatingSystem':
        return BiometricErrorKey.otherOperatingSystem;
      default:
        return BiometricErrorKey.authenticationFailed;
    }
  }

  /// English fallback for the transitional [BiometricResult.error] String field.
  ///
  /// Kept in sync with [resolveBiometricErrorMessage]. Any English wording change
  /// must update BOTH this method AND the corresponding ARB key.
  String _englishOf(BiometricErrorKey key) {
    switch (key) {
      case BiometricErrorKey.notAvailable:
        return 'Biometric authentication is not available';
      case BiometricErrorKey.notEnrolled:
        return 'No biometrics enrolled. Please set up fingerprint or face in device settings';
      case BiometricErrorKey.lockedOut:
        return 'Too many failed attempts. Please try again later';
      case BiometricErrorKey.permanentlyLockedOut:
        return 'Biometric authentication is locked. Please unlock your device first';
      case BiometricErrorKey.passcodeNotSet:
        return 'Please set up a device passcode to use biometric authentication';
      case BiometricErrorKey.otherOperatingSystem:
        return 'Biometric authentication is not supported on this device';
      case BiometricErrorKey.authenticationFailed:
        return 'Authentication failed';
      case BiometricErrorKey.notSupported:
        return 'Biometric authentication not supported';
      case BiometricErrorKey.noBiometricsEnrolled:
        return 'No biometrics enrolled on this device';
      case BiometricErrorKey.fallback:
        return "Couldn't authenticate. Please try again.";
    }
  }
}
```

### 2.1.e — Update the PlatformException catch site to use new helpers

The `_getErrorMessage` method had ONE caller — find it (likely in the `authenticate` method's catch block).

```bash
grep -n "_getErrorMessage" lib/core/services/biometric_service.dart
```

Should now return zero matches (since the method is renamed). The single caller site needs migration:

**Search** (find this catch block via grep `on PlatformException catch`):
```dart
    } on PlatformException catch (e) {
      return BiometricResult.failure(_getErrorMessage(e));
    }
```

**Replace:**
```dart
    } on PlatformException catch (e) {
      final key = _classifyPlatformException(e);
      return BiometricResult.failure(
        e.message ?? _englishOf(key),
        errorKey: key,
      );
    }
```

The `e.message ?? _englishOf(key)` preserves the platform's own message when available (it might be more specific) but falls back to our localized English. The errorKey is set unconditionally.

### 2.1.f — Delete the 3 wrapper methods

Delete `authenticateForLogin`, `authenticateForTransaction`, and `authenticateForSettings`. UI consumers will be updated in Stage 5 to call `authenticate(reason: ...)` directly with localized reason.

**Search:**
```dart
  /// Authenticate for login
  Future<BiometricResult> authenticateForLogin() async {
    return authenticate(
      reason: 'Authenticate to access your QR Wallet',
      biometricOnly: false,
    );
  }

  /// Authenticate for transaction
  Future<BiometricResult> authenticateForTransaction({
    required double amount,
    required String recipient,
    String currencySymbol = '',
  }) async {
    return authenticate(
      reason: 'Confirm payment of $currencySymbol${amount.toStringAsFixed(2)} to $recipient',
    );
  }

  /// Authenticate for settings change
  Future<BiometricResult> authenticateForSettings() async {
    return authenticate(
      reason: 'Authenticate to change security settings',
    );
  }
```

**Replace:** (empty — agent passes empty string `""` as new_str via the str_replace tool to delete this block)

If the actual file has slight whitespace differences from the spec text, the agent must view the file first and use the exact text as `old_str`.

## STAGE 2 verification

```bash
echo "==== Stage 2 verification ===="
echo "BiometricResult schema:"
sed -n '/^class BiometricResult/,/^}$/p' lib/core/services/biometric_service.dart
echo ""
echo "All BiometricResult.failure sites have errorKey:"
python3 -c "
import re
content = open('lib/core/services/biometric_service.dart').read()
matches = list(re.finditer(r'BiometricResult\.failure\((.+?)\)\s*;', content, re.DOTALL))
total = len(matches)
with_key = sum(1 for m in matches if 'errorKey:' in m.group(1))
print(f'  Total: {total}, with errorKey: {with_key}, expected: 4 sites + 1 factory = 5 total, 4 with errorKey')
"
echo ""
echo "_classifyPlatformException + _englishOf present:"
grep -nE "^  BiometricErrorKey _classifyPlatformException\(|^  String _englishOf\(" lib/core/services/biometric_service.dart
echo ""
echo "_getErrorMessage gone:"
grep -n "_getErrorMessage" lib/core/services/biometric_service.dart && echo "FAIL" || echo "PASS"
echo ""
echo "Wrapper methods deleted:"
grep -nE "authenticateForLogin|authenticateForTransaction|authenticateForSettings" lib/core/services/biometric_service.dart && echo "FAIL — wrappers still present" || echo "PASS — all 3 wrappers deleted"
echo ""
echo "debugPrint added for interpolation drop:"
grep -nE "debugPrint\('Biometric authentication error:" lib/core/services/biometric_service.dart
```

**Stop and report if any check fails before proceeding to Stage 3.**

---

# STAGE 3 — WalletException migration

## 3.1 — Edit `lib/core/services/wallet_service.dart`

### 3.1.a — Add wallet_localization_resolver import

Add alongside existing imports (transaction_localization_resolver was added in C.4 — add wallet_localization_resolver right after):

**Search:**
```dart
import 'transaction_localization_resolver.dart';
```

**Replace:**
```dart
import 'transaction_localization_resolver.dart';
import 'wallet_localization_resolver.dart';
import '../utils/error_handler_localization_resolver.dart';
```

### 3.1.b — Update `WalletException` class

**Search:**
```dart
class WalletException implements Exception {
  final String message;

  WalletException(this.message);

  @override
  String toString() => message;
}
```

**Replace:**
```dart
class WalletException implements Exception {
  final String message;
  final WalletErrorKey? walletErrorKey;
  final GenericErrorKey? genericErrorKey;

  WalletException(this.message, {this.walletErrorKey, this.genericErrorKey});

  @override
  String toString() => message;
}
```

### 3.1.c — Migrate the 4 hardcoded throw sites

| Line (approx) | Old | New |
|---|---|---|
| 87 | `throw WalletException('Too many requests. Please try again later.');` | `throw WalletException('Too many requests. Please try again later.', walletErrorKey: WalletErrorKey.tooManyRequests);` |
| 89 | `throw WalletException('Failed to lookup wallet: ${e.message}');` | (interpolation drop — see below) |
| 91 | `throw WalletException('Failed to lookup wallet: $e');` | (interpolation drop — see below) |
| 421 | `throw WalletException('Failed to fetch transaction: $e');` | (interpolation drop — see below) |

For L89 and L91 (both interpolation), the pattern depends on the catch context. View lines 80-95:

**Search** (this block contains both L89 and L91 — agent confirms the exact text):
```dart
    } on FirebaseFunctionsException catch (e) {
      throw WalletException('Failed to lookup wallet: ${e.message}');
    } catch (e) {
      throw WalletException('Failed to lookup wallet: $e');
    }
```

**Replace:**
```dart
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Failed to lookup wallet (FirebaseFunctions): ${e.message}');
      throw WalletException(
        'Failed to look up wallet',
        walletErrorKey: WalletErrorKey.failedToLookupWallet,
      );
    } catch (e) {
      debugPrint('Failed to lookup wallet (generic): $e');
      throw WalletException(
        'Failed to look up wallet',
        walletErrorKey: WalletErrorKey.failedToLookupWallet,
      );
    }
```

For L421:

**Search:**
```dart
    } catch (e) {
      throw WalletException('Failed to fetch transaction: $e');
    }
```

**Replace:**
```dart
    } catch (e) {
      debugPrint('Failed to fetch transaction: $e');
      throw WalletException(
        'Failed to fetch transaction',
        walletErrorKey: WalletErrorKey.failedToFetchTransaction,
      );
    }
```

### 3.1.d — Migrate the 3 ErrorHandler-wrapped sites

L38, L346, L386 currently look like:
```dart
throw WalletException(ErrorHandler.getUserFriendlyMessage(e));
```

Migrate each to:
```dart
throw WalletException(
  ErrorHandler.getUserFriendlyMessage(e),
  genericErrorKey: ErrorHandler.classifyUserError(e),
);
```

Use `replace_all=true` if the exact string appears identically at all 3 sites; otherwise migrate per-site.

## STAGE 3 verification

```bash
echo "==== Stage 3 verification ===="
echo "WalletException schema:"
sed -n '/^class WalletException/,/^}$/p' lib/core/services/wallet_service.dart
echo ""
echo "All throw WalletException sites tagged:"
python3 -c "
import re
content = open('lib/core/services/wallet_service.dart').read()
throws = list(re.finditer(r'throw WalletException\((.+?)\);', content, re.DOTALL))
total = len(throws)
tagged = sum(1 for t in throws if 'walletErrorKey:' in t.group(1) or 'genericErrorKey:' in t.group(1))
print(f'  Total throw sites: {total}, tagged: {tagged} (expect 7 throws total + 1 constructor: throws=7, tagged=7)')
"
echo ""
echo "debugPrint additions for interpolation drops:"
grep -cE "debugPrint\('Failed to lookup wallet|debugPrint\('Failed to fetch transaction" lib/core/services/wallet_service.dart
echo "(expected: 3)"
```

**Stop and report if any check fails before proceeding to Stage 4.**

---

# STAGE 4 — ExchangeRateException + 4 throw migrations

## 4.1 — Edit `lib/core/services/exchange_rate_service.dart`

### 4.1.a — Add foundation import + create ExchangeRateException class

Add at top of imports:
```dart
import 'package:flutter/foundation.dart';
import 'exchange_rate_localization_resolver.dart';
```

At the bottom of the file, after the existing service class, add:

```dart
/// Exception thrown by ExchangeRateService for unsupported currencies.
class ExchangeRateException implements Exception {
  final String message;
  final ExchangeRateErrorKey errorKey;
  final String from;
  final String to;

  ExchangeRateException(
    this.message, {
    required this.errorKey,
    this.from = '',
    this.to = '',
  });

  @override
  String toString() => message;
}
```

### 4.1.b — Migrate the 4 throw sites

L112 and L135 (the 2 with currency-pair interpolation):

**Search** (each occurrence handled separately — view file first to confirm):
```dart
      throw Exception('Unsupported currency: $fromCurrency or $toCurrency');
```

**Replace:**
```dart
      throw ExchangeRateException(
        'Unsupported currency: $fromCurrency or $toCurrency',
        errorKey: ExchangeRateErrorKey.unsupportedCurrencyPair,
        from: fromCurrency,
        to: toCurrency,
      );
```

(Use `replace_all=true` if both L112 and L135 have identical text.)

L149 and L168 (the 2 generic ones):

**Search:**
```dart
      throw Exception('Unsupported currency');
```

**Replace:**
```dart
      throw ExchangeRateException(
        'Unsupported currency',
        errorKey: ExchangeRateErrorKey.unsupportedCurrency,
      );
```

(Use `replace_all=true` for both.)

## STAGE 4 verification

```bash
echo "==== Stage 4 verification ===="
echo "ExchangeRateException class exists:"
grep -A6 "^class ExchangeRateException" lib/core/services/exchange_rate_service.dart
echo ""
echo "All 4 throws migrated:"
echo "  -- ExchangeRateException throws (expect 4) --"
grep -cE "throw ExchangeRateException\(" lib/core/services/exchange_rate_service.dart
echo "  -- Generic throw Exception('Unsupported currency') (expect 0) --"
grep -cE "throw Exception\('Unsupported currency" lib/core/services/exchange_rate_service.dart
```

---

# STAGE 5 — UI consumer migration + catcher refactoring (HIGHEST RISK)

This stage has the architectural piece. Agent works carefully here.

## 5.1 — `lib/providers/wallet_provider.dart` catcher refactoring

The agent views the file in full. Then identifies which `catch (e)` blocks could catch a WalletException.

**The wallet_service methods that throw WalletException:**
- `lookupWallet` (throws at L87, L89, L91)
- `getWallet` (throws via ErrorHandler at L38)
- `getTransactions` / methods around L346, L386 (throws via ErrorHandler)
- `getTransaction` (throws at L421)
- `loadMoreTransactions` (likely throws via ErrorHandler at L386)

**Catches in wallet_provider.dart that could catch WalletException** (agent confirms by tracing each):

| Line (approx) | Method | Calls | Refactor needed? |
|---|---|---|---|
| 92 area | watchWallet stream onError | watchWallet emits Stream — onError callback handles errors | YES |
| 119 try/catch | getWallet | calls _walletService.getWallet() | YES |
| 267 area | watchTransactions stream onError | YES |
| 292 try/catch | getTransactions | calls _walletService.getTransactions() | YES |
| 315 try/catch | loadMoreTransactions | calls _walletService.loadMoreTransactions() | YES |
| 459 try/catch | lookupWallet (in some method) | calls _walletService.lookupWallet() | YES |

**For each catch block, the refactor pattern is:**

**Before:**
```dart
} catch (e) {
  // existing handling
  state = state.copyWith(error: ErrorHandler.getUserFriendlyMessage(e));
}
```

**After:**
```dart
} on WalletException catch (we) {
  state = state.copyWith(
    error: we.message,
    walletException: we,
  );
} catch (e) {
  // existing handling unchanged
  state = state.copyWith(error: ErrorHandler.getUserFriendlyMessage(e));
}
```

**HOWEVER** — the wallet_provider state shape may not have a `walletException` field. The agent investigates the existing state class first.

**Simpler conservative refactor pattern** that doesn't require state shape changes:

**Before:**
```dart
} catch (e) {
  state = state.copyWith(error: ErrorHandler.getUserFriendlyMessage(e));
}
```

**After:**
```dart
} on WalletException catch (we) {
  state = state.copyWith(error: we.message);
} catch (e) {
  state = state.copyWith(error: ErrorHandler.getUserFriendlyMessage(e));
}
```

The `we.message` already contains an English-localized message (from the throw site). UI consumers reading `state.error` see localized text once Step 10 fills the fr/ar values, BECAUSE the WalletException message is constructed from the resolver chain in Stage 3.

**Wait — but state.error is just a String.** For the WalletException's errorKey to actually translate to user-locale text, the UI consumer needs access to the WalletException itself (or at least its errorKey).

**Agent investigates whether wallet_provider state carries enough info** for UI to translate. If not, a follow-up cleanup is needed (out of scope for C.5).

**For C.5 conservative approach:** Just add the type-narrowed catch. The walletException is constructed with English `message` for now — UI sees English. The proper localization comes from C.5.5 below where UI screens that DIRECTLY catch can use `resolveWalletExceptionError(loc, we)`.

**Actually, the cleanest approach is:** the catcher refactoring in wallet_provider is mostly mechanical (add `on WalletException catch` branches) but the LOCALIZATION happens at UI level.

If a UI screen catches via `catch (e)` and the wallet_provider state error already contains the WalletException's message (English), users see English until the UI can resolve via the errorKey. To do that translation in UI, the wallet_provider state needs to carry the WalletException itself, OR the UI needs to catch directly.

**For C.5 minimal-risk approach:** skip catcher refactoring in wallet_provider entirely if it requires state shape changes. Document as known follow-up. The architectural piece is then much smaller — only the throw-site localization in wallet_service is done.

**REVISED STAGE 5 SCOPE (lower risk):** the agent should report back after viewing wallet_provider.dart's state shape. Two options:

**Option α (state shape allows it):** wallet_provider state has a way to carry walletException or walletErrorKey. Refactor catches as described.

**Option β (state shape doesn't easily support it):** add type-narrowed catch to wallet_provider but only update `state.error` with `we.message` (still English for now). Document the localization gap as known follow-up.

**Default to Option β if uncertain.** The architectural piece's full localization can be a Phase 6.1 cleanup.

## 5.2 — BiometricResult UI consumers

### app_lock_screen.dart

The agent views around L162. The current code:
```dart
final result = await _biometricService.authenticateForLogin();
```

becomes:
```dart
final loc = AppLocalizations.of(context);
// ...
final result = await _biometricService.authenticate(
  reason: loc.biometricReasonAuthenticate,
  biometricOnly: false,
);
```

(Note `biometricOnly: false` was set inside `authenticateForLogin`, agent preserves this.)

The agent verifies AppLocalizations is imported, applies mandatory loc capture rule.

If `result.error` is read anywhere downstream, switch to `resolveBiometricResultError(loc, result)`.

### confirm_send_screen.dart

The agent views around L387-400. Current:
```dart
final biometricService = BiometricService();
final authResult = await biometricService.authenticateForTransaction(
  amount: ...,
  recipient: ...,
  currencySymbol: ...,
);
```

becomes:
```dart
final biometricService = BiometricService();
final loc = AppLocalizations.of(context); // capture before await if not already
final authResult = await biometricService.authenticate(
  reason: loc.biometricReasonConfirmPayment(currencySymbol, amount.toStringAsFixed(2), recipient),
);
```

The exact existing variable names for amount/recipient/currencySymbol must be discovered by agent viewing the actual file.

### profile_screen.dart

The agent views around L390-395. Current:
```dart
final bioService = BiometricService();
// ... probably calls bioService.authenticateForSettings() somewhere
```

The exact location of the `authenticateForSettings()` call needs to be located via grep:
```bash
grep -n "authenticateForSettings\|bioService\.authenticate\|BiometricService" lib/features/profile/screens/profile_screen.dart
```

Migration: replace with `bioService.authenticate(reason: loc.biometricReasonChangeSecurity)`.

## STAGE 5 verification

```bash
echo "==== Stage 5 verification ===="
echo "wallet_provider.dart 'on WalletException catch' branches added:"
grep -cE "on WalletException catch" lib/providers/wallet_provider.dart
echo ""
echo "BiometricService wrapper method calls (expect ZERO — all migrated to authenticate(reason:)):"
grep -rnE "authenticateForLogin\(|authenticateForTransaction\(|authenticateForSettings\(" lib/ --include="*.dart" | grep -v biometric_service.dart
echo "(no output = PASS)"
echo ""
echo "biometricReason* usages in UI:"
grep -rnE "loc\.biometricReason|biometricReasonAuthenticate|biometricReasonConfirmPayment|biometricReasonChangeSecurity" lib/features/ --include="*.dart"
```

**STOP if any check fails. The architectural piece is the highest-risk part — verify carefully.**

---

# STAGE 6 — Pure-UI hardcoded string sweep

For each file, agent views, applies mandatory loc capture rule, and migrates per the table.

## 6.1 — add_money_screen.dart (4 sites)

Add import:
```dart
// already imported, no addition needed
```

| Line (approx) | Old | New |
|---|---|---|
| 171, 223 (duplicate) | `_showError('User not found. Please log in again.');` | `_showError(loc.walletUiErrorUserNotFound);` (use replace_all=true) |
| 214 | `_showError('Please select a mobile money provider');` | `_showError(loc.walletUiErrorPleaseSelectMomoProvider);` |
| 331 | `_showError('Payment still pending. Please check your phone and try again.');` | `_showError(loc.walletUiErrorPaymentStillPending);` |

## 6.2 — withdraw_screen.dart (8 sites)

| Line (approx) | Old | New |
|---|---|---|
| 203, 264 (duplicate) | `_showError('Please select a bank');` | `_showError(loc.walletUiErrorPleaseSelectBank);` (replace_all=true) |
| 209 | `_showError('Account number must be at least $_minDigitsToVerify digits');` | `_showError(loc.walletUiErrorAccountNumberTooShort(_minDigitsToVerify));` |
| 268 | `_showError('Please verify your account first');` | `_showError(loc.walletUiErrorPleaseVerifyAccount);` |
| 273 | `_showError('Please select a mobile money provider');` | `_showError(loc.walletUiErrorPleaseSelectMomoProvider);` |
| 277 | `_showError('Please enter account name');` | `_showError(loc.walletUiErrorPleaseEnterAccountName);` |
| 330 | `_showError('Withdrawal failed. Your balance has been refunded.');` | `_showError(loc.walletUiErrorWithdrawalFailedRefunded);` |
| 451 | `_showError('Please enter a valid 6-digit OTP');` | `_showError(loc.walletUiErrorPleaseEnter6DigitOtp);` |

## 6.3 — scan_qr_screen.dart (2 sites)

| Line (approx) | Old | New |
|---|---|---|
| 135 | `_showError('Could not verify recipient wallet');` | `_showError(loc.sendUiErrorCouldNotVerifyRecipientWallet);` |
| 160 | `_showError('Could not read QR code');` | `_showError(loc.sendUiErrorCouldNotReadQrCode);` |

## 6.4 — confirm_send_screen.dart (2 sites — onTimeout exceptions)

| Line (approx) | Old | New |
|---|---|---|
| 174 | `onTimeout: () => throw Exception('Preview timed out'),` | `onTimeout: () => throw Exception(loc.sendUiErrorPreviewTimedOut),` |
| 421 | `onTimeout: () => throw Exception('Request timed out. Please check your connection and try again.'),` | `onTimeout: () => throw Exception(loc.sendUiErrorRequestTimedOut),` |

## STAGE 6 verification

```bash
echo "==== Stage 6 verification ===="
echo "ZERO leftover hardcoded English in pure-UI patterns:"
fail=0
for f in lib/features/wallet/screens/add_money_screen.dart lib/features/wallet/screens/withdraw_screen.dart lib/features/send/screens/scan_qr_screen.dart; do
  hits=$(grep -nE "_showError\('[A-Z]" "$f")
  if [ -n "$hits" ]; then fail=1; echo "FAIL — $f:"; echo "$hits"; fi
done
[ $fail -eq 0 ] && echo "PASS — no leftover hardcoded English"
echo ""
echo "confirm_send_screen onTimeout migration:"
grep -nE "loc\.sendUiErrorPreviewTimedOut|loc\.sendUiErrorRequestTimedOut" lib/features/send/screens/confirm_send_screen.dart
```

---

# STAGE 7 — Orphan ARB key removal

```bash
python3 << 'PYEOF'
import json

ORPHAN = "failedToCompleteVerification"

for arb_path in ["lib/l10n/app_en.arb", "lib/l10n/app_fr.arb", "lib/l10n/app_ar.arb"]:
    with open(arb_path, "r", encoding="utf-8") as f:
        arb = json.load(f)
    removed = 0
    if ORPHAN in arb:
        del arb[ORPHAN]
        removed += 1
    if f"@{ORPHAN}" in arb:
        del arb[f"@{ORPHAN}"]
        removed += 1
    with open(arb_path, "w", encoding="utf-8") as f:
        json.dump(arb, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{arb_path}: removed {removed} entries")
PYEOF
```

**Expected:** each ARB file reports `removed 2 entries` (the value key + the @-metadata key).

## STAGE 7 verification

```bash
echo "==== Stage 7 verification ===="
echo "failedToCompleteVerification orphan removal (expect ZERO references in lib/):"
grep -rn "failedToCompleteVerification" lib/ --include="*.arb"
echo "(no output above = PASS)"
echo ""
grep -rn "failedToCompleteVerification" lib/ --include="*.dart" | grep -v "lib/generated/" 
echo "(no output above = PASS — generated files are regenerated by gen-l10n)"
```

---

# Final verification (all stages)

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c5_final_verify.sh << 'VERIFY_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== ARB integrity vs C.4 baseline ===="
git show phase6-step9-cleanup-4-c4-complete:lib/l10n/app_en.arb 2>/dev/null | python3 -c "
import json, sys
arb = json.load(sys.stdin)
v = sum(1 for k in arb if not k.startswith(chr(64)))
m = sum(1 for k in arb if k.startswith(chr(64)))
print(f'Pre-C.5 baseline: total={len(arb)}, value={v}, meta={m}')
"
python3 -c "
import json
arb = json.load(open('lib/l10n/app_en.arb'))
v = sum(1 for k in arb if not k.startswith(chr(64)))
m = sum(1 for k in arb if k.startswith(chr(64)))
print(f'Post-C.5: total={len(arb)}, value={v}, meta={m}')
"
echo "(Difference: +32 - 1 = +31 value, +31 meta, +62 total)"
echo ""
echo "Resolver files exist:"
ls lib/core/services/biometric_localization_resolver.dart \
   lib/core/services/wallet_localization_resolver.dart \
   lib/core/services/exchange_rate_localization_resolver.dart 2>/dev/null
echo ""
echo "Schema migrations:"
echo "  BiometricResult has errorKey:" 
grep -c "BiometricErrorKey?" lib/core/services/biometric_service.dart
echo "  WalletException has walletErrorKey + genericErrorKey:"
grep -c "walletErrorKey\|genericErrorKey" lib/core/services/wallet_service.dart
echo "  ExchangeRateException class exists:"
grep -c "^class ExchangeRateException" lib/core/services/exchange_rate_service.dart
echo ""
echo "BiometricService wrapper methods deleted (expect ZERO):"
grep -cE "authenticateForLogin\(|authenticateForTransaction\(|authenticateForSettings\(" lib/core/services/biometric_service.dart
echo ""
echo "All wrapper-method callers migrated:"
grep -rnE "authenticateForLogin\(|authenticateForTransaction\(|authenticateForSettings\(" lib/ --include="*.dart" | grep -v biometric_service.dart
echo "(no output = PASS)"
echo ""
echo "Orphan ARB key removed:"
grep -c "failedToCompleteVerification" lib/l10n/app_en.arb
echo "(0 = PASS)"
echo ""
echo "Pure-UI sweep complete:"
for f in lib/features/wallet/screens/add_money_screen.dart lib/features/wallet/screens/withdraw_screen.dart lib/features/send/screens/scan_qr_screen.dart; do
  count=$(grep -cE "_showError\('[A-Z]" "$f")
  echo "  $(basename $f): $count leftover hardcoded (expect 0)"
done
echo ""
echo "Final commit:"
git log -1 --stat HEAD | head -25
VERIFY_EOF

bash /tmp/cleanup4_c5_final_verify.sh
```

---

# STAGE 8 — Commit on feature branch

```bash
git add lib/core/services/biometric_service.dart \
        lib/core/services/biometric_localization_resolver.dart \
        lib/core/services/wallet_service.dart \
        lib/core/services/wallet_localization_resolver.dart \
        lib/core/services/exchange_rate_service.dart \
        lib/core/services/exchange_rate_localization_resolver.dart \
        lib/providers/wallet_provider.dart \
        lib/features/auth/screens/app_lock_screen.dart \
        lib/features/profile/screens/profile_screen.dart \
        lib/features/send/screens/confirm_send_screen.dart \
        lib/features/wallet/screens/add_money_screen.dart \
        lib/features/wallet/screens/withdraw_screen.dart \
        lib/features/send/screens/scan_qr_screen.dart \
        lib/l10n/app_en.arb \
        lib/l10n/app_fr.arb \
        lib/l10n/app_ar.arb

git commit -m "9.cleanup-4-C5: BiometricResult + WalletException + exchange rate + UI sweep + orphan cleanup

Final cleanup-4 sub-batch. Closes the user-visible localization scope.

- BiometricResult migration: errorKey field (10 enum values), _classifyPlatformException
  + _englishOf helpers replace _getErrorMessage; 4 .failure sites tagged; interpolation
  drop with debugPrint at L109; authenticateForLogin/Transaction/Settings wrappers
  DELETED in favor of authenticate(reason:) called directly with localized reason
- WalletException migration: walletErrorKey + genericErrorKey fields; 4 hardcoded
  throw sites tagged with walletErrorKey; 3 ErrorHandler-wrapped throws also tagged
  with genericErrorKey from ErrorHandler.classifyUserError; interpolation drops with
  debugPrint at lookup/fetch sites
- exchange_rate_service: NEW ExchangeRateException class with errorKey + ICU-aware
  from/to fields; 4 throw sites migrated
- WalletException catcher refactoring in wallet_provider.dart: type-narrowed
  on WalletException catch branches added (Option β path — state.error gets the
  English message for now; full per-key UI translation is a Phase 6.1 follow-up)
- 3 BiometricResult UI consumers migrated to authenticate(reason: localized):
  app_lock_screen, confirm_send_screen, profile_screen; ICU placeholder used for
  biometricReasonConfirmPayment with currencySymbol, amount, recipient
- Pure-UI sweep across wallet/send screens: 16 hardcoded sites migrated
  (add_money: 4, withdraw: 8, scan_qr: 2, confirm_send onTimeout: 2);
  walletUiErrorAccountNumberTooShort uses ICU placeholder for minDigits
- 32 new ARB keys added (29 plain + 3 ICU); 1 orphan removed
  (failedToCompleteVerification — unreferenced after C.3 migration);
  net delta +31
- Mandatory loc capture pattern enforced across all touched UI methods

Fifth and final sub-batch of cleanup-4. Predecessor:
phase6-step9-cleanup-4-c4-complete @ c070c268.

Out of scope (post-Phase 6 hygiene):
- Transitional 'error: String' field collapse on AuthResult/UserResult/
  TransactionResult/BiometricResult
- Full per-key WalletException UI translation (currently English via we.message)
- BiometricService.getBiometricTypeDescription() — dead code, untouched"

git push -u origin cleanup-4-c5-biometric-wallet-exchange-and-ui-sweep
```

**Do NOT push to main. Do NOT merge. Do NOT create the tag — the human reviewer does both after verification.**

---

## Verification checklist (for the human reviewer after the agent finishes)

```bash
cd ~/Development/Projects/qr_wallet
git fetch origin
git checkout cleanup-4-c5-biometric-wallet-exchange-and-ui-sweep
git pull

flutter gen-l10n
git add lib/generated/l10n/
git commit --amend --no-edit

flutter analyze 2>&1 | tail -3
# Expected: 204 issues, 0 errors

bash /tmp/cleanup4_c5_final_verify.sh

flutter build apk --debug

# After all checks pass — sync guard before merging:
git fetch origin
local_main=$(git rev-parse main)
origin_main=$(git rev-parse origin/main)
if [ "$local_main" != "$origin_main" ]; then
  echo "FAIL — sync local main with origin/main before merging"
  exit 1
fi

git checkout main
git merge --ff-only cleanup-4-c5-biometric-wallet-exchange-and-ui-sweep
git tag -a phase6-step9-cleanup-4-c5-complete -m "Phase 6 Step 9 cleanup-4 sub-batch C.5 complete — final cleanup-4 sub-batch. BiometricResult + WalletException + exchange_rate localization + pure-UI sweep + orphan removal. ~50 string migrations, 32 new ARB keys (-1 orphan), 16 files. Predecessor: phase6-step9-cleanup-4-c4-complete @ c070c268. Cleanup-4 series complete; Phase 6 Step 9 epic complete; ready for Step 10 (fr/ar translations)."
git push origin main
git push origin phase6-step9-cleanup-4-c5-complete

git branch -D cleanup-4-c5-biometric-wallet-exchange-and-ui-sweep
git push origin --delete cleanup-4-c5-biometric-wallet-exchange-and-ui-sweep
```

## End of C.5 spec
