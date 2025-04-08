# Test Utilities

This directory contains utility functions and classes to help with testing.

## TestLogger

The `TestLogger` utility allows you to control logging output during tests, which is especially helpful for:

1. Reducing noise in test output
2. Focusing on specific components when debugging

### Environment Variables (Recommended)

The simplest way to control logging in tests is through environment variables - no code changes needed!

```bash
# Run tests with only ERROR logs
TEST_LOG_LEVEL=error flutter test

# Run tests with all logs for specific tags
TEST_LOG_TAGS=AUDIO,NETWORK flutter test

# Run tests with all logs enabled
TEST_LOG_LEVEL=all flutter test

# Run tests with no logs (default)
flutter test
```

Available log levels:
- `none`: No logs (default)
- `error`: Only error logs
- `warn`: Warnings and errors
- `info`: Info, warnings, and errors
- `debug`: Debug and above
- `all`: All logs

### Per-Test File Setup (Recommended)

For controlling log levels in specific test files, use the convenience methods:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/utils/test_logger.dart';

void main() {
  // Setup logging for the entire test file
  setUpAll(TestLogger.setupTestFile);  // Default: error level
  // OR with custom level:
  // setUpAll(() => TestLogger.setupTestFile(LogLevel.debug));
  
  // Clean up logging after all tests
  tearDownAll(TestLogger.tearDownTestFile);
  
  // Your tests...
  test('first test', () {
    // Runs with the log level set above
  });
}
```

### Per-Test Control

For fine-grained control in specific tests:

```dart
import 'package:docjet_mobile/core/utils/test_logger.dart';

test('test that needs debug logs', () {
  // Save current level
  final prevLevel = TestLogger.logLevel;
  
  // Change for this test
  TestLogger.setLogLevel(LogLevel.debug);
  
  // Your test code...
  
  // Restore previous level
  TestLogger.setLogLevel(prevLevel);
});
```

### Available Methods

- `TestLogger.setupTestFile([LogLevel level])` - Setup logging for a test file (for use with setUpAll)
- `TestLogger.tearDownTestFile()` - Clean up logging after tests (for use with tearDownAll)
- `TestLogger.disableLogging()` - Disable all logging
- `TestLogger.setLogLevel(LogLevel)` - Set log level (error, warn, info, debug, all)
- `TestLogger.enableLoggingForTag(String)` - Enable logging for specific tag (with or without brackets)
- `TestLogger.enableLoggingForTags(List<String>)` - Enable multiple tags
- `TestLogger.enableAllLogging()` - Enable all logging
- `TestLogger.resetLogging()` - Reset to default

### Log Format

For best results, format your logs with consistent tags and levels:

```dart
// Error logs
logger.e('[ERROR][AUDIO] Failed to load file: $fileName');

// Warning logs
logger.w('[WARN][NETWORK] Retry attempt #3');

// Info logs
logger.i('[INFO][DB] Connected to database');

// Debug logs
logger.d('[DEBUG][AUTH] User session refreshed');

// Tagged by component
logger.d('[AUDIO] Processing file: $fileName');
debugPrint('[NETWORK] Request started');
```

### Tag Filtering Details

When you filter by tags, the TestLogger will match any log message containing your tag. It automatically handles both bracketed and unbracketed formats:

```dart
// Both versions will show logs containing either "[AUDIO]" or "AUDIO"
TestLogger.enableLoggingForTag('[AUDIO]'); 
TestLogger.enableLoggingForTag('AUDIO');
```

Note that tag filtering takes precedence over log level filtering when both are specified.

### Example Test

See `test/example/test_logger_example_test.dart` for a complete working example. 