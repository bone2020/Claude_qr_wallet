import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import '../../models/models.dart';
import 'exchange_rate_service.dart';

/// Wallet service handling all wallet and transaction operations
class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // ============================================================
  // WALLET OPERATIONS
  // ============================================================

  /// Get current user's wallet
  Future<WalletModel?> getWallet() async {
    if (_userId == null) return null;

    try {
      final doc = await _firestore.collection('wallets').doc(_userId).get();
      if (!doc.exists) return null;
      return WalletModel.fromJson(doc.data()!);
    } catch (e) {
      throw WalletException('Failed to fetch wallet: $e');
    }
  }

  /// Stream of wallet updates (for real-time balance)
  Stream<WalletModel?> watchWallet() {
    if (_userId == null) return Stream.value(null);

    return _firestore
        .collection('wallets')
        .doc(_userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return WalletModel.fromJson(doc.data()!);
    });
  }

  /// Get wallet by wallet ID (for recipient lookup)
  Future<WalletLookupResult> lookupWallet(String walletId) async {
    try {
      final query = await _firestore
          .collection('wallets')
          .where('walletId', isEqualTo: walletId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return WalletLookupResult.notFound();
      }

      final walletDoc = query.docs.first;
      final wallet = WalletModel.fromJson(walletDoc.data());

      // Get user details
      final userDoc = await _firestore
          .collection('users')
          .doc(wallet.userId)
          .get();

      if (!userDoc.exists) {
        return WalletLookupResult.notFound();
      }

      final user = UserModel.fromJson(userDoc.data()!);
      final currency = wallet.currency;

      return WalletLookupResult.found(
        walletId: wallet.walletId,
        userId: wallet.userId,
        fullName: user.fullName,
        profilePhotoUrl: user.profilePhotoUrl,
        currency: currency,
        currencySymbol: _getCurrencySymbol(currency),
      );
    } catch (e) {
      throw WalletException('Failed to lookup wallet: $e');
    }
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'NGN': '₦',
      'GHS': 'GH₵',
      'KES': 'KSh',
      'ZAR': 'R',
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
    };
    return symbols[currency] ?? currency;
  }

  // ============================================================
  // TRANSACTION OPERATIONS
  // ============================================================

  /// Send money to another wallet
  Future<TransactionResult> sendMoney({
    required String recipientWalletId,
    required double amount,
    String? note,
  }) async {
    if (_userId == null) {
      return TransactionResult.failure('User not authenticated');
    }

    try {
      // Get sender's wallet
      final senderWalletDoc = await _firestore
          .collection('wallets')
          .doc(_userId)
          .get();

      if (!senderWalletDoc.exists) {
        return TransactionResult.failure('Sender wallet not found');
      }

      final senderWallet = WalletModel.fromJson(senderWalletDoc.data()!);

      // Check balance
      if (senderWallet.balance < amount) {
        return TransactionResult.failure('Insufficient balance');
      }

      // Check daily limit
      if (!senderWallet.canTransact(amount)) {
        return TransactionResult.failure('Transaction limit exceeded');
      }

      // Get recipient's wallet
      final recipientQuery = await _firestore
          .collection('wallets')
          .where('walletId', isEqualTo: recipientWalletId)
          .limit(1)
          .get();

      if (recipientQuery.docs.isEmpty) {
        return TransactionResult.failure('Recipient wallet not found');
      }

      final recipientWalletDoc = recipientQuery.docs.first;
      final recipientWallet = WalletModel.fromJson(recipientWalletDoc.data());

      // Prevent self-transfer
      if (recipientWallet.userId == _userId) {
        return TransactionResult.failure('Cannot send money to yourself');
      }

      // Get user names for transaction record
      final senderUserDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();
      final recipientUserDoc = await _firestore
          .collection('users')
          .doc(recipientWallet.userId)
          .get();

      final senderName = senderUserDoc.exists
          ? UserModel.fromJson(senderUserDoc.data()!).fullName
          : 'Unknown';
      final recipientName = recipientUserDoc.exists
          ? UserModel.fromJson(recipientUserDoc.data()!).fullName
          : 'Unknown';

      // Calculate fee (1% with min 10, max 100 in sender's currency)
      final fee = (amount * 0.01).clamp(10.0, 100.0);

      // Get currencies
      final senderCurrency = senderWallet.currency;
      final recipientCurrency = recipientWallet.currency;

      // Calculate conversion if needed
      double amountToCredit = amount;
      double? exchangeRate;
      double? convertedAmount;

      if (ExchangeRateService.needsConversion(senderCurrency, recipientCurrency)) {
        exchangeRate = ExchangeRateService.getExchangeRate(
          fromCurrency: senderCurrency,
          toCurrency: recipientCurrency,
        );
        convertedAmount = ExchangeRateService.convert(
          amount: amount,
          fromCurrency: senderCurrency,
          toCurrency: recipientCurrency,
        );
        amountToCredit = convertedAmount;
      }

      // Create transaction record
      final transactionId = _generateTransactionId();
      final now = DateTime.now();

      final transaction = TransactionModel(
        id: transactionId,
        senderWalletId: senderWallet.walletId,
        receiverWalletId: recipientWalletId,
        senderName: senderName,
        receiverName: recipientName,
        amount: amount,
        fee: fee,
        currency: senderCurrency,
        type: TransactionType.send,
        status: TransactionStatus.completed,
        note: note,
        createdAt: now,
        completedAt: now,
        reference: 'TXN-${now.millisecondsSinceEpoch}',
        senderCurrency: senderCurrency,
        receiverCurrency: recipientCurrency,
        convertedAmount: convertedAmount,
        exchangeRate: exchangeRate,
      );

      // Execute transaction in a batch
      final batch = _firestore.batch();

      // Deduct from sender (amount + fee in sender's currency)
      batch.update(
        _firestore.collection('wallets').doc(_userId),
        {
          'balance': FieldValue.increment(-(amount + fee)),
          'dailySpent': FieldValue.increment(amount + fee),
          'monthlySpent': FieldValue.increment(amount + fee),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Add to recipient (converted amount in recipient's currency)
      batch.update(
        recipientWalletDoc.reference,
        {
          'balance': FieldValue.increment(amountToCredit),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Create transaction record for sender
      batch.set(
        _firestore
            .collection('users')
            .doc(_userId)
            .collection('transactions')
            .doc(transactionId),
        transaction.toJson(),
      );

      // Create transaction record for recipient (as receive)
      final recipientTransaction = transaction.copyWith(
        type: TransactionType.receive,
      );
      batch.set(
        _firestore
            .collection('users')
            .doc(recipientWallet.userId)
            .collection('transactions')
            .doc(transactionId),
        recipientTransaction.toJson(),
      );

      // Commit transaction
      await batch.commit();

      return TransactionResult.success(transaction);
    } catch (e) {
      return TransactionResult.failure('Transaction failed: $e');
    }
  }

  /// Add money to wallet (from bank/card via Paystack)
  Future<TransactionResult> addMoney({
    required double amount,
    required String paymentReference,
    String? bankName,
  }) async {
    if (_userId == null) {
      return TransactionResult.failure('User not authenticated');
    }

    try {
      final walletDoc = await _firestore.collection('wallets').doc(_userId).get();
      if (!walletDoc.exists) {
        return TransactionResult.failure('Wallet not found');
      }

      final wallet = WalletModel.fromJson(walletDoc.data()!);

      final userDoc = await _firestore.collection('users').doc(_userId).get();
      final userName = userDoc.exists
          ? UserModel.fromJson(userDoc.data()!).fullName
          : 'Unknown';

      final transactionId = _generateTransactionId();
      final now = DateTime.now();

      final transaction = TransactionModel(
        id: transactionId,
        senderWalletId: bankName ?? 'Bank Account',
        receiverWalletId: wallet.walletId,
        senderName: bankName ?? 'Bank Transfer',
        receiverName: userName,
        amount: amount,
        fee: 0,
        currency: wallet.currency,
        type: TransactionType.deposit,
        status: TransactionStatus.completed,
        note: 'Deposit via ${bankName ?? "Bank"}',
        createdAt: now,
        completedAt: now,
        reference: paymentReference,
      );

      final batch = _firestore.batch();

      // Add to wallet
      batch.update(
        _firestore.collection('wallets').doc(_userId),
        {
          'balance': FieldValue.increment(amount),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Create transaction record
      batch.set(
        _firestore
            .collection('users')
            .doc(_userId)
            .collection('transactions')
            .doc(transactionId),
        transaction.toJson(),
      );

      await batch.commit();

      return TransactionResult.success(transaction);
    } catch (e) {
      return TransactionResult.failure('Deposit failed: $e');
    }
  }

  // ============================================================
  // TRANSACTION HISTORY
  // ============================================================

  /// Get transaction history
  Future<List<TransactionModel>> getTransactions({
    int limit = 20,
    TransactionType? type,
    TransactionStatus? status,
  }) async {
    if (_userId == null) return [];

    try {
      Query query = _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw WalletException('Failed to fetch transactions: $e');
    }
  }

  /// Stream of transactions (real-time updates)
  Stream<List<TransactionModel>> watchTransactions({int limit = 20}) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson(doc.data()))
            .toList());
  }

  /// Get single transaction by ID
  Future<TransactionModel?> getTransaction(String transactionId) async {
    if (_userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (!doc.exists) return null;
      return TransactionModel.fromJson(doc.data()!);
    } catch (e) {
      throw WalletException('Failed to fetch transaction: $e');
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Generate unique transaction ID
  String _generateTransactionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(9999).toString().padLeft(4, '0');
    return 'TXN$timestamp$randomPart';
  }
}

/// Result wrapper for wallet lookup
class WalletLookupResult {
  final bool found;
  final String? walletId;
  final String? userId;
  final String? fullName;
  final String? profilePhotoUrl;
  final String? currency;
  final String? currencySymbol;

  WalletLookupResult._({
    required this.found,
    this.walletId,
    this.userId,
    this.fullName,
    this.profilePhotoUrl,
    this.currency,
    this.currencySymbol,
  });

  factory WalletLookupResult.found({
    required String walletId,
    required String userId,
    required String fullName,
    String? profilePhotoUrl,
    required String currency,
    required String currencySymbol,
  }) {
    return WalletLookupResult._(
      found: true,
      walletId: walletId,
      userId: userId,
      fullName: fullName,
      profilePhotoUrl: profilePhotoUrl,
      currency: currency,
      currencySymbol: currencySymbol,
    );
  }

  factory WalletLookupResult.notFound() {
    return WalletLookupResult._(found: false);
  }
}

/// Result wrapper for transactions
class TransactionResult {
  final bool success;
  final TransactionModel? transaction;
  final String? error;

  TransactionResult._({
    required this.success,
    this.transaction,
    this.error,
  });

  factory TransactionResult.success(TransactionModel transaction) {
    return TransactionResult._(success: true, transaction: transaction);
  }

  factory TransactionResult.failure(String error) {
    return TransactionResult._(success: false, error: error);
  }
}

/// Custom exception for wallet operations
class WalletException implements Exception {
  final String message;
  WalletException(this.message);

  @override
  String toString() => message;
}
