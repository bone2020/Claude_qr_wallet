import '../../generated/l10n/app_localizations.dart';
import 'wallet_service.dart';
import '../utils/error_handler_localization_resolver.dart';

/// Identifies the kind of transaction error carried by [TransactionResult.errorKey].
///
/// Mirrors the C.2/C.3 pattern: a single enum captures every error path produced
/// by wallet_service.dart's TransactionResult-returning methods (sendMoney and
/// addMoney), with a single resolver function and a single field on the result
/// class.
enum TransactionErrorKey {
  // Send-flow keys
  userNotAuthenticated,
  pleaseLogInToSendMoney,
  recipientWalletNotFound,
  insufficientBalance,
  invalidRequest,
  transactionFailed,

  // Deposit-flow keys
  paymentAlreadyProcessed,
  paymentVerificationFailed,
  depositFailed,

  // Validation errors (wallet_provider)
  noRecipientSelected,
  invalidAmount,

  // Catch-all
  fallback,
}

/// Resolves a [TransactionErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch — adding a new enum value without
/// a matching case here is a compile error.
String resolveTransactionErrorMessage(AppLocalizations loc, TransactionErrorKey key) {
  return switch (key) {
    TransactionErrorKey.userNotAuthenticated => loc.transactionErrorUserNotAuthenticated,
    TransactionErrorKey.pleaseLogInToSendMoney => loc.transactionErrorPleaseLogInToSendMoney,
    TransactionErrorKey.recipientWalletNotFound => loc.transactionErrorRecipientWalletNotFound,
    TransactionErrorKey.insufficientBalance => loc.transactionErrorInsufficientBalance,
    TransactionErrorKey.invalidRequest => loc.transactionErrorInvalidRequest,
    TransactionErrorKey.transactionFailed => loc.transactionErrorTransactionFailed,
    TransactionErrorKey.paymentAlreadyProcessed => loc.transactionErrorPaymentAlreadyProcessed,
    TransactionErrorKey.paymentVerificationFailed => loc.transactionErrorPaymentVerificationFailed,
    TransactionErrorKey.depositFailed => loc.transactionErrorDepositFailed,
    TransactionErrorKey.noRecipientSelected => loc.transactionErrorNoRecipientSelected,
    TransactionErrorKey.invalidAmount => loc.transactionErrorInvalidAmount,
    TransactionErrorKey.fallback => loc.transactionErrorFallback,
  };
}

/// One-line resolver for UI consumers. Picks the best message available:
///
///   1. If [TransactionResult.errorKey] is non-null, resolve via [resolveTransactionErrorMessage].
///   2. Else if [TransactionResult.error] is non-null (transitional during C.4-C.5),
///      return it as-is.
///   3. Else return the generic transaction fallback.
///
/// UI screens should call this rather than reading [TransactionResult.error] directly.
String resolveTransactionResultError(AppLocalizations loc, TransactionResult result) {
  if (result.errorKey != null) {
    return resolveTransactionErrorMessage(loc, result.errorKey!);
  }
  if (result.genericErrorKey != null) {
    return resolveGenericErrorMessage(loc, result.genericErrorKey!);
  }
  return loc.transactionErrorFallback;
}
