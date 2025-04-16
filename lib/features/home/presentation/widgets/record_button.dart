import 'dart:io' show Platform; // Needed for platform check

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(micIcon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
