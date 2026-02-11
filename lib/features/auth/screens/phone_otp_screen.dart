import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

/// Phone OTP verification screen
class PhoneOtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const PhoneOtpScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;
  String? _errorMessage;
  String _phoneNumber = "";

  @override
  void initState() {
    super.initState();
    _initializePhone();
  }

  Future<void> _initializePhone() async {
    if (widget.phoneNumber.isNotEmpty) {
      _phoneNumber = widget.phoneNumber;
      _sendOtp();
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get();
          if (doc.exists && mounted) {
            setState(() {
              _phoneNumber = doc.data()?["phoneNumber"] ?? "";
            });
            debugPrint("Phone from Firestore: $_phoneNumber");
            if (_phoneNumber.isNotEmpty) {
              _sendOtp();
            } else {
              setState(() {
                _errorMessage = "Phone number not found. Please go back and try again.";
              });
            }
          }
        } catch (e) {
          debugPrint("Error fetching phone: $e");
          setState(() {
            _errorMessage = "Error fetching phone number: $e";
          });
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _pinController.dispose();
    _pinFocusNode.dispose();
    _resendTimer?.cancel();
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

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.sendPhoneOtp(
      phoneNumber: _phoneNumber,
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isSendingOtp = false;
        _otpSent = success;
      });

      if (success) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your phone'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  String get _otpCode {
    return _pinController.text;
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCode;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final result = await authNotifier.verifyPhoneOtp(otp);

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.main);
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Invalid OTP. Please try again.';
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
        setState(() => _isLoading = false);
      }
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_otpCode.length == 6) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.phone_android,
                size: 80,
                color: AppColors.primary,
              ).animate().fadeIn().scale(),

              const SizedBox(height: 24),

              Text(
                'Verify Your Phone',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 12),

              Text(
                'We sent a 6-digit code to',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 4),

              Text(
                _phoneNumber,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),

              if (_isSendingOtp)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_otpSent) ...[
                // OTP Input Fields using Pinput
                Pinput(
                  length: 6,
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  defaultPinTheme: PinTheme(
                    width: 50,
                    height: 56,
                    textStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 50,
                    height: 56,
                    textStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    debugPrint("Pinput value: $value");
                  },
                  onCompleted: (value) {
                    debugPrint("Pinput completed: $value");
                    _verifyOtp();
                  },
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Verify button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 16),

                // Resend OTP
                TextButton(
                  onPressed: _resendSeconds > 0 ? null : _sendOtp,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend code in ${_resendSeconds}s'
                        : 'Resend code',
                    style: TextStyle(
                      color: _resendSeconds > 0
                          ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                          : AppColors.primary,
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ] else if (_errorMessage != null) ...[
                // Error sending OTP
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _sendOtp,
                  child: const Text('Try Again'),
                ),
              ],

              const SizedBox(height: 32),

              // Skip button (optional - for testing)
              TextButton(
                onPressed: () => context.go(AppRoutes.kyc),
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
