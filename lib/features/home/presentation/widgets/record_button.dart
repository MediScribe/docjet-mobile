import 'dart:io' show Platform; // Needed for platform check

import 'package:docjet_mobile/core/theme/app_theme.dart'; // Import our theme utilities
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import 'package:flutter/material.dart';

class RecordButton extends StatelessWidget {
  final VoidCallback? onTap; // Callback for tap events
  final double size;
  final double iconSize;

  const RecordButton({
    super.key,
    this.onTap,
    this.size = 80.0, // Default size
    this.iconSize = 40.0, // Default icon size
  });

  @override
  Widget build(BuildContext context) {
    // Choose icon based on platform
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
          color:
              appColors
                  .recordButtonBg, // Use theme color instead of hardcoded red
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                (255 * 0.2).round(),
              ), // Use withAlpha
              blurRadius: 10.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          micIcon,
          color:
              appColors
                  .recordButtonFg, // Use theme color instead of hardcoded white
          size: iconSize,
        ),
      ),
    );
  }
}
