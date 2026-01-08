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
  BuildContext? _context;

  /// Initialize deep link handling
  void init(BuildContext context) {
    _context = context;
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
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _processDeepLink(uri),
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  /// Process the deep link and navigate accordingly
  void _processDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');

    // Handle payment callback: qrwallet://payment/success?reference=xxx
    if (uri.scheme == 'qrwallet' && uri.host == 'payment') {
      final reference = uri.queryParameters['reference'];
      final trxref = uri.queryParameters['trxref'];
      final status = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;

      final paymentReference = reference ?? trxref;

      if (paymentReference != null && _context != null) {
        _context!.push('/payment-result', extra: {
          'reference': paymentReference,
          'status': status,
        });
      }
    }

    // Handle pay QR: qrwallet://pay?id=xxx&name=xxx&amount=xxx
    if (uri.scheme == 'qrwallet' && uri.host == 'pay') {
      final walletId = uri.queryParameters['id'];
      final name = uri.queryParameters['name'];
      final amount = uri.queryParameters['amount'];
      final currency = uri.queryParameters['currency'];
      final note = uri.queryParameters['note'];

      if (walletId != null && _context != null) {
        _context!.push('/confirm-send', extra: {
          'recipientWalletId': walletId,
          'recipientName': name ?? 'Unknown',
          'amount': double.tryParse(amount ?? '0') ?? 0.0,
          'note': note,
          'fromScan': true,
          'amountLocked': amount != null && (double.tryParse(amount) ?? 0) > 0,
          'recipientCurrency': currency,
        });
      }
    }
  }

  /// Update context reference (call from build methods)
  void setContext(BuildContext context) {
    _context = context;
  }
}
