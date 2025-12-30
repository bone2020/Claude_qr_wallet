import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';

/// Welcome screen with options to sign up or log in
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo and App Name
              _buildHeader(),

              const Spacer(flex: 3),

              // Action Buttons
              _buildButtons(context),

              const SizedBox(height: AppDimensions.space4XL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 64,
            color: AppColors.backgroundDark,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 500.ms,
              curve: Curves.easeOut,
            )
            .fadeIn(duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceXL),

        // App Name
        Text(
          AppStrings.appName,
          style: AppTextStyles.displayMedium(),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceSM),

        // Tagline
        Text(
          AppStrings.appTagline,
          style: AppTextStyles.bodyLarge(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Create Account Button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: () => context.push(AppRoutes.signUp),
            child: Text(
              AppStrings.createAccount,
              style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(
              begin: 0.3,
              end: 0,
              delay: 400.ms,
              duration: 400.ms,
            ),

        const SizedBox(height: AppDimensions.spaceMD),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: OutlinedButton(
            onPressed: () => context.push(AppRoutes.login),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
            ),
            child: Text(
              AppStrings.logIn,
              style: AppTextStyles.labelLarge(color: AppColors.primary),
            ),
          ),
        ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(
              begin: 0.3,
              end: 0,
              delay: 500.ms,
              duration: 400.ms,
            ),
      ],
    );
  }
}
