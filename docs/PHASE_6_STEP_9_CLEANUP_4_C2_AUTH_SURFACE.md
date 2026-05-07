# Phase 6 Step 9 — Cleanup-4 (Sub-batch C.2): Auth Surface Localization

**Status:** READY TO IMPLEMENT
**Companion to:** `docs/PHASE_6_LOCALIZATION_SPEC.md`, `docs/PHASE_6_STEP_9_CLEANUP_4_C1_ERROR_HANDLER_INFRASTRUCTURE.md`
**Predecessor tag:** `phase6-step9-cleanup-4-c1-complete` @ `7118001c`
**Target tag:** `phase6-step9-cleanup-4-c2-complete`

## Background

Cleanup-4 sub-batch C.1 shipped the ErrorHandler infrastructure. **C.2 is the first consumer migration sub-batch** — the auth surface.

C.2 covers:
- 13 hardcoded `AuthResult.failure('English string')` calls in `auth_service.dart`
- The 11-case `_getAuthErrorMessage(String code)` private helper in `auth_service.dart` (which translates Firebase Auth error codes into English messages)
- 1 hardcoded `AuthResult.failure('English string')` in `auth_provider.dart` (line 281)
- 9 `result.error ?? 'English fallback'` consumption sites across 6 auth UI screens (sign-up, login, forgot-password, OTP verification, phone OTP, KYC phone verification)

Total: **24 hardcoded English strings migrated to ARB** (13 service-layer + 11 Firebase-code), **23 new ARB keys**, and **6 UI screens migrated to consume the new errorKey field** instead of the existing `error` String.

After C.2: when a French- or Arabic-locale user fails to sign in, sees a Firebase auth error, or hits any auth-related error path, they'll see translated text (once Step 10 fills the fr/ar values). The English `error` String field stays populated alongside the new `errorKey` for backward compatibility — C.5 will collapse the duplication after all sub-batches ship.

## Architectural decisions (locked)

1. **Single unified `AuthErrorKey` enum.** Per Q1 confirmation, we use simple nullable fields rather than sealed types. To keep the result class to one new field, we collapse what could have been two enums (one for service-layer errors, one for Firebase auth codes) into a single enum with 23 values, organized into two comment-separated groups. One field on AuthResult, one resolver function, one switch.
2. **No reuse of C.1's `firebaseAuthError*` ARB keys.** Per Q2 confirmation, we keep auth_service's existing wordings rather than the slightly more polished C.1 wordings. 11 new ARB keys are added for the 11 Firebase code mappings, even where wordings are nearly identical to C.1's.
3. **Drop the technical interpolation from "Apple sign in failed: ${e.message}".** Same pattern as cleanup-3 (`'Failed to parse result: $e'`) and C.1 (parse-error message): user sees a clean message, technical detail goes to `debugPrint` for engineers.
4. **`_getAuthErrorMessage` is deleted.** It is private (`_` prefix) and we control all 11 of its callsites. Replaced by two new private helpers: `_classifyAuthCode(code) → AuthErrorKey` (the dispatcher) and `_englishOf(key) → String` (the transitional English fallback table for the existing `error` String field). One additional caller helper `_failureFromAuthCode(code) → AuthResult` for compactness.
5. **`AuthResult.failure` factory gets an optional `errorKey` parameter.** Existing String-only callers continue to work unchanged. New callers pass both. This is backward-compatible — `auth_provider.dart`'s line 281 only needs to add the `errorKey:` parameter.
6. **UI screens drop their hardcoded English fallback strings.** The new resolver helper `resolveAuthResultError(loc, result)` always returns a String — UI consumers don't need a `??` fallback anymore. **Net effect: 9 hardcoded English fallback strings deleted from UI without adding any new ARB keys for them.**
7. **`sendOtp`'s `onError(String)` callback signature is preserved.** The internal call to `_getAuthErrorMessage` at line 282 is rewritten to use the new helpers but still produces a String for the callback. Callers of `sendOtp` (TBD per pre-flight) are not affected.

## Scope summary

- **1 file edited extensively:** `lib/core/services/auth_service.dart` — schema change to `AuthResult` + 13 string-site migrations + delete `_getAuthErrorMessage` + add 3 new private helpers
- **1 new file:** `lib/core/services/auth_localization_resolver.dart` — `AuthErrorKey` enum (23 values) + `resolveAuthErrorMessage` + `resolveAuthResultError` orchestrator
- **1 file edited (1 site):** `lib/providers/auth_provider.dart` — line 281 migration
- **6 UI files edited (1-3 sites each):**
  - `lib/features/auth/screens/sign_up_screen.dart` (2 sites)
  - `lib/features/auth/screens/login_screen.dart` (3 sites)
  - `lib/features/auth/screens/forgot_password_screen.dart` (1 site)
  - `lib/features/auth/screens/otp_verification_screen.dart` (1 site)
  - `lib/features/auth/screens/phone_otp_screen.dart` (1 site)
  - `lib/features/auth/screens/kyc/phone_verification_screen.dart` (1 site)
- **3 ARB files modified:** `app_en.arb` (23 new keys with @-metadata), `app_fr.arb` and `app_ar.arb` (23 placeholders each)

**File count: 12.** Same league as cleanup-3 (11 files) and C.1 (5 files; smaller because pure infrastructure).

## Pre-flight check

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c2_preflight.sh << 'PREFLIGHT_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== Capture analyzer baseline (must match post-fix exactly) ===="
flutter analyze 2>&1 | tail -3

echo ""
echo "==== Confirm origin/main is at C.1 complete (commit 7118001c) ===="
git fetch origin
git rev-parse origin/main

echo ""
echo "==== Confirm C.1 infrastructure is in place ===="
[ -f lib/core/utils/error_handler_localization_resolver.dart ] && echo "PASS: error_handler_localization_resolver.dart exists" || echo "FAIL: missing"
grep -nE "^enum FirebaseAuthErrorKey" lib/core/utils/error_handler_localization_resolver.dart && echo "PASS: FirebaseAuthErrorKey enum exists" || echo "FAIL: missing"

echo ""
echo "==== Confirm C.2 target file is unchanged (auth_service.dart still has AuthResult class with no errorKey) ===="
grep -A6 "^class AuthResult" lib/core/services/auth_service.dart

echo ""
echo "==== Confirm new resolver file does not yet exist ===="
[ -f lib/core/services/auth_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "Does not exist yet — OK"

echo ""
echo "==== Find sendOtp callers (informational; needed to know if onError signature is constrained) ===="
grep -rn "\.sendOtp\(" lib/ --include="*.dart"

echo ""
echo "==== Working tree must be clean ===="
git status --short
PREFLIGHT_EOF

bash /tmp/cleanup4_c2_preflight.sh
```

**Expected:** analyzer at 204 issues; origin/main at `7118001c`; C.1 resolver file exists with FirebaseAuthErrorKey enum present; AuthResult class shows the existing 4-field shape (`success`, `user`, `error`, `isNewUser`) without errorKey; new resolver file does not yet exist; working tree clean.

The `sendOtp` caller grep is informational — confirm we don't need to update any UI screens for sendOtp's callback signature.

---

## Step 1 — Add 23 new keys to `lib/l10n/app_en.arb`

```bash
python3 << 'PYEOF'
import json

ARB_PATH = "lib/l10n/app_en.arb"

NEW_KEYS = [
    # Service-layer auth errors (12 keys; AuthErrorKey.fallback uses authErrorFallback below)
    ("authErrorFailedToCreateUser",
     "Failed to create user",
     "Shown when account creation fails after Firebase auth succeeds (e.g. Firestore write fails)."),
    ("authErrorFailedToSignIn",
     "Failed to sign in",
     "Shown when sign-in completes without throwing but returns a null user."),
    ("authErrorUserDataNotFound",
     "User data not found",
     "Shown when Firebase auth succeeds but the user's Firestore document is missing."),
    ("authErrorGoogleSignInCancelled",
     "Google sign in cancelled",
     "Shown when the user cancels the Google sign-in flow."),
    ("authErrorFailedToSignInWithGoogle",
     "Failed to sign in with Google",
     "Shown when Google sign-in fails for an unspecified reason."),
    ("authErrorFailedToSignInWithApple",
     "Failed to sign in with Apple",
     "Shown when Apple sign-in fails for an unspecified reason."),
    ("authErrorAppleSignInCancelled",
     "Apple sign in cancelled",
     "Shown when the user cancels the Apple sign-in flow."),
    ("authErrorAppleSignInFailed",
     "Apple sign in failed",
     "Shown when Apple sign-in throws a SignInWithAppleException. Technical detail is logged separately."),
    ("authErrorFailedToVerifyOtp",
     "Failed to verify OTP",
     "Shown when OTP verification completes without throwing but returns a null user."),
    ("authErrorUserNotFound",
     "User not found",
     "Shown when an authenticated user's Firestore document cannot be found during a post-auth lookup."),
    ("authErrorNoUserLoggedIn",
     "No user logged in",
     "Shown when an operation requires a logged-in user but no current user is found."),
    ("authErrorNoVerificationId",
     "No verification ID. Please request OTP again.",
     "Shown when phone OTP verification is attempted without a stored verification ID."),

    # Firebase-code-derived auth errors (10 keys; matching auth_service's _getAuthErrorMessage switch wordings)
    ("authErrorFirebaseAccountNotFound",
     "No account found with this email",
     "Firebase auth code 'user-not-found': no account exists for the given email."),
    ("authErrorFirebaseWrongPassword",
     "Incorrect password",
     "Firebase auth code 'wrong-password': supplied password is incorrect."),
    ("authErrorFirebaseEmailAlreadyInUse",
     "An account already exists with this email",
     "Firebase auth code 'email-already-in-use': email already registered."),
    ("authErrorFirebaseInvalidEmail",
     "Please enter a valid email address",
     "Firebase auth code 'invalid-email': email format invalid."),
    ("authErrorFirebaseWeakPassword",
     "Password must be at least 6 characters",
     "Firebase auth code 'weak-password': password too short."),
    ("authErrorFirebaseTooManyRequests",
     "Too many attempts. Please try again later",
     "Firebase auth code 'too-many-requests': throttled."),
    ("authErrorFirebaseInvalidVerificationCode",
     "Invalid OTP code. Please try again",
     "Firebase auth code 'invalid-verification-code': OTP code rejected."),
    ("authErrorFirebaseInvalidVerificationId",
     "Verification session expired. Please request a new code",
     "Firebase auth code 'invalid-verification-id': verification session expired."),
    ("authErrorFirebaseCredentialAlreadyInUse",
     "This phone number is already linked to another account",
     "Firebase auth code 'credential-already-in-use': phone number already linked elsewhere."),
    ("authErrorFirebaseNetworkRequestFailed",
     "Network error. Please check your connection",
     "Firebase auth code 'network-request-failed': network unreachable."),

    # Auth fallback (1 key; matches auth_service's default case wording)
    ("authErrorFallback",
     "An error occurred. Please try again",
     "Generic auth fallback when no specific Firebase code or service-layer case applies."),
]

assert len(NEW_KEYS) == 23, f"Expected 23, got {len(NEW_KEYS)}"

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

**Expected:** `Added 23 keys`, `Skipped 0 keys: []`.

---

## Step 2 — Add 23 empty placeholder keys to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb`

```bash
python3 << 'PYEOF'
import json

NEW_KEY_NAMES = [
    "authErrorFailedToCreateUser", "authErrorFailedToSignIn", "authErrorUserDataNotFound",
    "authErrorGoogleSignInCancelled", "authErrorFailedToSignInWithGoogle",
    "authErrorFailedToSignInWithApple", "authErrorAppleSignInCancelled",
    "authErrorAppleSignInFailed", "authErrorFailedToVerifyOtp", "authErrorUserNotFound",
    "authErrorNoUserLoggedIn", "authErrorNoVerificationId",
    "authErrorFirebaseAccountNotFound", "authErrorFirebaseWrongPassword",
    "authErrorFirebaseEmailAlreadyInUse", "authErrorFirebaseInvalidEmail",
    "authErrorFirebaseWeakPassword", "authErrorFirebaseTooManyRequests",
    "authErrorFirebaseInvalidVerificationCode", "authErrorFirebaseInvalidVerificationId",
    "authErrorFirebaseCredentialAlreadyInUse", "authErrorFirebaseNetworkRequestFailed",
    "authErrorFallback",
]

assert len(NEW_KEY_NAMES) == 23, f"Expected 23, got {len(NEW_KEY_NAMES)}"

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

**Expected:** both files report `added 23, skipped 0`.

---

## Step 3 — `flutter gen-l10n` (SKIPPED BY THE AGENT)

The human reviewer runs this locally after pulling the feature branch.

---

## Step 4 — Create new file `lib/core/services/auth_localization_resolver.dart`

**Full file content (relative imports per project convention):**

```dart
import '../../generated/l10n/app_localizations.dart';
import 'auth_service.dart';

/// Identifies the kind of auth error carried by [AuthResult.errorKey].
///
/// Two conceptual groups are unified into a single enum to keep AuthResult to
/// one new field per the C.2 architectural decision (Q1, Option 1):
///
///   * Service-layer errors (no equivalent Firebase auth code) — produced by
///     auth_service.dart's own logic and by auth_provider.dart for things like
///     "user data not found" and "no verification ID".
///
///   * Firebase-code-derived errors — produced when a FirebaseAuthException
///     fires; the exception's code is mapped to one of these enum values via
///     `_classifyAuthCode` inside auth_service.dart.
///
/// The fallback value is used when none of the more specific cases apply
/// (e.g. unrecognized Firebase code, or a non-Firebase exception caught by a
/// generic `catch (e)`).
enum AuthErrorKey {
  // -- Service-layer errors (12 values) ---------------------------------------
  failedToCreateUser,
  failedToSignIn,
  userDataNotFound,
  googleSignInCancelled,
  failedToSignInWithGoogle,
  failedToSignInWithApple,
  appleSignInCancelled,
  appleSignInFailed,
  failedToVerifyOtp,
  userNotFound,
  noUserLoggedIn,
  noVerificationId,

  // -- Firebase-code-derived errors (10 values) -------------------------------
  firebaseAccountNotFound,
  firebaseWrongPassword,
  firebaseEmailAlreadyInUse,
  firebaseInvalidEmail,
  firebaseWeakPassword,
  firebaseTooManyRequests,
  firebaseInvalidVerificationCode,
  firebaseInvalidVerificationId,
  firebaseCredentialAlreadyInUse,
  firebaseNetworkRequestFailed,

  // -- Catch-all (1 value) ----------------------------------------------------
  fallback,
}

/// Resolves an [AuthErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch — adding a new enum value without
/// a matching case here is a compile error.
String resolveAuthErrorMessage(AppLocalizations loc, AuthErrorKey key) {
  return switch (key) {
    // Service-layer
    AuthErrorKey.failedToCreateUser => loc.authErrorFailedToCreateUser,
    AuthErrorKey.failedToSignIn => loc.authErrorFailedToSignIn,
    AuthErrorKey.userDataNotFound => loc.authErrorUserDataNotFound,
    AuthErrorKey.googleSignInCancelled => loc.authErrorGoogleSignInCancelled,
    AuthErrorKey.failedToSignInWithGoogle => loc.authErrorFailedToSignInWithGoogle,
    AuthErrorKey.failedToSignInWithApple => loc.authErrorFailedToSignInWithApple,
    AuthErrorKey.appleSignInCancelled => loc.authErrorAppleSignInCancelled,
    AuthErrorKey.appleSignInFailed => loc.authErrorAppleSignInFailed,
    AuthErrorKey.failedToVerifyOtp => loc.authErrorFailedToVerifyOtp,
    AuthErrorKey.userNotFound => loc.authErrorUserNotFound,
    AuthErrorKey.noUserLoggedIn => loc.authErrorNoUserLoggedIn,
    AuthErrorKey.noVerificationId => loc.authErrorNoVerificationId,
    // Firebase-code-derived
    AuthErrorKey.firebaseAccountNotFound => loc.authErrorFirebaseAccountNotFound,
    AuthErrorKey.firebaseWrongPassword => loc.authErrorFirebaseWrongPassword,
    AuthErrorKey.firebaseEmailAlreadyInUse => loc.authErrorFirebaseEmailAlreadyInUse,
    AuthErrorKey.firebaseInvalidEmail => loc.authErrorFirebaseInvalidEmail,
    AuthErrorKey.firebaseWeakPassword => loc.authErrorFirebaseWeakPassword,
    AuthErrorKey.firebaseTooManyRequests => loc.authErrorFirebaseTooManyRequests,
    AuthErrorKey.firebaseInvalidVerificationCode => loc.authErrorFirebaseInvalidVerificationCode,
    AuthErrorKey.firebaseInvalidVerificationId => loc.authErrorFirebaseInvalidVerificationId,
    AuthErrorKey.firebaseCredentialAlreadyInUse => loc.authErrorFirebaseCredentialAlreadyInUse,
    AuthErrorKey.firebaseNetworkRequestFailed => loc.authErrorFirebaseNetworkRequestFailed,
    // Fallback
    AuthErrorKey.fallback => loc.authErrorFallback,
  };
}

/// One-line resolver for UI consumers. Picks the best message available:
///
///   1. If [AuthResult.errorKey] is non-null, resolve via [resolveAuthErrorMessage].
///   2. Else if [AuthResult.error] is non-null (transitional during C.2-C.4),
///      return it as-is.
///   3. Else return the generic auth fallback.
///
/// UI screens should call this rather than reading [AuthResult.error] directly.
String resolveAuthResultError(AppLocalizations loc, AuthResult result) {
  if (result.errorKey != null) {
    return resolveAuthErrorMessage(loc, result.errorKey!);
  }
  return result.error ?? loc.authErrorFallback;
}
```

---

## Step 5 — Edit `lib/core/services/auth_service.dart`

**The agent should view the file in full first** to confirm all line numbers from the spec match before applying edits. The line numbers in this spec are based on cleanup-3-complete state and may differ slightly from the actual file at the time of execution — the agent should confirm via `grep -n` before each str_replace.

### 5.1 — Add resolver import at top of file

**Search:**
```dart
import '../utils/error_handler.dart';
```

**Replace:**
```dart
import '../utils/error_handler.dart';
import 'auth_localization_resolver.dart';
```

### 5.2 — Update `AuthResult` class to add `errorKey` field

**Search:**
```dart
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? error;
  final bool isNewUser;

  AuthResult._({
    required this.success,
    this.user,
    this.error,
    this.isNewUser = false,
  });

  factory AuthResult.success(UserModel? user, {bool isNewUser = false}) {
    return AuthResult._(success: true, user: user, isNewUser: isNewUser);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}
```

**Replace:**
```dart
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? error;
  final AuthErrorKey? errorKey;
  final bool isNewUser;

  AuthResult._({
    required this.success,
    this.user,
    this.error,
    this.errorKey,
    this.isNewUser = false,
  });

  factory AuthResult.success(UserModel? user, {bool isNewUser = false}) {
    return AuthResult._(success: true, user: user, isNewUser: isNewUser);
  }

  factory AuthResult.failure(String error, {AuthErrorKey? errorKey}) {
    return AuthResult._(success: false, error: error, errorKey: errorKey);
  }
}
```

### 5.3 — Migrate the 13 service-layer `AuthResult.failure(...)` sites

For each site, the change is from `AuthResult.failure('English string')` to `AuthResult.failure('English string', errorKey: AuthErrorKey.X)`. The English string stays for backward compat (transitional duplication, collapsed in C.5).

For sites that have **duplicate strings** (e.g., three `'No user logged in'` lines), the agent must use enough surrounding context in the str_replace `old_str` to make each match unique. View the file first if needed.

**13 sites with their target enum values:**

| Line (approx) | Search | Replace |
|---|---|---|
| 53 | `return AuthResult.failure('Failed to create user');` | `return AuthResult.failure('Failed to create user', errorKey: AuthErrorKey.failedToCreateUser);` |
| 96 | `return AuthResult.failure('Failed to sign in');` | `return AuthResult.failure('Failed to sign in', errorKey: AuthErrorKey.failedToSignIn);` |
| 103 | `return AuthResult.failure('User data not found');` | `return AuthResult.failure('User data not found', errorKey: AuthErrorKey.userDataNotFound);` |
| 126 | `return AuthResult.failure('Google sign in cancelled');` | `return AuthResult.failure('Google sign in cancelled', errorKey: AuthErrorKey.googleSignInCancelled);` |
| 143 | `return AuthResult.failure('Failed to sign in with Google');` | `return AuthResult.failure('Failed to sign in with Google', errorKey: AuthErrorKey.failedToSignInWithGoogle);` |
| 223 | `return AuthResult.failure('Failed to sign in with Apple');` | `return AuthResult.failure('Failed to sign in with Apple', errorKey: AuthErrorKey.failedToSignInWithApple);` |
| 257 | `return AuthResult.failure('Apple sign in cancelled');` | `return AuthResult.failure('Apple sign in cancelled', errorKey: AuthErrorKey.appleSignInCancelled);` |
| 259 | `return AuthResult.failure('Apple sign in failed: ${e.message}');` | (See 5.3a below — special handling: drop interpolation, add debugPrint) |
| 320 | `return AuthResult.failure('Failed to verify OTP');` | `return AuthResult.failure('Failed to verify OTP', errorKey: AuthErrorKey.failedToVerifyOtp);` |
| 329 | `return AuthResult.failure('User not found');` | `return AuthResult.failure('User not found', errorKey: AuthErrorKey.userNotFound);` |
| 380 | `return AuthResult.failure('No user logged in');` (3 occurrences total at L380, L438, L506 — disambiguate via surrounding context) | `return AuthResult.failure('No user logged in', errorKey: AuthErrorKey.noUserLoggedIn);` |
| 438 | (same as above — second occurrence) | (same replacement) |
| 506 | (same as above — third occurrence) | (same replacement) |

### 5.3a — Special: Apple sign-in failed (line 259)

Drop the technical interpolation `${e.message}` from the user-visible message; preserve it in `debugPrint` for engineers. Same pattern as cleanup-3 (Smile ID parse error) and C.1 (no equivalent here, but consistent precedent).

The agent should `view` the surrounding lines first to identify the catch block. The change typically looks like this (exact whitespace must match the file):

**Search:**
```dart
    } on SignInWithAppleException catch (e) {
      return AuthResult.failure('Apple sign in failed: ${e.message}');
```

**Replace:**
```dart
    } on SignInWithAppleException catch (e) {
      debugPrint('Apple sign in failed: ${e.message}');
      return AuthResult.failure(
        'Apple sign in failed',
        errorKey: AuthErrorKey.appleSignInFailed,
      );
```

If the agent finds `import 'package:flutter/foundation.dart';` is not already imported in this file, add it alongside the other imports — that's where `debugPrint` lives. Use `grep -n "debugPrint\|foundation.dart" lib/core/services/auth_service.dart` to check before adding.

### 5.4 — Replace `_getAuthErrorMessage` with new helpers

**Search the entire `_getAuthErrorMessage` method body** and replace with three new private helpers. The existing method starts at approximately line 557.

**Search:**
```dart
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please try again';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new code';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred. Please try again';
    }
  }
```

**Replace:**
```dart
  /// Maps a FirebaseAuthException code to an [AuthErrorKey] enum value.
  AuthErrorKey _classifyAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
        return AuthErrorKey.firebaseAccountNotFound;
      case 'wrong-password':
        return AuthErrorKey.firebaseWrongPassword;
      case 'email-already-in-use':
        return AuthErrorKey.firebaseEmailAlreadyInUse;
      case 'invalid-email':
        return AuthErrorKey.firebaseInvalidEmail;
      case 'weak-password':
        return AuthErrorKey.firebaseWeakPassword;
      case 'too-many-requests':
        return AuthErrorKey.firebaseTooManyRequests;
      case 'invalid-verification-code':
        return AuthErrorKey.firebaseInvalidVerificationCode;
      case 'invalid-verification-id':
        return AuthErrorKey.firebaseInvalidVerificationId;
      case 'credential-already-in-use':
        return AuthErrorKey.firebaseCredentialAlreadyInUse;
      case 'network-request-failed':
        return AuthErrorKey.firebaseNetworkRequestFailed;
      default:
        return AuthErrorKey.fallback;
    }
  }

  /// English fallback for the transitional [AuthResult.error] String field.
  ///
  /// Kept in sync with [resolveAuthErrorMessage] in auth_localization_resolver.dart.
  /// IMPORTANT: any English wording change must update BOTH this method AND the
  /// corresponding ARB key in app_en.arb. C.5 will collapse this duplication.
  String _englishOf(AuthErrorKey key) {
    switch (key) {
      // Service-layer
      case AuthErrorKey.failedToCreateUser:
        return 'Failed to create user';
      case AuthErrorKey.failedToSignIn:
        return 'Failed to sign in';
      case AuthErrorKey.userDataNotFound:
        return 'User data not found';
      case AuthErrorKey.googleSignInCancelled:
        return 'Google sign in cancelled';
      case AuthErrorKey.failedToSignInWithGoogle:
        return 'Failed to sign in with Google';
      case AuthErrorKey.failedToSignInWithApple:
        return 'Failed to sign in with Apple';
      case AuthErrorKey.appleSignInCancelled:
        return 'Apple sign in cancelled';
      case AuthErrorKey.appleSignInFailed:
        return 'Apple sign in failed';
      case AuthErrorKey.failedToVerifyOtp:
        return 'Failed to verify OTP';
      case AuthErrorKey.userNotFound:
        return 'User not found';
      case AuthErrorKey.noUserLoggedIn:
        return 'No user logged in';
      case AuthErrorKey.noVerificationId:
        return 'No verification ID. Please request OTP again.';
      // Firebase-code-derived
      case AuthErrorKey.firebaseAccountNotFound:
        return 'No account found with this email';
      case AuthErrorKey.firebaseWrongPassword:
        return 'Incorrect password';
      case AuthErrorKey.firebaseEmailAlreadyInUse:
        return 'An account already exists with this email';
      case AuthErrorKey.firebaseInvalidEmail:
        return 'Please enter a valid email address';
      case AuthErrorKey.firebaseWeakPassword:
        return 'Password must be at least 6 characters';
      case AuthErrorKey.firebaseTooManyRequests:
        return 'Too many attempts. Please try again later';
      case AuthErrorKey.firebaseInvalidVerificationCode:
        return 'Invalid OTP code. Please try again';
      case AuthErrorKey.firebaseInvalidVerificationId:
        return 'Verification session expired. Please request a new code';
      case AuthErrorKey.firebaseCredentialAlreadyInUse:
        return 'This phone number is already linked to another account';
      case AuthErrorKey.firebaseNetworkRequestFailed:
        return 'Network error. Please check your connection';
      // Fallback
      case AuthErrorKey.fallback:
        return 'An error occurred. Please try again';
    }
  }

  /// Compact helper: build an AuthResult.failure from a FirebaseAuthException
  /// code, populating both the transitional [AuthResult.error] String and
  /// the new [AuthResult.errorKey].
  AuthResult _failureFromAuthCode(String code) {
    final key = _classifyAuthCode(code);
    return AuthResult.failure(_englishOf(key), errorKey: key);
  }
```

### 5.5 — Migrate the 10 `_getAuthErrorMessage(e.code)` callsites that wrap in AuthResult.failure

Each of the 10 callsites looks like:
```dart
return AuthResult.failure(_getAuthErrorMessage(e.code));
```

Replace each with:
```dart
return _failureFromAuthCode(e.code);
```

Approximate line numbers: 77, 109, 172, 261, 332, 358, 409, 492, 520. (Note: the original section 2 of investigation listed 10 occurrences; the agent should `grep -n "_getAuthErrorMessage" lib/core/services/auth_service.dart` to locate them all and confirm the count.)

### 5.6 — Migrate the 1 `_getAuthErrorMessage(e.code)` callsite that doesn't use AuthResult.failure (sendOtp's onError callback)

The site at approximately line 282 inside `sendOtp` uses:
```dart
onError(_getAuthErrorMessage(e.code));
```

The callback signature stays `String` (per architectural decision 7). The internal call is rewritten to use the new helpers:

**Search:**
```dart
        onError(_getAuthErrorMessage(e.code));
```

**Replace:**
```dart
        onError(_englishOf(_classifyAuthCode(e.code)));
```

(The exact indentation depends on the existing code — agent should view the surrounding context to confirm whitespace.)

---

## Step 6 — Edit `lib/providers/auth_provider.dart` (1 site)

### 6.1 — Add the resolver import alongside existing imports

The file may not currently import `auth_service.dart`'s new symbols directly. Check whether `AuthErrorKey` is already accessible via the existing `auth_service` import; if not, add an explicit import.

```bash
grep -n "import.*auth_service\|import.*auth_localization_resolver" lib/providers/auth_provider.dart
```

If `AuthErrorKey` is not imported, add:
```dart
import '../core/services/auth_localization_resolver.dart';
```

### 6.2 — Migrate the line 281 `AuthResult.failure(...)` call

**Search:**
```dart
      return AuthResult.failure('No verification ID. Please request OTP again.');
```

**Replace:**
```dart
      return AuthResult.failure(
        'No verification ID. Please request OTP again.',
        errorKey: AuthErrorKey.noVerificationId,
      );
```

---

## Step 7 — Migrate the 6 UI screens

For each screen below, the migration is the same shape:
- Add an import for `auth_localization_resolver.dart` if not already present
- Ensure `AppLocalizations` is imported (it already is in all 6 screens — verified in pre-flight)
- Replace `result.error ?? 'Hardcoded English'` with `resolveAuthResultError(loc, result)`
- If a `final loc = AppLocalizations.of(context);` is not already declared in the same scope, add one at the top of the affected method

### 7.1 — `lib/features/auth/screens/sign_up_screen.dart` (2 sites at L131-133 and L172-176)

**Add import** (relative path from `lib/features/auth/screens/`):
```dart
import '../../../core/services/auth_localization_resolver.dart';
```

**Site 1 — L131-133:**

**Search:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? AppLocalizations.of(context).errorGeneric),
            backgroundColor: AppColors.error,
          ),
        );
```

**Replace:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
            backgroundColor: AppColors.error,
          ),
        );
```

**Site 2 — L174-178:**

**Search:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Google sign up failed'),
            backgroundColor: AppColors.error,
          ),
        );
```

**Replace:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
            backgroundColor: AppColors.error,
          ),
        );
```

### 7.2 — `lib/features/auth/screens/login_screen.dart` (3 sites)

**Add import:**
```dart
import '../../../core/services/auth_localization_resolver.dart';
```

**Site 1 — L78-82:**

**Search:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Login failed'),
            backgroundColor: AppColors.error,
          ),
        );
```

**Replace:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
            backgroundColor: AppColors.error,
          ),
        );
```

**Site 2 — L116-120:**

**Search:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Google login failed'),
            backgroundColor: AppColors.error,
          ),
        );
```

**Replace:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
            backgroundColor: AppColors.error,
          ),
        );
```

**Site 3 — L154-158:**

**Search:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Apple sign in failed'),
            backgroundColor: AppColors.error,
          ),
        );
```

**Replace:**
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
            backgroundColor: AppColors.error,
          ),
        );
```

### 7.3 — `lib/features/auth/screens/forgot_password_screen.dart` (1 site at L41-43)

**Add import:**
```dart
import '../../../core/services/auth_localization_resolver.dart';
```

**Search:**
```dart
      if (!result.success) {
        throw Exception(result.error ?? 'Failed to send reset email');
      }
```

**Replace:**
```dart
      if (!result.success) {
        throw Exception(resolveAuthResultError(AppLocalizations.of(context), result));
      }
```

### 7.4 — `lib/features/auth/screens/otp_verification_screen.dart` (1 site at L165-169)

**Add import:**
```dart
import '../../../core/services/auth_localization_resolver.dart';
```

**Search:**
```dart
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to send email';
        });
      }
```

**Replace:**
```dart
      } else {
        setState(() {
          _errorMessage = resolveAuthResultError(AppLocalizations.of(context), result);
        });
      }
```

### 7.5 — `lib/features/auth/screens/phone_otp_screen.dart` (1 site at L219-223)

**Add import:**
```dart
import '../../../core/services/auth_localization_resolver.dart';
```

**Search:**
```dart
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Invalid OTP. Please try again.';
        });
      }
```

**Replace:**
```dart
      } else {
        setState(() {
          _errorMessage = resolveAuthResultError(AppLocalizations.of(context), result);
        });
      }
```

### 7.6 — `lib/features/auth/screens/kyc/phone_verification_screen.dart` (1 site at L203-207)

**Add import** (relative path from `lib/features/auth/screens/kyc/` — note depth 4):
```dart
import '../../../../core/services/auth_localization_resolver.dart';
```

**Search:**
```dart
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Invalid code. Please try again.';
        });
      }
```

**Replace:**
```dart
      } else {
        setState(() {
          _errorMessage = resolveAuthResultError(AppLocalizations.of(context), result);
        });
      }
```

---

## Step 8 — Verification (skip Flutter calls; run all greps)

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c2_verify.sh << 'VERIFY_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== A. Resolver file exists with correct shape ===="
ls -la lib/core/services/auth_localization_resolver.dart
echo "Enum values (expect 23):"
grep -cE "^  [a-z]" lib/core/services/auth_localization_resolver.dart || true
echo "Resolver functions (expect 2):"
grep -cE "^String resolve" lib/core/services/auth_localization_resolver.dart

echo ""
echo "==== B. AuthResult class has new errorKey field ===="
sed -n '/^class AuthResult/,/^}/p' lib/core/services/auth_service.dart | head -25

echo ""
echo "==== C. Auth resolver import added to auth_service.dart ===="
grep -n "auth_localization_resolver" lib/core/services/auth_service.dart

echo ""
echo "==== D. _getAuthErrorMessage deleted; new helpers present ===="
grep -nE "^  String _getAuthErrorMessage\(" lib/core/services/auth_service.dart && echo "FAIL — _getAuthErrorMessage still present" || echo "PASS — _getAuthErrorMessage deleted"
grep -nE "^  AuthErrorKey _classifyAuthCode\(|^  String _englishOf\(|^  AuthResult _failureFromAuthCode\(" lib/core/services/auth_service.dart

echo ""
echo "==== E. All 13 service-layer AuthResult.failure sites use errorKey ===="
echo "Expect 13 matches:"
grep -cE "AuthResult\.failure\([^)]*errorKey:" lib/core/services/auth_service.dart
echo ""
echo "Expect ZERO bare AuthResult.failure(' calls (all should now have errorKey):"
grep -nE "AuthResult\.failure\('[^']*'\);" lib/core/services/auth_service.dart || echo "PASS — no bare failure calls"

echo ""
echo "==== F. All 10 _getAuthErrorMessage callsites migrated to _failureFromAuthCode ===="
grep -nE "_getAuthErrorMessage\(" lib/core/services/auth_service.dart && echo "FAIL — still references _getAuthErrorMessage" || echo "PASS — no _getAuthErrorMessage references"
echo ""
echo "Expect 10 matches for _failureFromAuthCode (the AuthResult-returning paths):"
grep -cE "_failureFromAuthCode\(" lib/core/services/auth_service.dart
echo "Expect 1 match for the sendOtp callback path using _englishOf(_classifyAuthCode):"
grep -nE "_englishOf\(_classifyAuthCode" lib/core/services/auth_service.dart

echo ""
echo "==== G. auth_provider.dart line 281 migrated ===="
grep -nE "errorKey: AuthErrorKey\.noVerificationId" lib/providers/auth_provider.dart

echo ""
echo "==== H. 6 UI screens use resolveAuthResultError ===="
for f in sign_up_screen login_screen forgot_password_screen otp_verification_screen phone_otp_screen; do
  count=$(grep -c "resolveAuthResultError" "lib/features/auth/screens/${f}.dart" 2>/dev/null || echo 0)
  echo "  ${f}.dart: $count match(es)"
done
echo "  kyc/phone_verification_screen.dart: $(grep -c "resolveAuthResultError" "lib/features/auth/screens/kyc/phone_verification_screen.dart") match(es)"
echo ""
echo "Expect 9 total: sign_up=2, login=3, forgot_password=1, otp_verification=1, phone_otp=1, kyc/phone_verification=1"

echo ""
echo "==== I. No leftover hardcoded English in the 6 migrated UI screens ===="
for f in lib/features/auth/screens/sign_up_screen.dart lib/features/auth/screens/login_screen.dart lib/features/auth/screens/forgot_password_screen.dart lib/features/auth/screens/otp_verification_screen.dart lib/features/auth/screens/phone_otp_screen.dart lib/features/auth/screens/kyc/phone_verification_screen.dart; do
  echo "  -- $f --"
  grep -nE "result\.error \?\? '[A-Z]" "$f" || echo "    PASS"
done

echo ""
echo "==== J. ARB integrity ===="
git show phase6-step9-cleanup-4-c1-complete:lib/l10n/app_en.arb 2>/dev/null | python3 -c "import json,sys; arb=json.load(sys.stdin); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'Pre-C.2 baseline: total={len(arb)}, value={v}, meta={m}')"
python3 -c "import json; arb=json.load(open('lib/l10n/app_en.arb')); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'Post-C.2: total={len(arb)}, value={v}, meta={m}')"
echo "(Difference must be exactly +23 value, +23 meta, +46 total)"
python3 << 'PYINNER'
import json, subprocess
old = json.loads(subprocess.check_output(['git','show','phase6-step9-cleanup-4-c1-complete:lib/l10n/app_en.arb']))
new = json.load(open('lib/l10n/app_en.arb'))
lost = [k for k in old if k not in new]
mutated = [k for k in old if k in new and old[k] != new[k]]
print(f'  Lost keys: {len(lost)} {lost[:5] if lost else ""}')
print(f'  Mutated values: {len(mutated)} {mutated[:5] if mutated else ""}')
if not lost and not mutated:
    print('  PASS: all pre-existing keys preserved')
PYINNER

echo ""
echo "==== K. fr/ar placeholders all empty ===="
for lang in fr ar; do
  echo "  -- app_${lang}.arb --"
  python3 - "$lang" << 'PYINNER'
import json, sys
lang = sys.argv[1]
arb = json.load(open(f'lib/l10n/app_{lang}.arb'))
new_keys = ["authErrorFailedToCreateUser","authErrorFailedToSignIn","authErrorUserDataNotFound","authErrorGoogleSignInCancelled","authErrorFailedToSignInWithGoogle","authErrorFailedToSignInWithApple","authErrorAppleSignInCancelled","authErrorAppleSignInFailed","authErrorFailedToVerifyOtp","authErrorUserNotFound","authErrorNoUserLoggedIn","authErrorNoVerificationId","authErrorFirebaseAccountNotFound","authErrorFirebaseWrongPassword","authErrorFirebaseEmailAlreadyInUse","authErrorFirebaseInvalidEmail","authErrorFirebaseWeakPassword","authErrorFirebaseTooManyRequests","authErrorFirebaseInvalidVerificationCode","authErrorFirebaseInvalidVerificationId","authErrorFirebaseCredentialAlreadyInUse","authErrorFirebaseNetworkRequestFailed","authErrorFallback"]
missing = [k for k in new_keys if k not in arb]
non_empty = [k for k in new_keys if k in arb and arb[k] != ""]
print(f'    Missing: {len(missing)}')
print(f'    Non-empty: {len(non_empty)}')
PYINNER
done
VERIFY_EOF

bash /tmp/cleanup4_c2_verify.sh
```

**Pass criteria:**
- A: 23 enum values, 2 resolver functions
- B: AuthResult class shows new `errorKey` field
- C: 1 import line for resolver
- D: `_getAuthErrorMessage` is gone; 3 new helpers present
- E: 13 errorKey-using AuthResult.failure calls, 0 bare ones
- F: 0 references to `_getAuthErrorMessage`, 10 `_failureFromAuthCode` calls, 1 `_englishOf(_classifyAuthCode` for sendOtp
- G: 1 match in auth_provider.dart
- H: 9 total `resolveAuthResultError` calls across 6 UI files
- I: 0 leftover `result.error ?? 'English'` patterns
- J: +23 value, +23 meta, +46 total; 0 lost, 0 mutated
- K: 0 missing, 0 non-empty in fr/ar

If any check fails, STOP and report.

---

## Step 9 — Commit on feature branch

```bash
git add lib/core/services/auth_service.dart \
        lib/core/services/auth_localization_resolver.dart \
        lib/providers/auth_provider.dart \
        lib/features/auth/screens/sign_up_screen.dart \
        lib/features/auth/screens/login_screen.dart \
        lib/features/auth/screens/forgot_password_screen.dart \
        lib/features/auth/screens/otp_verification_screen.dart \
        lib/features/auth/screens/phone_otp_screen.dart \
        lib/features/auth/screens/kyc/phone_verification_screen.dart \
        lib/l10n/app_en.arb \
        lib/l10n/app_fr.arb \
        lib/l10n/app_ar.arb

git commit -m "9.cleanup-4-C2: Auth surface localization

- Add AuthErrorKey enum (23 values: 12 service-layer + 10 Firebase-code + 1 fallback)
  and 2 resolver functions in new file lib/core/services/auth_localization_resolver.dart
- AuthResult gains errorKey: AuthErrorKey? field alongside existing error: String? for
  backward compatibility (transitional duplication, collapsed in C.5)
- 13 service-layer AuthResult.failure() sites in auth_service.dart migrated to populate
  both error String and errorKey enum
- _getAuthErrorMessage deleted; replaced by 3 new private helpers
  (_classifyAuthCode, _englishOf, _failureFromAuthCode)
- All 10 Firebase-auth-code AuthResult.failure paths migrated to _failureFromAuthCode
- sendOtp's onError(String) callback signature preserved; internal call updated to
  use new helpers
- Apple sign-in failed: technical interpolation \${e.message} dropped from user-visible
  message; preserved in debugPrint for engineers (matches cleanup-3 pattern)
- auth_provider.dart line 281 migrated
- 6 auth UI screens migrated to call resolveAuthResultError(loc, result); 9 hardcoded
  English fallback strings deleted from UI without adding ARB keys
- 23 new ARB keys added with @-metadata; fr/ar placeholders ready for Step 10
- Auth code wordings kept original (per Q2 decision); not reused from C.1's
  firebaseAuthError* keys
- Architecturally: single nullable errorKey field (Q1 Option 1); single unified enum
  rather than two separate enums to keep AuthResult to one new field

Second sub-batch of cleanup-4 (5 sub-batches total). Predecessor:
phase6-step9-cleanup-4-c1-complete @ 7118001c."

git push -u origin cleanup-4-c2-auth-surface
```

**Do NOT push to main. Do NOT merge. Do NOT create the tag — the human reviewer does both after verification.**

---

## Verification checklist (for the human reviewer after the agent finishes)

```bash
cd ~/Development/Projects/qr_wallet
git fetch origin
git checkout cleanup-4-c2-auth-surface
git pull

# Run gen-l10n locally
flutter gen-l10n

# Capture regenerated files into the agent's commit
git add lib/generated/l10n/
git commit --amend --no-edit

# Verify analyzer count matches pre-flight baseline
flutter analyze 2>&1 | tail -3
# Expected: same total count as pre-flight (currently 204), 0 errors

# Re-run Step 8 verification script
bash /tmp/cleanup4_c2_verify.sh

# Optional: build smoke test
flutter build apk --debug

# After all checks pass:
git checkout main
git merge --ff-only cleanup-4-c2-auth-surface
git tag -a phase6-step9-cleanup-4-c2-complete -m "Phase 6 Step 9 cleanup-4 sub-batch C.2 complete — Auth surface localization. AuthResult.errorKey field added; 23 new ARB keys (12 service-layer + 10 Firebase-code + 1 fallback); 6 UI screens migrated; 24 hardcoded English strings (13 service + 11 in _getAuthErrorMessage) replaced. Predecessor: phase6-step9-cleanup-4-c1-complete @ 7118001c."
git push origin main
git push origin phase6-step9-cleanup-4-c2-complete

git branch -d cleanup-4-c2-auth-surface
git push origin --delete cleanup-4-c2-auth-surface
```

---

## Out of scope — for later sub-batches

- **C.3 (User + Wallet surface):** UserResult, WalletException migrations. ~11 direct strings + ~8 KYC UI screens that consume UserResult.
- **C.4 (Payment / Momo / Biometric / QR result types):** ~17 unmapped result classes from cleanup-3 round 1 investigation.
- **C.5 (UI fallback sweep + collapse transitional duplication):** remaining `result.error ?? 'English'` patterns + collapse the duplicated English in ErrorHandler and AuthService by removing the fallback tables.

## End of C.2 spec
