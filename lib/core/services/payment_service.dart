import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';

import '../utils/error_handler.dart';
import 'wallet_service.dart';
import 'momo_service.dart';

/// Payment service handling Paystack integration via Cloud Functions
class PaymentService {
  final WalletService _walletService = WalletService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final MomoService _momoService = MomoService();

  // ============================================================
  // PAYSTACK CONFIGURATION
  // ============================================================

  /// Paystack public key — passed via --dart-define=PAYSTACK_PUBLIC_KEY=pk_live_xxx
  /// In debug/test builds, pass pk_test_xxx. In release, pass pk_live_xxx.
  /// The app will refuse to initialize payments if no key is provided.
  static const String _publicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: '',
  );

  /// Validates that a Paystack key has been provided via --dart-define
  static void _validateKey() {
    if (_publicKey.isEmpty) {
      throw Exception(
        'PAYSTACK_PUBLIC_KEY not configured. '
        'Build with: flutter build --dart-define=PAYSTACK_PUBLIC_KEY=pk_live_xxx',
      );
    }
  }

  // NOTE: Secret key removed - all sensitive operations now use Cloud Functions

  // ============================================================
  // PAYMENT VERIFICATION (Server-side via Cloud Function)
  // ============================================================

  /// Verify payment with server
  Future<PaymentVerificationResult> verifyPayment(String reference) async {
    try {
      final callable = _functions.httpsCallable('verifyPayment');
      final result = await callable.call({'reference': reference});

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return PaymentVerificationResult(
          success: true,
          reference: reference,
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
        );
      } else {
        return PaymentVerificationResult(
          success: false,
          reference: reference,
          error: data['error'] ?? 'Verification failed',
        );
      }
    } catch (e) {
      return PaymentVerificationResult(
        success: false,
        reference: reference,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // ADD MONEY OPERATIONS
  // ============================================================


  /// Initialize payment for adding money to wallet via Browser Checkout
  Future<PaymentResult> initializePayment({
    required BuildContext context,
    required String email,
    required int amount,
    required String userId,
    String? currency,
  }) async {
    _validateKey();
    try {
      // Call Cloud Function to initialize transaction
      final callable = _functions.httpsCallable('initializeTransaction');
      final result = await callable.call({
        'email': email,
        'amount': amount,
        'currency': currency ?? 'GHS',
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true && data['authorizationUrl'] != null) {
        final url = data['authorizationUrl'] as String;
        final reference = data['reference'] as String;

        // Open Paystack checkout in browser
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        return PaymentResult.pending(reference);
      } else {
        return PaymentResult.failure(data['error'] ?? 'Failed to initialize payment');
      }
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  // ============================================================
  // MOBILE MONEY PAYMENT (For adding funds via Mobile Money)
  // ============================================================

  /// Initialize mobile money payment via Cloud Function
  Future<MobileMoneyPaymentResult> initializeMobileMoneyPayment({
    required String email,
    required int amount,
    required String currency,
    required String provider,
    required String phoneNumber,
    required String userId,
  }) async {
    try {
      final idempotencyKey = _generateIdempotencyKey('chargeMobileMoney');
      final callable = _functions.httpsCallable('chargeMobileMoney');
      final result = await callable.call({
        'email': email,
        'amount': amount,
        'currency': currency,
        'provider': provider,
        'phoneNumber': phoneNumber,
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return MobileMoneyPaymentResult(
          success: true,
          reference: data['reference'] as String?,
          message: data['message'] as String?,
          status: data['status'] as String?,
          completed: data['completed'] as bool? ?? false,
        );
      } else {
        return MobileMoneyPaymentResult(
          success: false,
          error: data['error'] as String? ?? 'Payment failed',
        );
      }
    } catch (e) {
      return MobileMoneyPaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // VIRTUAL ACCOUNT (For Bank Transfer deposits)
  // ============================================================

  /// Get or create a virtual account for the user
  Future<VirtualAccountResult> getOrCreateVirtualAccount({
    required String email,
    required String name,
  }) async {
    try {
      final callable = _functions.httpsCallable('getOrCreateVirtualAccount');
      final result = await callable.call({
        'email': email,
        'name': name,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return VirtualAccountResult(
          success: true,
          bankName: data['bankName'] as String?,
          accountNumber: data['accountNumber'] as String?,
          accountName: data['accountName'] as String?,
          note: data['note'] as String?,
        );
      } else {
        return VirtualAccountResult(
          success: false,
          error: data['error'] as String? ?? 'Failed to get virtual account',
        );
      }
    } catch (e) {
      return VirtualAccountResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // WITHDRAWAL OPERATIONS
  // ============================================================

  /// Get list of banks from Cloud Function
  Future<List<Bank>> getBanks({String country = 'nigeria'}) async {
    try {
      final callable = _functions.httpsCallable('getBanks');
      final result = await callable.call({'country': country});

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final banks = (data['banks'] as List)
            .map((b) => Bank(
                  name: b['name'] as String,
                  code: b['code'] as String,
                  type: b['type'] as String? ?? 'nuban',
                ))
            .toList();
        return banks;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching banks: $e');
      return [];
    }
  }

  /// Verify bank account via Cloud Function
  Future<BankAccountVerification> verifyBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyBankAccount');
      final result = await callable.call({
        'accountNumber': accountNumber,
        'bankCode': bankCode,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return BankAccountVerification(
          success: true,
          accountName: data['accountName'] as String?,
          accountNumber: data['accountNumber'] as String?,
        );
      } else {
        return BankAccountVerification(
          success: false,
          error: data['error'] as String? ?? 'Verification failed',
        );
      }
    } catch (e) {
      return BankAccountVerification(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Initiate withdrawal to bank via Cloud Function
  Future<WithdrawalResult> initiateWithdrawal({
    required int amount,
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final idempotencyKey = _generateIdempotencyKey('initiateWithdrawal');
      final callable = _functions.httpsCallable('initiateWithdrawal');
      final result = await callable.call({
        'amount': amount,
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'type': 'bank',
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return WithdrawalResult(
          success: true,
          reference: data['reference'] as String?,
          message: data['message'] as String?,
          requiresOtp: data['requiresOtp'] as bool? ?? false,
          transferCode: data['transferCode'] as String?,
        );
      } else {
        return WithdrawalResult(
          success: false,
          error: data['error'] as String? ?? 'Withdrawal failed',
          requiresOtp: data['requiresOtp'] as bool? ?? false,
          transferCode: data['transferCode'] as String?,
        );
      }
    } catch (e) {
      return WithdrawalResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Finalize transfer with OTP via Cloud Function
  Future<WithdrawalResult> finalizeTransfer({
    required String transferCode,
    required String otp,
  }) async {
    try {
      final idempotencyKey = _generateIdempotencyKey('finalizeTransfer');
      final callable = _functions.httpsCallable('finalizeTransfer');
      final result = await callable.call({
        'transferCode': transferCode,
        'otp': otp,
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return WithdrawalResult(
          success: true,
          reference: data['reference'] as String?,
          message: data['message'] as String?,
        );
      } else {
        return WithdrawalResult(
          success: false,
          error: data['error'] as String? ?? 'OTP verification failed',
        );
      }
    } catch (e) {
      return WithdrawalResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Initiate withdrawal to mobile money via Cloud Function
  Future<WithdrawalResult> initiateMobileMoneyWithdrawal({
    required int amount,
    required String provider,
    required String phoneNumber,
    required String accountName,
  }) async {
    try {
      final idempotencyKey = _generateIdempotencyKey('initiateWithdrawal');
      final callable = _functions.httpsCallable('initiateWithdrawal');
      final result = await callable.call({
        'amount': amount,
        'mobileMoneyProvider': provider,
        'phoneNumber': phoneNumber,
        'accountName': accountName,
        'type': 'mobile_money',
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return WithdrawalResult(
          success: true,
          reference: data['reference'] as String?,
          message: data['message'] as String?,
          requiresOtp: data['requiresOtp'] as bool? ?? false,
          transferCode: data['transferCode'] as String?,
        );
      } else {
        return WithdrawalResult(
          success: false,
          error: data['error'] as String? ?? 'Withdrawal failed',
          requiresOtp: data['requiresOtp'] as bool? ?? false,
          transferCode: data['transferCode'] as String?,
        );
      }
    } catch (e) {
      return WithdrawalResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    return 'QRW_${timestamp}_$random';
  }

  /// Generate a unique idempotency key for financial operations
  String _generateIdempotencyKey(String operation) {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final randomPart = base64Url.encode(bytes).replaceAll('=', '');
    return 'idem_${operation}_${DateTime.now().millisecondsSinceEpoch}_$randomPart';
  }

  // ============================================================
  // MTN MOMO DIRECT API (For MTN users)
  // ============================================================

  /// Initialize MTN MoMo payment via direct API
  /// Use this for MTN users instead of Paystack
  Future<MobileMoneyPaymentResult> initializeMtnMomoPayment({
    required int amount,
    required String phoneNumber,
    required String userId,
    String? currency,
  }) async {
    try {
      final result = await _momoService.requestToPay(
        amount: amount,
        phoneNumber: phoneNumber,
        currency: currency,
      );

      if (result.success) {
        return MobileMoneyPaymentResult(
          success: true,
          reference: result.referenceId,
          status: result.status,
          message: result.message,
          completed: false, // Needs user approval
        );
      } else {
        // Use MoMo-specific error handler for better messages
        final errorMessage = ErrorHandler.getMomoUserFriendlyMessage(
          result.error ?? 'MTN MoMo payment failed',
        );
        return MobileMoneyPaymentResult(
          success: false,
          error: errorMessage,
        );
      }
    } catch (e) {
      // Use MoMo-specific error handler for better messages
      final errorMessage = ErrorHandler.getMomoUserFriendlyMessage(e);
      return MobileMoneyPaymentResult(
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Check MTN MoMo transaction status
  Future<MobileMoneyPaymentResult> checkMtnMomoStatus(String referenceId, {String type = 'collection'}) async {
    try {
      final result = await _momoService.checkStatus(
        referenceId: referenceId,
        type: type,
      );

      return MobileMoneyPaymentResult(
        success: result.success,
        reference: referenceId,
        status: result.status,
        completed: result.isSuccessful,
        error: result.error,
      );
    } catch (e) {
      return MobileMoneyPaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Initiate MTN MoMo withdrawal via direct API
  Future<WithdrawalResult> initiateMtnMomoWithdrawal({
    required int amount,
    required String phoneNumber,
    required String accountName,
    String? currency,
  }) async {
    try {
      final result = await _momoService.transfer(
        amount: amount,
        phoneNumber: phoneNumber,
        currency: currency,
      );

      if (result.success) {
        return WithdrawalResult(
          success: true,
          reference: result.referenceId,
          message: result.message,
        );
      } else {
        // Use MoMo-specific error handler for better messages
        final errorMessage = ErrorHandler.getMomoUserFriendlyMessage(
          result.error ?? 'MTN MoMo withdrawal failed',
        );
        return WithdrawalResult(
          success: false,
          error: errorMessage,
        );
      }
    } catch (e) {
      // Use MoMo-specific error handler for better messages
      final errorMessage = ErrorHandler.getMomoUserFriendlyMessage(e);
      return WithdrawalResult(
        success: false,
        error: errorMessage,
      );
    }
  }
}

// ============================================================
// MODELS
// ============================================================

class PaymentResult {
  final bool success;
  final String? reference;
  final String? error;
  final bool pending;

  PaymentResult._({
    required this.success,
    this.reference,
    this.error,
    this.pending = false,
  });

  factory PaymentResult.success(String reference) =>
      PaymentResult._(success: true, reference: reference);

  factory PaymentResult.pending(String reference) =>
      PaymentResult._(success: false, reference: reference, pending: true);

  factory PaymentResult.failure(String error) =>
      PaymentResult._(success: false, error: error);
}

class PaymentVerificationResult {
  final bool success;
  final String reference;
  final int amount;
  final String? error;

  PaymentVerificationResult({
    required this.success,
    required this.reference,
    this.amount = 0,
    this.error,
  });
}

class Bank {
  final String name;
  final String code;
  final String type;

  Bank({required this.name, required this.code, required this.type});
}

class BankAccountVerification {
  final bool success;
  final String? accountName;
  final String? accountNumber;
  final String? error;

  BankAccountVerification({
    required this.success,
    this.accountName,
    this.accountNumber,
    this.error,
  });
}

class WithdrawalResult {
  final bool success;
  final String? reference;
  final String? message;
  final String? error;
  final bool requiresOtp;
  final String? transferCode;

  WithdrawalResult({
    required this.success,
    this.reference,
    this.message,
    this.error,
    this.requiresOtp = false,
    this.transferCode,
  });
}

class MobileMoneyProvider {
  final String name;
  final String code;

  MobileMoneyProvider({required this.name, required this.code});

  /// Get available mobile money providers for a given country.
  /// Returns providers for both Paystack-routed and MTN MoMo Direct API countries.
  static List<MobileMoneyProvider> getProviders(String country) {
    switch (country.toLowerCase()) {
      // ── Paystack-supported MoMo countries ──
      case 'ghana':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
          MobileMoneyProvider(name: 'Vodafone Cash', code: 'VOD'),
          MobileMoneyProvider(name: 'AirtelTigo Money', code: 'ATL'),
        ];
      case 'kenya':
        return [
          MobileMoneyProvider(name: 'M-Pesa', code: 'MPESA'),
        ];

      // ── MTN MoMo Direct API countries ──
      case 'uganda':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
          MobileMoneyProvider(name: 'Airtel Money', code: 'AIRTEL'),
        ];
      case 'rwanda':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'cameroon':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
          MobileMoneyProvider(name: 'Orange Money', code: 'ORANGE'),
        ];
      case 'benin':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'ivory coast':
      case 'cote d\'ivoire':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
          MobileMoneyProvider(name: 'Orange Money', code: 'ORANGE'),
        ];
      case 'congo':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'guinea':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'liberia':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'zambia':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'south africa':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'eswatini':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'south sudan':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'guinea-bissau':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'sierra leone':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'nigeria':
        return [
          MobileMoneyProvider(name: 'MTN MoMo PSB', code: 'MTN'),
        ];
      case 'dr congo':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      case 'sudan':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
        ];
      default:
        return [];
    }
  }

  /// Maps a currency code to a country name for payment routing.
  ///
  /// IMPORTANT: Some currencies (XAF, XOF) are shared by multiple countries.
  /// For those, this returns the most common MTN country for that currency.
  /// For precise routing when a user's ISO country code is available,
  /// use [getCountryFromIsoCode] instead.
  static String getCountryFromCurrency(String currencyCode) {
    const map = {
      // Paystack countries
      'NGN': 'nigeria',
      'GHS': 'ghana',
      'KES': 'kenya',
      // MTN MoMo Direct API countries
      'UGX': 'uganda',
      'RWF': 'rwanda',
      'XAF': 'cameroon',     // Also: Congo, Gabon, Chad, CAR, Eq. Guinea
      'XOF': 'ivory coast',  // Also: Benin, Senegal, Togo, Guinea-Bissau, etc.
      'ZAR': 'south africa',
      'ZMW': 'zambia',
      'GNF': 'guinea',
      'LRD': 'liberia',
      'SZL': 'eswatini',
      'SSP': 'south sudan',
      'SLL': 'sierra leone',
      'CDF': 'dr congo',
      'SDG': 'sudan',
    };
    return map[currencyCode.toUpperCase()] ?? 'nigeria';
  }

  /// Maps an ISO 3166-1 alpha-2 country code to a country name.
  /// More precise than [getCountryFromCurrency] for shared-currency regions.
  static String getCountryFromIsoCode(String isoCode) {
    const map = {
      'GH': 'ghana',
      'NG': 'nigeria',
      'KE': 'kenya',
      'UG': 'uganda',
      'RW': 'rwanda',
      'CM': 'cameroon',
      'BJ': 'benin',
      'CI': 'ivory coast',
      'CG': 'congo',
      'GN': 'guinea',
      'LR': 'liberia',
      'ZM': 'zambia',
      'ZA': 'south africa',
      'SZ': 'eswatini',
      'SS': 'south sudan',
      'GW': 'guinea-bissau',
      'SL': 'sierra leone',
      'CD': 'dr congo',
      'SD': 'sudan',
      // Non-MTN African countries (for bank routing)
      'TZ': 'tanzania',
      'ET': 'ethiopia',
      'EG': 'egypt',
      'MA': 'morocco',
      'DZ': 'algeria',
      'TN': 'tunisia',
      'ZW': 'zimbabwe',
      'BW': 'botswana',
      'NA': 'namibia',
      'MZ': 'mozambique',
      'AO': 'angola',
      'LY': 'libya',
      'SN': 'senegal',
    };
    return map[isoCode.toUpperCase()] ?? 'nigeria';
  }
}

class MobileMoneyPaymentResult {
  final bool success;
  final String? reference;
  final String? message;
  final String? status;
  final String? error;
  final bool completed;

  MobileMoneyPaymentResult({
    required this.success,
    this.reference,
    this.message,
    this.status,
    this.error,
    this.completed = false,
  });
}

class VirtualAccountResult {
  final bool success;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? note;
  final String? error;

  VirtualAccountResult({
    required this.success,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.note,
    this.error,
  });
}
