import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../core/services/auth_localization_resolver.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_button.dart';

/// Login screen for existing users
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).errorFieldRequired;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return AppLocalizations.of(context).errorInvalidEmail;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).errorFieldRequired;
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Call the auth provider to sign in with Firebase
      final result = await ref.read(authNotifierProvider.notifier).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        // Load user's currency preference
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();

        if (!mounted) return;

        // Navigate to main screen
        context.go(AppRoutes.main);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
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

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;

      if (result.success) {
        // Load user's currency preference
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();

        if (!mounted) return;

        context.go(AppRoutes.main);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
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

  Future<void> _handleAppleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider.notifier).signInWithApple();

      if (!mounted) return;

      if (result.success) {
        // Load user's currency preference
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();

        if (!mounted) return;

        context.go(AppRoutes.main);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveAuthResultError(AppLocalizations.of(context), result)),
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

  void _handleForgotPassword() {
    context.push(AppRoutes.forgotPassword);
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

                // Back Button
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Header
                _buildHeader()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.space4XL),

                // Form Fields
                _buildFormFields(),

                const SizedBox(height: AppDimensions.spaceMD),

                // Forgot Password
                _buildForgotPassword()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Login Button
                _buildLoginButton()
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),



                const SizedBox(height: AppDimensions.spaceXXL),

                // Sign Up Link
                _buildSignUpLink()
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 400.ms),

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
          AppLocalizations.of(context).logIn,
          style: AppTextStyles.displaySmall(),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          AppLocalizations.of(context).logInSubtitle,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Email
        CustomTextField(
          hintText: AppLocalizations.of(context).emailHint,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceMD),

        // Password
        PasswordTextField(
          controller: _passwordController,
          hintText: AppLocalizations.of(context).passwordHint,
          textInputAction: TextInputAction.done,
          validator: _validatePassword,
          onChanged: (_) {},
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _handleForgotPassword,
        child: Text(
          AppLocalizations.of(context).forgotPassword,
          style: AppTextStyles.bodyMedium(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
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
                AppLocalizations.of(context).logIn,
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
      ),
    );
  }

  // Foundation for social login (Google + Apple) — wired into login flow
  // when activated. Handlers exist and are functional; only the build()
  // invocation is currently absent.
  // ignore: unused_element
  Widget _buildSocialLogin() {
    return Column(
      children: [
        OrDivider(text: AppLocalizations.of(context).orLogInWith),
        const SizedBox(height: AppDimensions.spaceLG),
        SocialLoginRow(
          onGooglePressed: () => _handleGoogleLogin(),
          onApplePressed: () => _handleAppleLogin(),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.signUp),
        child: RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            children: [
              TextSpan(text: '${AppLocalizations.of(context).dontHaveAccount} '),
              TextSpan(
                text: AppLocalizations.of(context).signUp,
                style: AppTextStyles.bodyMedium(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
