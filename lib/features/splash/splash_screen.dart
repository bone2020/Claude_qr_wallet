import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/constants.dart';
import '../../core/router/app_router.dart';
import '../../providers/currency_provider.dart';

/// Splash screen shown on app launch
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for splash animation
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // Check if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Load user's currency preference
      await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();

      if (!mounted) return;

      // User is logged in, navigate to main screen
      context.go(AppRoutes.main);
    } else {
      // User is not logged in, navigate to welcome screen
      context.go(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon/Logo
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
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXL),

            // App Name
            Text(
              AppStrings.appName,
              style: AppTextStyles.displaySmall(),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0, delay: 300.ms, duration: 500.ms),

            const SizedBox(height: AppDimensions.spaceXS),

            // Tagline
            Text(
              AppStrings.appTagline,
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
