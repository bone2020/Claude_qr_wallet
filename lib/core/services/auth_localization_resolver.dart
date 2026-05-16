import '../../generated/l10n/app_localizations.dart';
import '../utils/error_handler_localization_resolver.dart';
import 'auth_service.dart';

/// Identifies the kind of auth error carried by [AuthResult.errorKey].
///
/// Two conceptual groups are unified into a single enum to keep AuthResult to
/// one new field per the C.2 architectural decision (Q1, Option 1):
///
///   * Service-layer errors (no equivalent Firebase auth code) — produced by
///     auth_service.dart's own logic and by auth_provider.dart for things like
///     "user data not found" and "no verification ID".
///
///   * Firebase-code-derived errors — produced when a FirebaseAuthException
///     fires; the exception's code is mapped to one of these enum values via
///     `_classifyAuthCode` inside auth_service.dart.
///
/// The fallback value is used when none of the more specific cases apply
/// (e.g. unrecognized Firebase code, or a non-Firebase exception caught by a
/// generic `catch (e)`).
enum AuthErrorKey {
  // -- Service-layer errors (12 values) ---------------------------------------
  failedToCreateUser,
  failedToSignIn,
  userDataNotFound,
  googleSignInCancelled,
  failedToSignInWithGoogle,
  failedToSignInWithApple,
  appleSignInCancelled,
  appleSignInFailed,
  failedToVerifyOtp,
  userNotFound,
  noUserLoggedIn,
  noVerificationId,

  // -- Firebase-code-derived errors (10 values) -------------------------------
  firebaseAccountNotFound,
  firebaseWrongPassword,
  firebaseEmailAlreadyInUse,
  firebaseInvalidEmail,
  firebaseWeakPassword,
  firebaseTooManyRequests,
  firebaseInvalidVerificationCode,
  firebaseInvalidVerificationId,
  firebaseCredentialAlreadyInUse,
  firebaseNetworkRequestFailed,

  // -- Catch-all (1 value) ----------------------------------------------------
  fallback,
}

/// Resolves an [AuthErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch — adding a new enum value without
/// a matching case here is a compile error.
String resolveAuthErrorMessage(AppLocalizations loc, AuthErrorKey key) {
  return switch (key) {
    // Service-layer
    AuthErrorKey.failedToCreateUser => loc.authErrorFailedToCreateUser,
    AuthErrorKey.failedToSignIn => loc.authErrorFailedToSignIn,
    AuthErrorKey.userDataNotFound => loc.authErrorUserDataNotFound,
    AuthErrorKey.googleSignInCancelled => loc.authErrorGoogleSignInCancelled,
    AuthErrorKey.failedToSignInWithGoogle => loc.authErrorFailedToSignInWithGoogle,
    AuthErrorKey.failedToSignInWithApple => loc.authErrorFailedToSignInWithApple,
    AuthErrorKey.appleSignInCancelled => loc.authErrorAppleSignInCancelled,
    AuthErrorKey.appleSignInFailed => loc.authErrorAppleSignInFailed,
    AuthErrorKey.failedToVerifyOtp => loc.authErrorFailedToVerifyOtp,
    AuthErrorKey.userNotFound => loc.authErrorUserNotFound,
    AuthErrorKey.noUserLoggedIn => loc.authErrorNoUserLoggedIn,
    AuthErrorKey.noVerificationId => loc.authErrorNoVerificationId,
    // Firebase-code-derived
    AuthErrorKey.firebaseAccountNotFound => loc.authErrorFirebaseAccountNotFound,
    AuthErrorKey.firebaseWrongPassword => loc.authErrorFirebaseWrongPassword,
    AuthErrorKey.firebaseEmailAlreadyInUse => loc.authErrorFirebaseEmailAlreadyInUse,
    AuthErrorKey.firebaseInvalidEmail => loc.authErrorFirebaseInvalidEmail,
    AuthErrorKey.firebaseWeakPassword => loc.authErrorFirebaseWeakPassword,
    AuthErrorKey.firebaseTooManyRequests => loc.authErrorFirebaseTooManyRequests,
    AuthErrorKey.firebaseInvalidVerificationCode => loc.authErrorFirebaseInvalidVerificationCode,
    AuthErrorKey.firebaseInvalidVerificationId => loc.authErrorFirebaseInvalidVerificationId,
    AuthErrorKey.firebaseCredentialAlreadyInUse => loc.authErrorFirebaseCredentialAlreadyInUse,
    AuthErrorKey.firebaseNetworkRequestFailed => loc.authErrorFirebaseNetworkRequestFailed,
    // Fallback
    AuthErrorKey.fallback => loc.authErrorFallback,
  };
}

/// One-line resolver for UI consumers. Picks the best message available:
///
///   1. If [AuthResult.errorKey] is non-null, resolve via [resolveAuthErrorMessage].
///   2. Else if [AuthResult.error] is non-null (transitional during C.2-C.4),
///      return it as-is.
///   3. Else return the generic auth fallback.
///
/// UI screens should call this rather than reading [AuthResult.error] directly.
String resolveAuthResultError(AppLocalizations loc, AuthResult result) {
  if (result.errorKey != null) {
    return resolveAuthErrorMessage(loc, result.errorKey!);
  }
  if (result.genericErrorKey != null) {
    return resolveGenericErrorMessage(loc, result.genericErrorKey!);
  }
  return loc.authErrorFallback;
}
