import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smile_id/smile_id.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/smile_id_service.dart';
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

    // Validate NIN
    final validation = _smileIdService.validateIdNumber(idNumber, 'NIN', widget.countryCode);
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid NIN');
      return;
    }

    if (_dateOfBirth == null) {
      _showError('Please select your date of birth before taking the selfie');
      return;
    }

    final user = ref.read(currentUserProvider);
    final firstName = user?.firstName;
    final lastName = user?.lastName;
    final dobIso = _dateOfBirth!.toIso8601String().split('T').first; // YYYY-MM-DD

    // Capture the NIN form data so the Cloud Function can later submit
    // it to SmileID Enhanced KYC together with the selfie job ID.
    final ninFormData = {
      'country': widget.countryCode,
      'idType': 'NIN_V2',
      'idNumber': idNumber,
      'firstName': firstName,
      'lastName': lastName,
      'dob': dobIso,
    };
    debugPrint('NIN form data captured: $ninFormData');

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
    if (!_isCaptured) {
      _showError('Please complete verification with Smile ID');
      return;
    }

    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Finalizing verification...';
    });

    try {
      // Phone verification step (optional for SmileID countries)
      await context.push<bool>(
        AppRoutes.kycPhoneVerification,
        extra: {
          'countryCode': widget.countryCode,
          'documentVerified': true,
        },
      );

      if (!mounted) return;

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _showError('You are not signed in. Please sign in and try again.');
        return;
      }
      if (_userId == null) {
        _showError('Verification session expired. Please retake your selfie.');
        return;
      }

      // Save the kyc/documents record so verification_pending_screen can
      // poll for smileUserId and listen for kycStatus updates from the webhook.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .collection('kyc')
          .doc('documents')
          .set({
        'idType': 'NIN',
        'idNumber': _idNumberController.text.trim(),
        'dateOfBirth': _dateOfBirth!.toIso8601String(),
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending_review',
        'smileIdVerified': false,
        'smileUserId': _userId,
        if (_verificationResult != null) 'smileIdResult': _verificationResult,
      }, SetOptions(merge: true));

      if (!mounted) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .update({
        'kycCompleted': true,
        'dateOfBirth': _dateOfBirth!.toIso8601String(),
      });

      if (!mounted) return;

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
      _showError('Something went wrong. Please try again.');
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
        title: Text(AppStrings.verifyNin, style: AppTextStyles.headlineSmall()),
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
                      'NIN Verification',
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      AppStrings.ninDescription,
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    KycIdNumberInput(
                      controller: _idNumberController,
                      label: 'NIN Number',
                      hint: 'Enter your 11-digit NIN',
                      helperText: 'Your National Identification Number as shown on your NIN slip',
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
                    AppStrings.continueText,
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
