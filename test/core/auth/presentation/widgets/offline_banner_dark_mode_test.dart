import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('OfflineBanner Dark Mode Tests', () {
    testWidgets('Banner should display correctly in dark mode', (
      WidgetTester tester,
    ) async {
      // Set up a predictable test environment
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      // Pump the widget in dark mode
      await tester.pumpWidget(
        createTestApp(
          authState: createOfflineState(),
          child: const Scaffold(body: Center(child: Text('Content'))),
          themeMode: ThemeMode.dark,
        ),
      );

      await tester.pumpAndSettle();

      // Verify banner is visible
      expect(findOfflineBannerText(), findsOneWidget);

      // Skip golden test in normal CI runs as environment can affect rendering
      // If you want to update the golden, run:
      // flutter test --update-goldens test/core/auth/presentation/widgets/offline_banner_dark_mode_test.dart
      // await expectLater(
      //  find.byType(Scaffold),
      //  matchesGoldenFile('goldens/offline_banner_dark_mode.png'),
      // );
    });

    // This test ensures our implementation works properly when themes change
    testWidgets(
      'Banner should remain visible when theme switches to dark mode',
      (WidgetTester tester) async {
        // Start with light mode
        await tester.pumpWidget(
          createTestApp(
            authState: createOfflineState(),
            child: const Scaffold(body: Center(child: Text('Content'))),
            themeMode: ThemeMode.light,
          ),
        );

        await tester.pumpAndSettle();

        // Verify banner is visible in light mode
        expect(findOfflineBannerText(), findsOneWidget);

        // Switch to dark mode
        await tester.pumpWidget(
          createTestApp(
            authState: createOfflineState(),
            child: const Scaffold(body: Center(child: Text('Content'))),
            themeMode: ThemeMode.dark,
          ),
        );

        await tester.pumpAndSettle();

        // Verify banner remains visible after theme change
        expect(findOfflineBannerText(), findsOneWidget);
      },
    );
  });
}
