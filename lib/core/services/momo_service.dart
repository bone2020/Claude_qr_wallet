import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// MTN MoMo API Service for direct mobile money integration
class MomoService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Generate a unique idempotency key for financial operations
  String _generateIdempotencyKey(String operation) {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final randomPart = base64Url.encode(bytes).replaceAll('=', '');
    return 'idem_${operation}_${DateTime.now().millisecondsSinceEpoch}_$randomPart';
  }

  // ============================================================
  // COLLECTIONS - REQUEST TO PAY (Add Money)
  // ============================================================

  /// Request payment from user's MoMo wallet
  /// Returns referenceId to check status
  Future<MomoPaymentResult> requestToPay({
    required double amount,
    required String phoneNumber,
    String? currency,
    String? payerMessage,
  }) async {
    try {
      final idempotencyKey = _generateIdempotencyKey('momoRequestToPay');
      final callable = _functions.httpsCallable('momoRequestToPay');
      final result = await callable.call({
        'amount': amount,
        'currency': currency ?? 'EUR', // Sandbox uses EUR
        'phoneNumber': phoneNumber,
        'payerMessage': payerMessage ?? 'Add money to QR Wallet',
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return MomoPaymentResult(
          success: true,
          referenceId: data['referenceId'] as String?,
          status: data['status'] as String?,
          message: data['message'] as String?,
        );
      } else {
        return MomoPaymentResult(
          success: false,
          error: data['error'] as String? ?? 'Payment request failed',
        );
      }
    } catch (e) {
      debugPrint('MoMo requestToPay error: $e');
      return MomoPaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // DISBURSEMENTS - TRANSFER (Withdraw)
  // ============================================================

  /// Transfer money to user's MoMo wallet
  Future<MomoPaymentResult> transfer({
    required double amount,
    required String phoneNumber,
    String? currency,
    String? payeeNote,
  }) async {
    try {
      final idempotencyKey = _generateIdempotencyKey('momoTransfer');
      final callable = _functions.httpsCallable('momoTransfer');
      final result = await callable.call({
        'amount': amount,
        'currency': currency ?? 'EUR', // Sandbox uses EUR
        'phoneNumber': phoneNumber,
        'payeeNote': payeeNote ?? 'Withdrawal from QR Wallet',
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return MomoPaymentResult(
          success: true,
          referenceId: data['referenceId'] as String?,
          status: data['status'] as String?,
          message: data['message'] as String?,
        );
      } else {
        return MomoPaymentResult(
          success: false,
          error: data['error'] as String? ?? 'Transfer failed',
        );
      }
    } catch (e) {
      debugPrint('MoMo transfer error: $e');
      return MomoPaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // CHECK TRANSACTION STATUS
  // ============================================================

  /// Check the status of a MoMo transaction
  Future<MomoStatusResult> checkStatus({
    required String referenceId,
    required String type, // 'collection' or 'disbursement'
  }) async {
    try {
      final callable = _functions.httpsCallable('momoCheckStatus');
      final result = await callable.call({
        'referenceId': referenceId,
        'type': type,
      });

      final data = result.data as Map<String, dynamic>;

      return MomoStatusResult(
        success: data['success'] as bool? ?? false,
        status: data['status'] as String?,
        data: data['data'] as Map<String, dynamic>?,
        error: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('MoMo checkStatus error: $e');
      return MomoStatusResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // GET BALANCE (Admin/Debug)
  // ============================================================

  /// Get MoMo account balance (for debugging)
  Future<MomoBalanceResult> getBalance({String product = 'collection'}) async {
    try {
      final callable = _functions.httpsCallable('momoGetBalance');
      final result = await callable.call({'product': product});

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final balance = data['balance'] as Map<String, dynamic>?;
        return MomoBalanceResult(
          success: true,
          availableBalance: double.tryParse(balance?['availableBalance']?.toString() ?? '0'),
          currency: balance?['currency'] as String?,
        );
      } else {
        return MomoBalanceResult(success: false, error: 'Failed to get balance');
      }
    } catch (e) {
      debugPrint('MoMo getBalance error: $e');
      return MomoBalanceResult(success: false, error: e.toString());
    }
  }

  // ============================================================
  // HELPER - CHECK IF MTN MOMO IS AVAILABLE
  // ============================================================

  /// Check if MTN MoMo direct API is available for the given country
  static bool isAvailable(String country) {
    const mtnCountries = [
      'ghana', 'uganda', 'rwanda', 'cameroon', 'benin',
      'ivory coast', 'cote d\'ivoire', 'congo', 'guinea',
      'liberia', 'zambia', 'south africa', 'eswatini',
      'south sudan', 'guinea-bissau',
    ];
    return mtnCountries.contains(country.toLowerCase());
  }

  /// Check if provider is MTN
  static bool isMtnProvider(String providerCode) {
    return providerCode.toUpperCase() == 'MTN';
  }
}

// ============================================================
// RESULT MODELS
// ============================================================

class MomoPaymentResult {
  final bool success;
  final String? referenceId;
  final String? status;
  final String? message;
  final String? error;

  MomoPaymentResult({
    required this.success,
    this.referenceId,
    this.status,
    this.message,
    this.error,
  });
}

class MomoStatusResult {
  final bool success;
  final String? status;
  final Map<String, dynamic>? data;
  final String? error;

  MomoStatusResult({
    required this.success,
    this.status,
    this.data,
    this.error,
  });

  bool get isSuccessful => status == 'SUCCESSFUL';
  bool get isPending => status == 'PENDING';
  bool get isFailed => status == 'FAILED';
}

class MomoBalanceResult {
  final bool success;
  final double? availableBalance;
  final String? currency;
  final String? error;

  MomoBalanceResult({
    required this.success,
    this.availableBalance,
    this.currency,
    this.error,
  });
}
