import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

import 'wallet_service.dart';

/// Payment service handling Paystack integration via Cloud Functions
class PaymentService {
  final WalletService _walletService = WalletService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      final callable = _functions.httpsCallable('chargeMobileMoney');
      final result = await callable.call({
        'email': email,
        'amount': amount,
        'currency': currency,
        'provider': provider,
        'phoneNumber': phoneNumber,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return MobileMoneyPaymentResult(
          success: true,
          reference: data['reference'] as String?,
          message: data['message'] as String?,
          status: data['status'] as String?,
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
    required double amount,
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final callable = _functions.httpsCallable('initiateWithdrawal');
      final result = await callable.call({
        'amount': amount,
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'type': 'bank',
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
          error: data['error'] as String? ?? 'Withdrawal failed',
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
      final callable = _functions.httpsCallable('initiateWithdrawal');
      final result = await callable.call({
        'amount': amount,
        'mobileMoneyProvider': provider,
        'phoneNumber': phoneNumber,
        'accountName': accountName,
        'type': 'mobile_money',
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
          error: data['error'] as String? ?? 'Withdrawal failed',
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
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'QRW_${timestamp}_$random';
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

  WithdrawalResult({
    required this.success,
    this.reference,
    this.message,
    this.error,
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

  MobileMoneyPaymentResult({
    required this.success,
    this.reference,
    this.message,
    this.status,
    this.error,
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
