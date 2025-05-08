import 'package:flutter/material.dart';

@immutable
class SemanticStatusTokens {
  final Color colorSemanticRecordBackground;
  final Color colorSemanticRecordForeground;
  final Color colorSemanticPausedBackground;

  const SemanticStatusTokens({
    required this.colorSemanticRecordBackground,
    required this.colorSemanticRecordForeground,
    required this.colorSemanticPausedBackground,
  });

  SemanticStatusTokens copyWith({
    Color? colorSemanticRecordBackground,
    Color? colorSemanticRecordForeground,
    Color? colorSemanticPausedBackground,
  }) {
    return SemanticStatusTokens(
      colorSemanticRecordBackground:
          colorSemanticRecordBackground ?? this.colorSemanticRecordBackground,
      colorSemanticRecordForeground:
          colorSemanticRecordForeground ?? this.colorSemanticRecordForeground,
      colorSemanticPausedBackground:
          colorSemanticPausedBackground ?? this.colorSemanticPausedBackground,
    );
  }

  SemanticStatusTokens lerp(SemanticStatusTokens? other, double t) {
    if (other == null) return this;
    return SemanticStatusTokens(
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
    );
  }

  @override
  int get hashCode => Object.hash(
    colorSemanticRecordBackground,
    colorSemanticRecordForeground,
    colorSemanticPausedBackground,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemanticStatusTokens &&
        other.colorSemanticRecordBackground == colorSemanticRecordBackground &&
        other.colorSemanticRecordForeground == colorSemanticRecordForeground &&
        other.colorSemanticPausedBackground == colorSemanticPausedBackground;
  }
}
