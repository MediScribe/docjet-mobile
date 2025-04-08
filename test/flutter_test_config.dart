import 'dart:async';
import 'package:docjet_mobile/core/utils/test_logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Global test configuration that runs before any test file.
///
/// This file is automatically loaded by Flutter's test framework.
/// By default, ALL logs are suppressed unless enabled via environment variables
/// or explicit TestLogger method calls in individual test files.
///
/// Usage:
/// ```
/// # Run all tests with only error logs visible
/// TEST_LOG_LEVEL=error flutter test
///
/// # Run all tests with logs for specific tags
/// TEST_LOG_TAGS=AUDIO,NETWORK flutter test
///
/// # Run all tests with all logs enabled
/// TEST_LOG_LEVEL=all flutter test
///
/// # Run all tests with no logs (default behavior)
/// flutter test
/// ```
///
/// In individual test files, you can override this behavior with:
///
/// ```dart
/// setUpAll(() => TestLogger.setupTestFile(LogLevel.debug));
/// tearDownAll(TestLogger.tearDownTestFile);
/// ```
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // First disable all logging to start with a clean state
  TestLogger.disableLogging();

  // Then initialize logging from environment variables
  // This handles TEST_LOG_LEVEL and TEST_LOG_TAGS
  TestLogger.initFromEnvironment();

  // Run the tests
  await testMain();

  // Reset logging at the end
  TestLogger.resetLogging();
}
