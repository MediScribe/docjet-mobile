# Test Utilities

This directory contains utility functions and classes to help with testing.

## TestLogger

The `TestLogger` utility allows you to control logging output during tests, which is especially helpful for:

1. Reducing noise in test output
2. Focusing on specific components when debugging

### Basic Usage

Add these lines to your test file:

```dart
import 'package:docjet_mobile/core/utils/test_logger.dart';
// OR use the helper which also re-exports TestLogger
import '../helpers/logging_helper.dart';

void main() {
  // Disable all logging for these tests
  setupLogging();
  
  // Your tests here...
  
  // Make sure to reset logging when all tests are done
  tearDownAll(() => tearDownLogging());
}
```

### Global Configuration

If you want to control logging for ALL test files, you can use the global test configuration in `test/flutter_test_config.dart`:

```dart
// This file already exists - just uncomment your preferred option
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // OPTION 1: Disable all logs (default)
  // TestLogger.disableLogging();
  
  // OPTION 2: Enable ALL logging
  // TestLogger.enableAllLogging();
  
  // OPTION 3: Enable specific tags
  // TestLogger.enableLoggingForTags(['[AUDIO]', '[NETWORK]']);
  
  await testMain();
}
```

When using the global configuration, you don't need to add the `setupLogging()` and `tearDownLogging()` calls to individual test files.

### Debugging Specific Components

When you need to debug a specific test or component, you can enable logging for specific tags:

```dart
test('test that needs debugging', () {
  // Enable logging for audio-related components only
  TestLogger.enableLoggingForTag('[AUDIO]');
  
  // Your test code...
  
  // Optional: Reset logging back to disabled for remaining tests
  TestLogger.disableLogging();
});
```

### Multiple Tags and All Logging

You can enable multiple tags at once or all logging:

```dart
// Enable multiple tags
TestLogger.enableLoggingForTags(['[AUDIO]', '[NETWORK]', '[DB]']);

// Enable ALL logging
TestLogger.enableAllLogging();
```

### Available Methods

- `TestLogger.disableLogging()` - Disable all logging
- `TestLogger.enableLoggingForTag(String tag)` - Enable logging for messages that start with the specified tag
- `TestLogger.enableLoggingForTags(List<String> tags)` - Enable logging for multiple tags at once
- `TestLogger.enableAllLogging()` - Enable all logging, regardless of tags
- `TestLogger.resetLogging()` - Reset to default (all logging enabled)

### Helper Functions

For convenience, we also provide:

- `setupLogging()` - Initializes the Flutter test environment and disables logging
- `tearDownLogging()` - Resets logging to default state

### Example Test

See `test/example/test_logger_example_test.dart` for a complete working example.

### Tips for Effective Logging

1. Use consistent tags at the beginning of your log messages:
   ```dart
   logger.d('[AUDIO] Processing file: $filename');
   debugPrint('[AUDIO] Current state: $state');
   ```

2. In test setup, disable all logging:
   ```dart
   setupLogging();
   ```

3. When debugging a specific test, enable only what you need:
   ```dart
   // Inside the specific test you want to debug
   TestLogger.enableLoggingForTag('[AUDIO]');
   ```

4. Remember to reset after your tests:
   ```dart
   tearDownAll(() => tearDownLogging());
   ``` 