import 'package:flutter/material.dart';

@immutable
class NotificationBannerTokens {
  final Color notificationInfoBackground;
  final Color notificationInfoForeground;
  final Color notificationSuccessBackground;
  final Color notificationSuccessForeground;
  final Color notificationWarningBackground;
  final Color notificationWarningForeground;
  final Color notificationErrorBackground;
  final Color notificationErrorForeground;

  const NotificationBannerTokens({
    required this.notificationInfoBackground,
    required this.notificationInfoForeground,
    required this.notificationSuccessBackground,
    required this.notificationSuccessForeground,
    required this.notificationWarningBackground,
    required this.notificationWarningForeground,
    required this.notificationErrorBackground,
    required this.notificationErrorForeground,
  });

  NotificationBannerTokens copyWith({
    Color? notificationInfoBackground,
    Color? notificationInfoForeground,
    Color? notificationSuccessBackground,
    Color? notificationSuccessForeground,
    Color? notificationWarningBackground,
    Color? notificationWarningForeground,
    Color? notificationErrorBackground,
    Color? notificationErrorForeground,
  }) {
    return NotificationBannerTokens(
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
    );
  }

  NotificationBannerTokens lerp(NotificationBannerTokens? other, double t) {
    if (other == null) return this;
    return NotificationBannerTokens(
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
    );
  }

  @override
  int get hashCode => Object.hash(
    notificationInfoBackground,
    notificationInfoForeground,
    notificationSuccessBackground,
    notificationSuccessForeground,
    notificationWarningBackground,
    notificationWarningForeground,
    notificationErrorBackground,
    notificationErrorForeground,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationBannerTokens &&
        other.notificationInfoBackground == notificationInfoBackground &&
        other.notificationInfoForeground == notificationInfoForeground &&
        other.notificationSuccessBackground == notificationSuccessBackground &&
        other.notificationSuccessForeground == notificationSuccessForeground &&
        other.notificationWarningBackground == notificationWarningBackground &&
        other.notificationWarningForeground == notificationWarningForeground &&
        other.notificationErrorBackground == notificationErrorBackground &&
        other.notificationErrorForeground == notificationErrorForeground;
  }
}
