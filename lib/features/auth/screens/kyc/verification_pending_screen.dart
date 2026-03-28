import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../core/services/push_notification_service.dart';

class VerificationPendingScreen extends ConsumerStatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  ConsumerState<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState
    extends ConsumerState<VerificationPendingScreen> {
  StreamSubscription<DocumentSnapshot>? _kycSubscription;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _listenForKycStatusChange();
  }

  @override
  void dispose() {
    _kycSubscription?.cancel();
    super.dispose();
  }

  void _listenForKycStatusChange() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _kycSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || _isTransitioning) return;

      final data = snapshot.data()!;
      final kycStatus = data['kycStatus'] as String?;

      if (kycStatus == 'verified') {
        setState(() => _isTransitioning = true);

        // Refresh wallet and currency now that verification is complete
        await ref.read(walletNotifierProvider.notifier).refreshWallet();
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
        await PushNotificationService().saveTokenToFirestore();

        if (!mounted) return;
        context.go(AppRoutes.main);
      } else if (kycStatus == 'failed') {
        setState(() => _isTransitioning = true);

        if (!mounted) return;
        _showFailedDialog();
      }
    });
  }

  void _showFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        ),
        title: Text(
          'Verification Failed',
          style: AppTextStyles.headlineSmall(),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your identity verification did not pass. This may be due to a face mismatch or document issue. Please try again.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.kyc);
              },
              child: Text(
                'Try Again',
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 64,
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceXXL),

              Text(
                'Verification In Progress',
                style: AppTextStyles.headlineMedium(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spaceMD),

              Text(
                'Your identity documents are being verified. This usually takes a few seconds but may take up to a few minutes.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spaceXXL),

              // Loading indicator
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMD),

              Text(
                'Please wait...',
                style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
              ),

              const Spacer(),

              // Info card
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceMD),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                    const SizedBox(width: AppDimensions.spaceMD),
                    Expanded(
                      child: Text(
                        'You will be automatically redirected once verification is complete. Do not close the app.',
                        style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMD),
            ],
          ),
        ),
      ),
    );
  }
}
