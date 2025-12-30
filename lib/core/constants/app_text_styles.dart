import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// QR Wallet Typography
/// Using Outfit font family for a modern, clean look
class AppTextStyles {
  AppTextStyles._();

  /// Base text style with Outfit font
  static TextStyle get _baseStyle => GoogleFonts.outfit();

  // ============ HEADINGS ============
  
  /// Display Large - 40px Bold
  static TextStyle displayLarge({Color? color}) => _baseStyle.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimaryDark,
        letterSpacing: -0.5,
      );

  /// Display Medium - 32px Bold
  static TextStyle displayMedium({Color? color}) => _baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimaryDark,
        letterSpacing: -0.5,
      );

  /// Display Small - 28px SemiBold
  static TextStyle displaySmall({Color? color}) => _baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Headline Large - 24px Bold
  static TextStyle headlineLarge({Color? color}) => _baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Headline Medium - 20px SemiBold
  static TextStyle headlineMedium({Color? color}) => _baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Headline Small - 18px SemiBold
  static TextStyle headlineSmall({Color? color}) => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimaryDark,
      );

  // ============ BODY TEXT ============

  /// Body Large - 16px Regular
  static TextStyle bodyLarge({Color? color}) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textPrimaryDark,
        height: 1.5,
      );

  /// Body Medium - 14px Regular
  static TextStyle bodyMedium({Color? color}) => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textPrimaryDark,
        height: 1.5,
      );

  /// Body Small - 12px Regular
  static TextStyle bodySmall({Color? color}) => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondaryDark,
        height: 1.4,
      );

  // ============ LABELS & BUTTONS ============

  /// Label Large - 16px Medium (Buttons)
  static TextStyle labelLarge({Color? color}) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimaryDark,
        letterSpacing: 0.5,
      );

  /// Label Medium - 14px Medium
  static TextStyle labelMedium({Color? color}) => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Label Small - 12px Medium
  static TextStyle labelSmall({Color? color}) => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondaryDark,
      );

  // ============ SPECIAL STYLES ============

  /// Balance Display - Large currency display
  static TextStyle balanceDisplay({Color? color}) => _baseStyle.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimaryDark,
        letterSpacing: -1,
      );

  /// Balance Currency Symbol
  static TextStyle balanceCurrency({Color? color}) => _baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textSecondaryDark,
      );

  /// Transaction Amount
  static TextStyle transactionAmount({Color? color, bool isCredit = false}) =>
      _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? (isCredit ? AppColors.moneyIn : AppColors.moneyOut),
      );

  /// Input Label
  static TextStyle inputLabel({Color? color}) => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondaryDark,
      );

  /// Input Text
  static TextStyle inputText({Color? color}) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Input Hint
  static TextStyle inputHint({Color? color}) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textTertiaryDark,
      );

  /// Link Text
  static TextStyle link({Color? color}) => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.primary,
      );

  /// Caption
  static TextStyle caption({Color? color}) => _baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textTertiaryDark,
      );
}
