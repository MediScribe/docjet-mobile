import 'package:flutter/material.dart';

/// Theme utilities for the offline banner to maintain consistent styling
/// throughout the application.
///
/// This class provides theme values that adapt to the current app theme
/// while maintaining consistent layout measurements.
class OfflineBannerTheme {
  /// The height of the banner when visible
  static const double height = 36.0;

  /// The duration of the fade/height animation
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// The size of the icon
  static const double iconSize = 16.0;

  /// The horizontal spacing between the icon and text
  static const double iconTextSpacing = 8.0;

  /// Get a color scheme adapted background color
  /// Uses error container in light mode, dark grey in dark mode
  static Color getBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return brightness == Brightness.dark
        ? theme.colorScheme.errorContainer.withAlpha((255 * 0.8).round())
        : theme.colorScheme.error.withAlpha((255 * 0.1).round());
  }

  /// Get a color scheme adapted foreground color for text and icons
  static Color getForegroundColor(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return brightness == Brightness.dark
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onError.withAlpha((255 * 0.7).round());
  }

  /// Get text style for the banner message, using theme colors
  static TextStyle getTextStyle(BuildContext context) {
    return TextStyle(
      color: getForegroundColor(context),
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
    );
  }

  // Private constructor to prevent instantiation
  OfflineBannerTheme._();
}
