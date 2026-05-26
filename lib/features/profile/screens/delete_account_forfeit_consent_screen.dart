import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';

/// Step 2.5 of the delete-account flow — only shown when the user's wallet
/// balance is below the transfer minimum.
///
/// The user has a residual balance that is too small to withdraw (below the
/// transfer/withdrawal threshold of 100 in their currency, i.e. 10000 minor
/// units). Forcing them to "withdraw first" would trap them in an
/// unrecoverable state. This screen surfaces the situation, asks for
/// explicit consent, and on confirm proceeds to the confirmation screen with
/// `confirmForfeit: true` in the route extra so the server-side sweep will
/// accept the request.
class DeleteAccountForfeitConsentScreen extends ConsumerWidget {
  /// Residual balance in MINOR units (e.g. 289 means 2.89 major units).
  /// Typed as num to tolerate either int or double values from Firestore.
  final num balanceMinor;

  /// Currency symbol to render alongside the amount (e.g. "KSh", "NGN").
  final String currencySymbol;

  const DeleteAccountForfeitConsentScreen({
    super.key,
    required this.balanceMinor,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountStr = (balanceMinor / 100).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Delete account', style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimensions.spaceLG),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceLG),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: AppDimensions.iconXL,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Text(
                'Forfeit remaining balance?',
                style: AppTextStyles.headlineSmall(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text(
                'Your remaining balance of $currencySymbol$amountStr is below the '
                'transfer minimum of ${currencySymbol}100.00.',
                style: AppTextStyles.bodyMedium(color: AppColors.textPrimaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text(
                'If you proceed, this amount will be forfeited and your account '
                'will be deleted. This cannot be undone.',
                style:
                    AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: () => context.push(
                  AppRoutes.deleteAccountConfirm,
                  extra: <String, dynamic>{'confirmForfeit': true},
                ),
                child: Text(
                  'Forfeit and delete my account',
                  style: AppTextStyles.labelLarge(color: Colors.white),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: Text('Cancel', style: AppTextStyles.labelLarge()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
