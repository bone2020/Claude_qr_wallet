import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/wallet_provider.dart';

/// Screen shown after returning from Paystack payment
class PaymentResultScreen extends ConsumerStatefulWidget {
  final String reference;
  final String? status;

  const PaymentResultScreen({
    super.key,
    required this.reference,
    this.status,
  });

  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _errorMessage;
  double _amount = 0;
  String _currency = '';

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    try {
      final result = await _paymentService.verifyPayment(widget.reference);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = result.success;
          _amount = result.amount;
          _errorMessage = result.error;
        });

        if (result.success) {
          // Refresh wallet to show updated balance
          ref.read(walletNotifierProvider.notifier).refreshWallet();
          ref.read(transactionsNotifierProvider.notifier).refreshTransactions();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _errorMessage = e.toString();
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: _isLoading ? _buildLoading() : _buildResult(walletState),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXL),
          Text(
            'Verifying payment...',
            style: AppTextStyles.headlineSmall(),
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            'Please wait while we confirm your payment',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceXL),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reference: ',
                  style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                ),
                Text(
                  widget.reference,
                  style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(WalletState walletState) {
    final currencySymbol = walletState.currencySymbol;

    return Column(
      children: [
        const Spacer(),

        // Status Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: (_isSuccess ? AppColors.success : AppColors.error).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isSuccess ? Iconsax.tick_circle5 : Iconsax.close_circle5,
            color: _isSuccess ? AppColors.success : AppColors.error,
            size: 64,
          ),
        )
            .animate()
            .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 400.ms)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceXL),

        // Status Text
        Text(
          _isSuccess ? 'Payment Successful!' : 'Payment Failed',
          style: AppTextStyles.headlineLarge(),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.spaceMD),

        // Amount or Error
        if (_isSuccess && _amount > 0) ...[
          Text(
            '$currencySymbol${_formatAmount(_amount)}',
            style: AppTextStyles.displayMedium(color: AppColors.success),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            'has been added to your wallet',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),
        ] else if (!_isSuccess) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Text(
              _errorMessage ?? 'Something went wrong. Please try again.',
              style: AppTextStyles.bodyMedium(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms),
        ],

        const SizedBox(height: AppDimensions.spaceXL),

        // Reference
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reference',
                    style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                  ),
                  Flexible(
                    child: Text(
                      widget.reference,
                      style: AppTextStyles.bodySmall(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_isSuccess) ...[
                const SizedBox(height: AppDimensions.spaceSM),
                const Divider(color: AppColors.inputBorderDark),
                const SizedBox(height: AppDimensions.spaceSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Balance',
                      style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                    ),
                    Text(
                      '$currencySymbol${_formatAmount(walletState.balance)}',
                      style: AppTextStyles.bodyMedium(color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 400.ms),

        const Spacer(),

        // Done Button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.main),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
            ),
            child: Text(
              _isSuccess ? 'Done' : 'Go Back',
              style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0, delay: 600.ms, duration: 400.ms),

        if (!_isSuccess) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          TextButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _verifyPayment();
            },
            child: Text(
              'Try Again',
              style: AppTextStyles.labelMedium(color: AppColors.primary),
            ),
          ),
        ],

        const SizedBox(height: AppDimensions.spaceLG),
      ],
    );
  }
}
