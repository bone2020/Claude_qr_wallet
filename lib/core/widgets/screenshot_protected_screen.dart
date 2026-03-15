import 'package:flutter/material.dart';

import '../services/screenshot_prevention_service.dart';

class ScreenshotProtectedScreen extends StatefulWidget {
  final Widget child;

  const ScreenshotProtectedScreen({
    super.key,
    required this.child,
  });

  @override
  State<ScreenshotProtectedScreen> createState() => _ScreenshotProtectedScreenState();
}

class _ScreenshotProtectedScreenState extends State<ScreenshotProtectedScreen> {
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

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
