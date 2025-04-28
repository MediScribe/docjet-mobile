import 'package:flutter/material.dart';

/// A theme extension that provides semantic color tokens for the application.
///
/// This extension allows widgets to access semantic colors that automatically adapt
/// to the current theme brightness (light/dark) without hardcoding specific color values.
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  /// Primary background color for error/danger states
  final Color dangerBg;

  /// Foreground/text color for error/danger states
  final Color dangerFg;

  /// Background color for warning states
  final Color warningBg;

  /// Foreground/text color for warning states
  final Color warningFg;

  /// Background color for success states
  final Color successBg;

  /// Foreground/text color for success states
  final Color successFg;

  /// Background color for info/neutral states
  final Color infoBg;

  /// Foreground/text color for info/neutral states
  final Color infoFg;

  /// Background color for offline status indicators
  final Color offlineBg;

  /// Foreground/text color for offline status indicators
  final Color offlineFg;

  /// Color used for primary action button backgrounds (like record button)
  final Color primaryActionBg;

  /// Color used for primary action button icons/text
  final Color primaryActionFg;

  /// Color used for outlines and borders of form fields and containers
  final Color outlineColor;

  /// Color used for shadows with appropriate opacity
  final Color shadowColor;

  /// Creates an instance of [AppColorTokens] with the given colors.
  const AppColorTokens({
    required this.dangerBg,
    required this.dangerFg,
    required this.warningBg,
    required this.warningFg,
    required this.successBg,
    required this.successFg,
    required this.infoBg,
    required this.infoFg,
    required this.offlineBg,
    required this.offlineFg,
    required this.primaryActionBg,
    required this.primaryActionFg,
    required this.outlineColor,
    required this.shadowColor,
  });

  /// Creates the light theme version of [AppColorTokens].
  static AppColorTokens light(ColorScheme colorScheme) {
    return AppColorTokens(
      // Danger colors (red-based)
      dangerBg: colorScheme.error.withAlpha((255 * 0.1).round()),
      dangerFg: colorScheme.error,

      // Warning colors (orange-based)
      warningBg: colorScheme.errorContainer.withAlpha((255 * 0.2).round()),
      warningFg: Colors.orange.shade800,

      // Success colors (green-based)
      successBg: Colors.green.shade50,
      successFg: Colors.green.shade700,

      // Info colors (blue-based)
      infoBg: colorScheme.primary.withAlpha((255 * 0.1).round()),
      infoFg: colorScheme.primary,

      // Offline status colors
      offlineBg: colorScheme.error.withAlpha((255 * 0.1).round()),
      offlineFg: colorScheme.onError.withAlpha((255 * 0.7).round()),

      // Primary action button colors (was record button colors)
      primaryActionBg: colorScheme.error,
      primaryActionFg: colorScheme.onError,

      // Outline color for input fields and borders
      outlineColor: colorScheme.outline,

      // Shadow color with appropriate opacity
      shadowColor: Colors.black.withAlpha((255 * 0.2).round()),
    );
  }

  /// Creates the dark theme version of [AppColorTokens].
  static AppColorTokens dark(ColorScheme colorScheme) {
    return AppColorTokens(
      // Danger colors (red-based) - ensure color is different from light theme
      dangerBg: colorScheme.errorContainer.withAlpha((255 * 0.7).round()),
      // Use error shade instead of completely different color - Use alpha directly
      dangerFg: colorScheme.error.withAlpha((255 * 0.8).round()),

      // Warning colors (orange-based) - make noticeably different
      warningBg: Colors.orange.shade900.withAlpha((255 * 0.5).round()),
      warningFg: Colors.orange.shade100, // Lighter color for contrast
      // Success colors (green-based) - make noticeably different
      successBg: Colors.green.shade900.withAlpha((255 * 0.6).round()),
      successFg: Colors.green.shade100, // Lighter color for contrast
      // Info colors (blue-based)
      infoBg: colorScheme.primaryContainer.withAlpha((255 * 0.7).round()),
      infoFg: colorScheme.onPrimaryContainer,

      // Offline status colors - make noticeably different
      offlineBg: colorScheme.errorContainer.withAlpha((255 * 0.8).round()),
      offlineFg: colorScheme.onErrorContainer,

      // Primary action button colors (was record button colors)
      primaryActionBg: colorScheme.errorContainer,
      primaryActionFg: colorScheme.onErrorContainer,

      // Outline color for input fields and borders - darker in dark mode
      outlineColor: colorScheme.outline,

      // Shadow color with appropriate opacity - slightly different in dark mode
      shadowColor: Colors.black.withAlpha((255 * 0.3).round()),
    );
  }

  @override
  ThemeExtension<AppColorTokens> copyWith({
    Color? dangerBg,
    Color? dangerFg,
    Color? warningBg,
    Color? warningFg,
    Color? successBg,
    Color? successFg,
    Color? infoBg,
    Color? infoFg,
    Color? offlineBg,
    Color? offlineFg,
    Color? primaryActionBg,
    Color? primaryActionFg,
    Color? outlineColor,
    Color? shadowColor,
  }) {
    return AppColorTokens(
      dangerBg: dangerBg ?? this.dangerBg,
      dangerFg: dangerFg ?? this.dangerFg,
      warningBg: warningBg ?? this.warningBg,
      warningFg: warningFg ?? this.warningFg,
      successBg: successBg ?? this.successBg,
      successFg: successFg ?? this.successFg,
      infoBg: infoBg ?? this.infoBg,
      infoFg: infoFg ?? this.infoFg,
      offlineBg: offlineBg ?? this.offlineBg,
      offlineFg: offlineFg ?? this.offlineFg,
      primaryActionBg: primaryActionBg ?? this.primaryActionBg,
      primaryActionFg: primaryActionFg ?? this.primaryActionFg,
      outlineColor: outlineColor ?? this.outlineColor,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  ThemeExtension<AppColorTokens> lerp(
    covariant ThemeExtension<AppColorTokens>? other,
    double t,
  ) {
    if (other is! AppColorTokens) {
      return this;
    }

    return AppColorTokens(
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoFg: Color.lerp(infoFg, other.infoFg, t)!,
      offlineBg: Color.lerp(offlineBg, other.offlineBg, t)!,
      offlineFg: Color.lerp(offlineFg, other.offlineFg, t)!,
      primaryActionBg: Color.lerp(primaryActionBg, other.primaryActionBg, t)!,
      primaryActionFg: Color.lerp(primaryActionFg, other.primaryActionFg, t)!,
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}
