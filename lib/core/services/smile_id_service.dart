import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Smile ID verification operations
///
/// NOTE: Smile ID Flutter SDK uses WIDGETS for verification, not method calls.
/// Use the navigation methods to show verification screens.
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
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'GHANA_CARD'},
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
    if (countryCode == null) return countryIdTypes['GH']!;
    return countryIdTypes[countryCode.toUpperCase()] ?? countryIdTypes['GH']!;
  }

  /// Check if country supports phone verification
  bool supportsPhoneVerification(String? countryCode) {
    if (countryCode == null) return false;
    return phoneVerificationCountries.contains(countryCode.toUpperCase());
  }


  /// Check if country is supported by SmileID for KYC
  bool isCountrySupported(String? countryCode) {
    if (countryCode == null) return false;
    return countryIdTypes.containsKey(countryCode.toUpperCase());
  }
  /// Get country code from phone number
  String? extractCountryCode(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return null;

    const dialCodeMap = {
      '+234': 'NG',
      '+233': 'GH',
      '+254': 'KE',
      '+27': 'ZA',
      '+225': 'CI',
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

  /// Get the Smile ID document type string for a given ID type
  String getSmileIdDocumentType(String idType, String countryCode) {
    final idTypes = getIdTypesForCountry(countryCode);
    final type = idTypes.firstWhere(
      (t) => t['value'] == idType,
      orElse: () => {'smileIdType': idType},
    );
    return type['smileIdType'] ?? idType;
  }

  /// Validate ID number format
  IdValidationResult validateIdNumber(String idNumber, String idType, String countryCode) {
    if (idNumber.isEmpty) {
      return IdValidationResult(isValid: false, error: 'ID number is required');
    }

    switch (idType) {
      case 'NIN':
        if (idNumber.length != 11 || !RegExp(r'^\d{11}$').hasMatch(idNumber)) {
          return IdValidationResult(
            isValid: false,
            error: 'NIN must be exactly 11 digits',
            expectedFormat: '12345678901',
          );
        }
        break;
      case 'BVN':
        if (idNumber.length != 11 || !RegExp(r'^\d{11}$').hasMatch(idNumber)) {
          return IdValidationResult(
            isValid: false,
            error: 'BVN must be exactly 11 digits',
            expectedFormat: '12345678901',
          );
        }
        break;
      case 'SSNIT':
        if (!RegExp(r'^[A-Z]\d{12}$').hasMatch(idNumber.toUpperCase())) {
          return IdValidationResult(
            isValid: false,
            error: 'SSNIT must be 1 letter followed by 12 digits',
            expectedFormat: 'A123456789012',
          );
        }
        break;
      case 'NATIONAL_ID':
        if (countryCode == 'ZA') {
          if (idNumber.length != 13 || !RegExp(r'^\d{13}$').hasMatch(idNumber)) {
            return IdValidationResult(
              isValid: false,
              error: 'South African ID must be exactly 13 digits',
              expectedFormat: '1234567890123',
            );
          }
        }
        break;
    }

    return IdValidationResult(isValid: true);
  }

  // ============================================
  // PHONE VERIFICATION METHODS
  // ============================================

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Verify phone number belongs to ID holder via Cloud Function
  Future<PhoneVerificationResult> verifyPhoneNumber({
    required String phoneNumber,
    required String country,
    String? firstName,
    String? lastName,
    String? idNumber,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyPhoneNumber');
      final result = await callable.call<Map<String, dynamic>>({
        'phoneNumber': phoneNumber,
        'country': country,
        'firstName': firstName,
        'lastName': lastName,
        'idNumber': idNumber,
      });

      final data = result.data;

      return PhoneVerificationResult(
        success: data['success'] == true,
        verified: data['verified'] == true,
        resultText: data['resultText'] as String?,
        resultCode: data['resultCode'] as String?,
        match: data['match'] as String?,
        phoneInfo: data['phoneInfo'] as Map<String, dynamic>?,
        error: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('Phone verification error: $e');
      return PhoneVerificationResult(
        success: false,
        verified: false,
        error: e.toString(),
      );
    }
  }

  /// Check if phone verification is supported for a country
  Future<PhoneVerificationSupport> checkPhoneVerificationSupport(String country) async {
    try {
      final callable = _functions.httpsCallable('checkPhoneVerificationSupport');
      final result = await callable.call<Map<String, dynamic>>({
        'country': country,
      });

      final data = result.data;

      return PhoneVerificationSupport(
        supported: data['supported'] == true,
        country: data['country'] as String?,
        operators: (data['operators'] as List<dynamic>?)?.cast<String>(),
        message: data['message'] as String?,
      );
    } catch (e) {
      debugPrint('Check phone support error: $e');
      return PhoneVerificationSupport(
        supported: false,
        message: e.toString(),
      );
    }
  }
}

/// Result of ID number validation
class IdValidationResult {
  final bool isValid;
  final String? error;
  final String? expectedFormat;

  IdValidationResult({
    required this.isValid,
    this.error,
    this.expectedFormat,
  });
}

/// Result class for Smile ID verification
class SmileIDResult {
  final bool success;
  final String? jobId;
  final String? resultCode;
  final String? resultText;
  final String? selfieFile;
  final String? documentFrontFile;
  final String? documentBackFile;
  final Map<String, dynamic>? userData;
  final String? error;

  SmileIDResult({
    required this.success,
    this.jobId,
    this.resultCode,
    this.resultText,
    this.selfieFile,
    this.documentFrontFile,
    this.documentBackFile,
    this.userData,
    this.error,
  });

  factory SmileIDResult.fromJson(String jsonString) {
    try {
      // Parse the JSON result from Smile ID widget
      // The actual parsing depends on Smile ID's response format
      return SmileIDResult(
        success: true,
        resultText: jsonString,
      );
    } catch (e) {
      return SmileIDResult(
        success: false,
        error: 'Failed to parse result: $e',
      );
    }
  }

  factory SmileIDResult.success({
    String? jobId,
    String? resultCode,
    String? resultText,
    String? selfieFile,
    String? documentFrontFile,
    String? documentBackFile,
    Map<String, dynamic>? userData,
  }) {
    return SmileIDResult(
      success: true,
      jobId: jobId,
      resultCode: resultCode,
      resultText: resultText,
      selfieFile: selfieFile,
      documentFrontFile: documentFrontFile,
      documentBackFile: documentBackFile,
      userData: userData,
    );
  }

  factory SmileIDResult.failure(String error) {
    return SmileIDResult(
      success: false,
      error: error,
    );
  }
}

/// Result class for phone verification
class PhoneVerificationResult {
  final bool success;
  final bool verified;
  final String? resultText;
  final String? resultCode;
  final String? match;
  final Map<String, dynamic>? phoneInfo;
  final String? error;

  PhoneVerificationResult({
    required this.success,
    required this.verified,
    this.resultText,
    this.resultCode,
    this.match,
    this.phoneInfo,
    this.error,
  });

  /// Check if phone is verified and matches ID holder
  bool get isVerifiedMatch => verified && (match == 'Exact Match' || match == 'Partial Match');
}

/// Result class for phone verification support check
class PhoneVerificationSupport {
  final bool supported;
  final String? country;
  final List<String>? operators;
  final String? message;

  PhoneVerificationSupport({
    required this.supported,
    this.country,
    this.operators,
    this.message,
  });
}
