import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/constants.dart';
import '../../../providers/currency_provider.dart';

/// Transaction details screen
class TransactionDetailsScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailsScreen({
    super.key,
    required this.transactionId,
  });

  // Mock data - replace with actual data lookup
  Map<String, dynamic> _getTransaction(String currencySymbol) => {
        'id': transactionId,
        'reference': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Sarah Johnson',
        'walletId': 'QRW-1234-5678',
        'type': 'receive',
        'amount': 15000.0,
        'fee': 0.0,
        'currency': currencySymbol,
        'date': DateTime.now().subtract(const Duration(hours: 2)),
        'status': 'completed',
        'note': 'Payment for lunch',
      };

  bool _isCredit(Map<String, dynamic> transaction) =>
      transaction['type'] == 'receive' || transaction['type'] == 'deposit';

  Color _getStatusColor(Map<String, dynamic> transaction) {
    switch (transaction['status']) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textSecondaryDark;
    }
  }

  IconData _getStatusIcon(Map<String, dynamic> transaction) {
    switch (transaction['status']) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.access_time;
      case 'failed':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(currencyNotifierProvider).currency.symbol;
    final transaction = _getTransaction(currencySymbol);
    final isCredit = _isCredit(transaction);
    final statusColor = _getStatusColor(transaction);
    final statusIcon = _getStatusIcon(transaction);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          AppStrings.transactionDetails,
          style: AppTextStyles.headlineMedium(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        child: Column(
          children: [
            // Amount Card
            _buildAmountCard(transaction, isCredit)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.1, end: 0, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXL),

            // Status
            _buildStatusBadge(transaction, statusColor, statusIcon)
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXL),

            // Details Card
            _buildDetailsCard(context, transaction, isCredit)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(Map<String, dynamic> transaction, bool isCredit) {
    final amount = transaction['amount'] as double;
    final currency = transaction['currency'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceXL),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      ),
      child: Column(
        children: [
          // Transaction type icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.error)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Iconsax.arrow_down : Iconsax.arrow_up_2,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 32,
            ),
          ),

          const SizedBox(height: AppDimensions.spaceMD),

          // Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCredit ? '+' : '-',
                style: AppTextStyles.displaySmall(
                  color: isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                currency,
                style: AppTextStyles.displaySmall(
                  color: isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                _formatAmount(amount),
                style: AppTextStyles.displayMedium(
                  color: isCredit ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceXS),

          // Transaction type label
          Text(
            isCredit ? AppStrings.received : AppStrings.sent,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
      Map<String, dynamic> transaction, Color statusColor, IconData statusIcon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMD,
        vertical: AppDimensions.spaceXS,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            transaction['status'].toString().toUpperCase(),
            style: AppTextStyles.labelSmall(color: statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
      BuildContext context, Map<String, dynamic> transaction, bool isCredit) {
    final date = transaction['date'] as DateTime;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Column(
        children: [
          // From/To
          _buildDetailRow(
            label: isCredit ? AppStrings.from : AppStrings.to,
            value: transaction['name'],
            subtitle: transaction['walletId'],
          ),

          _buildDivider(),

          // Date & Time
          _buildDetailRow(
            label: AppStrings.date,
            value: DateFormat('MMM d, yyyy').format(date),
            subtitle: DateFormat.jm().format(date),
          ),

          _buildDivider(),

          // Transaction ID
          _buildDetailRow(
            label: AppStrings.transactionId,
            value: transaction['reference'],
            onTap: () => _copyToClipboard(
              context,
              transaction['reference'],
              'Transaction ID',
            ),
            trailing: const Icon(
              Iconsax.copy,
              size: 16,
              color: AppColors.textSecondaryDark,
            ),
          ),

          // Note (if present)
          if (transaction['note'] != null &&
              transaction['note'].toString().isNotEmpty) ...[
            _buildDivider(),
            _buildDetailRow(
              label: AppStrings.note,
              value: transaction['note'],
            ),
          ],

          // Fee (if present)
          if ((transaction['fee'] as double) > 0) ...[
            _buildDivider(),
            _buildDetailRow(
              label: AppStrings.transactionFee,
              value:
                  '${transaction['currency']}${_formatAmount(transaction['fee'])}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: AppTextStyles.bodyMedium(),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        trailing,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spaceXS),
      child: Divider(color: AppColors.inputBorderDark),
    );
  }
}
