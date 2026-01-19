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
      return SmileIDResult.failure('Selfie enrollment failed: $e');
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
      return SmileIDResult.failure('Selfie authentication failed: $e');
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
      return SmileIDResult.failure('Document verification failed: $e');
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
      return SmileIDResult.failure('Enhanced document verification failed: $e');
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
      return SmileIDResult.failure('Biometric KYC failed: $e');
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
      return SmileIDResult.failure('Enhanced KYC failed: $e');
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
