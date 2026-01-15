import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Send money to another wallet (via secure Cloud Function)
  Future<TransactionResult> sendMoney({
    required String recipientWalletId,
    required double amount,
    String? note,
  }) async {
    if (_userId == null) {
      return TransactionResult.failure('User not authenticated');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendMoney');
      final result = await callable.call<Map<String, dynamic>>({
        'recipientWalletId': recipientWalletId,
        'amount': amount,
        'note': note ?? '',
      });

      final data = result.data;

      if (data['success'] == true) {
        // Create a local transaction model for the UI
        final transaction = TransactionModel(
          id: data['transactionId'] as String,
          senderWalletId: '',
          receiverWalletId: recipientWalletId,
          senderName: '',
          receiverName: data['recipientName'] as String? ?? 'Unknown',
          amount: amount,
          fee: (data['fee'] as num?)?.toDouble() ?? 0,
          currency: 'GHS',
          type: TransactionType.send,
          status: TransactionStatus.completed,
          note: note,
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
          reference: data['transactionId'] as String,
        );

        return TransactionResult.success(transaction);
      } else {
        return TransactionResult.failure(data['error'] as String? ?? 'Transaction failed');
      }
    } on FirebaseFunctionsException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'Please log in to send money';
          break;
        case 'not-found':
          errorMessage = 'Recipient wallet not found';
          break;
        case 'failed-precondition':
          errorMessage = 'Insufficient balance';
          break;
        case 'invalid-argument':
          errorMessage = e.message ?? 'Invalid request';
          break;
        default:
          errorMessage = e.message ?? 'Transaction failed';
      }
      return TransactionResult.failure(errorMessage);
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

  /// Generate unique transaction ID (cryptographically secure)
  String _generateTransactionId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));
    final randomPart = base64Url.encode(randomBytes).replaceAll('=', '');
    return 'TXN_${timestamp}_$randomPart';
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
