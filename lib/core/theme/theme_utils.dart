import 'package:flutter/material.dart';

/// Theme utility functions to help with color and theme related operations.
///
/// This file contains helpers for working with ColorScheme and ThemeData
/// to make certain operations more discoverable and easier to use.
class ThemeUtils {
  // Private constructor to prevent instantiation
  ThemeUtils._();

  /// Returns the surfaceContainerHighest color from a ColorScheme.
  ///
  /// This function exists primarily for IDE discoverability and to make
  /// it easier to find and use the surfaceContainerHighest color.
  ///
  /// ```dart
  /// final color = ThemeUtils.surfaceContainerHighestOrDefault(colorScheme);
  /// ```
  static Color surfaceContainerHighestOrDefault(ColorScheme colorScheme) {
    return colorScheme.surfaceContainerHighest;
  }
}
