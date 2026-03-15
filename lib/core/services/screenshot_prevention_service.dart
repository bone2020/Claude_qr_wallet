import 'package:flutter/foundation.dart';
import 'package:no_screenshot/no_screenshot.dart';

class ScreenshotPreventionService {
  static final ScreenshotPreventionService _instance = ScreenshotPreventionService._internal();
  factory ScreenshotPreventionService() => _instance;
  ScreenshotPreventionService._internal();

  final _noScreenshot = NoScreenshot.instance;
  bool _isEnabled = false;
  int _refCount = 0;

  Future<void> enableProtection() async {
    _refCount++;
    if (_isEnabled) return;

    try {
      await _noScreenshot.screenshotOff();
      _isEnabled = true;
      debugPrint('Screenshot protection enabled (refCount: $_refCount)');
    } catch (e) {
      debugPrint('Failed to enable screenshot protection: $e');
    }
  }

  Future<void> disableProtection() async {
    _refCount--;
    if (_refCount < 0) _refCount = 0;

    if (_refCount > 0) {
      debugPrint('Screenshot protection still active (refCount: $_refCount)');
      return;
    }

    if (!_isEnabled) return;

    try {
      await _noScreenshot.screenshotOn();
      _isEnabled = false;
      debugPrint('Screenshot protection disabled (refCount: 0)');
    } catch (e) {
      debugPrint('Failed to disable screenshot protection: $e');
    }
  }

  bool get isEnabled => _isEnabled;
}
