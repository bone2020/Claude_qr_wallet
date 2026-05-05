# Phase 6 — App-Wide Localization (English / French / Arabic)

**Status:** SPEC — not yet implemented
**Author conversation:** 2026-05-05
**Target file path in repo:** `docs/PHASE_6_LOCALIZATION_SPEC.md`
**Estimated implementation effort:** 4–6 working sessions
**Risk level:** MEDIUM — touches every screen, but each change is small and additive
**Prerequisites:** None (predecessor to Phase 5i)

---

## How to Use This Document

Phase 6 is a wide-but-shallow project: a small framework change at the core, then a mechanical migration of strings across roughly 100 Dart files, plus three new screens (Settings hub entry, Language picker, first-launch picker). The risk is low per change but high in volume — there are many places to touch, and one missed string is one English word in an otherwise-French screen.

This spec is structured to enable **incremental, testable shipment**. Each of the 13 steps below is independently verifiable. A diligent implementer can complete steps 1–7 in one session, ship them as a no-op release (no user-visible change yet because all default strings are still English), then return for steps 8–13 in subsequent sessions to migrate strings and engage translators.

**Do not deviate from this spec without flagging it explicitly.** The codebase has existing patterns (`theme_provider.dart`, `currency_provider.dart`, `app_strings.dart`) that this spec mirrors deliberately — invent nothing new where existing patterns work.

**The Phase 5d cautionary tale applies.** Don't pattern-match. Read the existing files before editing them. Verify after each step.

---

## 1. Executive Summary

### What This Phase Builds

Phase 6 makes the entire QR Wallet Flutter app available in English, French, and Arabic — every screen, every button, every error message, every notification SMS, every email. The user picks their preferred language at first launch after the app update; the choice is changeable any time via Profile → Language. Arabic is rendered right-to-left, with Flutter's automatic RTL handling supplemented by per-screen verification.

The phase introduces no functional changes to the app's behavior. It is purely a presentation-layer redesign.

### Why It Matters

Eric's preference (recorded 2026-05-05): "We are looking at building an effective app where the user experience is great for everybody. Across Africa, people from different countries speak different languages, but these three cut across."

English alone limits the app to one slice of the African market. Adding French and Arabic unlocks French-speaking West Africa (Senegal, Côte d'Ivoire, Mali, Burkina Faso, Cameroon, etc.) and Arabic-speaking North Africa (Egypt, Morocco, Algeria, Tunisia, Sudan). These are large, mobile-money-active populations currently locked out of an English-only product.

### Why Localization Comes Before Phase 5i

Phase 5i (the dispute lifecycle redesign) is high-risk money-movement work. Localization is medium-risk, mostly mechanical. Sequencing localization first means:

1. Phase 5i ships on a stable, already-localized base — its new dispute screens and SMS templates get added in three languages from day one as routine work, rather than retrofitted later.
2. Bugs caused by language switching can never be confused with dispute-logic bugs.
3. Users get a tangible improvement (their own language) faster than they'd get the dispute redesign anyway.

This sequencing decision is recorded in `docs/PHASE_5I_RESOLVED.md` Section 1.

### Scope of This Phase

In scope:
- ✅ Flutter framework: `flutter_localizations` + ARB files (`app_en.arb`, `app_fr.arb`, `app_ar.arb`)
- ✅ User model: new `preferredLanguage` field (Hive + Firestore)
- ✅ Riverpod: new `languageNotifierProvider` mirroring the `themeNotifierProvider` pattern
- ✅ MaterialApp: wired to dynamic locale via the new provider
- ✅ Settings entry: new "Language" row on Profile screen, leading to a new `language_settings_screen.dart`
- ✅ First-launch picker: shown once after app update for users without a `preferredLanguage` set
- ✅ Migration of all `app_strings.dart` consumers to `AppLocalizations.of(context).foo`
- ✅ Migration of all hardcoded `Text(...)`, `hintText:`, `labelText:`, AppBar `title:` literals
- ✅ Backend: `sendCustomerSms()` and `sendProposalEmail()` localization
- ✅ Translator engagement and review process for French + Arabic
- ✅ RTL layout verification across all screens

Out of scope (explicitly deferred):
- Localizing strings inside `functions/index.js` audit log entries (admin-internal, English-only acceptable)
- Localizing admin dashboard (a separate React app, English-only — admins are internal staff)
- Localizing date/time formatting beyond what `intl` already provides automatically
- Adding more than three languages (Swahili, Portuguese, Hausa, etc. can come in future phases following the same framework)
- Crowdin / Lokalise integration (deferred — initial translations done as one-time engagement)
- In-app translation editing tools for non-developers

---

## 2. Conventions Used in This Spec

**Code blocks marked `// FIND:`** are exact text to locate in the existing codebase.

**Code blocks marked `// REPLACE WITH:`** are exact text to substitute.

**Code blocks marked `// NEW FILE:`** are entirely new files to create.

**File paths** are relative to the repository root: `lib/...`, `functions/...`, etc.

**ARB key naming convention:** camelCase, matching existing `AppStrings` field names where possible. New strings get descriptive camelCase keys (e.g., `disputeFiledNotification`, not `dispNotif1`).

**Languages:**
- English: `en` — source of truth, written first.
- French: `fr` — Standard French (France/West Africa), formal register.
- Arabic: `ar` — Modern Standard Arabic (MSA), formal register. Not regional dialect.

**Locale codes follow BCP 47:** `en`, `fr`, `ar` (no region suffix in v1; can be extended to `fr_CI`, `ar_EG` in future phases if regional variants are needed).

---

## 3. Current State (As of 2026-05-05)

### 3.1 What's Already in Place

The codebase has partial groundwork for localization:

- **`lib/core/constants/app_strings.dart`** exists and contains ~180 strings organized into 16 sections (App, Splash, Auth, Form Fields, Verification, KYC, Home, Send Money, Receive Money, Add Money, Transactions, Profile, Errors, Success, Buttons, KYC Verification Screens). All strings are `static const String` declarations on a private-constructor class.
- **167 references** to `AppStrings.*` exist across `lib/`. These are the easy migration sites.
- **`intl: ^0.18.1`** is already declared in `pubspec.yaml`. It's used today for date and number formatting in `transaction_tile.dart` and `transaction_details_screen.dart`. The package is present but `flutter_localizations` from the SDK is not yet declared.

### 3.2 What's Not in Place

- No `flutter_localizations` dependency.
- No `l10n.yaml` config.
- No ARB files (`app_en.arb`, `app_fr.arb`, `app_ar.arb`).
- No `AppLocalizations` import or usage anywhere.
- No `Locale` references in `MaterialApp.router` (no `localizationsDelegates`, no `supportedLocales`, no `locale`).
- No `preferredLanguage` field on `UserModel` (currently 17 fields, none of which is language).
- No `languageNotifierProvider`.
- No language picker screen.
- No first-launch language detection.
- ~140 hardcoded `Text('...')` widgets, ~40 hardcoded `hintText:` literals, ~58 hardcoded AppBar `title: Text(...)` literals, 1 hardcoded `labelText:` literal scattered across the codebase. Total estimated user-visible hardcoded strings: ~150-200.

### 3.3 Patterns This Spec Mirrors

Three existing patterns are used as templates:

- **`lib/providers/theme_provider.dart`** is the structural template for the new `language_provider.dart`. Same `StateNotifier` shape, same `LocalStorageService.saveSetting` / `getSetting` persistence, same provider exposure.
- **`lib/providers/currency_provider.dart`** is the persistence-to-Firestore template. Currency is saved both locally (via `theme`-style local cache) and to `users/{uid}.currency`. Language follows: `users/{uid}.preferredLanguage`.
- **`lib/features/profile/screens/theme_settings_screen.dart`** is the screen template for the new language picker — same scaffold, same visual style, same on-tap-save flow.

The spec does not invent new conventions. Where a pattern exists, the new code copies it.

### 3.4 Profile Feature Layout

The "settings hub" the user sees is `lib/features/profile/screens/profile_screen.dart`. It already contains rows leading to: Edit Profile, Change Password, Change PIN, Notification Settings, Theme Settings, Linked Accounts, Help & Support, About, plus a Currency Selector entry that routes to `lib/features/settings/screens/currency_selector_screen.dart`.

Phase 6 adds one more row to this hub: "Language", routing to a new `lib/features/profile/screens/language_settings_screen.dart`.

The currency selector remaining in `lib/features/settings/` is a small architectural inconsistency in the existing codebase (every other settings-type screen lives under `profile/`). Phase 6 does **not** move it — that would be scope creep and risks breaking the existing route. Future cleanup phases can normalize.

### 3.5 Routing

Routes are defined in `lib/core/router/app_router.dart`, with route name constants in the `AppRoutes` class at the top of that file (visible from line 56 onward). The convention is `static const String routeName = '/route-name';`. Phase 6 adds two new routes: `language` and `firstLaunchLanguage`.

### 3.6 User Model and Persistence

`lib/models/user_model.dart` defines `UserModel` with 17 Hive-annotated fields (`@HiveField(0)` through `@HiveField(16)`). Phase 6 adds `@HiveField(17) String? preferredLanguage`. This is forward-compatible: old cached `UserModel` objects deserialize cleanly with the new field as `null`, and the running app treats `null` as "not yet picked" → triggers first-launch picker.

The user document in Firestore (`users/{uid}`) stores fields including `currency`, `country`, etc. Language is added as a peer field: `preferredLanguage`. Existing users get this field populated either at first-launch picker time, or via a backfill script (see Section 11).

### 3.7 Notifications Backend

`functions/index.js` calls `sendCustomerSms({ phoneNumber, message, ... })` with hardcoded English `message` strings. Phase 6 adds: every call site reads `preferredLanguage` from the recipient's user document and selects the appropriate template variant. This is detailed in Section 7.

---

## 4. Target State (After Phase 6)

### 4.1 User Experience

**First launch after the update:**

1. User taps the app icon. Firebase initializes as today.
2. After `LocalStorageService.initialize()`, the app checks if the cached `UserModel` has a non-null `preferredLanguage`.
3. If yes → app proceeds normally with that locale set.
4. If no (new user, or upgraded user from before Phase 6) → a one-time **First-Launch Language Picker** screen appears before the existing splash screen.
5. The picker shows three large tappable cards: **English** / **Français** / **العربية**. Default visual highlight goes to the device locale if it matches one of the three; otherwise English.
6. User taps a card. The choice is saved to `LocalStorageService` as `preferred_language`, the `UserModel.preferredLanguage` field is set (and synced to Firestore on next user sync), and the app continues to its normal startup flow.
7. The user never sees this screen again unless they uninstall and reinstall.

**Changing language later:**

1. Profile → Language → tap a new language card → app instantly rebuilds in the new language.
2. The change persists locally and is synced to Firestore.
3. Subsequent SMS and email notifications come in the new language.

**Language detection logic at startup:**

```
if local storage has preferred_language:
    use that
else if Firestore user.preferredLanguage exists:
    use that, save to local storage
else if device locale is en/fr/ar:
    suggest that language (highlighted) on the picker screen, but require user tap
else:
    suggest English on the picker screen
```

### 4.2 Backend Notification Behavior

Every SMS and email sent by Cloud Functions:

1. Reads the recipient's `users/{uid}.preferredLanguage` (defaults to `en` if absent).
2. Selects the message template for that language from a new `i18n` module.
3. Substitutes parameters (amount, currency, dispute ID, etc.).
4. Sends.

For SMS specifically: **one SMS per user, in their language.** Not three-language stacked messages — that was considered and rejected for cost/readability reasons (see `PHASE_5I_RESOLVED.md` Q5).

### 4.3 RTL Layout for Arabic

When the active locale is `ar`:

- Flutter automatically flips the UI direction (text alignment, row order, navigation arrow direction, padding/margin sides).
- Most Material widgets handle this transparently.
- Custom layouts using `EdgeInsets.only(left: ...)` or hardcoded `MainAxisAlignment.start` may need adjustment to use `EdgeInsetsDirectional` and `MainAxisAlignment.start` (which is direction-aware) instead.
- Per-screen verification is required after migration.

---

## 5. Gap Analysis

| # | Gap | Severity |
|---|---|---|
| 1 | No `flutter_localizations` package | HIGH |
| 2 | No `l10n.yaml` config | HIGH |
| 3 | No ARB files for any language | HIGH |
| 4 | `MaterialApp.router` not wired to dynamic locale | HIGH |
| 5 | `UserModel` has no `preferredLanguage` field | HIGH |
| 6 | No `languageNotifierProvider` | HIGH |
| 7 | No language settings screen | HIGH |
| 8 | No first-launch language picker | HIGH |
| 9 | 167 sites still use static `AppStrings.foo` (need conversion to `AppLocalizations`) | MEDIUM |
| 10 | ~150-200 hardcoded user-visible strings outside `app_strings.dart` | MEDIUM |
| 11 | Backend SMS/email templates are English-only string literals | MEDIUM |
| 12 | No translator engagement | MEDIUM |
| 13 | RTL layout untested for Arabic | LOW |
| 14 | Profile screen has no "Language" row | LOW |
| 15 | `app_router.dart` has no `language` or `firstLaunchLanguage` routes | LOW |

### 5.1 Things This Spec Does NOT Change

- The structure of `app_strings.dart` itself stays as a class with `static const String` fields. After Phase 6, those fields hold the **English** values (the source of truth) and are the master copy from which `app_en.arb` is generated. Other languages live in `app_fr.arb` and `app_ar.arb`. The class is preserved for any backend-side code that still reads it directly (none expected, but defensive).
- The currency selector's location (still in `lib/features/settings/`) — defer architectural cleanup.
- Theme provider, currency provider, auth provider — all untouched by Phase 6 except for adding language-related sibling providers.
- The Hive type ID for `UserModel` stays at `0`. We add a new field (`@HiveField(17)`) without bumping the type ID; this is the Hive-recommended approach for forward-compatible field additions.

---

## 6. Detailed Design

### 6.1 Locale Resolution at Startup

The app resolves the active locale via this priority chain, evaluated in `MaterialApp.router`'s `locale` callback:

```
1. languageNotifierProvider.state  (in-memory, set after picker tap)
2. LocalStorageService.getSetting('preferred_language')  (Hive)
3. authNotifier.user.preferredLanguage  (Firestore-synced UserModel)
4. Platform device locale, IF it is en/fr/ar
5. Default: 'en'
```

The `languageNotifierProvider` initializes by reading 2 → 3 in order. If both are null, it leaves itself at a special "uninitialized" sentinel state, which the router uses to route to the first-launch picker before any other screen.

### 6.2 ARB File Structure

```
lib/
  l10n/
    app_en.arb         ← source language (English, master)
    app_fr.arb         ← French translations
    app_ar.arb         ← Arabic translations
  generated/
    l10n/              ← auto-generated by `flutter gen-l10n`, DO NOT edit
      app_localizations.dart
      app_localizations_en.dart
      app_localizations_fr.dart
      app_localizations_ar.dart
```

Each ARB file is JSON. The English file looks like:

```json
{
  "@@locale": "en",
  "appName": "QR Wallet",
  "@appName": {
    "description": "App name shown in title bars and splash"
  },
  "appTagline": "Seamless payments, anywhere",
  "@appTagline": {
    "description": "Tagline shown on splash screen"
  },
  "getStarted": "Get Started",
  "@getStarted": {},
  "signUp": "Sign up",
  "@signUp": {},
  "...": "..."
}
```

`@@locale` declares the language. Each translatable key (`appName`) is followed by an `@key` metadata object with a `description` (helps translators). Strings with parameters use ICU message format:

```json
"sentMoneyConfirmation": "You sent {amount} {currency} to {recipient}",
"@sentMoneyConfirmation": {
  "description": "Confirmation message after successful send",
  "placeholders": {
    "amount": { "type": "String", "example": "100.00" },
    "currency": { "type": "String", "example": "GHS" },
    "recipient": { "type": "String", "example": "John Doe" }
  }
}
```

The French and Arabic ARB files have the same keys but translated values, e.g., French:

```json
{
  "@@locale": "fr",
  "appName": "QR Wallet",
  "appTagline": "Paiements fluides, partout",
  "getStarted": "Commencer",
  "signUp": "S'inscrire",
  "...": "..."
}
```

### 6.3 The `languageNotifierProvider`

Mirrors `themeNotifierProvider` (file: `lib/providers/theme_provider.dart`). New file: `lib/providers/language_provider.dart`. Full code in Section 7.5.

Key behaviors:
- Initializes by reading `LocalStorageService.getSetting('preferred_language')`.
- Exposes `setLanguage(AppLanguage lang)` that writes to local storage AND updates Firestore via the existing user-update path AND emits new state.
- State type: `Locale?` — null means "first launch, picker not yet shown."
- Watched by `MaterialApp.router`'s `locale:` parameter.

### 6.4 First-Launch Picker Trigger

Routing logic in `app_router.dart` adds a redirect: if `languageNotifierProvider`'s state is `null`, redirect any incoming route to `/first-launch-language` until the user picks. Once they pick, the redirect clears and they land on the splash screen as normal.

### 6.5 Settings Entry on Profile Screen

A new tappable row on `profile_screen.dart`, sibling to the existing Theme Settings row. On tap → `context.push(AppRoutes.languageSettings)`.

### 6.6 Language Settings Screen

`lib/features/profile/screens/language_settings_screen.dart`. Visual structure mirrors `theme_settings_screen.dart`: an AppBar, a list of three cards (English/Français/العربية), each tappable, the currently-active one highlighted with a check icon. On tap: calls `languageNotifierProvider.notifier.setLanguage(...)`, the entire app rebuilds in the new language, and the user is back-navigated.

### 6.7 Backend Localization Module

A new file `functions/i18n.js` exporting:

```javascript
const TEMPLATES = {
  en: {
    disputeFiled_buyerConfirmation: (params) => `Dispute ${params.disputeId} filed. We'll investigate and update you.`,
    disputeFiled_sellerNotification: (params) => `A dispute has been filed against you for ${params.amount} ${params.currency}. Tap to respond.`,
    // ... all SMS/email templates
  },
  fr: { /* ... */ },
  ar: { /* ... */ },
};

function t(key, lang, params) {
  const langTemplates = TEMPLATES[lang] || TEMPLATES.en;
  const template = langTemplates[key] || TEMPLATES.en[key];
  if (typeof template !== 'function') {
    console.error(`i18n: missing template ${key} for lang ${lang}`);
    return TEMPLATES.en[key]?.(params) || `[Missing: ${key}]`;
  }
  return template(params);
}

async function getUserLanguage(uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  return userDoc.data()?.preferredLanguage || 'en';
}

module.exports = { t, getUserLanguage };
```

Then existing `sendCustomerSms` call sites change from:

```javascript
await sendCustomerSms({
  phoneNumber: user.phoneNumber,
  message: `Dispute ${disputeId} filed. We'll investigate.`,
  relatedTo: `dispute:${disputeId}`,
});
```

to:

```javascript
const lang = await getUserLanguage(user.uid);
await sendCustomerSms({
  phoneNumber: user.phoneNumber,
  message: t('disputeFiled_buyerConfirmation', lang, { disputeId }),
  relatedTo: `dispute:${disputeId}`,
});
```

### 6.8 Translation Workflow

1. Implementer completes Steps 1-9 (framework + screens + migration). All English ARB content is final.
2. Implementer generates `app_fr.arb` and `app_ar.arb` from `app_en.arb` with empty values for all keys (just the `@@locale` line and the keys, no translated text).
3. Implementer engages a professional translator. Files sent: `app_fr.arb` (for French translation), `app_ar.arb` (for Arabic translation), plus the English source for reference.
4. Translator returns the files with translations filled in.
5. **Native-speaker review** is conducted: a fluent French speaker reads through the French strings in context (the implementer runs the app in French and walks through key flows). Same for Arabic. Bug fixes returned to translator if needed.
6. Once both languages are reviewed: ARB files are committed to the repo.
7. The same translation cycle is run for the backend `functions/i18n.js` file — translator returns the `fr` and `ar` template objects.

**Estimated translation cost:** ~1,200-1,500 words per language at $0.10–0.20/word professional rate = **$120-300 per language, $240-600 total**. Phase 6 implementation budget should reserve this.

---

## 7. Implementation Steps (Detailed)

This is the implementer's primary build target. Each step is independently completable and testable. Steps 1-7 are framework/scaffolding (no user-visible change). Steps 8-9 are the migration (user-visible: same English text, just routed through `AppLocalizations`). Steps 10-13 add the languages and ship.

### Step 1: Add Flutter Localization Dependencies

**File:** `pubspec.yaml`

**FIND:**
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9
```

**REPLACE WITH:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9
```

The existing `intl: ^0.18.1` line (later in the file) stays as-is. `flutter_localizations` from the SDK has no version pin (it's tied to the Flutter SDK version).

**Verification:** Run `flutter pub get`. Should complete without errors. App should still build and run normally — no behavior change yet.

---

### Step 2: Create `l10n.yaml` Config

**File:** `l10n.yaml` (NEW, repo root)

**NEW FILE:**
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated/l10n
synthetic-package: false
nullable-getter: false
```

**Verification:** File exists. No build errors. (No ARB files exist yet, so `flutter gen-l10n` will fail until Step 3.)

---

### Step 3: Create `app_en.arb` from `app_strings.dart`

**File:** `lib/l10n/app_en.arb` (NEW)

Pour the contents of `lib/core/constants/app_strings.dart` into ARB format. Every `static const String foo = 'value';` becomes:

```json
"foo": "value",
"@foo": {}
```

Strings with placeholders (e.g., `'Currency changed to ${currency.name}'` from `currency_selector_screen.dart`) become ICU message format with declared placeholders.

**The implementer must do this conversion manually**, looking at `app_strings.dart` end to end. The full ARB file will be ~180 keys + every newly-discovered hardcoded string from Steps 8-9 (final count ~330-380). Initial creation in this step covers only the `app_strings.dart` content; hardcoded strings get added in Step 9.

**Verification:** Run `flutter gen-l10n` from the repo root. Should produce `lib/generated/l10n/app_localizations.dart`, `app_localizations_en.dart`, etc. The file `app_localizations.dart` should declare an `AppLocalizations` class with getter methods matching every ARB key. No build errors.

---

### Step 4: Create Empty `app_fr.arb` and `app_ar.arb`

**Files:** `lib/l10n/app_fr.arb`, `lib/l10n/app_ar.arb` (NEW)

For each, copy the structure of `app_en.arb` but with empty string values:

```json
{
  "@@locale": "fr",
  "appName": "",
  "appTagline": "",
  "getStarted": "",
  "...": "..."
}
```

These get filled in by the translator in Step 10. For now, having them present (with empty values) lets `flutter gen-l10n` produce the full set of language classes, and Flutter will fall back to English at runtime for any empty translation (with a warning logged).

**Verification:** `flutter gen-l10n` produces files for all three languages. Build succeeds.

---

### Step 5: Add `preferredLanguage` to UserModel

**File:** `lib/models/user_model.dart`

**Change A — Add the Hive field annotation:**

**FIND:** the field block ending with `@HiveField(16) final String? legalName;` (line ~52).

**REPLACE WITH (add after legalName):**
```dart
  @HiveField(16)
  final String? legalName;

  @HiveField(17)
  final String? preferredLanguage;  // 'en' | 'fr' | 'ar' | null (null = not yet picked)
```

**Change B — Add to constructor:**

**FIND:**
```dart
    this.legalName,
  });
```

**REPLACE WITH:**
```dart
    this.legalName,
    this.preferredLanguage,
  });
```

**Change C — Add to `fromJson`:**

**FIND:**
```dart
      legalName: json['legalName'] as String?,
    );
  }
```

**REPLACE WITH:**
```dart
      legalName: json['legalName'] as String?,
      preferredLanguage: json['preferredLanguage'] as String?,
    );
  }
```

**Change D — Add to `toJson`:**

**FIND:**
```dart
      if (legalName != null) 'legalName': legalName,
    };
```

**REPLACE WITH:**
```dart
      if (legalName != null) 'legalName': legalName,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    };
```

**Change E — Add to `copyWith`:**

**FIND:** the `copyWith` method's parameter list, ending with `String? legalName,`. Add `String? preferredLanguage,` after it.

Then in the body, add `preferredLanguage: preferredLanguage ?? this.preferredLanguage,` to the returned `UserModel(...)`.

**Change F — Regenerate the Hive adapter:**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This regenerates `lib/models/user_model.g.dart` to include the new field in serialization.

**Verification:**
- File compiles.
- `user_model.g.dart` is updated; `git diff` should show one new field reference in the adapter.
- App still runs. Existing cached users should load correctly with `preferredLanguage` defaulting to null. No data loss.

---

### Step 6: Create `language_provider.dart`

**File:** `lib/providers/language_provider.dart` (NEW)

**NEW FILE:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/local_storage_service.dart';
import 'auth_provider.dart';

/// Supported app languages
enum AppLanguage {
  english('en', 'English', 'English'),
  french('fr', 'French', 'Français'),
  arabic('ar', 'Arabic', 'العربية');

  final String code;
  final String englishName;
  final String nativeName;
  const AppLanguage(this.code, this.englishName, this.nativeName);

  static AppLanguage? fromCode(String? code) {
    if (code == null) return null;
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  Locale get locale => Locale(code);
}

/// Language state — null means "not yet picked, show first-launch picker"
class LanguageNotifier extends StateNotifier<AppLanguage?> {
  final LocalStorageService _localStorage;

  LanguageNotifier(this._localStorage) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final code = await _localStorage.getSetting<String>(
      'preferred_language',
      defaultValue: null,
    );
    state = AppLanguage.fromCode(code);
  }

  /// Set language. Persists locally and updates state.
  /// Firestore sync happens via the auth notifier's `updateUser` flow,
  /// which the caller should invoke if the user is signed in.
  Future<void> setLanguage(AppLanguage lang) async {
    await _localStorage.saveSetting('preferred_language', lang.code);
    state = lang;
  }

  /// Force-set state without persisting (used by first-launch picker
  /// before LocalStorageService has been initialized for this user).
  void setLanguageInMemory(AppLanguage lang) {
    state = lang;
  }
}

/// Language notifier provider
final languageNotifierProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguage?>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return LanguageNotifier(localStorage);
});

/// Current locale provider — returns Locale('en') if no language picked yet
/// (this lets the app render English on the first-launch picker screen itself,
/// since picker text is shown in all three languages so any base locale works)
final currentLocaleProvider = Provider<Locale>((ref) {
  final lang = ref.watch(languageNotifierProvider);
  return lang?.locale ?? const Locale('en');
});

/// Has the user picked a language yet?
final hasPickedLanguageProvider = Provider<bool>((ref) {
  return ref.watch(languageNotifierProvider) != null;
});
```

**Update `lib/providers/providers.dart`:**

**FIND:**
```dart
export 'auth_provider.dart';
export 'connectivity_provider.dart';
export 'wallet_provider.dart';
export 'theme_provider.dart';
```

**REPLACE WITH:**
```dart
export 'auth_provider.dart';
export 'connectivity_provider.dart';
export 'wallet_provider.dart';
export 'theme_provider.dart';
export 'language_provider.dart';
```

**Verification:** App compiles. Provider can be watched without error. State starts as `null` for any user without a saved language (which is everyone, until the picker runs). Calling `setLanguage(AppLanguage.french)` updates state to `AppLanguage.french` and persists.

---

### Step 7: Wire `MaterialApp.router` to Dynamic Locale

**File:** `lib/main.dart`

**Change A — Add imports:**

**FIND:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

**REPLACE WITH:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

**Change B — Add the locale wiring to MaterialApp.router:**

**FIND:**
```dart
    return MaterialApp.router(
      title: 'QR Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
```

**REPLACE WITH:**
```dart
    final locale = ref.watch(currentLocaleProvider);

    return MaterialApp.router(
      title: 'QR Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
```

**Change C — Import AppLocalizations:**

Add at the top imports section:
```dart
import 'generated/l10n/app_localizations.dart';
```

(The exact path depends on `synthetic-package: false` in `l10n.yaml` — should match.)

**Verification:** App compiles. Runs in English (because no other ARB content yet). `MaterialApp` is now correctly localized. No visible change to the user yet.

---

### Step 8: Migrate `AppStrings` Consumers to `AppLocalizations`

**Scope:** 167 sites across the codebase, identified by `grep -rn "AppStrings\." lib --include="*.dart"`.

**Migration pattern:**

```dart
// BEFORE:
Text(AppStrings.signUp)

// AFTER:
Text(AppLocalizations.of(context)!.signUp)
```

For each file containing `AppStrings.foo` references:

1. Add import: `import 'package:qr_wallet/generated/l10n/app_localizations.dart';` (or the appropriate relative path).
2. Replace every `AppStrings.foo` with `AppLocalizations.of(context)!.foo`.
3. If the file is a `StatelessWidget`'s build method or `ConsumerWidget`'s build method, `context` is available directly.
4. If the call site is inside a non-widget method (e.g., a snackbar shown from a callback), pass `context` in.
5. For `static const` defaults that need the value at compile time (rare — none currently expected), keep using `AppStrings.foo` as a fallback, but flag for case-by-case review.

**Bulk-replace strategy:**

Since all 167 references follow the same pattern, the implementer can use VS Code or a script:
1. Find: `AppStrings\.(\w+)`
2. Replace: `AppLocalizations.of(context)!.$1`
3. Apply across `lib/` excluding `lib/core/constants/app_strings.dart` itself (which stays).
4. Then walk through each modified file to ensure `context` is in scope and the import is added.

**`AppStrings` class fate:** Keep the file. After this migration, nothing in `lib/` should reference `AppStrings.foo` (verified by `grep -rn "AppStrings\." lib --include="*.dart" | grep -v "lib/core/constants/app_strings.dart"` returning empty). The file becomes a documentation reference for the English source-of-truth strings, useful for translators and for keeping ARB and code in sync. Future maintenance: when adding a new string, update both `app_strings.dart` AND `app_en.arb` simultaneously to keep them paired.

**Alternative (deferred decision):** delete `app_strings.dart` entirely. Cleaner, but losing a useful reference document. Recommendation: keep the file with a banner comment at the top: `/// SOURCE OF TRUTH FOR ENGLISH STRINGS — sync changes with lib/l10n/app_en.arb`. The implementer should make this call after seeing how the migration feels.

**Verification:** App compiles. Every screen that previously showed an `AppStrings.foo` value now shows the same string sourced from `AppLocalizations`. No visible change to the user. `grep -rn "AppStrings\." lib --include="*.dart"` should return 0 results outside of `app_strings.dart` itself.

---

### Step 9: Migrate Hardcoded String Literals

**Scope:** ~150-200 hardcoded strings in `Text('...')`, `hintText: '...'`, `labelText: '...'`, AppBar `title: Text(...)`, snackbar `content: Text(...)`, alert dialog titles/contents.

**Methodology:** Walk through the codebase systematically, file by file. For each hardcoded string:

1. Decide if it's user-visible. Skip dynamic content like `Text('$count items')` where the static portion is small ('items') vs. computed parts. For these, the static piece migrates: `'$count items'` becomes `AppLocalizations.of(context)!.itemCount(count)` with a parameterized ARB entry.
2. Pick a camelCase ARB key. Examples:
   - `Text('Phone Verification')` → key `phoneVerificationTitle`
   - `hintText: 'Enter your email'` → key `enterEmailHint`
   - `Text('Verify Code')` → key `verifyCodeButton`
3. Add the entry to `app_en.arb`.
4. Replace the hardcoded string in code with `AppLocalizations.of(context)!.<key>`.

**File ordering for migration:**

1. `lib/features/auth/` — most hardcoded strings live here, per the grep sample
2. `lib/features/home/`
3. `lib/features/send/`
4. `lib/features/receive/`
5. `lib/features/wallet/`
6. `lib/features/transactions/`
7. `lib/features/disputes/` (note: Phase 5i will add more strings here later — Phase 6 only migrates what exists today)
8. `lib/features/profile/`
9. `lib/features/notifications/`
10. `lib/features/settings/`
11. `lib/features/splash/`
12. `lib/core/widgets/` and any remaining shared widgets

**Per-file checklist:**

After each file is migrated, the implementer:
1. Counts hardcoded strings before and after (`grep -c "Text('"` on the file before and after migration).
2. Confirms all visible strings on every screen still display correctly in English (by running the app and walking the flow).
3. Commits the file change with a message like `i18n: migrate auth screens to AppLocalizations`.

This is the largest step in Phase 6 by far. Realistic effort: 1-2 working sessions of focused mechanical work. Splitting the commits per feature folder gives natural rollback points if something breaks.

**Verification:**
- `grep -rn "Text('" lib --include="*.dart" | wc -l` decreases from ~140 to under ~30 (some `Text('...')` calls are debug or non-user-visible and stay).
- `grep -rn "hintText: '" lib --include="*.dart" | wc -l` decreases from ~40 to under 5.
- App runs in English. Every screen visually identical to before Phase 6.
- `app_en.arb` has grown to ~330-380 keys.

---

### Step 10: Engage Translators

**Action by Eric (operator), not implementer:**

1. Take the final `app_en.arb` (after Step 9 is complete).
2. Generate empty `app_fr.arb` and `app_ar.arb` with all the same keys, empty values.
3. Send to a professional translator. Recommended sources:
   - Upwork or Fiverr for individual translators (look for finance/fintech experience)
   - Gengo, Smartling, Lokalise for managed translation services
   - Local translation agencies in Ghana, Senegal, or Egypt
4. **Brief the translator:**
   - Target: formal/standard register (not slang)
   - Domain: mobile money / financial services
   - Audience: general public, not technical users
   - Note: this is a financial app — terms like "send money," "withdraw," "balance," "transaction" must be translated with the precise meaning, not approximations
   - Provide context for ambiguous keys via the `description` field in ARB metadata
5. Receive completed `app_fr.arb` and `app_ar.arb`.
6. Commit them to the repo.

**Same process for the backend:**

1. Take the final `functions/i18n.js` template list (after Step 12 is implemented).
2. Send to translator with same brief.
3. Receive translated template objects, integrate.

**Native-speaker review:**

After translations are received but before shipping, have a native speaker of each language walk through the app in their language and flag any awkward, incorrect, or culturally tone-deaf translations. The implementer fixes these via translator round-trip or, for small corrections, directly. **Do not skip this step.** Machine translation and even professional translation can produce strings that read fine in isolation but feel wrong in app context.

---

### Step 11: Add Settings Entry — Profile → Language Row

**File:** `lib/features/profile/screens/profile_screen.dart`

**Change:** Add a new row, sibling to the existing Theme Settings row. The exact position should be just below the Theme Settings row in the visual hierarchy.

The implementer must read the existing profile screen to find the right location for the new row. The pattern will look something like:

```dart
_buildSettingsRow(
  icon: Iconsax.global,
  label: AppLocalizations.of(context)!.language,
  trailing: Text(
    ref.watch(languageNotifierProvider)?.nativeName ?? 'English',
    style: AppTextStyles.bodySmall(),
  ),
  onTap: () => context.push(AppRoutes.languageSettings),
),
```

Add a new ARB key `language` to `app_en.arb`: `"language": "Language"`. (And to `app_fr.arb`: `"language": "Langue"`. And to `app_ar.arb`: `"language": "اللغة"`.)

**Verification:** A new "Language" row appears on the Profile screen. Tapping it navigates to the language settings screen (which doesn't exist yet — implementer creates in Step 12).

---

### Step 12: Build Language Settings Screen

**File:** `lib/features/profile/screens/language_settings_screen.dart` (NEW)

Mirrors the structure of `theme_settings_screen.dart`. The implementer reads that file first, then writes the language version following the same pattern. The screen shows three tappable cards (English, Français, العربية), each with a flag emoji or icon, and a check icon on whichever is currently selected.

On tap of a card:
1. Calls `ref.read(languageNotifierProvider.notifier).setLanguage(...)`.
2. If the user is signed in, also updates Firestore: `users/{currentUid}.preferredLanguage = code`. The auth notifier's `updateUser` flow handles caching.
3. The MaterialApp rebuilds (because `currentLocaleProvider` updates).
4. The user sees the entire app in the new language immediately.
5. A snackbar confirms the change.

**Add route:** in `lib/core/router/app_router.dart`, register the new route:
```dart
static const String languageSettings = '/language-settings';
```
And add a `GoRoute` entry for it pointing to `LanguageSettingsScreen`.

**Verification:**
- Profile → Language opens the new screen
- Three options visible
- Currently-active language shown with check
- Tap French → app instantly rebuilds, every UI string is now French (or English if `app_fr.arb` is empty for that string)
- Tap Arabic → app rebuilds, RTL layout, every string in Arabic
- Tap English → app rebuilds back to English
- Setting persists across app restarts
- Setting persists to Firestore (verify via Firebase Console)

---

### Step 13: First-Launch Language Picker

**File:** `lib/features/auth/screens/first_launch_language_screen.dart` (NEW)

A simple full-screen widget that shows the QR Wallet logo at top, the prompt "Choose your language / Choisissez votre langue / اختر لغتك" (in all three languages stacked, since the user hasn't picked yet), and three large tappable cards. Tapping a card calls `setLanguage()` and navigates to the splash screen.

**Routing logic in `app_router.dart`:**

Add a redirect in the GoRouter config: if `hasPickedLanguageProvider` is `false` AND the current route is not `/first-launch-language`, redirect to `/first-launch-language`. Once the language is picked, the redirect is no-op and the user proceeds normally.

**Add route constant:**
```dart
static const String firstLaunchLanguage = '/first-launch-language';
```

**Default highlight on the picker:** read the device locale via `WidgetsBinding.instance.platformDispatcher.locale`. If it's `en`, `fr`, or `ar`, highlight that card visually (border, slight color tint) but still require a tap to confirm. If the device locale is something else, highlight English.

**Verification:**
- Fresh install: app launches → first-launch picker appears before splash
- Pick a language → app proceeds to splash with that language active
- Restart app: skips the picker (language is now persisted)
- Clear app data: picker appears again on next launch
- Existing user with `preferredLanguage` already set in Firestore: picker does NOT appear (because `_init()` in language provider reads from local storage on launch — but for an existing user upgrading from pre-Phase-6, local storage won't have it yet. SEE migration handling below)

**Migration handling for existing users:**

For an existing user whose Firestore `users/{uid}` already has `preferredLanguage` set (e.g., they previously used the app, signed in, but haven't opened it since Phase 6 deploy), the local storage will be empty until first sign-in completes. The flow is:

1. App launches → local storage empty → `LanguageNotifier` state = `null` → first-launch picker shown.
2. User picks a language at the picker (call it `lang_picker_choice`).
3. After picker, app continues to splash → auth flow → user signs in.
4. Auth notifier loads user from Firestore. The Firestore `preferredLanguage` may or may not match `lang_picker_choice`.
5. **Decision:** local storage / picker choice **wins** for the current session. After successful sign-in, the local storage value is synced UP to Firestore (overwriting any older value).

This avoids the surprising UX where a user picks a language at first launch and then sees the app silently switch to their old saved language after they sign in. The picker choice always wins for that session.

For users created BEFORE Phase 6 who never had the chance to set `preferredLanguage`: their Firestore document just doesn't have the field. The picker shows, they pick, the field gets created. No special migration script needed.

---

## 8. Backend Changes

### 8.1 Create `functions/i18n.js`

**NEW FILE:** `functions/i18n.js` — full content per Section 6.7 above.

The file exports a `t(key, lang, params)` function and a `getUserLanguage(uid)` async helper. Templates for all three languages live in this file as nested objects.

Initial commit of this file should have **only English templates filled in**. The French and Arabic template objects are present but empty. Functions will fall back to English if the user's preferred language has no template — with a console.error log for the missing key, so monitoring catches gaps.

### 8.2 Migrate `sendCustomerSms` Call Sites

**Scope:** Every site in `functions/index.js` that calls `sendCustomerSms({...})` with a hardcoded English `message` string.

**Pattern:**

```javascript
// BEFORE:
await sendCustomerSms({
  phoneNumber: someUser.phoneNumber,
  message: `Welcome to QR Wallet, ${someUser.fullName}!`,
  relatedTo: 'signup',
});

// AFTER:
const lang = await getUserLanguage(someUser.uid);
await sendCustomerSms({
  phoneNumber: someUser.phoneNumber,
  message: t('welcomeNewUser', lang, { fullName: someUser.fullName }),
  relatedTo: 'signup',
});
```

For each migrated site, add the corresponding entry to the templates in `functions/i18n.js`.

**Identifying call sites:** `grep -n "sendCustomerSms" functions/index.js`. Walk each one. Estimated count: ~30-50 call sites currently.

### 8.3 Migrate `sendProposalEmail` Call Sites

Same pattern, for the email helper. Smaller scope (~10-15 sites).

### 8.4 Add `preferredLanguage` to Firestore Rules

**File:** `firestore.rules`

The user document update rules need to allow `preferredLanguage` as an updateable field by the user themselves. The exact location depends on the existing rules layout — implementer reads `firestore.rules`, finds the `users/{userId}` write rule, and ensures `preferredLanguage` is in the allow-list of fields the user can update.

Pattern (template — adapt to actual rules structure):

```
match /users/{userId} {
  allow update: if request.auth.uid == userId
    && request.resource.data.diff(resource.data).affectedKeys()
       .hasOnly([
         /* existing fields */,
         'preferredLanguage'
       ]);
}
```

**Verification:**
- Sign in as a user.
- Try to update `preferredLanguage` via the app → should succeed.
- Try to update it via direct Firestore SDK call from a different user → should fail.

### 8.5 Backfill Script (Optional)

**File:** `functions/scripts/backfill_preferred_language.js` (NEW, optional)

A one-time admin script that scans all users, sets `preferredLanguage: 'en'` on any document where the field is missing. Useful for data hygiene but not strictly necessary — the app handles missing values gracefully (defaults to English).

```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

(async () => {
  const snap = await db.collection('users').get();
  let updated = 0;
  for (const doc of snap.docs) {
    if (doc.data().preferredLanguage === undefined) {
      await doc.ref.update({ preferredLanguage: 'en' });
      updated++;
    }
  }
  console.log(`Backfilled preferredLanguage on ${updated} users.`);
})();
```

Run via `firebase functions:shell` or as a one-off Cloud Function after Phase 6 deploy.

---

## 9. Deployment Order

This order is binding. Each step is verifiable before proceeding.

**Stage 1 — Framework (no user-visible change):**
- Step 1: pubspec dependencies
- Step 2: l10n.yaml
- Step 3: app_en.arb
- Step 4: empty app_fr.arb / app_ar.arb
- Step 5: UserModel.preferredLanguage
- Step 6: language_provider.dart
- Step 7: MaterialApp.router wiring

After Stage 1: app builds, runs, looks identical to before. No regression.

**Stage 2 — Code migration (no user-visible change in English):**
- Step 8: AppStrings → AppLocalizations
- Step 9: hardcoded literals → AppLocalizations

After Stage 2: app still looks identical in English, but every string is now localizable.

**Stage 3 — Languages (translation work, then ship):**
- Step 10: engage translators, receive translations, native-speaker review
- Step 11: Profile → Language row added
- Step 12: Language settings screen
- Step 13: First-launch picker

After Stage 3: ship to App Store / Play Store. Users get the language picker on launch.

**Stage 4 — Backend (notifications):**
- Step 8.1: i18n.js
- Step 8.2: sendCustomerSms migration
- Step 8.3: sendProposalEmail migration
- Step 8.4: Firestore rules update

After Stage 4: deploy Cloud Functions. Subsequent SMS/email goes out in user's preferred language.

**Stage 5 — Cleanup (optional):**
- Step 8.5: backfill script

---

## 10. Verification Plan

### 10.1 Per-Step Verification

Each step has a dedicated verification block in Section 7. Implementers must complete that verification before moving to the next step.

### 10.2 Integration Verification (After Stage 3)

**Test in English:**
1. Fresh install
2. First-launch picker appears
3. Pick English
4. App launches in English
5. Walk every primary flow (signup, login, send money, receive money, view transactions, profile)
6. Verify every string is in English
7. Profile → Language → confirm English is highlighted
8. Tap Theme Settings → still works as before

**Test in French:**
1. Profile → Language → tap Français
2. App rebuilds; every visible string in French
3. Snackbars, dialogs, error messages all in French
4. Forms accept input correctly (French keyboard support)
5. Pull-to-refresh, loaders, etc. all work
6. Background send/receive an actual transaction
7. Transaction details screen in French
8. Verify SMS notifications come in French (after Stage 4 deploys)

**Test in Arabic:**
1. Profile → Language → tap العربية
2. App rebuilds in RTL layout
3. Walk every primary flow
4. Verify text right-aligns
5. Verify navigation arrows reverse direction
6. Verify form input fields align text right
7. Verify dialogs are mirrored
8. Walk through the dispute flow specifically (since that's what Phase 5i depends on) — every string in Arabic, layout coherent
9. Verify SMS notifications come in Arabic

**Edge cases:**
1. Switch language mid-flow (e.g., on the send money review screen): app rebuilds without crashing, no in-flight transaction affected
2. Switch language while offline: works locally (LocalStorageService); Firestore sync deferred until online
3. Sign out and sign back in: preferredLanguage retrieved from Firestore overrides local cache if they differ
4. Clear app data and reopen: first-launch picker appears again

### 10.3 Backend Verification (Stage 4)

1. Set test user's `preferredLanguage` to `fr` in Firestore.
2. Trigger an SMS-sending event (e.g., file a dispute).
3. Verify the SMS arrives in French.
4. Repeat for `ar` and `en`.
5. Set a user's `preferredLanguage` to a value not in {en, fr, ar} (e.g., `de`). Trigger SMS. Verify it falls back to English. Verify a console.error is logged for the missing language.

---

## 11. Migration of Existing Users

### 11.1 Existing Cached UserModel Objects

Hive's `@HiveField` system is forward-compatible. Old cached `UserModel` objects (without `preferredLanguage`) deserialize cleanly with `preferredLanguage = null`. The app handles `null` gracefully by routing through the first-launch picker.

### 11.2 Existing Firestore User Documents

Firestore is schemaless. Existing `users/{uid}` documents simply don't have the `preferredLanguage` field. The app handles missing fields by treating them as null. No schema migration is needed.

The optional backfill script in Step 8.5 can normalize this if desired, but it's not required.

### 11.3 In-Flight Phase 5e/5f/5g/5h Disputes

These disputes (currently in various states) continue under the existing English-only notification path until Phase 6 is fully deployed. After deploy, any new SMS sent for these disputes (e.g., resolution notification) will use the user's `preferredLanguage` if set. The transition is graceful.

### 11.4 Active Sessions at Deploy Time

A user actively using the app at deploy time (e.g., in the middle of a send-money flow) will not be interrupted. The next time they cold-start the app, they'll see the first-launch picker. This is the intended behavior — it doesn't disrupt active flows.

---

## 12. Rollback Plan

### 12.1 Per-Step Rollback

Each step is in its own commit (per the per-file commit guidance in Step 9). Reverting a single commit reverts a single step.

### 12.2 Stage-Level Rollback

**If Stage 1 (framework) breaks:** revert all framework commits, app returns to pre-Phase-6 state. No data loss because no migration occurred.

**If Stage 2 (code migration) breaks:** revert the migration commits. AppStrings references stay intact. `app_strings.dart` was preserved in Step 8 specifically for this reason.

**If Stage 3 (languages + screens) breaks:** disable the first-launch picker route by removing the redirect in `app_router.dart`. Disable the Profile → Language row. The provider exists but is unused. App falls back to English on all screens.

**If Stage 4 (backend) breaks:** disable the `getUserLanguage` call in i18n.js — return `'en'` always. SMS/email goes out in English while the bug is fixed.

### 12.3 Translation Quality Issues

If a translation is wrong/offensive/embarrassing in production:

1. **Hot fix the ARB file** — edit the offending key value, run `flutter gen-l10n`, build, ship a patch release.
2. **Hot fix the backend template** — edit `functions/i18n.js`, deploy that one function. No app update needed for SMS/email fixes.
3. **For severe issues:** temporarily disable the affected language via a remote config flag (out of scope for v1; consider for v2 if quality issues recur).

---

## 13. Reference

### 13.1 Glossary

- **ARB (Application Resource Bundle):** JSON-based localization file format used by Flutter's `gen-l10n` tool.
- **ICU Message Format:** the syntax used inside ARB string values to support placeholders, plurals, and gender (e.g., `{count, plural, =0{none} =1{one} other{# items}}`).
- **Locale:** a language + optional region code (e.g., `en`, `fr_CA`, `ar_EG`). Phase 6 uses language-only locales.
- **RTL (Right-to-Left):** the writing direction used by Arabic, Hebrew, etc. Flutter handles most layout flipping automatically.
- **AppLocalizations:** the auto-generated class produced by `flutter gen-l10n`. Has a getter for every ARB key.

### 13.2 Files Created in Phase 6

- `l10n.yaml`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_ar.arb`
- `lib/generated/l10n/app_localizations*.dart` (auto-generated, gitignored is fine but committing is also fine)
- `lib/providers/language_provider.dart`
- `lib/features/profile/screens/language_settings_screen.dart`
- `lib/features/auth/screens/first_launch_language_screen.dart`
- `functions/i18n.js`
- `functions/scripts/backfill_preferred_language.js` (optional)

### 13.3 Files Modified in Phase 6

- `pubspec.yaml`
- `lib/main.dart`
- `lib/models/user_model.dart` (and regenerated `user_model.g.dart`)
- `lib/providers/providers.dart`
- `lib/core/router/app_router.dart`
- `lib/features/profile/screens/profile_screen.dart`
- `firestore.rules`
- `functions/index.js` (every `sendCustomerSms` and `sendProposalEmail` call site)
- ~80-100 other Flutter files (the migration of hardcoded strings + AppStrings consumers)

### 13.4 Open Questions for Eric (Pre-Implementation)

The implementing AI must get answers to these before starting:

1. **Translator engagement:** does Eric have a preferred translator/agency, or should the implementer recommend specific options (Upwork, Gengo, etc.)? Cost approval needed before engagement.

2. **Native-speaker reviewers:** does Eric have French and Arabic-fluent contacts who can do the review pass, or does the implementer recommend professional review services?

3. **`AppStrings` class fate:** delete after migration, or keep as English source-of-truth reference? (Recommendation: keep with banner comment.)

4. **Auto-detection vs. always-pick:** should the first-launch picker auto-select the device language if it's en/fr/ar (and just confirm with a tap), or always start neutral? (Recommendation: highlight device language as the suggestion, but require explicit tap.)

5. **Currency selector relocation:** keep in `lib/features/settings/` (current location) or move to `lib/features/profile/screens/` to match other settings? (Recommendation: defer — out of scope for Phase 6.)

6. **Backend rollout:** deploy backend i18n migration in same release as the app, or stage it 1 week earlier so users can update their language preference before SMS templates change? (Recommendation: deploy backend FIRST, with English-only template content for fr/ar — same behavior as today. Then ship app. Then push backend update with translated templates. Reduces blast radius if anything goes wrong.)

---

## 14. Decision Audit Trail

| Decision | Date | Made By | Source |
|---|---|---|---|
| Phase 6 added as predecessor to Phase 5i | 2026-05-05 | Eric | `PHASE_5I_RESOLVED.md` Section 1 |
| Three languages: English, French, Arabic | 2026-05-05 | Eric | `PHASE_5I_RESOLVED.md` Q5 |
| Full app localization, not just notifications | 2026-05-05 | Eric | `PHASE_5I_RESOLVED.md` Q5 + chat |
| One language per user (not multi-lang messages) | 2026-05-05 | Eric | Confirmed in chat |
| Settings hub via existing Profile screen pattern | 2026-05-05 | Eric | Q4 → Option X chat answer |

---

## End of Phase 6 Specification

Commit alongside `PHASE_5I_SPEC.md` and `PHASE_5I_RESOLVED.md` in the `docs/` directory.

**Total length:** ~1300 lines.
**Implementation effort estimate:** 4-6 working sessions (~20-30 hours of focused work, plus translator turnaround time which is asynchronous).
**Translation budget:** $240-600 USD professional translation fees + native-speaker review time.
**Risk level:** MEDIUM — wide surface area, but each change is small and additive. Rollback plan exists per stage.
**Operator sign-off required before implementation:** Eric must approve translator engagement (cost) and confirm any of the open questions in Section 13.4 before Step 10.

End of file.
