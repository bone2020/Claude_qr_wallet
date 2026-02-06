import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smile_id/smile_id.dart';
import 'package:smile_id/products/biometric/smile_id_biometric_kyc.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/smile_id_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../providers/pending_signup_provider.dart';
import '../../widgets/kyc_verification_card.dart';

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
  bool _isVerified = false;
  String? _verificationResult;
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
    _userId = user?.id ?? _smileIdService.generateUserId();
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
        builder: (context) => _SmileIdBiometricScreen(
          userId: _userId!,
          countryCode: widget.countryCode,
          idType: 'SSNIT',
          idNumber: idNumber.toUpperCase(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isVerified = true;
        _verificationResult = result;
      });
      _showSuccess(AppStrings.verificationSuccessful);
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
    if (!_isVerified) {
      _showError('Please complete verification with Smile ID');
      return;
    }

    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if this is a new signup (pending data exists)
      final pendingData = ref.read(pendingSignupProvider);

      if (pendingData != null) {
        // New user - create account now that KYC passed
        final authNotifier = ref.read(authNotifierProvider.notifier);
        final result = await authNotifier.createVerifiedUser(
          email: pendingData.email,
          password: pendingData.password,
          fullName: pendingData.fullName,
          phoneNumber: pendingData.phoneNumber,
          kycStatus: 'verified',
          countryCode: pendingData.countryCode,
          currencyCode: pendingData.currencyCode,
        );

        // Clear pending signup data
        ref.read(pendingSignupProvider.notifier).clear();

        if (!mounted) return;

        if (result.success) {
          _showSuccess('Account created successfully!');
          await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
          context.go(AppRoutes.main);
        } else {
          _showError(result.error ?? 'Failed to create account');
        }
      } else {
        // Existing user - update KYC status via Cloud Function
        final userService = UserService();
        final result = await userService.uploadKycDocuments(
          idType: 'SSNIT',
          idNumber: _idNumberController.text.trim().toUpperCase(),
          dateOfBirth: _dateOfBirth!,
          smileIdVerified: true,
          smileIdResult: _verificationResult,
        );

        if (!mounted) return;

        if (result.success) {
          if (result.user != null) {
            ref.read(authNotifierProvider.notifier).updateUser(result.user!);
          }
          await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
          context.go(AppRoutes.main);
        } else {
          _showError(result.error ?? 'Failed to complete verification');
        }
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
                      title: _isVerified ? 'Verified with Smile ID' : 'Verify Your Identity',
                      description: _isVerified
                          ? 'Your SSNIT has been verified successfully'
                          : 'We will verify your SSNIT and take a selfie for confirmation',
                      isVerified: _isVerified,
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

/// Internal Smile ID Biometric KYC Screen
class _SmileIdBiometricScreen extends StatelessWidget {
  final String userId;
  final String countryCode;
  final String idType;
  final String idNumber;

  const _SmileIdBiometricScreen({
    required this.userId,
    required this.countryCode,
    required this.idType,
    required this.idNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmileIDBiometricKYC(
        country: countryCode,
        idType: idType,
        idNumber: idNumber,
        userId: userId,
        allowAgentMode: false,
        showAttribution: true,
        showInstructions: true,
        onSuccess: (result) {
          Navigator.pop(context, result);
        },
        onError: (error) async {
          // Check if this is an "already enrolled" error - treat as success
          if (ErrorHandler.isAlreadyEnrolledError(error)) {
            // User was previously verified - update their KYC status immediately
            await UserService().markKycVerifiedForAlreadyEnrolledUser(
              idType: idType,
            );
            if (context.mounted) {
              Navigator.pop(context, 'already_enrolled');
            }
            return;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification failed: $error'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
