import 'dart:io' show Platform; // Needed for platform check

import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import 'package:flutter/material.dart';

/// A reusable, theme-aware circular icon button that adapts to light and dark themes automatically.
class CircleIconButton extends StatelessWidget {
  /// Callback function triggered when the button is tapped.
  final VoidCallback? onTap;

  /// Size of the button in logical pixels. Defaults to 80.0.
  final double size;

  /// Size of the icon in logical pixels. Defaults to 40.0.
  final double iconSize;

  /// Optional icon to display. If null, defaults to a microphone icon.
  final IconData? icon;

  /// Optional tooltip text for accessibility.
  final String? tooltip;

  /// Creates a CircleIconButton widget.
  const CircleIconButton({
    super.key,
    this.onTap,
    this.size = 80.0,
    this.iconSize = 40.0,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // Choose icon based on platform for better native feel,
    // or use the provided icon.
    final IconData displayIcon =
        icon ?? (Platform.isIOS ? CupertinoIcons.mic_fill : Icons.mic);

    // Get color tokens from theme
    final appColors = getAppColors(context);

    // Build the button
    final buttonWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: appColors.primaryActionBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: appColors.shadowColor,
              blurRadius: 10.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          displayIcon,
          color: appColors.primaryActionFg,
          size: iconSize,
        ),
      ),
    );

    // Wrap with tooltip and semantics if provided
    if (tooltip != null) {
      return Semantics(
        label: tooltip,
        button: true,
        child: Tooltip(message: tooltip!, child: buttonWidget),
      );
    }

    return buttonWidget;
  }
}
