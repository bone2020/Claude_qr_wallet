import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

/// Supported app languages for Phase 6 v1.
///
/// Each value carries:
///   - [code]       — BCP 47 language code stored in local storage and Firestore
///   - [englishName]— English name of the language (e.g. "French")
///   - [nativeName] — native rendering of the name (e.g. "Français", "العربية")
///
/// The native name is what the language picker displays so a French speaker
/// who doesn't read English still recognises their language.
enum AppLanguage {
  english('en', 'English', 'English'),
  french('fr', 'French', 'Français'),
  arabic('ar', 'Arabic', 'العربية');

  final String code;
  final String englishName;
  final String nativeName;

  const AppLanguage(this.code, this.englishName, this.nativeName);

  /// Resolve a stored language code (or null) back to the enum value.
  /// Returns null for unknown or null input — callers treat null as
  /// "user has not yet picked a language" and route to the first-launch
  /// picker (Step 13).
  static AppLanguage? fromCode(String? code) {
    if (code == null) return null;
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  /// Convert this language to a Flutter [Locale] for MaterialApp.
  Locale get locale => Locale(code);
}

/// SharedPreferences key for the user's chosen language code.
const String _kPreferredLanguageKey = 'preferred_language';

/// Riverpod state notifier holding the user's chosen language.
/// State is `null` until the user has picked a language. The router
/// uses this to redirect new users to the first-launch language picker
/// (see Step 13 of the localization spec).
///
/// Mirrors the structure of [ThemeNotifier] in theme_provider.dart so
/// future maintainers can follow one pattern, not two.
class LanguageNotifier extends StateNotifier<AppLanguage?> {
  /// Completes when the saved language has been read from SharedPreferences
  /// on construction. The router awaits this before deciding whether to
  /// redirect to the first-launch picker, so that returning users don't
  /// briefly flicker through the picker while SharedPreferences loads.
  late final Future<void> initialized;

  LanguageNotifier() : super(null) {
    initialized = _init();
  }

  /// Read the saved language code from SharedPreferences on construction.
  /// Sets state to the matching [AppLanguage], or leaves it null if
  /// no preference has been saved yet.
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kPreferredLanguageKey);
    state = AppLanguage.fromCode(code);
  }

  /// User picked a new language. Persist locally and update state so
  /// MaterialApp rebuilds with the new locale.
  ///
  /// Note: this method does NOT sync to Firestore. The language picker
  /// screen (Step 12) is responsible for calling
  /// [AuthNotifier.updateUser] with the new value when the user is
  /// signed in, so the choice persists across devices.
  Future<void> setLanguage(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPreferredLanguageKey, lang.code);
    state = lang;
  }

  /// Set state without persisting. Used by edge-case flows where the
  /// caller manages persistence separately (currently unused; reserved
  /// for first-launch picker if needed).
  void setLanguageInMemory(AppLanguage lang) {
    state = lang;
  }
}

/// Provider that exposes the current language choice as `AppLanguage?`.
final languageNotifierProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguage?>((ref) {
  return LanguageNotifier();
});

/// Convenience: the active [Locale] for MaterialApp.locale.
///
/// Falls back to English when the user has not yet picked. The
/// first-launch picker shows itself before the locale matters, so this
/// fallback only affects the brief moment before the picker renders
/// (and the picker shows "Choose your language" in three languages
/// stacked, so any base locale works for it).
final currentLocaleProvider = Provider<Locale>((ref) {
  final lang = ref.watch(languageNotifierProvider);
  return lang?.locale ?? const Locale('en');
});

/// Convenience: has the user picked a language yet?
///
/// Used by the router (Step 13) to redirect to the first-launch
/// picker until this returns true.
final hasPickedLanguageProvider = Provider<bool>((ref) {
  return ref.watch(languageNotifierProvider) != null;
});
