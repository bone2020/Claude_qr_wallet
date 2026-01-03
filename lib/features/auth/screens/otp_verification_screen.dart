import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

/// OTP verification screen for phone/email verification
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String email;
  final bool isPhoneVerification;
  final String? verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.email,
    this.isPhoneVerification = true,
    this.verificationId,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isSendingOtp = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;
  String? _verificationId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    // If no verification ID provided, trigger OTP send
    if (_verificationId == null && widget.isPhoneVerification) {
      _sendOtp();
    } else {
      _startResendTimer();
    }
  }

  Future<void> _sendOtp() async {
    if (_isSendingOtp) return;

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);

    await authService.sendOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isSendingOtp = false;
          });
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isSendingOtp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      onAutoVerify: (PhoneAuthCredential credential) async {
        // Auto-verification (Android only) - automatically verify
        if (mounted) {
          setState(() => _isLoading = true);
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await user.linkWithCredential(credential);
              if (mounted) {
                context.go(AppRoutes.kyc);
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _maskedContact {
    if (widget.isPhoneVerification) {
      final phone = widget.phoneNumber;
      if (phone.length > 4) {
        return '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}';
      }
      return phone;
    } else {
      final email = widget.email;
      final atIndex = email.indexOf('@');
      if (atIndex > 2) {
        return '${email.substring(0, 2)}***${email.substring(atIndex)}';
      }
      return email;
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification session expired. Please request a new code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.verifyOtp(
        verificationId: _verificationId!,
        otp: _otpController.text,
      );

      if (!mounted) return;

      if (result.success) {
        // Phone verified successfully, proceed to KYC
        context.go(AppRoutes.kyc);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Verification failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;

    // Trigger OTP send again
    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceLG),

              // Back Button
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: AppDimensions.spaceXL),

              // Header
              _buildHeader()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.2, end: 0, duration: 400.ms),

              const SizedBox(height: AppDimensions.space4XL),

              // OTP Input
              _buildOtpInput()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    delay: 200.ms,
                    duration: 400.ms,
                  ),

              const SizedBox(height: AppDimensions.spaceXXL),

              // Resend Code
              _buildResendCode()
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.space4XL),

              // Verify Button
              _buildVerifyButton()
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceXXL),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.enterOtp,
          style: AppTextStyles.displaySmall(),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Text(
          '${AppStrings.otpSentTo}\n$_maskedContact',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 56,
      textStyle: AppTextStyles.headlineLarge(),
      decoration: BoxDecoration(
        color: AppColors.inputBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.inputBorderDark),
      ),
    );

    return Center(
      child: Pinput(
        length: 6,
        controller: _otpController,
        focusNode: _focusNode,
        autofocus: true,
        defaultPinTheme: defaultPinTheme,
        focusedPinTheme: defaultPinTheme.copyWith(
          decoration: defaultPinTheme.decoration!.copyWith(
            border: Border.all(color: AppColors.primary, width: 2),
          ),
        ),
        submittedPinTheme: defaultPinTheme.copyWith(
          decoration: defaultPinTheme.decoration!.copyWith(
            border: Border.all(color: AppColors.primary),
          ),
        ),
        errorPinTheme: defaultPinTheme.copyWith(
          decoration: defaultPinTheme.decoration!.copyWith(
            border: Border.all(color: AppColors.error),
          ),
        ),
        onCompleted: (_) => _verifyOtp(),
        cursor: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 22,
              height: 2,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResendCode() {
    return Center(
      child: Column(
        children: [
          Text(
            AppStrings.didntReceiveCode,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          GestureDetector(
            onTap: _resendSeconds > 0 ? null : _resendCode,
            child: Text(
              _resendSeconds > 0
                  ? '${AppStrings.resendIn} ${_resendSeconds}s'
                  : AppStrings.resendCode,
              style: AppTextStyles.bodyMedium(
                color: _resendSeconds > 0
                    ? AppColors.textTertiaryDark
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOtp,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.backgroundDark,
                ),
              )
            : Text(
                AppStrings.verify,
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
      ),
    );
  }
}
