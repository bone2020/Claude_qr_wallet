import 'package:flutter/foundation.dart';
import 'package:smile_id/smile_id.dart';

import '../utils/error_handler.dart';

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

    // Map dial codes to country codes
    const dialCodeMap = {
      '+234': 'NG', // Nigeria
      '+233': 'GH', // Ghana
      '+254': 'KE', // Kenya
      '+27': 'ZA',  // South Africa
      '+225': 'CI', // Ivory Coast
      '+250': 'RW', // Rwanda
      '+255': 'TZ', // Tanzania
      '+20': 'EG',  // Egypt
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

  // ============================================================
  // ID NUMBER VALIDATION
  // ============================================================

  /// Validation rules for different ID types
  static const Map<String, Map<String, dynamic>> idValidationRules = {
    'NIN': {
      'pattern': r'^\d{11}$',
      'length': 11,
      'description': '11 digits',
      'example': '12345678901',
    },
    'BVN': {
      'pattern': r'^\d{11}$',
      'length': 11,
      'description': '11 digits',
      'example': '12345678901',
    },
    'SSNIT': {
      'pattern': r'^[A-Z]{1}\d{12}$',
      'length': 13,
      'description': '1 letter followed by 12 digits',
      'example': 'A123456789012',
    },
    'NATIONAL_ID_ZA': {
      'pattern': r'^\d{13}$',
      'length': 13,
      'description': '13 digits',
      'example': '1234567890123',
    },
  };

  /// Validate an ID number based on type and country
  IdValidationResult validateIdNumber(String idNumber, String idType, String countryCode) {
    final cleanedNumber = idNumber.trim().toUpperCase();

    if (cleanedNumber.isEmpty) {
      return IdValidationResult(
        isValid: false,
        error: 'ID number is required',
      );
    }

    // Get validation key based on ID type and country
    String validationKey = idType;
    if (idType == 'NATIONAL_ID' && countryCode == 'ZA') {
      validationKey = 'NATIONAL_ID_ZA';
    }

    final rules = idValidationRules[validationKey];
    if (rules == null) {
      // No specific validation rules, just check it's not empty
      return IdValidationResult(isValid: true);
    }

    final pattern = RegExp(rules['pattern'] as String);
    final expectedLength = rules['length'] as int;
    final description = rules['description'] as String;

    if (cleanedNumber.length != expectedLength) {
      return IdValidationResult(
        isValid: false,
        error: 'Must be exactly $expectedLength characters ($description)',
        expectedFormat: description,
      );
    }

    if (!pattern.hasMatch(cleanedNumber)) {
      return IdValidationResult(
        isValid: false,
        error: 'Invalid format. Expected: $description',
        expectedFormat: description,
      );
    }

    // Additional validation for South African ID (Luhn check on first 10 digits)
    if (validationKey == 'NATIONAL_ID_ZA') {
      if (!_validateSouthAfricanId(cleanedNumber)) {
        return IdValidationResult(
          isValid: false,
          error: 'Invalid South African ID number',
          expectedFormat: description,
        );
      }
    }

    return IdValidationResult(isValid: true);
  }

  /// Validate South African ID number using Luhn algorithm
  bool _validateSouthAfricanId(String idNumber) {
    if (idNumber.length != 13) return false;

    // Extract date of birth (first 6 digits: YYMMDD)
    final year = int.tryParse(idNumber.substring(0, 2));
    final month = int.tryParse(idNumber.substring(2, 4));
    final day = int.tryParse(idNumber.substring(4, 6));

    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    // Luhn algorithm validation
    int sum = 0;
    for (int i = 0; i < 13; i++) {
      int digit = int.parse(idNumber[i]);
      if (i % 2 == 1) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }

    return sum % 10 == 0;
  }

  /// Get the expected format description for an ID type
  String getIdFormatHint(String idType, String countryCode) {
    String validationKey = idType;
    if (idType == 'NATIONAL_ID' && countryCode == 'ZA') {
      validationKey = 'NATIONAL_ID_ZA';
    }

    final rules = idValidationRules[validationKey];
    if (rules == null) {
      return 'Enter your ID number as shown on your document';
    }

    final description = rules['description'] as String;
    final example = rules['example'] as String;
    return '$description (e.g., $example)';
  }

  // ============================================================
  // SMILE ID VERIFICATION METHODS
  // ============================================================

  /// Perform Smart Selfie Enrollment (captures face with liveness check)
  /// This is used for initial user registration/enrollment
  Future<SmileIDResult> doSmartSelfieEnrollment({
    required String userId,
    String? jobId,
    bool allowAgentMode = false,
  }) async {
    try {
      final result = await SmileID.instance.doSmartSelfieEnrollment(
        userId: userId,
        jobId: jobId ?? generateJobId(),
        allowAgentMode: allowAgentMode,
        showAttribution: true,
        showInstructions: true,
      );

      debugPrint('SmileID Enrollment Result: $result');

      return SmileIDResult.success(
        jobId: jobId ?? '',
        resultCode: result['resultCode']?.toString(),
        resultText: result['resultText']?.toString(),
        selfieFile: result['selfieFile']?.toString(),
      );
    } catch (e) {
      debugPrint('SmileID Enrollment Error: $e');
      return SmileIDResult.failure(
        ErrorHandler.getSmileIdUserFriendlyMessage(null, e.toString()),
      );
    }
  }

  /// Perform Smart Selfie Authentication (verifies face against enrolled user)
  /// This is used to verify a returning user
  Future<SmileIDResult> doSmartSelfieAuthentication({
    required String userId,
    String? jobId,
    bool allowAgentMode = false,
  }) async {
    try {
      final result = await SmileID.instance.doSmartSelfieAuthentication(
        userId: userId,
        jobId: jobId ?? generateJobId(),
        allowAgentMode: allowAgentMode,
        showAttribution: true,
        showInstructions: true,
      );

      debugPrint('SmileID Authentication Result: $result');

      return SmileIDResult.success(
        jobId: jobId ?? '',
        resultCode: result['resultCode']?.toString(),
        resultText: result['resultText']?.toString(),
      );
    } catch (e) {
      debugPrint('SmileID Authentication Error: $e');
      return SmileIDResult.failure(
        ErrorHandler.getSmileIdUserFriendlyMessage(null, e.toString()),
      );
    }
  }

  /// Perform Document Verification (captures and verifies ID document)
  /// Captures front and back of ID, extracts data via OCR
  Future<SmileIDResult> doDocumentVerification({
    required String userId,
    required String countryCode,
    required String idType,
    String? jobId,
    bool captureBothSides = true,
  }) async {
    try {
      final result = await SmileID.instance.doDocumentVerification(
        userId: userId,
        jobId: jobId ?? generateJobId(),
        countryCode: countryCode,
        documentType: idType,
        captureBothSides: captureBothSides,
        showAttribution: true,
        showInstructions: true,
      );

      debugPrint('SmileID Document Verification Result: $result');

      return SmileIDResult.success(
        jobId: jobId ?? '',
        resultCode: result['resultCode']?.toString(),
        resultText: result['resultText']?.toString(),
        documentFrontFile: result['documentFrontFile']?.toString(),
        documentBackFile: result['documentBackFile']?.toString(),
      );
    } catch (e) {
      debugPrint('SmileID Document Verification Error: $e');
      return SmileIDResult.failure(
        ErrorHandler.getSmileIdUserFriendlyMessage(null, e.toString()),
      );
    }
  }

  /// Perform Enhanced Document Verification (document + selfie comparison)
  /// This captures ID document AND selfie, then compares face on ID to selfie
  Future<SmileIDResult> doEnhancedDocumentVerification({
    required String userId,
    required String countryCode,
    required String idType,
    String? jobId,
    bool captureBothSides = true,
  }) async {
    try {
      final result = await SmileID.instance.doEnhancedDocumentVerification(
        userId: userId,
        jobId: jobId ?? generateJobId(),
        countryCode: countryCode,
        documentType: idType,
        captureBothSides: captureBothSides,
        showAttribution: true,
        showInstructions: true,
      );

      debugPrint('SmileID Enhanced Document Verification Result: $result');

      return SmileIDResult.success(
        jobId: jobId ?? '',
        resultCode: result['resultCode']?.toString(),
        resultText: result['resultText']?.toString(),
        selfieFile: result['selfieFile']?.toString(),
        documentFrontFile: result['documentFrontFile']?.toString(),
        documentBackFile: result['documentBackFile']?.toString(),
      );
    } catch (e) {
      debugPrint('SmileID Enhanced Document Verification Error: $e');
      return SmileIDResult.failure(
        ErrorHandler.getSmileIdUserFriendlyMessage(null, e.toString()),
      );
    }
  }

  /// Perform Biometric KYC (ID number verification + face comparison)
  /// Verifies ID number against government database AND captures selfie
  Future<SmileIDResult> doBiometricKyc({
    required String userId,
    required String countryCode,
    required String idType,
    required String idNumber,
    String? firstName,
    String? lastName,
    String? jobId,
  }) async {
    try {
      final result = await SmileID.instance.doBiometricKyc(
        userId: userId,
        jobId: jobId ?? generateJobId(),
        idInfo: IdInfo(
          country: countryCode,
          idType: idType,
          idNumber: idNumber,
          firstName: firstName,
          lastName: lastName,
        ),
        showAttribution: true,
        showInstructions: true,
      );

      debugPrint('SmileID Biometric KYC Result: $result');

      return SmileIDResult.success(
        jobId: jobId ?? '',
        resultCode: result['resultCode']?.toString(),
        resultText: result['resultText']?.toString(),
        selfieFile: result['selfieFile']?.toString(),
        userData: _extractUserData(result),
      );
    } catch (e) {
      debugPrint('SmileID Biometric KYC Error: $e');
      return SmileIDResult.failure(
        ErrorHandler.getSmileIdUserFriendlyMessage(null, e.toString()),
      );
    }
  }

  /// Perform Enhanced KYC (ID verification without selfie)
  /// Just verifies ID number against government database
  Future<SmileIDResult> doEnhancedKyc({
    required String countryCode,
    required String idType,
    required String idNumber,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final result = await SmileID.instance.doEnhancedKyc(
        idInfo: IdInfo(
          country: countryCode,
          idType: idType,
          idNumber: idNumber,
          firstName: firstName,
          lastName: lastName,
        ),
      );

      debugPrint('SmileID Enhanced KYC Result: $result');

      return SmileIDResult.success(
        jobId: '',
        resultCode: result['resultCode']?.toString(),
        resultText: result['resultText']?.toString(),
        userData: _extractUserData(result),
      );
    } catch (e) {
      debugPrint('SmileID Enhanced KYC Error: $e');
      return SmileIDResult.failure(
        ErrorHandler.getSmileIdUserFriendlyMessage(null, e.toString()),
      );
    }
  }

  /// Extract user data from Smile ID result
  Map<String, dynamic>? _extractUserData(Map<String, dynamic> result) {
    try {
      return {
        'fullName': result['fullName'] ?? result['FullName'],
        'firstName': result['firstName'] ?? result['FirstName'],
        'lastName': result['lastName'] ?? result['LastName'],
        'dob': result['dob'] ?? result['DOB'],
        'gender': result['gender'] ?? result['Gender'],
        'phoneNumber': result['phoneNumber'] ?? result['PhoneNumber'],
        'address': result['address'] ?? result['Address'],
        'photo': result['photo'] ?? result['Photo'],
        'idNumber': result['idNumber'] ?? result['IDNumber'],
        'expirationDate': result['expirationDate'] ?? result['ExpirationDate'],
      };
    } catch (e) {
      debugPrint('Error extracting user data: $e');
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
}

/// Result class for Smile ID verification operations
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

  factory SmileIDResult.success({
    required String jobId,
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

  @override
  String toString() {
    return 'SmileIDResult(success: $success, jobId: $jobId, resultCode: $resultCode, error: $error)';
  }
}

/// Result class for ID number validation
class IdValidationResult {
  final bool isValid;
  final String? error;
  final String? expectedFormat;

  IdValidationResult({
    required this.isValid,
    this.error,
    this.expectedFormat,
  });

  @override
  String toString() {
    return 'IdValidationResult(isValid: $isValid, error: $error)';
  }
}
