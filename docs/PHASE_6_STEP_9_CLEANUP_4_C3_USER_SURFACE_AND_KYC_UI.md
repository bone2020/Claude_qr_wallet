# Phase 6 Step 9 — Cleanup-4 (Sub-batch C.3): User Surface + KYC UI Localization

**Status:** READY TO IMPLEMENT
**Companion to:** `docs/PHASE_6_LOCALIZATION_SPEC.md`, `docs/PHASE_6_STEP_9_CLEANUP_4_C2_AUTH_SURFACE.md`
**Predecessor commit:** `66861755` (cleanup-4 C.2 + follow-up)
**Predecessor tag (C.2):** `phase6-step9-cleanup-4-c2-complete` @ `7f9bba8e`
**Target tag:** `phase6-step9-cleanup-4-c3-complete`

## Background

Cleanup-4 sub-batch C.2 shipped the auth surface migration. **C.3 covers the user surface + the full KYC UI sweep** — UserResult schema migration plus all hardcoded English strings in KYC verification screens. This is the broader "Option B" path chosen explicitly to complete KYC localization in one architectural sub-batch rather than splitting across C.3 and C.5.

C.3 covers:
- 7 hardcoded `UserResult.failure('English string')` calls in `user_service.dart` (5 of them duplicate `'User not authenticated'`)
- 7 `_showError(result.error ?? 'Failed to complete verification')` patterns across 7 KYC screens (UserResult consumers)
- 23 `_showError('English string')` and `_errorMessage = 'English string'` pure-UI validation calls across 9 KYC screens

Total: **37 hardcoded English strings migrated**, **13 new ARB keys** (4 UserResult enum keys + 9 KYC pure-UI keys), and **14 files modified**.

After C.3: when a French- or Arabic-locale user does any KYC flow (BVN, NIN, SSNIT, voters card, drivers license, passport, national ID, Uganda NIN) or hits any KYC validation error, they'll see translated text once Step 10 fills the fr/ar values.

## Out of scope for C.3 (deferred to C.5)

- **WalletException localization.** Investigation found zero `on WalletException catch` sites — every catcher uses generic `catch (e)` and reads `e.toString()`. Adding `errorKey` to WalletException would create dead code with no consumer. Deferred to C.5 alongside the "collapse transitional duplication" work.
- **The 4 unused UserResult-producing methods.** `updateProfile`, `updateProfilePhoto`, `saveSmileIdKycData`, `deleteAccount` — these methods exist in `user_service.dart` and produce UserResults, but no UI screen currently consumes them. Their 7 service-layer hardcoded strings are still migrated in C.3 (the producer side), but no UI consumer migration is needed because none exists. If a UI consumer is added in the future, it can use the `resolveUserResultError(loc, result)` helper that C.3 introduces.
- **C.5 also picks up:** UI fallback sweep in non-auth/non-KYC features (wallet, payment, send screens), plus removing transitional `error: String` fields where errorKey-based resolution has fully taken over.

## Architectural decisions (locked)

1. **Single nullable `errorKey` field on UserResult.** Mirrors C.2's pattern. UserResult gains `errorKey: UserErrorKey?` alongside the existing `error: String?`. The old String stays for backward compatibility (transitional, collapsed in C.5).

2. **One unified `UserErrorKey` enum** with 4 values (3 specific + 1 fallback). All current and foreseeable UserResult error paths are covered.

3. **No reuse of existing keys.** The cleanup-3 key `failedToCompleteVerification` is left in place but not referenced from C.3's resolver. The C.3 resolver uses `userErrorFallback` — a generic UserResult fallback. After C.3, `failedToCompleteVerification` becomes unreferenced (orphan flagged for C.5 hygiene cleanup).

4. **Pure-UI validation strings get domain-prefix ARB keys** (`kycError*`) rather than per-screen prefixes. The strings `'Please complete verification with Smile ID'` and `'Please select your date of birth'` are reused across 8 of the 9 KYC screens — one ARB key per unique string, referenced from multiple screens.

5. **Mandatory `loc` capture pattern.** Every method that gets edited must declare `final loc = AppLocalizations.of(context);` at the top of the method body, before any `await`, if such a capture is not already present. This is unconditional — even for sites that come before any await within the method, the rule is applied uniformly to prevent `use_build_context_synchronously` regressions like the one we hit in C.2 follow-up. Hot reload safety: capturing `loc` early is always correct because `AppLocalizations.of(context)` is cheap, idempotent, and guaranteed to return a usable instance synchronously.

6. **Migration patterns are strictly separated.** Three distinct patterns appear in this batch and the spec labels each site with its pattern letter. Agent must NOT mix them.
   - **Pattern X (UserResult consumer):** `_showError(result.error ?? 'English text')` → `_showError(resolveUserResultError(loc, result))`
   - **Pattern Y (pure-UI `_showError`):** `_showError('English text')` → `_showError(loc.kycErrorXxx)`
   - **Pattern Z (pure-UI `_errorMessage`):** `_errorMessage = 'English text'` (with or without `setState`) → `_errorMessage = loc.kycErrorXxx`

7. **Per-file str_replace boundaries.** Each str_replace operates on one file at a time using `replace_all=false` so that even when the same English string appears across multiple files, each migration is unambiguous within its file. The agent will edit one file end-to-end, verify, then move on.

## Scope summary

- **1 file edited (schema + 7 sites):** `lib/core/services/user_service.dart`
- **1 new file:** `lib/core/services/user_localization_resolver.dart`
- **9 KYC UI screens edited:**
  - `lib/features/auth/screens/kyc/bvn_verification_screen.dart` (3 sites: 2 Y + 1 X)
  - `lib/features/auth/screens/kyc/drivers_license_verification_screen.dart` (3 sites: 2 Y + 1 X)
  - `lib/features/auth/screens/kyc/national_id_verification_screen.dart` (3 sites: 2 Y + 1 X)
  - `lib/features/auth/screens/kyc/nin_verification_screen.dart` (6 sites: all Y; no UserResult consumer)
  - `lib/features/auth/screens/kyc/passport_verification_screen.dart` (3 sites: 2 Y + 1 X)
  - `lib/features/auth/screens/kyc/phone_verification_screen.dart` (2 sites: both Z; no UserResult consumer)
  - `lib/features/auth/screens/kyc/ssnit_verification_screen.dart` (3 sites: 2 Y + 1 X)
  - `lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart` (4 sites: 3 Y + 1 X)
  - `lib/features/auth/screens/kyc/voters_card_verification_screen.dart` (3 sites: 2 Y + 1 X)
- **3 ARB files modified:** `app_en.arb` (13 new keys with @-metadata), `app_fr.arb` and `app_ar.arb` (13 placeholders each)

**File count: 14.**

**Total UI site count by pattern:**
- Pattern X: 7 (one per UserResult-consuming KYC screen)
- Pattern Y: 21 (across 8 of the 9 KYC screens)
- Pattern Z: 2 (phone_verification_screen.dart only)
- Service-layer migrations in user_service.dart: 7

**Total: 37 string migrations.**

## Pre-flight check

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c3_preflight.sh << 'PREFLIGHT_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== Capture analyzer baseline (must match post-fix exactly) ===="
flutter analyze 2>&1 | tail -3

echo ""
echo "==== Confirm origin/main is at C.2 + follow-up commit (66861755) ===="
git fetch origin
git rev-parse origin/main

echo ""
echo "==== Confirm C.2 infrastructure is in place ===="
[ -f lib/core/services/auth_localization_resolver.dart ] && echo "PASS: auth_localization_resolver.dart exists" || echo "FAIL: missing"
grep -nE "^enum AuthErrorKey" lib/core/services/auth_localization_resolver.dart && echo "PASS: AuthErrorKey enum exists" || echo "FAIL: missing"

echo ""
echo "==== Confirm C.3 target file is unchanged (UserResult class still has 3-field shape) ===="
sed -n '/^class UserResult/,/^}/p' lib/core/services/user_service.dart

echo ""
echo "==== Confirm new resolver file does not yet exist ===="
[ -f lib/core/services/user_localization_resolver.dart ] && echo "ALREADY EXISTS — STOP" || echo "Does not exist yet — OK"

echo ""
echo "==== Working tree must be clean ===="
git status --short
PREFLIGHT_EOF

bash /tmp/cleanup4_c3_preflight.sh
```

**Expected:** analyzer at 204; origin/main at `66861755`; C.2 resolver file exists with AuthErrorKey enum; UserResult class shows the existing 3-field shape (`success`, `user`, `error`) without errorKey; new resolver file does not yet exist; working tree clean.

---

## Step 1 — Add 13 new keys to `lib/l10n/app_en.arb`

```bash
python3 << 'PYEOF'
import json

ARB_PATH = "lib/l10n/app_en.arb"

NEW_KEYS = [
    # UserResult enum keys (4)
    ("userErrorUserNotAuthenticated",
     "User not authenticated",
     "Shown when an action requires authentication but the user is not signed in."),
    ("userErrorNoUpdatesProvided",
     "No updates provided",
     "Shown when an updateProfile call is made with no fields to update."),
    ("userErrorIdFrontImageRequired",
     "ID front image is required",
     "Shown when KYC document upload is missing the required ID front image."),
    ("userErrorFallback",
     "Couldn't complete the action. Please try again.",
     "Generic UserResult fallback when no specific case applies."),

    # KYC pure-UI validation keys (9)
    ("kycErrorPleaseCompleteSmileId",
     "Please complete verification with Smile ID",
     "Shown across KYC screens when the Smile ID flow has not been completed yet."),
    ("kycErrorPleaseSelectDateOfBirth",
     "Please select your date of birth",
     "Shown across KYC screens when the user attempts to submit without selecting a DOB."),
    ("kycErrorPleaseSelectDateOfBirthBeforeSelfie",
     "Please select your date of birth before taking the selfie",
     "Shown specifically in the NIN flow when the user tries to take the selfie before entering their DOB."),
    ("kycErrorPleaseEnterCardNumber",
     "Please enter your card number",
     "Shown specifically in the Uganda NIN flow when the user attempts to submit without entering a card number."),
    ("kycErrorNotSignedIn",
     "You are not signed in. Please sign in and try again.",
     "Shown specifically in the NIN flow when the auth session is missing."),
    ("kycErrorVerificationSessionExpired",
     "Verification session expired. Please retake your selfie.",
     "Shown specifically in the NIN flow when the verification session has timed out."),
    ("kycErrorSomethingWentWrong",
     "Something went wrong. Please try again.",
     "Generic NIN-flow fallback when verification fails for an unspecified reason."),
    ("kycErrorPhoneVerificationNoPhoneNumber",
     "No phone number found on your account. Please go back and re-enter it.",
     "Shown in the phone verification flow when the user's account has no phone number on file."),
    ("kycErrorPhoneVerificationEnter6DigitCode",
     "Please enter the 6-digit code",
     "Shown in the phone verification flow when the user submits without entering the OTP."),
]

assert len(NEW_KEYS) == 13, f"Expected 13, got {len(NEW_KEYS)}"

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

**Expected:** `Added 13 keys`, `Skipped 0 keys: []`.

---

## Step 2 — Add 13 placeholder keys to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb`

```bash
python3 << 'PYEOF'
import json

NEW_KEY_NAMES = [
    "userErrorUserNotAuthenticated", "userErrorNoUpdatesProvided",
    "userErrorIdFrontImageRequired", "userErrorFallback",
    "kycErrorPleaseCompleteSmileId", "kycErrorPleaseSelectDateOfBirth",
    "kycErrorPleaseSelectDateOfBirthBeforeSelfie", "kycErrorPleaseEnterCardNumber",
    "kycErrorNotSignedIn", "kycErrorVerificationSessionExpired",
    "kycErrorSomethingWentWrong", "kycErrorPhoneVerificationNoPhoneNumber",
    "kycErrorPhoneVerificationEnter6DigitCode",
]

assert len(NEW_KEY_NAMES) == 13, f"Expected 13, got {len(NEW_KEY_NAMES)}"

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

**Expected:** both files report `added 13, skipped 0`.

---

## Step 3 — `flutter gen-l10n` (SKIPPED BY THE AGENT)

The human reviewer runs this locally after pulling the feature branch.

---

## Step 4 — Create new file `lib/core/services/user_localization_resolver.dart`

```dart
import '../../generated/l10n/app_localizations.dart';
import 'user_service.dart';

/// Identifies the kind of user-result error carried by [UserResult.errorKey].
///
/// Mirrors the C.2 pattern (AuthErrorKey): a single enum captures every
/// error path, with a single resolver function and a single field on the
/// result class.
enum UserErrorKey {
  userNotAuthenticated,
  noUpdatesProvided,
  idFrontImageRequired,
  fallback,
}

/// Resolves a [UserErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch — adding a new enum value without
/// a matching case here is a compile error.
String resolveUserErrorMessage(AppLocalizations loc, UserErrorKey key) {
  return switch (key) {
    UserErrorKey.userNotAuthenticated => loc.userErrorUserNotAuthenticated,
    UserErrorKey.noUpdatesProvided => loc.userErrorNoUpdatesProvided,
    UserErrorKey.idFrontImageRequired => loc.userErrorIdFrontImageRequired,
    UserErrorKey.fallback => loc.userErrorFallback,
  };
}

/// One-line resolver for UI consumers. Picks the best message available:
///
///   1. If [UserResult.errorKey] is non-null, resolve via [resolveUserErrorMessage].
///   2. Else if [UserResult.error] is non-null (transitional during C.3-C.4),
///      return it as-is.
///   3. Else return the generic user-result fallback.
///
/// UI screens should call this rather than reading [UserResult.error] directly.
String resolveUserResultError(AppLocalizations loc, UserResult result) {
  if (result.errorKey != null) {
    return resolveUserErrorMessage(loc, result.errorKey!);
  }
  return result.error ?? loc.userErrorFallback;
}
```

---

## Step 5 — Edit `lib/core/services/user_service.dart`

The agent should view the file in full before applying edits.

### 5.1 — Add resolver import at top of file

Locate the existing import block in `user_service.dart`. The agent should add an import for the new resolver alongside the existing imports. Exact placement: after the last `import` statement at the top of the file (preserving the file's existing import grouping conventions).

**Search:**
```dart
import '../utils/error_handler.dart';
```

If that exact import is not present, the agent should view the import block and add `import 'user_localization_resolver.dart';` alongside the existing `import` statements at the top of the file.

**Replace:**
```dart
import '../utils/error_handler.dart';
import 'user_localization_resolver.dart';
```

If the search anchor doesn't exist verbatim, the agent should add `import 'user_localization_resolver.dart';` after the last existing import in the file using a different but unambiguous anchor.

### 5.2 — Update `UserResult` class to add `errorKey` field

The class definition is at approximately line 474. Verify with `grep -n "^class UserResult" lib/core/services/user_service.dart`.

**Search:**
```dart
class UserResult {
  final bool success;
  final UserModel? user;
  final String? error;

  UserResult._({
    required this.success,
    this.user,
    this.error,
  });

  factory UserResult.success(UserModel? user) {
    return UserResult._(success: true, user: user);
  }

  factory UserResult.failure(String error) {
    return UserResult._(success: false, error: error);
  }
}
```

**Replace:**
```dart
class UserResult {
  final bool success;
  final UserModel? user;
  final String? error;
  final UserErrorKey? errorKey;

  UserResult._({
    required this.success,
    this.user,
    this.error,
    this.errorKey,
  });

  factory UserResult.success(UserModel? user) {
    return UserResult._(success: true, user: user);
  }

  factory UserResult.failure(String error, {UserErrorKey? errorKey}) {
    return UserResult._(success: false, error: error, errorKey: errorKey);
  }
}
```

### 5.3 — Migrate the 7 service-layer `UserResult.failure(...)` sites

Each migration adds an `errorKey:` parameter. The English string stays for backward compat (transitional, collapsed in C.5).

**5 occurrences of `'User not authenticated'`** at approximately lines 63, 98, 158, 290, 430. The exact text is identical in all 5 occurrences. The agent should use `replace_all=true` for this single str_replace.

**Search:**
```dart
return UserResult.failure('User not authenticated');
```

**Replace:**
```dart
return UserResult.failure('User not authenticated', errorKey: UserErrorKey.userNotAuthenticated);
```

(Use `replace_all=true` — there are 5 identical occurrences.)

**1 occurrence of `'No updates provided'`** at approximately line 75.

**Search:**
```dart
return UserResult.failure('No updates provided');
```

**Replace:**
```dart
return UserResult.failure('No updates provided', errorKey: UserErrorKey.noUpdatesProvided);
```

**1 occurrence of `'ID front image is required'`** at approximately line 163.

**Search:**
```dart
return UserResult.failure('ID front image is required');
```

**Replace:**
```dart
return UserResult.failure('ID front image is required', errorKey: UserErrorKey.idFrontImageRequired);
```

### 5.4 — Verification of Step 5

Before moving to Step 6, the agent runs:

```bash
grep -nE "UserResult\.failure\(" lib/core/services/user_service.dart
```

**Expected: 7 matches, every single one of them containing `errorKey: UserErrorKey.X`.** If any match shows a bare `UserResult.failure('English')` without `errorKey:`, STOP and re-investigate.

---

## Step 6 — UI screen migrations

**CRITICAL: Apply the mandatory `loc` capture pattern to every method that gets edited.** For each file below:

1. View the file to understand its structure.
2. For each site to migrate, identify the enclosing method.
3. If that method does NOT already have `final loc = AppLocalizations.of(context);` near its top (before any `await` or any setState), add it as the first statement of the method body. (Idempotent: skip if already present.)
4. Apply the migration using the labeled pattern (X, Y, or Z).
5. After all sites in a file are migrated, run a per-file verification grep before moving on.

The migration table for each file is below. Line numbers are approximate — the agent should use `grep -n` to confirm the exact location of each site before each str_replace.

### 6.1 — `lib/features/auth/screens/kyc/bvn_verification_screen.dart` (3 sites)

**Add import** at top of file (alongside other imports):
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 126 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 131 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 224 | X | `_showError(result.error ?? 'Failed to complete verification');` | `_showError(resolveUserResultError(loc, result));` |

`loc` capture: agent confirms the enclosing method(s) for sites L126, L131, L224 each have `final loc = AppLocalizations.of(context);` near the top of the method body before any await. Add if missing.

### 6.2 — `lib/features/auth/screens/kyc/drivers_license_verification_screen.dart` (3 sites)

**Add import:**
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 108 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 113 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 193 | X | `_showError(result.error ?? 'Failed to complete verification');` | `_showError(resolveUserResultError(loc, result));` |

`loc` capture: required for sites L108, L113, L193.

### 6.3 — `lib/features/auth/screens/kyc/national_id_verification_screen.dart` (3 sites)

**Add import:**
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

This screen already has 25 `AppLocalizations.of(context)` references and 1 `final loc = ...` capture from cleanup-3. Some methods may already have `loc` captured; others may not. Agent verifies per method.

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 197 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 202 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 301 | X | `_showError(result.error ?? AppLocalizations.of(context).failedToCompleteVerification);` | `_showError(resolveUserResultError(loc, result));` |

Site L301 is a special case — it already partially uses `AppLocalizations.of(context)` from cleanup-3. The migration replaces both the `result.error` String reading AND the `AppLocalizations.of(context).failedToCompleteVerification` fallback with the unified resolver call.

`loc` capture: required for sites L197, L202, L301.

### 6.4 — `lib/features/auth/screens/kyc/nin_verification_screen.dart` (6 sites — all Pattern Y; no UserResult consumer)

**Add import:** there is no UserResult consumer in this file, so the resolver import is NOT needed. This file only adds 0 imports.

Wait — the agent should check whether `AppLocalizations` is already imported in this file. If not, add:
```dart
import '../../../../generated/l10n/app_localizations.dart';
```
(per the C.2 investigation, all KYC screens already import AppLocalizations, so this should already be present)

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 75 | Y | `_showError('Please select your date of birth before taking the selfie');` | `_showError(loc.kycErrorPleaseSelectDateOfBirthBeforeSelfie);` |
| 144 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 149 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 179 | Y | `_showError('You are not signed in. Please sign in and try again.');` | `_showError(loc.kycErrorNotSignedIn);` |
| 183 | Y | `_showError('Verification session expired. Please retake your selfie.');` | `_showError(loc.kycErrorVerificationSessionExpired);` |
| 235 | Y | `_showError('Something went wrong. Please try again.');` | `_showError(loc.kycErrorSomethingWentWrong);` |

`loc` capture: required for every method containing any of these 6 sites. Multiple methods are likely; agent verifies each one.

### 6.5 — `lib/features/auth/screens/kyc/passport_verification_screen.dart` (3 sites)

**Add import:**
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 108 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 113 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 193 | X | `_showError(result.error ?? 'Failed to complete verification');` | `_showError(resolveUserResultError(loc, result));` |

`loc` capture: required.

### 6.6 — `lib/features/auth/screens/kyc/phone_verification_screen.dart` (2 sites — both Pattern Z; no UserResult consumer)

This file was edited in C.2 for the AuthResult migration. The C.2 edit at L205 used `AppLocalizations.of(context)` inline rather than capturing `loc`. While we're touching this file, the agent should ALSO refactor the C.2 site to use the captured `loc`. This is a small bonus cleanup, not introducing risk because the file is being touched anyway.

**No new import needed** (AppLocalizations already imported; UserResult/resolver not used in this file).

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 109 | Z | `_errorMessage = 'No phone number found on your account. Please go back and re-enter it.';` | `_errorMessage = loc.kycErrorPhoneVerificationNoPhoneNumber;` |
| 163 | Z | `setState(() => _errorMessage = 'Please enter the 6-digit code');` | `setState(() => _errorMessage = loc.kycErrorPhoneVerificationEnter6DigitCode);` |
| (existing C.2 site, ~L205) | bonus cleanup | `_errorMessage = resolveAuthResultError(AppLocalizations.of(context), result);` | `_errorMessage = resolveAuthResultError(loc, result);` |

`loc` capture: required for each affected method. The agent should view the file to determine which methods enclose L109, L163, and L205, and add `final loc = AppLocalizations.of(context);` to the top of each.

### 6.7 — `lib/features/auth/screens/kyc/ssnit_verification_screen.dart` (3 sites)

**Add import:**
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 126 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 131 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 225 | X | `_showError(result.error ?? 'Failed to complete verification');` | `_showError(resolveUserResultError(loc, result));` |

`loc` capture: required.

### 6.8 — `lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart` (4 sites)

**Add import:**
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 88 | Y | `_showError('Please enter your card number');` | `_showError(loc.kycErrorPleaseEnterCardNumber);` |
| 139 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 144 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 241 | X | `_showError(result.error ?? 'Failed to complete verification');` | `_showError(resolveUserResultError(loc, result));` |

`loc` capture: required for each method.

### 6.9 — `lib/features/auth/screens/kyc/voters_card_verification_screen.dart` (3 sites)

**Add import:**
```dart
import '../../../../core/services/user_localization_resolver.dart';
```

| Line (approx) | Pattern | Old | New |
|---|---|---|---|
| 108 | Y | `_showError('Please complete verification with Smile ID');` | `_showError(loc.kycErrorPleaseCompleteSmileId);` |
| 113 | Y | `_showError('Please select your date of birth');` | `_showError(loc.kycErrorPleaseSelectDateOfBirth);` |
| 193 | X | `_showError(result.error ?? 'Failed to complete verification');` | `_showError(resolveUserResultError(loc, result));` |

`loc` capture: required.

---

## Step 7 — Verification (skip Flutter calls; run all greps)

```bash
cd ~/Development/Projects/qr_wallet

cat > /tmp/cleanup4_c3_verify.sh << 'VERIFY_EOF'
#!/bin/bash
cd ~/Development/Projects/qr_wallet

echo "==== A. Resolver file exists with correct shape ===="
ls -la lib/core/services/user_localization_resolver.dart
echo "Enum values (expect exactly 4):"
python3 << 'PYINNER'
import re
content = open('lib/core/services/user_localization_resolver.dart').read()
m = re.search(r'enum UserErrorKey \{(.*?)\n\}', content, re.DOTALL)
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
    print(f'  {"PASS" if len(values) == 4 else "FAIL"}')
PYINNER
echo ""
echo "Resolver functions (expect 2):"
grep -nE "^String resolve" lib/core/services/user_localization_resolver.dart

echo ""
echo "==== B. UserResult schema has new errorKey field ===="
sed -n '/^class UserResult/,/^}/p' lib/core/services/user_service.dart

echo ""
echo "==== C. user_service.dart resolver import added ===="
grep -n "user_localization_resolver" lib/core/services/user_service.dart

echo ""
echo "==== D. All 7 UserResult.failure sites use errorKey ===="
echo "Total UserResult.failure occurrences (expect 7):"
grep -cE "UserResult\.failure\(" lib/core/services/user_service.dart
echo ""
echo "Expect 7 with errorKey:"
grep -cE "UserResult\.failure\([^)]*errorKey:" lib/core/services/user_service.dart
echo ""
echo "Expect ZERO bare UserResult.failure(' calls:"
grep -nE "UserResult\.failure\('[^']*'\);" lib/core/services/user_service.dart && echo "FAIL" || echo "PASS — no bare failures"

echo ""
echo "==== E. ARB integrity vs C.2-final baseline ===="
git show phase6-step9-cleanup-4-c2-complete:lib/l10n/app_en.arb 2>/dev/null | python3 -c "import json,sys; arb=json.load(sys.stdin); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'Pre-C.3 baseline: total={len(arb)}, value={v}, meta={m}')"
python3 -c "import json; arb=json.load(open('lib/l10n/app_en.arb')); v=sum(1 for k in arb if not k.startswith(chr(64))); m=sum(1 for k in arb if k.startswith(chr(64))); print(f'Post-C.3: total={len(arb)}, value={v}, meta={m}')"
echo "(Difference must be exactly +13 value, +13 meta, +26 total)"
python3 << 'PYINNER'
import json, subprocess
old = json.loads(subprocess.check_output(['git','show','phase6-step9-cleanup-4-c2-complete:lib/l10n/app_en.arb']))
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
new_keys = ["userErrorUserNotAuthenticated","userErrorNoUpdatesProvided","userErrorIdFrontImageRequired","userErrorFallback","kycErrorPleaseCompleteSmileId","kycErrorPleaseSelectDateOfBirth","kycErrorPleaseSelectDateOfBirthBeforeSelfie","kycErrorPleaseEnterCardNumber","kycErrorNotSignedIn","kycErrorVerificationSessionExpired","kycErrorSomethingWentWrong","kycErrorPhoneVerificationNoPhoneNumber","kycErrorPhoneVerificationEnter6DigitCode"]
missing = [k for k in new_keys if k not in arb]
non_empty = [k for k in new_keys if k in arb and arb[k] != ""]
print(f'    Missing: {len(missing)}')
print(f'    Non-empty: {len(non_empty)}')
PYINNER
done

echo ""
echo "==== G. UI screens — Pattern X (resolveUserResultError) calls ===="
total_x=0
for f in lib/features/auth/screens/kyc/bvn_verification_screen.dart lib/features/auth/screens/kyc/drivers_license_verification_screen.dart lib/features/auth/screens/kyc/national_id_verification_screen.dart lib/features/auth/screens/kyc/passport_verification_screen.dart lib/features/auth/screens/kyc/ssnit_verification_screen.dart lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart lib/features/auth/screens/kyc/voters_card_verification_screen.dart; do
  count=$(grep -c "resolveUserResultError" "$f" 2>/dev/null || echo 0)
  total_x=$((total_x + count))
  echo "  $(basename $f): $count call(s)"
done
echo "  TOTAL Pattern X: $total_x (expected 7)"

echo ""
echo "==== H. UI screens — Pattern Y (loc.kycError* references in _showError) ===="
total_y=0
for f in lib/features/auth/screens/kyc/bvn_verification_screen.dart lib/features/auth/screens/kyc/drivers_license_verification_screen.dart lib/features/auth/screens/kyc/national_id_verification_screen.dart lib/features/auth/screens/kyc/nin_verification_screen.dart lib/features/auth/screens/kyc/passport_verification_screen.dart lib/features/auth/screens/kyc/ssnit_verification_screen.dart lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart lib/features/auth/screens/kyc/voters_card_verification_screen.dart; do
  count=$(grep -cE "_showError\(loc\.kycError" "$f" 2>/dev/null || echo 0)
  total_y=$((total_y + count))
  echo "  $(basename $f): $count call(s)"
done
echo "  TOTAL Pattern Y: $total_y (expected 21)"

echo ""
echo "==== I. UI screens — Pattern Z (loc.kycError* in _errorMessage) ===="
echo "phone_verification_screen.dart only:"
grep -cE "_errorMessage = loc\.kycError" lib/features/auth/screens/kyc/phone_verification_screen.dart
echo "(expected 2)"

echo ""
echo "==== J. NO leftover hardcoded English in KYC _showError or _errorMessage = patterns ===="
fail=0
for f in $(find lib/features/auth/screens/kyc -name "*.dart"); do
  hits=$(grep -nE "_showError\('[A-Z]|_errorMessage = '[A-Z]" "$f")
  if [ -n "$hits" ]; then
    fail=1
    echo "  FAIL — $f:"
    echo "$hits"
  fi
done
[ $fail -eq 0 ] && echo "  PASS — no leftover hardcoded English"

echo ""
echo "==== K. loc capture present in every edited UI method ===="
echo "(Every KYC file edited should contain at least 1 'final loc = AppLocalizations.of(context);' near method tops)"
for f in $(find lib/features/auth/screens/kyc -name "*.dart" | sort); do
  count=$(grep -c "final loc = AppLocalizations" "$f" 2>/dev/null || echo 0)
  echo "  $(basename $f): $count loc capture(s)"
done

echo ""
echo "==== L. Imports added to UserResult-consuming KYC screens ===="
for f in lib/features/auth/screens/kyc/bvn_verification_screen.dart lib/features/auth/screens/kyc/drivers_license_verification_screen.dart lib/features/auth/screens/kyc/national_id_verification_screen.dart lib/features/auth/screens/kyc/passport_verification_screen.dart lib/features/auth/screens/kyc/ssnit_verification_screen.dart lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart lib/features/auth/screens/kyc/voters_card_verification_screen.dart; do
  match=$(grep -c "user_localization_resolver" "$f" 2>/dev/null || echo 0)
  echo "  $(basename $f): $match import(s) (expect 1)"
done
VERIFY_EOF

bash /tmp/cleanup4_c3_verify.sh
```

**Pass criteria:**
- A: 4 enum values, 2 resolver functions
- B: UserResult class shows 4-field shape with errorKey
- C: 1 import line for user_localization_resolver
- D: 7 total UserResult.failure calls, all 7 with errorKey, 0 bare calls
- E: +13 value, +13 meta, +26 total; 0 lost, 0 mutated
- F: 0 missing, 0 non-empty in fr/ar
- G: 7 Pattern X calls total
- H: 21 Pattern Y calls total
- I: 2 Pattern Z calls in phone_verification_screen
- J: 0 leftover hardcoded English in any KYC `_showError` or `_errorMessage =` pattern
- K: every edited KYC file has at least 1 `final loc = ...` capture
- L: every UserResult-consuming KYC screen has 1 user_localization_resolver import (7 files)

If any check fails, STOP and report.

---

## Step 8 — Commit on feature branch

```bash
git add lib/core/services/user_service.dart \
        lib/core/services/user_localization_resolver.dart \
        lib/features/auth/screens/kyc/bvn_verification_screen.dart \
        lib/features/auth/screens/kyc/drivers_license_verification_screen.dart \
        lib/features/auth/screens/kyc/national_id_verification_screen.dart \
        lib/features/auth/screens/kyc/nin_verification_screen.dart \
        lib/features/auth/screens/kyc/passport_verification_screen.dart \
        lib/features/auth/screens/kyc/phone_verification_screen.dart \
        lib/features/auth/screens/kyc/ssnit_verification_screen.dart \
        lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart \
        lib/features/auth/screens/kyc/voters_card_verification_screen.dart \
        lib/l10n/app_en.arb \
        lib/l10n/app_fr.arb \
        lib/l10n/app_ar.arb

git commit -m "9.cleanup-4-C3: User surface + KYC UI localization (Option B)

- Add UserErrorKey enum (4 values: userNotAuthenticated, noUpdatesProvided,
  idFrontImageRequired, fallback) and 2 resolver functions in new file
  lib/core/services/user_localization_resolver.dart
- UserResult gains errorKey: UserErrorKey? field alongside existing error: String?
  for backward compatibility (transitional duplication, collapsed in C.5)
- 7 service-layer UserResult.failure() sites in user_service.dart migrated to
  populate both error String and errorKey enum (5 of them duplicates of
  'User not authenticated' migrated via replace_all=true)
- 7 UserResult-consuming KYC screens migrated to use resolveUserResultError()
  helper; 7 hardcoded 'Failed to complete verification' fallbacks deleted from UI
  without adding ARB keys for them (resolver always returns something)
- 23 pure-UI validation strings across 9 KYC screens migrated to direct ARB key
  lookups (loc.kycError*); 21 Pattern Y in _showError() + 2 Pattern Z in
  _errorMessage =  (phone_verification_screen.dart only)
- Mandatory loc capture pattern applied: every edited method gets
  'final loc = AppLocalizations.of(context);' at the top before any await,
  preventing use_build_context_synchronously regressions
- 13 new ARB keys: 4 user* (UserResult enum) + 9 kycError* (pure UI validation)
- nin_verification_screen.dart: 6 sites all Pattern Y; no UserResult consumer
- phone_verification_screen.dart: 2 sites Pattern Z; bonus cleanup of C.2's
  inline AppLocalizations.of(context) at the existing AuthResult resolution site
- Orphan flagged: ARB key 'failedToCompleteVerification' from cleanup-3 is now
  unreferenced (national_id_verification_screen.dart no longer uses it after
  migrating to resolveUserResultError); C.5 hygiene cleanup will remove it

Third sub-batch of cleanup-4 (5 sub-batches total). WalletException localization
deferred to C.5 because catchers don't type-narrow ('on WalletException catch'
appears 0 times in the codebase). Predecessor: phase6-step9-cleanup-4-c2-complete
@ 7f9bba8e + follow-up 66861755."

git push -u origin cleanup-4-c3-user-surface-and-kyc-ui
```

**Do NOT push to main. Do NOT merge. Do NOT create the tag — the human reviewer does both after verification.**

---

## Verification checklist (for the human reviewer after the agent finishes)

```bash
cd ~/Development/Projects/qr_wallet
git fetch origin
git checkout cleanup-4-c3-user-surface-and-kyc-ui
git pull

# Run gen-l10n locally
flutter gen-l10n

# Capture regenerated files into the agent's commit
git add lib/generated/l10n/
git commit --amend --no-edit

# Verify analyzer count matches pre-flight baseline
flutter analyze 2>&1 | tail -3
# Expected: 204 issues, 0 errors

# Re-run Step 7 verification script
bash /tmp/cleanup4_c3_verify.sh

# Optional: build smoke test
flutter build apk --debug

# After all checks pass:
git checkout main
git merge --ff-only cleanup-4-c3-user-surface-and-kyc-ui
git tag -a phase6-step9-cleanup-4-c3-complete -m "Phase 6 Step 9 cleanup-4 sub-batch C.3 complete — User surface + KYC UI localization (Option B). UserResult.errorKey field added; 13 new ARB keys (4 UserResult + 9 KYC pure-UI); 9 KYC screens migrated; 37 hardcoded English strings replaced. WalletException deferred to C.5."
git push origin main
git push origin phase6-step9-cleanup-4-c3-complete

git branch -D cleanup-4-c3-user-surface-and-kyc-ui
git push origin --delete cleanup-4-c3-user-surface-and-kyc-ui
```

---

## Out of scope — for later sub-batches

- **C.4 (Payment / Momo / Biometric / QR result types):** ~17 unmapped result classes from cleanup-3 round 1 investigation.
- **C.5 (UI fallback sweep + collapse transitional duplication + WalletException localization):**
  - WalletException migration (requires rewriting generic `catch (e)` to type-narrow with `on WalletException`)
  - Wallet/payment/send screens that have `result.error ?? 'English'` patterns from non-auth/non-user contexts
  - Removal of the orphaned `failedToCompleteVerification` ARB key
  - Collapse of transitional `error: String` field on AuthResult, UserResult once errorKey-based resolution is fully adopted everywhere

## End of C.3 spec
