import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';

/// Service to prevent screenshots on sensitive screens
/// Uses FLAG_SECURE on Android and screen recording prevention on iOS
class ScreenshotPreventionService {
  static final ScreenshotPreventionService _instance =
      ScreenshotPreventionService._internal();

  factory ScreenshotPreventionService() => _instance;

  ScreenshotPreventionService._internal();

  final _noScreenshot = NoScreenshot.instance;
  bool _isEnabled = false;

  /// Check if screenshot prevention is currently enabled
  bool get isEnabled => _isEnabled;

  /// Enable screenshot prevention (call when entering sensitive screens)
  Future<void> enableProtection() async {
    if (_isEnabled) return;

    try {
      await _noScreenshot.screenshotOff();
      _isEnabled = true;
      debugPrint('Screenshot prevention enabled');
    } catch (e) {
      debugPrint('Failed to enable screenshot prevention: $e');
    }
  }

  /// Disable screenshot prevention (call when leaving sensitive screens)
  Future<void> disableProtection() async {
    if (!_isEnabled) return;

    try {
      await _noScreenshot.screenshotOn();
      _isEnabled = false;
      debugPrint('Screenshot prevention disabled');
    } catch (e) {
      debugPrint('Failed to disable screenshot prevention: $e');
    }
  }

  /// Toggle screenshot prevention
  Future<void> toggle() async {
    if (_isEnabled) {
      await disableProtection();
    } else {
      await enableProtection();
    }
  }
}

/// Mixin to easily add screenshot prevention to StatefulWidgets
///
/// Usage:
/// ```dart
/// class MySecureScreen extends StatefulWidget {
///   @override
///   State<MySecureScreen> createState() => _MySecureScreenState();
/// }
///
/// class _MySecureScreenState extends State<MySecureScreen>
///     with ScreenshotPreventionMixin {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(...);
///   }
/// }
/// ```
mixin ScreenshotPreventionMixin<T extends StatefulWidget> on State<T> {
  final _screenshotService = ScreenshotPreventionService();

  @override
  void initState() {
    super.initState();
    _screenshotService.enableProtection();
  }

  @override
  void dispose() {
    _screenshotService.disableProtection();
    super.dispose();
  }
}

/// Wrapper widget to enable screenshot prevention for any child widget
/// Use this to wrap sensitive screens in the router
///
/// Usage in GoRouter:
/// ```dart
/// GoRoute(
///   path: '/sensitive',
///   builder: (context, state) => ScreenshotProtectedScreen(
///     child: MySensitiveScreen(),
///   ),
/// ),
/// ```
class ScreenshotProtectedScreen extends StatefulWidget {
  final Widget child;

  const ScreenshotProtectedScreen({
    super.key,
    required this.child,
  });

  @override
  State<ScreenshotProtectedScreen> createState() =>
      _ScreenshotProtectedScreenState();
}

class _ScreenshotProtectedScreenState extends State<ScreenshotProtectedScreen>
    with WidgetsBindingObserver {
  final _screenshotService = ScreenshotPreventionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenshotService.enableProtection();
  }

  @override
  void dispose() {
    _screenshotService.disableProtection();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-enable protection when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _screenshotService.enableProtection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
