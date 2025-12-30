import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'dart:math';

import 'wallet_service.dart';

/// Payment service handling Paystack integration
class PaymentService {
  final WalletService _walletService = WalletService();

  // ============================================================
  // PAYSTACK CONFIGURATION
  // ============================================================

  /// Paystack public key - Replace with your actual key
  static const String _publicKey = 'pk_test_your_public_key_here';

  /// Paystack secret key (for server-side operations)
  /// NOTE: Never use secret key in client app - use backend API
  static const String _secretKey = 'sk_test_your_secret_key_here';

  // ============================================================
  // PAYMENT OPERATIONS
  // ============================================================

  /// Initialize payment for adding money to wallet
  Future<PaymentResult> initializePayment({
    required BuildContext context,
    required String email,
    required double amount,
    String? metadata,
  }) async {
    try {
      // Convert amount to kobo (Paystack uses smallest currency unit)
      final amountInKobo = (amount * 100).round();

      // Generate unique reference
      final reference = _generateReference();

      // Show Paystack checkout
      await FlutterPaystackPlus.openPaystackPopup(
        publicKey: _publicKey,
        customerEmail: email,
        amount: amountInKobo.toString(),
        reference: reference,
        currency: 'NGN',
        onClosed: () {
          // User closed the popup without completing payment
        },
        onSuccess: () async {
          // Payment successful - verify and credit wallet
          final verificationResult = await _verifyPayment(reference);
          
          if (verificationResult.success) {
            // Credit wallet
            await _walletService.addMoney(
              amount: amount,
              paymentReference: reference,
              bankName: 'Card Payment',
            );
          }
        },
        context: context,
      );

      return PaymentResult.pending(reference);
    } catch (e) {
      return PaymentResult.failure('Payment initialization failed: $e');
    }
  }

  /// Alternative: Charge card directly (for saved cards)
  Future<PaymentResult> chargeCard({
    required String email,
    required double amount,
    required String cardNumber,
    required String cvv,
    required int expiryMonth,
    required int expiryYear,
  }) async {
    try {
      // NOTE: In production, card charging should be done server-side
      // This is just a placeholder showing the flow

      final reference = _generateReference();
      final amountInKobo = (amount * 100).round();

      // In real implementation:
      // 1. Send card details to your backend
      // 2. Backend calls Paystack Charge API
      // 3. Handle OTP/PIN/3DS if required
      // 4. Return result

      return PaymentResult.pending(reference);
    } catch (e) {
      return PaymentResult.failure('Card charge failed: $e');
    }
  }

  /// Verify payment status
  Future<PaymentVerificationResult> _verifyPayment(String reference) async {
    try {
      // NOTE: Payment verification should be done server-side
      // Your backend should:
      // 1. Call Paystack Verify Transaction API
      // 2. Check if status is "success"
      // 3. Return result to app

      // Placeholder - assume success for now
      return PaymentVerificationResult(
        success: true,
        reference: reference,
        amount: 0, // Would come from verification response
      );
    } catch (e) {
      return PaymentVerificationResult(
        success: false,
        reference: reference,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // BANK TRANSFER (Virtual Account)
  // ============================================================

  /// Create dedicated virtual account for user
  Future<VirtualAccountResult> createVirtualAccount({
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    try {
      // NOTE: This should be called from your backend
      // Paystack creates a dedicated NUBAN for the user
      // Any transfer to this account auto-credits their wallet

      // API: POST https://api.paystack.co/dedicated_account
      // Requires: customer code, preferred_bank

      return VirtualAccountResult(
        success: true,
        accountNumber: '0123456789', // Would come from API response
        accountName: '$firstName $lastName',
        bankName: 'Wema Bank',
      );
    } catch (e) {
      return VirtualAccountResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // WITHDRAWAL (Transfer to Bank)
  // ============================================================

  /// Initiate transfer to user's bank account
  Future<PaymentResult> initiateWithdrawal({
    required double amount,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    String? narration,
  }) async {
    try {
      // NOTE: Withdrawals must be done server-side
      // Your backend should:
      // 1. Verify user has sufficient balance
      // 2. Create transfer recipient if not exists
      // 3. Initiate transfer via Paystack
      // 4. Deduct from wallet on success

      final reference = _generateReference();

      // API flow:
      // 1. POST /transferrecipient (create recipient)
      // 2. POST /transfer (initiate transfer)

      return PaymentResult.pending(reference);
    } catch (e) {
      return PaymentResult.failure('Withdrawal failed: $e');
    }
  }

  /// Get list of Nigerian banks
  Future<List<Bank>> getBankList() async {
    // Paystack Bank List API
    // GET https://api.paystack.co/bank

    // Hardcoded common banks for now
    return [
      Bank(code: '044', name: 'Access Bank'),
      Bank(code: '023', name: 'Citibank Nigeria'),
      Bank(code: '050', name: 'Ecobank Nigeria'),
      Bank(code: '070', name: 'Fidelity Bank'),
      Bank(code: '011', name: 'First Bank of Nigeria'),
      Bank(code: '214', name: 'First City Monument Bank'),
      Bank(code: '058', name: 'Guaranty Trust Bank'),
      Bank(code: '030', name: 'Heritage Bank'),
      Bank(code: '301', name: 'Jaiz Bank'),
      Bank(code: '082', name: 'Keystone Bank'),
      Bank(code: '526', name: 'Parallex Bank'),
      Bank(code: '076', name: 'Polaris Bank'),
      Bank(code: '101', name: 'Providus Bank'),
      Bank(code: '221', name: 'Stanbic IBTC Bank'),
      Bank(code: '068', name: 'Standard Chartered Bank'),
      Bank(code: '232', name: 'Sterling Bank'),
      Bank(code: '100', name: 'Suntrust Bank'),
      Bank(code: '032', name: 'Union Bank of Nigeria'),
      Bank(code: '033', name: 'United Bank for Africa'),
      Bank(code: '215', name: 'Unity Bank'),
      Bank(code: '035', name: 'Wema Bank'),
      Bank(code: '057', name: 'Zenith Bank'),
    ];
  }

  /// Verify bank account
  Future<BankAccountVerification> verifyBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      // API: GET https://api.paystack.co/bank/resolve
      // ?account_number={account_number}&bank_code={bank_code}

      // Placeholder response
      return BankAccountVerification(
        success: true,
        accountNumber: accountNumber,
        accountName: 'John Doe', // Would come from API
        bankCode: bankCode,
      );
    } catch (e) {
      return BankAccountVerification(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Generate unique payment reference
  String _generateReference() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return 'QRW_$timestamp$randomPart';
  }
}

// ============================================================
// DATA CLASSES
// ============================================================

/// Payment result wrapper
class PaymentResult {
  final bool success;
  final bool pending;
  final String? reference;
  final String? error;

  PaymentResult._({
    this.success = false,
    this.pending = false,
    this.reference,
    this.error,
  });

  factory PaymentResult.success(String reference) {
    return PaymentResult._(success: true, reference: reference);
  }

  factory PaymentResult.pending(String reference) {
    return PaymentResult._(pending: true, reference: reference);
  }

  factory PaymentResult.failure(String error) {
    return PaymentResult._(error: error);
  }
}

/// Payment verification result
class PaymentVerificationResult {
  final bool success;
  final String reference;
  final double? amount;
  final String? error;

  PaymentVerificationResult({
    required this.success,
    required this.reference,
    this.amount,
    this.error,
  });
}

/// Virtual account result
class VirtualAccountResult {
  final bool success;
  final String? accountNumber;
  final String? accountName;
  final String? bankName;
  final String? error;

  VirtualAccountResult({
    required this.success,
    this.accountNumber,
    this.accountName,
    this.bankName,
    this.error,
  });
}

/// Bank model
class Bank {
  final String code;
  final String name;

  Bank({required this.code, required this.name});
}

/// Bank account verification result
class BankAccountVerification {
  final bool success;
  final String? accountNumber;
  final String? accountName;
  final String? bankCode;
  final String? error;

  BankAccountVerification({
    required this.success,
    this.accountNumber,
    this.accountName,
    this.bankCode,
    this.error,
  });
}
