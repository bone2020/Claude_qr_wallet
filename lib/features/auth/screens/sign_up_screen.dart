import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_button.dart';

/// Sign up screen for new user registration
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    if (value.split(' ').length < 2) {
      return 'Please enter your full name';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return AppStrings.errorInvalidEmail;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    if (value.length < 10) {
      return AppStrings.errorInvalidPhone;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    if (value.length < 8) {
      return AppStrings.errorPasswordWeak;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    if (value != _passwordController.text) {
      return AppStrings.errorPasswordMismatch;
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Privacy Policy'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call the auth provider to sign up with Firebase
      final result = await ref.read(authNotifierProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        // Navigate to OTP verification for phone verification
        context.push(
          AppRoutes.otpVerification,
          extra: {
            'phoneNumber': _phoneController.text,
            'email': _emailController.text,
            'isPhoneVerification': true,
          },
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Sign up failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;

      if (result.success) {
        if (result.isNewUser) {
          // New user - navigate to KYC
          context.go(AppRoutes.kyc);
        } else {
          // Existing user - navigate to home
          context.go(AppRoutes.home);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Google sign up failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAppleSignUp() {
    // TODO: Implement Apple sign up (requires Apple Developer account setup)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spaceLG),

                // Header
                _buildHeader()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Form Fields
                _buildFormFields(),

                const SizedBox(height: AppDimensions.spaceLG),

                // Terms Checkbox
                _buildTermsCheckbox()
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Sign Up Button
                _buildSignUpButton()
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 600.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Social Login
                _buildSocialLogin()
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Login Link
                _buildLoginLink()
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceLG),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.signUp,
          style: AppTextStyles.displaySmall(),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          AppStrings.signUpSubtitle,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Full Name
        CustomTextField(
          label: AppStrings.fullName,
          hintText: AppStrings.fullNameHint,
          controller: _fullNameController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          validator: _validateFullName,
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceMD),

        // Email
        CustomTextField(
          hintText: AppStrings.emailHint,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceMD),

        // Phone Number
        PhoneTextField(
          controller: _phoneController,
          validator: _validatePhone,
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceMD),

        // Password
        PasswordTextField(
          controller: _passwordController,
          hintText: AppStrings.passwordHint,
          textInputAction: TextInputAction.next,
          validator: _validatePassword,
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceMD),

        // Confirm Password
        PasswordTextField(
          controller: _confirmPasswordController,
          hintText: AppStrings.confirmPasswordHint,
          textInputAction: TextInputAction.done,
          validator: _validateConfirmPassword,
        ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (value) {
              setState(() => _agreedToTerms = value ?? false);
            },
          ),
        ),
        const SizedBox(width: AppDimensions.spaceXS),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _agreedToTerms = !_agreedToTerms);
            },
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                children: [
                  const TextSpan(text: '${AppStrings.termsAgreement} '),
                  TextSpan(
                    text: AppStrings.termsAndPrivacy,
                    style: AppTextStyles.bodyMedium(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignUp,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.backgroundDark,
                ),
              )
            : Text(
                AppStrings.signUp,
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
      ),
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        const OrDivider(text: AppStrings.orSignUpWith),
        const SizedBox(height: AppDimensions.spaceLG),
        SocialLoginRow(
          onGooglePressed: () => _handleGoogleSignUp(),
          onApplePressed: _handleAppleSignUp,
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.login),
        child: RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            children: [
              const TextSpan(text: '${AppStrings.alreadyHaveAccount} '),
              TextSpan(
                text: AppStrings.logIn,
                style: AppTextStyles.bodyMedium(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
