import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../../../generated/l10n/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final result = await authNotifier.sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      if (!result.success) {
        throw Exception(result.error ?? 'Failed to send reset email');
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String message = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context).forgotPasswordTitle, style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: _emailSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Iconsax.tick_circle,
            color: AppColors.success,
            size: 64,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLG),
        Text(
          AppLocalizations.of(context).emailSentTitle,
          style: AppTextStyles.headlineMedium(),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Text(
          AppLocalizations.of(context).emailResetLinkSent(_emailController.text.trim()),
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          AppLocalizations.of(context).checkEmailForInstructions,
          style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spaceXL),
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: Text(
              AppLocalizations.of(context).backToLogin,
              style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMD),
        TextButton(
          onPressed: () {
            setState(() => _emailSent = false);
          },
          child: Text(
            AppLocalizations.of(context).didntReceiveEmailTryAgain,
            style: AppTextStyles.bodyMedium(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spaceLG),
          Text(
            AppLocalizations.of(context).resetYourPasswordTitle,
            style: AppTextStyles.displaySmall(),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            AppLocalizations.of(context).enterEmailForResetLink,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceXL),
          CustomTextField(
            controller: _emailController,
            hintText: AppLocalizations.of(context).enterEmailHint,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightLG,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.backgroundDark,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context).sendResetLink,
                      style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMD),
        ],
      ),
    );
  }
}
