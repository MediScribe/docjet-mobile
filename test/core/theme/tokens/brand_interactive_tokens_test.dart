import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/tokens/brand_interactive_tokens.dart';

void main() {
  group('BrandInteractiveTokens', () {
    // Helper
    BrandInteractiveTokens createDummy() {
      return const BrandInteractiveTokens(
        colorBrandPrimary: Color(0xFF000017),
        colorBrandOnPrimary: Color(0xFF000018),
        colorBrandSecondary: Color(0xFF000019),
        colorInteractivePrimaryBackground: Color(0xFF00001A),
        colorInteractivePrimaryForeground: Color(0xFF00001B),
        colorInteractiveSecondaryBackground: Color(0xFF00001C),
        colorInteractiveSecondaryForeground: Color(0xFF00001D),
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
      const newBrandPrimary = Color(0xFFFFFFFF);
      final copy = original.copyWith(colorBrandPrimary: newBrandPrimary);

      expect(copy.colorBrandPrimary, newBrandPrimary);
      expect(copy.colorBrandOnPrimary, original.colorBrandOnPrimary);
      expect(
        copy.colorInteractiveSecondaryForeground,
        original.colorInteractiveSecondaryForeground,
      );
    });

    test('lerp interpolates correctly', () {
      const start = BrandInteractiveTokens(
        colorBrandPrimary: Colors.blue,
        colorBrandOnPrimary: Colors.white,
        colorBrandSecondary: Colors.lightBlue,
        colorInteractivePrimaryBackground: Colors.blue,
        colorInteractivePrimaryForeground: Colors.white,
        colorInteractiveSecondaryBackground: Colors.grey,
        colorInteractiveSecondaryForeground: Colors.white,
      );
      const end = BrandInteractiveTokens(
        colorBrandPrimary: Colors.purple,
        colorBrandOnPrimary: Colors.black,
        colorBrandSecondary: Colors.purpleAccent,
        colorInteractivePrimaryBackground: Colors.purple,
        colorInteractivePrimaryForeground: Colors.black,
        colorInteractiveSecondaryBackground: Colors.blueGrey,
        colorInteractiveSecondaryForeground: Colors.black,
      );

      final mid = start.lerp(end, 0.5);

      expect(
        mid.colorBrandPrimary,
        Color.lerp(Colors.blue, Colors.purple, 0.5),
      );
      expect(start.lerp(end, 0).colorBrandOnPrimary, start.colorBrandOnPrimary);
      expect(
        start.lerp(end, 1).colorInteractiveSecondaryForeground,
        end.colorInteractiveSecondaryForeground,
      );
    });

    test('hashCode is consistent', () {
      final instance1 = createDummy();
      final instance2 = createDummy();
      final instance3 = instance1.copyWith(colorBrandSecondary: Colors.teal);

      expect(instance1.hashCode, instance2.hashCode);
      expect(instance1.hashCode, isNot(equals(instance3.hashCode)));
    });

    test('== operator works correctly', () {
      final instance1 = createDummy();
      final instance2 = createDummy();
      final instance3 = instance1.copyWith(
        colorInteractivePrimaryBackground: Colors.purple,
      );

      expect(instance1 == instance2, isTrue);
      expect(instance1 == instance3, isFalse);
      expect(instance1 == Object(), isFalse);
    });
  });
}
