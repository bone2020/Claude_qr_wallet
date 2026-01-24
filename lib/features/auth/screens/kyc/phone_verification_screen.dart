import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/smile_id_service.dart';
import '../../../../providers/auth_provider.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;
  final String? firstName;
  final String? lastName;
  final String? idNumber;

  const PhoneVerificationScreen({
    super.key,
    required this.countryCode,
    this.firstName,
    this.lastName,
    this.idNumber,
  });

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> {
  final _smileIdService = SmileIDService.instance;
  
  String? _phoneNumber;
  bool _isLoading = false;
  bool _isVerified = false;
  bool _isSupported = true;
  String? _errorMessage;
  List<String>? _supportedOperators;

  @override
  void initState() {
    super.initState();
    _checkSupport();
    _loadUserPhone();
  }

  void _loadUserPhone() {
    final user = ref.read(authNotifierProvider).user;
    if (user?.phoneNumber != null) {
      setState(() {
        _phoneNumber = user!.phoneNumber;
      });
    }
  }

  Future<void> _checkSupport() async {
    final support = await _smileIdService.checkPhoneVerificationSupport(widget.countryCode);
    if (mounted) {
      setState(() {
        _isSupported = support.supported;
        _supportedOperators = support.operators;
        if (!support.supported) {
          _errorMessage = support.message ?? 'Phone verification not available for this country';
        }
      });
    }
  }

  Future<void> _verifyPhone() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      _showError('No phone number found on your account');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _smileIdService.verifyPhoneNumber(
        phoneNumber: _phoneNumber!,
        country: widget.countryCode,
        firstName: widget.firstName,
        lastName: widget.lastName,
        idNumber: widget.idNumber,
      );

      if (!mounted) return;

      if (result.success && result.verified) {
        setState(() {
          _isVerified = true;
        });
        _showSuccess('Phone number verified successfully!');
      } else {
        setState(() {
          _errorMessage = result.error ?? result.resultText ?? 'Verification failed. Phone may not be registered to the ID holder.';
        });
        _showError(_errorMessage!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleContinue() {
    context.pop(_isVerified);
  }

  void _handleSkip() {
    context.pop(false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
                _isVerified ? 'Phone Verified!' : 'Verify Your Phone Number',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms),
              
              const SizedBox(height: 12),
              
              Text(
                _isVerified
                    ? 'Your phone number has been verified and matches your ID'
                    : 'We will verify that your registered phone number belongs to the ID holder',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),

              if (!_isSupported) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning),
                      SizedBox(height: 8),
                      Text(
                        'Phone verification is not available for your country yet. You can skip this step.',
                        style: TextStyle(color: AppColors.warning),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isVerified 
                        ? AppColors.success.withValues(alpha: 0.1)
                        : isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isVerified 
                          ? AppColors.success 
                          : isDark ? AppColors.inputBorderDark : AppColors.inputBorderLight,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Registered Phone Number',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone,
                            color: _isVerified ? AppColors.success : AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _phoneNumber ?? 'No phone number on file',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _phoneNumber != null 
                                    ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                    : AppColors.error,
                              ),
                            ),
                          ),
                          if (_isVerified) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.check_circle, color: AppColors.success),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 16, color: AppColors.info),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'This number cannot be changed for security',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),

                if (_supportedOperators != null && _supportedOperators!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Supported operators: ${_supportedOperators!.join(", ")}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
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
                ],
              ],

              const SizedBox(height: 32),

              if (_isSupported && !_isVerified && _phoneNumber != null)
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPhone,
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
                      : const Text('Verify Phone Number'),
                ).animate().fadeIn(delay: 400.ms),

              if (_phoneNumber == null && _isSupported)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No phone number found on your account. Please update your profile first.',
                    style: TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 16),

              if (_isVerified)
                ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ).animate().fadeIn(delay: 400.ms),

              if (!_isVerified)
                TextButton(
                  onPressed: _handleSkip,
                  child: Text(
                    _isSupported ? 'Skip for now' : 'Continue without phone verification',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
