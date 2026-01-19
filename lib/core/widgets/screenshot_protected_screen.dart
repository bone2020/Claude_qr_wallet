import 'package:flutter/material.dart';

/// A wrapper widget that provides screenshot protection for sensitive screens
class ScreenshotProtectedScreen extends StatelessWidget {
  final Widget child;

  const ScreenshotProtectedScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The actual screenshot prevention is handled by the service
    // This widget just wraps the child
    return child;
  }
}
