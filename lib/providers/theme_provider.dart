import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/local_storage_service.dart';
import 'auth_provider.dart';

/// App theme mode options
enum AppThemeMode { light, dark, system }

/// Theme mode notifier
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorageService _localStorage;
  AppThemeMode _appThemeMode = AppThemeMode.dark;

  ThemeNotifier(this._localStorage) : super(ThemeMode.dark) {
    _init();
  }

  Future<void> _init() async {
    final themeIndex = await _localStorage.getSetting<int>(
      'app_theme_mode',
      defaultValue: 1, // Default to dark (index 1)
    );
    _appThemeMode = AppThemeMode.values[themeIndex ?? 1];
    _updateThemeMode();
  }

  void _updateThemeMode() {
    switch (_appThemeMode) {
      case AppThemeMode.light:
        state = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        state = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        state = ThemeMode.system;
        break;
    }
  }

  /// Get current app theme mode
  AppThemeMode get appThemeMode => _appThemeMode;

  /// Toggle theme between light and dark
  Future<void> toggleTheme() async {
    final newMode = _appThemeMode == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    await setTheme(newMode);
  }

  /// Set specific theme mode
  Future<void> setTheme(AppThemeMode mode) async {
    _appThemeMode = mode;
    _updateThemeMode();
    await _localStorage.saveSetting('app_theme_mode', mode.index);
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

/// Theme provider
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return ThemeNotifier(localStorage);
});

/// App theme mode provider (for UI to show current selection)
final appThemeModeProvider = Provider<AppThemeMode>((ref) {
  final themeMode = ref.watch(themeNotifierProvider);
  switch (themeMode) {
    case ThemeMode.light:
      return AppThemeMode.light;
    case ThemeMode.dark:
      return AppThemeMode.dark;
    case ThemeMode.system:
      return AppThemeMode.system;
  }
});

/// Is dark mode provider
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeNotifierProvider) == ThemeMode.dark;
});
