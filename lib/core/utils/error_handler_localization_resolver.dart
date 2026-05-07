import '../../generated/l10n/app_localizations.dart';

// ============================================================
// ENUM TYPES
// ============================================================
//
// One enum per error category. Each enum value maps to exactly one
// AppLocalizations getter via the corresponding resolver function below.
//
// These enums are returned by the new classify methods on ErrorHandler.
// UI consumers convert the enum to a translated string by calling the
// matching resolver function with their AppLocalizations instance.
//
// Some enum values intentionally resolve to the SAME ARB key as a value
// in another enum — this is documented per-case in the resolver functions.

enum MomoErrorKey {
  notConfigured,
  paymentDeclined,
  insufficientFunds,
  invalidPhone,
  paymentTimeout,
  fallback,
}

enum GenericErrorKey {
  network,
  cameraPermission,
  userCancelled,
  faceDetection,
  faceMismatch,
  idVerification,
  document,
  server,
  timeout,
  auth,
  somethingWentWrong,
}

enum SmileIdResultKey {
  verified,
  faceMatchFailed,
  idDocFailed,
  livenessFailed,
  expiredDoc,
  infoMismatch,
  unsupportedDoc,
  faceNotDetected,
  multipleFacesDetected,
  poorImageQuality,
  couldNotComplete,
}

enum KycErrorKey {
  ninLength,
  bvnLength,
  ssnitFormat,
  documentUploadNetwork,
  imageTooLarge,
  documentUploadGeneric,
  fallback,
}

enum FirebaseAuthErrorKey {
  network,
  tooManyRequests,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  invalidPhoneNumber,
  invalidVerificationCode,
  serviceUnavailable,
  operationNotAllowed,
  fallback,
}

// ============================================================
// RESOLVER FUNCTIONS
// ============================================================
//
// Each switch is exhaustive — adding a new enum value without a matching
// case here is a compile error.

String resolveMomoErrorMessage(AppLocalizations loc, MomoErrorKey key) {
  return switch (key) {
    MomoErrorKey.notConfigured => loc.momoErrorNotConfigured,
    MomoErrorKey.paymentDeclined => loc.momoErrorPaymentDeclined,
    MomoErrorKey.insufficientFunds => loc.momoErrorInsufficientFunds,
    MomoErrorKey.invalidPhone => loc.momoErrorInvalidPhone,
    MomoErrorKey.paymentTimeout => loc.momoErrorPaymentTimeout,
    // Cross-enum reuse: MoMo's last-resort fallback uses the same wording
    // as GenericErrorKey.somethingWentWrong.
    MomoErrorKey.fallback => loc.genericErrorFallback,
  };
}

String resolveGenericErrorMessage(AppLocalizations loc, GenericErrorKey key) {
  return switch (key) {
    GenericErrorKey.network => loc.genericErrorNetwork,
    GenericErrorKey.cameraPermission => loc.genericErrorCameraPermission,
    GenericErrorKey.userCancelled => loc.genericErrorUserCancelled,
    GenericErrorKey.faceDetection => loc.genericErrorFaceDetection,
    GenericErrorKey.faceMismatch => loc.genericErrorFaceMismatch,
    GenericErrorKey.idVerification => loc.genericErrorIdVerification,
    GenericErrorKey.document => loc.genericErrorDocument,
    GenericErrorKey.server => loc.genericErrorServer,
    GenericErrorKey.timeout => loc.genericErrorTimeout,
    GenericErrorKey.auth => loc.genericErrorAuth,
    GenericErrorKey.somethingWentWrong => loc.genericErrorFallback,
  };
}

String resolveSmileIdResultMessage(AppLocalizations loc, SmileIdResultKey key) {
  return switch (key) {
    SmileIdResultKey.verified => loc.smileIdResultVerified,
    SmileIdResultKey.faceMatchFailed => loc.smileIdResultFaceMatchFailed,
    SmileIdResultKey.idDocFailed => loc.smileIdResultIdDocFailed,
    SmileIdResultKey.livenessFailed => loc.smileIdResultLivenessFailed,
    SmileIdResultKey.expiredDoc => loc.smileIdResultExpiredDoc,
    SmileIdResultKey.infoMismatch => loc.smileIdResultInfoMismatch,
    SmileIdResultKey.unsupportedDoc => loc.smileIdResultUnsupportedDoc,
    SmileIdResultKey.faceNotDetected => loc.smileIdResultFaceNotDetected,
    SmileIdResultKey.multipleFacesDetected => loc.smileIdResultMultipleFacesDetected,
    SmileIdResultKey.poorImageQuality => loc.smileIdResultPoorImageQuality,
    SmileIdResultKey.couldNotComplete => loc.smileIdResultCouldNotComplete,
  };
}

String resolveKycErrorMessage(AppLocalizations loc, KycErrorKey key) {
  return switch (key) {
    // Reuses cleanup-3 keys (Decision ω from the C.1 spec).
    KycErrorKey.ninLength => loc.ninLengthError,
    KycErrorKey.bvnLength => loc.bvnLengthError,
    KycErrorKey.ssnitFormat => loc.ssnitFormatError,
    KycErrorKey.documentUploadNetwork => loc.kycErrorDocumentUploadNetwork,
    KycErrorKey.imageTooLarge => loc.kycErrorImageTooLarge,
    KycErrorKey.documentUploadGeneric => loc.kycErrorDocumentUploadGeneric,
    // Cross-enum reuse: KYC's fallback uses SmileID's couldNotComplete wording
    // because most KYC flows end in some kind of verification.
    KycErrorKey.fallback => loc.smileIdResultCouldNotComplete,
  };
}

String resolveFirebaseAuthErrorMessage(
  AppLocalizations loc,
  FirebaseAuthErrorKey key,
) {
  return switch (key) {
    FirebaseAuthErrorKey.network => loc.firebaseAuthErrorNetwork,
    FirebaseAuthErrorKey.tooManyRequests => loc.firebaseAuthErrorTooManyRequests,
    FirebaseAuthErrorKey.userNotFound => loc.firebaseAuthErrorUserNotFound,
    FirebaseAuthErrorKey.wrongPassword => loc.firebaseAuthErrorWrongPassword,
    FirebaseAuthErrorKey.emailAlreadyInUse => loc.firebaseAuthErrorEmailAlreadyInUse,
    FirebaseAuthErrorKey.invalidEmail => loc.firebaseAuthErrorInvalidEmail,
    FirebaseAuthErrorKey.weakPassword => loc.firebaseAuthErrorWeakPassword,
    FirebaseAuthErrorKey.invalidPhoneNumber => loc.firebaseAuthErrorInvalidPhone,
    FirebaseAuthErrorKey.invalidVerificationCode => loc.firebaseAuthErrorInvalidVerificationCode,
    FirebaseAuthErrorKey.serviceUnavailable => loc.firebaseAuthErrorServiceUnavailable,
    FirebaseAuthErrorKey.operationNotAllowed => loc.firebaseAuthErrorOperationNotAllowed,
    FirebaseAuthErrorKey.fallback => loc.firebaseAuthErrorFallback,
  };
}
