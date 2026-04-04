import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smile_id/smile_id.dart';
import 'package:smile_id/products/selfie/smile_id_smart_selfie_enrollment.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/smile_id_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/auth_provider.dart';
import '../../widgets/kyc_verification_card.dart';
import '../../../../core/services/push_notification_service.dart'; 

const String _smileIdCallbackUrl = 'https://us-central1-qr-wallet-1993.cloudfunctions.net/smileIdWebhook';

class SsnitVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;

  const SsnitVerificationScreen({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<SsnitVerificationScreen> createState() => _SsnitVerificationScreenState();
}

class _SsnitVerificationScreenState extends ConsumerState<SsnitVerificationScreen> {
  final _smileIdService = SmileIDService.instance;
  final _idNumberController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _isCaptured = false;
  String? _verificationResult;
  SmileIdFiles? _smileIdFiles;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _generateUserId();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  void _generateUserId() {
    final user = ref.read(currentUserProvider);
    _userId = _smileIdService.generateUserId();
  }

  Future<void> _startVerification() async {
    final idNumber = _idNumberController.text.trim();

    // Validate SSNIT
    final validation = _smileIdService.validateIdNumber(idNumber, 'SSNIT', widget.countryCode);
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid SSNIT number');
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _SmileIdSmartSelfieScreen(
          userId: _userId!,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isCaptured = true;
        _verificationResult = result;
        _smileIdFiles = SmileIDService.instance.parseResultFiles(result);
      });
      _showSuccess('Selfie captured successfully');
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _dateOfBirth = date);
    }
  }

  Future<void> _handleContinue() async {
    if (!_isCaptured) {
      _showError('Please complete verification with Smile ID');
      return;
    }

    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Phone verification step (optional for SmileID countries)
      final phoneVerified = await context.push<bool>(
        AppRoutes.kycPhoneVerification,
        extra: {
          'countryCode': widget.countryCode,
          'documentVerified': true, // SmileID already verified, skip is allowed
        },
      );

      if (!mounted) return;

      final userService = UserService();
      final result = await userService.uploadKycDocuments(
        idType: 'SSNIT',
        idNumber: _idNumberController.text.trim().toUpperCase(),
        dateOfBirth: _dateOfBirth!,
        selfie: _smileIdFiles?.selfie,
        idFront: null,
        idBack: null,
        smileIdVerified: false,
        smileIdResult: _verificationResult,
      );

      if (!mounted) return;

      if (result.success) {
        if (result.user != null) {
          ref.read(authNotifierProvider.notifier).updateUser(result.user!);
        }

        // Set kycStatus to pending_review (webhook will finalize to verified)
        final completeKyc = FirebaseFunctions.instance.httpsCallable('completeKycVerification');
        await completeKyc.call();

        // Save SmileID userId and jobId for polling
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && _userId != null) {
            String? smileJobId;
            if (_verificationResult != null && _verificationResult != 'already_enrolled_pending') {
              try {
                final jsonResult = json.decode(_verificationResult!);
                smileJobId = jsonResult['smile_job_id']?.toString() ?? jsonResult['smileJobId']?.toString();
                // Extract job ID from file paths if not found
                if (smileJobId == null) {
                  final selfieFile = jsonResult['selfieFile']?.toString() ?? '';
                  final jobMatch = RegExp(r'job-[a-f0-9\-]+').firstMatch(selfieFile);
                  if (jobMatch != null) smileJobId = jobMatch.group(0);
                }
              } catch (_) {}
            }
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'smileUserId': _userId,
              if (smileJobId != null) 'smileJobId': smileJobId,
            });
          }
        } catch (e) {
          debugPrint('Error saving SmileID job info: $e');
        }

        // Submit Biometric KYC via server-side API
        try {
          final submitKyc = FirebaseFunctions.instance.httpsCallable('submitBiometricKycVerification');
          await submitKyc.call({
            'smileUserId': _userId,
            'country': widget.countryCode,
            'idType': 'SSNIT',
            'idNumber': _idNumberController.text.trim().toUpperCase(),
          });
        } catch (e) {
          debugPrint('Error submitting biometric KYC: $e');
        }

        await PushNotificationService().saveTokenToFirestore();
        if (!mounted) return;
        context.go(AppRoutes.verificationPending);
      } else {
        _showError(result.error ?? 'Failed to complete verification');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.verifySsnit, style: AppTextStyles.headlineSmall()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SSNIT Verification',
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      AppStrings.ssnitDescription,
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycIdNumberInput(
                      controller: _idNumberController,
                      label: 'SSNIT Number',
                      hint: 'Enter your SSNIT number (e.g., A123456789012)',
                      helperText: 'Your SSNIT number: 1 letter followed by 12 digits',
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycVerificationCard(
                      title: _isCaptured ? 'Document Captured' : 'Verify Your Identity',
                      description: _isCaptured
                          ? 'Your SSNIT has been captured. Verification will begin when you continue.'
                          : 'We will verify your SSNIT and take a selfie for confirmation',
                      isVerified: _isCaptured,
                      onStartVerification: _startVerification,
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycDateOfBirthPicker(
                      selectedDate: _dateOfBirth,
                      onTap: _selectDateOfBirth,
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(top: BorderSide(color: AppColors.inputBorderDark, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleContinue,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.backgroundDark),
                  )
                : Text(
                    AppStrings.continueText,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Internal SmartSelfie Enrollment Screen (selfie only, no document)
class _SmileIdSmartSelfieScreen extends StatelessWidget {
  final String userId;

  const _SmileIdSmartSelfieScreen({
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmileIDSmartSelfieEnrollment(
        userId: userId,
        allowNewEnroll: true,
        allowAgentMode: false,
        showAttribution: true,
        showInstructions: true,
        extraPartnerParams: {
          "callback_url": _smileIdCallbackUrl,
        },
        onSuccess: (result) {
          Navigator.pop(context, result);
        },
        onError: (error) {
          if (ErrorHandler.isAlreadyEnrolledError(error)) {
            if (context.mounted) {
              Navigator.pop(context, 'already_enrolled_pending');
            }
            return;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification failed: $error'),
                backgroundColor: AppColors.error,
              ),
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
