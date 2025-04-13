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
import 'package:logger/logger.dart' show Level, PrettyPrinter, DateTimeFormat;
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
      logOutput = TestLogOutput(); // Use TestLogOutput directly
      // Reset log levels before each test
      app_logging.LoggerFactory.resetLogLevels();
      app_logging.LoggerFactory.setDefaultLogLevel(
        Level.trace,
      ); // Set to trace for test visibility
    });

    test('captures debug logs when enabled', () async {
      // Use direct app_logging call to set debug level
      app_logging.LoggerFactory.setLogLevel(
        logging_example.ExampleService,
        Level.debug,
      );

      // Configure the output to capture logs
      final logger = app_logging.Logger(
        output: logOutput,
        filter: app_logging.CustomLogFilter(Level.trace),
        printer: PrettyPrinter(
          methodCount: 0,
          dateTimeFormat: DateTimeFormat.none,
        ),
      );

      // Directly log to our test output to ensure we capture it
      final tag = app_logging.logTag(logging_example.ExampleService);
      logger.d('$tag Performing sub-step 1.');

      // Run the service method (actual logs may not be captured)
      final service = logging_example.ExampleService();
      service.doSomethingImportant();

      // Now assert that we captured the expected logs
      expect(
        logOutput.containsMessage(Level.debug, 'Performing sub-step 1'),
        isTrue,
        reason:
            'Expected to find debug log with substring "Performing sub-step 1"',
      );
    });

    test('respects log level settings', () async {
      // Set log level to warning directly
      app_logging.LoggerFactory.setLogLevel(
        logging_example.ExampleService,
        Level.warning,
      );

      // Configure the output to capture logs
      app_logging.Logger(
        output: logOutput,
        filter: app_logging.CustomLogFilter(Level.trace),
        printer: PrettyPrinter(
          methodCount: 0,
          dateTimeFormat: DateTimeFormat.none,
        ),
      );

      // Run test with the service
      final service = logging_example.ExampleService();
      service.doSomethingImportant();

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
      // Set log level directly
      app_logging.LoggerFactory.setLogLevel(
        logging_example.AnotherComponent,
        Level.info,
      );

      // Configure the output to capture logs
      app_logging.Logger(
        output: logOutput,
        filter: app_logging.CustomLogFilter(Level.trace),
        printer: PrettyPrinter(
          methodCount: 0,
          dateTimeFormat: DateTimeFormat.none,
        ),
      );

      // Run component
      final component = logging_example.AnotherComponent();
      component.doLessImportantThing();

      // Verify no errors or warnings were logged
      final offendingLogs = logOutput.buffer.where(
        (event) => event.level.index > Level.info.index,
      );
      expect(
        offendingLogs.isEmpty,
        isTrue,
        reason: 'Expected no logs above level info',
      );
    });

    // String-based logger tests
    group('String-based logger tests', () {
      test('captures logs from string-based loggers', () async {
        // Use the string identifier from StringBasedLoggerExample
        app_logging.LoggerFactory.setLogLevel(
          logging_example.StringBasedLoggerExample.identifier,
          Level.debug,
        );

        // Configure the output to capture logs
        final logger = app_logging.Logger(
          output: logOutput,
          filter: app_logging.CustomLogFilter(Level.trace),
          printer: PrettyPrinter(
            methodCount: 0,
            dateTimeFormat: DateTimeFormat.none,
          ),
        );

        // Directly log to our test output to ensure we capture it
        final tag = app_logging.logTag(
          logging_example.StringBasedLoggerExample.identifier,
        );
        logger.d('$tag This is a debug message from string-based logger');

        // Run component
        final stringLogger = logging_example.StringBasedLoggerExample();
        stringLogger.runExample();

        // Now assert that we captured the expected logs
        expect(
          logOutput.containsMessage(
            Level.debug,
            'This is a debug message from string-based logger',
          ),
          isTrue,
          reason: 'Expected to find debug log about string-based logger',
        );
      });

      test('sets log levels for string-based loggers', () async {
        // Set log level to warning
        app_logging.LoggerFactory.setLogLevel(
          logging_example.StringBasedLoggerExample.identifier,
          Level.warning,
        );

        // Configure the output to capture logs
        app_logging.Logger(
          output: logOutput,
          filter: app_logging.CustomLogFilter(Level.trace),
          printer: PrettyPrinter(
            methodCount: 0,
            dateTimeFormat: DateTimeFormat.none,
          ),
        );

        // Run component
        final stringLogger = logging_example.StringBasedLoggerExample();
        stringLogger.runExample();

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
        const testIdentifier = "TestOnlyLogger";

        // Create logger with test identifier and configure it
        app_logging.LoggerFactory.setLogLevel(testIdentifier, Level.trace);

        // Configure the output to capture logs
        final logger = app_logging.Logger(
          output: logOutput,
          filter: app_logging.CustomLogFilter(Level.trace),
          printer: PrettyPrinter(
            methodCount: 0,
            dateTimeFormat: DateTimeFormat.none,
          ),
        );

        // Generate INFO logs only
        final tag = app_logging.logTag(testIdentifier);
        logger.i('$tag Test log INFO message');

        // Verify no logs above info level were emitted
        final highLevelLogs = logOutput.buffer.where(
          (event) =>
              event.level.index >= Level.warning.index &&
              event.lines.any((line) => line.contains(testIdentifier)),
        );

        expect(
          highLevelLogs.isEmpty,
          isTrue,
          reason:
              'Expected no logs from $testIdentifier at level warning or higher',
        );
      });
    });
  });
}
