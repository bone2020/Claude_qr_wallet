import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/constants.dart';
import '../../core/router/app_router.dart';
import '../../providers/currency_provider.dart';
import '../../models/user_model.dart';

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
      try {
        // Fetch user document from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (!mounted) return;

        // Check if user document exists
        if (!userDoc.exists) {
          // User exists in Auth but not in Firestore (incomplete signup)
          // Sign them out and send to welcome screen
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          context.go(AppRoutes.welcome);
          return;
        }

        // Parse user data
        final userData = UserModel.fromJson(userDoc.data()!);

        // Check if phone is verified
        if (!userData.isVerified) {
          // User hasn't completed phone verification
          context.go(AppRoutes.otpVerification, extra: {
            'phoneNumber': userData.phoneNumber,
            'email': userData.email,
            'isPhoneVerification': true,
          });
          return;
        }

        // Check if KYC is completed
        if (!userData.kycCompleted) {
          // User hasn't completed KYC
          context.go(AppRoutes.kyc);
          return;
        }

        // Load user's currency preference
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();

        if (!mounted) return;

        // User is fully verified, navigate to main screen
        context.go(AppRoutes.main);
      } catch (e) {
        // Error fetching user data, sign out and go to welcome
        debugPrint('Error checking user status: $e');
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        context.go(AppRoutes.welcome);
      }
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
