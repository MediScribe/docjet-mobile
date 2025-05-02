import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/widgets/configurable_transient_banner.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart'; // Import for theme

void main() {
  group('ConfigurableTransientBanner Tests', () {
    testWidgets('displays correct message for info type', (tester) async {
      final message = AppMessage(message: 'Info test', type: MessageType.info);

      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: ConfigurableTransientBanner(
              message: message,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Verify the message text is displayed
      expect(find.text('Info test'), findsOneWidget);

      // Verify the close icon exists (now inside a GestureDetector)
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays correct message for success type', (tester) async {
      final message = AppMessage(
        message: 'Success test',
        type: MessageType.success,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: ConfigurableTransientBanner(
              message: message,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Verify the message text is displayed
      expect(find.text('Success test'), findsOneWidget);
    });

    testWidgets('displays correct message for warning type', (tester) async {
      final message = AppMessage(
        message: 'Warning test',
        type: MessageType.warning,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: ConfigurableTransientBanner(
              message: message,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Verify the message text is displayed
      expect(find.text('Warning test'), findsOneWidget);
    });

    testWidgets('displays correct message for error type', (tester) async {
      final message = AppMessage(
        message: 'Error test',
        type: MessageType.error,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: ConfigurableTransientBanner(
              message: message,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Verify the message text is displayed
      expect(find.text('Error test'), findsOneWidget);
    });

    testWidgets('calls onDismiss when close button is tapped', (tester) async {
      bool onDismissCalled = false;
      final message = AppMessage(
        message: 'Test message',
        type: MessageType.info,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: ConfigurableTransientBanner(
              message: message,
              onDismiss: () {
                onDismissCalled = true;
              },
            ),
          ),
        ),
      );

      // Find and tap the close icon inside the GestureDetector
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Verify onDismiss was called
      expect(onDismissCalled, true);
    });

    testWidgets('has accessible close action', (tester) async {
      final message = AppMessage(
        message: 'Accessibility test',
        type: MessageType.info,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: ConfigurableTransientBanner(
              message: message,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Verify we have a GestureDetector with tap functionality
      final gestureDetector = find.byType(GestureDetector);
      expect(gestureDetector, findsOneWidget);

      // Verify it contains a close icon
      expect(
        find.descendant(
          of: gestureDetector,
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
      );
    });
  });
}
