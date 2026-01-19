import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class QrSigningService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<SignedQrPayload?> signQrPayload({
    required String walletId,
    double? amount,
    String? note,
  }) async {
    try {
      final callable = _functions.httpsCallable('signQrPayload');
      final result = await callable.call<Map<String, dynamic>>({
        'walletId': walletId,
        'amount': amount ?? 0,
        'note': note ?? '',
      });

      return SignedQrPayload(
        payload: result.data['payload'] as String,
        signature: result.data['signature'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          result.data['expiresAt'] as int,
        ),
      );
    } catch (e) {
      debugPrint('Error signing QR payload: $e');
      return null;
    }
  }

  static Future<QrVerificationResult> verifyQrSignature({
    required String payload,
    required String signature,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyQrSignature');
      final result = await callable.call<Map<String, dynamic>>({
        'payload': payload,
        'signature': signature,
      });

      final data = result.data;
      
      if (data['valid'] == true) {
        return QrVerificationResult(
          isValid: true,
          walletId: data['walletId'] as String?,
          amount: (data['amount'] as num?)?.toDouble(),
          note: data['note'] as String?,
          recipientName: data['recipientName'] as String?,
          profilePhotoUrl: data['profilePhotoUrl'] as String?,
        );
      } else {
        return QrVerificationResult(
          isValid: false,
          errorReason: data['reason'] as String? ?? 'Verification failed',
        );
      }
    } catch (e) {
      debugPrint('Error verifying QR signature: $e');
      return QrVerificationResult(
        isValid: false,
        errorReason: 'Verification error: $e',
      );
    }
  }

  static String generateSignedQrData(SignedQrPayload signedPayload) {
    final data = {
      'p': signedPayload.payload,
      's': signedPayload.signature,
    };
    return 'qrwallet://pay?signed=${Uri.encodeComponent(jsonEncode(data))}';
  }

  static Map<String, String>? parseSignedQrData(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      final signedParam = uri.queryParameters['signed'];
      
      if (signedParam != null) {
        final decoded = jsonDecode(Uri.decodeComponent(signedParam));
        return {
          'payload': decoded['p'] as String,
          'signature': decoded['s'] as String,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing signed QR data: $e');
      return null;
    }
  }
}

class SignedQrPayload {
  final String payload;
  final String signature;
  final DateTime expiresAt;

  SignedQrPayload({
    required this.payload,
    required this.signature,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class QrVerificationResult {
  final bool isValid;
  final String? walletId;
  final double? amount;
  final String? note;
  final String? recipientName;
  final String? profilePhotoUrl;
  final String? errorReason;

  QrVerificationResult({
    required this.isValid,
    this.walletId,
    this.amount,
    this.note,
    this.recipientName,
    this.profilePhotoUrl,
    this.errorReason,
  });
}