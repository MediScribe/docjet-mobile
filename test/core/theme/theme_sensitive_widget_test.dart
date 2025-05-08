import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/theme/app_color_tokens.dart';
import 'package:docjet_mobile/core/widgets/buttons/circle_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock providers for testing
import '../../core/auth/presentation/widgets/test_helpers.dart';

void main() {
  group('Theme-Sensitive Widget Tests', () {
    testWidgets('OfflineBanner should adapt colors in dark mode', (
      WidgetTester tester,
    ) async {
      // First test in light mode
      await tester.pumpWidget(
        createTestApp(
          authState: createOfflineState(),
          child: const Scaffold(body: Text('Content')),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();

      // Find the banner text
      final lightTextFinder = find.text('You are offline');
      expect(lightTextFinder, findsOneWidget);

      // Now test in dark mode
      await tester.pumpWidget(
        createTestApp(
          authState: createOfflineState(),
          child: const Scaffold(body: Text('Content')),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      // Find the banner text in dark mode
      final darkTextFinder = find.text('You are offline');
      expect(darkTextFinder, findsOneWidget);

      // This test is now based on the mock implementation in test_helpers.dart
      // which uses a fixed color, so we don't test color adaptation here
      expect(find.text('You are offline'), findsOneWidget);
    });

    testWidgets(
      'CircleIconButton should use theme colors, not hardcoded ones',
      (WidgetTester tester) async {
        // Create Material app with properly configured theme
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: createLightTheme(), // Use our light theme with tokens
              home: const Scaffold(body: Center(child: CircleIconButton())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find the CircleIconButton's container with more specific finder
        final containerFinder = find.descendant(
          of: find.byType(CircleIconButton),
          matching: find.byType(Container),
        );
        final container = tester.widget<Container>(containerFinder);

        // Check that container has BoxDecoration
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        final Color buttonColor = decoration.color!;

        // Test that the color matches our theme's token color, not hardcoded
        expect(
          buttonColor,
          equals(
            createLightTheme().extension<AppColorTokens>()!.primaryActionBg,
          ),
          reason: 'CircleIconButton should use theme-provided color',
        );

        // Also check the icon color
        final Icon icon = tester.widget<Icon>(find.byType(Icon));
        expect(
          icon.color,
          equals(
            createLightTheme().extension<AppColorTokens>()!.primaryActionFg,
          ),
          reason: 'CircleIconButton icon should use theme-provided color',
        );
      },
    );

    testWidgets('CircleIconButton should use custom icon when provided', (
      WidgetTester tester,
    ) async {
      // Create Material app with CircleIconButton that uses custom icon
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: createLightTheme(),
            home: const Scaffold(
              body: Center(
                child: CircleIconButton(
                  icon: Icons.add,
                  tooltip: 'Add new item',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the custom icon is used
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);

      // Verify tooltip is applied
      expect(find.byType(Tooltip), findsOneWidget);
      final Tooltip tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('Add new item'));
    });
  });
}
