// This file contains End-to-End (E2E) tests for the DocJet Mobile app UI.
// It uses the 'integration_test' package to drive the app on a device/emulator.
// IMPORTANT: These tests rely on a mock API server being run externally.
// Use the './run_e2e_tests.sh' script to launch the tests and manage the server.

// Remove dotenv import
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

// Import the main app entry point. Make sure it can be configured
// (e.g., via environment variables or passed params) to use the mock server.
import 'package:docjet_mobile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Remove the dotenv.testLoad() block
  // // Load test-specific environment variables before running the app
  // // This ensures the app can load required keys like the API key.
  // dotenv.testLoad(
  //   fileInput: '''
  //     # Provide the API Key needed by main.dart
  //     API_KEY=test-api-key
  //     # Base URL is configured elsewhere (likely via DI)
  //   ''',
  // );

  testWidgets('App launches and finds initial MaterialApp widget', (
    WidgetTester tester,
  ) async {
    // Config is now handled entirely by --dart-define in the run script.
    app.main(); // Call the app's main function

    // Let the app settle
    await tester.pumpAndSettle();

    // Verify that the main app widget (MaterialApp) is present.
    // This is a basic check that the app didn't crash immediately.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Add more specific checks here later, e.g.:
    // expect(find.text('Login'), findsOneWidget);
  });
}
