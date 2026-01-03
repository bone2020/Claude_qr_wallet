class ExchangeRateService {
  // Exchange rates based on USD (1 USD = X currency)
  // Update these rates periodically
  static const Map<String, double> _ratesToUSD = {
    'USD': 1.0,
    'GHS': 15.4,      // 1 USD = 15.4 GHS
    'NGN': 1550.0,    // 1 USD = 1550 NGN
    'KES': 129.0,     // 1 USD = 129 KES
    'ZAR': 18.5,      // 1 USD = 18.5 ZAR
    'GBP': 0.79,      // 1 USD = 0.79 GBP
    'EUR': 0.92,      // 1 USD = 0.92 EUR
  };

  /// Check if conversion is needed
  static bool needsConversion(String fromCurrency, String toCurrency) {
    return fromCurrency != toCurrency;
  }

  /// Convert amount from one currency to another
  static double convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    // Same currency - no conversion
    if (fromCurrency == toCurrency) return amount;

    // Get rates
    final fromRate = _ratesToUSD[fromCurrency];
    final toRate = _ratesToUSD[toCurrency];

    if (fromRate == null || toRate == null) {
      throw Exception('Unsupported currency: $fromCurrency or $toCurrency');
    }

    // Convert: fromCurrency → USD → toCurrency
    final amountInUSD = amount / fromRate;
    final convertedAmount = amountInUSD * toRate;

    return convertedAmount;
  }

  /// Get exchange rate between two currencies
  static double getExchangeRate({
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return 1.0;

    final fromRate = _ratesToUSD[fromCurrency];
    final toRate = _ratesToUSD[toCurrency];

    if (fromRate == null || toRate == null) {
      throw Exception('Unsupported currency');
    }

    // Rate: 1 fromCurrency = X toCurrency
    return toRate / fromRate;
  }

  /// Format converted amount with rate info
  static String formatConversionInfo({
    required double originalAmount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    final rate = getExchangeRate(fromCurrency: fromCurrency, toCurrency: toCurrency);

    return '1 $fromCurrency = ${rate.toStringAsFixed(2)} $toCurrency';
  }
}
