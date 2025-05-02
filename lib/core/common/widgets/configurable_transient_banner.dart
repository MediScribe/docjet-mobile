import 'package:flutter/material.dart';

import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart'; // For getAppColors
// For AppColorTokens

/// A configurable banner widget to display transient application messages.
///
/// Uses [AppMessage] to determine content, style (color, icon), and behavior.
///
/// This widget handles styling based on message type and provides semantic
/// accessibility through proper labeling and live region support. It uses
/// AnimatedSize for smooth transitions when showing/hiding.
class ConfigurableTransientBanner extends StatelessWidget {
  /// The message data to display.
  final AppMessage message;

  /// Callback invoked when the dismiss button is pressed.
  final VoidCallback onDismiss;

  /// Creates a banner based on the provided [message].
  const ConfigurableTransientBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  /// Styling constants for the banner.
  ///
  /// Height is fixed to ensure consistent appearance across the app.
  /// Animation duration and curve provide a smooth entrance/exit.
  // TODO: Consider making banner height configurable or responsive if design requirements change
  static const double _bannerHeight = 50.0;
  static const Duration _animationDuration = Duration(milliseconds: 350);
  static const Curve _animationCurve = Curves.easeOutCubic;

  /// Icons to use for each message type
  static const Map<MessageType, IconData> _typeIcons = {
    MessageType.info: Icons.info_outline,
    MessageType.success: Icons.check_circle_outline,
    MessageType.warning: Icons.warning_amber_outlined,
    MessageType.error: Icons.error_outline,
  };

  /// Helper to get styling based on message type.
  ///
  /// Returns a record containing background color, foreground color, and icon
  /// for the given message type, using the app's theme tokens.
  ({Color background, Color foreground, IconData icon}) _getStyle(
    BuildContext context,
    MessageType type,
  ) {
    final colors = getAppColors(context);
    switch (type) {
      case MessageType.info:
        return (
          background: colors.notificationInfoBackground,
          foreground: colors.notificationInfoForeground,
          icon: _typeIcons[type]!,
        );
      case MessageType.success:
        return (
          background: colors.notificationSuccessBackground,
          foreground: colors.notificationSuccessForeground,
          icon: _typeIcons[type]!,
        );
      case MessageType.warning:
        return (
          background: colors.notificationWarningBackground,
          foreground: colors.notificationWarningForeground,
          icon: _typeIcons[type]!,
        );
      case MessageType.error:
        return (
          background: colors.notificationErrorBackground,
          foreground: colors.notificationErrorForeground,
          icon: _typeIcons[type]!,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle(context, message.type);
    final foregroundColor = style.foreground;
    final textStyle = TextStyle(
      color: foregroundColor,
      fontWeight: FontWeight.bold,
    );

    final bannerContent = Container(
      height: _bannerHeight,
      width: double.infinity,
      color: style.background,
      child: Semantics(
        liveRegion: true, // Announce changes to screen readers
        label: '${message.type.name}: ${message.message}',
        container: true, // Mark this as a semantic container
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(style.icon, color: foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message.message,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: foregroundColor),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onDismiss,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );

    // Use AnimatedSize for smooth entrance/exit transitions
    return AnimatedSize(
      duration: _animationDuration,
      curve: _animationCurve,
      child: bannerContent,
    );
  }
}
