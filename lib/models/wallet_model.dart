import 'package:hive/hive.dart';

part 'wallet_model.g.dart';

/// Wallet model representing user's wallet
@HiveType(typeId: 1)
class WalletModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String walletId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final double balance;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final double dailyLimit;

  @HiveField(9)
  final double monthlyLimit;

  @HiveField(10)
  final double dailySpent;

  @HiveField(11)
  final double monthlySpent;

  WalletModel({
    required this.id,
    required this.walletId,
    required this.userId,
    this.balance = 0.0,
    this.currency = 'NGN',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.dailyLimit = 500000.0,
    this.monthlyLimit = 5000000.0,
    this.dailySpent = 0.0,
    this.monthlySpent = 0.0,
  });

  /// Create wallet from Firestore document
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      userId: json['userId'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'NGN',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dailyLimit: (json['dailyLimit'] as num?)?.toDouble() ?? 500000.0,
      monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble() ?? 5000000.0,
      dailySpent: (json['dailySpent'] as num?)?.toDouble() ?? 0.0,
      monthlySpent: (json['monthlySpent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert wallet to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'userId': userId,
      'balance': balance,
      'currency': currency,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dailyLimit': dailyLimit,
      'monthlyLimit': monthlyLimit,
      'dailySpent': dailySpent,
      'monthlySpent': monthlySpent,
    };
  }

  /// Copy with new values
  WalletModel copyWith({
    String? id,
    String? walletId,
    String? userId,
    double? balance,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? dailyLimit,
    double? monthlyLimit,
    double? dailySpent,
    double? monthlySpent,
  }) {
    return WalletModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      dailySpent: dailySpent ?? this.dailySpent,
      monthlySpent: monthlySpent ?? this.monthlySpent,
    );
  }

  /// Check if user can make transaction of given amount
  bool canTransact(double amount) {
    if (!isActive) return false;
    if (amount > balance) return false;
    if (dailySpent + amount > dailyLimit) return false;
    if (monthlySpent + amount > monthlyLimit) return false;
    return true;
  }

  /// Get remaining daily limit
  double get remainingDailyLimit => dailyLimit - dailySpent;

  /// Get remaining monthly limit
  double get remainingMonthlyLimit => monthlyLimit - monthlySpent;

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
