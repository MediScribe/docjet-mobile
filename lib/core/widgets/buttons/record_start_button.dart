import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/widgets/buttons/circular_action_button.dart';

/// A custom button specifically for initiating a recording.
///
/// Uses semantic theme colors for record actions (red background, white icon).
/// This widget is designed for mobile platforms only.
class RecordStartButton extends StatelessWidget {
  /// Callback function triggered when the button is tapped.
  final VoidCallback? onTap;

  /// Size of the button in logical pixels.
  final double size;

  /// Size of the microphone icon in logical pixels.
  final double iconSize;

  /// Creates a RecordStartButton widget.
  const RecordStartButton({
    super.key,
    this.onTap,
    this.size = 96.0, // Default size matching previous usage in modal
    this.iconSize = 56.0, // Default size matching previous usage in modal
  });

  @override
  Widget build(BuildContext context) {
    final appColors = getAppColors(context);
    final platform = Theme.of(context).platform;

    // Choose appropriate mic icon based on platform
    final IconData micIcon =
        platform == TargetPlatform.iOS ? CupertinoIcons.mic_fill : Icons.mic;

    return CircularActionButton(
      size: size,
      buttonColor: appColors.semanticStatus.colorSemanticRecordBackground,
      onTap: onTap,
      tooltip: 'Start recording',
      child: Icon(
        micIcon,
        color: appColors.semanticStatus.colorSemanticRecordForeground,
        size: iconSize,
      ),
    );
  }
}
