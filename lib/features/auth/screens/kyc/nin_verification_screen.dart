import 'dart:convert';

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
import '../../../../generated/l10n/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/smile_id_service.dart';
import '../../../../core/services/smile_id_localization_resolver.dart';
import '../../../../core/services/user_localization_resolver.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/auth_provider.dart';
import '../../widgets/kyc_verification_card.dart';
import '../../../../core/services/push_notification_service.dart';

class NinVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;

  const NinVerificationScreen({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<NinVerificationScreen> createState() => _NinVerificationScreenState();
}

class _NinVerificationScreenState extends ConsumerState<NinVerificationScreen> {
  final _smileIdService = SmileIDService.instance;
  final _idNumberController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _isCaptured = false;
  String? _verificationResult;
  String? _userId;
  String? _loadingMessage;
  SmileIdFiles? _smileIdFiles;

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
    final loc = AppLocalizations.of(context);
    final idNumber = _idNumberController.text.trim();

    // Validate NIN
    final validation = _smileIdService.validateIdNumber(idNumber, 'NIN', widget.countryCode);
    if (!validation.isValid) {
      final key = validation.errorKey;
      _showError(key != null
          ? resolveIdValidationErrorMessage(loc, key)
          : loc.invalidIdNumberFallback);
      return;
    }

    if (_dateOfBirth == null) {
      _showError(loc.kycErrorPleaseSelectDateOfBirthBeforeSelfie);
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _SmileIdSmartSelfieEnrollmentScreen(
          userId: _userId!,
        ),
      ),
    );

    if (result != null) {
      debugPrint('=== SMILEID RESULT JSON START ===');
      debugPrint(result);
      debugPrint('=== SMILEID RESULT JSON END ===');
      setState(() {
        _isCaptured = true;
        _verificationResult = result;
        // Parse the SDK result into File handles for selfie + liveness frames.
        // These are required by the canonical biometric KYC pattern
        // (see _handleContinue): the upload uses _smileIdFiles.selfie and
        // _smileIdFiles.livenessImages, the resulting storage paths get
        // threaded into submitBiometricKycVerification.
        _smileIdFiles = _smileIdService.parseResultFiles(result);
      });
      _showSuccess('Verification submitted successfully');
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
    final loc = AppLocalizations.of(context);
    if (!_isCaptured) {
      _showError(loc.kycErrorPleaseCompleteSmileId);
      return;
    }

    if (_dateOfBirth == null) {
      _showError(loc.kycErrorPleaseSelectDateOfBirth);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Finalizing verification...';
    });

    try {
      // Phone verification step (optional for SmileID countries).
      // Phone verification: only run for SmileID countries. Non-SmileID
      // countries already verified their phone at /phone-otp before reaching
      // this KYC screen. Running it again here causes Firebase to throttle
      // the second OTP request for the same number.
      const smileIdCountries = ['GH', 'NG', 'KE', 'ZA', 'CI', 'UG', 'ZM', 'ZW'];
      if (smileIdCountries.contains(widget.countryCode.toUpperCase())) {
        await context.push<bool>(
          AppRoutes.kycPhoneVerification,
          extra: {
            'countryCode': widget.countryCode,
            'documentVerified': true,
          },
        );

        if (!mounted) return;
      }

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _showError(loc.kycErrorNotSignedIn);
        return;
      }
      if (_userId == null) {
        _showError(loc.kycErrorVerificationSessionExpired);
        return;
      }

      // Extract the Smile ID job ID from the on-device SDK result.
      // Used as the per-attempt media scope for the upload (so retries
      // don't overwrite previous attempts) and as the smileJobId field on
      // the user doc (used by polling/audit). If the result can't be parsed,
      // the upload falls back to the legacy flat-path layout and we skip the
      // user-doc smileJobId field -- both are non-fatal.
      String? smileJobId;
      if (_verificationResult != null && _verificationResult != 'already_enrolled_pending') {
        try {
          final jsonResult = json.decode(_verificationResult!);
          smileJobId = jsonResult['smile_job_id']?.toString() ?? jsonResult['smileJobId']?.toString();
          if (smileJobId == null) {
            final selfieFile = jsonResult['selfieFile']?.toString() ?? '';
            final jobMatch = RegExp(r'job-[a-f0-9\-]+').firstMatch(selfieFile);
            if (jobMatch != null) smileJobId = jobMatch.group(0);
          }
        } catch (_) {}
      }

      // Audit 4.3 fix: align Nigeria NIN to the canonical biometric KYC
      // pattern. Previously this screen wrote the kyc/documents subdoc
      // directly and never called completeKycVerification or
      // submitBiometricKycVerification (the misleading "Phase 4b" comment
      // claimed the CF would finalize the status, but no CF was ever
      // invoked from this screen). Now it goes through the same flow as
      // BVN: UserService.uploadKycDocuments -> submitBiometricKycVerification
      // -> completeKycVerification -> navigate, with proper failure handling
      // at each step.
      //
      // Note: unlike PR A's BVN canonical, this screen also passes idNumber
      // to uploadKycDocuments so the NIN value is persisted in the
      // kyc/documents Firestore doc as part of the upload. BVN should be
      // brought up to this in a future cleanup pass.
      final userService = UserService();
      final result = await userService.uploadKycDocuments(
        idType: 'NIN_V2',
        idNumber: _idNumberController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        selfie: _smileIdFiles?.selfie,
        livenessImages: _smileIdFiles?.livenessImages,
        mediaScope: smileJobId,
        idFront: null,
        idBack: null,
        smileIdVerified: false,
        smileIdResult: _verificationResult,
      );

      if (!mounted) return;

      if (!result.success) {
        _showError(resolveUserResultError(loc, result));
        return;
      }

      // Verify the upload produced the storage paths required by the
      // server-side BIOMETRIC_KYC submission. If the SDK didn't capture
      // liveness frames or the upload didn't populate them, fail closed
      // -- the verification cannot succeed downstream without these.
      final paths = result.kycMediaPaths;
      if (paths == null ||
          paths.selfieStoragePath == null ||
          paths.livenessStoragePaths.isEmpty) {
        _showError('Verification media incomplete. Please try again.');
        return;
      }

      if (result.user != null) {
        ref.read(authNotifierProvider.notifier).updateUser(result.user!);
      }

      // Save smileUserId + smileJobId to the user doc (preserved from
      // the prior NIN flow; same pattern as BVN canonical).
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .update({
          'smileUserId': _userId,
          if (smileJobId != null) 'smileJobId': smileJobId,
        });
      } catch (e) {
        debugPrint('Error saving SmileID job info: $e');
      }

      // Submit Biometric KYC via server-side API.
      //
      // Per audit 4.1 Phase 2 design decision 2 (reordered): this call runs
      // BEFORE completeKycVerification so user.kycStatus only becomes
      // 'pending_review' if Smile ID actually accepted the submission.
      //
      // Per audit 4.1 Phase 2 design decision 3 (fail-closed): if submission
      // fails, surface the error and stay on this screen so the user can
      // retry. Do NOT navigate to the verification-pending screen because
      // there is no in-flight Smile ID job to wait on.
      try {
        final submitKyc = FirebaseFunctions.instance.httpsCallable('submitBiometricKycVerification');
        await submitKyc.call({
          'smileUserId': _userId,
          'country': widget.countryCode,
          'idType': 'NIN_V2',
          'idNumber': _idNumberController.text.trim(),
          'selfieStoragePath': paths.selfieStoragePath,
          'livenessStoragePaths': paths.livenessStoragePaths,
          'dob': _dateOfBirth!.toIso8601String(),
        });
      } catch (e) {
        if (!mounted) return;
        _showError('Verification submission failed. Please try again.');
        debugPrint('submitBiometricKycVerification failed: $e');
        return;
      }

      if (!mounted) return;

      // Submission succeeded -> safe to mark KYC as pending_review.
      // If completeKycVerification itself fails (rare), proceed anyway: the
      // Smile ID webhook will finalize user.kycStatus when the BIOMETRIC_KYC
      // result arrives, so the user is not left stranded.
      try {
        final completeKyc = FirebaseFunctions.instance.httpsCallable('completeKycVerification');
        await completeKyc.call();
      } catch (e) {
        debugPrint('completeKycVerification failed after submit succeeded: $e');
      }

      try {
        await ref.read(authNotifierProvider.notifier).refreshUser();
      } catch (_) {}

      try {
        await PushNotificationService().saveTokenToFirestore();
      } catch (_) {}

      if (!mounted) return;
      context.go(AppRoutes.verificationPending);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      debugPrint('Firebase error during KYC finalization: ${e.code} ${e.message}');
      _showError(e.message ?? 'Save failed. Please check your connection and try again.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected error during KYC finalization: $e');
      _showError(loc.kycErrorSomethingWentWrong);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
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
        title: Text(AppLocalizations.of(context).verifyNin, style: AppTextStyles.headlineSmall()),
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
                      AppLocalizations.of(context).ninVerificationTitle,
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      AppLocalizations.of(context).ninDescription,
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycIdNumberInput(
                      controller: _idNumberController,
                      label: 'NIN Number',
                      hint: 'Enter your 11-digit NIN',
                      helperText: AppLocalizations.of(context).ninHelperText,
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycDateOfBirthPicker(
                      selectedDate: _dateOfBirth,
                      onTap: _selectDateOfBirth,
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycVerificationCard(
                      title: _isCaptured ? 'Verification Submitted' : 'Verify Your Identity',
                      description: _isCaptured
                          ? 'Your selfie has been captured and submitted. Tap continue to finish.'
                          : 'Enter your NIN and date of birth above, then tap to take a selfie and submit verification.',
                      isVerified: _isCaptured,
                      onStartVerification: _startVerification,
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
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.backgroundDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _loadingMessage ?? 'Please wait...',
                          style: AppTextStyles.labelMedium(
                            color: AppColors.backgroundDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Text(
                    AppLocalizations.of(context).continueText,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Internal SmartSelfie Enrollment screen — captures a selfie and enrolls
/// the user with SmileID. The NIN number lookup is performed separately
/// by a Cloud Function after enrollment completes.
class _SmileIdSmartSelfieEnrollmentScreen extends StatelessWidget {
  final String userId;

  const _SmileIdSmartSelfieEnrollmentScreen({
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
                content: Text(AppLocalizations.of(context).verificationFailedWithError(error)),
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
