import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/constants.dart';
import '../../../../providers/auth_provider.dart';

/// Universal phone verification screen using Firebase SMS OTP.
///
/// Replaces the previous SmileID-based phone verification which only worked
/// in 6 countries and was prone to UNAUTHENTICATED errors. This screen works
/// for ALL countries because it uses Firebase Phone Auth directly.
///
/// Flow: KYC ID screen pushes here -> SMS OTP sent to user's registered phone
/// -> user types 6-digit code -> on success sets users/{uid}.phoneVerified=true
/// and pops with `true`.
///
/// Constructor signature kept identical to the old SmileID screen so the 7
/// KYC screens that already call this route work without modification. The
/// firstName/lastName/idNumber/documentVerified params are accepted but
/// unused — Firebase SMS OTP doesn't need them.
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;
  final String? firstName;
  final String? lastName;
  final String? idNumber;
  final bool documentVerified;

  const PhoneVerificationScreen({
    super.key,
    required this.countryCode,
    this.firstName,
    this.lastName,
    this.idNumber,
    this.documentVerified = false,
  });

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  String _phoneNumber = '';
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  bool _isVerified = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePhone();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePhone() async {
    // Source 1: current Riverpod user
    final user = ref.read(currentUserProvider);
    if (user != null && user.phoneNumber.isNotEmpty) {
      _phoneNumber = user.phoneNumber;
      _sendOtp();
      return;
    }

    // Source 2: Firestore (fallback)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (doc.exists && mounted) {
          final phone = doc.data()?['phoneNumber'] as String? ?? '';
          if (phone.isNotEmpty) {
            setState(() => _phoneNumber = phone);
            _sendOtp();
            return;
          }
        }
      } catch (e) {
        debugPrint('Error fetching phone from Firestore: $e');
      }
    }

    if (mounted) {
      setState(() {
        _errorMessage = 'No phone number found on your account. Please go back and re-enter it.';
      });
    }
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        if (mounted) setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber.isEmpty) return;

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.sendPhoneOtp(
      phoneNumber: _phoneNumber,
      onError: (error) {
        if (mounted) setState(() => _errorMessage = error);
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

  Future<void> _verifyOtp() async {
    final otp = _pinController.text;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
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
        // Persist phoneVerified=true to Firestore for the router/KYC checks
        try {
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .update({'phoneVerified': true});
          }
        } catch (e) {
          debugPrint('Failed to write phoneVerified flag: $e');
        }

        if (!mounted) return;
        setState(() => _isVerified = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Brief pause so the user sees the success state, then return
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.pop(true);
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Invalid code. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _maskedPhone() {
    if (_phoneNumber.length < 4) return _phoneNumber;
    final visible = _phoneNumber.substring(_phoneNumber.length - 3);
    return '${'*' * (_phoneNumber.length - 3)}$visible';
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _isVerified ? Icons.verified : Icons.phone_android,
                size: 80,
                color: _isVerified ? AppColors.success : AppColors.primary,
              ).animate().fadeIn().scale(),

              const SizedBox(height: 24),

              Text(
                _isVerified ? 'Phone Verified!' : 'Verify Your Phone',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 12),

              Text(
                _isVerified
                    ? 'Your phone number has been verified.'
                    : _otpSent
                        ? 'Enter the 6-digit code sent to ${_maskedPhone()}'
                        : 'We will send a verification code to ${_maskedPhone()}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              if (_otpSent && !_isVerified) ...[
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    defaultPinTheme: defaultPinTheme,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onCompleted: (_) => _verifyOtp(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify Code'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend code in ${_resendSeconds}s',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : TextButton(
                          onPressed: _isSendingOtp ? null : _sendOtp,
                          child: const Text('Resend Code'),
                        ),
                ),
              ],

              if (!_otpSent && !_isVerified) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSendingOtp ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSendingOtp
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Verification Code'),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
