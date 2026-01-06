import 'package:cloud_firestore/cloud_firestore.dart';

/// Exchange rate service with Firestore + fallback
class ExchangeRateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Map<String, double>? _cachedRates;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Fallback rates (used if Firestore fails)
  static const Map<String, double> _fallbackRates = {
    'USD': 1.0,
    'NGN': 1550.0,
    'ZAR': 18.5,
    'KES': 129.0,
    'GHS': 15.4,
    'EGP': 50.0,
    'TZS': 2700.0,
    'UGX': 3700.0,
    'RWF': 1300.0,
    'ETB': 56.0,
    'MAD': 10.0,
    'DZD': 135.0,
    'TND': 3.1,
    'XAF': 600.0,
    'XOF': 600.0,
    'ZMW': 27.0,
    'BWP': 13.5,
    'NAD': 18.5,
    'MZN': 64.0,
    'AOA': 830.0,
    'CDF': 2800.0,
    'SDG': 600.0,
    'LYD': 4.8,
    'MUR': 45.0,
    'MWK': 1700.0,
    'SLL': 22000.0,
    'LRD': 190.0,
    'GMD': 67.0,
    'GNF': 8600.0,
    'BIF': 2850.0,
    'ERN': 15.0,
    'DJF': 178.0,
    'SOS': 570.0,
    'SSP': 130.0,
    'LSL': 18.5,
    'SZL': 18.5,
    'MGA': 4500.0,
    'SCR': 13.0,
    'KMF': 450.0,
    'MRU': 40.0,
    'CVE': 101.0,
    'STN': 22.5,
    'GBP': 0.79,
    'EUR': 0.92,
  };

  /// Fetch rates from Firestore (with caching)
  static Future<Map<String, double>> _getRates() async {
    if (_cachedRates != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedRates!;
      }
    }

    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('exchange_rates')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rates = Map<String, double>.from(
          (data['rates'] as Map).map(
            (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
          ),
        );
        _cachedRates = rates;
        _cacheTime = DateTime.now();
        return rates;
      }
    } catch (e) {
      print('Error fetching rates from Firestore: $e');
    }
    return _fallbackRates;
  }

  static bool needsConversion(String fromCurrency, String toCurrency) {
    return fromCurrency != toCurrency;
  }

  static Future<double> convertAsync({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return amount;
    final rates = await _getRates();
    final fromRate = rates[fromCurrency] ?? _fallbackRates[fromCurrency];
    final toRate = rates[toCurrency] ?? _fallbackRates[toCurrency];
    if (fromRate == null || toRate == null) {
      throw Exception('Unsupported currency: $fromCurrency or $toCurrency');
    }
    return (amount / fromRate) * toRate;
  }

  static double convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return amount;
    final rates = _cachedRates ?? _fallbackRates;
    final fromRate = rates[fromCurrency] ?? _fallbackRates[fromCurrency];
    final toRate = rates[toCurrency] ?? _fallbackRates[toCurrency];
    if (fromRate == null || toRate == null) {
      throw Exception('Unsupported currency: $fromCurrency or $toCurrency');
    }
    return (amount / fromRate) * toRate;
  }

  static Future<double> getExchangeRateAsync({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return 1.0;
    final rates = await _getRates();
    final fromRate = rates[fromCurrency] ?? _fallbackRates[fromCurrency];
    final toRate = rates[toCurrency] ?? _fallbackRates[toCurrency];
    if (fromRate == null || toRate == null) {
      throw Exception('Unsupported currency');
    }
    return toRate / fromRate;
  }

  static double getExchangeRate({
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return 1.0;
    final rates = _cachedRates ?? _fallbackRates;
    final fromRate = rates[fromCurrency] ?? _fallbackRates[fromCurrency];
    final toRate = rates[toCurrency] ?? _fallbackRates[toCurrency];
    if (fromRate == null || toRate == null) {
      throw Exception('Unsupported currency');
    }
    return toRate / fromRate;
  }

  static Future<void> preloadRates() async {
    await _getRates();
  }

  static Future<void> refreshRates() async {
    _cachedRates = null;
    _cacheTime = null;
    await _getRates();
  }

  static Future<DateTime?> getLastUpdateTime() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('exchange_rates')
          .get();
      if (doc.exists && doc.data() != null) {
        final timestamp = doc.data()!['updatedAt'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (e) {
      print('Error getting update time: $e');
    }
    return null;
  }

  static String formatConversionInfo({
    required double originalAmount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    final rate = getExchangeRate(fromCurrency: fromCurrency, toCurrency: toCurrency);
    return '1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency';
  }
}
