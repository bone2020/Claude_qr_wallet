# Phase 6 Step 9 — Cleanup-3: `smile_id_service.dart` Localization

**Status:** READY TO IMPLEMENT
**Companion to:** `docs/PHASE_6_LOCALIZATION_SPEC.md`, `docs/PHASE_6_RESOLVED.md`, `docs/SESSION_HANDOVER_2026-05-06.md`
**Predecessor tag:** `phase6-step9-complete` @ `31d4501d`
**Target tag:** `phase6-step9-cleanup-3-complete`

## Background

The `phase6-step9-complete` handover deferred two orphans in `lib/core/services/smile_id_service.dart`:

1. **~8 validation error messages** inside `validateIdNumber()` and `SmileIDResult.fromJson()` — service-layer code with no `BuildContext`, so direct `AppLocalizations.of(context)` won't work.
2. **Country-specific dropdown labels** in the `countryIdTypes` static const map (~10 unique label strings across 30 countries) — same architectural problem.

Both are resolved here using **Option 2** from the handover (return error keys/codes from the service; callers resolve via `AppLocalizations`), with the dropdown labels folded in via a parallel mechanism.

## Architectural decisions (locked, do not change)

1. **Error keys are typed enums, not strings.** Compile-time safety, exhaustiveness checking via switch expressions.
2. **`IdValidationResult.error` field is REMOVED entirely** and replaced with `errorKey`. Build errors at every old call site are the safety net — they cannot be missed.
3. **`SmileIDResult.error` field is KEPT and `errorKey` is ADDED alongside.** External-source error strings (network, server) still need a free-form text channel; we don't break that. The new `errorKey` is populated only by the in-service `fromJson` parse-failure path.
4. **`SmileIDResult.fromJson` catch block populates BOTH** `error` (technical detail with `$e` for crash reports / log uploads) AND `errorKey` (user-facing translation key). Plus a new `debugPrint` for engineer-side logging.
5. **A new file `lib/core/services/smile_id_localization_resolver.dart`** holds the enums and the resolver functions. Service file stays free of `AppLocalizations` import.
6. **`countryIdTypes` static const map is NOT modified.** Its `'label'` strings remain as debug/documentation. The single consumer (`kyc_screen.dart:158`) switches from `idType['label']` to a resolver call keyed by `idType['value']`.
7. **Hardcoded English fallback strings** in 4 of the 5 caller screens (`'Invalid NIN'`, `'Invalid BVN'`, `'Invalid SSNIT number'`, `'Invalid NIN'`) are replaced with the existing ARB key `invalidIdNumberFallback` — no new translations needed for these.

## Scope summary

- **1 new file** created: `lib/core/services/smile_id_localization_resolver.dart`
- **1 file** edited at multiple sites: `lib/core/services/smile_id_service.dart`
- **5 caller screens** edited: each gets ~5 line change + 1 import
- **1 dropdown consumer** edited: `lib/features/auth/screens/kyc_screen.dart` (1 line + 1 import)
- **15 new ARB keys** added to `lib/l10n/app_en.arb` with metadata
- **15 placeholder keys** added to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb` (empty values for Step 10)
- **3 existing ARB keys reused**: `idNumberRequired`, `nationalId`, `driversLicense`
- **5 hardcoded English fallbacks** in caller screens migrated to the existing `invalidIdNumberFallback` key
- **`expectedFormat` field is left untouched** (dead-code observation flagged at end; not in scope)

---

## Pre-flight check (run before starting)

```bash
cd ~/Development/Projects/qr_wallet

# Capture analyzer baseline — must end at this number after the cleanup
flutter analyze 2>&1 | tail -3

# Confirm the import style used in caller screens (package: vs relative)
echo "==== Existing import style in caller screens ===="
grep "^import" lib/features/auth/screens/kyc/nin_verification_screen.dart | head -10

# Confirm the resolver doesn't already exist
echo "==== Resolver file existence check (should be 'No such file') ===="
ls -la lib/core/services/smile_id_localization_resolver.dart 2>&1 | head -1

# Confirm git is clean
git status --short
```

**Expected baseline:** Capture the exact issue count from the pre-flight `flutter analyze` output. As of this cleanup-3, the count is `204 issues found` (drifted up by 16 from the handover-era 188; this drift is pre-existing and not part of cleanup-3 scope). **Post-fix issue count must match the pre-flight count exactly.** A drop in count is acceptable only if it traces directly to a string we removed (e.g. an `avoid_print` lint disappearing because a `print` line was deleted). Investigate any other change.

**Confirmed import convention:** caller screens use **relative imports for in-project files** (e.g. `import '../../../../core/constants/constants.dart';`) and `package:` imports only for third-party packages. All new imports in this cleanup follow this convention. Do NOT use `package:qr_wallet/...` for own-code imports.

---

## Step 1 — Add 15 new keys to `lib/l10n/app_en.arb`

Run this Python script from the project root. It uses `json.dumps` per the handover's lessons (handles apostrophes in `"Voter's ID"`, `"Driver's License"` cleanly).

```python
python3 << 'PYEOF'
import json

ARB_PATH = "lib/l10n/app_en.arb"

# Order matters for diff readability — keys grouped by category
NEW_KEYS = [
    # Validation errors (6 new + 1 reuse of existing idNumberRequired)
    ("ninLengthError", "NIN must be exactly 11 digits",
     "Validation error shown when the user enters a NIN that is not exactly 11 digits."),
    ("bvnLengthError", "BVN must be exactly 11 digits",
     "Validation error shown when the user enters a BVN that is not exactly 11 digits."),
    ("ssnitFormatError", "SSNIT must be 1 letter followed by 12 digits",
     "Validation error shown when the user's SSNIT does not match the format: one letter followed by twelve digits."),
    ("southAfricanIdLengthError", "South African ID must be exactly 13 digits",
     "Validation error shown when the user's South African National ID is not exactly 13 digits."),
    ("ugandaNinFormatError", "Uganda NIN must be exactly 14 alphanumeric characters",
     "Validation error shown when the user's Uganda NIN does not match the expected 14 alphanumeric characters."),
    ("tpinLengthError", "TPIN must be exactly 10 digits",
     "Validation error shown when the user's Zambian TPIN is not exactly 10 digits."),

    # Smile ID parse failure (1 new)
    ("smileIdParseError", "Could not read verification result. Please try again.",
     "User-facing error shown when the app cannot parse the verification result returned by the Smile ID widget. Technical detail is logged separately."),

    # Dropdown labels (8 new + 2 reuses of existing nationalId, driversLicense)
    ("votersIdLabel", "Voter's ID",
     "Label for the 'Voter's ID' option in the KYC ID-type picker dropdown."),
    ("internationalPassportLabel", "International Passport",
     "Label for the 'International Passport' option in the KYC ID-type picker dropdown."),
    ("alienIdLabel", "Alien ID",
     "Label for the 'Alien ID' option in the KYC ID-type picker dropdown (Kenya only)."),
    ("ninFullLabel", "National Identification Number (NIN)",
     "Label for the long-form NIN option in the KYC ID-type picker dropdown (Nigeria; pending SmileID entitlement activation)."),
    ("bvnFullLabel", "Bank Verification Number (BVN)",
     "Label for the long-form BVN option in the KYC ID-type picker dropdown (Nigeria; pending SmileID entitlement activation)."),
    ("ssnitLabel", "SSNIT",
     "Label for the SSNIT option in the KYC ID-type picker dropdown (Ghana; pending SmileID entitlement activation)."),
    ("ugandaNationalIdLabel", "National ID (NIN)",
     "Label for the Uganda National ID option in the KYC ID-type picker dropdown (pending SmileID entitlement activation)."),
    ("tpinFullLabel", "Taxpayer PIN (TPIN)",
     "Label for the long-form Zambian TPIN option in the KYC ID-type picker dropdown (pending SmileID entitlement activation)."),
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

print(f"Added {len(added)} keys: {added}")
print(f"Skipped (already present) {len(skipped)} keys: {skipped}")
PYEOF
```

**Expected output:** `Added 15 keys: [...]`, `Skipped 0 keys: []`.

**If any key was skipped:** stop and investigate — it means a name collided with something already in the file.

---

## Step 2 — Add empty placeholder keys to `lib/l10n/app_fr.arb` and `lib/l10n/app_ar.arb`

Per the established Phase 6 Step 9 pattern, fr/ar get the keys with empty string values (no `@-metadata` — that's English-only).

```python
python3 << 'PYEOF'
import json

NEW_KEY_NAMES = [
    "ninLengthError",
    "bvnLengthError",
    "ssnitFormatError",
    "southAfricanIdLengthError",
    "ugandaNinFormatError",
    "tpinLengthError",
    "smileIdParseError",
    "votersIdLabel",
    "internationalPassportLabel",
    "alienIdLabel",
    "ninFullLabel",
    "bvnFullLabel",
    "ssnitLabel",
    "ugandaNationalIdLabel",
    "tpinFullLabel",
]

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

**Expected output:**
```
lib/l10n/app_fr.arb: added 15, skipped 0
lib/l10n/app_ar.arb: added 15, skipped 0
```

---

## Step 3 — Run `flutter gen-l10n`

```bash
flutter gen-l10n
```

This regenerates `lib/generated/l10n/app_localizations*.dart`. After this step, every new key (e.g. `ninLengthError`) is callable as `AppLocalizations.of(context).ninLengthError`.

**Expected output:** silent success, no errors. If gen-l10n complains about missing values in fr/ar, that's expected and benign for the new keys (Step 10 will fill them).

**Verify:** `grep -c "ninLengthError\|smileIdParseError\|votersIdLabel" lib/generated/l10n/app_localizations.dart` should return at least 3.

---

## Step 4 — Create new file `lib/core/services/smile_id_localization_resolver.dart`

**Full file content (create exactly as below):**

```dart
import '../../generated/l10n/app_localizations.dart';

/// Identifies the kind of validation failure produced by
/// [SmileIDService.validateIdNumber].
///
/// The service returns one of these values; the UI layer (which has a
/// [BuildContext]) calls [resolveIdValidationErrorMessage] to convert it
/// into a user-visible, translated message.
enum IdValidationErrorKey {
  idNumberRequired,
  ninLength,
  bvnLength,
  ssnitFormat,
  southAfricanIdLength,
  ugandaNinFormat,
  tpinLength,
}

/// Identifies the kind of in-service Smile ID failure carried by
/// [SmileIDResult.errorKey] when the service itself produced the error.
///
/// External errors (network, server, third-party SDK) still come through
/// [SmileIDResult.error] as free-form text — they do not get an [errorKey].
enum SmileIDErrorKey {
  parseResultFailed,
}

/// Resolves an [IdValidationErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch expression — adding a new enum
/// value without a matching case here is a compile error.
String resolveIdValidationErrorMessage(
  AppLocalizations loc,
  IdValidationErrorKey key,
) {
  return switch (key) {
    IdValidationErrorKey.idNumberRequired => loc.idNumberRequired,
    IdValidationErrorKey.ninLength => loc.ninLengthError,
    IdValidationErrorKey.bvnLength => loc.bvnLengthError,
    IdValidationErrorKey.ssnitFormat => loc.ssnitFormatError,
    IdValidationErrorKey.southAfricanIdLength => loc.southAfricanIdLengthError,
    IdValidationErrorKey.ugandaNinFormat => loc.ugandaNinFormatError,
    IdValidationErrorKey.tpinLength => loc.tpinLengthError,
  };
}

/// Resolves a [SmileIDErrorKey] into a translated, user-visible message.
String resolveSmileIdErrorMessage(
  AppLocalizations loc,
  SmileIDErrorKey key,
) {
  return switch (key) {
    SmileIDErrorKey.parseResultFailed => loc.smileIdParseError,
  };
}

/// Resolves an ID type's `value` string (e.g. `'NATIONAL_ID'`, `'VOTERS_ID'`)
/// into the translated dropdown label that the user sees in the KYC ID-type
/// picker.
///
/// Falls back to the raw value if the type is unknown — a defensive escape
/// hatch that keeps the picker usable if a new ID type is added to
/// `countryIdTypes` without a matching label entry here.
String resolveIdTypeLabel(AppLocalizations loc, String idTypeValue) {
  switch (idTypeValue) {
    case 'NATIONAL_ID':
      return loc.nationalId;
    case 'VOTERS_ID':
      return loc.votersIdLabel;
    case 'DRIVERS_LICENSE':
      return loc.driversLicense;
    case 'PASSPORT':
      return loc.internationalPassportLabel;
    case 'ALIEN_ID':
      return loc.alienIdLabel;
    case 'NIN':
      return loc.ninFullLabel;
    case 'BVN':
      return loc.bvnFullLabel;
    case 'SSNIT':
      return loc.ssnitLabel;
    case 'UGANDA_NIN':
      return loc.ugandaNationalIdLabel;
    case 'TPIN':
      return loc.tpinFullLabel;
    default:
      return idTypeValue;
  }
}
```

**Confirmed import convention:** the import line above uses relative paths for in-project files, matching the codebase convention. The path `../../generated/l10n/app_localizations.dart` resolves correctly from `lib/core/services/`. Do NOT change to `package:` style.

---

## Step 5 — Edit `lib/core/services/smile_id_service.dart`

Nine sub-edits. Apply in order. Each `str_replace` operation has a unique target — none of the search strings repeat in the file.

### 5.1 — Add import for the new resolver file

**Search:**
```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
```

**Replace:**
```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'smile_id_localization_resolver.dart';
```

### 5.2 — Replace `error: 'ID number is required'` with `errorKey:`

**Search:**
```dart
      return IdValidationResult(isValid: false, error: 'ID number is required');
```

**Replace:**
```dart
      return IdValidationResult(isValid: false, errorKey: IdValidationErrorKey.idNumberRequired);
```

### 5.3 — NIN error

**Search:**
```dart
            error: 'NIN must be exactly 11 digits',
```

**Replace:**
```dart
            errorKey: IdValidationErrorKey.ninLength,
```

### 5.4 — BVN error

**Search:**
```dart
            error: 'BVN must be exactly 11 digits',
```

**Replace:**
```dart
            errorKey: IdValidationErrorKey.bvnLength,
```

### 5.5 — SSNIT error

**Search:**
```dart
            error: 'SSNIT must be 1 letter followed by 12 digits',
```

**Replace:**
```dart
            errorKey: IdValidationErrorKey.ssnitFormat,
```

### 5.6 — South African ID error (note the deeper indentation — 14 spaces, not 12)

**Search:**
```dart
              error: 'South African ID must be exactly 13 digits',
```

**Replace:**
```dart
              errorKey: IdValidationErrorKey.southAfricanIdLength,
```

### 5.7 — Uganda NIN error

**Search:**
```dart
            error: 'Uganda NIN must be exactly 14 alphanumeric characters',
```

**Replace:**
```dart
            errorKey: IdValidationErrorKey.ugandaNinFormat,
```

### 5.8 — TPIN error

**Search:**
```dart
            error: 'TPIN must be exactly 10 digits',
```

**Replace:**
```dart
            errorKey: IdValidationErrorKey.tpinLength,
```

### 5.9 — Replace the `IdValidationResult` class definition (entire class block)

**Search:**
```dart
/// Result of ID number validation
class IdValidationResult {
  final bool isValid;
  final String? error;
  final String? expectedFormat;

  IdValidationResult({
    required this.isValid,
    this.error,
    this.expectedFormat,
  });
}
```

**Replace:**
```dart
/// Result of ID number validation.
///
/// When [isValid] is `false`, [errorKey] indicates the specific validation
/// rule that was violated. Callers convert [errorKey] into a user-visible
/// message via [resolveIdValidationErrorMessage] from
/// `smile_id_localization_resolver.dart`.
class IdValidationResult {
  final bool isValid;
  final IdValidationErrorKey? errorKey;
  final String? expectedFormat;

  IdValidationResult({
    required this.isValid,
    this.errorKey,
    this.expectedFormat,
  });
}
```

### 5.10 — Add `errorKey` field to `SmileIDResult` class

**Search:**
```dart
  final String? error;

  SmileIDResult({
    required this.success,
```

**Replace:**
```dart
  final String? error;
  final SmileIDErrorKey? errorKey;

  SmileIDResult({
    required this.success,
```

### 5.11 — Add `this.errorKey` parameter to `SmileIDResult` constructor

**Search:**
```dart
    this.userData,
    this.error,
  });
```

**Replace:**
```dart
    this.userData,
    this.error,
    this.errorKey,
  });
```

### 5.12 — Update `SmileIDResult.fromJson` catch block (debugPrint + populate both fields)

**Search:**
```dart
    } catch (e) {
      return SmileIDResult(
        success: false,
        error: 'Failed to parse result: $e',
      );
    }
```

**Replace:**
```dart
    } catch (e) {
      debugPrint('Failed to parse Smile ID result: $e');
      return SmileIDResult(
        success: false,
        error: 'Failed to parse result: $e',
        errorKey: SmileIDErrorKey.parseResultFailed,
      );
    }
```

---

## Step 6 — Edit each of the 5 caller screens

Each screen needs:
- An import for `smile_id_localization_resolver.dart` (matching the file's existing import style)
- An import for `app_localizations.dart` if not already present
- The `_showError(...)` line replaced with the resolver pattern

**For each screen below**, before applying the edit, verify the `AppLocalizations` import already exists:

```bash
grep -c "app_localizations" <screen-file>
```

If the count is `0`, add the import alongside the resolver import using the same style as the file's other imports.

### 6.1 — `lib/features/auth/screens/kyc/nin_verification_screen.dart`

**Add import** (relative path from `lib/features/auth/screens/kyc/`):
```dart
import '../../../../core/services/smile_id_localization_resolver.dart';
```

`AppLocalizations` is already imported in this file (verified in pre-flight: `import '../../../../generated/l10n/app_localizations.dart';`). Do not duplicate.

**Search:**
```dart
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid NIN');
      return;
    }
```

**Replace:**
```dart
    if (!validation.isValid) {
      final loc = AppLocalizations.of(context);
      final key = validation.errorKey;
      _showError(key != null
          ? resolveIdValidationErrorMessage(loc, key)
          : loc.invalidIdNumberFallback);
      return;
    }
```

### 6.2 — `lib/features/auth/screens/kyc/bvn_verification_screen.dart`

**Add import** (relative path from `lib/features/auth/screens/kyc/`):
```dart
import '../../../../core/services/smile_id_localization_resolver.dart';
```

Before applying the body change, verify `AppLocalizations` is already imported in this file:
```bash
grep -c "app_localizations" lib/features/auth/screens/kyc/bvn_verification_screen.dart
```
If the count is `0`, also add: `import '../../../../generated/l10n/app_localizations.dart';`

**Search:**
```dart
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid BVN');
      return;
    }
```

**Replace:**
```dart
    if (!validation.isValid) {
      final loc = AppLocalizations.of(context);
      final key = validation.errorKey;
      _showError(key != null
          ? resolveIdValidationErrorMessage(loc, key)
          : loc.invalidIdNumberFallback);
      return;
    }
```

### 6.3 — `lib/features/auth/screens/kyc/ssnit_verification_screen.dart`

**Add import** (relative path from `lib/features/auth/screens/kyc/`):
```dart
import '../../../../core/services/smile_id_localization_resolver.dart';
```

Before applying the body change, verify `AppLocalizations` is already imported in this file:
```bash
grep -c "app_localizations" lib/features/auth/screens/kyc/ssnit_verification_screen.dart
```
If the count is `0`, also add: `import '../../../../generated/l10n/app_localizations.dart';`

**Search:**
```dart
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid SSNIT number');
      return;
    }
```

**Replace:**
```dart
    if (!validation.isValid) {
      final loc = AppLocalizations.of(context);
      final key = validation.errorKey;
      _showError(key != null
          ? resolveIdValidationErrorMessage(loc, key)
          : loc.invalidIdNumberFallback);
      return;
    }
```

### 6.4 — `lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart`

**Add import** (relative path from `lib/features/auth/screens/kyc/`):
```dart
import '../../../../core/services/smile_id_localization_resolver.dart';
```

Before applying the body change, verify `AppLocalizations` is already imported in this file:
```bash
grep -c "app_localizations" lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart
```
If the count is `0`, also add: `import '../../../../generated/l10n/app_localizations.dart';`

**Search:**
```dart
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid NIN');
      return;
    }
```

**Replace:**
```dart
    if (!validation.isValid) {
      final loc = AppLocalizations.of(context);
      final key = validation.errorKey;
      _showError(key != null
          ? resolveIdValidationErrorMessage(loc, key)
          : loc.invalidIdNumberFallback);
      return;
    }
```

### 6.5 — `lib/features/auth/screens/kyc/national_id_verification_screen.dart`

This screen already uses `AppLocalizations.of(context).invalidIdNumberFallback` so the AppLocalizations import is already present. **Add only the resolver import.** Note the deeper indentation in this screen (6-space inner block):

**Add import** (relative path from `lib/features/auth/screens/kyc/`):
```dart
import '../../../../core/services/smile_id_localization_resolver.dart';
```

**Search:**
```dart
      if (!validation.isValid) {
        _showError(validation.error ?? AppLocalizations.of(context).invalidIdNumberFallback);
        return;
      }
```

**Replace:**
```dart
      if (!validation.isValid) {
        final loc = AppLocalizations.of(context);
        final key = validation.errorKey;
        _showError(key != null
            ? resolveIdValidationErrorMessage(loc, key)
            : loc.invalidIdNumberFallback);
        return;
      }
```

---

## Step 7 — Edit `lib/features/auth/screens/kyc_screen.dart` (dropdown label consumer)

The single line that reads the static `'label'` from the `countryIdTypes` map needs to switch to the resolver.

**Add import** (relative path from `lib/features/auth/screens/` — note ONE FEWER `../` than the kyc/ subfolder screens):
```dart
import '../../../core/services/smile_id_localization_resolver.dart';
```

**Search:**
```dart
                    title: idType['label'] as String,
```

**Replace:**
```dart
                    title: resolveIdTypeLabel(AppLocalizations.of(context), idType['value'] as String),
```

**Note:** `AppLocalizations.of(context)` is already used elsewhere in this file (per the `_getDescriptionForIdType` method), so no new AppLocalizations import is needed.

---

## Step 8 — Verify the build

```bash
# Regenerate localizations one more time to catch any straggler keys
flutter gen-l10n

# Analyzer must report 0 errors (matching pre-flight baseline)
flutter analyze 2>&1 | tail -3

# No leftover hardcoded English error strings in the touched files
echo "==== Should return ZERO matches ===="
grep -nE "validation\.error\b|'Invalid (NIN|BVN|SSNIT)'" \
  lib/features/auth/screens/kyc/*.dart \
  lib/core/services/smile_id_service.dart

# No leftover idType['label'] reads anywhere in lib/
echo "==== Should return ZERO matches ===="
grep -rn "idType\[['\"]label['\"]" lib/ --include="*.dart"

# Confirm the resolver is wired into all 5 callers
echo "==== Should return 5 matches (one per caller screen) ===="
grep -rln "resolveIdValidationErrorMessage" lib/features/auth/screens/kyc/ --include="*.dart" | wc -l

# Confirm the dropdown resolver is wired
echo "==== Should return at least 1 match ===="
grep -rn "resolveIdTypeLabel" lib/features/auth/screens/ --include="*.dart"

# Build a debug APK as the final smoke test (optional but recommended)
flutter build apk --debug
```

**Expected analyzer output:** the exact same issue count as the pre-flight baseline (currently `204 issues found`). Any change in count — up OR down — must be reconciled before commit. A drop in count is acceptable only if it traces directly to a string we removed (e.g. an `avoid_print` lint disappearing because a `print` line was deleted); investigate any other drop.

If `flutter analyze` shows any new errors (severity `error`, not `info`/`warning`), **stop and surface them** — do not auto-fix without confirming the cause.

---

## Step 9 — Commit and tag

```bash
git add lib/core/services/smile_id_service.dart \
        lib/core/services/smile_id_localization_resolver.dart \
        lib/features/auth/screens/kyc/nin_verification_screen.dart \
        lib/features/auth/screens/kyc/bvn_verification_screen.dart \
        lib/features/auth/screens/kyc/ssnit_verification_screen.dart \
        lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart \
        lib/features/auth/screens/kyc/national_id_verification_screen.dart \
        lib/features/auth/screens/kyc_screen.dart \
        lib/l10n/app_en.arb \
        lib/l10n/app_fr.arb \
        lib/l10n/app_ar.arb \
        lib/generated/l10n/

git commit -m "9.cleanup-3: smile_id_service.dart errorKey refactor + countryIdTypes labels

- Add IdValidationErrorKey and SmileIDErrorKey enums in new resolver file
- IdValidationResult.error (String?) replaced by errorKey (enum?) — old field removed
- SmileIDResult gains errorKey alongside existing error; fromJson populates both + debugPrint
- 5 caller screens migrated to resolver pattern; hardcoded English fallbacks replaced with invalidIdNumberFallback
- countryIdTypes 'label' consumer (kyc_screen.dart) switched to resolver keyed by 'value'
- 15 new ARB keys added with @-metadata; fr/ar placeholders ready for Step 10
- 3 existing keys reused: idNumberRequired, nationalId, driversLicense
- countryIdTypes static const map left unchanged (label strings now serve as documentation)

Resolves orphan deferred at phase6-step9-complete (SESSION_HANDOVER_2026-05-06.md)."

git push origin main

git tag -a phase6-step9-cleanup-3-complete -m "Phase 6 Step 9 cleanup-3 complete — smile_id_service.dart fully localized via Option-2 errorKey pattern. Resolves the deferred orphan from phase6-step9-complete."
git push origin phase6-step9-cleanup-3-complete
```

---

## Verification checklist (for the human reviewer after the agent finishes)

Run each command and confirm the expected result.

### A. File / structure checks

```bash
cd ~/Development/Projects/qr_wallet

# New file exists with expected content
ls -la lib/core/services/smile_id_localization_resolver.dart
grep -c "enum IdValidationErrorKey\|enum SmileIDErrorKey\|resolveIdValidationErrorMessage\|resolveSmileIdErrorMessage\|resolveIdTypeLabel" lib/core/services/smile_id_localization_resolver.dart
# Expected: 5
```

### B. Service file checks

```bash
# IdValidationResult class no longer has String? error field
grep -A8 "class IdValidationResult" lib/core/services/smile_id_service.dart
# Expected: shows 'final IdValidationErrorKey? errorKey;' NOT 'final String? error;'

# All 7 validation error sites use errorKey (no 'error: ' string literals)
grep -nE "error: '" lib/core/services/smile_id_service.dart
# Expected: only the SmileIDResult.fromJson line (L~503-equivalent: "error: 'Failed to parse result: \$e',")

# All 7 errorKey assignments present
grep -c "errorKey: IdValidationErrorKey\." lib/core/services/smile_id_service.dart
# Expected: 7

# SmileIDResult has both error AND errorKey
grep -A12 "class SmileIDResult" lib/core/services/smile_id_service.dart | head -15
# Expected: shows both 'final String? error;' and 'final SmileIDErrorKey? errorKey;'

# fromJson populates both error and errorKey, plus debugPrint
sed -n '/factory SmileIDResult.fromJson/,/^  }/p' lib/core/services/smile_id_service.dart
# Expected: contains debugPrint, error: 'Failed to parse result: $e', errorKey: SmileIDErrorKey.parseResultFailed
```

### C. Caller screen checks

```bash
# All 5 callers use the resolver
for f in nin bvn ssnit uganda_nin national_id; do
  echo "==== ${f}_verification_screen.dart ===="
  grep -n "resolveIdValidationErrorMessage\|invalidIdNumberFallback" lib/features/auth/screens/kyc/${f}_verification_screen.dart
done
# Expected: each file shows 2 matches (the resolver call + the fallback key)

# No hardcoded English fallbacks remain in callers
grep -nE "'Invalid (NIN|BVN|SSNIT)'" lib/features/auth/screens/kyc/*.dart
# Expected: zero matches

# No more validation.error reads
grep -rn "validation\.error\b" lib/ --include="*.dart"
# Expected: zero matches
```

### D. Dropdown consumer check

```bash
# kyc_screen.dart no longer reads idType['label']
grep -n "idType\['label'\]" lib/features/auth/screens/kyc_screen.dart
# Expected: zero matches

# It now uses the resolver
grep -n "resolveIdTypeLabel" lib/features/auth/screens/kyc_screen.dart
# Expected: 1 match
```

### E. ARB file checks

```bash
# All 15 new keys present in en.arb with @-metadata
for k in ninLengthError bvnLengthError ssnitFormatError southAfricanIdLengthError ugandaNinFormatError tpinLengthError smileIdParseError votersIdLabel internationalPassportLabel alienIdLabel ninFullLabel bvnFullLabel ssnitLabel ugandaNationalIdLabel tpinFullLabel; do
  count=$(grep -c "\"$k\"" lib/l10n/app_en.arb)
  echo "$k: $count (expect 2 — one for value, one for @-metadata)"
done

# All 15 new keys present in fr.arb and ar.arb with empty values
for k in ninLengthError bvnLengthError ssnitFormatError southAfricanIdLengthError ugandaNinFormatError tpinLengthError smileIdParseError votersIdLabel internationalPassportLabel alienIdLabel ninFullLabel bvnFullLabel ssnitLabel ugandaNationalIdLabel tpinFullLabel; do
  fr=$(grep -c "\"$k\": \"\"" lib/l10n/app_fr.arb)
  ar=$(grep -c "\"$k\": \"\"" lib/l10n/app_ar.arb)
  echo "$k: fr=$fr ar=$ar (expect 1 each)"
done
```

### F. Build / analyzer checks

```bash
# Generated Dart code is up to date
flutter gen-l10n

# Analyzer baseline preserved
flutter analyze 2>&1 | tail -3
# Expected: same total issue count as pre-flight (currently 204), with 0 severity-error entries

# Optional final smoke test
flutter build apk --debug 2>&1 | tail -5
# Expected: BUILD SUCCESSFUL
```

### G. Spot-test in app (manual, after install)

After installing the debug APK:

1. Launch the app, navigate to KYC verification.
2. Confirm the ID-type dropdown shows correct labels in English.
3. Open NIN verification (or whichever flow is enabled for your test country), submit a clearly-invalid number (e.g. `123`).
4. Confirm the error message appears in English and reads clearly (e.g. "NIN must be exactly 11 digits").
5. (Once Step 10 fr/ar translations are filled) Switch language to French/Arabic and repeat — confirm errors translate.

---

## Out of scope — observations for future cleanup

These were noticed during investigation but are NOT addressed in this fix. Flag them in the next session-handover or queue separate tickets:

1. **`IdValidationResult.expectedFormat` is dead code.** Set in 6 places inside `validateIdNumber`, read in 0 places anywhere in `lib/`. Could be removed in a future refactor. Keeping it costs ~6 lines and one nullable field — low impact.

2. **`countryIdTypes['label']` strings remain hardcoded English.** They are no longer consumed (the consumer now uses `resolveIdTypeLabel(loc, idType['value'])`), so these strings are effectively documentation-only. A future cleanup could remove the `'label'` key entirely from the map, shrinking the file by ~30 entries × 1 line. Not urgent.

3. **`SmileIDResult` has zero typed callers visible to grep.** Either consumed via implicit typing (`final result = ...`) or unused. The migration is defensive — harmless if dead, correct if live. Worth a deeper investigation in a future pass to confirm the type is reachable from at least one production code path.

4. **The "TPIN" comment at L66 of `smile_id_service.dart`** mentioned the `'TPIN'` keyword count gotcha from cleanup-2. The TPIN error path inside `validateIdNumber` is dead today (commented-out in `countryIdTypes` for ZM) but the validation logic is correct and ready for SmileID activation. Migration applies regardless — when ZM uncomments the TPIN entry, the validation + the dropdown label both work in all 3 languages without further changes.

---

## End of cleanup-3 spec

After this is verified green, the next deferred orphan is `file_dispute_screen.dart` / `respond_to_dispute_screen.dart` (~17 strings) — but those are intentionally held until Phase 5i Q4 redesigns them, so they don't apply yet.

The natural next task after this cleanup is **Phase 6 Step 10 — translate fr/ar values**, including the 15 new keys added by this cleanup.
