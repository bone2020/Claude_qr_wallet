import '../../generated/l10n/app_localizations.dart';
import 'biometric_service.dart';

/// Identifies the kind of biometric error carried by [BiometricResult.errorKey].
enum BiometricErrorKey {
  // PlatformException-derived (from _classifyPlatformException)
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  passcodeNotSet,
  otherOperatingSystem,
  authenticationFailed,

  // Service-layer (from BiometricResult.failure call sites)
  notSupported,
  noBiometricsEnrolled,

  // Catch-all
  fallback,
}

/// Resolves a [BiometricErrorKey] into a translated, user-visible message.
String resolveBiometricErrorMessage(AppLocalizations loc, BiometricErrorKey key) {
  return switch (key) {
    BiometricErrorKey.notAvailable => loc.biometricErrorNotAvailable,
    BiometricErrorKey.notEnrolled => loc.biometricErrorNotEnrolled,
    BiometricErrorKey.lockedOut => loc.biometricErrorLockedOut,
    BiometricErrorKey.permanentlyLockedOut => loc.biometricErrorPermanentlyLockedOut,
    BiometricErrorKey.passcodeNotSet => loc.biometricErrorPasscodeNotSet,
    BiometricErrorKey.otherOperatingSystem => loc.biometricErrorOtherOperatingSystem,
    BiometricErrorKey.authenticationFailed => loc.biometricErrorAuthenticationFailed,
    BiometricErrorKey.notSupported => loc.biometricErrorNotSupported,
    BiometricErrorKey.noBiometricsEnrolled => loc.biometricErrorNoBiometricsEnrolled,
    BiometricErrorKey.fallback => loc.biometricErrorFallback,
  };
}

/// One-line resolver for UI consumers.
String resolveBiometricResultError(AppLocalizations loc, BiometricResult result) {
  if (result.errorKey != null) {
    return resolveBiometricErrorMessage(loc, result.errorKey!);
  }
  return loc.biometricErrorFallback;
}
