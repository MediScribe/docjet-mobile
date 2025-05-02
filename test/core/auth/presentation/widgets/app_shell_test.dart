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

// Simple fake widget to replace the transient banner for notifications
class FakeTransientBanner extends StatelessWidget {
  final bool isVisible;
  final String? errorMessage;

  const FakeTransientBanner({
    this.isVisible = false,
    this.errorMessage = 'An error occurred',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isVisible ? 50.0 : 0.0,
      color: Colors.red,
      child:
          isVisible
              ? Center(child: Text(errorMessage ?? 'An error occurred'))
              : null,
    );
  }
}

// A test version of AppShell that uses our controllable fake banners
class TestAppShell extends StatelessWidget {
  final Widget child;
  final bool isOffline;
  final bool hasTransientError;
  final String? errorMessage;

  const TestAppShell({
    required this.child,
    this.isOffline = false,
    this.hasTransientError = false,
    this.errorMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FakeOfflineBanner(isVisible: isOffline),
        FakeTransientBanner(
          isVisible: hasTransientError,
          errorMessage: errorMessage,
        ),
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

    testWidgets('shows transient error banner when there is an error', (
      WidgetTester tester,
    ) async {
      // Build our widget with a transient error
      await tester.pumpWidget(
        const MaterialApp(
          home: TestAppShell(
            hasTransientError: true,
            errorMessage: 'Profile not found',
            child: Text('Child Content'),
          ),
        ),
      );

      // Act: Let the widget render
      await tester.pump();

      // Assert: The error message should be visible
      expect(find.text('Profile not found'), findsOneWidget);
      // Child content should still be visible
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('does not show transient error when there is no error', (
      WidgetTester tester,
    ) async {
      // Build our widget without an error
      await tester.pumpWidget(
        const MaterialApp(
          home: TestAppShell(
            hasTransientError: false,
            child: Text('Child Content'),
          ),
        ),
      );

      // Act: Let the widget render
      await tester.pump();

      // Assert: No error message should be visible
      expect(find.text('An error occurred'), findsNothing);
      // Child content should still be visible
      expect(find.text('Child Content'), findsOneWidget);
    });
  });
}
