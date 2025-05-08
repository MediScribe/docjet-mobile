import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/tokens/base_status_tokens.dart';

void main() {
  group('BaseStatusTokens', () {
    // Helper to create a dummy instance
    BaseStatusTokens createDummy() {
      return const BaseStatusTokens(
        dangerBg: Color(0xFF000001),
        dangerFg: Color(0xFF000002),
        warningBg: Color(0xFF000003),
        warningFg: Color(0xFF000004),
        successBg: Color(0xFF000005),
        successFg: Color(0xFF000006),
        infoBg: Color(0xFF000007),
        infoFg: Color(0xFF000008),
        offlineBg: Color(0xFF000009),
        offlineFg: Color(0xFF00000A),
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
      const newDangerFg = Color(0xFFFFFFFF);
      final copy = original.copyWith(dangerFg: newDangerFg);

      expect(copy.dangerFg, newDangerFg);
      expect(
        copy.dangerBg,
        original.dangerBg,
      ); // Check other fields remain unchanged
      expect(copy.warningBg, original.warningBg);
      expect(copy.offlineFg, original.offlineFg);
    });

    test('lerp interpolates correctly', () {
      const start = BaseStatusTokens(
        dangerBg: Color(0xFFF44336), // Colors.red
        dangerFg: Color(0xFFFFFFFF), // Colors.white
        warningBg: Color(0xFFFF9800), // Colors.orange
        warningFg: Color(0xFF000000), // Colors.black
        successBg: Color(0xFF4CAF50), // Colors.green
        successFg: Color(0xFFFFFFFF), // Colors.white
        infoBg: Color(0xFF2196F3), // Colors.blue
        infoFg: Color(0xFFFFFFFF), // Colors.white
        offlineBg: Color(0xFF9E9E9E), // Colors.grey
        offlineFg: Color(0xFFFFFFFF), // Colors.white
      );
      const end = BaseStatusTokens(
        dangerBg: Color(0xFFE91E63), // Colors.pink
        dangerFg: Color(0xFF000000), // Colors.black
        warningBg: Color(0xFFFFEB3B), // Colors.yellow
        warningFg: Color(0xFF9E9E9E), // Colors.grey
        successBg: Color(0xFF8BC34A), // Colors.lightGreen
        successFg: Color(0xFF000000), // Colors.black
        infoBg: Color(0xFF03A9F4), // Colors.lightBlue
        infoFg: Color(0xFF000000), // Colors.black
        offlineBg: Color(0xFF607D8B), // Colors.blueGrey
        offlineFg: Color(0xFF000000), // Colors.black
      );

      final mid = start.lerp(end, 0.5);

      // Check one interpolated color property
      expect(
        mid.dangerBg,
        Color.lerp(const Color(0xFFF44336), const Color(0xFFE91E63), 0.5),
      );
      // Check one non-color property that should be identical to start at t=0
      expect(start.lerp(end, 0).dangerFg, start.dangerFg);
      // Check one non-color property that should be identical to end at t=1
      expect(start.lerp(end, 1).warningFg, end.warningFg);
    });

    test('hashCode is consistent', () {
      final instance1 = createDummy();
      final instance2 = createDummy(); // Identical content
      final instance3 = instance1.copyWith(successBg: Colors.teal);

      expect(instance1.hashCode, instance2.hashCode);
      expect(instance1.hashCode, isNot(equals(instance3.hashCode)));
    });

    test('== operator works correctly', () {
      final instance1 = createDummy();
      final instance2 = createDummy(); // Identical content
      final instance3 = instance1.copyWith(infoFg: Colors.purple);

      expect(instance1 == instance2, isTrue);
      expect(instance1 == instance3, isFalse);
      expect(instance1 == Object(), isFalse);
    });
  });
}
