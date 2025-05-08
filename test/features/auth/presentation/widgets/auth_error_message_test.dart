import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/theme/app_color_tokens.dart';

void main() {
  // Helper to pump the widget with MaterialApp and a theme
  Future<void> pumpAuthErrorMessage(
    WidgetTester tester,
    Widget widget, {
    bool useDarkTheme = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: useDarkTheme ? createDarkTheme() : createLightTheme(),
        home: Scaffold(body: widget),
      ),
    );
  }

  group('AuthErrorMessage Widget Tests', () {
    testWidgets(
      'offlineMode displays with correct background and foreground colors in Light Theme',
      (WidgetTester tester) async {
        // Arrange
        final widget = AuthErrorMessage.offlineMode();
        final lightTheme = createLightTheme();
        final AppColorTokens lightAppColors =
            lightTheme.extension<AppColorTokens>()!;

        // Act
        await pumpAuthErrorMessage(tester, widget, useDarkTheme: false);

        // Assert
        // Find the Container responsible for the background
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.color == lightAppColors.baseStatus.offlineBg,
        );
        expect(
          containerFinder,
          findsOneWidget,
          reason:
              "Expected to find a Container with offlineBg color in light theme.",
        );

        // Find the Text widget
        final textFinder = find.text('Offline Mode');
        expect(textFinder, findsOneWidget);

        // Verify text color
        final Text textWidget = tester.widget(textFinder);
        expect(
          textWidget.style?.color,
          lightAppColors.baseStatus.offlineFg,
          reason: "Text color should be offlineFg in light theme.",
        );
        expect(
          textWidget.textAlign,
          TextAlign.center,
          reason: "Text should be centered.",
        );
      },
    );

    testWidgets(
      'offlineMode displays with correct background and foreground colors in Dark Theme',
      (WidgetTester tester) async {
        // Arrange
        final widget = AuthErrorMessage.offlineMode();
        final darkTheme = createDarkTheme();
        final AppColorTokens darkAppColors =
            darkTheme.extension<AppColorTokens>()!;

        // Act
        await pumpAuthErrorMessage(tester, widget, useDarkTheme: true);

        // Assert
        // Find the Container responsible for the background
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.color == darkAppColors.baseStatus.offlineBg,
        );
        expect(
          containerFinder,
          findsOneWidget,
          reason:
              "Expected to find a Container with offlineBg color in dark theme.",
        );

        // Find the Text widget
        final textFinder = find.text('Offline Mode');
        expect(textFinder, findsOneWidget);

        // Verify text color
        final Text textWidget = tester.widget(textFinder);
        expect(
          textWidget.style?.color,
          darkAppColors.baseStatus.offlineFg,
          reason: "Text color should be offlineFg in dark theme.",
        );
        expect(
          textWidget.textAlign,
          TextAlign.center,
          reason: "Text should be centered.",
        );
      },
    );

    testWidgets(
      'other error types use dangerFg color and no special background in Light Theme',
      (WidgetTester tester) async {
        // Arrange
        final widget = AuthErrorMessage(
          errorMessage: 'Generic Error',
          errorType: AuthErrorType.unknown,
        );
        final lightTheme = createLightTheme();
        final AppColorTokens lightAppColors =
            lightTheme.extension<AppColorTokens>()!;

        // Act
        await pumpAuthErrorMessage(tester, widget, useDarkTheme: false);

        // Assert
        // Ensure no Container with offlineBg is present
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.color == lightAppColors.baseStatus.offlineBg,
        );
        expect(
          containerFinder,
          findsNothing,
          reason:
              "Expected no Container with offlineBg for non-offline errors.",
        );

        // Find the Text widget
        final textFinder = find.text('Generic Error');
        expect(textFinder, findsOneWidget);

        // Verify text color (should be dangerFg)
        final Text textWidget = tester.widget(textFinder);
        expect(
          textWidget.style?.color,
          lightAppColors.baseStatus.dangerFg,
          reason:
              "Text color should be dangerFg for generic errors in light theme.",
        );
      },
    );

    testWidgets(
      'other error types use dangerFg color and no special background in Dark Theme',
      (WidgetTester tester) async {
        // Arrange
        final widget = AuthErrorMessage(
          errorMessage: 'Generic Error',
          errorType: AuthErrorType.unknown,
        );
        final darkTheme = createDarkTheme();
        final AppColorTokens darkAppColors =
            darkTheme.extension<AppColorTokens>()!;

        // Act
        await pumpAuthErrorMessage(tester, widget, useDarkTheme: true);

        // Assert
        // Ensure no Container with offlineBg is present
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.color == darkAppColors.baseStatus.offlineBg,
        );
        expect(
          containerFinder,
          findsNothing,
          reason:
              "Expected no Container with offlineBg for non-offline errors in dark theme.",
        );

        // Find the Text widget
        final textFinder = find.text('Generic Error');
        expect(textFinder, findsOneWidget);

        // Verify text color (should be dangerFg)
        final Text textWidget = tester.widget(textFinder);
        expect(
          textWidget.style?.color,
          darkAppColors.baseStatus.dangerFg,
          reason:
              "Text color should be dangerFg for generic errors in dark theme.",
        );
      },
    );
  });
}
