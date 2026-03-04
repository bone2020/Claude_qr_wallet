import 'package:flutter/foundation.dart';
import 'package:no_screenshot/no_screenshot.dart';

class ScreenshotPreventionService {
  static final ScreenshotPreventionService _instance = ScreenshotPreventionService._internal();
  factory ScreenshotPreventionService() => _instance;
  ScreenshotPreventionService._internal();

  final _noScreenshot = NoScreenshot.instance;
  bool _isEnabled = false;

  Future<void> enableProtection() async {
    if (_isEnabled) return;

    try {
      await _noScreenshot.screenshotOff();
      _isEnabled = true;
      debugPrint('Screenshot protection enabled');
    } catch (e) {
      debugPrint('Failed to enable screenshot protection: $e');
    }
  }

  Future<void> disableProtection() async {
    if (!_isEnabled) return;

    try {
      await _noScreenshot.screenshotOn();
      _isEnabled = false;
      debugPrint('Screenshot protection disabled');
    } catch (e) {
      debugPrint('Failed to disable screenshot protection: $e');
    }
  }

  bool get isEnabled => _isEnabled;
}