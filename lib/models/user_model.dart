import 'package:hive/hive.dart';

part 'user_model.g.dart';

/// User model representing app user data
@HiveType(typeId: 0)
class UserModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String phoneNumber;

  @HiveField(4)
  final String? profilePhotoUrl;

  @HiveField(5)
  final String? walletId;

  @HiveField(6)
  final bool isVerified;

  @HiveField(7)
  final bool kycCompleted;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime? dateOfBirth;

  @HiveField(10)
  final String? country;

  @HiveField(11)
  final String currency;

  @HiveField(12)
  final String? businessLogoUrl;

  @HiveField(13)
  final String? kycStatus;

  @HiveField(14)
  final bool accountBlocked;

  @HiveField(15)
  final String? accountBlockedBy;

  @HiveField(16)
  final String? legalName;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profilePhotoUrl,
    this.walletId,
    this.isVerified = false,
    this.kycCompleted = false,
    required this.createdAt,
    this.dateOfBirth,
    this.country,
    this.currency = 'NGN',
    this.businessLogoUrl,
    this.kycStatus,
    this.accountBlocked = false,
    this.accountBlockedBy,
    this.legalName,
  });

  /// Create user from Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      walletId: json['walletId'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      kycCompleted: json['kycCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      country: json['country'] as String?,
      currency: json['currency'] as String? ?? 'NGN',
      businessLogoUrl: json['businessLogoUrl'] as String?,
      kycStatus: json['kycStatus'] as String?,
      accountBlocked: json['accountBlocked'] as bool? ?? false,
      accountBlockedBy: json['accountBlockedBy'] as String?,
      legalName: json['legalName'] as String?,
    );
  }

  /// Convert user to JSON for Firestore
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePhotoUrl': profilePhotoUrl,
      'walletId': walletId,
      'isVerified': isVerified,
      'kycCompleted': kycCompleted,
      'createdAt': createdAt.toIso8601String(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'country': country,
      'currency': currency,
      'businessLogoUrl': businessLogoUrl,
      'accountBlocked': accountBlocked,
      'accountBlockedBy': accountBlockedBy,
      if (legalName != null) 'legalName': legalName,
    };
    // Only include kycStatus when non-null — Firestore security rules block
    // user document creation if the kycStatus key is present (server-only field)
    if (kycStatus != null) {
      json['kycStatus'] = kycStatus;
    }
    return json;
  }

  /// Copy with new values
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? walletId,
    bool? isVerified,
    bool? kycCompleted,
    DateTime? createdAt,
    DateTime? dateOfBirth,
    String? country,
    String? currency,
    String? businessLogoUrl,
    String? kycStatus,
    bool? accountBlocked,
    String? accountBlockedBy,
    String? legalName,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      walletId: walletId ?? this.walletId,
      isVerified: isVerified ?? this.isVerified,
      kycCompleted: kycCompleted ?? this.kycCompleted,
      createdAt: createdAt ?? this.createdAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      businessLogoUrl: businessLogoUrl ?? this.businessLogoUrl,
      kycStatus: kycStatus ?? this.kycStatus,
      accountBlocked: accountBlocked ?? this.accountBlocked,
      accountBlockedBy: accountBlockedBy ?? this.accountBlockedBy,
      legalName: legalName ?? this.legalName,
    );
  }

  /// Get display name — prefers legalName (title-cased) over fullName
  String get displayName => legalName != null ? _titleCase(legalName!) : fullName;

  /// Title-case a name: "JOE LEO DOE" → "Joe Leo Doe"
  static String _titleCase(String name) {
    if (name.isEmpty) return name;
    return name.trim().toLowerCase().replaceAllMapped(
      RegExp(r"(?:^|\s|[-'])\S"),
      (match) => match.group(0)!.toUpperCase(),
    );
  }

  /// Mask name for privacy: "Joe Leo Doe" → "Joe D."
  String get maskedName {
    final name = displayName;
    if (name.isEmpty) return 'User';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0];
    final firstName = parts[0];
    final lastInitial = parts.last[0].toUpperCase();
    return '$firstName $lastInitial.';
  }

  /// Get first name from display name
  String get firstName {
    final name = displayName;
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  /// Get last name from display name
  String get lastName {
    final name = displayName;
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    return parts.length > 1 ? parts.skip(1).join(' ') : '';
  }

  /// Get initials for avatar from display name
  String get initials {
    final name = displayName;
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '??';
  }

  /// Whether the user has completed KYC and name is locked
  bool get isNameLocked => kycStatus == 'verified' && legalName != null;
}
