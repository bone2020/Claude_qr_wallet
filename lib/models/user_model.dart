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
  final String walletId;

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

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profilePhotoUrl,
    required this.walletId,
    this.isVerified = false,
    this.kycCompleted = false,
    required this.createdAt,
    this.dateOfBirth,
    this.country,
    this.currency = 'NGN',
  });

  /// Create user from Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      walletId: json['walletId'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      kycCompleted: json['kycCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      country: json['country'] as String?,
      currency: json['currency'] as String? ?? 'NGN',
    );
  }

  /// Convert user to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
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
    };
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
    );
  }

  /// Get display name (first name)
  String get firstName => fullName.split(' ').first;

  /// Get initials for avatar
  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }
}
