import '../models/currency_model.dart';

/// Service for managing currencies
class CurrencyService {
  // Supported currencies - African countries first, then international
  static const List<CurrencyModel> supportedCurrencies = [
    // African currencies
    CurrencyModel(code: 'GHS', symbol: 'GH₵', name: 'Ghanaian Cedi', countryCode: '+233', flag: '🇬🇭'),
    CurrencyModel(code: 'NGN', symbol: '₦', name: 'Nigerian Naira', countryCode: '+234', flag: '🇳🇬'),
    CurrencyModel(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', countryCode: '+254', flag: '🇰🇪'),
    CurrencyModel(code: 'ZAR', symbol: 'R', name: 'South African Rand', countryCode: '+27', flag: '🇿🇦'),
    CurrencyModel(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound', countryCode: '+20', flag: '🇪🇬'),
    CurrencyModel(code: 'TZS', symbol: 'TSh', name: 'Tanzanian Shilling', countryCode: '+255', flag: '🇹🇿'),
    CurrencyModel(code: 'UGX', symbol: 'USh', name: 'Ugandan Shilling', countryCode: '+256', flag: '🇺🇬'),
    CurrencyModel(code: 'RWF', symbol: 'FRw', name: 'Rwandan Franc', countryCode: '+250', flag: '🇷🇼'),
    CurrencyModel(code: 'ETB', symbol: 'Br', name: 'Ethiopian Birr', countryCode: '+251', flag: '🇪🇹'),
    CurrencyModel(code: 'MAD', symbol: 'DH', name: 'Moroccan Dirham', countryCode: '+212', flag: '🇲🇦'),
    CurrencyModel(code: 'XOF', symbol: 'CFA', name: 'West African CFA Franc', countryCode: '+225', flag: '🇨🇮'),
    CurrencyModel(code: 'XAF', symbol: 'FCFA', name: 'Central African CFA Franc', countryCode: '+237', flag: '🇨🇲'),
    CurrencyModel(code: 'ZWG', symbol: 'ZiG', name: 'Zimbabwe Gold', countryCode: '+263', flag: '🇿🇼'),

    // International currencies
    CurrencyModel(code: 'USD', symbol: '\$', name: 'US Dollar', countryCode: '+1', flag: '🇺🇸'),
    CurrencyModel(code: 'GBP', symbol: '£', name: 'British Pound', countryCode: '+44', flag: '🇬🇧'),
    CurrencyModel(code: 'EUR', symbol: '€', name: 'Euro', countryCode: '+49', flag: '🇪🇺'),
  ];

  // Default currency if none found
  static const CurrencyModel defaultCurrency = CurrencyModel(
    code: 'NGN',
    symbol: '₦',
    name: 'Nigerian Naira',
    countryCode: '+234',
    flag: '🇳🇬',
  );

  // Get currency by country dial code (for sign-up)
  static CurrencyModel getCurrencyByCountryCode(String countryCode) {
    // Clean the country code
    final cleanCode = countryCode.startsWith('+') ? countryCode : '+$countryCode';

    return supportedCurrencies.firstWhere(
      (c) => c.countryCode == cleanCode,
      orElse: () => defaultCurrency,
    );
  }

  // Get currency by currency code (for manual selection)
  static CurrencyModel getCurrencyByCode(String currencyCode) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == currencyCode.toUpperCase(),
      orElse: () => defaultCurrency,
    );
  }

  // Format amount with currency symbol
  static String formatAmount(double amount, CurrencyModel currency) {
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  // Format amount with thousand separators
  static String formatAmountWithSeparators(double amount, CurrencyModel currency) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }

    return '${currency.symbol}${buffer.toString()}.$decPart';
  }
}
