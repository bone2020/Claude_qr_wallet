import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/constants.dart';

/// Transaction tile widget for displaying a single transaction
class TransactionTile extends StatelessWidget {
  final String name;
  final String type; // 'send', 'receive', 'deposit', 'withdraw'
  final double amount;
  final String currency;
  final DateTime date;
  final String status; // 'completed', 'pending', 'failed'
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.name,
    required this.type,
    required this.amount,
    required this.currency,
    required this.date,
    required this.status,
    this.onTap,
  });

  bool get _isCredit => type == 'receive' || type == 'deposit';

  IconData get _icon {
    switch (type) {
      case 'send':
        return Iconsax.arrow_up_2;
      case 'receive':
        return Iconsax.arrow_down;
      case 'deposit':
        return Iconsax.add_circle;
      case 'withdraw':
        return Iconsax.minus_cirlce;
      default:
        return Iconsax.money;
    }
  }

  Color get _iconBackgroundColor {
    if (status == 'pending') return AppColors.warning.withOpacity(0.1);
    if (status == 'failed') return AppColors.error.withOpacity(0.1);
    return _isCredit
        ? AppColors.success.withOpacity(0.1)
        : AppColors.error.withOpacity(0.1);
  }

  Color get _iconColor {
    if (status == 'pending') return AppColors.warning;
    if (status == 'failed') return AppColors.error;
    return _isCredit ? AppColors.success : AppColors.error;
  }

  Color get _amountColor {
    if (status == 'pending') return AppColors.warning;
    if (status == 'failed') return AppColors.textSecondaryDark;
    return _isCredit ? AppColors.success : AppColors.textPrimaryDark;
  }

  String get _amountPrefix {
    if (status == 'failed') return '';
    return _isCredit ? '+' : '-';
  }

  String get _formattedAmount {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  String get _formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today, ${DateFormat.jm().format(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday, ${DateFormat.jm().format(date)}';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconBackgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              ),
              child: Icon(
                _icon,
                color: _iconColor,
                size: 20,
              ),
            ),

            const SizedBox(width: AppDimensions.spaceMD),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formattedDate,
                        style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Pending',
                            style: AppTextStyles.caption(color: AppColors.warning),
                          ),
                        ),
                      ],
                      if (status == 'failed') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Failed',
                            style: AppTextStyles.caption(color: AppColors.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '$_amountPrefix$currency$_formattedAmount',
              style: AppTextStyles.labelMedium(color: _amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
