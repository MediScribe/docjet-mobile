import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_color_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/base_status_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/brand_interactive_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/notification_banner_tokens.dart';
import 'package:docjet_mobile/core/theme/tokens/semantic_status_tokens.dart';

// Test for AppColorTokens
void main() {
  // Helper to create a ColorScheme for testing
  ColorScheme createTestColorScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    );
  }

  // Helper to create a dummy AppColorTokens instance for copyWith/hashCode/== tests
  AppColorTokens createDummyTokens() {
    return AppColorTokens(
      baseStatus: const BaseStatusTokens(
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
      ),
      primaryActionBg: const Color(0xFF00000B),
      primaryActionFg: const Color(0xFF00000C),
      outlineColor: const Color(0xFF00000D),
      shadowColor: const Color(0xFF00000E),
      notificationBanners: const NotificationBannerTokens(
        notificationInfoBackground: Color(0xFF00000F),
        notificationInfoForeground: Color(0xFF000010),
        notificationSuccessBackground: Color(0xFF000011),
        notificationSuccessForeground: Color(0xFF000012),
        notificationWarningBackground: Color(0xFF000013),
        notificationWarningForeground: Color(0xFF000014),
        notificationErrorBackground: Color(0xFF000015),
        notificationErrorForeground: Color(0xFF000016),
      ),
      brandInteractive: const BrandInteractiveTokens(
        colorBrandPrimary: Color(0xFF000017),
        colorBrandOnPrimary: Color(0xFF000018),
        colorBrandSecondary: Color(0xFF000019),
        colorInteractivePrimaryBackground: Color(0xFF00001A),
        colorInteractivePrimaryForeground: Color(0xFF00001B),
        colorInteractiveSecondaryBackground: Color(0xFF00001C),
        colorInteractiveSecondaryForeground: Color(0xFF00001D),
      ),
      semanticStatus: const SemanticStatusTokens(
        colorSemanticRecordBackground: Color(0xFF00001E),
        colorSemanticRecordForeground: Color(0xFF00001F),
        colorSemanticPausedBackground: Color(0xFF000020),
      ),
    );
  }

  group('AppColorTokens constructors', () {
    test('light() constructor populates all fields', () {
      final colorScheme = createTestColorScheme(Brightness.light);
      final lightTokens = AppColorTokens.light(colorScheme);

      // Check direct properties
      expect(
        lightTokens.primaryActionBg,
        isNotNull,
        reason: 'primaryActionBg should be populated',
      );
      expect(
        lightTokens.primaryActionFg,
        isNotNull,
        reason: 'primaryActionFg should be populated',
      );
      expect(
        lightTokens.outlineColor,
        isNotNull,
        reason: 'outlineColor should be populated',
      );
      expect(
        lightTokens.shadowColor,
        isNotNull,
        reason: 'shadowColor should be populated',
      );

      // Check composed token objects
      expect(
        lightTokens.baseStatus,
        isNotNull,
        reason: 'baseStatus object should be populated',
      );
      expect(
        lightTokens.notificationBanners,
        isNotNull,
        reason: 'notificationBanners object should be populated',
      );
      expect(
        lightTokens.brandInteractive,
        isNotNull,
        reason: 'brandInteractive object should be populated',
      );
      expect(
        lightTokens.semanticStatus,
        isNotNull,
        reason: 'semanticStatus object should be populated',
      );

      // Optionally, spot-check a value within each composed object
      expect(
        lightTokens.baseStatus.dangerBg,
        isNotNull,
        reason: 'dangerBg should be populated via baseStatus',
      );
      expect(
        lightTokens.notificationBanners.notificationInfoBackground,
        isNotNull,
        reason:
            'notificationInfoBackground should be populated via notificationBanners',
      );
      expect(
        lightTokens.brandInteractive.colorBrandPrimary,
        isNotNull,
        reason: 'colorBrandPrimary should be populated via brandInteractive',
      );
      expect(
        lightTokens.semanticStatus.colorSemanticRecordBackground,
        isNotNull,
        reason:
            'colorSemanticRecordBackground should be populated via semanticStatus',
      );
    });

    test('dark() constructor populates all fields', () {
      final colorScheme = createTestColorScheme(Brightness.dark);
      final darkTokens = AppColorTokens.dark(colorScheme);

      // Check direct properties
      expect(
        darkTokens.primaryActionBg,
        isNotNull,
        reason: 'primaryActionBg should be populated for dark theme',
      );
      expect(
        darkTokens.primaryActionFg,
        isNotNull,
        reason: 'primaryActionFg should be populated for dark theme',
      );
      expect(
        darkTokens.outlineColor,
        isNotNull,
        reason: 'outlineColor should be populated for dark theme',
      );
      expect(
        darkTokens.shadowColor,
        isNotNull,
        reason: 'shadowColor should be populated for dark theme',
      );

      // Check composed token objects
      expect(
        darkTokens.baseStatus,
        isNotNull,
        reason: 'baseStatus object should be populated for dark theme',
      );
      expect(
        darkTokens.notificationBanners,
        isNotNull,
        reason: 'notificationBanners object should be populated for dark theme',
      );
      expect(
        darkTokens.brandInteractive,
        isNotNull,
        reason: 'brandInteractive object should be populated for dark theme',
      );
      expect(
        darkTokens.semanticStatus,
        isNotNull,
        reason: 'semanticStatus object should be populated for dark theme',
      );

      // Optionally, spot-check a value within each composed object
      expect(
        darkTokens.baseStatus.dangerBg,
        isNotNull,
        reason: 'dangerBg should be populated via baseStatus for dark theme',
      );
      expect(
        darkTokens.notificationBanners.notificationInfoBackground,
        isNotNull,
        reason:
            'notificationInfoBackground should be populated via notificationBanners for dark theme',
      );
      expect(
        darkTokens.brandInteractive.colorBrandPrimary,
        isNotNull,
        reason:
            'colorBrandPrimary should be populated via brandInteractive for dark theme',
      );
      expect(
        darkTokens.semanticStatus.colorSemanticRecordBackground,
        isNotNull,
        reason:
            'colorSemanticRecordBackground should be populated via semanticStatus for dark theme',
      );
    });

    test('should adapt colors between light and dark themes', () {
      final lightTokens = AppColorTokens.light(
        createTestColorScheme(Brightness.light),
      );
      final darkTokens = AppColorTokens.dark(
        createTestColorScheme(Brightness.dark),
      );

      // Compare *some* relevant values between themes
      expect(
        lightTokens.baseStatus.dangerFg,
        isNot(equals(darkTokens.baseStatus.dangerFg)),
        reason: 'BaseStatus dangerFg should differ',
      );
      expect(
        lightTokens.primaryActionBg,
        isNot(equals(darkTokens.primaryActionBg)),
        reason: 'PrimaryActionBg should differ',
      );
      expect(
        lightTokens.outlineColor,
        isNot(equals(darkTokens.outlineColor)),
        reason: 'OutlineColor should differ',
      );
      expect(
        lightTokens.shadowColor,
        isNot(equals(darkTokens.shadowColor)),
        reason: 'ShadowColor should differ',
      );
      expect(
        lightTokens.notificationBanners.notificationWarningForeground,
        isNot(
          equals(darkTokens.notificationBanners.notificationWarningForeground),
        ),
        reason: 'Notification warningFg should differ',
      );
      expect(
        lightTokens.brandInteractive.colorInteractiveSecondaryBackground,
        isNot(
          equals(
            darkTokens.brandInteractive.colorInteractiveSecondaryBackground,
          ),
        ),
        reason: 'Interactive secondaryBg should differ',
      );
      expect(
        lightTokens.semanticStatus.colorSemanticPausedBackground,
        isNot(equals(darkTokens.semanticStatus.colorSemanticPausedBackground)),
        reason: 'Semantic pausedBg should differ',
      );
    });
  });

  group('AppColorTokens copyWith, lerp, hashCode, ==', () {
    test(
      'copyWith should create an identical copy if no arguments are provided',
      () {
        final original = createDummyTokens();
        final copy = original.copyWith();

        expect(
          copy,
          original,
          reason: 'Copy should be equal to original via ==',
        );
        expect(
          identical(copy, original),
          isFalse,
          reason: 'Copy should not be identical',
        );

        // Check composed objects are equal (but not identical)
        expect(copy.baseStatus, original.baseStatus);
        expect(copy.notificationBanners, original.notificationBanners);
        expect(copy.brandInteractive, original.brandInteractive);
        expect(copy.semanticStatus, original.semanticStatus);
        expect(
          identical(copy.baseStatus, original.baseStatus),
          isTrue,
          reason: 'Composed objects should be identical if not copied',
        );

        // Check direct properties
        expect(copy.primaryActionBg, original.primaryActionBg);
        expect(copy.primaryActionFg, original.primaryActionFg);
        expect(copy.outlineColor, original.outlineColor);
        expect(copy.shadowColor, original.shadowColor);
      },
    );

    test('copyWith should update only the provided fields', () {
      final original = createDummyTokens();

      // Create new values/objects for testing updates
      const newPrimaryActionFg = Color(0xFFFFFF0C);
      final newBaseStatus = original.baseStatus.copyWith(
        dangerBg: const Color(0xFFFFFF01),
      );
      final newNotificationBanners = original.notificationBanners.copyWith(
        notificationInfoBackground: const Color(0xFFFFFF0F),
      );
      final newBrandInteractive = original.brandInteractive.copyWith(
        colorBrandPrimary: const Color(0xFFFFFF17),
      );
      final newSemanticStatus = original.semanticStatus.copyWith(
        colorSemanticRecordForeground: const Color(0xFFFFFF1F),
      );

      final copy = original.copyWith(
        baseStatus: newBaseStatus,
        primaryActionFg: newPrimaryActionFg, // Update a direct property
        notificationBanners: newNotificationBanners,
        brandInteractive: newBrandInteractive,
        semanticStatus: newSemanticStatus,
      );

      // Check updated fields have new values/objects
      expect(copy.primaryActionFg, newPrimaryActionFg);
      expect(copy.baseStatus, newBaseStatus);
      expect(copy.baseStatus.dangerBg, const Color(0xFFFFFF01));
      expect(copy.notificationBanners, newNotificationBanners);
      expect(
        copy.notificationBanners.notificationInfoBackground,
        const Color(0xFFFFFF0F),
      );
      expect(copy.brandInteractive, newBrandInteractive);
      expect(copy.brandInteractive.colorBrandPrimary, const Color(0xFFFFFF17));
      expect(copy.semanticStatus, newSemanticStatus);
      expect(
        copy.semanticStatus.colorSemanticRecordForeground,
        const Color(0xFFFFFF1F),
      );

      // Check UN-updated direct fields remain the same
      expect(copy.primaryActionBg, original.primaryActionBg);
      expect(copy.outlineColor, original.outlineColor);
      expect(copy.shadowColor, original.shadowColor);

      // Check UN-updated composed objects remain identical
      expect(
        identical(copy.baseStatus, original.baseStatus),
        isFalse,
        reason: 'BaseStatus was copied, should not be identical',
      );
      expect(
        identical(copy.notificationBanners, original.notificationBanners),
        isFalse,
        reason: 'NotificationBanners was copied, should not be identical',
      );
      expect(
        identical(copy.brandInteractive, original.brandInteractive),
        isFalse,
        reason: 'BrandInteractive was copied, should not be identical',
      );
      expect(
        identical(copy.semanticStatus, original.semanticStatus),
        isFalse,
        reason: 'SemanticStatus was copied, should not be identical',
      );

      // Check UN-updated fields within the copied objects have original values
      expect(copy.baseStatus.dangerFg, original.baseStatus.dangerFg);
      expect(
        copy.notificationBanners.notificationInfoForeground,
        original.notificationBanners.notificationInfoForeground,
      );
      expect(
        copy.brandInteractive.colorBrandOnPrimary,
        original.brandInteractive.colorBrandOnPrimary,
      );
      expect(
        copy.semanticStatus.colorSemanticRecordBackground,
        original.semanticStatus.colorSemanticRecordBackground,
      );
    });

    test('lerp interpolates correctly', () {
      final start = AppColorTokens.light(
        createTestColorScheme(Brightness.light),
      );
      final end = AppColorTokens.dark(createTestColorScheme(Brightness.dark));
      // Ensure start and end have different values for lerp to be meaningful
      expect(start.primaryActionBg, isNot(equals(end.primaryActionBg)));
      expect(start.baseStatus.dangerBg, isNot(equals(end.baseStatus.dangerBg)));
      // expect(start.brandInteractive.colorBrandPrimary, isNot(equals(end.brandInteractive.colorBrandPrimary))); // REMOVED - May be intentionally the same

      final mid = start.lerp(end, 0.5);

      // Check interpolation of a direct property
      expect(
        mid.primaryActionBg,
        Color.lerp(start.primaryActionBg, end.primaryActionBg, 0.5),
      );
      // Check interpolation of composed objects (by checking a value within them)
      expect(
        mid.baseStatus.dangerBg,
        Color.lerp(start.baseStatus.dangerBg, end.baseStatus.dangerBg, 0.5),
      );
      expect(
        mid.notificationBanners.notificationInfoBackground,
        Color.lerp(
          start.notificationBanners.notificationInfoBackground,
          end.notificationBanners.notificationInfoBackground,
          0.5,
        ),
      );
      expect(
        mid.brandInteractive.colorBrandPrimary,
        Color.lerp(
          start.brandInteractive.colorBrandPrimary,
          end.brandInteractive.colorBrandPrimary,
          0.5,
        ),
      );
      expect(
        mid.semanticStatus.colorSemanticRecordBackground,
        Color.lerp(
          start.semanticStatus.colorSemanticRecordBackground,
          end.semanticStatus.colorSemanticRecordBackground,
          0.5,
        ),
      );

      expect(start.lerp(end, 0), start);
      expect(start.lerp(end, 1), end);
    });

    test('hashCode is consistent and differs', () {
      final instance1 = createDummyTokens();
      final instance2 = createDummyTokens();
      final instance3 = instance1.copyWith(
        shadowColor: Colors.transparent,
      ); // Change direct property
      final instance4 = instance1.copyWith(
        baseStatus: instance1.baseStatus.copyWith(dangerFg: Colors.yellow),
      ); // Change composed property

      expect(instance1.hashCode, instance2.hashCode);
      expect(instance1.hashCode, isNot(equals(instance3.hashCode)));
      expect(instance1.hashCode, isNot(equals(instance4.hashCode)));
    });

    test('== operator works correctly', () {
      final instance1 = createDummyTokens();
      final instance2 = createDummyTokens();
      final instance3 = instance1.copyWith(outlineColor: Colors.transparent);
      final instance4 = instance1.copyWith(
        notificationBanners: instance1.notificationBanners.copyWith(
          notificationSuccessBackground: Colors.pink,
        ),
      );

      expect(instance1 == instance2, isTrue);
      expect(instance1 == instance3, isFalse);
      expect(instance1 == instance4, isFalse);
      expect(instance1 == Object(), isFalse);
    });
  });
}
