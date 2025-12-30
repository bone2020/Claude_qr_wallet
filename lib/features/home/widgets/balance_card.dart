import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';

/// Balance card widget displaying wallet balance
class BalanceCard extends StatelessWidget {
  final double balance;
  final String currency;
  final bool isHidden;
  final String walletId;
  final VoidCallback onToggleVisibility;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.currency,
    required this.isHidden,
    required this.walletId,
    required this.onToggleVisibility,
  });

  String get _formattedBalance {
    if (isHidden) return '••••••';
    
    // Format with thousand separators
    final parts = balance.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  void _copyWalletId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: walletId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.walletIdCopied),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceXL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A),
            Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.totalBalance,
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _copyWalletId(context),
                    child: Row(
                      children: [
                        Text(
                          walletId,
                          style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Iconsax.copy,
                          size: 12,
                          color: AppColors.textTertiaryDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackgroundDark,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  ),
                  child: Icon(
                    isHidden ? Iconsax.eye_slash : Iconsax.eye,
                    color: AppColors.textSecondaryDark,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceMD),

          // Balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  currency,
                  style: AppTextStyles.headlineMedium(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _formattedBalance,
                  style: AppTextStyles.balanceDisplay(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceLG),

          // Wallet ID QR hint
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceSM,
              vertical: AppDimensions.spaceXS,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.scan_barcode,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.tapToCopy,
                  style: AppTextStyles.caption(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
