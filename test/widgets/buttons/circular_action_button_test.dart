import 'package:docjet_mobile/core/widgets/buttons/circular_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode, SemanticsFlag;
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
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is SizedBox &&
              widget.width == customSize &&
              widget.height == customSize,
          description: 'SizedBox with width and height of $customSize',
        ),
      );

      expect(sizedBox.width, equals(customSize));
      expect(sizedBox.height, equals(customSize));
    });

    testWidgets('exposes Semantics with label and enabled state', (
      WidgetTester tester,
    ) async {
      const String tooltipText = 'Test Action';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularActionButton(
                buttonColor: Colors.blue,
                tooltip: tooltipText,
                onTap: () {}, // Enabled state
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      // Enable semantics for testing
      final SemanticsHandle semanticsHandle = tester.ensureSemantics();
      // Find the Semantics node associated with the button.
      final SemanticsNode node = tester.getSemantics(
        find.byType(CircularActionButton),
      );

      // Assert - Verify semantics properties
      // The label should come from the tooltip
      expect(node.label, tooltipText);
      // The button should be marked as a button
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      // The button should be enabled
      expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
      semanticsHandle.dispose();
    });

    testWidgets(
      'exposes Semantics with disabled state when onTap is null and has no tooltip',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularActionButton(
                  buttonColor: Colors.blue,
                  onTap: null, // Disabled state
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ),
        );

        // Enable semantics for testing
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        // Find the Semantics node. Since there's no tooltip, we find by type.
        final SemanticsNode node = tester.getSemantics(
          find.byType(CircularActionButton),
        );

        // Assert - Verify semantics properties
        expect(
          node.hasFlag(SemanticsFlag.isButton),
          isTrue,
          reason: "Semantics should identify it as a button",
        );
        expect(
          node.hasFlag(SemanticsFlag.isEnabled),
          isFalse,
          reason: "Semantics should be disabled as onTap is null",
        );
        // Check for a default or missing label, as no tooltip was provided.
        // Depending on implementation, label might be empty or a default.
        // For now, let's just check it's not null if it exists, or handle if it's expected to be absent.
        // If the widget doesn't provide a label when tooltip is null, this might need adjustment.
        // A more robust check might be that the label is an empty string if no tooltip is given.
        expect(
          node.label,
          equals('Action button'),
          reason: "Label should use default semantic when no tooltip is given.",
        );
        semanticsHandle.dispose();
      },
    );
  });
}
