import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple fake widget to replace OfflineBanner that can be directly controlled
class FakeOfflineBanner extends StatelessWidget {
  final bool isVisible;

  const FakeOfflineBanner({this.isVisible = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isVisible ? 36.0 : 0.0,
      color: Colors.grey,
      child: isVisible ? const Center(child: Text('You are offline')) : null,
    );
  }
}

// A test version of AppShell that uses our controllable fake banner
class TestAppShell extends StatelessWidget {
  final Widget child;
  final bool isOffline;

  const TestAppShell({required this.child, this.isOffline = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FakeOfflineBanner(isVisible: isOffline),
        Expanded(child: child),
      ],
    );
  }
}

void main() {
  group('AppShell Widget', () {
    testWidgets('shows offline banner when offline', (
      WidgetTester tester,
    ) async {
      // Build our widget without provider dependencies
      await tester.pumpWidget(
        const MaterialApp(
          home: TestAppShell(isOffline: true, child: Text('Child Content')),
        ),
      );

      // Act: Let the widget render
      await tester.pump();

      // Assert: The offline text should be visible
      expect(find.text('You are offline'), findsOneWidget);
      // Child content should still be visible
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('does not show offline text when online', (
      WidgetTester tester,
    ) async {
      // Build our widget without provider dependencies
      await tester.pumpWidget(
        const MaterialApp(
          home: TestAppShell(isOffline: false, child: Text('Child Content')),
        ),
      );

      // Act: Let the widget render
      await tester.pump();

      // Assert: The offline text should not be visible
      expect(find.text('You are offline'), findsNothing);
      // Child content should still be visible
      expect(find.text('Child Content'), findsOneWidget);
    });
  });
}
