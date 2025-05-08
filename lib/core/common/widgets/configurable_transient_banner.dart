import 'package:flutter/material.dart';

import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart'; // For getAppColors
// For AppColorTokens

/// A configurable banner widget to display transient application messages.
///
/// Uses [AppMessage] to determine content, style (color, icon), and behavior.
/// Mimics the appearance of an iOS-style notification.
///
/// This widget handles styling based on message type and provides semantic
/// accessibility through proper labeling and live region support.
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
  static const double _borderRadius =
      0.0; // No border radius for a full-width iOS-like banner
  static const double _elevation = 1.0; // Subtle elevation
  static const EdgeInsets _outerPadding = EdgeInsets.symmetric(
    horizontal: 0.0, // No horizontal padding - full width
    vertical: 0.0, // No vertical padding for iOS-style
  );
  static const EdgeInsets _innerPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 14.0, // Slightly more vertical padding inside
  );

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
          background: colors.notificationBanners.notificationInfoBackground,
          foreground: colors.notificationBanners.notificationInfoForeground,
          icon: _typeIcons[type]!,
        );
      case MessageType.success:
        return (
          background: colors.notificationBanners.notificationSuccessBackground,
          foreground: colors.notificationBanners.notificationSuccessForeground,
          icon: _typeIcons[type]!,
        );
      case MessageType.warning:
        return (
          background: colors.notificationBanners.notificationWarningBackground,
          foreground: colors.notificationBanners.notificationWarningForeground,
          icon: _typeIcons[type]!,
        );
      case MessageType.error:
        return (
          background: colors.notificationBanners.notificationErrorBackground,
          foreground: colors.notificationBanners.notificationErrorForeground,
          icon: _typeIcons[type]!,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle(context, message.type);
    final foregroundColor = style.foreground;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w500, // Slightly less bold
    );

    // Add padding around the entire banner
    return Padding(
      padding: _outerPadding,
      // Use Material for elevation/shadow
      child: Material(
        elevation: _elevation,
        borderRadius: BorderRadius.circular(_borderRadius),
        color: style.background, // Set background color on Material
        // Clip content to rounded corners
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Semantics(
            liveRegion: true, // Announce changes to screen readers
            label: '${message.type.name}: ${message.message}',
            container: true, // Mark this as a semantic container
            child: Padding(
              // Add padding inside the banner content
              padding: _innerPadding,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Center items vertically
                children: [
                  Icon(
                    style.icon,
                    color: foregroundColor,
                    size: 20,
                  ), // Slightly smaller icon
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message.message,
                      style: textStyle,
                      // Allow more lines if needed, up to a limit
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8), // Space before close button
                  // Replace IconButton with GestureDetector to avoid tooltip/overlay issues
                  Semantics(
                    button: true,
                    label: 'Close notification',
                    excludeSemantics:
                        true, // Prevents child from providing semantics
                    child: GestureDetector(
                      onTap: onDismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.close,
                          color: foregroundColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
