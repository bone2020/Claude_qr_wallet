// Pure-logic tests for QR Wallet. Real boot-path smoke testing
// requires mocking Hive + Firebase + auth state and is out of scope
// for this file; track that work separately.

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_wallet/core/services/currency_service.dart';

void main() {
  group('CurrencyService', () {
    test('default currency is GHS (audit 4.7)', () {
      expect(CurrencyService.defaultCurrency.code, 'GHS');
      expect(CurrencyService.defaultCurrency.symbol, 'GH₵');
    });

    test('getCurrencyByCode returns matching currency', () {
      final ghs = CurrencyService.getCurrencyByCode('GHS');
      expect(ghs.code, 'GHS');
      expect(ghs.name, 'Ghanaian Cedi');

      final ngn = CurrencyService.getCurrencyByCode('NGN');
      expect(ngn.code, 'NGN');
      expect(ngn.name, 'Nigerian Naira');
    });

    test('getCurrencyByCode falls back to defaultCurrency for unknown codes', () {
      final unknown = CurrencyService.getCurrencyByCode('XYZ_UNKNOWN');
      expect(unknown.code, 'GHS');
    });

    test('getCurrencyByCode is case-insensitive', () {
      expect(CurrencyService.getCurrencyByCode('ghs').code, 'GHS');
    });
  });
}
