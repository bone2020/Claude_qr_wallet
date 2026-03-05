import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/secure_storage_service.dart';

/// Lock screen shown on app open when PIN is set
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _pinController = TextEditingController();
  final _biometricService = BiometricService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final isAvailable = await _biometricService.canCheckBiometrics();
    final isEnabled = await SecureStorageService.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _biometricAvailable = isAvailable;
        _biometricEnabled = isEnabled;
      });

      // Auto-trigger biometric if available and enabled
      if (isAvailable && isEnabled) {
        _authenticateWithBiometric();
      }
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storedPinHash = await SecureStorageService.getPinHash();

      if (storedPinHash == null) {
        // No PIN stored locally, allow access
        if (mounted) _navigateToMain();
        return;
      }

      final enteredPinHash = _hashPin(pin);

      if (enteredPinHash == storedPinHash) {
        _failedAttempts = 0;
        if (mounted) _navigateToMain();
      } else {
        _failedAttempts++;
        setState(() {
          _isLoading = false;
          _errorMessage = _failedAttempts >= 3
              ? 'Too many failed attempts. Try biometric or wait.'
              : 'Incorrect PIN. ${3 - _failedAttempts} attempts remaining.';
          _pinController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error verifying PIN';
        _pinController.clear();
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final result = await _biometricService.authenticateForLogin();

    if (result.success && mounted) {
      _navigateToMain();
    }
  }

  void _navigateToMain() {
    context.go(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTextStyles.headlineLarge(),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.inputBorderDark),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.error),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Lock icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.lock,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),

              const SizedBox(height: AppDimensions.spaceXL),

              Text('Welcome Back', style: AppTextStyles.headlineMedium()),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                'Enter your PIN to unlock',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              ),

              const SizedBox(height: AppDimensions.spaceXXL),

              // PIN input
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  obscuringCharacter: '\u25CF',
                  defaultPinTheme: _errorMessage != null ? errorPinTheme : defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  onCompleted: _verifyPin,
                  keyboardType: TextInputType.number,
                ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.spaceMD),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: AppDimensions.spaceXXL),

              // Biometric button
              if (_biometricAvailable && _biometricEnabled)
                GestureDetector(
                  onTap: _authenticateWithBiometric,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.inputBorderDark),
                        ),
                        child: const Icon(
                          Iconsax.finger_scan,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceXS),
                      Text(
                        'Use Biometric',
                        style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
                ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
