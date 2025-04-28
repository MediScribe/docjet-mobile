import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple mock of HomeScreen for testing
class MockHomeScreen extends StatelessWidget {
  final bool isOffline;

  const MockHomeScreen({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Home')),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home Screen Placeholder'),
            const Text('User ID: test-user-id'),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed:
                  isOffline
                      ? null
                      : () {
                        // Navigator would be here in real code
                      },
              child: const Text('Go to Jobs List'),
            ),
            if (isOffline)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Network operations are disabled while offline',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('HomeScreen Offline Mode Tests', () {
    testWidgets('Network-dependent buttons are disabled when offline', (
      WidgetTester tester,
    ) async {
      // Build MockHomeScreen with offline state
      await tester.pumpWidget(
        MaterialApp(home: MockHomeScreen(isOffline: true)),
      );

      // Allow all animations and async operations to complete
      await tester.pumpAndSettle();

      // Find the "Go to Jobs List" button
      final buttonFinder = find.widgetWithText(
        CupertinoButton,
        'Go to Jobs List',
      );
      expect(buttonFinder, findsOneWidget);

      // Verify the button is disabled
      final button = tester.widget<CupertinoButton>(buttonFinder);
      expect(button.onPressed, isNull); // Should be null when disabled

      // Verify the offline message is displayed
      expect(
        find.text('Network operations are disabled while offline'),
        findsOneWidget,
      );
    });

    testWidgets('Network-dependent buttons are enabled when online', (
      WidgetTester tester,
    ) async {
      // Build MockHomeScreen with online state
      await tester.pumpWidget(
        MaterialApp(home: MockHomeScreen(isOffline: false)),
      );

      // Allow all animations and async operations to complete
      await tester.pumpAndSettle();

      // Find the "Go to Jobs List" button
      final buttonFinder = find.widgetWithText(
        CupertinoButton,
        'Go to Jobs List',
      );
      expect(buttonFinder, findsOneWidget);

      // Verify the button is enabled
      final button = tester.widget<CupertinoButton>(buttonFinder);
      expect(button.onPressed, isNotNull); // Should NOT be null when enabled

      // Verify no offline message is displayed
      expect(
        find.text('Network operations are disabled while offline'),
        findsNothing,
      );
    });
  });
}
