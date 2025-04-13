/// DOCJET LOGGING TESTING EXAMPLE
///
/// This test demonstrates how to use the logging test utilities.
/// It shows how to verify logging behavior in your tests.
///
/// Note: For real test code, you should import the utilities from:
/// import 'package:docjet_test/docjet_test.dart';

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_test/docjet_test.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import '../../examples/logging_example.dart' as logging_example;

void main() {
  // Basic example that just runs the example code
  test('Run logging example', () {
    logging_example.main();
    expect(true, isTrue);
  });

  // REAL DEMONSTRATION of testing with logging utilities
  group('Logging test utilities demonstration', () {
    late TestLogOutput logOutput;

    setUp(() {
      logOutput = captureLogOutput();
      // Reset log levels before each test
      resetLogLevels();
    });

    test('captures debug logs when enabled', () async {
      // Use the real withDebugLogging utility from docjet_test
      await withDebugLogging(logging_example.ExampleService, () async {
        final service = logging_example.ExampleService();
        service.doSomethingImportant();
      });

      // Now assert that we captured the expected logs
      expectLogContains(logOutput, Level.debug, 'Performing sub-step 1');
    });

    test('respects log level settings', () async {
      // Set log level to warning
      await withLogLevel(
        logging_example.ExampleService,
        Level.warning,
        () async {
          final service = logging_example.ExampleService();
          service.doSomethingImportant();
        },
      );

      // Debug messages should NOT be logged
      expect(
        logOutput.containsMessage(Level.debug, 'Performing sub-step'),
        isFalse,
        reason: 'Debug logs should not appear when log level is warning',
      );

      // But warnings should be logged (if they occur)
      // Note: this test might be flaky since warnings only happen when second % 2 == 0
      // In a real test you'd want more deterministic behavior
    });

    test('verifies absence of logs above certain level', () async {
      // Run code with info level
      await withLogLevel(
        logging_example.AnotherComponent,
        Level.info,
        () async {
          final component = logging_example.AnotherComponent();
          component.doLessImportantThing();
        },
      );

      // Verify no errors or warnings were logged
      expectNoLogsAboveLevel(logOutput, Level.info);
    });
  });
}
