import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'biometric_localization_resolver.dart';

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
        return BiometricResult.failure(BiometricErrorKey.notSupported);
      }

      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        return BiometricResult.failure(BiometricErrorKey.noBiometricsEnrolled);
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
        return BiometricResult.failure(BiometricErrorKey.authenticationFailed);
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric PlatformException: ${e.code} - ${e.message}');
      return BiometricResult.failure(_classifyPlatformException(e));
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return BiometricResult.failure(BiometricErrorKey.authenticationFailed);
    }
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

  /// Maps a PlatformException code to a [BiometricErrorKey] enum value.
  BiometricErrorKey _classifyPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricErrorKey.notAvailable;
      case 'NotEnrolled':
        return BiometricErrorKey.notEnrolled;
      case 'LockedOut':
        return BiometricErrorKey.lockedOut;
      case 'PermanentlyLockedOut':
        return BiometricErrorKey.permanentlyLockedOut;
      case 'PasscodeNotSet':
        return BiometricErrorKey.passcodeNotSet;
      case 'OtherOperatingSystem':
        return BiometricErrorKey.otherOperatingSystem;
      default:
        return BiometricErrorKey.authenticationFailed;
    }
  }

  /// English fallback for the transitional [BiometricResult.error] String field.
  ///
  /// Kept in sync with [resolveBiometricErrorMessage]. Any English wording change
  /// must update BOTH this method AND the corresponding ARB key.
  String _englishOf(BiometricErrorKey key) {
    switch (key) {
      case BiometricErrorKey.notAvailable:
        return 'Biometric authentication is not available';
      case BiometricErrorKey.notEnrolled:
        return 'No biometrics enrolled. Please set up fingerprint or face in device settings';
      case BiometricErrorKey.lockedOut:
        return 'Too many failed attempts. Please try again later';
      case BiometricErrorKey.permanentlyLockedOut:
        return 'Biometric authentication is locked. Please unlock your device first';
      case BiometricErrorKey.passcodeNotSet:
        return 'Please set up a device passcode to use biometric authentication';
      case BiometricErrorKey.otherOperatingSystem:
        return 'Biometric authentication is not supported on this device';
      case BiometricErrorKey.authenticationFailed:
        return 'Authentication failed';
      case BiometricErrorKey.notSupported:
        return 'Biometric authentication not supported';
      case BiometricErrorKey.noBiometricsEnrolled:
        return 'No biometrics enrolled on this device';
      case BiometricErrorKey.fallback:
        return "Couldn't authenticate. Please try again.";
    }
  }
}

/// Result wrapper for biometric authentication
class BiometricResult {
  final bool success;
  final BiometricErrorKey? errorKey;
  final bool cancelled;

  BiometricResult._({
    required this.success,
    this.errorKey,
    this.cancelled = false,
  });

  factory BiometricResult.success() {
    return BiometricResult._(success: true);
  }

  factory BiometricResult.failure(BiometricErrorKey errorKey) {
    return BiometricResult._(success: false, errorKey: errorKey);
  }

  factory BiometricResult.cancelled() {
    return BiometricResult._(success: false, cancelled: true);
  }
}
