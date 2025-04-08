/// Central utilities for testing
///
/// Import this file in your test files to get access to all common testing utilities.
///
/// ```dart
/// import '../test_utils.dart';
///
/// void main() {
///   setUpAll(setupTestLogging);
///   tearDownAll(teardownTestLogging);
///
///   // Your tests...
/// }
/// ```

// Import needed libraries first
import 'package:docjet_mobile/core/utils/test_logger.dart';

export 'package:docjet_mobile/core/utils/logger.dart';
export 'package:docjet_mobile/core/utils/test_logger.dart';
export 'package:flutter/foundation.dart';
// Then export them
export 'package:flutter_test/flutter_test.dart';

// Optional: Add other common test utilities/mocking frameworks you use
// export 'package:mocktail/mocktail.dart';
// export 'package:fake_async/fake_async.dart';

/// Convenience setup function for tests
void setupTestLogging([LogLevel level = LogLevel.error]) {
  TestLogger.setupTestFile(level);
}

/// Convenience teardown function for tests
void teardownTestLogging() {
  TestLogger.tearDownTestFile();
}

/// Enable logging for a specific set of tests
void withLogging(LogLevel level, void Function() testCode) {
  final prevLevel = TestLogger.logLevel;
  TestLogger.setLogLevel(level);
  testCode();
  TestLogger.setLogLevel(prevLevel);
}
