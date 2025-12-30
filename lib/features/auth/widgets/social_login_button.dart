import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';

/// Social login button (Google, Apple)
class SocialLoginButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool isLoading;

  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  /// Google sign-in button
  factory SocialLoginButton.google({
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SocialLoginButton(
      label: 'Google',
      icon: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: const Text(
          'G',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }

  /// Apple sign-in button
  factory SocialLoginButton.apple({
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SocialLoginButton(
      label: 'Apple',
      icon: const Icon(
        Icons.apple,
        color: Colors.white,
        size: 24,
      ),
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.buttonHeightLG,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.inputBorderDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : icon,
      ),
    );
  }
}

/// Row of social login buttons
class SocialLoginRow extends StatelessWidget {
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool isGoogleLoading;
  final bool isAppleLoading;

  const SocialLoginRow({
    super.key,
    required this.onGooglePressed,
    required this.onApplePressed,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SocialLoginButton.google(
            onPressed: onGooglePressed,
            isLoading: isGoogleLoading,
          ),
        ),
        const SizedBox(width: AppDimensions.spaceMD),
        Expanded(
          child: SocialLoginButton.apple(
            onPressed: onApplePressed,
            isLoading: isAppleLoading,
          ),
        ),
      ],
    );
  }
}

/// Divider with "or" text
class OrDivider extends StatelessWidget {
  final String text;

  const OrDivider({
    super.key,
    this.text = 'Or sign up with',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.inputBorderDark),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
          child: Text(
            text,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.inputBorderDark),
        ),
      ],
    );
  }
}
