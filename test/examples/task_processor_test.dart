import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../examples/task_processor.dart';

// TEST-SPECIFIC LOGGER: Completely separate from the SUT
final testLogger = LoggerFactory.getLogger('TestLogger');
final testTag = logTag('TestLogger');

void main() {
  group('TaskProcessor', () {
    late TaskProcessor processor;

    setUp(() {
      // Clear logs before each test
      LoggerFactory.clearLogs();

      // Set log levels
      LoggerFactory.setLogLevel(
        'TestLogger',
        Level.info,
      ); // Test logger at INFO
      LoggerFactory.setLogLevel(
        TaskProcessor,
        Level.trace,
      ); // SUT logger overridden to TRACE

      // Log from the test
      testLogger.i('$testTag Setting up test');

      // Create processor
      processor = TaskProcessor();

      testLogger.d('$testTag This debug message should be filtered out');
    });

    test('test and component loggers are independent', () {
      // Log from the test at different levels
      testLogger.d('$testTag Debug from test - should be filtered out');
      testLogger.i('$testTag Info from test - should be visible');

      // Run the processor to generate component logs
      processor.process('valid task');

      // Check test logs
      expect(
        LoggerFactory.containsLog('Info from test', forType: 'TestLogger'),
        isTrue,
        reason: 'Test INFO logs should be visible',
      );

      expect(
        LoggerFactory.containsLog('Debug from test', forType: 'TestLogger'),
        isFalse,
        reason: 'Test DEBUG logs should be filtered out at INFO level',
      );

      // Check component logs - should all be visible at TRACE level
      expect(
        LoggerFactory.containsLog(
          'Starting to process task',
          forType: TaskProcessor,
        ),
        isTrue,
        reason: 'Component DEBUG logs should be visible at TRACE level',
      );

      // Add a check for a TRACE level message if one existed in the SUT
      // Example (assuming TaskProcessor had a _logger.t() call):
      // expect(
      //   LoggerFactory.containsLog(
      //     'Trace message from SUT', // This is a TRACE level message
      //     forType: TaskProcessor,
      //   ),
      //   isTrue,
      //   reason: 'Component TRACE logs should be visible at TRACE level',
      // );

      // Change levels mid-test
      LoggerFactory.setLogLevel(
        'TestLogger',
        Level.debug,
      ); // Lower test logger to DEBUG
      LoggerFactory.setLogLevel(
        TaskProcessor,
        Level.warning,
      ); // Raise component logger to WARNING

      // Clear logs to start fresh
      LoggerFactory.clearLogs();

      // Log again with new levels
      testLogger.d('$testTag Debug from test - NOW should be visible');
      processor.process('valid task');

      // Verify test debug logs now visible
      expect(
        LoggerFactory.containsLog('Debug from test - NOW should be visible'),
        isTrue,
        reason: 'Test DEBUG logs should now be visible after changing level',
      );

      // Verify component debug logs now filtered
      expect(
        LoggerFactory.containsLog('Starting to process task'),
        isFalse,
        reason: 'Component DEBUG logs should now be filtered at WARNING level',
      );
    });

    test('successfully processes valid task', () {
      // Log from test
      testLogger.i('$testTag Running success test');

      // Run processor
      final result = processor.process('valid task');

      // Verify result
      expect(result, isTrue);

      // Verify logs
      expect(
        LoggerFactory.containsLog('Successfully processed task: valid task'),
        isTrue,
      );
    });

    test('logs error when processing fails', () {
      // Run processor with invalid task
      final result = processor.process('invalid task');

      // Verify result
      expect(result, isFalse);

      // Verify error log
      expect(
        LoggerFactory.containsLog('Failed to process task: invalid task'),
        isTrue,
      );
    });

    test('logs warning for empty task', () {
      // Run processor with empty task
      final result = processor.process('');

      // Verify result
      expect(result, isFalse);

      // Verify warning log
      expect(LoggerFactory.containsLog('Cannot process empty task'), isTrue);
    });

    test('respects log level settings', () {
      // Set log level to WARNING - should hide TRACE, DEBUG and INFO logs
      LoggerFactory.setLogLevel(TaskProcessor, Level.warning);

      // Process a valid task
      processor.process('valid task');

      // Debug log should be filtered out
      expect(LoggerFactory.containsLog('Starting to process task'), isFalse);

      // Info log should be filtered out
      expect(LoggerFactory.containsLog('Successfully processed task'), isFalse);

      // But if we process an invalid task, error should still show
      processor.process('invalid task');
      expect(LoggerFactory.containsLog('Failed to process task'), isTrue);
    });
  });
}
