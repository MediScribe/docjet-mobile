/// LOG HELPERS UNIT TESTS
///
/// These tests verify the functionality of the
/// logging system implementation.
///
/// Note: For reusable test helpers, see:
/// test/helpers/log_test_helpers.dart

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
// NOTE: TestLogOutput moved to test/helpers/log_test_helpers.dart

// Mock class for testing
class TestClass {}

class AnotherTestClass {}

// Memory output to capture logs during tests
class TestLogOutput extends LogOutput {
  final List<OutputEvent> buffer = [];

  @override
  void output(OutputEvent event) {
    buffer.add(event);
  }

  void clear() {
    buffer.clear();
  }

  bool containsMessage(Level level, String messageSubstring) {
    return buffer.any(
      (event) =>
          event.level == level &&
          event.lines.any((line) => line.contains(messageSubstring)),
    );
  }

  bool isEmpty() => buffer.isEmpty;
}

// Helper to create a logger with a test output
Logger _createTestLogger(Type type, TestLogOutput output, {Level? level}) {
  final effectiveLevel = level ?? LoggerFactory.getCurrentLevel(type);

  return Logger(
    output: output,
    filter: CustomLogFilter(effectiveLevel),
    // Use a simple printer for tests to make assertion easier
    printer: SimplePrinter(printTime: false, colors: false),
  );
}

void main() {
  late TestLogOutput testOutput;

  setUp(() {
    // Reset log levels before each test
    LoggerFactory.resetLogLevels();
    // Reset default levels to known state (assuming default behavior)
    // Set default to trace (previously verbose) for testing most levels
    LoggerFactory.setDefaultLogLevel(Level.trace);
    testOutput = TestLogOutput();
  });

  tearDown(() {
    testOutput.clear();
  });

  group('Log Helpers', () {
    test('logTag generates correct tag', () {
      expect(logTag(TestClass), 'TestClass');
      expect(logTag(AnotherTestClass), 'AnotherTestClass');
    });

    test('LoggerFactory returns a logger', () {
      // Can't easily test the default logger's output without more setup
      // So we just check if it returns a Logger instance.
      final logger = LoggerFactory.getLogger(TestClass);
      expect(logger, isA<Logger>());
    });

    test('Logger respects default level (trace)', () {
      final logger = _createTestLogger(TestClass, testOutput);
      logger.t('Trace message'); // Should log with default trace
      logger.d('Debug message'); // Should log
      logger.i('Info message'); // Should log
      logger.w('Warning message'); // Should log
      logger.e('Error message'); // Should log
      logger.f('Fatal message'); // Should log

      expect(testOutput.buffer.length, 6);
      expect(testOutput.containsMessage(Level.trace, 'Trace message'), isTrue);
      expect(testOutput.containsMessage(Level.debug, 'Debug message'), isTrue);
      expect(testOutput.containsMessage(Level.info, 'Info message'), isTrue);
      expect(
        testOutput.containsMessage(Level.warning, 'Warning message'),
        isTrue,
      );
      expect(testOutput.containsMessage(Level.error, 'Error message'), isTrue);
      expect(testOutput.containsMessage(Level.fatal, 'Fatal message'), isTrue);
    });

    test(
      'LoggerFactory allows setting specific level (warning) for a class',
      () {
        LoggerFactory.setLogLevel(TestClass, Level.warning);
        final logger = _createTestLogger(TestClass, testOutput);

        logger.i('Info message'); // Should NOT log
        logger.w('Warning message'); // Should log
        logger.e('Error message'); // Should log

        expect(testOutput.buffer.length, 2);
        expect(testOutput.containsMessage(Level.info, 'Info message'), isFalse);
        expect(
          testOutput.containsMessage(Level.warning, 'Warning message'),
          isTrue,
        );
        expect(
          testOutput.containsMessage(Level.error, 'Error message'),
          isTrue,
        );

        // Other classes should still use the default (trace)
        final otherLogger = _createTestLogger(AnotherTestClass, testOutput);
        otherLogger.d('Other debug'); // Should log
        expect(testOutput.containsMessage(Level.debug, 'Other debug'), isTrue);
      },
    );

    test('LoggerFactory.getLogger level override works', () {
      // Default is trace
      final logger = _createTestLogger(
        TestClass,
        testOutput,
        level: Level.error,
      );

      logger.w('Warning message'); // Should NOT log
      logger.e('Error message'); // Should log
      logger.f('Fatal message'); // Should log

      expect(testOutput.buffer.length, 2);
      expect(
        testOutput.containsMessage(Level.warning, 'Warning message'),
        isFalse,
      );
      expect(testOutput.containsMessage(Level.error, 'Error message'), isTrue);
      expect(testOutput.containsMessage(Level.fatal, 'Fatal message'), isTrue);

      // Default level for the class should remain unchanged (trace)
      testOutput.clear();
      final defaultLogger = _createTestLogger(TestClass, testOutput);
      defaultLogger.d('Debug message'); // Should log
      expect(testOutput.containsMessage(Level.debug, 'Debug message'), isTrue);
    });

    test('LoggerFactory resets specific log levels', () {
      LoggerFactory.setLogLevel(TestClass, Level.error);
      LoggerFactory.setLogLevel(AnotherTestClass, Level.warning);

      LoggerFactory.resetLogLevels(); // Resets to default (trace in setUp)

      final logger1 = _createTestLogger(TestClass, testOutput);
      final logger2 = _createTestLogger(AnotherTestClass, testOutput);

      logger1.i('Info 1'); // Should log (trace)
      logger2.d('Debug 2'); // Should log (trace)

      expect(testOutput.containsMessage(Level.info, 'Info 1'), isTrue);
      expect(testOutput.containsMessage(Level.debug, 'Debug 2'), isTrue);
    });

    test('LoggerFactory allows changing default level (info)', () {
      LoggerFactory.setDefaultLogLevel(Level.info); // Change from trace
      final logger = _createTestLogger(TestClass, testOutput);

      logger.d('Debug message'); // Should NOT log
      logger.i('Info message'); // Should log

      expect(testOutput.buffer.length, 1);
      expect(testOutput.containsMessage(Level.debug, 'Debug message'), isFalse);
      expect(testOutput.containsMessage(Level.info, 'Info message'), isTrue);
    });

    test('LoggerFactory.getCurrentLevel reflects current level', () {
      expect(
        LoggerFactory.getCurrentLevel(TestClass),
        Level.trace, // Default from setUp
      );
      LoggerFactory.setLogLevel(TestClass, Level.error);
      expect(LoggerFactory.getCurrentLevel(TestClass), Level.error);
      LoggerFactory.resetLogLevels();
      expect(
        LoggerFactory.getCurrentLevel(TestClass),
        Level.trace, // Back to default
      );
      LoggerFactory.setDefaultLogLevel(Level.debug);
      expect(LoggerFactory.getCurrentLevel(TestClass), Level.debug);
    });

    test('CustomLogFilter handles Level.off correctly', () {
      LoggerFactory.setLogLevel(TestClass, Level.off);
      final logger = _createTestLogger(TestClass, testOutput);

      logger.f('Fatal message');
      logger.e('Error message');
      logger.w('Warning message');
      logger.i('Info message');
      logger.d('Debug message');
      logger.t('Trace message');

      expect(testOutput.isEmpty(), isTrue);
    });

    // Test the placeholder formatPlaybackState - replace when real state is available
    test('formatPlaybackState formats placeholder states', () {
      expect(formatPlaybackState(PlaybackStatePlaceholder.initial), 'initial');
      expect(formatPlaybackState(PlaybackStatePlaceholder.loading), 'loading');
      expect(formatPlaybackState(PlaybackStatePlaceholder.playing), 'playing');
      expect(formatPlaybackState(PlaybackStatePlaceholder.paused), 'paused');
      expect(formatPlaybackState(PlaybackStatePlaceholder.stopped), 'stopped');
      expect(
        formatPlaybackState(PlaybackStatePlaceholder.completed),
        'completed',
      );
      expect(formatPlaybackState(PlaybackStatePlaceholder.error), 'error');
    });
  });
}
