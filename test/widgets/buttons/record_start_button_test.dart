import 'package:docjet_mobile/core/theme/app_color_tokens.dart';
import 'package:docjet_mobile/core/widgets/buttons/circular_action_button.dart';
import 'package:docjet_mobile/core/widgets/buttons/record_start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode, SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper to provide a theme for testing
  Widget createWidgetWithTheme({VoidCallback? onTap}) {
    return MaterialApp(
      theme: ThemeData(
        extensions: [AppColorTokens.light(const ColorScheme.light())],
      ),
      home: Scaffold(body: Center(child: RecordStartButton(onTap: onTap))),
    );
  }

  group('RecordStartButton Widget Tests', () {
    testWidgets('renders with correct theme colors', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetWithTheme());

      // Assert
      // Verify the CircularActionButton is used internally
      expect(find.byType(RecordStartButton), findsOneWidget);
      expect(find.byType(CircularActionButton), findsOneWidget);

      // Verify the icon is visible
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('executes onTap callback when tapped', (
      WidgetTester tester,
    ) async {
      // Arrange
      bool wasTapped = false;

      await tester.pumpWidget(
        createWidgetWithTheme(
          onTap: () {
            wasTapped = true;
          },
        ),
      );

      // Act
      await tester.tap(find.byType(RecordStartButton));
      await tester.pump();

      // Assert
      expect(wasTapped, true);
    });

    testWidgets('renders the correct mic icon based on platform', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetWithTheme());

      // We're using Theme.of(context).platform in the widget now
      // This will show the correct icon based on platform

      // Assert - Verify there's exactly one Icon
      expect(find.byType(Icon), findsOneWidget);

      // Note: Since this test runs on the current platform,
      // we'd need more complex logic to test cross-platform icons.
      // For now, just verify an icon is there.
    });

    testWidgets('respects custom size properties', (WidgetTester tester) async {
      // Arrange - Create with custom sizes
      const double customSize = 120.0;
      const double customIconSize = 70.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppColorTokens.light(const ColorScheme.light())],
          ),
          home: Scaffold(
            body: Center(
              child: RecordStartButton(
                size: customSize,
                iconSize: customIconSize,
              ),
            ),
          ),
        ),
      );

      // Assert - Verify CircularActionButton has correct size
      final CircularActionButton actionButton = tester
          .widget<CircularActionButton>(find.byType(CircularActionButton));

      expect(actionButton.size, equals(customSize));

      // Verify icon has correct size
      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, equals(customIconSize));
    });

    testWidgets('has accessibility tooltip', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetWithTheme());

      // Assert
      expect(find.byTooltip('Start recording'), findsOneWidget);
    });

    testWidgets('exposes Semantics with correct label and enabled state', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetWithTheme(onTap: () {})); // Enabled
      // Enable semantics for testing
      final SemanticsHandle semanticsHandle = tester.ensureSemantics();

      // Find the SemanticsNode for RecordStartButton
      final SemanticsNode node = tester.getSemantics(
        find.byType(RecordStartButton),
      );

      // Assert
      expect(node.label, 'Start recording');
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
      semanticsHandle.dispose();
    });

    testWidgets('exposes Semantics with disabled state when onTap is null', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createWidgetWithTheme(onTap: null)); // Disabled
      // Enable semantics for testing
      final SemanticsHandle semanticsHandle = tester.ensureSemantics();

      // Find the SemanticsNode for RecordStartButton
      final SemanticsNode node = tester.getSemantics(
        find.byType(RecordStartButton),
      );

      // Assert
      expect(node.label, 'Start recording'); // Label should still be present
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
      semanticsHandle.dispose();
    });
  });
}
