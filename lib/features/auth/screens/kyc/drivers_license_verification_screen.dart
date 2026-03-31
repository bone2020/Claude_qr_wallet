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
import 'package:smile_id/products/document/smile_id_document_verification.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/smile_id_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/auth_provider.dart';
import '../../widgets/kyc_verification_card.dart';
import '../../../../core/services/push_notification_service.dart';

const String _smileIdCallbackUrl = 'https://us-central1-qr-wallet-1993.cloudfunctions.net/smileIdWebhook';

class DriversLicenseVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;

  const DriversLicenseVerificationScreen({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<DriversLicenseVerificationScreen> createState() => _DriversLicenseVerificationScreenState();
}

class _DriversLicenseVerificationScreenState extends ConsumerState<DriversLicenseVerificationScreen> {
  final _smileIdService = SmileIDService.instance;

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

  void _generateUserId() {
    final user = ref.read(currentUserProvider);
    _userId = _smileIdService.generateUserId();
  }

  Future<void> _startVerification() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _SmileIdDocumentScreen(
          userId: _userId!,
          countryCode: widget.countryCode,
          documentType: 'DRIVERS_LICENSE',
          captureBothSides: true,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isCaptured = true;
        _verificationResult = result;
        _smileIdFiles = SmileIDService.instance.parseResultFiles(result);
      });
      _showSuccess('Document captured successfully');
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
        idType: 'DRIVERS_LICENSE',
        dateOfBirth: _dateOfBirth!,
        selfie: _smileIdFiles?.selfie,
        idFront: _smileIdFiles?.documentFront,
        idBack: _smileIdFiles?.documentBack,
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
        title: Text(AppStrings.verifyDriversLicense, style: AppTextStyles.headlineSmall()),
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
                      "Driver's License Verification",
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      AppStrings.driversLicenseDescription,
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),

                    KycVerificationCard(
                      title: _isCaptured ? 'Document Captured' : "Verify Your Driver's License",
                      description: _isCaptured
                          ? "Your driver's license has been captured. Verification will begin when you continue."
                          : 'We will capture both sides of your license and take a selfie',
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

/// Internal Smile ID Document Verification Screen
class _SmileIdDocumentScreen extends StatelessWidget {
  final String userId;
  final String countryCode;
  final String documentType;
  final bool captureBothSides;

  const _SmileIdDocumentScreen({
    required this.userId,
    required this.countryCode,
    required this.documentType,
    required this.captureBothSides,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmileIDDocumentVerification(
        countryCode: countryCode,
        documentType: documentType,
        userId: userId,
        captureBothSides: captureBothSides,
        extraPartnerParams: {"callback_url": _smileIdCallbackUrl},
        allowAgentMode: false,
        showAttribution: true,
        showInstructions: true,
        onSuccess: (result) {
          Navigator.pop(context, result);
        },
        onError: (error) async {
          // "Already enrolled" means SmileID has seen this user before
          // Still require webhook verification — don't bypass
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
