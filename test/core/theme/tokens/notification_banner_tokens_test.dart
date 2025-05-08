import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/tokens/notification_banner_tokens.dart';

void main() {
  group('NotificationBannerTokens', () {
    // Helper
    NotificationBannerTokens createDummy() {
      return const NotificationBannerTokens(
        notificationInfoBackground: Color(0xFF00000F),
        notificationInfoForeground: Color(0xFF000010),
        notificationSuccessBackground: Color(0xFF000011),
        notificationSuccessForeground: Color(0xFF000012),
        notificationWarningBackground: Color(0xFF000013),
        notificationWarningForeground: Color(0xFF000014),
        notificationErrorBackground: Color(0xFF000015),
        notificationErrorForeground: Color(0xFF000016),
      );
    }

    test('copyWith creates an identical copy if no arguments are provided', () {
      final original = createDummy();
      final copy = original.copyWith();
      expect(copy, original);
      expect(identical(copy, original), isFalse);
    });

    test('copyWith updates only the provided fields', () {
      final original = createDummy();
      const newInfoBg = Color(0xFFFFFFFF);
      final copy = original.copyWith(notificationInfoBackground: newInfoBg);

      expect(copy.notificationInfoBackground, newInfoBg);
      expect(
        copy.notificationInfoForeground,
        original.notificationInfoForeground,
      );
      expect(
        copy.notificationErrorForeground,
        original.notificationErrorForeground,
      );
    });

    test('lerp interpolates correctly', () {
      const start = NotificationBannerTokens(
        notificationInfoBackground: Color(0xFF2196F3), // Colors.blue
        notificationInfoForeground: Color(0xFFFFFFFF), // Colors.white
        notificationSuccessBackground: Color(0xFF4CAF50), // Colors.green
        notificationSuccessForeground: Color(0xFFFFFFFF), // Colors.white
        notificationWarningBackground: Color(0xFFFF9800), // Colors.orange
        notificationWarningForeground: Color(0xFF000000), // Colors.black
        notificationErrorBackground: Color(0xFFF44336), // Colors.red
        notificationErrorForeground: Color(0xFFFFFFFF), // Colors.white
      );
      const end = NotificationBannerTokens(
        notificationInfoBackground: Color(0xFF03A9F4), // Colors.lightBlue
        notificationInfoForeground: Color(0xFF000000), // Colors.black
        notificationSuccessBackground: Color(0xFF8BC34A), // Colors.lightGreen
        notificationSuccessForeground: Color(0xFF000000), // Colors.black
        notificationWarningBackground: Color(0xFFFFEB3B), // Colors.yellow
        notificationWarningForeground: Color(0xFF9E9E9E), // Colors.grey
        notificationErrorBackground: Color(0xFFE91E63), // Colors.pink
        notificationErrorForeground: Color(0xFF000000), // Colors.black
      );

      final mid = start.lerp(end, 0.5);

      expect(
        mid.notificationInfoBackground,
        Color.lerp(const Color(0xFF2196F3), const Color(0xFF03A9F4), 0.5),
      );
      expect(
        start.lerp(end, 0).notificationSuccessForeground,
        start.notificationSuccessForeground,
      );
      expect(
        start.lerp(end, 1).notificationWarningBackground,
        end.notificationWarningBackground,
      );
    });

    test('hashCode is consistent', () {
      final instance1 = createDummy();
      final instance2 = createDummy();
      final instance3 = instance1.copyWith(
        notificationWarningForeground: Colors.cyan,
      );

      expect(instance1.hashCode, instance2.hashCode);
      expect(instance1.hashCode, isNot(equals(instance3.hashCode)));
    });

    test('== operator works correctly', () {
      final instance1 = createDummy();
      final instance2 = createDummy();
      final instance3 = instance1.copyWith(
        notificationErrorBackground: Colors.purple,
      );

      expect(instance1 == instance2, isTrue);
      expect(instance1 == instance3, isFalse);
      expect(instance1 == Object(), isFalse);
    });
  });
}
