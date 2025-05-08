import 'package:flutter/material.dart';

/// A generic circular action button widget.
/// Provides a circular background and handles taps, displaying a custom child widget.
/// Includes proper ripple effects and accessibility support.
class CircularActionButton extends StatelessWidget {
  /// Callback function triggered when the button is tapped.
  final VoidCallback? onTap;

  /// The diameter of the outer circle.
  final double size;

  /// The background color of the circle.
  final Color buttonColor;

  /// The widget to display in the center of the circle (e.g., Icon, Container).
  final Widget child;

  /// Optional tooltip for accessibility.
  final String? tooltip;

  /// Creates a CircularActionButton.
  const CircularActionButton({
    super.key,
    required this.child,
    required this.buttonColor,
    this.onTap,
    this.size = 64.0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: buttonColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      ),
    );

    // Include tooltip if provided
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
