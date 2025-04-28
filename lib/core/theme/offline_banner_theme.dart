import 'package:flutter/material.dart';
import 'app_theme.dart';

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
  /// Uses theme tokens for consistent offline styling
  static Color getBackgroundColor(BuildContext context) {
    // Use the app's color tokens instead of direct ColorScheme access
    return getAppColors(context).offlineBg;
  }

  /// Get a color scheme adapted foreground color for text and icons
  static Color getForegroundColor(BuildContext context) {
    // Use the app's color tokens instead of direct ColorScheme access
    return getAppColors(context).offlineFg;
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
