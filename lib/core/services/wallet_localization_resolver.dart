import '../../generated/l10n/app_localizations.dart';
import '../utils/error_handler_localization_resolver.dart';
import 'wallet_service.dart';

/// Wallet-specific error keys carried by [WalletException.walletErrorKey].
///
/// Cross-category note: WalletException can also carry a [GenericErrorKey] via
/// its [WalletException.genericErrorKey] field for ErrorHandler-classified
/// errors that don't have a specific wallet meaning.
enum WalletErrorKey {
  tooManyRequests,
  failedToLookupWallet,
  failedToFetchTransaction,
  fallback,
}

/// Resolves a [WalletErrorKey] into a translated, user-visible message.
String resolveWalletErrorMessage(AppLocalizations loc, WalletErrorKey key) {
  return switch (key) {
    WalletErrorKey.tooManyRequests => loc.walletErrorTooManyRequests,
    WalletErrorKey.failedToLookupWallet => loc.walletErrorFailedToLookupWallet,
    WalletErrorKey.failedToFetchTransaction => loc.walletErrorFailedToFetchTransaction,
    WalletErrorKey.fallback => loc.walletErrorFallback,
  };
}

/// One-line resolver for UI consumers catching a [WalletException].
///
/// Resolution priority:
///   1. walletErrorKey (specific wallet error)
///   2. genericErrorKey (ErrorHandler-classified error)
///   3. message String (transitional)
///   4. Generic wallet fallback
String resolveWalletExceptionError(AppLocalizations loc, WalletException e) {
  if (e.walletErrorKey != null) {
    return resolveWalletErrorMessage(loc, e.walletErrorKey!);
  }
  if (e.genericErrorKey != null) {
    return resolveGenericErrorMessage(loc, e.genericErrorKey!);
  }
  return e.message.isNotEmpty ? e.message : loc.walletErrorFallback;
}
