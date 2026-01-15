import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../auth/widgets/custom_text_field.dart';

/// Confirm send screen showing transaction summary
class ConfirmSendScreen extends ConsumerStatefulWidget {
  final String recipientWalletId;
  final String recipientName;
  final double amount;
  final String? note;
  final bool fromScan;
  final bool amountLocked;
  final String? recipientCurrency;
  final String? recipientCurrencySymbol;

  const ConfirmSendScreen({
    super.key,
    required this.recipientWalletId,
    required this.recipientName,
    required this.amount,
    this.note,
    this.fromScan = false,
    this.amountLocked = false,
    this.recipientCurrency,
    this.recipientCurrencySymbol,
  });

  @override
  ConsumerState<ConfirmSendScreen> createState() => _ConfirmSendScreenState();
}

class _ConfirmSendScreenState extends ConsumerState<ConfirmSendScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _hasConvertedMerchantAmount = false;

  // Mock fee calculation
  double get _fee => (_amount * 0.01).clamp(10, 100); // 1% fee, min 10, max 100
  double get _amount => double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
  double get _total => _amount + _fee;

  String get _currency => ref.watch(currencyNotifierProvider).currency.symbol;
  String get _currencyCode => ref.watch(currencyNotifierProvider).currency.code;

  // Currency conversion
  bool get _needsConversion {
    final recipientCurrency = widget.recipientCurrency;
    return recipientCurrency != null && recipientCurrency != _currencyCode;
  }

  double? get _convertedAmount {
    if (!_needsConversion || widget.recipientCurrency == null) return null;
    return ExchangeRateService.convert(
      amount: _amount,
      fromCurrency: _currencyCode,
      toCurrency: widget.recipientCurrency!,
    );
  }

  double? get _exchangeRate {
    if (!_needsConversion || widget.recipientCurrency == null) return null;
    return ExchangeRateService.getExchangeRate(
      fromCurrency: _currencyCode,
      toCurrency: widget.recipientCurrency!,
    );
  }

  // Merchant QR specific getters
  bool get _isMerchantQR => widget.amountLocked && _needsConversion;

  // Original amount seller requested in their currency
  double get _sellerRequestedAmount => widget.amount;

  // Reverse rate: from seller's currency to buyer's currency
  double? get _reverseExchangeRate {
    if (!_needsConversion || widget.recipientCurrency == null) return null;
    return ExchangeRateService.getExchangeRate(
      fromCurrency: widget.recipientCurrency!,
      toCurrency: _currencyCode,
    );
  }

  // Amount buyer needs to pay in their currency (for merchant QR)
  double? get _buyerPaysAmount {
    if (!_isMerchantQR || widget.recipientCurrency == null) return null;
    return ExchangeRateService.convert(
      amount: _sellerRequestedAmount,
      fromCurrency: widget.recipientCurrency!,
      toCurrency: _currencyCode,
    );
  }

  @override
  void initState() {
    super.initState();
    // For non-merchant QR or same currency, set amount directly
    // Merchant QR with different currency needs conversion in didChangeDependencies
    if (widget.amount > 0 && !widget.amountLocked) {
      _amountController.text = widget.amount.toStringAsFixed(0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Convert merchant QR amount from seller's currency to buyer's currency
    if (!_hasConvertedMerchantAmount && widget.amountLocked && widget.amount > 0) {
      _hasConvertedMerchantAmount = true;
      if (_isMerchantQR && _buyerPaysAmount != null) {
        // Seller requested amount in their currency, convert to buyer's currency
        _amountController.text = _buyerPaysAmount!.toStringAsFixed(2);
      } else {
        // Same currency or no conversion needed
        _amountController.text = widget.amount.toStringAsFixed(2);
      }
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
      // Check if biometric is enabled and require authentication
      final secureStorage = SecureStorageService.instance;
      final biometricEnabled = await secureStorage.isBiometricEnabled();

      if (biometricEnabled) {
        final biometricService = BiometricService();
        final authResult = await biometricService.authenticateForTransaction(
          amount: _total,
          recipient: widget.recipientName,
          currencySymbol: _currency,
        );

        if (!authResult.success) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          if (!authResult.cancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authResult.error ?? 'Authentication failed'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      // Get wallet service and send money
      final walletService = ref.read(walletServiceProvider);
      final result = await walletService.sendMoney(
        recipientWalletId: widget.recipientWalletId,
        amount: _amount,
        note: widget.note,
      );

      if (!mounted) return;

      if (result.success) {
        // Refresh wallet and transactions
        ref.read(walletNotifierProvider.notifier).refreshWallet();
        ref.read(transactionsNotifierProvider.notifier).refreshTransactions();

        // Show success dialog
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Transaction failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
                    // Payment Request Banner (if from merchant QR)
                    if (widget.amountLocked && widget.note != null && widget.note!.isNotEmpty) ...[
                      _buildPaymentRequestBanner()
                          .animate()
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceMD),
                    ],

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

  Widget _buildPaymentRequestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Request',
                  style: AppTextStyles.labelMedium(color: AppColors.primary),
                ),
                Text(
                  widget.note!,
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppStrings.amount,
              style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
            ),
            if (widget.amountLocked) ...[
              const SizedBox(width: AppDimensions.spaceXS),
              const Icon(Icons.lock, size: 14, color: AppColors.textTertiaryDark),
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLG,
            vertical: AppDimensions.spaceMD,
          ),
          decoration: BoxDecoration(
            color: widget.amountLocked
                ? AppColors.surfaceDark.withOpacity(0.5)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(
              color: widget.amountLocked
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.inputBorderDark,
            ),
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
                  readOnly: widget.amountLocked,
                  enabled: !widget.amountLocked,
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
              if (widget.amountLocked)
                const Icon(Icons.lock, color: AppColors.textTertiaryDark, size: 20),
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
          // Show conversion info if currencies are different
          if (_needsConversion && (_isMerchantQR || _convertedAmount != null)) ...[
            const SizedBox(height: AppDimensions.spaceMD),
            _buildConversionInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildConversionInfo() {
    final recipientSymbol = widget.recipientCurrencySymbol ?? widget.recipientCurrency ?? '';

    // For merchant QR: show "Seller requested X" in seller's currency
    // For regular send: show "Recipient receives X" in recipient's currency
    if (_isMerchantQR) {
      final reverseRate = _reverseExchangeRate ?? 0;
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.info.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seller requested:',
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                ),
                Text(
                  '$recipientSymbol${_formatAmount(_sellerRequestedAmount)}',
                  style: AppTextStyles.bodyLarge(color: AppColors.info),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXS),
            Text(
              '1 ${widget.recipientCurrency} = ${reverseRate.toStringAsFixed(2)} $_currencyCode',
              style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      );
    }

    // Regular send: show what recipient receives
    final rate = _exchangeRate ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recipient receives:',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              ),
              Text(
                '$recipientSymbol${_formatAmount(_convertedAmount!)}',
                style: AppTextStyles.bodyLarge(color: AppColors.info),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            '1 $_currencyCode = ${rate.toStringAsFixed(2)} ${widget.recipientCurrency}',
            style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
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
