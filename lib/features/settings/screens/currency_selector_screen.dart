import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/models/currency_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../providers/currency_provider.dart';

/// Screen for selecting preferred currency
class CurrencySelectorScreen extends ConsumerWidget {
  const CurrencySelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyNotifierProvider);
    final currentCurrency = currencyState.currency;

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
          'Select Currency',
          style: AppTextStyles.headlineSmall(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info text
            Padding(
              padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
              child: Text(
                'Choose your preferred currency for displaying balances and transactions.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: AppDimensions.spaceSM),

            // Currency list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPaddingH),
                itemCount: CurrencyService.supportedCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = CurrencyService.supportedCurrencies[index];
                  final isSelected = currency.code == currentCurrency.code;

                  return _CurrencyTile(
                    currency: currency,
                    isSelected: isSelected,
                    isLoading: currencyState.isLoading,
                    onTap: () => _selectCurrency(context, ref, currency),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
                      .slideX(begin: 0.1, end: 0, delay: Duration(milliseconds: 50 * index), duration: 300.ms);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCurrency(BuildContext context, WidgetRef ref, CurrencyModel currency) async {
    final notifier = ref.read(currencyNotifierProvider.notifier);
    final success = await notifier.setCurrency(currency);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency changed to ${currency.name}'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change currency'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _CurrencyTile extends StatelessWidget {
  final CurrencyModel currency;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _CurrencyTile({
    required this.currency,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.inputBorderDark,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Flag
                Text(
                  currency.flag,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: AppDimensions.spaceMD),

                // Currency details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency.name,
                        style: AppTextStyles.labelLarge(
                          color: isSelected ? AppColors.primary : AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currency.symbol} (${currency.code})',
                        style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
                ),

                // Selected indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
