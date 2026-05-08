import '../../generated/l10n/app_localizations.dart';
import 'exchange_rate_service.dart';

enum ExchangeRateErrorKey {
  unsupportedCurrency,
  unsupportedCurrencyPair,
  fallback,
}

/// Resolves an [ExchangeRateErrorKey] into a translated message.
///
/// For [unsupportedCurrencyPair], the caller MUST supply [from] and [to] for
/// ICU placeholder substitution. For other variants those parameters are unused.
String resolveExchangeRateErrorMessage(
  AppLocalizations loc,
  ExchangeRateErrorKey key, {
  String from = '',
  String to = '',
}) {
  return switch (key) {
    ExchangeRateErrorKey.unsupportedCurrency => loc.exchangeRateErrorUnsupportedCurrency,
    ExchangeRateErrorKey.unsupportedCurrencyPair => loc.exchangeRateErrorUnsupportedCurrencyPair(from, to),
    ExchangeRateErrorKey.fallback => loc.exchangeRateErrorUnsupportedCurrency,
  };
}

/// One-line resolver for UI consumers catching an [ExchangeRateException].
String resolveExchangeRateExceptionError(AppLocalizations loc, ExchangeRateException e) {
  return resolveExchangeRateErrorMessage(
    loc,
    e.errorKey,
    from: e.from,
    to: e.to,
  );
}
