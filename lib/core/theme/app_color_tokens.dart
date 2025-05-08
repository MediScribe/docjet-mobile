import 'package:flutter/material.dart';
import 'package:docjet_mobile/core/theme/tokens/notification_banner_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/brand_interactive_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/semantic_status_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/base_status_tokens.dart';

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

  // --------------------------------------------------------------------------
  // Base Status Colors (Now a separate class)
  // --------------------------------------------------------------------------
  final BaseStatusTokens baseStatus;

  // --------------------------------------------------------------------------
  // Notification Banner Colors (Now a separate class)
  // --------------------------------------------------------------------------
  final NotificationBannerTokens notificationBanners;

  // --------------------------------------------------------------------------
  // CI Brand & Interactive Colors (Now a separate class)
  // --------------------------------------------------------------------------
  final BrandInteractiveTokens brandInteractive;

  // --------------------------------------------------------------------------
  // Semantic Status/Action Colors (Now a separate class)
  // --------------------------------------------------------------------------
  final SemanticStatusTokens semanticStatus;

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
    required this.baseStatus,
    required this.primaryActionBg,
    required this.primaryActionFg,
    required this.outlineColor,
    required this.shadowColor,
    required this.notificationBanners,
    required this.brandInteractive,
    required this.semanticStatus,
  });

  /// Creates the light theme version of [AppColorTokens].
  factory AppColorTokens.light(ColorScheme colorScheme) {
    return AppColorTokens(
      // Base status colors
      baseStatus: BaseStatusTokens(
        dangerBg: colorScheme.error.withAlpha((255 * 0.1).round()),
        dangerFg: colorScheme.error,
        warningBg: colorScheme.errorContainer.withAlpha((255 * 0.2).round()),
        warningFg: Colors.orange.shade800,
        successBg: Colors.green.shade50,
        successFg: Colors.green.shade700,
        infoBg: colorScheme.primary.withAlpha((255 * 0.1).round()),
        infoFg: colorScheme.primary,
        offlineBg: colorScheme.error.withAlpha((255 * 0.1).round()),
        offlineFg: colorScheme.onError.withAlpha((255 * 0.7).round()),
      ),
      // Primary action button colors (circular icon buttons)
      primaryActionBg: kBrandPrimaryValue,
      primaryActionFg: kBrandOnPrimaryValue,

      // Outline color for input fields and borders
      outlineColor: colorScheme.outline,

      // Shadow color with appropriate opacity
      shadowColor: Colors.black.withAlpha((255 * 0.2).round()),

      // Notification banner colors
      notificationBanners: NotificationBannerTokens(
        notificationInfoBackground: Colors.blue.shade600,
        notificationInfoForeground: Colors.white,
        notificationSuccessBackground: Colors.green.shade600,
        notificationSuccessForeground: Colors.white,
        notificationWarningBackground: Colors.orange.shade700,
        notificationWarningForeground: Colors.white,
        notificationErrorBackground: Colors.red.shade700,
        notificationErrorForeground: Colors.white,
      ),

      // CI Brand & Interactive Colors - Light Theme
      brandInteractive: BrandInteractiveTokens(
        colorBrandPrimary: kBrandPrimaryValue,
        colorBrandOnPrimary: kBrandOnPrimaryValue,
        colorBrandSecondary: kBrandSecondaryValue,
        colorInteractivePrimaryBackground: kBrandPrimaryValue,
        colorInteractivePrimaryForeground: kBrandOnPrimaryValue,
        colorInteractiveSecondaryBackground: Colors.grey.shade600,
        colorInteractiveSecondaryForeground: Colors.white,
      ),

      // Semantic Colors - Light Theme
      semanticStatus: SemanticStatusTokens(
        colorSemanticRecordBackground: Colors.red.shade600,
        colorSemanticRecordForeground: Colors.white,
        colorSemanticPausedBackground: Colors.blue.shade800,
      ),
    );
  }

  /// Creates the dark theme version of [AppColorTokens].
  factory AppColorTokens.dark(ColorScheme colorScheme) {
    return AppColorTokens(
      // Base status colors
      baseStatus: BaseStatusTokens(
        dangerBg: colorScheme.errorContainer.withAlpha((255 * 0.7).round()),
        dangerFg: colorScheme.error.withAlpha((255 * 0.8).round()),
        warningBg: Colors.orange.shade900.withAlpha((255 * 0.5).round()),
        warningFg: Colors.orange.shade100, // Lighter color for contrast
        successBg: Colors.green.shade900.withAlpha((255 * 0.6).round()),
        successFg: Colors.green.shade100, // Lighter color for contrast
        infoBg: colorScheme.primaryContainer.withAlpha((255 * 0.7).round()),
        infoFg: colorScheme.onPrimaryContainer,
        offlineBg: colorScheme.error.withAlpha(
          (0.92 * 255).round(),
        ), // Match iOS system bar opacity
        offlineFg: Colors.white, // White for maximum contrast
      ),

      // Primary action button colors (circular icon buttons)
      primaryActionBg:
          colorScheme.primary, // Distinct primary color for dark theme
      primaryActionFg:
          colorScheme.onPrimary, // Ensure contrast with primary background
      // Outline color for input fields and borders
      outlineColor: colorScheme.outlineVariant, // Use variant for dark
      // Shadow color with appropriate opacity
      shadowColor: Colors.black.withAlpha((255 * 0.4).round()), // Darker shadow
      // Notification banner colors - Dark Theme
      notificationBanners: NotificationBannerTokens(
        notificationInfoBackground: Colors.blue.shade800,
        notificationInfoForeground: Colors.white,
        notificationSuccessBackground: Colors.green.shade800,
        notificationSuccessForeground: Colors.white,
        notificationWarningBackground: Colors.orange.shade800,
        notificationWarningForeground:
            Colors.black, // Better contrast on dark orange
        notificationErrorBackground: Colors.red.shade800,
        notificationErrorForeground: Colors.white,
      ),

      // CI Brand & Interactive Colors - Dark Theme
      brandInteractive: BrandInteractiveTokens(
        colorBrandPrimary: kBrandPrimaryValue, // Keep CI color consistent
        colorBrandOnPrimary: kBrandOnPrimaryValue,
        colorBrandSecondary: kBrandSecondaryValue, // Keep CI color consistent
        colorInteractivePrimaryBackground: colorScheme.primary,
        colorInteractivePrimaryForeground: colorScheme.onPrimary,
        colorInteractiveSecondaryBackground:
            colorScheme.surfaceContainerHighest,
        colorInteractiveSecondaryForeground: colorScheme.onSurfaceVariant,
      ),

      // Semantic Colors - Dark Theme
      semanticStatus: SemanticStatusTokens(
        colorSemanticRecordBackground: Colors.red.shade400, // Darker red
        colorSemanticRecordForeground: Colors.white,
        colorSemanticPausedBackground: Colors.blueGrey.shade600,
      ),
    );
  }

  @override
  AppColorTokens copyWith({
    BaseStatusTokens? baseStatus,
    Color? primaryActionBg,
    Color? primaryActionFg,
    Color? outlineColor,
    Color? shadowColor,
    NotificationBannerTokens? notificationBanners,
    BrandInteractiveTokens? brandInteractive,
    SemanticStatusTokens? semanticStatus,
  }) {
    return AppColorTokens(
      baseStatus: baseStatus ?? this.baseStatus,
      primaryActionBg: primaryActionBg ?? this.primaryActionBg,
      primaryActionFg: primaryActionFg ?? this.primaryActionFg,
      outlineColor: outlineColor ?? this.outlineColor,
      shadowColor: shadowColor ?? this.shadowColor,
      notificationBanners: notificationBanners ?? this.notificationBanners,
      brandInteractive: brandInteractive ?? this.brandInteractive,
      semanticStatus: semanticStatus ?? this.semanticStatus,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }
    return AppColorTokens(
      baseStatus: baseStatus.lerp(other.baseStatus, t),
      primaryActionBg: Color.lerp(primaryActionBg, other.primaryActionBg, t)!,
      primaryActionFg: Color.lerp(primaryActionFg, other.primaryActionFg, t)!,
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      notificationBanners: notificationBanners.lerp(
        other.notificationBanners,
        t,
      ),
      brandInteractive: brandInteractive.lerp(other.brandInteractive, t),
      semanticStatus: semanticStatus.lerp(other.semanticStatus, t),
    );
  }

  @override
  int get hashCode => Object.hashAll([
    baseStatus,
    primaryActionBg,
    primaryActionFg,
    outlineColor,
    shadowColor,
    notificationBanners,
    brandInteractive,
    semanticStatus,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppColorTokens &&
        other.baseStatus == baseStatus &&
        other.primaryActionBg == primaryActionBg &&
        other.primaryActionFg == primaryActionFg &&
        other.outlineColor == outlineColor &&
        other.shadowColor == shadowColor &&
        other.notificationBanners == notificationBanners &&
        other.brandInteractive == brandInteractive &&
        other.semanticStatus == semanticStatus;
  }
}
