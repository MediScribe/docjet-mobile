import '../test_utils.d.dart';

/// Demonstrates how to use the test_utils.dart barrel file
///
/// - Imports all common test utilities (flutter_test.dart, TestLogger, etc.)
/// - Includes convenience setup and teardown methods
/// - Shows how to control log visibility for specific tests
void main() {
  // Set up logging for the entire file (error level by default)
  setUpAll(setupTestLogging);
  tearDownAll(teardownTestLogging);

  test('default behavior - only error logs visible', () {
    // By default, only error logs are shown
    debugPrint('This debug print should be hidden');
    logger.d('[DEBUG] This debug log should be hidden');
    logger.i('[INFO] This info log should be hidden');
    logger.w('[WARN] This warning log should be visible');
    logger.e('[ERROR] This error log should be visible');

    expect(true, isTrue); // Just a dummy assertion
  });

  test('can enable debug logs for a specific test', () {
    // Enable debug logs just for this test
    TestLogger.setLogLevel(LogLevel.debug);

    debugPrint('This debug print should be visible now');
    logger.d('[DEBUG] This debug log should be visible now');
    logger.i('[INFO] This info log should be visible now');

    expect(true, isTrue);

    // Reset to error level for other tests
    TestLogger.setLogLevel(LogLevel.error);
  });

  test('can use withLogging helper', () {
    // This log is at error level (outside the withLogging block)
    logger.d('[DEBUG] This debug log should be hidden');

    // Use the helper to temporarily enable all logs
    withLogging(LogLevel.all, () {
      logger.d('[DEBUG] This debug log inside withLogging should be visible');
      logger.i('[INFO] This info log inside withLogging should be visible');

      expect(true, isTrue);
    });

    // Back to error level
    logger.d('[DEBUG] This debug log should be hidden again');
  });

  test('can focus on specific component logs', () {
    // Enable only AUDIO logs
    TestLogger.enableLoggingForTag('AUDIO');

    // These logs should be hidden
    logger.d('[DEBUG] This general debug log should be hidden');
    logger.i('[NETWORK] This network log should be hidden');

    // These logs should be visible
    logger.d('[AUDIO] This audio debug log should be visible');
    logger.i('[AUDIO] This audio info log should be visible');

    expect(true, isTrue);

    // Reset to error level
    TestLogger.setLogLevel(LogLevel.error);
  });
}
