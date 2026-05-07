# Phase 6 Step 9 — Cleanup-4 (Sub-batch C.1): ErrorHandler Localization Infrastructure

**Status:** READY TO IMPLEMENT
**Companion to:** `docs/PHASE_6_LOCALIZATION_SPEC.md`, `docs/SESSION_HANDOVER_2026-05-06.md`
**Predecessor tag:** `phase6-step9-cleanup-3-complete` @ `42219c34`
**Target tag:** `phase6-step9-cleanup-4-c1-complete`

## Background

Cleanup-3 closed the smile_id_service.dart orphan but surfaced a new one: `lib/core/utils/error_handler.dart` (327 lines, 1 class, ~46 user-visible English strings) plus ~30+ wrapper-type construction sites and ~10+ UI fallback strings across services/screens. The total surface for "fully localize the error pipeline" is ~50+ files.

That total work is sized as **cleanup-4, executed across 5 sub-batches (C.1 through C.5)**. This spec implements **C.1 — infrastructure only**.

C.1 is **purely additive** — no existing code changes behavior. Specifically:
- `ErrorHandler`'s existing public methods (`getUserFriendlyMessage`, `getMomoUserFriendlyMessage`, `getSmileIdUserFriendlyMessage`, `getKycErrorMessage`, plus the private `_getFirebaseUserFriendlyMessage`) remain byte-for-byte unchanged. They keep returning hardcoded English exactly as today.
- 5 NEW public classify methods are added that return typed enum values rather than strings.
- A new resolver file maps each enum value to an `AppLocalizations` getter.
- All 46 user-visible English strings move into `app_en.arb` (3 reuse cleanup-3 keys; 42 new keys; 1 additional cross-enum reuse). `app_fr.arb` and `app_ar.arb` get 42 empty placeholders for Step 10.
- The dead `.userFriendlyMessage` extension getter at the end of the file (zero consumers) is deleted.

After C.1: build remains green, analyzer count unchanged, users see no difference. Translators can work the 42 keys for Step 10. Sub-batches C.2-C.5 will progressively migrate consumers (services, wrapper types, UI screens) to the new enum-based API.

## Architectural decisions (locked, do not change)

1. **Per-category enums.** 5 enums — `MomoErrorKey`, `GenericErrorKey`, `SmileIdResultKey`, `KycErrorKey`, `FirebaseAuthErrorKey`. Type safety via switch-expression exhaustiveness.
2. **Cross-category fallback hidden inside ErrorHandler (Option β).** Each new classify method returns a non-null enum value. Unmatched cases return that enum's `fallback` value (or `somethingWentWrong` / `couldNotComplete` for enums that already have a natural fallback). Caller does single classify + single resolve — no chaining. Resolver's switch decides the final ARB key.
3. **KYC enum reuses cleanup-3 keys (Option ω).** `KycErrorKey.ninLength`, `bvnLength`, `ssnitFormat` resolve to the cleanup-3 ARB keys (`ninLengthError`, `bvnLengthError`, `ssnitFormatError`). The slight wording cleanup ("Invalid NIN format. NIN must be exactly 11 digits." → "NIN must be exactly 11 digits.") is accepted.
4. **Old methods stay 100% untouched.** No internal refactor. Adding the new classify methods does not modify existing `getMomoUserFriendlyMessage`, `getUserFriendlyMessage`, `getSmileIdUserFriendlyMessage`, `getKycErrorMessage`, or `_getFirebaseUserFriendlyMessage`. The English strings are intentionally duplicated between ErrorHandler's hardcoded returns and `app_en.arb` for the duration of C.1-C.4. C.5 collapses the duplication after all consumers migrate.
5. **Resolver file holds the enums AND the resolve functions.** Same architectural compromise as cleanup-3 (`smile_id_localization_resolver.dart` did the same). ErrorHandler imports the resolver file purely to use the enum types as return values; no resolver function is called from ErrorHandler.
6. **Two same-batch cross-enum reuses to save translation work:**
   - `MomoErrorKey.fallback` resolves to `loc.genericErrorFallback` ("Something went wrong. Please try again or contact support if the problem persists.")
   - `KycErrorKey.fallback` resolves to `loc.smileIdResultCouldNotComplete` ("Verification could not be completed. Please try again.")

## Behavior change in the NEW API (intentional, documented)

These are subtle but real differences between the old String-returning methods and the new classify methods. The OLD methods' behavior is preserved in C.1; the NEW methods' behavior is what C.2-C.5 callers will see.

| Case | Old method behavior | New classify method behavior |
|---|---|---|
| Unmatched MoMo error | Falls through to `getUserFriendlyMessage(error)` — gets a network/timeout/server-specific message if applicable | Returns `MomoErrorKey.fallback` → "Something went wrong…" |
| `getUserFriendlyMessage` with a Firebase error | Routes to `_getFirebaseUserFriendlyMessage` — gets a Firebase-specific message | Returns `GenericErrorKey.somethingWentWrong` → "Something went wrong…" |
| `getKycErrorMessage` with operation `'biometric_kyc'` | Delegates to `getSmileIdUserFriendlyMessage(null, error)` — falls through to generic classifier | Returns `KycErrorKey.fallback` → "Verification could not be completed…" |
| `getKycErrorMessage` with unknown operation | Falls through to `getUserFriendlyMessage(error)` | Returns `KycErrorKey.fallback` → "Verification could not be completed…" |
| `getSmileIdUserFriendlyMessage` with unknown result code AND non-null error | Falls through to `getUserFriendlyMessage(error)` | Returns `SmileIdResultKey.couldNotComplete` → "Verification could not be completed…" |

Net effect: callers that migrate from the OLD String-returning API to the NEW classify+resolve API may see slightly less specific error messages for cross-category cases. This is acceptable for C.1 because (a) the OLD API still works for any caller that wants the more specific behavior, (b) callers who NEED Firebase-specific messages should call `classifyFirebaseAuthError` directly, (c) C.2-C.5 caller migrations will use the appropriate classify method per call site.

## Scope summary

- **1 new file** created: `lib/core/utils/error_handler_localization_resolver.dart`
- **1 file** edited at 3 sites: `lib/core/utils/error_handler.dart` (add import, add 5 classify methods, delete dead extension)
- **No service or UI files touched.** This is C.1's most important property.
- **42 new ARB keys** added to `lib/l10n/app_en.arb` with `@`-metadata
- **42 placeholder keys** added to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb` (empty values for Step 10)
- **3 existing ARB keys reused** from cleanup-3: `ninLengthError`, `bvnLengthError`, `ssnitFormatError`
- **2 same-batch cross-enum reuses** (no extra ARB keys): `MomoErrorKey.fallback` → `genericErrorFallback`, `KycErrorKey.fallback` → `smileIdResultCouldNotComplete`

---

## Pre-flight check (run before starting)

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c1_preflight.sh << 'PREFLIGHT_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== Capture analyzer baseline (must match post-fix exactly) ===="
flutter analyze 2>&1 | tail -3

echo ""
echo "==== Confirm origin/main is at phase6-step9-cleanup-3-complete (commit 42219c34) ===="
git fetch origin
git rev-parse origin/main

echo ""
echo "==== Confirm cleanup-3 reuse keys exist in app_en.arb ===="
grep -nE "\"ninLengthError\"|\"bvnLengthError\"|\"ssnitFormatError\"" lib/l10n/app_en.arb

echo ""
echo "==== Confirm new resolver file does not yet exist ===="
[ -f lib/core/utils/error_handler_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "Does not exist yet — OK"

echo ""
echo "==== Working tree must be clean ===="
git status --short
PREFLIGHT_EOF

bash /tmp/cleanup4_c1_preflight.sh
```

**Expected:** analyzer baseline noted (currently `204 issues found.`); origin/main at `42219c34`; the 3 cleanup-3 reuse keys present; resolver file does not exist; working tree clean.

If the analyzer baseline is anything other than the current count: stop and reconcile before starting. The post-fix count must match exactly.

If `origin/main` is anything other than `42219c34`: fetch state is stale or main has moved. Stop and resolve before continuing.

---

## Step 1 — Add 42 new keys to `lib/l10n/app_en.arb`

```bash
python3 << 'PYEOF'
import json

ARB_PATH = "lib/l10n/app_en.arb"

NEW_KEYS = [
    # MomoErrorKey (5 keys; .fallback reuses genericErrorFallback below)
    ("momoErrorNotConfigured",
     "Mobile Money is coming soon! This feature is not yet available. Please use Card or Bank Transfer instead.",
     "Shown when a user tries to use Mobile Money but the service is not yet configured."),
    ("momoErrorPaymentDeclined",
     "Payment was declined. Please check your Mobile Money balance and try again.",
     "Shown when a Mobile Money payment is rejected or declined by the provider."),
    ("momoErrorInsufficientFunds",
     "Insufficient funds in your Mobile Money account.",
     "Shown when the user's Mobile Money account does not have enough balance for the transaction."),
    ("momoErrorInvalidPhone",
     "Invalid phone number. Please check and try again.",
     "Shown when the phone number provided for Mobile Money is invalid."),
    ("momoErrorPaymentTimeout",
     "Payment request timed out. Please check your phone for approval prompt and try again.",
     "Shown when a Mobile Money payment request times out before user approval."),

    # GenericErrorKey (11 keys)
    ("genericErrorNetwork",
     "Unable to connect. Please check your internet connection and try again.",
     "Shown when a network error prevents an operation from completing."),
    ("genericErrorCameraPermission",
     "Camera access is required for verification. Please enable camera permissions in your device settings.",
     "Shown when camera permission is denied during a verification flow."),
    ("genericErrorUserCancelled",
     "Verification was cancelled. You can try again when ready.",
     "Shown when the user cancels a verification flow."),
    ("genericErrorFaceDetection",
     "We couldn't detect your face clearly. Please ensure good lighting and position your face within the frame.",
     "Shown when the camera cannot detect the user's face during verification."),
    ("genericErrorFaceMismatch",
     "Face verification failed. The selfie doesn't match the ID photo. Please ensure you're using your own ID document.",
     "Shown when the user's selfie does not match the photo on their ID document."),
    ("genericErrorIdVerification",
     "ID verification failed. Please ensure your ID is valid, not expired, and the information entered is correct.",
     "Shown when ID verification fails for unknown reasons."),
    ("genericErrorDocument",
     "We couldn't read your document clearly. Please ensure the document is well-lit, flat, and all text is visible.",
     "Shown when an uploaded document cannot be read by the verification system."),
    ("genericErrorServer",
     "Our verification service is temporarily unavailable. Please try again in a few minutes.",
     "Shown when the verification backend returns a server error."),
    ("genericErrorTimeout",
     "The request took too long. Please check your connection and try again.",
     "Shown when a request times out."),
    ("genericErrorAuth",
     "Your session has expired. Please sign in again to continue.",
     "Shown when the user's authentication session has expired."),
    ("genericErrorFallback",
     "Something went wrong. Please try again or contact support if the problem persists.",
     "Generic last-resort error message when no more specific classification applies."),

    # SmileIdResultKey (11 keys)
    ("smileIdResultVerified",
     "Verification successful!",
     "Shown when a Smile ID verification completes successfully (result code 0810)."),
    ("smileIdResultFaceMatchFailed",
     "Face verification failed. The selfie doesn't match the ID photo.",
     "Smile ID result code 0811 — selfie/ID photo mismatch."),
    ("smileIdResultIdDocFailed",
     "ID document could not be verified. Please try with a different document.",
     "Smile ID result code 0812 — ID document failed verification."),
    ("smileIdResultLivenessFailed",
     "Liveness check failed. Please follow the on-screen instructions carefully.",
     "Smile ID result code 0813 — liveness check failed."),
    ("smileIdResultExpiredDoc",
     "Document is expired. Please use a valid, non-expired ID.",
     "Smile ID result code 0814 — document is expired."),
    ("smileIdResultInfoMismatch",
     "ID information mismatch. Please ensure you entered the correct details.",
     "Smile ID result code 0815 — information on ID does not match what user entered."),
    ("smileIdResultUnsupportedDoc",
     "Document not supported. Please try with a different ID type.",
     "Smile ID result code 0816 — document type not supported."),
    ("smileIdResultFaceNotDetected",
     "Face not detected. Please ensure your face is clearly visible and well-lit.",
     "Smile ID result code 0820 — no face detected in selfie."),
    ("smileIdResultMultipleFacesDetected",
     "Multiple faces detected. Please ensure only your face is in the frame.",
     "Smile ID result code 0821 — more than one face in selfie."),
    ("smileIdResultPoorImageQuality",
     "Poor image quality. Please ensure good lighting and a clear photo.",
     "Smile ID result code 0822 — image quality too low for verification."),
    ("smileIdResultCouldNotComplete",
     "Verification could not be completed. Please try again.",
     "Smile ID fallback when result code is unknown or no error info available."),

    # KycErrorKey (3 new keys; ninLength/bvnLength/ssnitFormat reuse cleanup-3 keys; fallback reuses smileIdResultCouldNotComplete)
    ("kycErrorDocumentUploadNetwork",
     "Failed to upload document. Please check your connection and try again.",
     "Shown when document upload fails due to a network issue."),
    ("kycErrorImageTooLarge",
     "Image file is too large. Please use a smaller image.",
     "Shown when an uploaded document image is too large."),
    ("kycErrorDocumentUploadGeneric",
     "Failed to upload document. Please try again.",
     "Generic fallback when document upload fails for unspecified reason."),

    # FirebaseAuthErrorKey (12 keys)
    ("firebaseAuthErrorNetwork",
     "Unable to connect. Please check your internet connection.",
     "Firebase auth error: network request failed."),
    ("firebaseAuthErrorTooManyRequests",
     "Too many attempts. Please wait a few minutes and try again.",
     "Firebase auth error: too many requests, throttled."),
    ("firebaseAuthErrorUserNotFound",
     "Account not found. Please check your credentials or sign up.",
     "Firebase auth error: account does not exist."),
    ("firebaseAuthErrorWrongPassword",
     "Incorrect password. Please try again.",
     "Firebase auth error: wrong password supplied."),
    ("firebaseAuthErrorEmailAlreadyInUse",
     "This email is already registered. Please sign in instead.",
     "Firebase auth error: email already used by another account."),
    ("firebaseAuthErrorInvalidEmail",
     "Please enter a valid email address.",
     "Firebase auth error: email format invalid."),
    ("firebaseAuthErrorWeakPassword",
     "Password is too weak. Please use at least 6 characters.",
     "Firebase auth error: password does not meet strength requirement."),
    ("firebaseAuthErrorInvalidPhone",
     "Please enter a valid phone number.",
     "Firebase auth error: phone number invalid."),
    ("firebaseAuthErrorInvalidVerificationCode",
     "Invalid verification code. Please check and try again.",
     "Firebase auth error: SMS or email verification code is invalid."),
    ("firebaseAuthErrorServiceUnavailable",
     "Service temporarily unavailable. Please try again later.",
     "Firebase auth error: backend service unavailable."),
    ("firebaseAuthErrorOperationNotAllowed",
     "You don't have permission to perform this action.",
     "Firebase auth error: operation not allowed for current user."),
    ("firebaseAuthErrorFallback",
     "Something went wrong. Please try again.",
     "Firebase auth fallback when no more specific code applies."),
]

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

**Expected:** `Added 42 keys`, `Skipped 0 keys: []`. If any key is skipped, stop and investigate name collisions.

---

## Step 2 — Add 42 empty placeholder keys to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb`

```bash
python3 << 'PYEOF'
import json

NEW_KEY_NAMES = [
    "momoErrorNotConfigured", "momoErrorPaymentDeclined", "momoErrorInsufficientFunds",
    "momoErrorInvalidPhone", "momoErrorPaymentTimeout",
    "genericErrorNetwork", "genericErrorCameraPermission", "genericErrorUserCancelled",
    "genericErrorFaceDetection", "genericErrorFaceMismatch", "genericErrorIdVerification",
    "genericErrorDocument", "genericErrorServer", "genericErrorTimeout", "genericErrorAuth",
    "genericErrorFallback",
    "smileIdResultVerified", "smileIdResultFaceMatchFailed", "smileIdResultIdDocFailed",
    "smileIdResultLivenessFailed", "smileIdResultExpiredDoc", "smileIdResultInfoMismatch",
    "smileIdResultUnsupportedDoc", "smileIdResultFaceNotDetected",
    "smileIdResultMultipleFacesDetected", "smileIdResultPoorImageQuality",
    "smileIdResultCouldNotComplete",
    "kycErrorDocumentUploadNetwork", "kycErrorImageTooLarge", "kycErrorDocumentUploadGeneric",
    "firebaseAuthErrorNetwork", "firebaseAuthErrorTooManyRequests", "firebaseAuthErrorUserNotFound",
    "firebaseAuthErrorWrongPassword", "firebaseAuthErrorEmailAlreadyInUse",
    "firebaseAuthErrorInvalidEmail", "firebaseAuthErrorWeakPassword",
    "firebaseAuthErrorInvalidPhone", "firebaseAuthErrorInvalidVerificationCode",
    "firebaseAuthErrorServiceUnavailable", "firebaseAuthErrorOperationNotAllowed",
    "firebaseAuthErrorFallback",
]

assert len(NEW_KEY_NAMES) == 42, f"Expected 42, got {len(NEW_KEY_NAMES)}"

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

**Expected:**
```
lib/l10n/app_fr.arb: added 42, skipped 0
lib/l10n/app_ar.arb: added 42, skipped 0
```

---

## Step 3 — Run `flutter gen-l10n` (SKIPPED BY THE AGENT)

The Flutter CLI is not installed in the agent's sandbox. The human reviewer runs this locally after pulling the feature branch. The `git add` list in Step 7 explicitly EXCLUDES `lib/generated/l10n/` because the agent cannot regenerate it.

---

## Step 4 — Create new file `lib/core/utils/error_handler_localization_resolver.dart`

**Full file content (create exactly as below; uses relative imports per project convention):**

```dart
import '../../generated/l10n/app_localizations.dart';

// ============================================================
// ENUM TYPES
// ============================================================
//
// One enum per error category. Each enum value maps to exactly one
// AppLocalizations getter via the corresponding resolver function below.
//
// These enums are returned by the new classify methods on ErrorHandler.
// UI consumers convert the enum to a translated string by calling the
// matching resolver function with their AppLocalizations instance.
//
// Some enum values intentionally resolve to the SAME ARB key as a value
// in another enum — this is documented per-case in the resolver functions.

enum MomoErrorKey {
  notConfigured,
  paymentDeclined,
  insufficientFunds,
  invalidPhone,
  paymentTimeout,
  fallback,
}

enum GenericErrorKey {
  network,
  cameraPermission,
  userCancelled,
  faceDetection,
  faceMismatch,
  idVerification,
  document,
  server,
  timeout,
  auth,
  somethingWentWrong,
}

enum SmileIdResultKey {
  verified,
  faceMatchFailed,
  idDocFailed,
  livenessFailed,
  expiredDoc,
  infoMismatch,
  unsupportedDoc,
  faceNotDetected,
  multipleFacesDetected,
  poorImageQuality,
  couldNotComplete,
}

enum KycErrorKey {
  ninLength,
  bvnLength,
  ssnitFormat,
  documentUploadNetwork,
  imageTooLarge,
  documentUploadGeneric,
  fallback,
}

enum FirebaseAuthErrorKey {
  network,
  tooManyRequests,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  invalidPhoneNumber,
  invalidVerificationCode,
  serviceUnavailable,
  operationNotAllowed,
  fallback,
}

// ============================================================
// RESOLVER FUNCTIONS
// ============================================================
//
// Each switch is exhaustive — adding a new enum value without a matching
// case here is a compile error.

String resolveMomoErrorMessage(AppLocalizations loc, MomoErrorKey key) {
  return switch (key) {
    MomoErrorKey.notConfigured => loc.momoErrorNotConfigured,
    MomoErrorKey.paymentDeclined => loc.momoErrorPaymentDeclined,
    MomoErrorKey.insufficientFunds => loc.momoErrorInsufficientFunds,
    MomoErrorKey.invalidPhone => loc.momoErrorInvalidPhone,
    MomoErrorKey.paymentTimeout => loc.momoErrorPaymentTimeout,
    // Cross-enum reuse: MoMo's last-resort fallback uses the same wording
    // as GenericErrorKey.somethingWentWrong.
    MomoErrorKey.fallback => loc.genericErrorFallback,
  };
}

String resolveGenericErrorMessage(AppLocalizations loc, GenericErrorKey key) {
  return switch (key) {
    GenericErrorKey.network => loc.genericErrorNetwork,
    GenericErrorKey.cameraPermission => loc.genericErrorCameraPermission,
    GenericErrorKey.userCancelled => loc.genericErrorUserCancelled,
    GenericErrorKey.faceDetection => loc.genericErrorFaceDetection,
    GenericErrorKey.faceMismatch => loc.genericErrorFaceMismatch,
    GenericErrorKey.idVerification => loc.genericErrorIdVerification,
    GenericErrorKey.document => loc.genericErrorDocument,
    GenericErrorKey.server => loc.genericErrorServer,
    GenericErrorKey.timeout => loc.genericErrorTimeout,
    GenericErrorKey.auth => loc.genericErrorAuth,
    GenericErrorKey.somethingWentWrong => loc.genericErrorFallback,
  };
}

String resolveSmileIdResultMessage(AppLocalizations loc, SmileIdResultKey key) {
  return switch (key) {
    SmileIdResultKey.verified => loc.smileIdResultVerified,
    SmileIdResultKey.faceMatchFailed => loc.smileIdResultFaceMatchFailed,
    SmileIdResultKey.idDocFailed => loc.smileIdResultIdDocFailed,
    SmileIdResultKey.livenessFailed => loc.smileIdResultLivenessFailed,
    SmileIdResultKey.expiredDoc => loc.smileIdResultExpiredDoc,
    SmileIdResultKey.infoMismatch => loc.smileIdResultInfoMismatch,
    SmileIdResultKey.unsupportedDoc => loc.smileIdResultUnsupportedDoc,
    SmileIdResultKey.faceNotDetected => loc.smileIdResultFaceNotDetected,
    SmileIdResultKey.multipleFacesDetected => loc.smileIdResultMultipleFacesDetected,
    SmileIdResultKey.poorImageQuality => loc.smileIdResultPoorImageQuality,
    SmileIdResultKey.couldNotComplete => loc.smileIdResultCouldNotComplete,
  };
}

String resolveKycErrorMessage(AppLocalizations loc, KycErrorKey key) {
  return switch (key) {
    // Reuses cleanup-3 keys (Decision ω from the C.1 spec).
    KycErrorKey.ninLength => loc.ninLengthError,
    KycErrorKey.bvnLength => loc.bvnLengthError,
    KycErrorKey.ssnitFormat => loc.ssnitFormatError,
    KycErrorKey.documentUploadNetwork => loc.kycErrorDocumentUploadNetwork,
    KycErrorKey.imageTooLarge => loc.kycErrorImageTooLarge,
    KycErrorKey.documentUploadGeneric => loc.kycErrorDocumentUploadGeneric,
    // Cross-enum reuse: KYC's fallback uses SmileID's couldNotComplete wording
    // because most KYC flows end in some kind of verification.
    KycErrorKey.fallback => loc.smileIdResultCouldNotComplete,
  };
}

String resolveFirebaseAuthErrorMessage(
  AppLocalizations loc,
  FirebaseAuthErrorKey key,
) {
  return switch (key) {
    FirebaseAuthErrorKey.network => loc.firebaseAuthErrorNetwork,
    FirebaseAuthErrorKey.tooManyRequests => loc.firebaseAuthErrorTooManyRequests,
    FirebaseAuthErrorKey.userNotFound => loc.firebaseAuthErrorUserNotFound,
    FirebaseAuthErrorKey.wrongPassword => loc.firebaseAuthErrorWrongPassword,
    FirebaseAuthErrorKey.emailAlreadyInUse => loc.firebaseAuthErrorEmailAlreadyInUse,
    FirebaseAuthErrorKey.invalidEmail => loc.firebaseAuthErrorInvalidEmail,
    FirebaseAuthErrorKey.weakPassword => loc.firebaseAuthErrorWeakPassword,
    FirebaseAuthErrorKey.invalidPhoneNumber => loc.firebaseAuthErrorInvalidPhone,
    FirebaseAuthErrorKey.invalidVerificationCode => loc.firebaseAuthErrorInvalidVerificationCode,
    FirebaseAuthErrorKey.serviceUnavailable => loc.firebaseAuthErrorServiceUnavailable,
    FirebaseAuthErrorKey.operationNotAllowed => loc.firebaseAuthErrorOperationNotAllowed,
    FirebaseAuthErrorKey.fallback => loc.firebaseAuthErrorFallback,
  };
}
```

---

## Step 5 — Edit `lib/core/utils/error_handler.dart`

Three sub-edits, applied in order. **Old methods (`getMomoUserFriendlyMessage`, `getUserFriendlyMessage`, `getSmileIdUserFriendlyMessage`, `getKycErrorMessage`, `_getFirebaseUserFriendlyMessage`) are NOT touched — leave them byte-for-byte unchanged.**

### 5.1 — Add import for the new resolver file at the top of the file

The file currently has no imports (it's a pure-Dart utility). Add a single import line BEFORE the class declaration.

**Search** (the very first line of the file, used as a unique anchor):
```dart
/// Centralized error handling utility for user-friendly error messages
class ErrorHandler {
```

**Replace:**
```dart
import 'error_handler_localization_resolver.dart';

/// Centralized error handling utility for user-friendly error messages
class ErrorHandler {
```

### 5.2 — Add 5 new public classify methods

Insert the new methods between the last existing public method (`getKycErrorMessage`) and the `// PRIVATE HELPER METHODS` divider. The unique anchor is the closing `}` of `getKycErrorMessage` (line containing only `  }` after `return getUserFriendlyMessage(error);`) followed by the divider comment.

**Search:**
```dart
    return getUserFriendlyMessage(error);
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================
```

**Replace:**
```dart
    return getUserFriendlyMessage(error);
  }

  // ============================================================
  // CLASSIFY METHODS — return enum keys for localized resolution
  // ============================================================
  //
  // C.1 of cleanup-4: these methods classify errors into typed enum values
  // without performing any localization. UI and service consumers convert
  // the returned enum to a translated string via the resolver functions in
  // `error_handler_localization_resolver.dart`.
  //
  // The existing String-returning methods above (getMomoUserFriendlyMessage,
  // getUserFriendlyMessage, getSmileIdUserFriendlyMessage, getKycErrorMessage,
  // _getFirebaseUserFriendlyMessage) continue to work unchanged for backward
  // compatibility and will be migrated in cleanup-4 sub-batch C.5.
  //
  // IMPORTANT — TRANSITIONAL DUPLICATION:
  // The English text returned by the existing methods is duplicated in
  // app_en.arb. Until C.5 collapses the duplication, both must stay in sync.
  // When updating any English error string, update BOTH the hardcoded return
  // value AND the corresponding ARB key (search for the string in app_en.arb).

  /// Classify a Mobile Money error into a [MomoErrorKey].
  ///
  /// Unmatched errors return [MomoErrorKey.fallback], which the resolver maps
  /// to a generic "something went wrong" message. The OLD String-returning
  /// [getMomoUserFriendlyMessage] still falls through to the more specific
  /// [getUserFriendlyMessage] for unmatched cases — caller migration in
  /// cleanup-4 sub-batches accepts this minor specificity loss.
  static MomoErrorKey classifyMomoError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (isMomoNotConfiguredError(error) ||
        errorString.contains('config_missing') ||
        errorString.contains('service unavailable')) {
      return MomoErrorKey.notConfigured;
    }
    if (errorString.contains('rejected') || errorString.contains('declined')) {
      return MomoErrorKey.paymentDeclined;
    }
    if (errorString.contains('insufficient') || errorString.contains('not enough')) {
      return MomoErrorKey.insufficientFunds;
    }
    if (errorString.contains('invalid') && errorString.contains('phone')) {
      return MomoErrorKey.invalidPhone;
    }
    if (_isTimeoutError(errorString)) {
      return MomoErrorKey.paymentTimeout;
    }
    return MomoErrorKey.fallback;
  }

  /// Classify a generic error into a [GenericErrorKey].
  ///
  /// Firebase-specific errors return [GenericErrorKey.somethingWentWrong] from
  /// this method — callers that want Firebase-specific classification should
  /// call [classifyFirebaseAuthError] directly. The OLD [getUserFriendlyMessage]
  /// still routes Firebase errors to [_getFirebaseUserFriendlyMessage] for
  /// backward compatibility.
  static GenericErrorKey classifyUserError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Firebase errors are a separate category — fall through to the generic
    // fallback rather than cross-routing. C.2 will migrate Firebase callers
    // to classifyFirebaseAuthError directly.
    if (_isFirebaseError(errorString)) {
      return GenericErrorKey.somethingWentWrong;
    }
    if (_isNetworkError(errorString)) return GenericErrorKey.network;
    if (_isCameraPermissionError(errorString)) return GenericErrorKey.cameraPermission;
    if (_isUserCancelled(errorString)) return GenericErrorKey.userCancelled;
    if (_isFaceDetectionError(errorString)) return GenericErrorKey.faceDetection;
    if (_isFaceMismatchError(errorString)) return GenericErrorKey.faceMismatch;
    if (_isIdVerificationError(errorString)) return GenericErrorKey.idVerification;
    if (_isDocumentError(errorString)) return GenericErrorKey.document;
    if (_isServerError(errorString)) return GenericErrorKey.server;
    if (_isTimeoutError(errorString)) return GenericErrorKey.timeout;
    if (_isAuthError(errorString)) return GenericErrorKey.auth;
    return GenericErrorKey.somethingWentWrong;
  }

  /// Classify a Smile ID verification result into a [SmileIdResultKey].
  ///
  /// Unknown result codes (or the null/null case) return
  /// [SmileIdResultKey.couldNotComplete]. The OLD
  /// [getSmileIdUserFriendlyMessage] falls through to [getUserFriendlyMessage]
  /// for unknown codes when an error string is provided — the new method
  /// drops that cross-category routing per Decision β.
  static SmileIdResultKey classifySmileIdResult(String? resultCode, String? error) {
    if (resultCode != null) {
      switch (resultCode) {
        case '0810': return SmileIdResultKey.verified;
        case '0811': return SmileIdResultKey.faceMatchFailed;
        case '0812': return SmileIdResultKey.idDocFailed;
        case '0813': return SmileIdResultKey.livenessFailed;
        case '0814': return SmileIdResultKey.expiredDoc;
        case '0815': return SmileIdResultKey.infoMismatch;
        case '0816': return SmileIdResultKey.unsupportedDoc;
        case '0820': return SmileIdResultKey.faceNotDetected;
        case '0821': return SmileIdResultKey.multipleFacesDetected;
        case '0822': return SmileIdResultKey.poorImageQuality;
        default: return SmileIdResultKey.couldNotComplete;
      }
    }
    return SmileIdResultKey.couldNotComplete;
  }

  /// Classify a KYC operation error into a [KycErrorKey].
  ///
  /// Unknown operations and the `'biometric_kyc'` operation both return
  /// [KycErrorKey.fallback]. The OLD [getKycErrorMessage] handles these via
  /// cross-category routing through [getUserFriendlyMessage]; the new method
  /// collapses to a single fallback per Decision β. Callers needing finer
  /// classification should call [classifyUserError] or [classifySmileIdResult]
  /// directly.
  static KycErrorKey classifyKycError(String operation, dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (operation == 'id_validation') {
      if (errorString.contains('nin') || errorString.contains('national identification')) {
        return KycErrorKey.ninLength;
      }
      if (errorString.contains('bvn') || errorString.contains('bank verification')) {
        return KycErrorKey.bvnLength;
      }
      if (errorString.contains('ssnit')) {
        return KycErrorKey.ssnitFormat;
      }
      return KycErrorKey.fallback;
    }

    if (operation == 'document_upload') {
      if (_isNetworkError(errorString)) {
        return KycErrorKey.documentUploadNetwork;
      }
      if (errorString.contains('size') || errorString.contains('large')) {
        return KycErrorKey.imageTooLarge;
      }
      return KycErrorKey.documentUploadGeneric;
    }

    return KycErrorKey.fallback;
  }

  /// Classify a Firebase Auth error string into a [FirebaseAuthErrorKey].
  ///
  /// Mirrors the existing private [_getFirebaseUserFriendlyMessage] except
  /// that it returns an enum rather than a localized string.
  static FirebaseAuthErrorKey classifyFirebaseAuthError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network-request-failed') || errorString.contains('network')) {
      return FirebaseAuthErrorKey.network;
    }
    if (errorString.contains('too-many-requests')) {
      return FirebaseAuthErrorKey.tooManyRequests;
    }
    if (errorString.contains('user-not-found')) {
      return FirebaseAuthErrorKey.userNotFound;
    }
    if (errorString.contains('wrong-password')) {
      return FirebaseAuthErrorKey.wrongPassword;
    }
    if (errorString.contains('email-already-in-use')) {
      return FirebaseAuthErrorKey.emailAlreadyInUse;
    }
    if (errorString.contains('invalid-email')) {
      return FirebaseAuthErrorKey.invalidEmail;
    }
    if (errorString.contains('weak-password')) {
      return FirebaseAuthErrorKey.weakPassword;
    }
    if (errorString.contains('invalid-phone-number')) {
      return FirebaseAuthErrorKey.invalidPhoneNumber;
    }
    if (errorString.contains('invalid-verification-code')) {
      return FirebaseAuthErrorKey.invalidVerificationCode;
    }
    if (errorString.contains('service-unavailable')) {
      return FirebaseAuthErrorKey.serviceUnavailable;
    }
    if (errorString.contains('operation-not-allowed')) {
      return FirebaseAuthErrorKey.operationNotAllowed;
    }
    return FirebaseAuthErrorKey.fallback;
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================
```

### 5.3 — Delete the dead `.userFriendlyMessage` extension getter at the bottom of the file

This extension has zero consumers across `lib/` (verified in cleanup-4 round 1 investigation) and can be safely removed.

**Search:**
```dart
}

extension ErrorHandlerExtension on dynamic {
  String get userFriendlyMessage => ErrorHandler.getUserFriendlyMessage(this);
}
```

**Replace:**
```dart
}
```

---

## Step 6 — Verification (skip Flutter calls; run all greps)

Run this script after Steps 1-5 are complete. Every check must pass before committing.

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c1_verify.sh << 'VERIFY_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== A. Resolver file exists with correct enums and resolvers ===="
ls -la lib/core/utils/error_handler_localization_resolver.dart
echo "Enum declarations (expect 5):"
grep -cE "^enum [A-Z]" lib/core/utils/error_handler_localization_resolver.dart
echo "Resolver functions (expect 5):"
grep -cE "^String resolve" lib/core/utils/error_handler_localization_resolver.dart

echo ""
echo "==== B. ErrorHandler import added ===="
grep -n "error_handler_localization_resolver" lib/core/utils/error_handler.dart

echo ""
echo "==== C. New classify methods present (expect 5) ===="
grep -nE "^  static (MomoErrorKey|GenericErrorKey|SmileIdResultKey|KycErrorKey|FirebaseAuthErrorKey) classify" lib/core/utils/error_handler.dart

echo ""
echo "==== D. Dead extension removed (expect ZERO matches) ===="
grep -n "extension ErrorHandlerExtension" lib/core/utils/error_handler.dart || echo "PASS: extension removed"
grep -n "userFriendlyMessage =>" lib/core/utils/error_handler.dart || echo "PASS: getter removed"

echo ""
echo "==== E. Old methods still present and signatures unchanged ===="
grep -nE "^  static String (getMomoUserFriendlyMessage|getUserFriendlyMessage|getSmileIdUserFriendlyMessage|getKycErrorMessage|_getFirebaseUserFriendlyMessage)" lib/core/utils/error_handler.dart

echo ""
echo "==== F. ARB integrity — no data loss ===="
echo "Pre-cleanup-4 baseline (phase6-step9-cleanup-3-complete tag):"
git show phase6-step9-cleanup-3-complete:lib/l10n/app_en.arb 2>/dev/null | python3 -c "import json,sys; arb=json.load(sys.stdin); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'  Total: {len(arb)}, value: {v}, meta: {m}')"
echo "Current (after C.1):"
python3 -c "import json; arb=json.load(open('lib/l10n/app_en.arb')); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'  Total: {len(arb)}, value: {v}, meta: {m}')"
echo "(Difference must be exactly +42 value, +42 meta, +84 total)"
python3 << 'PYINNER'
import json, subprocess
old = json.loads(subprocess.check_output(['git','show','phase6-step9-cleanup-3-complete:lib/l10n/app_en.arb']))
new = json.load(open('lib/l10n/app_en.arb'))
lost = [k for k in old if k not in new]
mutated = [k for k in old if k in new and old[k] != new[k]]
print(f'  Lost keys: {len(lost)} {lost[:5] if lost else ""}')
print(f'  Mutated values: {len(mutated)} {mutated[:5] if mutated else ""}')
if not lost and not mutated:
    print('  PASS: All pre-existing keys preserved')
PYINNER

echo ""
echo "==== G. All 42 new EN keys present with exact expected values ===="
python3 << 'PYINNER'
import json
arb = json.load(open('lib/l10n/app_en.arb'))
expected = {
    "momoErrorNotConfigured": "Mobile Money is coming soon! This feature is not yet available. Please use Card or Bank Transfer instead.",
    "momoErrorPaymentDeclined": "Payment was declined. Please check your Mobile Money balance and try again.",
    "momoErrorInsufficientFunds": "Insufficient funds in your Mobile Money account.",
    "momoErrorInvalidPhone": "Invalid phone number. Please check and try again.",
    "momoErrorPaymentTimeout": "Payment request timed out. Please check your phone for approval prompt and try again.",
    "genericErrorNetwork": "Unable to connect. Please check your internet connection and try again.",
    "genericErrorCameraPermission": "Camera access is required for verification. Please enable camera permissions in your device settings.",
    "genericErrorUserCancelled": "Verification was cancelled. You can try again when ready.",
    "genericErrorFaceDetection": "We couldn't detect your face clearly. Please ensure good lighting and position your face within the frame.",
    "genericErrorFaceMismatch": "Face verification failed. The selfie doesn't match the ID photo. Please ensure you're using your own ID document.",
    "genericErrorIdVerification": "ID verification failed. Please ensure your ID is valid, not expired, and the information entered is correct.",
    "genericErrorDocument": "We couldn't read your document clearly. Please ensure the document is well-lit, flat, and all text is visible.",
    "genericErrorServer": "Our verification service is temporarily unavailable. Please try again in a few minutes.",
    "genericErrorTimeout": "The request took too long. Please check your connection and try again.",
    "genericErrorAuth": "Your session has expired. Please sign in again to continue.",
    "genericErrorFallback": "Something went wrong. Please try again or contact support if the problem persists.",
    "smileIdResultVerified": "Verification successful!",
    "smileIdResultFaceMatchFailed": "Face verification failed. The selfie doesn't match the ID photo.",
    "smileIdResultIdDocFailed": "ID document could not be verified. Please try with a different document.",
    "smileIdResultLivenessFailed": "Liveness check failed. Please follow the on-screen instructions carefully.",
    "smileIdResultExpiredDoc": "Document is expired. Please use a valid, non-expired ID.",
    "smileIdResultInfoMismatch": "ID information mismatch. Please ensure you entered the correct details.",
    "smileIdResultUnsupportedDoc": "Document not supported. Please try with a different ID type.",
    "smileIdResultFaceNotDetected": "Face not detected. Please ensure your face is clearly visible and well-lit.",
    "smileIdResultMultipleFacesDetected": "Multiple faces detected. Please ensure only your face is in the frame.",
    "smileIdResultPoorImageQuality": "Poor image quality. Please ensure good lighting and a clear photo.",
    "smileIdResultCouldNotComplete": "Verification could not be completed. Please try again.",
    "kycErrorDocumentUploadNetwork": "Failed to upload document. Please check your connection and try again.",
    "kycErrorImageTooLarge": "Image file is too large. Please use a smaller image.",
    "kycErrorDocumentUploadGeneric": "Failed to upload document. Please try again.",
    "firebaseAuthErrorNetwork": "Unable to connect. Please check your internet connection.",
    "firebaseAuthErrorTooManyRequests": "Too many attempts. Please wait a few minutes and try again.",
    "firebaseAuthErrorUserNotFound": "Account not found. Please check your credentials or sign up.",
    "firebaseAuthErrorWrongPassword": "Incorrect password. Please try again.",
    "firebaseAuthErrorEmailAlreadyInUse": "This email is already registered. Please sign in instead.",
    "firebaseAuthErrorInvalidEmail": "Please enter a valid email address.",
    "firebaseAuthErrorWeakPassword": "Password is too weak. Please use at least 6 characters.",
    "firebaseAuthErrorInvalidPhone": "Please enter a valid phone number.",
    "firebaseAuthErrorInvalidVerificationCode": "Invalid verification code. Please check and try again.",
    "firebaseAuthErrorServiceUnavailable": "Service temporarily unavailable. Please try again later.",
    "firebaseAuthErrorOperationNotAllowed": "You don't have permission to perform this action.",
    "firebaseAuthErrorFallback": "Something went wrong. Please try again.",
}
missing, mismatched, no_meta = [], [], []
for k, v in expected.items():
    if k not in arb: missing.append(k)
    elif arb[k] != v: mismatched.append((k, arb[k][:60], v[:60]))
    if "@"+k not in arb: no_meta.append(k)
print(f'  Missing: {len(missing)}')
print(f'  Mismatched: {len(mismatched)} {mismatched[:3]}')
print(f'  Missing @-metadata: {len(no_meta)}')
if not (missing or mismatched or no_meta):
    print(f'  PASS: All 42 new keys with exact expected values + @-metadata')
PYINNER

echo ""
echo "==== H. fr/ar placeholders all present and empty ===="
for lang in fr ar; do
  echo "  -- app_${lang}.arb --"
  python3 - "$lang" << 'PYINNER'
import json, sys
lang = sys.argv[1]
arb = json.load(open(f'lib/l10n/app_{lang}.arb'))
new_keys = ["momoErrorNotConfigured","momoErrorPaymentDeclined","momoErrorInsufficientFunds","momoErrorInvalidPhone","momoErrorPaymentTimeout","genericErrorNetwork","genericErrorCameraPermission","genericErrorUserCancelled","genericErrorFaceDetection","genericErrorFaceMismatch","genericErrorIdVerification","genericErrorDocument","genericErrorServer","genericErrorTimeout","genericErrorAuth","genericErrorFallback","smileIdResultVerified","smileIdResultFaceMatchFailed","smileIdResultIdDocFailed","smileIdResultLivenessFailed","smileIdResultExpiredDoc","smileIdResultInfoMismatch","smileIdResultUnsupportedDoc","smileIdResultFaceNotDetected","smileIdResultMultipleFacesDetected","smileIdResultPoorImageQuality","smileIdResultCouldNotComplete","kycErrorDocumentUploadNetwork","kycErrorImageTooLarge","kycErrorDocumentUploadGeneric","firebaseAuthErrorNetwork","firebaseAuthErrorTooManyRequests","firebaseAuthErrorUserNotFound","firebaseAuthErrorWrongPassword","firebaseAuthErrorEmailAlreadyInUse","firebaseAuthErrorInvalidEmail","firebaseAuthErrorWeakPassword","firebaseAuthErrorInvalidPhone","firebaseAuthErrorInvalidVerificationCode","firebaseAuthErrorServiceUnavailable","firebaseAuthErrorOperationNotAllowed","firebaseAuthErrorFallback"]
missing = [k for k in new_keys if k not in arb]
non_empty = [k for k in new_keys if k in arb and arb[k] != ""]
print(f'    Missing: {len(missing)}')
print(f'    Non-empty: {len(non_empty)} {non_empty[:3] if non_empty else ""}')
PYINNER
done

echo ""
echo "==== I. Sanity — old methods STILL present and unchanged ===="
echo "Old method bodies' first lines (compared to baseline):"
echo "Current getMomoUserFriendlyMessage line:"
grep -n "static String getMomoUserFriendlyMessage" lib/core/utils/error_handler.dart
echo "Baseline getMomoUserFriendlyMessage line (must be at the same line number):"
git show phase6-step9-cleanup-3-complete:lib/core/utils/error_handler.dart | grep -n "static String getMomoUserFriendlyMessage"
echo ""
echo "If line numbers DIFFER above, the old methods were modified — investigate before commit."
VERIFY_EOF

bash /tmp/cleanup4_c1_verify.sh
```

**Pass criteria:**
- A: 5 enum declarations, 5 resolver functions
- B: import line present
- C: 5 new classify methods, one per category
- D: extension and getter removed (both grep returns "PASS")
- E: 5 old methods present
- F: 0 lost keys, 0 mutated values; total counts diff +42 value, +42 meta
- G: 0 missing, 0 mismatched, 0 missing-metadata
- H: 0 missing, 0 non-empty in both fr and ar
- I: getMomoUserFriendlyMessage line number matches baseline (line 24); if it differs, old methods were touched — STOP

If any check fails, STOP and report. Do not auto-fix.

---

## Step 7 — Commit on feature branch (no main push, no tag)

```bash
git add lib/core/utils/error_handler.dart \
        lib/core/utils/error_handler_localization_resolver.dart \
        lib/l10n/app_en.arb \
        lib/l10n/app_fr.arb \
        lib/l10n/app_ar.arb

git commit -m "9.cleanup-4-C1: ErrorHandler localization infrastructure

- Add 5 typed error enums (MomoErrorKey, GenericErrorKey, SmileIdResultKey,
  KycErrorKey, FirebaseAuthErrorKey) and 5 corresponding resolver functions in
  new file lib/core/utils/error_handler_localization_resolver.dart
- Add 5 new public classify methods to ErrorHandler that return enum keys
- Delete dead .userFriendlyMessage extension getter (zero consumers)
- 42 new ARB keys added with @-metadata; fr/ar placeholders ready for Step 10
- 3 cleanup-3 keys reused (ninLengthError, bvnLengthError, ssnitFormatError)
- 2 same-batch cross-enum reuses (MomoErrorKey.fallback -> genericErrorFallback,
  KycErrorKey.fallback -> smileIdResultCouldNotComplete)
- Existing String-returning methods unchanged for backward compatibility;
  C.5 will collapse the transitional duplication
- C.2-C.5 will progressively migrate service callers, wrapper types, and
  UI screens to consume the new enum-based API

First sub-batch of cleanup-4 (5 sub-batches total). Resolves no orphan yet —
this is infrastructure that C.2-C.5 build on. Predecessor:
phase6-step9-cleanup-3-complete @ 42219c34."

git push -u origin cleanup-4-c1-error-handler-infrastructure
```

**Do NOT push to main. Do NOT merge. Do NOT create the `phase6-step9-cleanup-4-c1-complete` tag — the human reviewer does both after verification.**

---

## Verification checklist (for the human reviewer after the agent finishes)

```bash
cd ~/Development/Projects/qr_wallet
git fetch origin
git checkout cleanup-4-c1-error-handler-infrastructure
git pull

# Run gen-l10n locally
flutter gen-l10n

# Capture regenerated files into the agent's commit
git add lib/generated/l10n/
git commit --amend --no-edit

# Verify analyzer count matches pre-flight baseline
flutter analyze 2>&1 | tail -3
# Expected: same total count as pre-flight (currently 204), 0 errors

# Run the verification script from Step 6 again — confirms nothing drifted
bash /tmp/cleanup4_c1_verify.sh

# Optional: build smoke test
flutter build apk --debug

# After all checks pass:
git checkout main
git merge --ff-only cleanup-4-c1-error-handler-infrastructure
git tag -a phase6-step9-cleanup-4-c1-complete -m "Phase 6 Step 9 cleanup-4 sub-batch C.1 complete — ErrorHandler localization infrastructure (5 enums, 5 resolvers, 42 new ARB keys). Pure infrastructure, no consumer migrations yet. C.2-C.5 will progressively migrate service callers, wrapper types, and UI screens."
git push origin main
git push origin phase6-step9-cleanup-4-c1-complete

# Tidy up
git branch -d cleanup-4-c1-error-handler-infrastructure
git push origin --delete cleanup-4-c1-error-handler-infrastructure
```

---

## Out of scope — for later sub-batches

These are NOT addressed in C.1. They are the planned scope of subsequent sub-batches:

- **C.2 (Auth surface):** Migrate `AuthResult` to carry `errorKey` alongside `error`. Migrate `auth_service.dart` direct `AuthResult.failure(...)` strings (~22 strings) and the private `_getAuthErrorMessage(e.code)` helper. Update auth UI consumers (login, signup, OTP, password reset screens) to resolve via `AppLocalizations`.
- **C.3 (User + Wallet surface):** Migrate `UserResult` and `WalletException` to carry `errorKey`. Migrate direct construction sites in `user_service.dart` and `wallet_service.dart` (~11 strings). Update consumers.
- **C.4 (Payment/Momo surface):** Investigate the 17 unmapped result types (PaymentResult, MomoPaymentResult, BiometricResult, QrVerificationResult, etc.) and migrate strings + add `errorKey` fields. Likely the largest sub-batch.
- **C.5 (UI fallback sweep + collapse transitional duplication):** Replace remaining hardcoded English fallbacks in screens (`result.error ?? 'Failed to complete verification'` patterns across ~7 KYC screens, profile, wallet). Collapse the duplicated English in `ErrorHandler` by making the old String-returning methods delegate to the new classify methods + the resolver. After C.5, all error text lives in ARB only.

After C.5, the cleanup-4 series is complete and Step 10 (translation) can proceed against a frozen English source.

## End of C.1 spec
