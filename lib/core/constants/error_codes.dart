import 'package:cloud_functions/cloud_functions.dart';

/// Standardized error codes matching backend ERROR_CODES.
/// Use these for machine-readable error handling instead of string matching.
class AppErrorCodes {
  AppErrorCodes._();

  // Authentication & Authorization
  static const String authUnauthenticated = 'AUTH_UNAUTHENTICATED';
  static const String authPermissionDenied = 'AUTH_PERMISSION_DENIED';
  static const String authSessionExpired = 'AUTH_SESSION_EXPIRED';

  // KYC & Verification
  static const String kycRequired = 'KYC_REQUIRED';
  static const String kycIncomplete = 'KYC_INCOMPLETE';
  static const String kycVerificationFailed = 'KYC_VERIFICATION_FAILED';

  // Wallet Operations
  static const String walletNotFound = 'WALLET_NOT_FOUND';
  static const String walletInsufficientFunds = 'WALLET_INSUFFICIENT_FUNDS';
  static const String walletLimitExceeded = 'WALLET_LIMIT_EXCEEDED';
  static const String walletSuspended = 'WALLET_SUSPENDED';

  // Transaction Errors
  static const String txnInvalidState = 'TXN_INVALID_STATE';
  static const String txnDuplicateRequest = 'TXN_DUPLICATE_REQUEST';
  static const String txnSelfTransfer = 'TXN_SELF_TRANSFER';
  static const String txnRecipientNotFound = 'TXN_RECIPIENT_NOT_FOUND';
  static const String txnNotFound = 'TXN_NOT_FOUND';
  static const String txnAmountInvalid = 'TXN_AMOUNT_INVALID';
  static const String txnAmountTooSmall = 'TXN_AMOUNT_TOO_SMALL';
  static const String txnAmountTooLarge = 'TXN_AMOUNT_TOO_LARGE';

  // Rate Limiting
  static const String rateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
  static const String rateCooldownActive = 'RATE_COOLDOWN_ACTIVE';

  // External Services
  static const String servicePaystackError = 'SERVICE_PAYSTACK_ERROR';
  static const String serviceMomoError = 'SERVICE_MOMO_ERROR';
  static const String serviceUnavailable = 'SERVICE_UNAVAILABLE';

  // Configuration
  static const String configMissing = 'CONFIG_MISSING';
  static const String configInvalid = 'CONFIG_INVALID';

  // System Errors
  static const String systemInternalError = 'SYSTEM_INTERNAL_ERROR';
  static const String systemValidationFailed = 'SYSTEM_VALIDATION_FAILED';
}

/// Parsed exception from Cloud Function errors with structured error codes.
///
/// Usage:
/// ```dart
/// try {
///   await functions.httpsCallable('sendMoney').call(data);
/// } on FirebaseFunctionsException catch (e) {
///   final error = AppException.fromFirebaseError(e);
///   if (error.isInsufficientFunds) {
///     // Show balance top-up dialog
///   } else if (error.isKycRequired) {
///     // Navigate to verification screen
///   }
/// }
/// ```
class AppException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  AppException({
    required this.code,
    required this.message,
    this.details,
  });

  factory AppException.fromFirebaseError(FirebaseFunctionsException e) {
    final details = e.details is Map<String, dynamic>
        ? e.details as Map<String, dynamic>
        : null;
    return AppException(
      code: details?['code'] as String? ?? 'UNKNOWN',
      message: details?['message'] as String? ?? e.message ?? 'An error occurred',
      details: details,
    );
  }

  // Authentication checks
  bool get isUnauthenticated => code == AppErrorCodes.authUnauthenticated;
  bool get isPermissionDenied => code == AppErrorCodes.authPermissionDenied;
  bool get isSessionExpired => code == AppErrorCodes.authSessionExpired;

  // KYC checks
  bool get isKycRequired => code == AppErrorCodes.kycRequired;
  bool get isKycIncomplete => code == AppErrorCodes.kycIncomplete;

  // Wallet checks
  bool get isWalletNotFound => code == AppErrorCodes.walletNotFound;
  bool get isInsufficientFunds => code == AppErrorCodes.walletInsufficientFunds;
  bool get isWalletSuspended => code == AppErrorCodes.walletSuspended;

  // Transaction checks
  bool get isSelfTransfer => code == AppErrorCodes.txnSelfTransfer;
  bool get isDuplicateRequest => code == AppErrorCodes.txnDuplicateRequest;
  bool get isRecipientNotFound => code == AppErrorCodes.txnRecipientNotFound;
  bool get isAmountInvalid =>
      code == AppErrorCodes.txnAmountInvalid ||
      code == AppErrorCodes.txnAmountTooSmall ||
      code == AppErrorCodes.txnAmountTooLarge;

  // Rate limiting checks
  bool get isRateLimited =>
      code == AppErrorCodes.rateLimitExceeded ||
      code == AppErrorCodes.rateCooldownActive;

  // Service checks
  bool get isServiceError =>
      code == AppErrorCodes.servicePaystackError ||
      code == AppErrorCodes.serviceMomoError ||
      code == AppErrorCodes.serviceUnavailable;
  bool get isRetryable => details?['retryable'] == true || isServiceError;

  @override
  String toString() => 'AppException($code): $message';
}
