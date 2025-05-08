import 'package:docjet_mobile/core/widgets/buttons/circular_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircularActionButton Widget Tests', () {
    testWidgets('renders correctly with required props', (
      WidgetTester tester,
    ) async {
      // Arrange - Setup widget with required properties
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularActionButton(
                buttonColor: Colors.blue,
                child: Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      // Assert - Verify the button is rendered
      expect(find.byType(CircularActionButton), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('executes onTap callback when tapped', (
      WidgetTester tester,
    ) async {
      // Arrange - Setup widget with a callback
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularActionButton(
                buttonColor: Colors.blue,
                onTap: () {
                  wasTapped = true;
                },
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      // Act - Tap the button
      await tester.tap(find.byType(CircularActionButton));
      await tester.pump();

      // Assert - Verify the callback was executed
      expect(wasTapped, true);
    });

    testWidgets('displays tooltip when provided', (WidgetTester tester) async {
      // Arrange - Setup widget with tooltip
      const String tooltipText = 'Test Tooltip';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularActionButton(
                buttonColor: Colors.blue,
                tooltip: tooltipText,
                child: Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      // Assert - Verify the tooltip is available
      expect(find.byType(Tooltip), findsOneWidget);

      // This verifies the tooltip text is in the widget tree
      expect(find.byTooltip(tooltipText), findsOneWidget);
    });

    testWidgets('respects size property', (WidgetTester tester) async {
      // Arrange - Setup widget with custom size
      const double customSize = 100.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularActionButton(
                buttonColor: Colors.blue,
                size: customSize,
                child: Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      // Assert - Verify size is applied
      final SizedBox sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CircularActionButton),
          matching: find.byType(SizedBox),
        ),
      );

      expect(sizedBox.width, equals(customSize));
      expect(sizedBox.height, equals(customSize));
    });
  });
}
