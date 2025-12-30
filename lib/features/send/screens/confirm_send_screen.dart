import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../auth/widgets/custom_text_field.dart';

/// Confirm send screen showing transaction summary
class ConfirmSendScreen extends StatefulWidget {
  final String recipientWalletId;
  final String recipientName;
  final double amount;
  final String? note;

  const ConfirmSendScreen({
    super.key,
    required this.recipientWalletId,
    required this.recipientName,
    required this.amount,
    this.note,
  });

  @override
  State<ConfirmSendScreen> createState() => _ConfirmSendScreenState();
}

class _ConfirmSendScreenState extends State<ConfirmSendScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  
  // Mock fee calculation
  double get _fee => (_amount * 0.01).clamp(10, 100); // 1% fee, min ₦10, max ₦100
  double get _amount => double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
  double get _total => _amount + _fee;
  
  final String _currency = '₦';

  @override
  void initState() {
    super.initState();
    if (widget.amount > 0) {
      _amountController.text = widget.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  Future<void> _handleSend() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Implement actual send transaction
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Text(
                AppStrings.successMoneySent,
                style: AppTextStyles.headlineMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                '$_currency${_formatAmount(_amount)} sent to ${widget.recipientName}',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeightMD,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.main);
                  },
                  child: Text(
                    AppStrings.done,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        title: Text(AppStrings.confirmSend, style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Column(
                  children: [
                    // Recipient Card
                    _buildRecipientCard()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.1, end: 0, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // Amount Input
                    _buildAmountInput()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // Transaction Summary
                    _buildTransactionSummary()
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),

            // Send Button
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Center(
              child: Text(
                widget.recipientName.isNotEmpty
                    ? widget.recipientName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.headlineLarge(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.sendingTo,
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.recipientName,
                  style: AppTextStyles.bodyLarge(),
                ),
                Text(
                  widget.recipientWalletId,
                  style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                ),
              ],
            ),
          ),
          const Icon(
            Iconsax.verify5,
            color: AppColors.success,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.amount,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLG,
            vertical: AppDimensions.spaceMD,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _currency,
                style: AppTextStyles.displaySmall(color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.spaceXS),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.displaySmall(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: AppTextStyles.displaySmall(color: AppColors.textTertiaryDark),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Column(
        children: [
          _buildSummaryRow(AppStrings.amount, '$_currency${_formatAmount(_amount)}'),
          const SizedBox(height: AppDimensions.spaceMD),
          _buildSummaryRow(AppStrings.transactionFee, '$_currency${_formatAmount(_fee)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
            child: Divider(color: AppColors.inputBorderDark),
          ),
          _buildSummaryRow(
            AppStrings.totalAmount,
            '$_currency${_formatAmount(_total)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.bodyLarge()
              : AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.headlineSmall(color: AppColors.primary)
              : AppTextStyles.bodyMedium(),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.inputBorderDark, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading || _amount <= 0 ? null : _handleSend,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.backgroundDark,
                    ),
                  )
                : Text(
                    '${AppStrings.send} $_currency${_formatAmount(_total)}',
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}
