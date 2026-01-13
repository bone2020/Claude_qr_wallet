import 'package:cloud_firestore/cloud_firestore.dart';
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
      createdAt: json['createdAt'] is Timestamp ? (json['createdAt'] as Timestamp).toDate() : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] is Timestamp ? (json['updatedAt'] as Timestamp).toDate() : DateTime.parse(json['updatedAt'] as String),
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

  /// Get currency symbol for African and common currencies
  String get currencySymbol {
    const currencySymbols = {
      // African currencies
      'NGN': '₦',      // Nigerian Naira
      'GHS': 'GH₵',    // Ghanaian Cedi
      'KES': 'KSh',    // Kenyan Shilling
      'ZAR': 'R',      // South African Rand
      'EGP': 'E£',     // Egyptian Pound
      'TZS': 'TSh',    // Tanzanian Shilling
      'UGX': 'USh',    // Ugandan Shilling
      'RWF': 'FRw',    // Rwandan Franc
      'ETB': 'Br',     // Ethiopian Birr
      'MAD': 'DH',     // Moroccan Dirham
      'DZD': 'DA',     // Algerian Dinar
      'TND': 'DT',     // Tunisian Dinar
      'XAF': 'FCFA',   // Central African CFA Franc
      'XOF': 'CFA',    // West African CFA Franc
      'ZWL': 'Z\$',    // Zimbabwean Dollar
      'ZMW': 'ZK',     // Zambian Kwacha
      'BWP': 'P',      // Botswana Pula
      'NAD': 'N\$',    // Namibian Dollar
      'MZN': 'MT',     // Mozambican Metical
      'AOA': 'Kz',     // Angolan Kwanza
      'CDF': 'FC',     // Congolese Franc
      'SDG': 'SDG',    // Sudanese Pound
      'LYD': 'LD',     // Libyan Dinar
      'MUR': 'Rs',     // Mauritian Rupee
      'MWK': 'MK',     // Malawian Kwacha
      'SLL': 'Le',     // Sierra Leonean Leone
      'LRD': 'L\$',    // Liberian Dollar
      'GMD': 'D',      // Gambian Dalasi
      'GNF': 'FG',     // Guinean Franc
      'BIF': 'FBu',    // Burundian Franc
      'ERN': 'Nfk',    // Eritrean Nakfa
      'DJF': 'Fdj',    // Djiboutian Franc
      'SOS': 'Sh.So.', // Somali Shilling
      'SSP': 'SSP',    // South Sudanese Pound
      'LSL': 'L',      // Lesotho Loti
      'SZL': 'E',      // Swazi Lilangeni
      'MGA': 'Ar',     // Malagasy Ariary
      'SCR': 'Rs',     // Seychellois Rupee
      'KMF': 'CF',     // Comorian Franc
      'MRU': 'UM',     // Mauritanian Ouguiya
      'CVE': '\$',     // Cape Verdean Escudo
      'STN': 'Db',     // Sao Tome and Principe Dobra
      // Common international currencies
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
    };
    return currencySymbols[currency] ?? currency;
  }
}
