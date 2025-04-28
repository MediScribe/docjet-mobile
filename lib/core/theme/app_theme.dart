import 'package:flutter/material.dart';
import 'app_color_tokens.dart';

/// Single export file for all app theme related definitions.
/// This provides a centralized place for all theme configuration.

/// The primary color seed for the application.
const Color _primarySeedColor = Colors.deepPurple;

/// Creates the light theme for the application.
ThemeData createLightTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: _primarySeedColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    extensions: [AppColorTokens.light(colorScheme)],
  );
}

/// Creates the dark theme for the application.
ThemeData createDarkTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: _primarySeedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    extensions: [AppColorTokens.dark(colorScheme)],
  );
}

/// Retrieves the application color tokens from the theme.
///
/// This is a convenience method to access the AppColorTokens extension.
/// Example usage: `final colors = getAppColors(context);`
AppColorTokens getAppColors(BuildContext context) {
  final tokens = Theme.of(context).extension<AppColorTokens>();
  if (tokens == null) {
    throw StateError(
      'AppColorTokens not found in the theme. Make sure to use the themes from app_theme.dart',
    );
  }
  return tokens;
}
