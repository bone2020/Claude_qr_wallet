import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Screen for adding money to wallet via Paystack
class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _paymentService = PaymentService();

  bool _isLoading = false;

  // Quick amount options
  final List<double> _quickAmounts = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      return 'Please enter a valid amount';
    }
    if (amount < 100) {
      return 'Minimum amount is ${AppStrings.currencySymbol}100';
    }
    if (amount > 5000000) {
      return 'Maximum amount is ${AppStrings.currencySymbol}5,000,000';
    }
    return null;
  }

  void _selectQuickAmount(double amount) {
    _amountController.text = amount.toInt().toString();
  }

  Future<void> _handleAddMoney() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final user = ref.read(currentUserProvider);

    if (user == null) {
      _showError('User not found. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _paymentService.initializePayment(
        context: context,
        email: user.email,
        amount: amount,
      );

      if (!mounted) return;

      if (result.success) {
        // Payment completed successfully
        ref.read(walletNotifierProvider.notifier).refreshWallet();
        _showSuccess('${AppStrings.currencySymbol}${amount.toStringAsFixed(2)} added to your wallet');
        context.pop();
      } else if (result.pending) {
        // Payment is pending (popup shown)
        // The payment service handles the callback
      } else if (result.error != null) {
        _showError(result.error!);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppStrings.addMoney,
          style: AppTextStyles.headlineSmall(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spaceLG),

                // Amount Input Card
                _buildAmountCard()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Quick Amount Selection
                _buildQuickAmounts()
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Payment Methods Info
                _buildPaymentInfo()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Continue Button
                _buildContinueButton()
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceLG),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.inputBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Amount',
            style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppStrings.currencySymbol,
                style: AppTextStyles.displayMedium(color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.displayMedium(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTextStyles.displayMedium(color: AppColors.textTertiaryDark),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: _validateAmount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceMD),
        Wrap(
          spacing: AppDimensions.spaceSM,
          runSpacing: AppDimensions.spaceSM,
          children: _quickAmounts.map((amount) {
            return GestureDetector(
              onTap: () => _selectQuickAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                  vertical: AppDimensions.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  border: Border.all(color: AppColors.inputBorderDark),
                ),
                child: Text(
                  '${AppStrings.currencySymbol}${_formatAmount(amount)}',
                  style: AppTextStyles.bodyMedium(),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.security_safe,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: AppTextStyles.labelMedium(),
                ),
                const SizedBox(height: 2),
                Text(
                  'Powered by Paystack. Your payment details are secure.',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAddMoney,
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
                'Continue to Payment',
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

/// Input formatter for thousands separator
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text.replaceAll(',', ''));
    if (value == null) {
      return oldValue;
    }

    final formatted = _formatNumber(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
