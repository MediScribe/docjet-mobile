import 'package:flutter/material.dart';

@immutable
class BaseStatusTokens {
  final Color dangerBg;
  final Color dangerFg;
  final Color warningBg;
  final Color warningFg;
  final Color successBg;
  final Color successFg;
  final Color infoBg;
  final Color infoFg;
  final Color offlineBg;
  final Color offlineFg;

  const BaseStatusTokens({
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
  });

  BaseStatusTokens copyWith({
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
  }) {
    return BaseStatusTokens(
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
    );
  }

  BaseStatusTokens lerp(BaseStatusTokens? other, double t) {
    if (other == null) return this;
    return BaseStatusTokens(
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
    );
  }

  @override
  int get hashCode => Object.hash(
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
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseStatusTokens &&
        other.dangerBg == dangerBg &&
        other.dangerFg == dangerFg &&
        other.warningBg == warningBg &&
        other.warningFg == warningFg &&
        other.successBg == successBg &&
        other.successFg == successFg &&
        other.infoBg == infoBg &&
        other.infoFg == infoFg &&
        other.offlineBg == offlineBg &&
        other.offlineFg == offlineFg;
  }
}
