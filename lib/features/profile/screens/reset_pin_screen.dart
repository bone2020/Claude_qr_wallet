import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/secure_storage_service.dart';

class ResetPinScreen extends ConsumerStatefulWidget {
  const ResetPinScreen({super.key});

  @override
  ConsumerState<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends ConsumerState<ResetPinScreen> {
  // Steps: 0 = choose method, 1 = verify identity, 2 = new PIN, 3 = confirm PIN
  int _currentStep = 0;
  String _selectedMethod = ''; // 'email' or 'phone'
  bool _isLoading = false;
  String? _errorMessage;

  final _passwordController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePassword = true;

  // Phone OTP state
  String? _verificationId;
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _selectMethod(String method) {
    final user = FirebaseAuth.instance.currentUser;

    if (method == 'phone' && (user?.phoneNumber == null || user!.phoneNumber!.isEmpty)) {
      setState(() {
        _errorMessage = 'No phone number linked to this account.';
      });
      return;
    }

    setState(() {
      _selectedMethod = method;
      _errorMessage = null;
      _currentStep = 1;
    });

    if (method == 'phone') {
      _sendPhoneOtp();
    }
  }

  Future<void> _verifyEmailPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not logged in or no email found.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 2;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect password. Please try again.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = 'Authentication failed. Please try again.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication failed. Please try again.';
      });
    }
  }

  Future<void> _sendPhoneOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.phoneNumber == null) {
        throw Exception('No phone number linked.');
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: user.phoneNumber!,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          try {
            await user.reauthenticateWithCredential(credential);
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentStep = 2;
            });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMessage = 'Auto-verification failed. Please enter the code manually.';
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? 'Failed to send OTP. Please try again.';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Verification expired. Please resend OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      await user.reauthenticateWithCredential(credential);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 2;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'invalid-verification-code':
          message = 'Invalid code. Please try again.';
          break;
        case 'session-expired':
          message = 'Code expired. Please resend OTP.';
          break;
        default:
          message = 'Verification failed. Please try again.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification failed. Please try again.';
      });
    }
  }

  void _setNewPin(String pin) {
    setState(() {
      _errorMessage = null;
      _currentStep = 3;
    });
  }

  Future<void> _confirmNewPin(String pin) async {
    if (pin != _newPinController.text) {
      setState(() {
        _errorMessage = 'PINs do not match.';
        _confirmPinController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newPinHash = _hashPin(pin);

      // Force token refresh to get fresh auth_time
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      // Call resetPin Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('resetPin');
      await callable.call({
        'newPinHash': newPinHash,
        'method': _selectedMethod,
      });

      // Save to secure storage for offline app lock
      await SecureStorageService.savePinHash(newPinHash);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.tick_circle, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text('PIN Reset!', style: AppTextStyles.headlineSmall()),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                'Your transaction PIN has been reset successfully.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: Text('Done', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
              ),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Failed to reset PIN. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to reset PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep = _currentStep == 1 ? 0 : _currentStep - 1;
                _errorMessage = null;
              });
            } else {
              context.pop();
            }
          },
        ),
        title: Text('Reset PIN', style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildChooseMethod();
      case 1:
        return _buildVerifyIdentity();
      case 2:
        return _buildNewPin();
      case 3:
        return _buildConfirmPin();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChooseMethod() {
    final user = FirebaseAuth.instance.currentUser;
    final hasPhone = user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spaceMD),
        Text('Verify Your Identity', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          'Choose how to verify your identity before resetting your PIN.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXXL),

        // Email/Password option
        _buildMethodCard(
          icon: Iconsax.sms,
          title: 'Email & Password',
          subtitle: user?.email ?? 'Email',
          onTap: () => _selectMethod('email'),
        ),

        const SizedBox(height: AppDimensions.spaceMD),

        // Phone OTP option
        _buildMethodCard(
          icon: Iconsax.call,
          title: 'Phone OTP',
          subtitle: hasPhone ? user!.phoneNumber! : 'No phone number linked',
          onTap: hasPhone ? () => _selectMethod('phone') : null,
          enabled: hasPhone,
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodySmall(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],

        const Spacer(),

        // Security note
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.shield_tick, color: AppColors.primary, size: 24),
              const SizedBox(width: AppDimensions.spaceMD),
              Expanded(
                child: Text(
                  'For your security, you must verify your identity before resetting your PIN.',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMD),
      ],
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(
            color: enabled ? AppColors.inputBorderDark : AppColors.inputBorderDark.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (enabled ? AppColors.primary : AppColors.textSecondaryDark).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: enabled ? AppColors.primary : AppColors.textSecondaryDark, size: 24),
            ),
            const SizedBox(width: AppDimensions.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge(
                      color: enabled ? AppColors.textPrimaryDark : AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              color: enabled ? AppColors.textSecondaryDark : AppColors.inputBorderDark,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyIdentity() {
    if (_selectedMethod == 'email') {
      return _buildEmailVerification();
    } else {
      return _buildPhoneVerification();
    }
  }

  Widget _buildEmailVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spaceMD),
        Text('Enter Your Password', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          'Enter your account password to verify your identity.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXXL),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: AppTextStyles.bodyLarge(),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            filled: true,
            fillColor: AppColors.surfaceDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.inputBorderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.inputBorderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            prefixIcon: const Icon(Iconsax.lock, color: AppColors.textSecondaryDark),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                color: AppColors.textSecondaryDark,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodySmall(color: AppColors.error),
          ),
        ],

        const SizedBox(height: AppDimensions.spaceXXL),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyEmailPassword,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: AppColors.backgroundDark, strokeWidth: 2),
                  )
                : Text('Verify', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneVerification() {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 48,
      textStyle: AppTextStyles.headlineSmall(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spaceMD),
        Text('Enter OTP Code', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          'Enter the 6-digit code sent to your phone number.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXXL),

        if (_isLoading && _verificationId == null)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else ...[
          Center(
            child: Pinput(
              controller: _otpController,
              length: 6,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              keyboardType: TextInputType.number,
              onCompleted: (_) => _verifyPhoneOtp(),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppDimensions.spaceMD),
            Center(
              child: Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.spaceXXL),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyPhoneOtp,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: AppColors.backgroundDark, strokeWidth: 2),
                    )
                  : Text('Verify', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
            ),
          ),

          const SizedBox(height: AppDimensions.spaceMD),

          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _sendPhoneOtp,
              child: Text(
                'Resend Code',
                style: AppTextStyles.bodyMedium(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNewPin() {
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

    return Column(
      children: [
        const SizedBox(height: AppDimensions.spaceMD),
        Text('Enter New PIN', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          'Create a new 6-digit transaction PIN.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spaceXXL),

        Pinput(
          controller: _newPinController,
          length: 6,
          obscureText: true,
          obscuringCharacter: '\u25CF',
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          onCompleted: _setNewPin,
          keyboardType: TextInputType.number,
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodySmall(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmPin() {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTextStyles.headlineLarge(),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: _errorMessage != null ? AppColors.error : AppColors.inputBorderDark),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );

    return Column(
      children: [
        const SizedBox(height: AppDimensions.spaceMD),
        Text('Confirm New PIN', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          'Re-enter your new PIN to confirm.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spaceXXL),

        if (_isLoading)
          const CircularProgressIndicator(color: AppColors.primary)
        else
          Pinput(
            controller: _confirmPinController,
            length: 6,
            obscureText: true,
            obscuringCharacter: '\u25CF',
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            onCompleted: _confirmNewPin,
            keyboardType: TextInputType.number,
          ),

        if (_errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodySmall(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
