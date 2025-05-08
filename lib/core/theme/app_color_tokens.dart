import 'package:flutter/material.dart';

/// A theme extension that provides semantic color tokens for the application.
///
/// This extension allows widgets to access semantic colors that automatically adapt
/// to the current theme brightness (light/dark) without hardcoding specific color values.
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  // --------------------------------------------------------------------------
  // Brand Color Constants
  // --------------------------------------------------------------------------

  /// Core brand primary color (CI Blue: #004199).
  static const Color kBrandPrimaryValue = Color(0xFF004199);

  /// Text/icon color for elements on brand primary background.
  static const Color kBrandOnPrimaryValue = Colors.white;

  /// Core brand secondary color (CI Light Blue: #65A5FF).
  static const Color kBrandSecondaryValue = Color(0xFF65A5FF);

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

  // --------------------------------------------------------------------------
  // Notification Banner Colors
  // --------------------------------------------------------------------------

  /// Background color for informational notification banners.
  final Color notificationInfoBackground;

  /// Text/Icon color for informational notification banners.
  final Color notificationInfoForeground;

  /// Background color for success notification banners.
  final Color notificationSuccessBackground;

  /// Text/Icon color for success notification banners.
  final Color notificationSuccessForeground;

  /// Background color for warning notification banners.
  final Color notificationWarningBackground;

  /// Text/Icon color for warning notification banners.
  final Color notificationWarningForeground;

  /// Background color for error notification banners.
  final Color notificationErrorBackground;

  /// Text/Icon color for error notification banners.
  final Color notificationErrorForeground;

  // --------------------------------------------------------------------------
  // CI Brand & Interactive Colors
  // --------------------------------------------------------------------------

  /// Core brand primary color (CI Blue: #004199).
  final Color colorBrandPrimary;

  /// Text/icon color for elements on [colorBrandPrimary] background.
  final Color colorBrandOnPrimary;

  /// Core brand secondary color (CI Light Blue: #65A5FF).
  final Color colorBrandSecondary;

  /// Background color for primary interactive elements (e.g., Accept button).
  final Color colorInteractivePrimaryBackground;

  /// Foreground (text/icon) color for primary interactive elements.
  final Color colorInteractivePrimaryForeground;

  /// Background color for secondary interactive elements (e.g., Cancel button).
  final Color colorInteractiveSecondaryBackground;

  /// Foreground (text/icon) color for secondary interactive elements.
  final Color colorInteractiveSecondaryForeground;

  // --------------------------------------------------------------------------
  // Semantic Status/Action Colors (Beyond standard interactive)
  // --------------------------------------------------------------------------

  /// Background color for record action elements.
  final Color colorSemanticRecordBackground;

  /// Foreground (text/icon) color for record action elements.
  final Color colorSemanticRecordForeground;

  /// Background color for paused state elements.
  final Color colorSemanticPausedBackground;

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
    required this.notificationInfoBackground,
    required this.notificationInfoForeground,
    required this.notificationSuccessBackground,
    required this.notificationSuccessForeground,
    required this.notificationWarningBackground,
    required this.notificationWarningForeground,
    required this.notificationErrorBackground,
    required this.notificationErrorForeground,
    // Brand Colors
    required this.colorBrandPrimary,
    required this.colorBrandOnPrimary,
    required this.colorBrandSecondary,
    // Interactive Colors
    required this.colorInteractivePrimaryBackground,
    required this.colorInteractivePrimaryForeground,
    required this.colorInteractiveSecondaryBackground,
    required this.colorInteractiveSecondaryForeground,
    // New Semantic Colors
    required this.colorSemanticRecordBackground,
    required this.colorSemanticRecordForeground,
    required this.colorSemanticPausedBackground,
  });

  /// Creates the light theme version of [AppColorTokens].
  factory AppColorTokens.light(ColorScheme colorScheme) {
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

      // Primary action button colors (circular icon buttons)
      primaryActionBg: kBrandPrimaryValue,
      primaryActionFg: kBrandOnPrimaryValue,

      // Outline color for input fields and borders
      outlineColor: colorScheme.outline,

      // Shadow color with appropriate opacity
      shadowColor: Colors.black.withAlpha((255 * 0.2).round()),

      // Notification banner colors
      notificationInfoBackground: Colors.blue.shade600,
      notificationInfoForeground: Colors.white,
      notificationSuccessBackground: Colors.green.shade600,
      notificationSuccessForeground: Colors.white,
      notificationWarningBackground: Colors.orange.shade700,
      notificationWarningForeground: Colors.white,
      notificationErrorBackground: Colors.red.shade700,
      notificationErrorForeground: Colors.white,

      // CI Brand & Interactive Colors - Light Theme
      colorBrandPrimary: kBrandPrimaryValue,
      colorBrandOnPrimary: kBrandOnPrimaryValue,
      colorBrandSecondary: kBrandSecondaryValue,
      colorInteractivePrimaryBackground: kBrandPrimaryValue,
      colorInteractivePrimaryForeground: kBrandOnPrimaryValue,
      colorInteractiveSecondaryBackground: Colors.grey.shade600,
      colorInteractiveSecondaryForeground: Colors.white,

      // Semantic Colors - Light Theme
      colorSemanticRecordBackground: Colors.red.shade600,
      colorSemanticRecordForeground: Colors.white,
      colorSemanticPausedBackground: Colors.blue.shade800,
    );
  }

  /// Creates the dark theme version of [AppColorTokens].
  factory AppColorTokens.dark(ColorScheme colorScheme) {
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
      offlineBg: colorScheme.error.withAlpha(
        (0.92 * 255).round(),
      ), // Match iOS system bar opacity
      offlineFg: Colors.white, // White for maximum contrast
      // Primary action button colors (circular icon buttons)
      primaryActionBg: kBrandPrimaryValue,
      primaryActionFg: kBrandOnPrimaryValue,

      // Outline color for input fields and borders - darker in dark mode
      outlineColor: colorScheme.outline,

      // Shadow color with appropriate opacity - slightly different in dark mode
      shadowColor: Colors.black.withAlpha((255 * 0.3).round()),

      // Notification banner colors
      notificationInfoBackground: Colors.blue.shade700,
      notificationInfoForeground: Colors.white,
      notificationSuccessBackground: Colors.green.shade700,
      notificationSuccessForeground: Colors.white,
      notificationWarningBackground: Colors.orange.shade800,
      notificationWarningForeground: Colors.black87,
      notificationErrorBackground: Colors.red.shade800,
      notificationErrorForeground: Colors.white,

      // CI Brand & Interactive Colors - Dark Theme
      colorBrandPrimary: kBrandPrimaryValue,
      colorBrandOnPrimary: kBrandOnPrimaryValue,
      colorBrandSecondary: kBrandSecondaryValue,
      colorInteractivePrimaryBackground: kBrandPrimaryValue,
      colorInteractivePrimaryForeground: kBrandOnPrimaryValue,
      colorInteractiveSecondaryBackground: Colors.grey.shade800,
      colorInteractiveSecondaryForeground: Colors.white,

      // Semantic Colors - Dark Theme
      colorSemanticRecordBackground: Colors.red.shade600,
      colorSemanticRecordForeground: Colors.white,
      colorSemanticPausedBackground: Colors.blue.shade800,
    );
  }

  @override
  AppColorTokens copyWith({
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
    Color? notificationInfoBackground,
    Color? notificationInfoForeground,
    Color? notificationSuccessBackground,
    Color? notificationSuccessForeground,
    Color? notificationWarningBackground,
    Color? notificationWarningForeground,
    Color? notificationErrorBackground,
    Color? notificationErrorForeground,
    Color? colorInteractivePrimaryBackground,
    Color? colorInteractivePrimaryForeground,
    Color? colorInteractiveSecondaryBackground,
    Color? colorInteractiveSecondaryForeground,
    Color? colorSemanticRecordBackground,
    Color? colorSemanticRecordForeground,
    Color? colorSemanticPausedBackground,
    Color? colorBrandPrimary,
    Color? colorBrandOnPrimary,
    Color? colorBrandSecondary,
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
      notificationInfoBackground:
          notificationInfoBackground ?? this.notificationInfoBackground,
      notificationInfoForeground:
          notificationInfoForeground ?? this.notificationInfoForeground,
      notificationSuccessBackground:
          notificationSuccessBackground ?? this.notificationSuccessBackground,
      notificationSuccessForeground:
          notificationSuccessForeground ?? this.notificationSuccessForeground,
      notificationWarningBackground:
          notificationWarningBackground ?? this.notificationWarningBackground,
      notificationWarningForeground:
          notificationWarningForeground ?? this.notificationWarningForeground,
      notificationErrorBackground:
          notificationErrorBackground ?? this.notificationErrorBackground,
      notificationErrorForeground:
          notificationErrorForeground ?? this.notificationErrorForeground,
      colorInteractivePrimaryBackground:
          colorInteractivePrimaryBackground ??
          this.colorInteractivePrimaryBackground,
      colorInteractivePrimaryForeground:
          colorInteractivePrimaryForeground ??
          this.colorInteractivePrimaryForeground,
      colorInteractiveSecondaryBackground:
          colorInteractiveSecondaryBackground ??
          this.colorInteractiveSecondaryBackground,
      colorInteractiveSecondaryForeground:
          colorInteractiveSecondaryForeground ??
          this.colorInteractiveSecondaryForeground,
      colorSemanticRecordBackground:
          colorSemanticRecordBackground ?? this.colorSemanticRecordBackground,
      colorSemanticRecordForeground:
          colorSemanticRecordForeground ?? this.colorSemanticRecordForeground,
      colorSemanticPausedBackground:
          colorSemanticPausedBackground ?? this.colorSemanticPausedBackground,
      colorBrandPrimary: colorBrandPrimary ?? this.colorBrandPrimary,
      colorBrandOnPrimary: colorBrandOnPrimary ?? this.colorBrandOnPrimary,
      colorBrandSecondary: colorBrandSecondary ?? this.colorBrandSecondary,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
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
      notificationInfoBackground:
          Color.lerp(
            notificationInfoBackground,
            other.notificationInfoBackground,
            t,
          )!,
      notificationInfoForeground:
          Color.lerp(
            notificationInfoForeground,
            other.notificationInfoForeground,
            t,
          )!,
      notificationSuccessBackground:
          Color.lerp(
            notificationSuccessBackground,
            other.notificationSuccessBackground,
            t,
          )!,
      notificationSuccessForeground:
          Color.lerp(
            notificationSuccessForeground,
            other.notificationSuccessForeground,
            t,
          )!,
      notificationWarningBackground:
          Color.lerp(
            notificationWarningBackground,
            other.notificationWarningBackground,
            t,
          )!,
      notificationWarningForeground:
          Color.lerp(
            notificationWarningForeground,
            other.notificationWarningForeground,
            t,
          )!,
      notificationErrorBackground:
          Color.lerp(
            notificationErrorBackground,
            other.notificationErrorBackground,
            t,
          )!,
      notificationErrorForeground:
          Color.lerp(
            notificationErrorForeground,
            other.notificationErrorForeground,
            t,
          )!,
      colorInteractivePrimaryBackground:
          Color.lerp(
            colorInteractivePrimaryBackground,
            other.colorInteractivePrimaryBackground,
            t,
          )!,
      colorInteractivePrimaryForeground:
          Color.lerp(
            colorInteractivePrimaryForeground,
            other.colorInteractivePrimaryForeground,
            t,
          )!,
      colorInteractiveSecondaryBackground:
          Color.lerp(
            colorInteractiveSecondaryBackground,
            other.colorInteractiveSecondaryBackground,
            t,
          )!,
      colorInteractiveSecondaryForeground:
          Color.lerp(
            colorInteractiveSecondaryForeground,
            other.colorInteractiveSecondaryForeground,
            t,
          )!,
      colorSemanticRecordBackground:
          Color.lerp(
            colorSemanticRecordBackground,
            other.colorSemanticRecordBackground,
            t,
          )!,
      colorSemanticRecordForeground:
          Color.lerp(
            colorSemanticRecordForeground,
            other.colorSemanticRecordForeground,
            t,
          )!,
      colorSemanticPausedBackground:
          Color.lerp(
            colorSemanticPausedBackground,
            other.colorSemanticPausedBackground,
            t,
          )!,
      colorBrandPrimary:
          Color.lerp(colorBrandPrimary, other.colorBrandPrimary, t)!,
      colorBrandOnPrimary:
          Color.lerp(colorBrandOnPrimary, other.colorBrandOnPrimary, t)!,
      colorBrandSecondary:
          Color.lerp(colorBrandSecondary, other.colorBrandSecondary, t)!,
    );
  }

  @override
  int get hashCode => Object.hashAll([
    dangerBg,
    dangerFg,
    warningBg,
    warningFg,
    successBg,
    successFg,
    infoBg,
    infoFg,
    offlineBg,
    offlineFg,
    primaryActionBg,
    primaryActionFg,
    outlineColor,
    shadowColor,
    notificationInfoBackground,
    notificationInfoForeground,
    notificationSuccessBackground,
    notificationSuccessForeground,
    notificationWarningBackground,
    notificationWarningForeground,
    notificationErrorBackground,
    notificationErrorForeground,
    colorInteractivePrimaryBackground,
    colorInteractivePrimaryForeground,
    colorInteractiveSecondaryBackground,
    colorInteractiveSecondaryForeground,
    colorSemanticRecordBackground,
    colorSemanticRecordForeground,
    colorSemanticPausedBackground,
    colorBrandPrimary,
    colorBrandOnPrimary,
    colorBrandSecondary,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppColorTokens &&
          runtimeType == other.runtimeType &&
          dangerBg == other.dangerBg &&
          dangerFg == other.dangerFg &&
          warningBg == other.warningBg &&
          warningFg == other.warningFg &&
          successBg == other.successBg &&
          successFg == other.successFg &&
          infoBg == other.infoBg &&
          infoFg == other.infoFg &&
          offlineBg == other.offlineBg &&
          offlineFg == other.offlineFg &&
          primaryActionBg == other.primaryActionBg &&
          primaryActionFg == other.primaryActionFg &&
          outlineColor == other.outlineColor &&
          shadowColor == other.shadowColor &&
          notificationInfoBackground == other.notificationInfoBackground &&
          notificationInfoForeground == other.notificationInfoForeground &&
          notificationSuccessBackground ==
              other.notificationSuccessBackground &&
          notificationSuccessForeground ==
              other.notificationSuccessForeground &&
          notificationWarningBackground ==
              other.notificationWarningBackground &&
          notificationWarningForeground ==
              other.notificationWarningForeground &&
          notificationErrorBackground == other.notificationErrorBackground &&
          notificationErrorForeground == other.notificationErrorForeground &&
          colorInteractivePrimaryBackground ==
              other.colorInteractivePrimaryBackground &&
          colorInteractivePrimaryForeground ==
              other.colorInteractivePrimaryForeground &&
          colorInteractiveSecondaryBackground ==
              other.colorInteractiveSecondaryBackground &&
          colorInteractiveSecondaryForeground ==
              other.colorInteractiveSecondaryForeground &&
          colorSemanticRecordBackground ==
              other.colorSemanticRecordBackground &&
          colorSemanticRecordForeground ==
              other.colorSemanticRecordForeground &&
          colorSemanticPausedBackground ==
              other.colorSemanticPausedBackground &&
          colorBrandPrimary == other.colorBrandPrimary &&
          colorBrandOnPrimary == other.colorBrandOnPrimary &&
          colorBrandSecondary == other.colorBrandSecondary;
}
