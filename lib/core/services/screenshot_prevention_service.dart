import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScreenshotPreventionService {
  static final ScreenshotPreventionService _instance = ScreenshotPreventionService._internal();
  factory ScreenshotPreventionService() => _instance;
  ScreenshotPreventionService._internal();

  static const MethodChannel _channel = MethodChannel('screenshot_prevention');
  bool _isEnabled = false;

  Future<void> enableProtection() async {
    if (_isEnabled) return;
    
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('enableProtection');
      }
      _isEnabled = true;
      debugPrint('Screenshot protection enabled');
    } catch (e) {
      debugPrint('Failed to enable screenshot protection: $e');
    }
  }

  Future<void> disableProtection() async {
    if (!_isEnabled) return;
    
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('disableProtection');
      }
      _isEnabled = false;
      debugPrint('Screenshot protection disabled');
    } catch (e) {
      debugPrint('Failed to disable screenshot protection: $e');
    }
  }

  bool get isEnabled => _isEnabled;
}