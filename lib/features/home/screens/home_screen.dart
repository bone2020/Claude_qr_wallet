import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/transaction_tile.dart';

/// Home screen with balance, quick actions, and recent transactions
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _balanceHidden = false;

  // Mock data - replace with actual data from providers
  final double _balance = 125750.00;
  final String _currency = '₦';
  final String _userName = 'John';
  final String _walletId = 'QRW-8472-9103';

  final List<Map<String, dynamic>> _recentTransactions = [
    {
      'id': '1',
      'name': 'Sarah Johnson',
      'type': 'receive',
      'amount': 15000.0,
      'date': DateTime.now().subtract(const Duration(hours: 2)),
      'status': 'completed',
    },
    {
      'id': '2',
      'name': 'Netflix Subscription',
      'type': 'send',
      'amount': 4500.0,
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'status': 'completed',
    },
    {
      'id': '3',
      'name': 'Bank Deposit',
      'type': 'deposit',
      'amount': 50000.0,
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'status': 'completed',
    },
    {
      'id': '4',
      'name': 'Michael Obi',
      'type': 'send',
      'amount': 7500.0,
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'status': 'pending',
    },
  ];

  void _toggleBalanceVisibility() {
    setState(() => _balanceHidden = !_balanceHidden);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // TODO: Refresh balance and transactions
            await Future.delayed(const Duration(seconds: 1));
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
                _buildHeader()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.1, end: 0, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Balance Card
                BalanceCard(
                  balance: _balance,
                  currency: _currency,
                  isHidden: _balanceHidden,
                  walletId: _walletId,
                  onToggleVisibility: _toggleBalanceVisibility,
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXL),

                // Quick Actions
                _buildQuickActions()
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: AppDimensions.spaceXXL),

                // Recent Transactions
                _buildRecentTransactions()
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $_userName 👋',
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

  Widget _buildQuickActions() {
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

  Widget _buildRecentTransactions() {
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
        if (_recentTransactions.isEmpty)
          _buildEmptyTransactions()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentTransactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spaceSM),
            itemBuilder: (context, index) {
              final transaction = _recentTransactions[index];
              return TransactionTile(
                name: transaction['name'],
                type: transaction['type'],
                amount: transaction['amount'],
                currency: _currency,
                date: transaction['date'],
                status: transaction['status'],
                onTap: () {
                  context.push(
                    AppRoutes.transactionDetails,
                    extra: transaction['id'],
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
