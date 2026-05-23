import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';

/// Step 1 of the delete-account flow.
///
/// Warns the user, explains what is deleted vs kept, and offers a clear path
/// forward (Continue → Preflight) or out (Cancel → pop back to Profile).
class DeleteAccountExplainerScreen extends StatelessWidget {
  const DeleteAccountExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceLG),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: AppDimensions.iconXL,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Text(
                'Are you sure you want to delete your account?',
                style: AppTextStyles.headlineSmall(),
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              Text('What will be deleted:', style: AppTextStyles.bodyLarge()),
              const SizedBox(height: AppDimensions.spaceSM),
              _buildBullet('Your profile and personal information'),
              _buildBullet('Your transaction history (from the app)'),
              _buildBullet('Your ability to sign in'),

              const SizedBox(height: AppDimensions.spaceLG),
              Text('What will be kept:', style: AppTextStyles.bodyLarge()),
              const SizedBox(height: AppDimensions.spaceSM),
              _buildBullet('Some records are kept as required by law'),

              const SizedBox(height: AppDimensions.spaceXXL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: Text('Cancel', style: AppTextStyles.labelLarge()),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceMD),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          context.push(AppRoutes.deleteAccountPreflight),
                      child: Text(
                        'Continue',
                        style: AppTextStyles.labelLarge(
                            color: AppColors.backgroundDark),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMD),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppColors.textSecondaryDark),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
