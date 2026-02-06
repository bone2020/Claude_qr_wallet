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
import '../../../../providers/currency_provider.dart';
import '../../../../providers/pending_signup_provider.dart';
import '../../widgets/kyc_verification_card.dart';

class VotersCardVerificationScreen extends ConsumerStatefulWidget {
  final String countryCode;

  const VotersCardVerificationScreen({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<VotersCardVerificationScreen> createState() => _VotersCardVerificationScreenState();
}

class _VotersCardVerificationScreenState extends ConsumerState<VotersCardVerificationScreen> {
  final _smileIdService = SmileIDService.instance;

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

  void _generateUserId() {
    final user = ref.read(currentUserProvider);
    _userId = user?.id ?? _smileIdService.generateUserId();
  }

  Future<void> _startVerification() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _SmileIdDocumentScreen(
          userId: _userId!,
          countryCode: widget.countryCode,
          documentType: 'VOTER_ID',
          captureBothSides: true,
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
          idType: 'VOTERS_ID',
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
        title: Text(AppStrings.verifyVotersCard, style: AppTextStyles.headlineSmall()),
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
                      "Voter's Card Verification",
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      AppStrings.votersCardDescription,
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),

                    KycVerificationCard(
                      title: _isVerified ? 'Verified with Smile ID' : "Verify Your Voter's Card",
                      description: _isVerified
                          ? "Your voter's card has been verified successfully"
                          : 'We will capture both sides of your card and take a selfie',
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
              idType: documentType,
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
