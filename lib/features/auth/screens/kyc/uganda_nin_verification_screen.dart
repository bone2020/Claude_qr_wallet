import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
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
import '../../widgets/kyc_verification_card.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../core/services/push_notification_service.dart';

/// Dedicated verification screen for Uganda National ID (NIN).
/// Uganda requires 3 fields: NIN (id_number), Card Number (secondary_id_number), and DOB.
/// This is separate from NationalIdVerificationScreen to avoid complicating the shared screen.
class UgandaNinVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;

  const UgandaNinVerificationScreen({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<UgandaNinVerificationScreen> createState() => _UgandaNinVerificationScreenState();
}

class _UgandaNinVerificationScreenState extends ConsumerState<UgandaNinVerificationScreen> {
  final _smileIdService = SmileIDService.instance;
  final _ninController = TextEditingController();
  final _cardNumberController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _isVerified = false;
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
    _ninController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  void _generateUserId() {
    final user = ref.read(currentUserProvider);
    _userId = _smileIdService.generateUserId();
  }

  Future<void> _startVerification() async {
    final nin = _ninController.text.trim();
    final cardNumber = _cardNumberController.text.trim();

    // Validate NIN
    final validation = _smileIdService.validateIdNumber(nin, 'UGANDA_NIN', 'UG');
    if (!validation.isValid) {
      _showError(validation.error ?? 'Invalid NIN');
      return;
    }

    // Validate Card Number
    if (cardNumber.isEmpty) {
      _showError('Please enter your card number');
      return;
    }

    // Use Biometric KYC with NIN
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _UgandaSmileIdBiometricScreen(
          userId: _userId!,
          idNumber: nin,
          secondaryIdNumber: cardNumber,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isVerified = true;
        _verificationResult = result;
        _smileIdFiles = SmileIDService.instance.parseResultFiles(result);
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
      // Phone verification step
      final phoneVerified = await context.push<bool>(
        AppRoutes.kycPhoneVerification,
        extra: {
          'countryCode': widget.countryCode,
          'firstName': null,
          'lastName': null,
          'idNumber': _ninController.text.trim(),
          'documentVerified': true,
        },
      );

      if (!mounted) return;

      final userService = UserService();
      final result = await userService.uploadKycDocuments(
        idType: 'NATIONAL_ID_NO_PHOTO',
        idNumber: _ninController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        selfie: _smileIdFiles?.selfie,
        idFront: _smileIdFiles?.documentFront,
        idBack: _smileIdFiles?.documentBack,
        smileIdVerified: true,
        smileIdResult: _verificationResult,
      );

      if (!mounted) return;

      if (result.success) {
        if (result.user != null) {
          ref.read(authNotifierProvider.notifier).updateUser(result.user!);
        }

        // Create wallet (server sets kycStatus: 'verified')
        final createWallet = FirebaseFunctions.instance.httpsCallable('createWalletForUser');
        await createWallet.call();

        // Refresh wallet and currency after verification
        await ref.read(walletNotifierProvider.notifier).refreshWallet();
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
        await PushNotificationService().saveTokenToFirestore();
        if (!mounted) return;
        context.go(AppRoutes.main);
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
        title: Text('Uganda National ID', style: AppTextStyles.headlineSmall()),
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
                      'National ID Verification',
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      'Verify your identity using your Uganda National Identification Number (NIN) and card number.',
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // NIN Input
                    KycIdNumberInput(
                      controller: _ninController,
                      label: 'National Identification Number (NIN)',
                      hint: 'Enter your 14-character NIN',
                      helperText: 'Your NIN is 14 alphanumeric characters',
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceLG),

                    // Card Number Input
                    KycIdNumberInput(
                      controller: _cardNumberController,
                      label: 'Card Number',
                      hint: 'Enter the card number on your National ID',
                      helperText: 'The number printed on your physical ID card',
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // Smile ID Verification
                    KycVerificationCard(
                      title: _isVerified ? 'Verified with Smile ID' : 'Verify Your National ID',
                      description: _isVerified
                          ? 'Your National ID has been verified successfully'
                          : 'We will verify your NIN against the national database and take a selfie for confirmation',
                      isVerified: _isVerified,
                      onStartVerification: _startVerification,
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // Date of Birth
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

/// Internal Smile ID Biometric KYC Screen for Uganda
/// Sends NIN as id_number and card number as secondary_id_number
class _UgandaSmileIdBiometricScreen extends StatelessWidget {
  final String userId;
  final String idNumber;
  final String secondaryIdNumber;

  const _UgandaSmileIdBiometricScreen({
    required this.userId,
    required this.idNumber,
    required this.secondaryIdNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmileIDBiometricKYC(
        country: 'UG',
        idType: 'NATIONAL_ID_NO_PHOTO',
        idNumber: idNumber,
        userId: userId,
        allowAgentMode: false,
        showAttribution: true,
        showInstructions: true,
        onSuccess: (result) {
          Navigator.pop(context, result);
        },
        onError: (error) async {
          if (ErrorHandler.isAlreadyEnrolledError(error)) {
            await UserService().markKycVerifiedForAlreadyEnrolledUser(
              idType: 'NATIONAL_ID_NO_PHOTO',
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
