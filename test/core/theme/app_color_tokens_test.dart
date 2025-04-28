import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_color_tokens.dart';

// Test for AppColorTokens
void main() {
  group('AppColorTokens', () {
    test('should adapt colors between light and dark themes', () {
      // Get direct instances of the tokens, without MaterialApp
      final lightTokens = AppColorTokens.light(
        ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      );

      final darkTokens = AppColorTokens.dark(
        ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      );

      // Compare light and dark theme colors directly
      expect(
        lightTokens.dangerFg,
        isNot(equals(darkTokens.dangerFg)),
        reason: 'Danger foreground color should differ between themes',
      );

      expect(
        lightTokens.warningFg,
        isNot(equals(darkTokens.warningFg)),
        reason: 'Warning foreground color should differ between themes',
      );

      expect(
        lightTokens.successFg,
        isNot(equals(darkTokens.successFg)),
        reason: 'Success foreground color should differ between themes',
      );

      expect(
        lightTokens.infoFg,
        isNot(equals(darkTokens.infoFg)),
        reason: 'Info foreground color should differ between themes',
      );

      expect(
        lightTokens.recordButtonBg,
        isNot(equals(darkTokens.recordButtonBg)),
        reason: 'Record button background color should differ between themes',
      );
    });
  });
}
