import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/constants.dart';

/// Transaction details screen
class TransactionDetailsScreen extends StatelessWidget {
  final String transactionId;

  const TransactionDetailsScreen({
    super.key,
    required this.transactionId,
  });

  // Mock data - replace with actual data lookup
  Map<String, dynamic> get _transaction => {
        'id': transactionId,
        'reference': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Sarah Johnson',
        'walletId': 'QRW-1234-5678',
        'type': 'receive',
        'amount': 15000.0,
        'fee': 0.0,
        'currency': '₦',
        'date': DateTime.now().subtract(const Duration(hours: 2)),
        'status': 'completed',
        'note': 'Payment for lunch',
      };

  bool get _isCredit =>
      _transaction['type'] == 'receive' || _transaction['type'] == 'deposit';

  Color get _statusColor {
    switch (_transaction['status']) {
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

  IconData get _statusIcon {
    switch (_transaction['status']) {
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
  Widget build(BuildContext context) {
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
            _buildAmountCard()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.1, end: 0, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXL),

            // Status
            _buildStatusBadge()
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXL),

            // Details Card
            _buildDetailsCard(context)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    final amount = _transaction['amount'] as double;
    final currency = _transaction['currency'] as String;

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
              color: (_isCredit ? AppColors.success : AppColors.error)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCredit ? Iconsax.arrow_down : Iconsax.arrow_up_2,
              color: _isCredit ? AppColors.success : AppColors.error,
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
                _isCredit ? '+' : '-',
                style: AppTextStyles.displaySmall(
                  color: _isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                currency,
                style: AppTextStyles.displaySmall(
                  color: _isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                _formatAmount(amount),
                style: AppTextStyles.displayMedium(
                  color: _isCredit ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceXS),

          // Transaction type label
          Text(
            _isCredit ? AppStrings.received : AppStrings.sent,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMD,
        vertical: AppDimensions.spaceXS,
      ),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon,
            size: 16,
            color: _statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            _transaction['status'].toString().toUpperCase(),
            style: AppTextStyles.labelSmall(color: _statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final date = _transaction['date'] as DateTime;

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
            label: _isCredit ? AppStrings.from : AppStrings.to,
            value: _transaction['name'],
            subtitle: _transaction['walletId'],
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
            value: _transaction['reference'],
            onTap: () => _copyToClipboard(
              context,
              _transaction['reference'],
              'Transaction ID',
            ),
            trailing: const Icon(
              Iconsax.copy,
              size: 16,
              color: AppColors.textSecondaryDark,
            ),
          ),

          // Note (if present)
          if (_transaction['note'] != null &&
              _transaction['note'].toString().isNotEmpty) ...[
            _buildDivider(),
            _buildDetailRow(
              label: AppStrings.note,
              value: _transaction['note'],
            ),
          ],

          // Fee (if present)
          if ((_transaction['fee'] as double) > 0) ...[
            _buildDivider(),
            _buildDetailRow(
              label: AppStrings.transactionFee,
              value:
                  '${_transaction['currency']}${_formatAmount(_transaction['fee'])}',
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
