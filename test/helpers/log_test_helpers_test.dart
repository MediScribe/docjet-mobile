/// LOG TEST HELPERS UNIT TESTS
///
/// These tests verify that the logging test utilities work correctly.
/// This is a "test the test code" approach to ensure our test helpers
/// are reliable.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import '../helpers/log_test_helpers.dart';

// Mock class for testing
class TestHelperClass {}

void main() {
  late TestLogOutput testOutput;

  setUp(() {
    // Reset log levels before each test
    resetLogLevels();
    // Set default to trace level for predictable test behavior
    LoggerFactory.setDefaultLogLevel(Level.trace);
    testOutput = captureLogOutput();
  });

  tearDown(() {
    testOutput.clear();
  });

  group('TestLogOutput', () {
    test('captures logs correctly', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false, colors: false),
      );

      logger.t('Trace message');
      logger.d('Debug message');
      logger.i('Info message');

      expect(testOutput.buffer.length, 3);
      expect(testOutput.containsMessage(Level.trace, 'Trace message'), isTrue);
      expect(testOutput.containsMessage(Level.debug, 'Debug message'), isTrue);
      expect(testOutput.containsMessage(Level.info, 'Info message'), isTrue);
      expect(testOutput.containsMessage(Level.error, 'Not logged'), isFalse);
    });

    test('clear() removes all captured logs', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false, colors: false),
      );

      logger.i('Test message');
      expect(testOutput.buffer.isNotEmpty, isTrue);

      testOutput.clear();
      expect(testOutput.buffer.isEmpty, isTrue);
    });
  });

  group('withDebugLogsFor', () {
    test('enables debug logs for Type during test execution', () async {
      // Set initial level to warning
      LoggerFactory.setLogLevel(TestHelperClass, Level.warning);
      final initialLevel = LoggerFactory.getCurrentLevel(TestHelperClass);
      expect(initialLevel, Level.warning);

      // Configure logger to use our test output
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace), // Low filter to capture all
        printer: SimplePrinter(printTime: false),
      );

      await withDebugLogsFor(TestHelperClass, () async {
        // Should be at debug level during test
        expect(LoggerFactory.getCurrentLevel(TestHelperClass), Level.debug);

        logger.d('${logTag(TestHelperClass)} Debug message during test');
        logger.i('${logTag(TestHelperClass)} Info message during test');
      });

      // Should be back to original level after test
      expect(LoggerFactory.getCurrentLevel(TestHelperClass), Level.warning);

      // Verify logs were captured
      expect(
        testOutput.containsMessage(Level.debug, 'Debug message during test'),
        isTrue,
      );
    });

    test(
      'enables debug logs for String identifier during test execution',
      () async {
        // Set initial level to warning
        LoggerFactory.setLogLevel("StringLogger", Level.warning);
        final initialLevel = LoggerFactory.getCurrentLevel("StringLogger");
        expect(initialLevel, Level.warning);

        // Configure logger to use our test output
        final logger = Logger(
          output: testOutput,
          filter: CustomLogFilter(Level.trace), // Low filter to capture all
          printer: SimplePrinter(printTime: false),
        );

        await withDebugLogsFor("StringLogger", () async {
          // Should be at debug level during test
          expect(LoggerFactory.getCurrentLevel("StringLogger"), Level.debug);

          logger.d('${logTag("StringLogger")} Debug message during test');
          logger.i('${logTag("StringLogger")} Info message during test');
        });

        // Should be back to original level after test
        expect(LoggerFactory.getCurrentLevel("StringLogger"), Level.warning);

        // Verify logs were captured
        expect(
          testOutput.containsMessage(Level.debug, 'Debug message during test'),
          isTrue,
        );
      },
    );
  });

  group('withLogLevelFor', () {
    test('sets specific log level for Type during test execution', () async {
      // Set initial level to trace
      LoggerFactory.setLogLevel(TestHelperClass, Level.trace);
      final initialLevel = LoggerFactory.getCurrentLevel(TestHelperClass);
      expect(initialLevel, Level.trace);

      // Configure logger to use our test output
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace), // Low filter to capture all
        printer: SimplePrinter(printTime: false),
      );

      await withLogLevelFor(TestHelperClass, Level.error, () async {
        // Should be at error level during test
        expect(LoggerFactory.getCurrentLevel(TestHelperClass), Level.error);

        logger.w('${logTag(TestHelperClass)} Warning message during test');
        logger.e('${logTag(TestHelperClass)} Error message during test');
      });

      // Should be back to original level after test
      expect(LoggerFactory.getCurrentLevel(TestHelperClass), Level.trace);

      // Verify only error was captured at ERROR level
      // (we're using a low filter in the logger so we see everything, but
      // in real use the filter would be at Level.error)
      expect(
        testOutput.containsMessage(
          Level.warning,
          'Warning message during test',
        ),
        isTrue,
      );
      expect(
        testOutput.containsMessage(Level.error, 'Error message during test'),
        isTrue,
      );
    });

    test(
      'sets specific log level for String identifier during test execution',
      () async {
        // Set initial level to trace
        LoggerFactory.setLogLevel("StringLogger", Level.trace);
        final initialLevel = LoggerFactory.getCurrentLevel("StringLogger");
        expect(initialLevel, Level.trace);

        // Configure logger to use our test output
        final logger = Logger(
          output: testOutput,
          filter: CustomLogFilter(Level.trace), // Low filter to capture all
          printer: SimplePrinter(printTime: false),
        );

        await withLogLevelFor("StringLogger", Level.error, () async {
          // Should be at error level during test
          expect(LoggerFactory.getCurrentLevel("StringLogger"), Level.error);

          logger.w('${logTag("StringLogger")} Warning message during test');
          logger.e('${logTag("StringLogger")} Error message during test');
        });

        // Should be back to original level after test
        expect(LoggerFactory.getCurrentLevel("StringLogger"), Level.trace);
      },
    );
  });

  group('expectNoLogsFrom', () {
    test('passes when no high-level logs from Type occur', () async {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      // Should not throw
      await expectNoLogsFrom(
        TestHelperClass,
        Level.warning,
        testOutput,
        () async {
          logger.i('${logTag(TestHelperClass)} Info message');
          logger.d('${logTag(TestHelperClass)} Debug message');
        },
      );
    });

    test('throws when high-level logs from Type occur', () async {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      // Should throw
      expect(() async {
        await expectNoLogsFrom(
          TestHelperClass,
          Level.warning,
          testOutput,
          () async {
            logger.w('${logTag(TestHelperClass)} Warning message');
          },
        );
      }, throwsA(isA<TestFailure>()));
    });

    test(
      'passes when no high-level logs from String identifier occur',
      () async {
        final logger = Logger(
          output: testOutput,
          filter: CustomLogFilter(Level.trace),
          printer: SimplePrinter(printTime: false),
        );

        // Should not throw
        await expectNoLogsFrom(
          "StringLogger",
          Level.warning,
          testOutput,
          () async {
            logger.i('${logTag("StringLogger")} Info message');
            logger.d('${logTag("StringLogger")} Debug message');
          },
        );
      },
    );

    test('throws when high-level logs from String identifier occur', () async {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      // Should throw
      expect(() async {
        await expectNoLogsFrom(
          "StringLogger",
          Level.warning,
          testOutput,
          () async {
            logger.w('${logTag("StringLogger")} Warning message');
          },
        );
      }, throwsA(isA<TestFailure>()));
    });
  });

  group('expectLogContains', () {
    test('passes when log contains expected message at specified level', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      logger.i('Expected test message');

      // Should not throw
      expectLogContains(testOutput, Level.info, 'Expected test message');
    });

    test('fails when log does not contain expected message', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      logger.i('Actual message');

      // Should throw
      expect(() {
        expectLogContains(testOutput, Level.info, 'Expected but not present');
      }, throwsA(isA<TestFailure>()));
    });

    test('fails when message is at different level', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      logger.i('Test message');

      // Should throw - message exists but at info level, not warning
      expect(() {
        expectLogContains(testOutput, Level.warning, 'Test message');
      }, throwsA(isA<TestFailure>()));
    });
  });

  group('expectNoLogsAboveLevel', () {
    test('passes when no logs above specified level exist', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      logger.d('Debug message');
      logger.i('Info message');

      // Should not throw
      expectNoLogsAboveLevel(testOutput, Level.info);
    });

    test('fails when logs above specified level exist', () {
      final logger = Logger(
        output: testOutput,
        filter: CustomLogFilter(Level.trace),
        printer: SimplePrinter(printTime: false),
      );

      logger.i('Info message');
      logger.w('Warning message');
      logger.e('Error message');

      // Should throw - we have warning and error logs above info
      expect(() {
        expectNoLogsAboveLevel(testOutput, Level.info);
      }, throwsA(isA<TestFailure>()));
    });
  });

  group('resetLogLevels', () {
    test('resets all log levels to default', () {
      // Set custom levels
      LoggerFactory.setLogLevel(TestHelperClass, Level.error);
      LoggerFactory.setLogLevel("StringLogger", Level.warning);

      expect(LoggerFactory.getCurrentLevel(TestHelperClass), Level.error);
      expect(LoggerFactory.getCurrentLevel("StringLogger"), Level.warning);

      // Reset levels
      resetLogLevels();

      // Should be back to default (trace from setUp)
      expect(LoggerFactory.getCurrentLevel(TestHelperClass), Level.trace);
      expect(LoggerFactory.getCurrentLevel("StringLogger"), Level.trace);
    });
  });
}
