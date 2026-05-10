# Phase 6 Step 11 + Step 12 — Profile Language Row + Language Settings Screen

**Status:** SPEC — ready to apply
**Bundled scope:** Step 11 (profile row) + Step 12 (language settings screen) in one atomic change
**Risk level:** LOW — additive only, no existing code paths altered
**Prerequisite tag:** `phase6-step10-ar-translations-complete` (HEAD of `main` at start: `58ae0fa6`)
**Recommended workflow:** Direct VS Code edits — zero new ARB keys, no `gen-l10n`, no translation pipeline run
**Suggested completion tag:** `phase6-step11-12-language-settings-complete`

---

## 1. Decisions Locked

| Decision | Choice | Why |
|---|---|---|
| Workflow grouping | Bundled (B) | Spec acknowledges Step 11 alone leaves broken nav; bundling is atomic |
| Profile row trailing UX | None (α) | Matches Theme/Notifications rows; current language is shown inside the screen |
| Snackbar after change | None (Q3 a) | Whole app instantly rebuilds in new locale — visual confirmation is built in |
| Section header on screen | Yes — use `languageDescription` (Q4 b) | Existing key, no ARB additions |
| Subtitle on language cards | None (Q5 a) | `nativeName` is self-explanatory; no ARB additions |
| Card icon | `Iconsax.global` for all three | Politically neutral; flag emojis avoided |
| Firestore sync approach | Inline write in screen, then `updateUser(...)` for cache/state | Single-file change; matches existing pattern for non-Auth Firestore fields |
| New ARB keys | **Zero** | All required keys already exist in en/fr/ar |

---

## 2. Files Affected

| File | Change | Lines (approx) |
|---|---|---|
| `lib/core/router/app_router.dart` | Add 1 import, 1 route constant, 1 GoRoute entry | +9 lines |
| `lib/features/profile/screens/profile_screen.dart` | Add 1 menu item between Theme and Notifications | +5 lines |
| `lib/features/profile/screens/language_settings_screen.dart` | NEW FILE | ~115 lines |

Nothing else touched. No model, provider, ARB, or service changes.

---

## 3. Pre-Flight Checks

Run these before applying any edit. Each must produce the noted result.

```bash
cd ~/Development/Projects/qr_wallet

# 3.1 Confirm we're on main and up to date
git fetch origin
git rev-parse main
git rev-parse origin/main
# Both should print 58ae0fa6 (or the same newer SHA if main has moved)

# 3.2 Confirm working tree has no NEW changes beyond the known repo dirt
git status --short
# Expected: only the pre-existing dirt (admin-dashboard/dist, .firebase/hosting cache, untracked PHASE_*.py files)

# 3.3 Confirm the language ARB keys exist in all three locales
for f in lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/app_ar.arb; do
  echo "=== $f ==="
  grep -E '"(language|selectLanguage|languageDescription)":' "$f"
done
# Expected: each file shows all 3 keys with non-empty values

# 3.4 Confirm new screen file does not yet exist
ls -la lib/features/profile/screens/language_settings_screen.dart 2>&1
# Expected: "No such file or directory"

# 3.5 Confirm AppRoutes.languageSettings is not yet defined
grep -n "languageSettings" lib/core/router/app_router.dart
# Expected: no output (constant doesn't exist yet)

# 3.6 Confirm the import path convention used for theme_settings_screen.dart
# (we'll mirror this for language_settings_screen.dart)
grep -n "theme_settings_screen" lib/core/router/app_router.dart
# Expected: shows the existing import line — we'll copy this exact format below
```

If 3.6 reveals an import path different from the one written in this spec (Section 4.1), use the actual existing convention.

---

## 4. Changes — In Dependency Order

Apply in this order. Each later change depends on earlier ones compiling.

### 4.1 — `lib/core/router/app_router.dart` — Add import for new screen

**Locate** the existing import for `theme_settings_screen.dart` near the top of the file. Add a sibling import for `language_settings_screen.dart` immediately after it.

**Find:**
```dart
import '../../features/profile/screens/theme_settings_screen.dart';
```

**Replace with:**
```dart
import '../../features/profile/screens/theme_settings_screen.dart';
import '../../features/profile/screens/language_settings_screen.dart';
```

**Note:** The import path `'../../features/profile/screens/theme_settings_screen.dart'` is what we expect based on the directory structure. Pre-flight check 3.6 confirms the actual path. If it differs (e.g., extra `..` or different segment count), use whatever the actual existing import uses — just append `language_settings_screen.dart` instead of `theme_settings_screen.dart` in the same form.

---

### 4.2 — `lib/core/router/app_router.dart` — Add `languageSettings` route constant

**Find** (around line 97):
```dart
  static const String themeSettings = '/theme-settings';
  static const String notifications = '/notifications';
```

**Replace with:**
```dart
  static const String themeSettings = '/theme-settings';
  static const String languageSettings = '/language-settings';
  static const String notifications = '/notifications';
```

---

### 4.3 — `lib/core/router/app_router.dart` — Add GoRoute entry

**Find** (around line 703):
```dart
      // Theme Settings Screen
      GoRoute(
        path: AppRoutes.themeSettings,
        name: 'themeSettings',
        builder: (context, state) => const ThemeSettingsScreen(),
      ),

      // Notifications Screen
```

**Replace with:**
```dart
      // Theme Settings Screen
      GoRoute(
        path: AppRoutes.themeSettings,
        name: 'themeSettings',
        builder: (context, state) => const ThemeSettingsScreen(),
      ),

      // Language Settings Screen
      GoRoute(
        path: AppRoutes.languageSettings,
        name: 'languageSettings',
        builder: (context, state) => const LanguageSettingsScreen(),
      ),

      // Notifications Screen
```

---

### 4.4 — Create `lib/features/profile/screens/language_settings_screen.dart`

**Create new file** with the following content verbatim:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';

/// Language settings screen — Phase 6 Step 12.
///
/// Lets a signed-in user choose between English, French, and Arabic.
/// Tapping a language:
///   1. Persists the choice locally and updates Riverpod state
///      (which causes MaterialApp to rebuild in the new locale).
///   2. If the user is signed in, syncs the choice to Firestore
///      (`users/{uid}.preferredLanguage`) so it persists across devices.
///   3. Refreshes the local UserModel cache via [AuthNotifier.updateUser].
///
/// Mirrors the structure of [ThemeSettingsScreen] for consistency.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context).selectLanguage,
          style: AppTextStyles.headlineMedium(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).languageDescription,
              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 24),
            for (final lang in AppLanguage.values)
              _buildLanguageOption(
                context: context,
                ref: ref,
                lang: lang,
                isSelected: lang == currentLanguage,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required AppLanguage lang,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _onLanguageSelected(ref, lang),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Iconsax.global,
                color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(lang.nativeName, style: AppTextStyles.bodyLarge()),
            ),
            if (isSelected)
              const Icon(Iconsax.tick_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _onLanguageSelected(WidgetRef ref, AppLanguage lang) async {
    // 1. Persist locally + update Riverpod state.
    //    MaterialApp rebuilds in the new locale immediately.
    await ref.read(languageNotifierProvider.notifier).setLanguage(lang);

    // 2. If signed in, sync to Firestore for cross-device persistence.
    final currentUser = ref.read(authNotifierProvider).user;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'preferredLanguage': lang.code});

        // 3. Refresh local cache + state with the new value.
        final updatedUser =
            currentUser.copyWith(preferredLanguage: lang.code);
        ref.read(authNotifierProvider.notifier).updateUser(updatedUser);
      } catch (e) {
        // Local change is already in effect; cross-device sync deferred
        // until the next opportunity. Log technical detail for engineers.
        debugPrint('Failed to sync preferredLanguage to Firestore: $e');
      }
    }
  }
}
```

---

### 4.5 — `lib/features/profile/screens/profile_screen.dart` — Add Language menu item

**Find** (around lines 430–439):
```dart
                _buildMenuItem(
                  icon: Iconsax.moon,
                  title: AppLocalizations.of(context).appearanceMenuItem,
                  onTap: () => context.push(AppRoutes.themeSettings),
                ),
                _buildMenuItem(
                  icon: Iconsax.notification,
                  title: AppLocalizations.of(context).notifications,
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
```

**Replace with:**
```dart
                _buildMenuItem(
                  icon: Iconsax.moon,
                  title: AppLocalizations.of(context).appearanceMenuItem,
                  onTap: () => context.push(AppRoutes.themeSettings),
                ),
                _buildMenuItem(
                  icon: Iconsax.global,
                  title: AppLocalizations.of(context).language,
                  onTap: () => context.push(AppRoutes.languageSettings),
                ),
                _buildMenuItem(
                  icon: Iconsax.notification,
                  title: AppLocalizations.of(context).notifications,
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
```

No new imports needed in this file — `Iconsax`, `AppRoutes`, `AppLocalizations`, and `context.push` are all already imported.

---

## 5. Verification

After applying all five changes, run these in order. Each step has a clear pass/fail.

### 5.1 — Static analysis

```bash
cd ~/Development/Projects/qr_wallet
flutter analyze lib/features/profile/screens/profile_screen.dart \
                lib/features/profile/screens/language_settings_screen.dart \
                lib/core/router/app_router.dart
```

**Pass criteria:** No new errors introduced. Pre-existing warnings (e.g., the known `unnecessary_import` info in `wallet_provider.dart`) are unaffected.

If any of these are flagged, address them before continuing:
- `undefined_identifier: AppRoutes.languageSettings` → Step 4.2 not applied
- `undefined_class: LanguageSettingsScreen` → Step 4.4 not applied or wrong filename
- `uri_does_not_exist` for the new screen import → Step 4.1 import path is wrong (verify against the theme import path)
- `undefined_getter: language` on `AppLocalizations` → ARB keys not regenerated. **In theory not needed** since these keys already existed at HEAD `58ae0fa6` and `lib/generated/l10n/` should already contain them. If the bindings do NOT have `selectLanguage`, `languageDescription`, or `language`, run `flutter gen-l10n` once.

### 5.2 — Build

```bash
flutter build apk --debug
```

**Pass criteria:** Build completes successfully. (Same baseline state the handover lists as "green".)

### 5.3 — Manual test on device or emulator

1. **Profile screen.** Open the app → Profile tab. A new "Language" row appears between "Appearance" and "Notifications" with a globe icon.
2. **Tap Language.** Should navigate to a new screen with the AppBar title "Select Language", the `languageDescription` text below it, and three cards: English / Français / العربية. The currently active language (English by default) is highlighted with a primary-colored border and a check icon on the right.
3. **Tap Français.** The entire app instantly switches to French. Profile row labels, AppBar text, navigation labels — all in French. Going back to Profile, the "Language" row label is now "Langue".
4. **Tap Language → Tap Arabic.** App switches to Arabic. Layout flips to RTL. AppBar title reads "اختر اللغة".
5. **Tap Language → Tap English.** Back to English. LTR layout restored.
6. **Restart the app.** The most recently selected language persists. (LocalStorageService verification.)

### 5.4 — Firestore sync (if signed in)

1. Sign in with a test user (e.g., `kingbonstrah@gmail.com`).
2. Go to Profile → Language → tap Français.
3. Open Firebase Console → Firestore → `users/{kingbonstrahUid}`.
4. Confirm `preferredLanguage` field is now `"fr"`.
5. Tap Arabic. Refresh Firebase Console. Field should be `"ar"`.
6. Tap English. Field should be `"en"`.

If the Firestore field doesn't update, check browser DevTools / device logs for `"Failed to sync preferredLanguage to Firestore"` messages — Firestore rules on the `users/{uid}` doc must permit the user to write to `preferredLanguage`. Section 6 covers this contingency.

### 5.5 — Verify diff before commit

```bash
git --no-pager diff lib/core/router/app_router.dart
git --no-pager diff lib/features/profile/screens/profile_screen.dart
git --no-pager status lib/features/profile/screens/language_settings_screen.dart
# Expected: untracked, then becomes new file after `git add`
```

---

## 6. Possible Snag — Firestore Rules

The screen calls `update({'preferredLanguage': ...})` on `users/{uid}`. The current rules at `firestore.rules` line 82 govern this collection. If the rule for self-writes restricts the field set (e.g., uses `keys().hasOnly([...])` and `preferredLanguage` is missing), the write will be rejected with a `PERMISSION_DENIED` error.

**To check before deploying:**
```bash
grep -n -A 30 "match /users/{userId}" firestore.rules | head -60
```

If the user-self-update rule restricts allowed field changes and does not include `preferredLanguage`, that rule needs to be updated separately. **This spec does NOT include a rules change** — flag any `PERMISSION_DENIED` symptom in testing and we'll handle it in a follow-up patch.

The local language change (Step 1 of `_onLanguageSelected`) succeeds regardless of rules — the user always sees the language switch immediately. Only cross-device sync depends on rules.

---

## 7. Commit & Tag

After verification passes:

```bash
cd ~/Development/Projects/qr_wallet

# Stage ONLY the intended files
git add lib/core/router/app_router.dart \
        lib/features/profile/screens/profile_screen.dart \
        lib/features/profile/screens/language_settings_screen.dart

# Verify what's about to be committed
git --no-pager diff --cached --stat
# Expected output: 3 files changed, ~130 insertions, ~3 deletions
# CRITICAL: should NOT show admin-dashboard/dist/, .firebase/, untracked PHASE_*.py, etc.

# Read the actual diff once before commit
git --no-pager diff --cached

# Commit
git commit -m "feat(11+12): language settings screen + profile language row

Step 11: Add Language menu item to Profile screen between Theme and
Notifications, navigating to a new language settings screen.

Step 12: New LanguageSettingsScreen mirroring ThemeSettingsScreen.
Lists English/Français/العربية. Tapping a language:
  1. Persists locally + updates Riverpod state (instant locale switch)
  2. If signed in, syncs users/{uid}.preferredLanguage to Firestore
  3. Refreshes local UserModel cache via AuthNotifier.updateUser

Reuses existing ARB keys (language, selectLanguage, languageDescription).
No new ARB keys, no gen-l10n needed."

git push origin main

# Tag this milestone
git tag phase6-step11-12-language-settings-complete
git push origin phase6-step11-12-language-settings-complete
```

---

## 8. Rollback Plan

If something breaks post-deploy:

```bash
# Revert the commit (creates a new commit that undoes the change)
git revert <commit-sha>
git push origin main
```

Or if not yet pushed:
```bash
git reset --hard HEAD~1
```

The change is purely additive (new file, new constant, new GoRoute, new menu item). No existing functionality was modified, so revert is safe — no migration / data implications. The `preferredLanguage` field already existed in `UserModel` from a prior phase; reverting this commit does not remove or alter user data.

---

## 9. Out of Scope — Confirmed Deferred

Documented here so the next session knows what is NOT in this commit:

- **Step 13 (first-launch language picker)** — separate scope, separate spec.
- **Disputes feature literal migration** — disputes screens still have hardcoded English (cleanup-5 candidate).
- **Pin screens literal migration** — `reset_pin_screen.dart` and `change_pin_screen.dart` still have hardcoded English (cleanup-5 candidate).
- **Snackbar after language change** — explicitly skipped per Q3=a; the locale rebuild is itself the confirmation.
- **Wrapping the Firestore write in `AuthService.updatePreferredLanguage(...)`** — explicitly inline-only per Section 1; can be promoted to a service method later if a second caller emerges.
- **Updating Firestore rules to whitelist `preferredLanguage`** — only addressed if Section 5.4 verification surfaces a `PERMISSION_DENIED` error.

---

## 10. Summary

5 mechanical changes across 3 files. All ARB keys pre-exist. Zero translation work. Zero schema changes. Zero existing functionality altered. Bundles Steps 11 and 12 as one atomic, revertable commit.

End of spec.
