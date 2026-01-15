import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for signing and verifying QR code payloads
/// Uses HMAC-SHA256 via Cloud Functions for security
class QrSigningService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Sign a QR payload for payment requests
  /// Returns signed payload with expiration
  Future<SignedQrPayload> signPayload({
    required String walletId,
    double? amount,
    String? note,
  }) async {
    try {
      final callable = _functions.httpsCallable('signQrPayload');
      final result = await callable.call<Map<String, dynamic>>({
        'walletId': walletId,
        'amount': amount,
        'note': note ?? '',
      });

      final data = result.data;
      return SignedQrPayload(
        payload: data['payload'] as String,
        signature: data['signature'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int),
      );
    } catch (e) {
      throw QrSigningException('Failed to sign QR payload: $e');
    }
  }

  /// Verify a scanned QR signature
  /// Returns verification result with parsed data
  Future<QrVerificationResult> verifySignature({
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
        return QrVerificationResult.valid(
          walletId: data['walletId'] as String,
          amount: (data['amount'] as num?)?.toDouble(),
          note: data['note'] as String?,
        );
      } else {
        return QrVerificationResult.invalid(
          reason: data['reason'] as String? ?? 'Verification failed',
        );
      }
    } catch (e) {
      return QrVerificationResult.invalid(reason: 'Verification failed: $e');
    }
  }

  /// Generate QR data string from signed payload
  String generateQrData(SignedQrPayload signed) {
    final qrData = {
      'p': signed.payload,
      's': signed.signature,
      'v': 2, // Version 2 = signed QR
    };
    return jsonEncode(qrData);
  }

  /// Parse QR data string to extract payload and signature
  /// Returns null if format is invalid or unsigned (v1)
  ParsedQrData? parseQrData(String qrData) {
    try {
      final decoded = jsonDecode(qrData);

      // Check if this is a signed QR (v2)
      if (decoded is Map && decoded['v'] == 2) {
        return ParsedQrData(
          payload: decoded['p'] as String,
          signature: decoded['s'] as String,
          isSigned: true,
        );
      }

      // Legacy unsigned QR (v1 or no version)
      return ParsedQrData(
        payload: qrData,
        signature: '',
        isSigned: false,
      );
    } catch (e) {
      // Try parsing as legacy format (just wallet ID)
      return ParsedQrData(
        payload: qrData,
        signature: '',
        isSigned: false,
      );
    }
  }
}

/// Signed QR payload result
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

/// QR verification result
class QrVerificationResult {
  final bool isValid;
  final String? walletId;
  final double? amount;
  final String? note;
  final String? reason;

  QrVerificationResult._({
    required this.isValid,
    this.walletId,
    this.amount,
    this.note,
    this.reason,
  });

  factory QrVerificationResult.valid({
    required String walletId,
    double? amount,
    String? note,
  }) {
    return QrVerificationResult._(
      isValid: true,
      walletId: walletId,
      amount: amount,
      note: note,
    );
  }

  factory QrVerificationResult.invalid({required String reason}) {
    return QrVerificationResult._(
      isValid: false,
      reason: reason,
    );
  }
}

/// Parsed QR data
class ParsedQrData {
  final String payload;
  final String signature;
  final bool isSigned;

  ParsedQrData({
    required this.payload,
    required this.signature,
    required this.isSigned,
  });
}

/// Custom exception for QR signing operations
class QrSigningException implements Exception {
  final String message;
  QrSigningException(this.message);

  @override
  String toString() => message;
}
