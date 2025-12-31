import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/transaction_tile.dart';

/// Home screen with balance, quick actions, and recent transactions
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getTransactionType(dynamic type) {
    if (type is String) return type;
    return type.toString().split('.').last;
  }

  String _getTransactionStatus(dynamic status) {
    if (status is String) return status;
    return status.toString().split('.').last;
  }

  /// Safely extract first name from full name
  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'User';
    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts.first : 'User';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get real data from providers
    final user = ref.watch(currentUserProvider);
    final walletState = ref.watch(walletNotifierProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);

    final userName = _getFirstName(user?.fullName);
    final balance = walletState.balance;
    final currency = walletState.currencySymbol;
    final walletId = walletState.walletId;
    final balanceHidden = walletState.balanceHidden;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Refresh balance and transactions from Firebase
            await ref.read(walletNotifierProvider.notifier).refreshWallet();
            await ref.read(transactionsNotifierProvider.notifier).refreshTransactions();
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spaceSM),

                // Header with greeting
                _buildHeader(context, userName)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.1, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Balance Card
                BalanceCard(
                  balance: balance,
                  currency: currency,
                  isHidden: balanceHidden,
                  walletId: walletId,
                  onToggleVisibility: () {
                    ref.read(walletNotifierProvider.notifier).toggleBalanceVisibility();
                  },
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Quick Actions
                _buildQuickActions(context)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Recent Transactions
                _buildRecentTransactions(context, recentTransactions, currency)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceLG),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $userName 👋',
              style: AppTextStyles.headlineLarge(),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome back',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            // TODO: Navigate to notifications
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.inputBorderDark),
            ),
            child: const Icon(
              Iconsax.notification,
              color: AppColors.textPrimaryDark,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        QuickActionButton(
          icon: Iconsax.send_2,
          label: AppStrings.send,
          onTap: () => context.push(AppRoutes.sendMoney),
        ),
        QuickActionButton(
          icon: Iconsax.receive_square_2,
          label: AppStrings.receive,
          onTap: () => context.push(AppRoutes.receiveMoney),
        ),
        QuickActionButton(
          icon: Iconsax.add_circle,
          label: AppStrings.addMoney,
          onTap: () {
            // TODO: Navigate to add money screen
          },
        ),
        QuickActionButton(
          icon: Iconsax.money_send,
          label: AppStrings.withdraw,
          onTap: () {
            // TODO: Navigate to withdraw screen
          },
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(BuildContext context, List<dynamic> transactions, String currency) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.recentTransactions,
              style: AppTextStyles.headlineSmall(),
            ),
            TextButton(
              onPressed: () {
                // Navigate to transactions tab
              },
              child: Text(
                AppStrings.viewAll,
                style: AppTextStyles.bodyMedium(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        if (transactions.isEmpty)
          _buildEmptyTransactions()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spaceSM),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionTile(
                name: transaction.recipientName ?? transaction.senderName ?? 'Unknown',
                type: _getTransactionType(transaction.type),
                amount: transaction.amount,
                currency: currency,
                date: transaction.createdAt,
                status: _getTransactionStatus(transaction.status),
                onTap: () {
                  context.push(
                    AppRoutes.transactionDetails,
                    extra: transaction.id,
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceXXL),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Column(
        children: [
          Icon(
            Iconsax.receipt_text,
            size: 48,
            color: AppColors.textTertiaryDark,
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Text(
            AppStrings.noTransactions,
            style: AppTextStyles.bodyLarge(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            AppStrings.noTransactionsSubtitle,
            style: AppTextStyles.bodySmall(color: AppColors.textTertiaryDark),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
