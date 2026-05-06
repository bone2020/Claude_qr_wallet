# Session Handover — 2026-05-05

**Session date:** 2026-05-05
**Operator:** Eric (bonstrahe@gmail.com — super_admin)
**Outgoing AI:** Claude (Opus 4.7)
**Project:** qr_wallet (Flutter app + Cloud Functions backend + React admin dashboard)
**Repo:** github.com:bone2020/Claude_qr_wallet
**Branch:** main

---

## How to Use This Document

This handover exists because Phase 6 (app-wide localization) is partially complete. **Steps 1-8 are fully done** — the localization framework is in place AND the entire `AppStrings → AppLocalizations` migration shipped (167 references migrated across 14 sub-batches, plus the cleanup commit that deleted `lib/core/constants/app_strings.dart`). Steps 9-13 remain. The session pushed straight through Step 8 cleanly; the operator (Eric) declined to pause earlier and we finished the migration entirely.

The incoming Claude should:

1. Read this handover end to end before any tool use
2. Read `docs/PHASE_6_LOCALIZATION_SPEC.md` (1283 lines) and `docs/PHASE_6_RESOLVED.md` (281 lines) for the full Phase 6 picture
3. NOT read `docs/PHASE_5I_SPEC.md` and `docs/PHASE_5I_RESOLVED.md` yet — those describe Phase 5i which only begins after Phase 6 ships
4. Begin Step 9: hardcoded-literal sweep. The 4 deferred items in section 7 below are pre-located starting points; the rest must be discovered via grep.

Eric's stated workflow (from the start of this session, paraphrased): investigate before any change, write step-by-step instructions with detailed code, never guess. He runs commands and pastes output. He uses a code agent in GitHub for big multi-file work — that agent reads files committed to the repo. So future commits should keep the docs/ folder current and code well-commented.

---

## 1. Where Phase 6 Is Right Now

### 1.1 Spec status

`docs/PHASE_6_LOCALIZATION_SPEC.md` is the master plan, committed at `35839bce`. The spec defines 13 implementation steps. As of this handover:

- **Steps 1-7 (framework):** done. App is structurally a multi-language Flutter app. `MaterialApp.router` is wired to `currentLocaleProvider`. `AppLocalizations` is generated and importable. The user model has a `preferredLanguage` field. The language provider exists. Three ARB files exist (en filled, fr/ar empty placeholders).
- **Step 8 (AppStrings → AppLocalizations migration):** **COMPLETE.** All 167 `AppStrings.foo` references migrated across 14 sub-batches (Batch 1 through Batch 8b), plus the cleanup commit that deleted `lib/core/constants/app_strings.dart` entirely. Zero `AppStrings` references remain in the codebase. `flutter analyze` and `flutter build apk --debug` both clean.
- **Steps 9-13:** not started. These are: hardcoded literals migration, translator engagement, Profile→Language entry, language settings screen, first-launch picker.

### 1.2 Phase 6 resolved decisions (locked in)

From `docs/PHASE_6_RESOLVED.md`:

- **Translation budget: $0.** Use DeepL Free + AI translation. No paid translator.
- **Reviewers:** Eric will use his Arabic-speaking friends. French reviewer TBD; if none found by Step 10, ship French as machine-translated and iterate post-launch from user feedback.
- **`AppStrings` class fate:** delete entirely after Step 8 migration is complete.
- **First-launch picker:** highlight device locale visually, but require explicit tap.
- **Currency selector relocation:** leave at current `lib/features/settings/` location. Out of scope for Phase 6.
- **Backend rollout:** three-stage. Deploy 1 = backend i18n indirection with English-only templates. Deploy 2 = Flutter app. Deploy 3 = backend translated templates.

### 1.3 Phase 5i decisions (locked in, not active until Phase 6 ships)

From `docs/PHASE_5I_RESOLVED.md`:

- **Q1 (stuck disputes):** route through support + two-admin decision; new `stuck_pending_review` state added.
- **Q2 (partial release):** buyer chooses close-after vs. continue-collecting; new `closed_partial_buyer_choice` state added.
- **Q3 (buyer-owes recovery):** mirrors seller-owes flow. Buyer not locked out.
- **Q4 (seller dispute view):** tabbed `my_disputes` screen with "Filed by me" / "Filed against me".
- **Q5 (notifications):** all three languages (handled by Phase 6 framework).
- **Q6 (filing fee):** not refunded in buyer-owes outcome. No additional penalty.

The next session should not pick up Phase 5i until all of Phase 6 is shipped including translations and backend templates.

---

## 2. Today's Commits (Chronological)

All on `main`. Repo state at start of session: HEAD at `c6ebe5f6` (the previous handover's HEAD). Working tree had pre-existing dirt that was cleaned up in the second commit below.

```
c6ebe5f6  (start of session)
8feba95b  docs: add Phase 5i specification and resolved open questions
35839bce  docs: add Phase 6 localization spec + resolved decisions
b273edc3  chore: untrack build artifacts and add to gitignore
5d75c004  feat(i18n): add flutter_localizations dependency (Phase 6 Step 1)
2c73d779  feat(i18n): add l10n.yaml config (Phase 6 Step 2)
d41f6ff0  feat(i18n): add app_en.arb with 183 keys, generate AppLocalizations (Phase 6 Step 3)
a4747675  feat(i18n): add empty fr/ar ARB files and regenerate (Phase 6 Step 4)
f631599a  feat(i18n): add preferredLanguage field to UserModel (Phase 6 Step 5)
cabadfd1  feat(i18n): add language_provider with AppLanguage enum (Phase 6 Step 6)
7a308aaf  feat(i18n): wire MaterialApp.router to language provider (Phase 6 Step 7)
b4a5605b  feat(i18n): migrate splash screen (Phase 6 Step 8 - Batch 1)             [2 refs]
b06c41d0  feat(i18n): migrate home screens (Phase 6 Step 8 - Batch 2)              [13 refs]
faa070f4  feat(i18n): migrate transactions screens (Phase 6 Step 8 - Batch 3)     [17 refs]
2fc2379e  feat(i18n): migrate scan_qr_screen (Phase 6 Step 8 - Batch 4a)           [1 ref]
de7d57d9  feat(i18n): migrate send_money_screen (Phase 6 Step 8 - Batch 4b)       [12 refs]
faae3f1d  feat(i18n): migrate confirm_send_screen (Phase 6 Step 8 - Batch 4c)      [9 refs]
97c1e036  feat(i18n): migrate receive_money_screen (Phase 6 Step 8 - Batch 5)      [6 refs]
432a225a  feat(i18n): migrate wallet screens (Phase 6 Step 8 - Batch 6)            [2 refs]
0f134d70  feat(i18n): migrate profile screens (Phase 6 Step 8 - Batch 7)          [26 refs]
4b1b01dd  feat(i18n): migrate welcome_screen (Phase 6 Step 8 - Batch 8a-i)         [4 refs]
2121c849  feat(i18n): migrate login_screen + auth widgets (Phase 6 Step 8 - 8a-ii) [17 refs]
ad53a2bf  feat(i18n): migrate sign_up + kyc_screen (Phase 6 Step 8 - 8a-iii)      [36 refs]
4d0623b3  feat(i18n): migrate KYC verification screens (Phase 6 Step 8 - Batch 8b) [23 refs]
44e65623  feat(i18n): delete AppStrings class - migration complete (Step 8 cleanup)
```

**Total:** 168 ref counts above (one ref counted in two batches due to identical key referenced from two locations); the actual distinct migration count from the spec was 167. Either way, the codebase now has zero `AppStrings.` references.

**Tag created:** `phase6-framework-complete` at SHA `7a308aaf`. This was the rollback point for Step 8. Step 8 is now complete and pushed; the tag remains as a historical marker but is no longer the recommended rollback point. To rollback past Step 8, use the SHA of the last pre-Step-8 commit (`7a308aaf`) directly. To rollback past today's whole session, use `c6ebe5f6`.

---

## 3. Current Codebase State (Verified)

### 3.1 Files that exist and are committed

**Configuration:**
- `pubspec.yaml` — has `flutter_localizations: sdk: flutter`, `intl: ^0.20.2`, `flutter: generate: true`
- `l10n.yaml` — 6 lines, no `synthetic-package` (deprecated)
- `.gitignore` — added `admin-dashboard/dist/`, `admin-dashboard/node_modules/`, `.firebase/`, `CURRENT_PROJECT_AUDIT_REPORT.md`

**Generated localization framework:**
- `lib/l10n/app_en.arb` — 183 keys, all translated (English source of truth)
- `lib/l10n/app_fr.arb` — 183 keys, all empty (placeholder for Step 10)
- `lib/l10n/app_ar.arb` — 183 keys, all empty (placeholder for Step 10)
- `lib/generated/l10n/app_localizations.dart` — generated, has `supportedLocales: [Locale('ar'), Locale('en'), Locale('fr')]`
- `lib/generated/l10n/app_localizations_en.dart` — generated, has all 183 getters
- `lib/generated/l10n/app_localizations_fr.dart` — generated, all empty (falls back to English)
- `lib/generated/l10n/app_localizations_ar.dart` — generated, all empty (falls back to English)

**New code:**
- `lib/providers/language_provider.dart` — exists, exports `AppLanguage` enum, `LanguageNotifier`, `languageNotifierProvider`, `currentLocaleProvider`, `hasPickedLanguageProvider`
- `lib/providers/providers.dart` — has 5 exports including `language_provider.dart`

**Modified code:**
- `lib/main.dart` — wired to `currentLocaleProvider`, has `localizationsDelegates` and `supportedLocales`
- `lib/models/user_model.dart` — has `@HiveField(17) String? preferredLanguage` field
- `lib/models/user_model.g.dart` — regenerated to read/write the new field

### 3.2 Migration completion (Step 8 final state)

All 167 `AppStrings.foo` references migrated to `AppLocalizations.of(context).foo`. The source file `lib/core/constants/app_strings.dart` has been deleted (commit `44e65623`). The export line in `lib/core/constants/constants.dart` has been removed.

To verify:
```bash
cd ~/Development/Projects/qr_wallet
grep -rn "AppStrings" lib --include="*.dart" | wc -l
```
Expected: **0**.

```bash
ls lib/core/constants/app_strings.dart
```
Expected: `No such file or directory`.

```bash
cat lib/core/constants/constants.dart
```
Expected: 4 lines, exporting `app_colors`, `app_text_styles`, `app_dimensions`, `african_countries` (no `app_strings`).

### 3.3 Files migrated by batch (final list)

All files that received `AppLocalizations` migration this session:

**Batch 1 (splash, 2 refs):**
- `lib/features/splash/splash_screen.dart`

**Batch 2 (home, 13 refs):**
- `lib/features/home/screens/main_navigation_screen.dart` (3)
- `lib/features/home/screens/home_screen.dart` (7) — `_buildEmptyTransactions()` helper-fix applied
- `lib/features/home/widgets/balance_card.dart` (3) — `const SnackBar` removed

**Batch 3 (transactions, 17 refs):**
- `lib/features/transactions/screens/transactions_screen.dart` (7) — `tabs: const [...]` removed
- `lib/features/transactions/screens/transaction_details_screen.dart` (10) — `_buildAmountCard` helper-fix applied

**Batch 4a (scan_qr, 1 ref):**
- `lib/features/send/screens/scan_qr_screen.dart` (1) — `_buildTopBar()` helper-fix applied

**Batch 4b (send_money, 12 refs):**
- `lib/features/send/screens/send_money_screen.dart` (12) — validators worked via State auto-resolution

**Batch 4c (confirm_send, 9 refs):**
- `lib/features/send/screens/confirm_send_screen.dart` (9) — helpers worked via State auto-resolution

**Batch 5 (receive, 6 refs):**
- `lib/features/receive/screens/receive_money_screen.dart` (6) — `const SnackBar` removed; deferred 'Saving...' literal

**Batch 6 (wallet, 2 refs):**
- `lib/features/wallet/screens/add_money_screen.dart` (1)
- `lib/features/wallet/screens/withdraw_screen.dart` (1)

**Batch 7 (profile, 26 refs):**
- `lib/features/profile/screens/profile_screen.dart` (16)
- `lib/features/profile/screens/edit_profile_screen.dart` (10) — `const SnackBar` removed; inline closure validator worked via State auto-resolution

**Batch 8a-i (welcome, 4 refs):**
- `lib/features/auth/screens/welcome_screen.dart` (4) — `_buildHeader()` helper-fix applied

**Batch 8a-ii (login + auth widgets, 17 refs):**
- `lib/features/auth/screens/login_screen.dart` (12) — `const OrDivider` and `const TextSpan` both removed
- `lib/features/auth/widgets/kyc_verification_card.dart` (3) — deferred 'Please wait...' literal
- `lib/features/auth/widgets/custom_text_field.dart` (2)

**Batch 8a-iii (sign_up + kyc_screen, 36 refs):**
- `lib/features/auth/screens/sign_up_screen.dart` (27) — many validators all on State, auto-resolution
- `lib/features/auth/screens/kyc_screen.dart` (9) — switch-statement returns; deferred 2 hardcoded ID descriptions

**Batch 8b (KYC verification screens, 23 refs across 8 files):**
- `lib/features/auth/screens/kyc/voters_card_verification_screen.dart` (3)
- `lib/features/auth/screens/kyc/nin_verification_screen.dart` (3)
- `lib/features/auth/screens/kyc/ssnit_verification_screen.dart` (3)
- `lib/features/auth/screens/kyc/uganda_nin_verification_screen.dart` (1)
- `lib/features/auth/screens/kyc/drivers_license_verification_screen.dart` (3)
- `lib/features/auth/screens/kyc/national_id_verification_screen.dart` (3)
- `lib/features/auth/screens/kyc/bvn_verification_screen.dart` (3)
- `lib/features/auth/screens/kyc/passport_verification_screen.dart` (4)

**Cleanup (deletion only, 0 refs):**
- `lib/core/constants/app_strings.dart` — deleted entirely
- `lib/core/constants/constants.dart` — `export 'app_strings.dart';` line removed

### 3.4 Pre-existing dirt being deliberately ignored

20 untracked Python migration scripts at the repo root (`PHASE_2_*.py`, `PHASE_3a_*.py`). These are historical from earlier project phases. **Do not touch them. Do not commit them.** They're not in `.gitignore` because there might be reference value, but they sit untracked.

---

## 4. The Patterns We've Established

These are the operational patterns we converged on through the session. The next Claude should follow these — don't reinvent.

### 4.1 The basic migration script template

For each batch:

```python
import re

files = ['path/to/file1.dart', 'path/to/file2.dart']

# Calculate the relative path based on directory depth:
# - lib/features/X/file.dart           → '../generated/l10n/app_localizations.dart'
# - lib/features/X/screens/file.dart   → '../../generated/l10n/app_localizations.dart'
# - lib/features/X/widgets/file.dart   → '../../generated/l10n/app_localizations.dart'
# - lib/features/X/Y/file.dart         → '../../../generated/l10n/app_localizations.dart'
# Use the deepest path for any given batch.
loc_import = "import '../../../generated/l10n/app_localizations.dart';"

# Anchor: every file imports core/constants/constants.dart. Add ours after.
anchor = "import '../../../core/constants/constants.dart';"

pattern = re.compile(r'\bAppStrings\.([a-zA-Z_][a-zA-Z0-9_]*)\b')

for filepath in files:
    with open(filepath) as f:
        content = f.read()

    # Sanity asserts BEFORE modifying anything
    assert content.count(anchor) == 1, f"{filepath}: expected 1 anchor, found {content.count(anchor)}"
    assert loc_import not in content, f"{filepath}: AppLocalizations import already present"
    keys = pattern.findall(content)
    assert len(keys) > 0, f"{filepath}: no AppStrings references"

    # Apply
    content = content.replace(anchor, anchor + "\n" + loc_import)
    content = pattern.sub(r'AppLocalizations.of(context).\1', content)

    # Verify
    assert 'AppStrings.' not in content, f"{filepath}: AppStrings remain"

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"OK: {filepath} - {len(keys)} replacement(s): {keys}")
```

### 4.2 Critical: NO trailing `!` on `AppLocalizations.of(context)`

We set `nullable-getter: false` in `l10n.yaml` (Step 2). That means `AppLocalizations.of(context)` returns non-null. Adding a `!` produces `unnecessary_non_null_assertion` warnings.

The migration regex MUST be:
```python
content = pattern.sub(r'AppLocalizations.of(context).\1', content)   # CORRECT
```

NOT:
```python
content = pattern.sub(r'AppLocalizations.of(context)!.\1', content)  # WRONG - generates warnings
```

This was discovered during Batch 1 (splash) and corrected. Batches 2 onward use the correct form.

### 4.3 Three known edge cases that surface during migration

These bite. Recognize them on sight in the analyzer output and fix immediately.

**Edge case A — `Undefined name 'context'`** (`compile error`)

The `AppStrings.foo` was inside a helper method that does not take `BuildContext context` as a parameter. The migration script blindly substituted `AppLocalizations.of(context)` in there, but `context` isn't in scope.

**Fix pattern:**
```python
# 1. Add BuildContext context to the helper's signature
old_sig = "  Widget _helperName() {"
new_sig = "  Widget _helperName(BuildContext context) {"
content = content.replace(old_sig, new_sig)

# 2. Update every call site to pass context
old_call = "_helperName()"
new_call = "_helperName(context)"
content = content.replace(old_call, new_call)
```

If the helper has named parameters (`{required String label}`), `context` goes as a positional first arg before the curly brace:
```dart
Widget _helperName(BuildContext context, {required String label}) { ... }
```
And callers pass it positionally: `_helperName(context, label: 'foo')`.

Examples we hit:
- Batch 2: `_buildEmptyTransactions()` in `home_screen.dart`
- Batch 3: `_buildAmountCard(transaction, isCredit, currencySymbol)` in `transaction_details_screen.dart`
- Batch 4a: `_buildTopBar()` in `scan_qr_screen.dart`

**Edge case B — `Methods can't be invoked in constant expressions`** (`compile error`)

The `AppStrings.foo` was inside something marked `const`. Could be `const SnackBar(...)`, `const [...]` for a tabs list, etc. After migration, `AppLocalizations.of(context).foo` is a runtime call and can't be inside `const`.

**Fix pattern:** remove the offending `const` keyword. Be careful to remove only the outer `const` that's wrapping the AppLocalizations call — inner `const` widgets that don't depend on the call can stay.

Examples we hit:
- Batch 2: `const SnackBar(...)` in `balance_card.dart`
- Batch 3: `tabs: const [...]` in `transactions_screen.dart`

**Edge case C — `prefer_const_constructors` info-level lint** (info, not error)

Side effect of removing `const` in Edge case B. The analyzer suggests inner widgets could now be `const`. Don't act on it. Belongs in the future cleanup phase along with the 188 other pre-existing lints.

### 4.4 Helpers that take a String parameter are SAFE

If a helper's signature is `_buildSomething(String label)` and the caller is `_buildSomething(AppStrings.foo)`, the migration becomes `_buildSomething(AppLocalizations.of(context).foo)`. The `context` is available at the call site (which is inside `build()`), the helper just receives the resulting string. **No fix needed.**

Examples:
- `_buildDetailRow({required String label, ...})` in `transaction_details_screen.dart`
- `_buildSummaryRow(String label, String value, ...)` in `confirm_send_screen.dart` (predicted)

### 4.5 Form validators need closure-wrapping (NOT YET TESTED)

This pattern hasn't been exercised yet but is predicted for Batch 4b.

**Problem:** Form validators in Flutter are typically `String? Function(String?)`. They're passed bare to TextFormField:
```dart
validator: _validateWalletId,
```

If we add `BuildContext context` to the validator's signature, it no longer matches `String? Function(String?)`. We'd need to wrap it in a closure at the call site.

**Predicted fix:** Either:

(a) Use the BuildContext available in the surrounding `build(BuildContext context)` method via closure capture:
```dart
// keep validator signature as-is, but make AppLocalizations call work
// by accessing context through closure capture
String? _validateWalletId(String? value) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context).errorFieldRequired;  // 'context' from outer scope
  }
  return null;
}
```
This requires `_validateWalletId` to be a method on a State class where `context` is the State's own getter. Most TextFormField cases ARE inside State classes, so `context` is just available as `this.context`. **The migration script may "just work" without any wrapping if we don't add a parameter** — Dart will resolve `context` to the State's `context` getter at runtime.

(b) Add a parameter and wrap at call site:
```dart
String? _validateWalletId(BuildContext context, String? value) { ... }

// call site:
validator: (value) => _validateWalletId(context, value),
```

**Recommendation for Batch 4b:** Try approach (a) first — DON'T add `BuildContext context` to the validator signature; let Dart resolve `context` via the State class's getter. Run `flutter analyze` after migration. If errors, fall back to approach (b).

The next Claude should INVESTIGATE FIRST: run `head -50 lib/features/send/screens/send_money_screen.dart` and confirm whether it's a `StatefulWidget` and whether `_validateWalletId` is on the State class. If yes, approach (a) should work for free.

### 4.6 Per-batch verification rhythm

After running the migration script:

```bash
# 1. Confirm no AppStrings remain in the migrated files
grep -rn "AppStrings\." <batch's folder>/

# 2. Confirm import was added (case-insensitive — path is lowercase)
grep -rn "app_localizations\|AppLocalizations" <batch's folder>/ | head -10

# 3. Run analyzer on just the migrated files
flutter analyze <list of files>

# 4. If analyzer passes (only info/warning, no error), run a build
flutter build apk --debug --no-pub 2>&1 | tail -5
```

If analyzer shows errors, identify which Edge Case (A/B/C) and apply the fix BEFORE committing. Do not commit a batch with build errors. Use the assert-style Python script to apply fixes safely.

### 4.7 Commit message format

Use a temp file via `cat > /tmp/commit_msg.txt << 'EOF'` to avoid zsh `!` history-expansion issues. Then `git commit -F /tmp/commit_msg.txt`.

Subject line: `feat(i18n): migrate <area> to AppLocalizations (Phase 6 Step 8 - Batch N/N)`

Body should include:
- Files touched
- Reference count
- Any non-trivial fixes (helpers needing context, const removed, etc.)
- Verification (grep results, analyzer, build)
- Reference to `docs/PHASE_6_LOCALIZATION_SPEC.md Step 8`

### 4.8 Pre-existing 188 analyzer issues — do NOT fix

Eric considered fixing them and we decided no. They're info-level lints (mostly `withOpacity` deprecations and `prefer_const_constructors` suggestions) that have been there for months. Fixing them is its own dedicated phase, AFTER Phase 6 ships. Mixing them with localization work creates noise that obscures whether migration bugs are migration bugs.

The new `prefer_const_constructors` lints introduced as side effects of removing `const` (in Batches 2 and 3) are part of this — leave them.

---

## 5. Operational Lessons (zsh and tooling quirks)

### 5.1 zsh hates inline `#` comments in command blocks

Command blocks like:
```bash
# Some comment
ls -la
```

Sometimes work and sometimes drop zsh into a `quote>` prompt. Avoid inline `#` comments in any block sent to Eric. Use `echo "===="` separators instead:

```bash
echo "==== description ===="
ls -la
```

### 5.2 zsh history-expansion bites on `!`

Commit messages containing `!` (e.g. `Foo!.bar` or `foo!`) cause zsh to error with `event not found: .bar`. Always write commit messages to a temp file with single-quoted heredoc:

```bash
cat > /tmp/commit_msg.txt << 'EOF'
... message with ! and * and other special chars ...
EOF
git commit -F /tmp/commit_msg.txt
```

### 5.3 The `code` shell command is now installed

Eric installed VS Code's `code` shell command via the command palette during this session. `code path/to/file` opens files in VS Code from terminal. But for simple one-line edits, prefer `echo >> file` or sed/python — fewer round trips.

### 5.4 Multi-line Python heredocs work fine in zsh

`python3 << 'PY' ... PY` blocks are reliable. Use them liberally. The single-quoted `'PY'` is what makes them safe — it tells zsh "don't interpret anything inside."

### 5.5 macOS sed needs `-i ''`

On macOS, in-place sed requires an empty string after `-i`:
```bash
sed -i '' 's/old/new/' file.dart   # macOS
sed -i 's/old/new/' file.dart       # Linux (different)
```

### 5.6 Always use `assert content.count(...) == N` in scripts

Every Python script that modifies files should assert occurrence counts BEFORE making the change. If the count is unexpected, the script bails without touching the file. This caught issues during the session — for example, when an edit was attempted that would have matched zero or two patterns, the assert flagged it before any damage.

---

## 6. Step 8 in Retrospect (COMPLETE)

Step 8 was completed in this session across 14 sub-batches plus a cleanup commit. The plan that originally had ~10 batches in mind grew to 14 because some folders were split for safety (Batch 4 split into 4a/4b/4c, Batch 8 split into 8a-i/8a-ii/8a-iii/8b).

**What this means for future Step 9 work:** the same batched, verify-after-each-batch rhythm is appropriate. Step 9 will likely be larger (~150-200 strings to migrate, plus new ARB keys to invent for each). Expect to split Step 9 across many sessions.

### Patterns proven through Step 8 (use these in Step 9)

**Pattern A — State auto-resolution (validated in batches 4b/4c/5/6/7/8a-ii/8a-iii/8b):**
When a method or validator sits on a `ConsumerStatefulWidget`'s State class (`extends ConsumerState<X>`) or any class that extends `State<T>`, it can use `AppLocalizations.of(context).foo` for free. The State class has `context` as an inherited getter (`State.context`), so `context` resolves at runtime even if the helper method has no `context` parameter. **No signature changes needed.**

**Pattern B — StatelessWidget/ConsumerWidget helper-context fix (validated in batches 2/3/4a/8a-i):**
When a method sits on a stateless widget class (`extends StatelessWidget` or `extends ConsumerWidget`), it does NOT have `context` available unless the parameter is added explicitly. The fix:
```dart
// Before:
Widget _buildHeader() { ... AppLocalizations.of(context).foo ... }

// After:
Widget _buildHeader(BuildContext context) { ... AppLocalizations.of(context).foo ... }

// And update the call site:
// Before:  _buildHeader()
// After:   _buildHeader(context)
```

**Pattern C — `const` block removal (validated in batches 2/3/5/7/8a-ii):**
When `AppLocalizations.of(context).foo` ended up inside a `const` constructor (e.g. `const SnackBar(...)`, `tabs: const [...]`, `const TextSpan(...)`, `const OrDivider(...)`), the build error is:
```
Methods can't be invoked in constant expressions
```
The fix: remove the offending `const` keyword. Inner `const` widgets that don't depend on the AppLocalizations call can stay.

**Pattern D — Helpers taking String parameter are safe:**
If the helper signature is `_buildRow({required String label})` and the caller is `_buildRow(label: AppStrings.foo)`, the migration becomes `_buildRow(label: AppLocalizations.of(context).foo)`. The `context` is available at the call site (inside `build()`), the helper just receives the resulting String. **No fix needed.** Examples we hit: `_buildDetailRow`, `_buildSummaryRow`.

**Pattern E — Inline closures (validated in batch 7):**
Inline closure validators like `validator: (value) { ... return AppStrings.errorFieldRequired; }` work without modification, because the closure captures `context` from the surrounding `build()` scope where it was a parameter. Same as Pattern A.

**Pattern F — String interpolations work fine:**
`Text('${AppStrings.greeting} World')` migrates to `Text('${AppLocalizations.of(context).greeting} World')` — works at runtime. **Unless** the wrapping widget is `const` (Pattern C).

### Migration tooling (use the same Python pattern in Step 9)

The Python script template in section 4.1 worked reliably across 14 sub-batches. It does:
1. Asserts the anchor import line exists exactly once
2. Asserts the AppLocalizations import isn't already present
3. Asserts the file has at least one AppStrings reference (for AppStrings batches; for Step 9, this assertion changes)
4. Adds the import after the anchor
5. Replaces all references with regex
6. Asserts no AppStrings remain
7. Saves only on success

For Step 9, the same shape works but the assertions and replacements differ — Step 9 has to look for hardcoded literals with various patterns (`Text('...')`, `hintText: '...'`, etc.) and may need to add new ARB keys before migrating.

### Build verification per batch — keep doing this

Run `flutter build apk --debug --no-pub 2>&1 | tail -5` after every 1-3 batches. We did this consistently through Step 8 and it never let us down. The build catches issues that `flutter analyze` doesn't catch (transient state during migration). **Never commit a batch without confirming the build succeeds.**

---

## 7. Steps 9-13 — Not Started Yet

After Step 8 is fully complete, the following work remains. The full details are in `docs/PHASE_6_LOCALIZATION_SPEC.md` Sections 7.9-7.13.

**Step 9 — Hardcoded literal migration.** ~150-200 hardcoded `Text('...')`, `hintText: '...'`, AppBar `title:` strings that bypass `AppStrings`. Each needs a new ARB key invented and added to `app_en.arb`, then migrated. Estimated ~80-100 user-visible literals after filtering out dynamic content. Larger than Step 8 because each string needs a new ARB key.

**Step 9 deferred items — locations recorded here, NOT planted as TODO comments in code:**

When Step 8 batches encountered hardcoded literals adjacent to migrated `AppStrings` references, we deliberately did NOT migrate them — Step 8 stayed strictly `AppStrings → AppLocalizations`. Instead of adding TODO comments to the code (which would clutter the files when the master list is here), we tracked them in this handover. **This list is the single source of truth for known Step 9 deferrals.** Step 9 will discover many more hardcoded literals beyond this list via systematic grep — these are simply pre-located starting points.

Known deferred items (4 total — final after Step 8 completion):

1. **`lib/features/receive/screens/receive_money_screen.dart`, around line 321** — Hardcoded `'Saving...'` inside a ternary expression: `label: Text(_isDownloading ? 'Saving...' : AppLocalizations.of(context).downloadQrCode)`. Step 9 action: add `saving` key to `lib/l10n/app_en.arb` (value `"Saving..."`), run `flutter gen-l10n`, change ternary's first branch to `AppLocalizations.of(context).saving`. Surfaced in Batch 5.

2. **`lib/features/auth/widgets/kyc_verification_card.dart`, around line 80** — Hardcoded `'Please wait...'` inside a ternary expression: `label: Text(isLoading ? 'Please wait...' : AppLocalizations.of(context).startVerification)`. Step 9 action: add `pleaseWait` key to `lib/l10n/app_en.arb` (value `"Please wait..."`), run `flutter gen-l10n`, change ternary's first branch to `AppLocalizations.of(context).pleaseWait`. Surfaced in Batch 8a-ii.

3. **`lib/features/auth/screens/kyc_screen.dart`, around line 123** — Hardcoded `'Verify your identity with your Uganda National Identification Number'` returned from a switch case for `'UGANDA_NIN'` ID type. Step 9 action: add `ugandaNinDescription` key to `lib/l10n/app_en.arb`, run `flutter gen-l10n`, change return statement to `return AppLocalizations.of(context).ugandaNinDescription;`. Surfaced in Batch 8a-iii.

4. **`lib/features/auth/screens/kyc_screen.dart`, around line 125** — Hardcoded `'Verify your identity with your Zambian Taxpayer PIN'` returned from a switch case for `'TPIN'` ID type. Step 9 action: add `tpinDescription` key to `lib/l10n/app_en.arb`, run `flutter gen-l10n`, change return statement to `return AppLocalizations.of(context).tpinDescription;`. Surfaced in Batch 8a-iii.

**Step 10 — Translation work.** In-session Eric will use DeepL Free + Claude AI to translate the 183-key `app_en.arb` plus the new keys from Step 9 into French and Arabic. Result committed as filled `app_fr.arb` and `app_ar.arb`. Run `flutter gen-l10n` to regenerate. Have Arabic-friend reviewer walk through the app in Arabic; iterate based on feedback.

**Step 11 — Profile → Language row.** Add a tappable row to `lib/features/profile/screens/profile_screen.dart` (already has 9 similar rows for Theme, Notifications, etc.), routing to a new language settings screen.

**Step 12 — Language settings screen.** New file `lib/features/profile/screens/language_settings_screen.dart`. Mirror the structure of `lib/features/profile/screens/theme_settings_screen.dart` (read it first). Three cards: English / Français / العربية. Tap → calls `languageNotifierProvider.notifier.setLanguage(lang)` AND syncs to Firestore via `authNotifierProvider`'s update flow.

**Step 13 — First-launch picker.** Most subtle piece. New file `lib/features/auth/screens/first_launch_language_screen.dart`. Router redirect logic: if `hasPickedLanguageProvider` is false, route to first-launch picker. After pick, redirects clear. Auto-detect device locale to highlight the matching card (but require explicit tap per Q4 resolution).

**Backend (separate from Flutter):** Spec Sections 7.6-7.8 describe the `functions/i18n.js` module and the migration of `sendCustomerSms`/`sendProposalEmail` call sites. Three-stage backend rollout per `PHASE_6_RESOLVED.md` Q6.

---

## 8. Recovery and Rollback

If anything goes wrong during Step 8 batches:

**Single batch revert:**
```bash
git revert <batch-sha>
git push origin main
```

**Multiple-batch revert (rollback to framework-only state):**
```bash
git reset --hard phase6-framework-complete
git push --force-with-lease origin main
```
Note: `--force-with-lease` is safer than plain `--force`. Only do this if you truly want to discard all batch commits.

**Disaster — completely undo Phase 6:**
```bash
git reset --hard 35839bce  # the docs commit before any code changes
git push --force-with-lease origin main
```

**Eric's strict rule from session start:** never `git add .` or `git add -A`. Always explicit `git add <path>`. The 20 untracked PHASE_*.py files at repo root would otherwise sweep into commits.

---

## 9. Things The Next Claude Should NOT Do

Hard list, learned through this session:

1. **Do NOT use inline `#` comments inside command blocks sent to Eric.** zsh chokes. Use `echo "===="` separators.
2. **Do NOT include `!` in commit messages or terminal commands without escaping.** zsh history-expansion bites. Use temp files.
3. **Do NOT add `!` after `AppLocalizations.of(context)`.** Setting `nullable-getter: false` makes it non-null already; `!` generates 167+ warnings.
4. **Do NOT fix the 188 pre-existing analyzer issues.** They're scope creep. Belong in their own future phase.
5. **Do NOT remove `const` from places that don't need it.** Only remove `const` from blocks where AppLocalizations.of(context) calls would be inside a constant expression. Inner widgets can stay `const`.
6. **Do NOT batch migrate more than ~3 files at once without a build check.** Each `flutter build apk --debug --no-pub` is the safety net. Don't skip it.
7. **Do NOT commit anything other than the explicitly-staged files.** Never `git add .`. Always `git add <specific-paths>`.
8. **Do NOT run `flutter packages upgrade` or similar dependency-modifying commands.** The dependency graph is locked at the working state from Step 1.
9. **Do NOT touch Phase 5i material yet.** Phase 6 must ship first. Phase 5i is recorded in `docs/PHASE_5I_*.md` but should not be implemented until Phase 6 is fully done.
10. **Do NOT skip the "INVESTIGATE first" rhythm.** Eric's stated workflow requires reading existing code before changing it. The script from section 4.1 has assertions specifically because shortcuts have bitten us before.

---

## 10. First Actions for Next Session

When Eric opens the next session, the incoming Claude should:

1. Read this handover end to end
2. Read `docs/PHASE_6_LOCALIZATION_SPEC.md` and `docs/PHASE_6_RESOLVED.md` (committed in repo)
3. Confirm current state by having Eric run:
   ```bash
   cd ~/Development/Projects/qr_wallet
   git status
   git --no-pager log --oneline -10
   git tag -l | head -5
   grep -rn "AppStrings" lib --include="*.dart" | wc -l
   ls lib/core/constants/app_strings.dart 2>&1
   ```
4. Expected state:
   - `git status`: clean except for the 20 untracked PHASE_*.py files at repo root (leave alone)
   - HEAD on `main` at `44e65623` (Step 8 cleanup commit) or later
   - Tag `phase6-framework-complete` exists at SHA `7a308aaf` (historical marker)
   - **Zero `AppStrings` references** in lib/
   - `app_strings.dart` shows "No such file or directory"
5. Begin **Step 9 — hardcoded literal migration**. Steps:
   - Read Section 7 above for the 4 pre-located deferred items (`'Saving...'`, `'Please wait...'`, 2 KYC ID descriptions)
   - Run a systematic grep to find more: `grep -rn "Text(\s*'" lib --include="*.dart"` and similar patterns for `hintText: '...'`, `title: '...'`
   - Plan Step 9 batches similarly to Step 8 — by feature folder, with surveys before each batch
   - For each new key, add it to `lib/l10n/app_en.arb`, run `flutter gen-l10n`, then migrate
   - **Step 9 is bigger than Step 8** because each string requires inventing a new ARB key, not just a mechanical replacement
6. After Step 9 is done, move to Step 10 (translation work).

---

## 11. Outgoing Claude's Self-Assessment

This session pushed all the way through Step 8 in one sitting — 14 sub-batches plus the cleanup commit, ~167 references migrated, the `AppStrings` class deleted entirely. Eric was sharp throughout and pushed back at the right moments — including a key correction about whether Step 9 deferrals should be tracked as in-code TODOs or in this handover (he was right that the handover is the better single source of truth).

Mistakes I caught and corrected during the session:

- Initially typed `_localStorage` as `dynamic` in `language_provider.dart` instead of `LocalStorageService` — caught and fixed before delivery
- Sent multi-line shell blocks with `#` comments that broke zsh, twice
- The zsh `!` history-expansion bit me on a commit message; recovered by switching to temp-file commits via `git commit -F`
- Initially proposed planting in-code TODO comments for Step 9 deferrals; Eric correctly pointed out this was redundant given the handover entry
- Wavered on whether to defer or fix-in-batch when Eric pushed back on my approach — eventually held the deferral position consistently

The work shipped is solid. Each commit was verified with grep, `flutter analyze`, and `flutter build apk --debug` before merging. Zero migration-introduced errors made it into any commit.

Good luck to whoever picks this up. The repo is in a clean, building, testable state. Phase 6 is roughly 60% complete (Steps 1-8 of 13 done). Steps 9-13 remain. Stay disciplined and the same patterns that carried Step 8 will carry Step 9.

---

**End of handover.**

Total length: this document is intentionally detailed. It is the only context the next Claude will have besides the spec docs themselves and the git log. Better verbose and accurate than terse and incomplete.
