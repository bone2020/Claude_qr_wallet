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
import '../../../core/utils/error_handler.dart';
import '../../../providers/auth_provider.dart'; 

class ResetPinScreen extends ConsumerStatefulWidget {
  const ResetPinScreen({super.key});

  @override
  ConsumerState<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends ConsumerState<ResetPinScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  int _currentStep = 0;
  String _selectedMethod = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  String? _verificationId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _verifyWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);

      setState(() { _isLoading = false; _currentStep = 2; });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _errorMessage = 'Incorrect password. Please try again.';
        } else if (e.code == 'too-many-requests') {
          _errorMessage = 'Too many attempts. Please try again later.';
        } else {
          _errorMessage = 'Verification failed. Please try again.';
        }
      });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = ErrorHandler.getUserFriendlyMessage(e); });
    }
  }

  Future<void> _sendPhoneOtp() async {
  final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check Firebase Auth phone first, fall back to Firestore phone from sign-up
    final authPhone = user.phoneNumber;
    final firestorePhone = ref.read(currentUserProvider)?.phoneNumber;
    final phoneNumber = (authPhone != null && authPhone.isNotEmpty) ? authPhone : firestorePhone;
    if (phoneNumber == null || phoneNumber.isEmpty) { 

      setState(() => _errorMessage = 'No phone number linked to your account. Please use email verification.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await user.reauthenticateWithCredential(credential);
            if (mounted) setState(() { _isLoading = false; _currentStep = 2; });
          } catch (e) {
            if (mounted) setState(() { _isLoading = false; _errorMessage = 'Auto-verification failed. Please enter the OTP manually.'; });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = e.code == 'too-many-requests'
                  ? 'Too many attempts. Please try again later.'
                  : 'Failed to send OTP. Please try again.';
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) setState(() { _isLoading = false; _verificationId = verificationId; });
        },
        codeAutoRetrievalTimeout: (String verificationId) { _verificationId = verificationId; },
      );
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = ErrorHandler.getUserFriendlyMessage(e); });
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) { setState(() => _errorMessage = 'Please enter the 6-digit code'); return; }
    if (_verificationId == null) { setState(() => _errorMessage = 'Verification expired. Please request a new code.'); return; }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      await user.reauthenticateWithCredential(credential);

      setState(() { _isLoading = false; _currentStep = 2; });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == 'invalid-verification-code'
            ? 'Incorrect code. Please try again.'
            : 'Verification failed. Please try again.';
      });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = ErrorHandler.getUserFriendlyMessage(e); });
    }
  }

  void _setNewPin(String pin) {
    setState(() { _errorMessage = null; _currentStep = 3; });
  }

  Future<void> _confirmNewPin(String pin) async {
    if (pin != _newPinController.text) {
      setState(() { _errorMessage = 'PINs do not match'; _confirmPinController.clear(); });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final newPinHash = _hashPin(pin);
      final callable = FirebaseFunctions.instance.httpsCallable('resetPin');
      await callable.call({ 'newPinHash': newPinHash, 'method': _selectedMethod });

      await SecureStorageService.savePinHash(newPinHash);

      if (!mounted) return;
      setState(() => _isLoading = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLG)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Iconsax.tick_circle, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text('PIN Reset!', style: AppTextStyles.headlineSmall()),
              const SizedBox(height: AppDimensions.spaceXS),
              Text('Your transaction PIN has been reset successfully.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); context.pop(); },
                child: Text('Done', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMessage = 'Failed to reset PIN. Please try again.'; });
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
              setState(() { _currentStep = _currentStep == 1 ? 0 : _currentStep - 1; _errorMessage = null; });
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
      case 0: return _buildMethodSelection();
      case 1: return _selectedMethod == 'email' ? _buildEmailVerification() : _buildPhoneVerification();
      case 2: return _buildPinStep(title: 'Enter New PIN', subtitle: 'Create a new 6-digit transaction PIN', controller: _newPinController, onCompleted: _setNewPin);
      case 3: return _buildPinStep(title: 'Confirm New PIN', subtitle: 'Re-enter your new PIN to confirm', controller: _confirmPinController, onCompleted: _confirmNewPin);
      default: return _buildMethodSelection();
    }
  }

  Widget _buildMethodSelection() {
    final user = FirebaseAuth.instance.currentUser;
    final firestorePhone = ref.read(currentUserProvider)?.phoneNumber;
    final hasPhone = (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) ||
        (firestorePhone != null && firestorePhone.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spaceXL),
        Text('Verify Your Identity', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text('To reset your PIN, please verify your identity using one of the options below.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark)),
        const SizedBox(height: AppDimensions.spaceXXL),
        _buildMethodCard(icon: Iconsax.sms, title: 'Email & Password', subtitle: 'Verify using your login credentials',
          onTap: () { setState(() { _selectedMethod = 'email'; _currentStep = 1; _errorMessage = null; }); }),
        const SizedBox(height: AppDimensions.spaceMD),
        _buildMethodCard(icon: Iconsax.call, title: 'Phone Number',
          subtitle: hasPhone ? 'Verify via OTP sent to your phone' : 'No phone number linked to your account',
          enabled: hasPhone,
          onTap: hasPhone ? () { setState(() { _selectedMethod = 'phone'; _currentStep = 1; _errorMessage = null; }); _sendPhoneOtp(); } : null),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
          child: Row(children: [
            const Icon(Iconsax.shield_tick, color: AppColors.primary, size: 24),
            const SizedBox(width: AppDimensions.spaceMD),
            Expanded(child: Text('This verification ensures only you can reset your PIN.',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark))),
          ]),
        ),
        const SizedBox(height: AppDimensions.spaceMD),
      ],
    );
  }

  Widget _buildMethodCard({required IconData icon, required String title, required String subtitle, bool enabled = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceLG),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: enabled ? AppColors.inputBorderDark : AppColors.inputBorderDark.withOpacity(0.5)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary.withOpacity(0.1) : AppColors.textTertiaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Icon(icon, color: enabled ? AppColors.primary : AppColors.textTertiaryDark, size: 24),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.labelLarge(color: enabled ? AppColors.textPrimaryDark : AppColors.textTertiaryDark)),
            const SizedBox(height: 2),
            Text(subtitle, style: AppTextStyles.bodySmall(color: enabled ? AppColors.textSecondaryDark : AppColors.textTertiaryDark)),
          ])),
          if (enabled) const Icon(Iconsax.arrow_right_3, color: AppColors.textSecondaryDark, size: 20),
        ]),
      ),
    );
  }

  Widget _buildEmailVerification() {
    final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppDimensions.spaceXL),
        Text('Enter Your Password', style: AppTextStyles.headlineSmall()),
        const SizedBox(height: AppDimensions.spaceXS),
        Text('Verify your identity by entering your login credentials.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark)),
        const SizedBox(height: AppDimensions.spaceXXL),
        Text('Email', style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark)),
        const SizedBox(height: AppDimensions.spaceSM),
        TextFormField(
          controller: _emailController..text = user?.email ?? '',
          readOnly: true,
          style: AppTextStyles.bodyLarge(color: AppColors.textSecondaryDark),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.surfaceDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD), borderSide: const BorderSide(color: AppColors.inputBorderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD), borderSide: const BorderSide(color: AppColors.inputBorderDark)),
            prefixIcon: const Icon(Iconsax.sms, color: AppColors.textSecondaryDark),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLG),
        Text('Password', style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark)),
        const SizedBox(height: AppDimensions.spaceSM),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: AppTextStyles.bodyLarge(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
            filled: true, fillColor: AppColors.surfaceDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD), borderSide: const BorderSide(color: AppColors.inputBorderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD), borderSide: const BorderSide(color: AppColors.inputBorderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD), borderSide: const BorderSide(color: AppColors.primary)),
            prefixIcon: const Icon(Iconsax.lock, color: AppColors.textSecondaryDark),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Iconsax.eye_slash : Iconsax.eye, color: AppColors.textSecondaryDark),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          Text(_errorMessage!, style: AppTextStyles.bodySmall(color: AppColors.error)),
        ],
        const SizedBox(height: AppDimensions.spaceXXL),
        SizedBox(
          width: double.infinity, height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyWithEmail,
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.backgroundDark))
                : Text('Verify', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
          ),
        ),
      ]),
    );
  }

  Widget _buildPhoneVerification() {
final user = FirebaseAuth.instance.currentUser;
    final firestorePhone = ref.read(currentUserProvider)?.phoneNumber ?? '';
    final phone = (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) ? user.phoneNumber! : firestorePhone;
    final maskedPhone = phone.length > 4 ? '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}' : phone;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppDimensions.spaceXL),
      Text('Enter OTP', style: AppTextStyles.headlineSmall()),
      const SizedBox(height: AppDimensions.spaceXS),
      Text('Enter the 6-digit code sent to $maskedPhone',
        style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark)),
      const SizedBox(height: AppDimensions.spaceXXL),
      if (_isLoading && _verificationId == null)
        const Center(child: CircularProgressIndicator(color: AppColors.primary))
      else ...[
        Center(
          child: Pinput(
            controller: _otpController, length: 6,
            defaultPinTheme: PinTheme(width: 50, height: 50, textStyle: AppTextStyles.headlineSmall(),
              decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(color: AppColors.inputBorderDark))),
            focusedPinTheme: PinTheme(width: 50, height: 50, textStyle: AppTextStyles.headlineSmall(),
              decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(color: AppColors.primary, width: 2))),
            keyboardType: TextInputType.number,
            onCompleted: (_) => _verifyPhoneOtp(),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          Center(child: Text(_errorMessage!, style: AppTextStyles.bodySmall(color: AppColors.error), textAlign: TextAlign.center)),
        ],
        const SizedBox(height: AppDimensions.spaceXL),
        Center(child: TextButton(
          onPressed: _isLoading ? null : _sendPhoneOtp,
          child: Text('Resend Code', style: AppTextStyles.labelMedium(color: AppColors.primary)),
        )),
        const SizedBox(height: AppDimensions.spaceXL),
        SizedBox(
          width: double.infinity, height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyPhoneOtp,
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.backgroundDark))
                : Text('Verify', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
          ),
        ),
      ],
    ]);
  }

  Widget _buildPinStep({required String title, required String subtitle, required TextEditingController controller, required Function(String) onCompleted}) {
    final defaultPinTheme = PinTheme(width: 56, height: 56, textStyle: AppTextStyles.headlineLarge(),
      decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: _errorMessage != null ? AppColors.error : AppColors.inputBorderDark)));
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.primary, width: 2)));

    return Column(children: [
      const SizedBox(height: AppDimensions.spaceXXL),
      Text(title, style: AppTextStyles.headlineSmall()),
      const SizedBox(height: AppDimensions.spaceXS),
      Text(subtitle, style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark), textAlign: TextAlign.center),
      const SizedBox(height: AppDimensions.spaceXXL),
      if (_isLoading)
        const CircularProgressIndicator(color: AppColors.primary)
      else
        Pinput(controller: controller, length: 6, obscureText: true, obscuringCharacter: '\u25CF',
          defaultPinTheme: defaultPinTheme, focusedPinTheme: focusedPinTheme,
          onCompleted: onCompleted, keyboardType: TextInputType.number),
      if (_errorMessage != null) ...[
        const SizedBox(height: AppDimensions.spaceMD),
        Text(_errorMessage!, style: AppTextStyles.bodySmall(color: AppColors.error), textAlign: TextAlign.center),
      ],
    ]);
  }
}
