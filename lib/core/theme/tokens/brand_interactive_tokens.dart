import 'package:flutter/material.dart';

@immutable
class BrandInteractiveTokens {
  final Color colorBrandPrimary;
  final Color colorBrandOnPrimary;
  final Color colorBrandSecondary;
  final Color colorInteractivePrimaryBackground;
  final Color colorInteractivePrimaryForeground;
  final Color colorInteractiveSecondaryBackground;
  final Color colorInteractiveSecondaryForeground;

  const BrandInteractiveTokens({
    required this.colorBrandPrimary,
    required this.colorBrandOnPrimary,
    required this.colorBrandSecondary,
    required this.colorInteractivePrimaryBackground,
    required this.colorInteractivePrimaryForeground,
    required this.colorInteractiveSecondaryBackground,
    required this.colorInteractiveSecondaryForeground,
  });

  BrandInteractiveTokens copyWith({
    Color? colorBrandPrimary,
    Color? colorBrandOnPrimary,
    Color? colorBrandSecondary,
    Color? colorInteractivePrimaryBackground,
    Color? colorInteractivePrimaryForeground,
    Color? colorInteractiveSecondaryBackground,
    Color? colorInteractiveSecondaryForeground,
  }) {
    return BrandInteractiveTokens(
      colorBrandPrimary: colorBrandPrimary ?? this.colorBrandPrimary,
      colorBrandOnPrimary: colorBrandOnPrimary ?? this.colorBrandOnPrimary,
      colorBrandSecondary: colorBrandSecondary ?? this.colorBrandSecondary,
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
    );
  }

  BrandInteractiveTokens lerp(BrandInteractiveTokens? other, double t) {
    if (other == null) return this;
    return BrandInteractiveTokens(
      colorBrandPrimary:
          Color.lerp(colorBrandPrimary, other.colorBrandPrimary, t)!,
      colorBrandOnPrimary:
          Color.lerp(colorBrandOnPrimary, other.colorBrandOnPrimary, t)!,
      colorBrandSecondary:
          Color.lerp(colorBrandSecondary, other.colorBrandSecondary, t)!,
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
    );
  }

  @override
  int get hashCode => Object.hash(
    colorBrandPrimary,
    colorBrandOnPrimary,
    colorBrandSecondary,
    colorInteractivePrimaryBackground,
    colorInteractivePrimaryForeground,
    colorInteractiveSecondaryBackground,
    colorInteractiveSecondaryForeground,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrandInteractiveTokens &&
        other.colorBrandPrimary == colorBrandPrimary &&
        other.colorBrandOnPrimary == colorBrandOnPrimary &&
        other.colorBrandSecondary == colorBrandSecondary &&
        other.colorInteractivePrimaryBackground ==
            colorInteractivePrimaryBackground &&
        other.colorInteractivePrimaryForeground ==
            colorInteractivePrimaryForeground &&
        other.colorInteractiveSecondaryBackground ==
            colorInteractiveSecondaryBackground &&
        other.colorInteractiveSecondaryForeground ==
            colorInteractiveSecondaryForeground;
  }
}
