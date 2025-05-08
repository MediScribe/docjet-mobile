import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/tokens/semantic_status_tokens.dart';

void main() {
  group('SemanticStatusTokens', () {
    // Helper
    SemanticStatusTokens createDummy() {
      return const SemanticStatusTokens(
        colorSemanticRecordBackground: Color(0xFF00001E),
        colorSemanticRecordForeground: Color(0xFF00001F),
        colorSemanticPausedBackground: Color(0xFF000020),
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
      const newRecordFg = Color(0xFFFFFFFF);
      final copy = original.copyWith(
        colorSemanticRecordForeground: newRecordFg,
      );

      expect(copy.colorSemanticRecordForeground, newRecordFg);
      expect(
        copy.colorSemanticRecordBackground,
        original.colorSemanticRecordBackground,
      );
      expect(
        copy.colorSemanticPausedBackground,
        original.colorSemanticPausedBackground,
      );
    });

    test('lerp interpolates correctly', () {
      const start = SemanticStatusTokens(
        colorSemanticRecordBackground: Color(0xFFF44336),
        colorSemanticRecordForeground: Color(0xFFFFFFFF),
        colorSemanticPausedBackground: Color(0xFF2196F3),
      );
      const end = SemanticStatusTokens(
        colorSemanticRecordBackground: Color(0xFFE91E63),
        colorSemanticRecordForeground: Color(0xFF000000),
        colorSemanticPausedBackground: Color(0xFF03A9F4),
      );

      final mid = start.lerp(end, 0.5);

      expect(
        mid.colorSemanticRecordBackground,
        Color.lerp(const Color(0xFFF44336), const Color(0xFFE91E63), 0.5),
      );
      expect(
        start.lerp(end, 0).colorSemanticRecordForeground,
        start.colorSemanticRecordForeground,
      );
      expect(
        start.lerp(end, 1).colorSemanticPausedBackground,
        end.colorSemanticPausedBackground,
      );
    });

    test('hashCode is consistent', () {
      final instance1 = createDummy();
      final instance2 = createDummy();
      final instance3 = instance1.copyWith(
        colorSemanticPausedBackground: Colors.teal,
      );

      expect(instance1.hashCode, instance2.hashCode);
      expect(instance1.hashCode, isNot(equals(instance3.hashCode)));
    });

    test('== operator works correctly', () {
      final instance1 = createDummy();
      final instance2 = createDummy();
      final instance3 = instance1.copyWith(
        colorSemanticRecordBackground: Colors.purple,
      );

      expect(instance1 == instance2, isTrue);
      expect(instance1 == instance3, isFalse);
      expect(instance1 == Object(), isFalse);
    });
  });
}
