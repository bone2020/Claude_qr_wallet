import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  SmileIdFiles? _smileIdFiles;
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

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _SmileIdSmartSelfieScreen(
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

    // Validate that we actually have the captured files on disk
    final selfieFile = _smileIdFiles?.selfie;
    final livenessFiles = _smileIdFiles?.livenessImages ?? const <File>[];

    if (selfieFile == null || !selfieFile.existsSync()) {
      _showError('Selfie image is missing. Please retake your selfie.');
      return;
    }
    if (livenessFiles.isEmpty) {
      _showError('Verification images are missing. Please retake your selfie.');
      return;
    }
    for (final f in livenessFiles) {
      if (!f.existsSync()) {
        _showError('Verification images are missing. Please retake your selfie.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Starting verification...';
    });

    try {
      // Phone verification step (optional for SmileID countries)
      // Run BEFORE uploading photos so user can back out without wasting bandwidth
      await context.push<bool>(
        AppRoutes.kycPhoneVerification,
        extra: {
          'countryCode': widget.countryCode,
          'documentVerified': true, // SmileID already verified, skip is allowed
        },
      );

      if (!mounted) return;

      // Confirm we still have a Firebase user
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _showError('You are not signed in. Please sign in and try again.');
        return;
      }
      if (_userId == null) {
        _showError('Verification session expired. Please retake your selfie.');
        return;
      }

      // Generate a client-side job ID used only for storage path naming
      // (the server function generates its own SmileID job ID separately)
      final clientJobId =
          'job_${DateTime.now().millisecondsSinceEpoch}_${firebaseUser.uid.substring(0, 6)}';

      final storage = FirebaseStorage.instance;
      final basePath = 'kyc_documents/${firebaseUser.uid}';

      // Upload selfie
      setState(() => _loadingMessage = 'Uploading selfie...');
      final selfieStoragePath = '$basePath/${clientJobId}_selfie.jpg';
      await storage.ref(selfieStoragePath).putFile(
            selfieFile,
            SettableMetadata(contentType: 'image/jpeg'),
          );

      if (!mounted) return;

      // Upload each liveness image, updating the progress message as we go
      final livenessStoragePaths = <String>[];
      for (var i = 0; i < livenessFiles.length; i++) {
        if (!mounted) return;
        setState(() {
          _loadingMessage =
              'Uploading verification images... (${i + 1} of ${livenessFiles.length})';
        });
        final livenessPath = '$basePath/${clientJobId}_liveness_$i.jpg';
        await storage.ref(livenessPath).putFile(
              livenessFiles[i],
              SettableMetadata(contentType: 'image/jpeg'),
            );
        livenessStoragePaths.add(livenessPath);
      }

      if (!mounted) return;

      // Write the kyc/documents record so the verification_pending_screen
      // can find smileUserId/smileJobId and so other parts of the app that
      // read this doc continue to work.
      setState(() => _loadingMessage = 'Saving verification details...');
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
        'clientJobId': clientJobId,
        'selfieStoragePath': selfieStoragePath,
        'livenessStoragePaths': livenessStoragePaths,
        if (_verificationResult != null) 'smileIdResult': _verificationResult,
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Update legacy KYC fields on the user doc.
      // Do NOT set kycStatus here — the server function does that.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .update({
        'kycCompleted': true,
        'dateOfBirth': _dateOfBirth!.toIso8601String(),
      });

      if (!mounted) return;

      // Call the server function — this is the moment SmileID actually
      // gets the verification request. Errors here MUST be shown to the user.
      setState(() => _loadingMessage = 'Submitting verification...');
      final submitKyc = FirebaseFunctions.instance
          .httpsCallable('submitBiometricKycVerification');
      await submitKyc.call(<String, dynamic>{
        'smileUserId': _userId,
        'country': widget.countryCode,
        'idType': 'NIN',
        'idNumber': _idNumberController.text.trim(),
        'selfieStoragePath': selfieStoragePath,
        'livenessStoragePaths': livenessStoragePaths,
      });

      if (!mounted) return;

      // Refresh local user state and navigate to the waiting screen
      try {
        await ref.read(authNotifierProvider.notifier).refreshUser();
      } catch (_) {}

      try {
        await PushNotificationService().saveTokenToFirestore();
      } catch (_) {}

      if (!mounted) return;
      context.go(AppRoutes.verificationPending);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      debugPrint('submitBiometricKycVerification failed: ${e.code} ${e.message}');
      _showError(e.message ?? 'Failed to submit verification. Please try again.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      debugPrint('Firebase error during KYC submission: ${e.code} ${e.message}');
      _showError(e.message ?? 'Upload failed. Please check your connection and try again.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected error during KYC submission: $e');
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

                    KycVerificationCard(
                      title: _isCaptured ? 'Document Captured' : 'Verify Your Identity',
                      description: _isCaptured
                          ? 'Your NIN has been captured. Verification will begin when you continue.'
                          : 'We will verify your NIN and take a selfie for confirmation',
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
