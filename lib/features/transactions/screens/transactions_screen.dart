import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../home/widgets/transaction_tile.dart';

/// Transactions history screen
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TransactionModel> _getFilteredTransactions(
    List<TransactionModel> allTransactions,
    String filter,
  ) {
    switch (filter) {
      case 'sent':
        return allTransactions
            .where((t) => t.type == TransactionType.send)
            .toList();
      case 'received':
        return allTransactions
            .where((t) =>
                t.type == TransactionType.receive ||
                t.type == TransactionType.deposit)
            .toList();
      case 'pending':
        return allTransactions
            .where((t) => t.status == TransactionStatus.pending)
            .toList();
      default:
        return allTransactions;
    }
  }

  String _getTransactionTypeString(TransactionType type) {
    switch (type) {
      case TransactionType.send:
        return 'send';
      case TransactionType.receive:
        return 'receive';
      case TransactionType.deposit:
        return 'deposit';
      case TransactionType.withdraw:
        return 'withdraw';
    }
  }

  String _getTransactionStatusString(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'pending';
      case TransactionStatus.completed:
        return 'completed';
      case TransactionStatus.failed:
        return 'failed';
      case TransactionStatus.cancelled:
        return 'cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsState = ref.watch(transactionsNotifierProvider);
    final isLoading = transactionsState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text(AppStrings.transactions, style: AppTextStyles.headlineMedium()),
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTextStyles.labelMedium(),
          tabs: const [
            Tab(text: AppStrings.allTransactions),
            Tab(text: AppStrings.sent),
            Tab(text: AppStrings.received),
            Tab(text: AppStrings.pending),
          ],
        ),
      ),
      body: isLoading && transactionsState.transactions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList('all', transactionsState.transactions),
                _buildTransactionList('sent', transactionsState.transactions),
                _buildTransactionList('received', transactionsState.transactions),
                _buildTransactionList('pending', transactionsState.transactions),
              ],
            ),
    );
  }

  Widget _buildTransactionList(String filter, List<TransactionModel> allTransactions) {
    final transactions = _getFilteredTransactions(allTransactions, filter);
    final currencySymbol = ref.watch(currencyNotifierProvider).currency.symbol;
    final walletId = ref.watch(walletNotifierProvider).walletId;

    if (transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(transactionsNotifierProvider.notifier).refreshTransactions();
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(filter),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(transactionsNotifierProvider.notifier).refreshTransactions();
      },
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spaceSM),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final isCredit = transaction.isCredit(walletId);
          final counterpartyName = transaction.getCounterpartyName(walletId);

          return TransactionTile(
            name: counterpartyName,
            type: _getTransactionTypeString(transaction.type),
            amount: transaction.amount,
            currency: currencySymbol,
            date: transaction.createdAt,
            status: _getTransactionStatusString(transaction.status),
            onTap: () {
              context.push(
                AppRoutes.transactionDetails,
                extra: transaction.id,
              );
            },
          ).animate().fadeIn(
                delay: Duration(milliseconds: index * 50),
                duration: 300.ms,
              );
        },
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String message;
    switch (filter) {
      case 'sent':
        message = 'No sent transactions';
        break;
      case 'received':
        message = 'No received transactions';
        break;
      case 'pending':
        message = 'No pending transactions';
        break;
      default:
        message = AppStrings.noTransactions;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textTertiaryDark,
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Text(
            message,
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
