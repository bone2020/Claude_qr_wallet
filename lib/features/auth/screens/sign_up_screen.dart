import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/country_codes.dart';
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
  final _phoneFieldKey = GlobalKey<PhoneInputFieldState>();

  bool _agreedToTerms = false;
  bool _isLoading = false;
  CountryCode _selectedCountry = AfricanCountryCodes.defaultCountry;

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
    if (value == null || value.isEmpty) return AppLocalizations.of(context).errorFieldRequired;
    if (value.split(' ').length < 2) return 'Please enter your full name';
    return null;
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return AppLocalizations.of(context).errorFieldRequired;
    if (value.length < 7) return AppLocalizations.of(context).errorInvalidPhone;
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppLocalizations.of(context).errorFieldRequired;
    if (value.length < 8) return AppLocalizations.of(context).errorPasswordWeak;
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return AppLocalizations.of(context).errorFieldRequired;
    if (value != _passwordController.text) return AppLocalizations.of(context).errorPasswordMismatch;
    return null;
  }

  String get _fullPhoneNumber => '${_selectedCountry.dialCode}${_phoneController.text}';

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
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final result = await authNotifier.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _fullPhoneNumber,
        countryCode: _selectedCountry.code,
        currencyCode: _selectedCountry.currency,
      );

      if (!mounted) return;

      if (result.success) {
        // Send email verification
        await authNotifier.sendEmailVerification();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please verify your email.'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to email verification screen
        context.push(
          AppRoutes.otpVerification,
          extra: {
            'email': _emailController.text.trim(),
            'phoneNumber': _fullPhoneNumber,
            'isEmailVerification': true,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? AppLocalizations.of(context).errorGeneric),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final result = await authNotifier.signInWithGoogle();
      if (!mounted) return;

      if (result.success) {
        // Route based on country
        const smileIdCountries = ['GH', 'NG', 'KE', 'ZA', 'CI', 'UG', 'ZM', 'ZW'];
        final user = ref.read(currentUserProvider);
        final countryCode = (user?.country ?? 'GH').toUpperCase().trim();

        if (smileIdCountries.contains(countryCode)) {
          context.go(AppRoutes.kyc);
        } else {
          context.go(
            AppRoutes.phoneOtp,
            extra: {'phoneNumber': user?.phoneNumber ?? ''},
          );
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAppleSignUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Apple Sign In coming soon'),
        backgroundColor: AppColors.warning,
      ),
    );
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
                  icon: const Icon(Icons.arrow_back_ios),
                  color: AppColors.textPrimaryDark,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Title
                Text(
                  AppLocalizations.of(context).createAccount,
                  style: AppTextStyles.displaySmall(),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXS),

                // Subtitle
                Text(
                  AppLocalizations.of(context).signUpSubtitle,
                  style: AppTextStyles.bodyLarge(color: AppColors.textSecondaryDark),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Full Name
                CustomTextField(
                  controller: _fullNameController,
                  label: AppLocalizations.of(context).fullName,
                  hintText: AppLocalizations.of(context).fullNameHint,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondaryDark),
                  validator: _validateFullName,
                  textInputAction: TextInputAction.next,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceMD),

                // Email
                CustomTextField(
                  controller: _emailController,
                  label: AppLocalizations.of(context).email,
                  hintText: AppLocalizations.of(context).emailHint,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondaryDark),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  textInputAction: TextInputAction.next,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceMD),

                // Phone
                PhoneInputField(
                  key: _phoneFieldKey,
                  controller: _phoneController,
                  label: AppLocalizations.of(context).phoneNumber,
                  initialCountry: _selectedCountry,
                  validator: _validatePhone,
                  onCountryChanged: (country) => setState(() => _selectedCountry = country),
                  textInputAction: TextInputAction.next,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceMD),

                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: AppLocalizations.of(context).password,
                  hintText: AppLocalizations.of(context).passwordHint,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondaryDark),
                  obscureText: true,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.next,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 600.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceMD),

                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: AppLocalizations.of(context).confirmPassword,
                  hintText: AppLocalizations.of(context).confirmPasswordHint,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondaryDark),
                  obscureText: true,
                  validator: _validateConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSignUp(),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 700.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceMD),

                // Terms
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceXS),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${AppLocalizations.of(context).termsAgreement} ',
                          style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(context).termsAndPrivacy,
                              style: AppTextStyles.bodySmall(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 800.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeightLG,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.backgroundDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.backgroundDark),
                            ),
                          )
                        : Text(AppLocalizations.of(context).signUp, style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 900.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Divider
                OrDivider(text: AppLocalizations.of(context).orSignUpWith)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 1000.ms),

                const SizedBox(height: AppDimensions.spaceLG),

               

                const SizedBox(height: AppDimensions.spaceXXL),

                // Already have account
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: '${AppLocalizations.of(context).alreadyHaveAccount} ',
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => context.push(AppRoutes.login),
                            child: Text(AppLocalizations.of(context).logIn, style: AppTextStyles.bodyMedium(color: AppColors.primary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 1200.ms),

                const SizedBox(height: AppDimensions.spaceLG),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
