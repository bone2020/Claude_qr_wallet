import 'package:flutter/material.dart';

/// QR Wallet Color Palette
/// A sleek, fintech-focused color scheme with yellow/gold as primary
class AppColors {
  AppColors._();

  // ============ PRIMARY COLORS ============
  /// Main brand color - Yellow/Gold
  static const Color primary = Color(0xFFFFD700);
  static const Color primaryLight = Color(0xFFFFE44D);
  static const Color primaryDark = Color(0xFFCCAA00);

  // ============ DARK THEME COLORS ============
  /// Deep black background
  static const Color backgroundDark = Color(0xFF0A0A0A);
  
  /// Surface color for cards, sheets
  static const Color surfaceDark = Color(0xFF1A1A1A);
  
  /// Elevated surface (dialogs, modals)
  static const Color surfaceElevatedDark = Color(0xFF242424);
  
  /// Input field background
  static const Color inputBackgroundDark = Color(0xFF1E1E1E);
  
  /// Input field border
  static const Color inputBorderDark = Color(0xFF3A3A3A);
  
  /// Primary text on dark
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  
  /// Secondary text on dark
  static const Color textSecondaryDark = Color(0xFF888888);
  
  /// Tertiary/hint text on dark
  static const Color textTertiaryDark = Color(0xFF555555);

  // ============ LIGHT THEME COLORS ============
  /// Light background
  static const Color backgroundLight = Color(0xFFF8F8F8);
  
  /// Surface color for cards in light mode
  static const Color surfaceLight = Color(0xFFFFFFFF);
  
  /// Elevated surface light
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  
  /// Input field background light
  static const Color inputBackgroundLight = Color(0xFFF0F0F0);
  
  /// Input field border light
  static const Color inputBorderLight = Color(0xFFDDDDDD);
  
  /// Primary text on light
  static const Color textPrimaryLight = Color(0xFF0A0A0A);
  
  /// Secondary text on light
  static const Color textSecondaryLight = Color(0xFF666666);
  
  /// Tertiary text on light
  static const Color textTertiaryLight = Color(0xFF999999);

  // ============ SEMANTIC COLORS ============
  /// Success green
  static const Color success = Color(0xFF00C853);
  static const Color successLight = Color(0xFF69F0AE);
  
  /// Error red
  static const Color error = Color(0xFFFF4444);
  static const Color errorLight = Color(0xFFFF8A80);
  
  /// Warning orange
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFCC80);
  
  /// Info blue
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF90CAF9);

  // ============ TRANSACTION COLORS ============
  /// Money received (credit)
  static const Color moneyIn = Color(0xFF00C853);
  
  /// Money sent (debit)
  static const Color moneyOut = Color(0xFFFF4444);
  
  /// Pending transaction
  static const Color pending = Color(0xFFFF9800);

  // ============ GRADIENTS ============
  /// Primary button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );

  /// Card gradient for dark mode
  static const LinearGradient cardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
  );

  /// Gold shimmer gradient
  static const LinearGradient goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFD700),
      Color(0xFFFFF8DC),
      Color(0xFFFFD700),
    ],
  );
}
