import 'dart:convert';
import 'dart:io';

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
      {'value': 'NIN', 'label': 'National Identification Number (NIN)', 'requiresNumber': true, 'smileIdType': 'NIN'},
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
    'UG': [
      {'value': 'UGANDA_NIN', 'label': 'National ID (NIN)', 'requiresNumber': true, 'smileIdType': 'NATIONAL_ID_NO_PHOTO'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': true, 'smileIdType': 'PASSPORT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': true, 'smileIdType': 'DRIVERS_LICENSE'},
    ],
    'ZM': [
      {'value': 'TPIN', 'label': 'Taxpayer PIN (TPIN)', 'requiresNumber': true, 'smileIdType': 'TPIN'},
    ],
    'ZW': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID_NO_PHOTO'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    // Non-database MoMo countries (SmileID Document Verification only — no government database check)
    'SL': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
    ],
    'LR': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
    ],
    'CM': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
    ],
    'BJ': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'BF': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'CD': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
    ],
    'CG': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'GQ': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'GA': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'GN': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'GW': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'ML': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'NE': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'RW': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'ST': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'SN': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'TD': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'TG': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'TZ': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
      {'value': 'DRIVERS_LICENSE', 'label': "Driver's License", 'requiresNumber': false, 'smileIdType': 'DRIVERS_LICENSE'},
    ],
    'SD': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'SS': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
      {'value': 'PASSPORT', 'label': 'International Passport', 'requiresNumber': false, 'smileIdType': 'PASSPORT'},
    ],
    'SZ': [
      {'value': 'NATIONAL_ID', 'label': 'National ID', 'requiresNumber': false, 'smileIdType': 'NATIONAL_ID'},
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

  /// Get country code from phone number
  String? extractCountryCode(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return null;

    const dialCodeMap = {
      // SmileID countries
      '+234': 'NG',
      '+233': 'GH',
      '+254': 'KE',
      '+27': 'ZA',
      '+225': 'CI',
      '+256': 'UG',
      '+260': 'ZM',
      '+263': 'ZW',
      // Non-SmileID MoMo countries
      '+232': 'SL',  // Sierra Leone
      '+231': 'LR',  // Liberia
      '+237': 'CM',  // Cameroon
      '+229': 'BJ',  // Benin
      '+226': 'BF',  // Burkina Faso
      '+243': 'CD',  // DR Congo
      '+242': 'CG',  // Congo
      '+240': 'GQ',  // Equatorial Guinea
      '+241': 'GA',  // Gabon
      '+224': 'GN',  // Guinea
      '+245': 'GW',  // Guinea-Bissau
      '+223': 'ML',  // Mali
      '+227': 'NE',  // Niger
      '+250': 'RW',  // Rwanda
      '+239': 'ST',  // São Tomé
      '+221': 'SN',  // Senegal
      '+235': 'TD',  // Chad
      '+228': 'TG',  // Togo
      '+255': 'TZ',  // Tanzania
      '+249': 'SD',  // Sudan
      '+211': 'SS',  // South Sudan
      '+268': 'SZ',  // Eswatini
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

    /// Parse Smile ID onSuccess result JSON to extract captured file paths.
  /// The SDK returns: {"selfieFile": "/path/...", "documentFrontFile": "/path/...", "documentBackFile": "/path/..."}
  SmileIdFiles? parseResultFiles(String? result) {
    if (result == null || result == 'already_enrolled') return null;

    try {
      final Map<String, dynamic> data = jsonDecode(result);
      return SmileIdFiles(
        selfie: data['selfieFile'] != null ? File(data['selfieFile'] as String) : null,
        documentFront: data['documentFrontFile'] != null ? File(data['documentFrontFile'] as String) : null,
        documentBack: data['documentBackFile'] != null ? File(data['documentBackFile'] as String) : null,
      );
    } catch (e) {
      debugPrint('Failed to parse Smile ID result files: $e');
      return null;
    }
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
      case 'UGANDA_NIN':
        if (!RegExp(r'^[A-Z0-9]{14}$', caseSensitive: false).hasMatch(idNumber)) {
          return IdValidationResult(
            isValid: false,
            error: 'Uganda NIN must be exactly 14 alphanumeric characters',
            expectedFormat: 'CM12345678901X',
          );
        }
        break;
      case 'TPIN':
        if (!RegExp(r'^\d{10}$').hasMatch(idNumber)) {
          return IdValidationResult(
            isValid: false,
            error: 'TPIN must be exactly 10 digits',
            expectedFormat: '1234567890',
          );
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

/// Parsed file paths from Smile ID verification result
class SmileIdFiles {
  final File? selfie;
  final File? documentFront;
  final File? documentBack;

  SmileIdFiles({
    this.selfie,
    this.documentFront,
    this.documentBack,
  });
}
