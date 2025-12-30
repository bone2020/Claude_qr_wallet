import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../home/widgets/transaction_tile.dart';

/// Transactions history screen
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final String _currency = '₦';

  // Mock data - replace with actual data from providers
  final List<Map<String, dynamic>> _allTransactions = [
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
    {
      'id': '5',
      'name': 'Amaka Store',
      'type': 'send',
      'amount': 12500.0,
      'date': DateTime.now().subtract(const Duration(days: 4)),
      'status': 'completed',
    },
    {
      'id': '6',
      'name': 'John Okafor',
      'type': 'receive',
      'amount': 25000.0,
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'status': 'completed',
    },
    {
      'id': '7',
      'name': 'Uber Ride',
      'type': 'send',
      'amount': 2500.0,
      'date': DateTime.now().subtract(const Duration(days: 6)),
      'status': 'failed',
    },
  ];

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

  List<Map<String, dynamic>> _getFilteredTransactions(String filter) {
    switch (filter) {
      case 'sent':
        return _allTransactions.where((t) => t['type'] == 'send').toList();
      case 'received':
        return _allTransactions
            .where((t) => t['type'] == 'receive' || t['type'] == 'deposit')
            .toList();
      case 'pending':
        return _allTransactions.where((t) => t['status'] == 'pending').toList();
      default:
        return _allTransactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text(AppStrings.transactions, style: AppTextStyles.headlineMedium()),
        automaticallyImplyLeading: false,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionList('all'),
          _buildTransactionList('sent'),
          _buildTransactionList('received'),
          _buildTransactionList('pending'),
        ],
      ),
    );
  }

  Widget _buildTransactionList(String filter) {
    final transactions = _getFilteredTransactions(filter);

    if (transactions.isEmpty) {
      return _buildEmptyState(filter);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh transactions
        await Future.delayed(const Duration(seconds: 1));
      },
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spaceSM),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
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
