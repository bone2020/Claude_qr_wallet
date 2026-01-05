import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Biometric authentication service
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ============================================================
  // AVAILABILITY CHECKS
  // ============================================================

  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Check if biometrics are enrolled on device
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if fingerprint is available
  Future<bool> hasFingerprintSupport() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Check if face recognition is available
  Future<bool> hasFaceSupport() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Get biometric type description
  Future<String> getBiometricTypeDescription() async {
    final biometrics = await getAvailableBiometrics();
    
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    
    return 'Biometric';
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  /// Authenticate user with biometrics
  Future<BiometricResult> authenticate({
    String reason = 'Please authenticate to continue',
    bool biometricOnly = true,
  }) async {
    try {
      // Check if biometrics are available
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return BiometricResult.failure('Biometric authentication not supported');
      }

      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        return BiometricResult.failure('No biometrics enrolled on this device');
      }

      // Attempt authentication
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        return BiometricResult.success();
      } else {
        return BiometricResult.failure('Authentication failed');
      }
    } on PlatformException catch (e) {
      return BiometricResult.failure(_getErrorMessage(e));
    } catch (e) {
      return BiometricResult.failure('An error occurred: $e');
    }
  }

  /// Authenticate for login
  Future<BiometricResult> authenticateForLogin() async {
    return authenticate(
      reason: 'Authenticate to access your QR Wallet',
      biometricOnly: true,
    );
  }

  /// Authenticate for transaction confirmation
  Future<BiometricResult> authenticateForTransaction({
    required double amount,
    required String recipient,
    required String currencySymbol,
  }) async {
    return authenticate(
      reason: 'Confirm payment of $currencySymbol${amount.toStringAsFixed(2)} to $recipient',
      biometricOnly: true,
    );
  }

  /// Authenticate for sensitive settings change
  Future<BiometricResult> authenticateForSettings() async {
    return authenticate(
      reason: 'Authenticate to change security settings',
      biometricOnly: false, // Allow PIN/password fallback for settings
    );
  }

  // ============================================================
  // CANCEL AUTHENTICATION
  // ============================================================

  /// Cancel ongoing authentication
  Future<void> cancelAuthentication() async {
    await _localAuth.stopAuthentication();
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get user-friendly error message
  String _getErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available';
      case 'NotEnrolled':
        return 'No biometrics enrolled. Please set up fingerprint or face in device settings';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is locked. Please unlock your device first';
      case 'PasscodeNotSet':
        return 'Please set up a device passcode to use biometric authentication';
      case 'OtherOperatingSystem':
        return 'Biometric authentication is not supported on this device';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}

/// Result wrapper for biometric authentication
class BiometricResult {
  final bool success;
  final String? error;
  final bool cancelled;

  BiometricResult._({
    required this.success,
    this.error,
    this.cancelled = false,
  });

  factory BiometricResult.success() {
    return BiometricResult._(success: true);
  }

  factory BiometricResult.failure(String error) {
    return BiometricResult._(success: false, error: error);
  }

  factory BiometricResult.cancelled() {
    return BiometricResult._(success: false, cancelled: true);
  }
}
