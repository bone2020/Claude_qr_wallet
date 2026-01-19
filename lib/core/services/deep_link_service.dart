import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Service to handle deep links for payment redirects
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GoRouter? _router;
  
  // Store pending deep link if router isn't ready
  Uri? _pendingDeepLink;

  /// Initialize deep link handling with router
  void init(GoRouter router) {
    _router = router;
    
    // Process any pending deep link
    if (_pendingDeepLink != null) {
      final pending = _pendingDeepLink;
      _pendingDeepLink = null;
      _processDeepLink(pending!);
    }
    
    _handleInitialLink();
    _handleIncomingLinks();
  }

  /// Dispose of subscriptions
  void dispose() {
    _subscription?.cancel();
  }

  /// Handle initial link when app is launched from deep link
  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _processDeepLink(uri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  /// Handle incoming links while app is running
  void _handleIncomingLinks() {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _processDeepLink(uri),
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  /// Process the deep link and navigate accordingly
  void _processDeepLink(Uri uri) {
    debugPrint('=== DEEP LINK RECEIVED ===');
    debugPrint('URI: $uri');
    debugPrint('Scheme: ${uri.scheme}, Host: ${uri.host}');
    debugPrint('Path: ${uri.path}');
    debugPrint('Query: ${uri.queryParameters}');
    debugPrint('Router available: ${_router != null}');

    if (_router == null) {
      debugPrint('Router not ready, storing pending deep link');
      _pendingDeepLink = uri;
      return;
    }

    // Handle payment callback: qrwallet://payment/success?reference=xxx
    if (uri.scheme == 'qrwallet' && uri.host == 'payment') {
      _handlePaymentCallback(uri);
    }

    // Handle pay QR: qrwallet://pay?id=xxx&name=xxx&amount=xxx
    if (uri.scheme == 'qrwallet' && uri.host == 'pay') {
      _handlePayQRCallback(uri);
    }
  }

  void _handlePaymentCallback(Uri uri) {
    final reference = uri.queryParameters['reference'];
    final trxref = uri.queryParameters['trxref'];
    final status = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    final paymentReference = reference ?? trxref;

    debugPrint('Payment callback - Reference: $paymentReference, Status: $status');

    if (paymentReference == null) {
      debugPrint('ERROR: No payment reference found');
      return;
    }

    // Delay navigation slightly to ensure app is fully resumed
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        debugPrint('Navigating to /payment-result...');
        _router?.push('/payment-result', extra: {
          'reference': paymentReference,
          'status': status,
        });
        debugPrint('Navigation successful');
      } catch (e, stack) {
        debugPrint('Navigation ERROR: $e');
        debugPrint('Stack: $stack');
      }
    });
  }

  void _handlePayQRCallback(Uri uri) {
    final walletId = uri.queryParameters['id'];
    final name = uri.queryParameters['name'];
    final amount = uri.queryParameters['amount'];
    final currency = uri.queryParameters['currency'];
    final note = uri.queryParameters['note'];

    // SECURITY: Validate wallet ID format to prevent injection
    if (walletId == null || !_isValidWalletIdFormat(walletId)) {
      debugPrint('ERROR: Invalid or missing wallet ID in deep link');
      return;
    }

    // SECURITY: Validate amount is a reasonable positive number
    double? parsedAmount;
    if (amount != null) {
      parsedAmount = double.tryParse(amount);
      if (parsedAmount == null || parsedAmount < 0 || parsedAmount > 10000000) {
        debugPrint('ERROR: Invalid amount in deep link: $amount');
        parsedAmount = null; // Reset to null for safety
      }
    }

    // SECURITY: Sanitize name to prevent XSS-like issues
    final sanitizedName = _sanitizeString(name ?? 'Unknown');
    final sanitizedNote = note != null ? _sanitizeString(note) : null;

    // SECURITY: Validate currency code format (3 uppercase letters)
    String? validatedCurrency;
    if (currency != null && RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      validatedCurrency = currency;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        _router?.push('/confirm-send', extra: {
          'recipientWalletId': walletId,
          'recipientName': sanitizedName,
          'amount': parsedAmount ?? 0.0,
          'note': sanitizedNote,
          'fromScan': true,
          'amountLocked': parsedAmount != null && parsedAmount > 0,
          'recipientCurrency': validatedCurrency,
        });
      } catch (e) {
        debugPrint('Navigation ERROR: $e');
      }
    });
  }

  /// Validate wallet ID format (QRW-XXXX-XXXX-XXXX or legacy QRW-XXXXX-XXXXX)
  bool _isValidWalletIdFormat(String id) {
    // New format: QRW-XXXX-XXXX-XXXX (alphanumeric)
    final newFormat = RegExp(r'^QRW-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    // Legacy format: QRW-XXXXX-XXXXX (numeric)
    final legacyFormat = RegExp(r'^QRW-\d{5}-\d{5}$');
    return newFormat.hasMatch(id) || legacyFormat.hasMatch(id);
  }

  /// Sanitize string to remove potentially dangerous characters
  String _sanitizeString(String input) {
    // Remove any HTML-like tags and limit length
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp("[<>\"']"), '')
        .substring(0, input.length > 100 ? 100 : input.length)
        .trim();
  }

  /// Update router reference
  void setRouter(GoRouter router) {
    _router = router;
    
    // Process pending deep link if any
    if (_pendingDeepLink != null) {
      final pending = _pendingDeepLink;
      _pendingDeepLink = null;
      _processDeepLink(pending!);
    }
  }
}
