import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

/// Transaction types
@HiveType(typeId: 3)
enum TransactionType {
  @HiveField(0)
  send,
  @HiveField(1)
  receive,
  @HiveField(2)
  deposit,
  @HiveField(3)
  withdraw,
}

/// Transaction status
@HiveType(typeId: 4)
enum TransactionStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  completed,
  @HiveField(2)
  failed,
  @HiveField(3)
  cancelled,
}

/// Transaction model representing a single transaction
@HiveType(typeId: 2)
class TransactionModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderWalletId;

  @HiveField(2)
  final String receiverWalletId;

  @HiveField(3)
  final String? senderName;

  @HiveField(4)
  final String? receiverName;

  @HiveField(5)
  final double amount;

  @HiveField(6)
  final double fee;

  @HiveField(7)
  final String currency;

  @HiveField(8)
  final TransactionType type;

  @HiveField(9)
  final TransactionStatus status;

  @HiveField(10)
  final String? note;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime? completedAt;

  @HiveField(13)
  final String? reference;

  @HiveField(14)
  final String? failureReason;

  @HiveField(15)
  final String? senderCurrency;

  @HiveField(16)
  final String? receiverCurrency;

  @HiveField(17)
  final double? convertedAmount;

  @HiveField(18)
  final double? exchangeRate;

  @HiveField(19)
  final String? method;

  TransactionModel({
    required this.id,
    required this.senderWalletId,
    required this.receiverWalletId,
    this.senderName,
    this.receiverName,
    required this.amount,
    this.fee = 0.0,
    this.currency = 'NGN',
    required this.type,
    this.status = TransactionStatus.pending,
    this.note,
    required this.createdAt,
    this.completedAt,
    this.reference,
    this.failureReason,
    this.senderCurrency,
    this.receiverCurrency,
    this.convertedAmount,
    this.exchangeRate,
    this.method,
  });

  /// Create transaction from Firestore document
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Handle Firestore Timestamp or String for createdAt
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return TransactionModel(
      id: json['id'] as String? ?? '',
      senderWalletId: json['senderWalletId'] as String? ?? '',
      receiverWalletId: json['receiverWalletId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      receiverName: json['receiverName'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'GHS',
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.deposit,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      note: json['note'] as String? ?? json['description'] as String?,
      createdAt: parseDateTime(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? parseDateTime(json['completedAt'])
          : null,
      reference: json['reference'] as String?,
      failureReason: json['failureReason'] as String?,
      senderCurrency: json['senderCurrency'] as String?,
      receiverCurrency: json['receiverCurrency'] as String?,
      convertedAmount: (json['convertedAmount'] as num?)?.toDouble(),
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      method: json['method'] as String?,
    );
  }

  /// Convert transaction to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderWalletId': senderWalletId,
      'receiverWalletId': receiverWalletId,
      'senderName': senderName,
      'receiverName': receiverName,
      'amount': amount,
      'fee': fee,
      'currency': currency,
      'type': type.name,
      'status': status.name,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'reference': reference,
      'failureReason': failureReason,
      'senderCurrency': senderCurrency,
      'receiverCurrency': receiverCurrency,
      'convertedAmount': convertedAmount,
      'exchangeRate': exchangeRate,
      'method': method,
    };
  }

  /// Copy with new values
  TransactionModel copyWith({
    String? id,
    String? senderWalletId,
    String? receiverWalletId,
    String? senderName,
    String? receiverName,
    double? amount,
    double? fee,
    String? currency,
    TransactionType? type,
    TransactionStatus? status,
    String? note,
    DateTime? createdAt,
    DateTime? completedAt,
    String? reference,
    String? failureReason,
    String? senderCurrency,
    String? receiverCurrency,
    double? convertedAmount,
    double? exchangeRate,
    String? method,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      senderWalletId: senderWalletId ?? this.senderWalletId,
      receiverWalletId: receiverWalletId ?? this.receiverWalletId,
      senderName: senderName ?? this.senderName,
      receiverName: receiverName ?? this.receiverName,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      reference: reference ?? this.reference,
      failureReason: failureReason ?? this.failureReason,
      senderCurrency: senderCurrency ?? this.senderCurrency,
      receiverCurrency: receiverCurrency ?? this.receiverCurrency,
      convertedAmount: convertedAmount ?? this.convertedAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      method: method ?? this.method,
    );
  }

  /// Get total amount including fee
  double get totalAmount => amount + fee;

  /// Check if transaction is a credit (money received)
  bool isCredit(String currentWalletId) {
    return receiverWalletId == currentWalletId;
  }

  /// Get display amount with sign
  String displayAmount(String currentWalletId, String symbol) {
    final isReceived = isCredit(currentWalletId);
    final sign = isReceived ? '+' : '-';
    return '$sign$symbol${amount.toStringAsFixed(2)}';
  }

  /// Get counterparty name or method for deposits/withdrawals
  String getCounterpartyName(String currentWalletId) {
    // For deposits and withdrawals, show method or type name
    if (type == TransactionType.deposit) {
      return method ?? 'Deposit';
    }
    if (type == TransactionType.withdraw) {
      return method ?? 'Withdrawal';
    }
    // For send/receive, use counterparty name
    if (isCredit(currentWalletId)) {
      return senderName ?? 'Unknown';
    }
    return receiverName ?? 'Unknown';
  }

  /// Get transaction title based on type
  String get title {
    switch (type) {
      case TransactionType.send:
        return 'Sent to ${receiverName ?? "Wallet"}';
      case TransactionType.receive:
        return 'Received from ${senderName ?? "Wallet"}';
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdraw:
        return 'Withdrawal';
    }
  }

  /// Get currency symbol
  String get currencySymbol {
    switch (currency) {
      case 'NGN':
        return '₦';
      case 'GHS':
        return 'GH₵';
      case 'KES':
        return 'KSh';
      case 'ZAR':
        return 'R';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency;
    }
  }
}
