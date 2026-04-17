import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'wallet_model.g.dart';

/// Wallet model representing user's wallet
/// All monetary amounts are stored in minor units (e.g. kobo, pesewas, cents)
@HiveType(typeId: 1)
class WalletModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String walletId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final int balance;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final int dailyLimit;

  @HiveField(9)
  final int monthlyLimit;

  @HiveField(10)
  final int dailySpent;

 @HiveField(11)
  final int monthlySpent;

  @HiveField(12)
  final int heldBalance;

  @HiveField(13)
  final int availableBalance;

  WalletModel({
    required this.id,
    required this.walletId,
    required this.userId,
    this.balance = 0,
    this.currency = 'NGN',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.dailyLimit = 50000000,
    this.monthlyLimit = 500000000,
    this.dailySpent = 0,
    this.monthlySpent = 0,
    this.heldBalance = 0,
    this.availableBalance = 0,
  });

  /// Create wallet from Firestore document
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      userId: json['userId'] as String,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] is Timestamp ? (json['createdAt'] as Timestamp).toDate() : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] is Timestamp ? (json['updatedAt'] as Timestamp).toDate() : DateTime.parse(json['updatedAt'] as String),
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 50000000,
      monthlyLimit: (json['monthlyLimit'] as num?)?.toInt() ?? 500000000,
      dailySpent: (json['dailySpent'] as num?)?.toInt() ?? 0,
      monthlySpent: (json['monthlySpent'] as num?)?.toInt() ?? 0,
      heldBalance: (json['heldBalance'] as num?)?.toInt() ?? 0,
      availableBalance: (json['availableBalance'] as num?)?.toInt() ?? ((json['balance'] as num?)?.toInt() ?? 0),
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
      'heldBalance': heldBalance,
      'availableBalance': availableBalance,
    };
  }

  /// Copy with new values
WalletModel copyWith({
    String? id,
    String? walletId,
    String? userId,
    int? balance,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? dailyLimit,
    int? monthlyLimit,
    int? dailySpent,
    int? monthlySpent,
    int? heldBalance,
    int? availableBalance,
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
      heldBalance: heldBalance ?? this.heldBalance,
      availableBalance: availableBalance ?? this.availableBalance,
    );
  }

  /// Check if user can make transaction of given amount (minor units)
  /// Check if user can make transaction of given amount (minor units).
  /// Uses availableBalance (not total balance) to prevent spending held funds.
  bool canTransact(int amount) {
    if (!isActive) return false;
    if (amount > availableBalance) return false;
    if (dailySpent + amount > dailyLimit) return false;
    if (monthlySpent + amount > monthlyLimit) return false;
    return true;
  }

  /// Get remaining daily limit (minor units)
  int get remainingDailyLimit => dailyLimit - dailySpent;

  /// Get remaining monthly limit (minor units)
  int get remainingMonthlyLimit => monthlyLimit - monthlySpent;

 /// Format minor units to display string (e.g. 150050 -> "1500.50")
  String get displayBalance => (balance / 100).toStringAsFixed(2);

  /// Format available balance for display
  String get displayAvailableBalance => (availableBalance / 100).toStringAsFixed(2);

  /// Format held balance for display
  String get displayHeldBalance => (heldBalance / 100).toStringAsFixed(2);

  /// Whether this wallet has any active holds
  bool get hasHolds => heldBalance > 0;

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
      'ZWG': 'Z\$',    // Zimbabwean Dollar
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
