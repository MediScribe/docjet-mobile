import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/core/utils/test_logger.dart';

/// Example class that produces log output in production code
class AudioProcessor {
  bool processFile(String filename) {
    logger.d('[AUDIO] Starting to process file: $filename');

    try {
      // Simulate file processing
      if (filename.isEmpty) {
        logger.e('[ERROR][AUDIO] Empty filename provided');
        return false;
      }

      logger.i('[INFO][AUDIO] Successfully validated filename');

      // More processing...
      logger.d('[AUDIO] Applied effects to file');

      // Finalize processing
      logger.i('[INFO][AUDIO] Completed processing file: $filename');
      return true;
    } catch (e) {
      logger.e('[ERROR][AUDIO] Failed to process file: $e');
      return false;
    }
  }
}

/// Example test demonstrating TestLogger functionality
///
/// Usage with environment variables:
/// ```
/// # Run with only error logs:
/// TEST_LOG_LEVEL=error flutter test test/example/test_logger_example_test.dart
///
/// # Run with specific tag logs:
/// TEST_LOG_TAGS=AUDIO,NETWORK flutter test test/example/test_logger_example_test.dart
///
/// # Run with all logs:
/// TEST_LOG_LEVEL=all flutter test test/example/test_logger_example_test.dart
/// ```
void main() {
  // Using the new convenience methods for setting up the test file
  // This will be overridden by environment variables if they're set
  setUpAll(() => TestLogger.setupTestFile(LogLevel.error));
  tearDownAll(TestLogger.tearDownTestFile);

  group('TestLogger demonstration tests', () {
    // Helper to print test boundaries
    void printTestBoundary(String testName) {
      debugPrint(
        '\n----------------------------------------------------------',
      );
      debugPrint('TEST: $testName');
      debugPrint(
        '----------------------------------------------------------\n',
      );
    }

    test('Log filtering is disabled by default', () {
      printTestBoundary('Log filtering is disabled by default');

      // Make sure we're starting with clean state
      TestLogger.disableLogging();

      debugPrint('EXPECT: The following logs should be hidden:');

      // These logs should be suppressed by default
      debugPrint('This debug print should be hidden');
      logger.d('This logger.d call should be hidden');

      // Log with a tag - also hidden by default
      debugPrint('[TAG] Debug print with tag should also be hidden');
      logger.d('[TAG] Logger.d call with tag should also be hidden');

      // Error logs might be visible if TEST_LOG_LEVEL=error is set
      debugPrint(
        'EXPECT: This error log might be visible if TEST_LOG_LEVEL=error is set:',
      );
      logger.e(
        '[ERROR] This error log might be visible depending on TEST_LOG_LEVEL',
      );

      // Simple assertion to make test pass
      expect(true, isTrue);
    });

    test('Can enable logs with specific tag', () {
      printTestBoundary('Can enable logs with specific tag');

      // Enable logging for a specific tag
      TestLogger.enableLoggingForTag('[TAG]');

      debugPrint('EXPECT: These logs should still be hidden:');

      // These logs should still be suppressed
      debugPrint('This debug print should still be hidden');
      logger.d('This logger.d call should still be hidden');

      debugPrint('EXPECT: These logs with [TAG] should be visible:');

      // These logs with the enabled tag should be visible
      debugPrint('[TAG] This debug print with TAG should be visible');
      logger.d('[TAG] This logger.d call with TAG should be visible');

      // Reset for next test
      TestLogger.disableLogging();

      expect(true, isTrue);
    });

    test('Different tags can be enabled', () {
      printTestBoundary('Different tags can be enabled');

      // Enable logging for a different tag
      TestLogger.enableLoggingForTag('[NETWORK]');

      debugPrint('EXPECT: These logs should be hidden:');

      // These logs should be suppressed
      debugPrint('[TAG] This debug print with TAG should be hidden now');
      logger.d('[TAG] This logger.d call with TAG should be hidden now');

      debugPrint('EXPECT: These logs with [NETWORK] should be visible:');

      // These logs with the enabled tag should be visible
      debugPrint(
        '[NETWORK] This debug print with NETWORK tag should be visible',
      );
      logger.d(
        '[NETWORK] This logger.d call with NETWORK tag should be visible',
      );

      // Reset for next test
      TestLogger.disableLogging();

      expect(true, isTrue);
    });

    test('Can enable multiple tags at once', () {
      printTestBoundary('Can enable multiple tags at once');

      // Enable multiple tags
      TestLogger.enableLoggingForTags(['[TAG]', '[NETWORK]', '[AUDIO]']);

      debugPrint('EXPECT: These logs should all be visible:');

      // These logs should all be visible
      debugPrint('[TAG] This debug print with TAG should be visible');
      logger.d('[NETWORK] This logger.d call with NETWORK should be visible');
      debugPrint('[AUDIO] This debug print with AUDIO should be visible');

      debugPrint('EXPECT: Logs without enabled tags should still be hidden:');

      // Logs without enabled tags still suppressed
      debugPrint('This debug print without tag should still be hidden');
      logger.d('This logger.d call without tag should still be hidden');

      // Reset for next test
      TestLogger.disableLogging();

      expect(true, isTrue);
    });

    test('Can enable all logging', () {
      printTestBoundary('Can enable all logging');

      // Enable ALL logging
      TestLogger.enableAllLogging();

      debugPrint('EXPECT: Everything should be visible now:');

      // Everything should be visible now
      debugPrint('This debug print without any tag should be visible');
      logger.d('This logger.d call without any tag should be visible');
      debugPrint('[TAG] This debug print with TAG should be visible');
      logger.d('[NETWORK] This logger.d call with NETWORK should be visible');

      // Reset for next test
      TestLogger.disableLogging();

      expect(true, isTrue);
    });

    test('Can set specific log level', () {
      printTestBoundary('Can set specific log level');

      // Set log level to show only errors and warnings
      TestLogger.setLogLevel(LogLevel.warn);

      debugPrint('EXPECT: These should be visible:');

      // These should be visible
      logger.e('[ERROR] This error log should be visible');
      logger.w('[WARN] This warning log should be visible');

      debugPrint('EXPECT: These should be hidden:');

      // These should be hidden
      logger.i('[INFO] This info log should be hidden');
      logger.d('[DEBUG] This debug log should be hidden');
      debugPrint('This debug print should be hidden');

      // Reset for next test
      TestLogger.disableLogging();

      expect(true, isTrue);
    });
  });

  group('Testing real code with logging', () {
    late AudioProcessor audioProcessor;

    setUp(() {
      audioProcessor = AudioProcessor();
    });

    test('processFile successful case with all logs hidden', () {
      // This is the default in setUpAll, but making it explicit for the example
      TestLogger.setLogLevel(LogLevel.error);

      // Verify functionality works
      final result = audioProcessor.processFile('test_file.mp3');

      // You can focus on assertions without log noise
      expect(result, isTrue);

      // Note: no debug or info logs will be visible here,
      // even though the method is generating them
    });

    test('processFile with errors showing only error logs', () {
      // Show only error logs
      TestLogger.setLogLevel(LogLevel.error);

      // Test error case
      final result = audioProcessor.processFile('');
      expect(result, isFalse);

      // Note: Only the ERROR log will be visible:
      // [ERROR][AUDIO] Empty filename provided
    });

    test('processFile with full debugging enabled', () {
      // When debugging a specific test, enable all logs
      TestLogger.setLogLevel(LogLevel.all);

      // Now you'll see ALL log output for detailed debugging
      final result = audioProcessor.processFile('debug_file.mp3');
      expect(result, isTrue);

      // All logs will be visible for debugging
    });

    test('processFile focusing on AUDIO logs only', () {
      // Focus on just the component being tested
      TestLogger.enableLoggingForTag('AUDIO');

      // Now you'll see only AUDIO-tagged logs
      final result = audioProcessor.processFile('component_test.mp3');
      expect(result, isTrue);

      // Only [AUDIO] logs will be visible, perfect for component focus
    });
  });
}
