import 'package:flutter/cupertino.dart';

/// Theme constants for the offline banner to maintain consistent styling
/// throughout the application.
class OfflineBannerTheme {
  /// The height of the banner when visible
  static const double height = 36.0;

  /// The duration of the fade/height animation
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// The background color of the banner
  static const Color backgroundColor = CupertinoColors.systemGrey;

  /// The color of the text and icon
  static const Color foregroundColor = CupertinoColors.white;

  /// The size of the icon
  static const double iconSize = 16.0;

  /// The horizontal spacing between the icon and text
  static const double iconTextSpacing = 8.0;

  /// The text style for the banner message
  static const TextStyle textStyle = TextStyle(
    color: foregroundColor,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
  );

  // Private constructor to prevent instantiation
  OfflineBannerTheme._();
}
