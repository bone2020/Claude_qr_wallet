import 'package:flutter/material.dart';

/// Constrains content width on wide screens (tablets).
/// On phones (< 600px), content fills the full width.
/// On tablets (>= 600px), content is centered with max width.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 500,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 600) {
          // Phone — use full width
          return child;
        }

        // Tablet — center content with max width
        return Container(
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
