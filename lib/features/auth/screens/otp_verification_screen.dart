import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

/// Email verification screen with auto-detect and manual check
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String? phoneNumber;
  final bool isEmailVerification;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.phoneNumber,
    this.isEmailVerification = true,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  bool _isResending = false;
  bool _isCheckingVerification = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;
  Timer? _autoCheckTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        if (mounted) {
          setState(() => _resendSeconds--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Auto-check email verification every 3 seconds
  void _startAutoCheck() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkEmailVerified(showLoading: false, showError: false);
    });
  }

  Future<void> _checkEmailVerified({bool showLoading = true, bool showError = true}) async {
    if (_isCheckingVerification) return;

    if (showLoading) {
      setState(() {
        _isCheckingVerification = true;
        _errorMessage = null;
      });
    }

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final isVerified = await authNotifier.checkEmailVerified();

      if (!mounted) return;

      if (isVerified) {
        // Stop auto-check
        _autoCheckTimer?.cancel();

        // Update Firestore
        await authNotifier.markEmailVerified();

        if (!mounted) return;

        // Show success and navigate to KYC
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        context.go(AppRoutes.kyc);
      } else if (showError) {
        setState(() {
          _errorMessage = 'Email not verified yet. Please check your inbox and click the verification link.';
        });
      }
    } catch (e) {
      if (mounted && showError) {
        setState(() {
          _errorMessage = 'Error checking verification status. Please try again.';
        });
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _isCheckingVerification = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_resendSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final result = await authNotifier.sendEmailVerification();

      if (!mounted) return;

      if (result.success) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to send email';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  String get _maskedEmail {
    final email = widget.email;
    final atIndex = email.indexOf('@');
    if (atIndex > 2) {
      return '${email.substring(0, 2)}***${email.substring(atIndex)}';
    }
    return email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
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

              // Email Icon with pulse animation
              _buildEmailIcon()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    delay: 200.ms,
                    duration: 400.ms,
                  ),

              const SizedBox(height: AppDimensions.spaceXXL),

              // Instructions
              _buildInstructions()
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceLG),

              // Auto-checking indicator
              _buildAutoCheckIndicator()
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceLG),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMD),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: AppDimensions.spaceXS),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodySmall(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),

              const Spacer(),

              // Resend Email
              _buildResendEmail()
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceLG),

              // Check Now Button (secondary/fallback)
              _buildCheckNowButton()
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceXXL),
            ],
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
          'Verify Your Email',
          style: AppTextStyles.displaySmall(),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Text(
          'We\'ve sent a verification link to:',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          _maskedEmail,
          style: AppTextStyles.bodyLarge(color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildEmailIcon() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.mark_email_unread_rounded,
          size: 60,
          color: AppColors.primary,
        ),
      )
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(delay: 1000.ms, duration: 1800.ms, color: AppColors.primary.withOpacity(0.3)),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstructionItem(1, 'Open your email app'),
          const SizedBox(height: AppDimensions.spaceSM),
          _buildInstructionItem(2, 'Look for email from QR Wallet'),
          const SizedBox(height: AppDimensions.spaceSM),
          _buildInstructionItem(3, 'Click the verification link'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(int number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: AppTextStyles.labelSmall(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSM),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoCheckIndicator() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          Text(
            'Checking automatically...',
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildResendEmail() {
    return Center(
      child: Column(
        children: [
          Text(
            'Didn\'t receive the email?',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          GestureDetector(
            onTap: _resendSeconds > 0 ? null : _resendEmail,
            child: _isResending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _resendSeconds > 0
                        ? 'Resend in ${_resendSeconds}s'
                        : 'Resend Email',
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

  Widget _buildCheckNowButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: OutlinedButton(
        onPressed: _isCheckingVerification ? null : () => _checkEmailVerified(showLoading: true, showError: true),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
        ),
        child: _isCheckingVerification
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Text(
                'Check Now',
                style: AppTextStyles.labelLarge(color: AppColors.primary),
              ),
      ),
    );
  }
}
