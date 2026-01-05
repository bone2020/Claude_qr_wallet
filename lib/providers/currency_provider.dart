import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/currency_model.dart';
import '../core/services/currency_service.dart';

// ============================================================
// CURRENCY STATE
// ============================================================

/// Currency state
class CurrencyState {
  final CurrencyModel currency;
  final bool isLoading;
  final String? error;

  CurrencyState({
    CurrencyModel? currency,
    this.isLoading = false,
    this.error,
  }) : currency = currency ?? CurrencyService.defaultCurrency;

  CurrencyState copyWith({
    CurrencyModel? currency,
    bool? isLoading,
    String? error,
  }) {
    return CurrencyState(
      currency: currency ?? this.currency,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  String get symbol => currency.symbol;
  String get code => currency.code;
  String get name => currency.name;
  String get flag => currency.flag;
}

// ============================================================
// CURRENCY NOTIFIER
// ============================================================

/// Currency notifier for managing currency state
class CurrencyNotifier extends StateNotifier<CurrencyState> {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CurrencyNotifier({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(CurrencyState());

  /// Initialize currency from Firestore
  Future<void> loadUserCurrency() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists && doc.data()?['currency'] != null) {
          final currencyCode = doc.data()!['currency'] as String;
          final currency = CurrencyService.getCurrencyByCode(currencyCode);
          state = state.copyWith(currency: currency, isLoading: false);
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set currency (manual selection)
  Future<bool> setCurrency(CurrencyModel newCurrency) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'currency': newCurrency.code,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Also update wallet currency
        final walletDoc = await _firestore
            .collection('wallets')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (walletDoc.docs.isNotEmpty) {
          await walletDoc.docs.first.reference.update({
            'currency': newCurrency.code,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        state = state.copyWith(currency: newCurrency, isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Set currency from country dial code (used during sign-up)
  Future<bool> setCurrencyFromCountryCode(String countryCode) async {
    final currency = CurrencyService.getCurrencyByCountryCode(countryCode);
    return await setCurrency(currency);
  }

  /// Set currency locally without saving to Firestore (for pre-login)
  void setLocalCurrency(CurrencyModel currency) {
    state = state.copyWith(currency: currency);
  }

  /// Format amount with current currency
  String formatAmount(double amount) {
    return CurrencyService.formatAmount(amount, state.currency);
  }

  /// Format amount with thousand separators
  String formatAmountWithSeparators(double amount) {
    return CurrencyService.formatAmountWithSeparators(amount, state.currency);
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Currency notifier provider
final currencyNotifierProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyState>((ref) {
  return CurrencyNotifier();
});

/// Currency symbol provider (convenience)
final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(currencyNotifierProvider).symbol;
});

/// Currency code provider (convenience)
final currencyCodeProvider = Provider<String>((ref) {
  return ref.watch(currencyNotifierProvider).code;
});

/// Supported currencies provider
final supportedCurrenciesProvider = Provider<List<CurrencyModel>>((ref) {
  return CurrencyService.supportedCurrencies;
});
