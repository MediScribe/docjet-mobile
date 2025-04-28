import 'dart:io' show Platform; // Needed for platform check

import 'package:docjet_mobile/core/theme/app_theme.dart'; // Import our theme utilities
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import 'package:flutter/material.dart';

/// A reusable, theme-aware record button that can be used across the app.
/// This component provides a consistent recording button UI that adapts to
/// light and dark themes automatically.
class RecordButton extends StatelessWidget {
  /// Callback function triggered when the button is tapped.
  final VoidCallback? onTap;

  /// Size of the button in logical pixels. Defaults to 80.0.
  final double size;

  /// Size of the microphone icon in logical pixels. Defaults to 40.0.
  final double iconSize;

  /// Creates a RecordButton widget.
  const RecordButton({
    super.key,
    this.onTap,
    this.size = 80.0,
    this.iconSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    // Choose icon based on platform for better native feel
    final IconData micIcon =
        Platform.isIOS ? CupertinoIcons.mic_fill : Icons.mic;

    // Get color tokens from theme
    final appColors = getAppColors(context);

    return GestureDetector(
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
        child: Icon(micIcon, color: appColors.primaryActionFg, size: iconSize),
      ),
    );
  }
}
