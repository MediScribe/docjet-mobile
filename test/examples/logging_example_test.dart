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
import 'package:docjet_mobile/core/utils/log_helpers.dart' as app_logging;
import 'package:logger/logger.dart' show Level;
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

    // String-based logger tests
    group('String-based logger tests', () {
      test('captures logs from string-based loggers', () async {
        // Use the string identifier from StringBasedLoggerExample
        await withDebugLogging(
          logging_example.StringBasedLoggerExample.identifier,
          () async {
            final stringLogger = logging_example.StringBasedLoggerExample();
            stringLogger.runExample();
          },
        );

        // Now assert that we captured the expected logs
        expectLogContains(
          logOutput,
          Level.debug,
          'This is a debug message from string-based logger',
        );
      });

      test('sets log levels for string-based loggers', () async {
        // Set log level to warning
        await withLogLevel(
          logging_example.StringBasedLoggerExample.identifier,
          Level.warning,
          () async {
            final stringLogger = logging_example.StringBasedLoggerExample();
            stringLogger.runExample();
          },
        );

        // Info messages should NOT be logged when level is warning
        expect(
          logOutput.containsMessage(
            Level.info,
            'String-based logger example completed',
          ),
          isFalse,
          reason: 'Info logs should not appear when log level is warning',
        );
      });

      test('expectNoLogsFrom works with string identifiers', () async {
        final testIdentifier = "TestOnlyLogger";

        // Run test with trace level to capture everything
        await withLogLevel(testIdentifier, Level.trace, () async {
          // Create logger with this identifier
          final logger = app_logging.LoggerFactory.getLogger(testIdentifier);
          final tag = app_logging.logTag(testIdentifier);

          // Generate INFO logs only (no warnings or errors)
          logger.i('$tag Test log INFO message');
        });

        // Verify no logs above info level were emitted
        await expectNoLogsFrom(
          testIdentifier,
          Level.warning,
          logOutput,
          () async {
            // Nothing to do, we're checking existing logs
          },
        );
      });
    });
  });
}
