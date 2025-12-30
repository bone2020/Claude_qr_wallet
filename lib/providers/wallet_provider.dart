import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/services.dart';
import '../models/models.dart';
import 'auth_provider.dart';

// ============================================================
// SERVICE PROVIDERS
// ============================================================

/// Wallet service provider
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

// ============================================================
// WALLET STATE
// ============================================================

/// Wallet state
class WalletState {
  final WalletModel? wallet;
  final bool isLoading;
  final String? error;
  final bool balanceHidden;

  WalletState({
    this.wallet,
    this.isLoading = false,
    this.error,
    this.balanceHidden = false,
  });

  WalletState copyWith({
    WalletModel? wallet,
    bool? isLoading,
    String? error,
    bool? balanceHidden,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      balanceHidden: balanceHidden ?? this.balanceHidden,
    );
  }

  double get balance => wallet?.balance ?? 0.0;
  String get walletId => wallet?.walletId ?? '';
  String get currency => wallet?.currency ?? 'NGN';
  String get currencySymbol => wallet?.currencySymbol ?? '₦';
}

/// Wallet notifier
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletService _walletService;
  final LocalStorageService _localStorage;

  WalletNotifier(this._walletService, this._localStorage) : super(WalletState()) {
    _init();
  }

  Future<void> _init() async {
    // Load cached wallet first
    final cachedWallet = await _localStorage.getWallet();
    if (cachedWallet != null) {
      state = state.copyWith(wallet: cachedWallet);
    }

    // Load balance hidden setting
    final balanceHidden = await _localStorage.getSetting<bool>(
      LocalStorageService.keyBalanceHidden,
      defaultValue: false,
    );
    state = state.copyWith(balanceHidden: balanceHidden ?? false);

    // Fetch fresh data
    await refreshWallet();
  }

  /// Refresh wallet data from server
  Future<void> refreshWallet() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final wallet = await _walletService.getWallet();
      if (wallet != null) {
        await _localStorage.saveWallet(wallet);
        state = state.copyWith(wallet: wallet, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: 'Wallet not found');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggle balance visibility
  Future<void> toggleBalanceVisibility() async {
    final newValue = !state.balanceHidden;
    state = state.copyWith(balanceHidden: newValue);
    await _localStorage.saveSetting(LocalStorageService.keyBalanceHidden, newValue);
  }

  /// Lookup recipient wallet
  Future<WalletLookupResult> lookupWallet(String walletId) async {
    return _walletService.lookupWallet(walletId);
  }

  /// Update wallet balance locally (for optimistic UI)
  void updateBalance(double newBalance) {
    if (state.wallet != null) {
      final updatedWallet = state.wallet!.copyWith(balance: newBalance);
      state = state.copyWith(wallet: updatedWallet);
      _localStorage.saveWallet(updatedWallet);
    }
  }
}

/// Wallet provider
final walletNotifierProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return WalletNotifier(walletService, localStorage);
});

/// Wallet stream provider (real-time updates)
final walletStreamProvider = StreamProvider<WalletModel?>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.watchWallet();
});

/// Current balance provider
final currentBalanceProvider = Provider<double>((ref) {
  return ref.watch(walletNotifierProvider).balance;
});

/// Balance hidden provider
final balanceHiddenProvider = Provider<bool>((ref) {
  return ref.watch(walletNotifierProvider).balanceHidden;
});

// ============================================================
// TRANSACTIONS STATE
// ============================================================

/// Transactions state
class TransactionsState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;
  final TransactionFilter filter;

  TransactionsState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
    this.filter = TransactionFilter.all,
  });

  TransactionsState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
    TransactionFilter? filter,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filter: filter ?? this.filter,
    );
  }

  List<TransactionModel> get filteredTransactions {
    switch (filter) {
      case TransactionFilter.all:
        return transactions;
      case TransactionFilter.sent:
        return transactions.where((t) => t.type == TransactionType.send).toList();
      case TransactionFilter.received:
        return transactions
            .where((t) =>
                t.type == TransactionType.receive ||
                t.type == TransactionType.deposit)
            .toList();
      case TransactionFilter.pending:
        return transactions
            .where((t) => t.status == TransactionStatus.pending)
            .toList();
    }
  }
}

enum TransactionFilter { all, sent, received, pending }

/// Transactions notifier
class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final WalletService _walletService;
  final LocalStorageService _localStorage;

  TransactionsNotifier(this._walletService, this._localStorage)
      : super(TransactionsState()) {
    _init();
  }

  Future<void> _init() async {
    // Load cached transactions first
    final cached = await _localStorage.getTransactions();
    if (cached.isNotEmpty) {
      state = state.copyWith(transactions: cached);
    }

    // Fetch fresh data
    await refreshTransactions();
  }

  /// Refresh transactions from server
  Future<void> refreshTransactions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final transactions = await _walletService.getTransactions(limit: 50);
      await _localStorage.saveTransactions(transactions);
      state = state.copyWith(transactions: transactions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set transaction filter
  void setFilter(TransactionFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Add new transaction to list
  void addTransaction(TransactionModel transaction) {
    final updated = [transaction, ...state.transactions];
    state = state.copyWith(transactions: updated);
    _localStorage.addTransaction(transaction);
  }
}

/// Transactions provider
final transactionsNotifierProvider =
    StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return TransactionsNotifier(walletService, localStorage);
});

/// Transactions stream provider (real-time updates)
final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.watchTransactions(limit: 50);
});

/// Recent transactions provider (for home screen)
final recentTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final transactions = ref.watch(transactionsNotifierProvider).transactions;
  return transactions.take(5).toList();
});

// ============================================================
// SEND MONEY PROVIDER
// ============================================================

/// Send money state
class SendMoneyState {
  final String? recipientWalletId;
  final String? recipientName;
  final double amount;
  final String? note;
  final bool isLoading;
  final bool isLookingUp;
  final String? error;
  final TransactionModel? completedTransaction;

  SendMoneyState({
    this.recipientWalletId,
    this.recipientName,
    this.amount = 0,
    this.note,
    this.isLoading = false,
    this.isLookingUp = false,
    this.error,
    this.completedTransaction,
  });

  SendMoneyState copyWith({
    String? recipientWalletId,
    String? recipientName,
    double? amount,
    String? note,
    bool? isLoading,
    bool? isLookingUp,
    String? error,
    TransactionModel? completedTransaction,
  }) {
    return SendMoneyState(
      recipientWalletId: recipientWalletId ?? this.recipientWalletId,
      recipientName: recipientName ?? this.recipientName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isLoading: isLoading ?? this.isLoading,
      isLookingUp: isLookingUp ?? this.isLookingUp,
      error: error,
      completedTransaction: completedTransaction ?? this.completedTransaction,
    );
  }

  double get fee => (amount * 0.01).clamp(10, 100);
  double get total => amount + fee;

  void clear() {}
}

/// Send money notifier
class SendMoneyNotifier extends StateNotifier<SendMoneyState> {
  final WalletService _walletService;

  SendMoneyNotifier(this._walletService) : super(SendMoneyState());

  /// Lookup recipient by wallet ID
  Future<void> lookupRecipient(String walletId) async {
    if (walletId.length < 10) {
      state = state.copyWith(recipientName: null);
      return;
    }

    state = state.copyWith(isLookingUp: true, error: null);

    try {
      final result = await _walletService.lookupWallet(walletId);
      if (result.found) {
        state = state.copyWith(
          recipientWalletId: result.walletId,
          recipientName: result.fullName,
          isLookingUp: false,
        );
      } else {
        state = state.copyWith(
          recipientName: null,
          isLookingUp: false,
          error: 'Wallet not found',
        );
      }
    } catch (e) {
      state = state.copyWith(isLookingUp: false, error: e.toString());
    }
  }

  /// Set recipient from QR scan
  void setRecipient({
    required String walletId,
    required String name,
  }) {
    state = state.copyWith(
      recipientWalletId: walletId,
      recipientName: name,
    );
  }

  /// Set amount
  void setAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  /// Set note
  void setNote(String? note) {
    state = state.copyWith(note: note);
  }

  /// Send money
  Future<TransactionResult> sendMoney() async {
    if (state.recipientWalletId == null) {
      return TransactionResult.failure('No recipient selected');
    }

    if (state.amount <= 0) {
      return TransactionResult.failure('Invalid amount');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _walletService.sendMoney(
        recipientWalletId: state.recipientWalletId!,
        amount: state.amount,
        note: state.note,
      );

      if (result.success) {
        state = state.copyWith(
          isLoading: false,
          completedTransaction: result.transaction,
        );
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }

      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return TransactionResult.failure(e.toString());
    }
  }

  /// Reset state
  void reset() {
    state = SendMoneyState();
  }
}

/// Send money provider
final sendMoneyNotifierProvider =
    StateNotifierProvider<SendMoneyNotifier, SendMoneyState>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  return SendMoneyNotifier(walletService);
});
