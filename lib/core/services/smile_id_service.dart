import 'package:flutter/foundation.dart';
import 'package:smile_id/smile_id.dart';

/// Service for handling Smile ID verification operations
class SmileIDService {
  SmileIDService._();
  static final SmileIDService _instance = SmileIDService._();
  static SmileIDService get instance => _instance;

  /// Country-specific ID types configuration
  static const Map<String, List<Map<String, dynamic>>> countryIdTypes = {
    'NG': [
      {'value': 'NIN', 'label': 'National Identification Number (NIN)', 'requiresNumber': true, 'smileIdType': 'NIN_SLIP'},
      {'value': 'BVN', 'label': 'Bank Verification Number (BVN)', 'requiresNumber': true, 'smileIdType': 'BVN'},
      {'value': 'VOTERS_ID', 'label': "Voter's ID", 'requiresNumber': false, 'smileIdType': 'VOTER_ID'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'GH': [
      {'value': 'NATIONAL_ID', 'label': 'Ghana Card (National ID)', 'requiresNumber': false, 'smileIdType': 'GHANA_CARD'},
      {'value': 'SSNIT', 'label': 'SSNIT', 'requiresNumber': true, 'smileIdType': 'SSNIT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'KE': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
      {'value': 'ALIEN_ID', 'label': 'Alien ID', 'requiresNumber': false, 'smileIdType': 'ALIEN_CARD'},
    ],
    'ZA': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': true, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'CI': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
  };

  /// Countries that support phone number verification
  static const List<String> phoneVerificationCountries = ['NG', 'ZA'];

  /// Get ID types for a specific country
  List<Map<String, dynamic>> getIdTypesForCountry(String? countryCode) {
    if (countryCode == null) return countryIdTypes['NG']!;
    return countryIdTypes[countryCode.toUpperCase()] ?? countryIdTypes['NG']!;
  }

  /// Check if country supports phone verification
  bool supportsPhoneVerification(String? countryCode) {
    if (countryCode == null) return false;
    return phoneVerificationCountries.contains(countryCode.toUpperCase());
  }

  /// Get country code from phone number or user data
  String? extractCountryCode(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return null;
    
    // Map dial codes to country codes
    const dialCodeMap = {
      '+234': 'NG', // Nigeria
      '+233': 'GH', // Ghana
      '+254': 'KE', // Kenya
      '+27': 'ZA',  // South Africa
      '+225': 'CI', // Côte d'Ivoire
    };

    for (final entry in dialCodeMap.entries) {
      if (phoneNumber.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Generate a unique user ID for Smile ID jobs
  String generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generate a unique job ID for Smile ID jobs
  String generateJobId() {
    return 'job_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Result class for KYC verification
class KycVerificationResult {
  final bool success;
  final String? jobId;
  final String? resultCode;
  final String? resultText;
  final Map<String, dynamic>? userData;
  final String? error;

  KycVerificationResult({
    required this.success,
    this.jobId,
    this.resultCode,
    this.resultText,
    this.userData,
    this.error,
  });

  factory KycVerificationResult.success({
    required String jobId,
    String? resultCode,
    String? resultText,
    Map<String, dynamic>? userData,
  }) {
    return KycVerificationResult(
      success: true,
      jobId: jobId,
      resultCode: resultCode,
      resultText: resultText,
      userData: userData,
    );
  }

  factory KycVerificationResult.failure(String error) {
    return KycVerificationResult(
      success: false,
      error: error,
    );
  }
}
