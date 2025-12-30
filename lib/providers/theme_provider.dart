import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/local_storage_service.dart';
import 'auth_provider.dart';

/// Theme mode notifier
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorageService _localStorage;

  ThemeNotifier(this._localStorage) : super(ThemeMode.dark) {
    _init();
  }

  Future<void> _init() async {
    final isDarkMode = await _localStorage.getSetting<bool>(
      LocalStorageService.keyDarkMode,
      defaultValue: true,
    );
    state = isDarkMode == true ? ThemeMode.dark : ThemeMode.light;
  }

  /// Toggle theme
  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    await _localStorage.saveSetting(
      LocalStorageService.keyDarkMode,
      newMode == ThemeMode.dark,
    );
  }

  /// Set specific theme
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _localStorage.saveSetting(
      LocalStorageService.keyDarkMode,
      mode == ThemeMode.dark,
    );
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

/// Theme provider
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return ThemeNotifier(localStorage);
});

/// Is dark mode provider
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeNotifierProvider) == ThemeMode.dark;
});
