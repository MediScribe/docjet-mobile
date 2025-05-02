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

      // Verify the close icon button exists
      expect(find.widgetWithIcon(IconButton, Icons.close), findsOneWidget);
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

      // Tap the close button
      await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
      await tester.pump();

      // Verify onDismiss was called
      expect(onDismissCalled, true);
    });

    testWidgets('dismiss button has correct tooltip', (tester) async {
      final message = AppMessage(
        message: 'Tooltip test',
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

      final buttonFinder = find.widgetWithIcon(IconButton, Icons.close);
      expect(buttonFinder, findsOneWidget);

      final IconButton button = tester.widget(buttonFinder);
      final localizations = MaterialLocalizations.of(
        tester.element(buttonFinder),
      );
      expect(button.tooltip, localizations.closeButtonTooltip);
    });
  });
}
