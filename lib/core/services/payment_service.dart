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

  /// Paystack public key - safe to include in client
  static const String _publicKey = 'pk_test_a5d5b376b470ceabd388aea915744bed5bd0f36b';

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
    required double amount,
    required String userId,
    String? currency,
  }) async {
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
    required double amount,
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
                  currency: b['currency'] as String? ?? 'NGN',
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
    String country = 'ghana',
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyBankAccount');
      final result = await callable.call({
        'accountNumber': accountNumber,
        'bankCode': bankCode,
        'country': country,
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
    required double amount,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    String country = 'ghana',
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
        'country': country,
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
    required double amount,
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
    required double amount,
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
    required double amount,
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
  final double amount;
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
  final String currency;

  Bank({required this.name, required this.code, required this.type, required this.currency});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bank &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(code, currency);

  @override
  String toString() => 'Bank(name: $name, code: $code, type: $type, currency: $currency)';
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

  static List<MobileMoneyProvider> getProviders(String country) {
    switch (country.toLowerCase()) {
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
      case 'uganda':
        return [
          MobileMoneyProvider(name: 'MTN Mobile Money', code: 'MTN'),
          MobileMoneyProvider(name: 'Airtel Money', code: 'AIRTEL'),
        ];
      default:
        return [];
    }
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
