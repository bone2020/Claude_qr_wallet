import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../generated/l10n/app_localizations.dart';

/// Balance card widget displaying wallet balance
class BalanceCard extends StatelessWidget {
  final int balance;
  final int heldBalance;
  final int availableBalance;
  final String currency;
  final bool isHidden;
  final String walletId;
  final VoidCallback onToggleVisibility;

  const BalanceCard({
    super.key,
    required this.balance,
    this.heldBalance = 0,
    this.availableBalance = 0,
    required this.currency,
    required this.isHidden,
    required this.walletId,
    required this.onToggleVisibility,
  });

  String get _formattedBalance {
    if (isHidden) return '••••••';

    // Convert minor units to major and format with thousand separators
    final parts = (balance / 100).toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  void _copyWalletId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: walletId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).walletIdCopied),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
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
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
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
                    AppLocalizations.of(context).totalBalance,
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _copyWalletId(context),
                    child: Row(
                      children: [
                       Text(
                        walletId,
                          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Iconsax.copy,
                          size: 16,
                          color: AppColors.textSecondaryDark,
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formattedBalance,
                    style: AppTextStyles.balanceDisplay(),
                  ),
                ),
              ),
            ],
          ),

          // Show held/available breakdown if there are active holds
          if (heldBalance > 0 && !isHidden) ...[
            const SizedBox(height: AppDimensions.spaceSM),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceSM,
                      vertical: AppDimensions.spaceXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).availableBalanceLabel,
                          style: AppTextStyles.caption(color: AppColors.success),
                        ),
                        Text(
                          AppLocalizations.of(context).currencyAmount(currency, (availableBalance / 100).toStringAsFixed(2)),
                          style: AppTextStyles.bodySmall(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceSM,
                      vertical: AppDimensions.spaceXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).onHoldBalanceLabel,
                          style: AppTextStyles.caption(color: AppColors.warning),
                        ),
                        Text(
                          AppLocalizations.of(context).currencyAmount(currency, (heldBalance / 100).toStringAsFixed(2)),
                          style: AppTextStyles.bodySmall(color: AppColors.warning),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.spaceLG),

          // Wallet ID QR hint
          GestureDetector(
            onTap: () => _copyWalletId(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceSM,
                vertical: AppDimensions.spaceXS,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Iconsax.copy,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).tapToCopy,
                    style: AppTextStyles.caption(color: AppColors.primary),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}
