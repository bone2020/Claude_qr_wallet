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

    if (walletId == null) {
      debugPrint('ERROR: No wallet ID found in QR');
      return;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        _router?.push('/confirm-send', extra: {
          'recipientWalletId': walletId,
          'recipientName': name ?? 'Unknown',
          'amount': double.tryParse(amount ?? '0') ?? 0.0,
          'note': note,
          'fromScan': true,
          'amountLocked': amount != null && (double.tryParse(amount) ?? 0) > 0,
          'recipientCurrency': currency,
        });
      } catch (e) {
        debugPrint('Navigation ERROR: $e');
      }
    });
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
