# Step 1: Clean Up Logging

## Overview

This step focuses on standardizing logging without changing any functional behavior. It's an ideal first step as it improves code readability with minimal risk.

**Estimated time:** 7-10 days

**Key Files & Roles Clarification:**

*   **`lib/core/utils/log_helpers.dart`**: Contains the **new `LoggerFactory`** system. This is the target implementation.
*   **`lib/core/utils/logger.dart`**: The **old logger** implementation (often just re-exporting). This will be removed after refactoring.
*   **`test/core/utils/log_helpers_test.dart`**: Contains **unit tests** specifically for `lib/core/utils/log_helpers.dart`.
*   **`test/helpers/log_test_helpers.dart`**: Contains **test utilities** (e.g., `TestLogOutput`, `withDebugLogsFor`) to help verify logging *within other component tests*.

## Implementation Steps

### 1.1 Create Logging Utilities (1 day)    

1. **Write Tests**
   - Create tests for log formatting helpers
   - Verify logger tag generation works correctly
   - Test conditional logging behavior
   - Test file-specific logging level configuration
   - Test string-based logger functionality

2. **Implementation**

```dart
// lib/core/utils/log_helpers.dart

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

/// Default release mode level
final Level _defaultReleaseLevel = Level.warning;

/// Default debug mode level
final Level _defaultDebugLevel = Level.info;

/// Map to store file-specific log levels
final Map<String, Level> _logLevels = {};

/// Converts a Type or String to a consistent string identifier
String _getLogId(dynamic target) {
  if (target is Type) {
    return target.toString();
  } else if (target is String) {
    return target;
  }
  throw ArgumentError(
    'Logger target must be Type or String, but was ${target.runtimeType}',
  );
}

/// LoggerFactory for creating loggers with appropriate tags and levels
class LoggerFactory {
  /// Get a logger for a specific class or string identifier with optional custom level
  ///
  /// Accepts either:
  /// - A Type (class): LoggerFactory.getLogger(MyClass)
  /// - A String: LoggerFactory.getLogger("TestLogger")
  static Logger getLogger(dynamic target, {Level? level}) {
    final tag = _getLogId(target);
    final logLevel = level ?? _logLevels[tag] ?? (kReleaseMode ? _defaultReleaseLevel : _defaultDebugLevel);
    
    return Logger(
      filter: CustomLogFilter(logLevel),
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: false,
      ),
    );
  }
  
  /// Set log level for a specific class or string identifier
  static void setLogLevel(dynamic target, Level level) {
    _logLevels[_getLogId(target)] = level;
  }
  
  /// Reset all custom log levels
  static void resetLogLevels() {
    _logLevels.clear();
  }
  
  /// Set global default log level
  static void setDefaultLogLevel(Level level) {
    if (kReleaseMode) {
      // Prevent setting levels below warning in release mode
      if (level.index < Level.warning.index) {
        level = Level.warning;
      }
    }
    
    if (!kReleaseMode) {
      _defaultDebugLevel = level;
    } else {
      _defaultReleaseLevel = level;
    }
  }
  
  /// Get the current effective log level for a type or string identifier
  static Level getCurrentLevel(dynamic target) {
    final tag = _getLogId(target);
    return _logLevels[tag] ?? (kReleaseMode ? _defaultReleaseLevel : _defaultDebugLevel);
  }
}

/// Custom log filter with per-instance level control
class CustomLogFilter extends LogFilter {
  final Level level;
  
  CustomLogFilter(this.level);
  
  @override
  bool shouldLog(LogEvent event) {
    // Handle Level.off explicitly
    if (level == Level.off) {
      return false;
    }
    return event.level.index >= level.index;
  }
}

/// Generate a consistent tag for a class or string identifier
String logTag(dynamic target) => _getLogId(target);

/// Format PlaybackState for logging
String formatPlaybackState(PlaybackState state) {
  return state.when(
    initial: () => 'initial',
    loading: () => 'loading',
    playing: (pos, dur) => 'playing(${pos.inMilliseconds}ms/${dur?.inMilliseconds ?? 'N/A'}ms)',
    paused: (pos, dur) => 'paused(${pos.inMilliseconds}ms/${dur?.inMilliseconds ?? 'N/A'}ms)',
    stopped: () => 'stopped',
    completed: () => 'completed',
    error: (msg, pos, dur) => 'error($msg)',
  );
}
```

3. **Verification**
   - Run formatter utility tests
   - Manually test formatting output for different states
   - Verify per-file logging levels work as expected

### 1.2 Update One Component's Logging (0.5 day per component)

Start with a single component like `AudioPlayerAdapter`. Apply the new logging approach to this component while ensuring it doesn't change behavior.

1. **Write Tests**
   - Create a test that mocks the logger and verifies logging calls
   - Verify that the new logging doesn't affect functionality
   - Test changing the log level for the specific component

2. **Implementation**

```dart
// lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:logger/logger.dart';

class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  static final _tag = logTag(AudioPlayerAdapterImpl);
  final Logger logger;
  
  AudioPlayerAdapterImpl({Logger? logger}) : 
    this.logger = logger ?? LoggerFactory.getLogger(AudioPlayerAdapterImpl);
  
  // Enable debug logs for this component only
  static void enableDebugLogs() {
    LoggerFactory.setLogLevel(AudioPlayerAdapterImpl, Level.debug);
  }
  
  // Update logging calls
  Future<void> resume() async {
    logger.d('$_tag resume: Started');
    try {
      await _audioPlayer.play();
      logger.d('$_tag resume: Completed successfully');
    } catch (e, s) {
      logger.e('$_tag resume: Failed', error: e, stackTrace: s);
      rethrow;
    }
  }
  
  // Other methods...
}
```

### 1.2.1 Alternative: Using String-Based Loggers for Cross-Component Modules

For utilities, services or cross-component modules, you can use string-based loggers:

```dart
// lib/features/audio_recorder/utils/audio_formatting.dart

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:logger/logger.dart';

/// Constants for logging
class AudioFormattingLogs {
  static const String identifier = "AudioFormatting";
  
  // Enable debug logs for this module
  static void enableDebugLogs() {
    LoggerFactory.setLogLevel(identifier, Level.debug);
  }
}

/// Audio formatting utility functions
class AudioFormatting {
  static final _tag = logTag(AudioFormattingLogs.identifier);
  static final Logger _logger = LoggerFactory.getLogger(AudioFormattingLogs.identifier);
  
  static String formatAudioDuration(Duration duration) {
    _logger.d('$_tag Formatting duration: $duration');
    // Implementation...
  }
  
  // Other methods...
}
```

3. **Verification**
   - Run existing adapter tests to verify no behavior change
   - Manual testing with logging output enabled
   - Verify enabling/disabling debug logs for the component works

### 1.3 Gradually Update All Components (3-5 days)

Apply the same logging approach to each component in sequence:

1. `AudioPlayerAdapterImpl`
2. `PlaybackStateMapperImpl`
3. `AudioPlaybackServiceImpl`
4. `AudioListCubit`
5. `AudioPlayerWidget`

For each component:
- Keep the same verification process
- Ensure all tests continue to pass
- Verify no behavior changes
- Add component-specific log level control with `enableDebugLogs()` static method

### 1.4 Remove Debug Flags and Commented Logs (1 day)

Once all components are using the new logging approach:

1. Remove all commented-out log statements
2. Replace debug flags with conditional logging
3. Standardize log levels across components

```dart
// Before
const bool _debugStateTransitions = true;
if (_debugStateTransitions) {
  logger.d('[STATE_TRANSITION] Some info');
}

// After
// No conditional check needed - log level control handles this
logger.d('$_tag stateTransition: Some info');
```

### 1.5 Update Tests for Component-Specific Logging (1 day)

1. **Test Helpers for Logging**

```dart
// test/helpers/log_test_helpers.dart

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:logger/logger.dart';

/// Reset all log levels to default before/after tests
void resetLogLevels() {
  LoggerFactory.resetLogLevels();
}

/// Enable debug logs for a specific component during a test
/// 
/// Works with both Type and String identifiers:
/// ```dart
/// // With Type (class):
/// await withDebugLogsFor(MyComponent, () async { /* test code */ });
/// 
/// // With String identifier:
/// await withDebugLogsFor("Feature.Logger", () async { /* test code */ });
/// ```
Future<void> withDebugLogsFor(dynamic target, Future<void> Function() testFn) async {
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    LoggerFactory.setLogLevel(target, Level.debug);
    await testFn();
  } finally {
    LoggerFactory.setLogLevel(target, originalLevel);
  }
}

/// Enable logs of a specific level for a component during a test
/// 
/// Works with both Type and String identifiers:
/// ```dart
/// // With Type (class):
/// await withLogLevelFor(MyComponent, Level.warning, () async { /* test code */ });
/// 
/// // With String identifier:
/// await withLogLevelFor("Feature.Logger", Level.warning, () async { /* test code */ });
/// ```
Future<void> withLogLevelFor(
  dynamic target,
  Level level,
  Future<void> Function() testFn,
) async {
  final originalLevel = LoggerFactory.getCurrentLevel(target);
  try {
    LoggerFactory.setLogLevel(target, level);
    await testFn();
  } finally {
    LoggerFactory.setLogLevel(target, originalLevel);
  }
}

/// Memory output to capture logs during tests
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

/// Creates and returns a TestLogOutput instance for capturing logs
TestLogOutput captureLogOutput() {
  return TestLogOutput();
}

/// Assert that logs contain a specific message at a specific level
void expectLogContains(
  TestLogOutput output, 
  Level level, 
  String expectedSubstring,
  {String? reason}
) {
  expect(
    output.containsMessage(level, expectedSubstring), 
    isTrue,
    reason: reason ?? 'Expected log to contain "$expectedSubstring" at level ${level.name}'
  );
}
```

2. **Test Examples**

```dart
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import '../../helpers/log_test_helpers.dart';

testWidgets('AudioPlayer logs detailed information when debug enabled', (tester) async {
  final output = captureLogOutput();
  
  // Type-based logger example
  await withDebugLogsFor(AudioPlayerAdapterImpl, () async {
    // Test with verbose logging enabled for this component
    final adapter = AudioPlayerAdapterImpl();
    await adapter.resume();
    
    // Verify debug logs were captured
    expectLogContains(output, Level.debug, 'resume: Started');
  });
  
  // String-based logger example
  await withDebugLogsFor("AudioFormatting", () async {
    final formatter = AudioFormatting();
    formatter.formatAudioDuration(Duration(seconds: 30));
    
    // Verify debug logs were captured
    expectLogContains(output, Level.debug, 'Formatting duration');
  });
});
```

### 1.6 Important Note About String and Type Loggers

When a Type and String have the same name (e.g., `MyClass` vs `"MyClass"`), they will share the same log level. The last `setLogLevel` call will determine the level for both. This is because the implementation uses the string representation of Types for internal storage.

```dart
// This will set both loggers to Level.debug  
LoggerFactory.setLogLevel(MyClass, Level.warning);
LoggerFactory.setLogLevel("MyClass", Level.debug); // Last call wins

// Both will now return Level.debug
LoggerFactory.getCurrentLevel(MyClass);      // Level.debug
LoggerFactory.getCurrentLevel("MyClass");    // Level.debug
```

To avoid this behavior, use distinct names for string-based loggers that don't match class names.

### 1.7 When to Use String vs Type Loggers

- **Type-based loggers** (recommended for classes):
  - For all regular classes with a clear OOP structure
  - Makes refactoring safer as IDE tools can track Type usage
  - Provides better code navigation in modern IDEs
  
- **String-based loggers** (for special cases):
  - For test-only loggers (avoids creating dummy test classes)
  - For utility functions or modules without a clear class
  - For shared subsystems that span multiple classes
  - For cross-component modules or services

### 1.8 Verify and Cleanup (1 day)

1. Run the full test suite
2. Perform manual testing with different log levels
3. Remove any remaining legacy logging code
4. Document the new logging system in the README

## Success Criteria

1. All components use the standardized logging pattern
2. No commented-out logging code remains
3. All tests pass with the updated logging
4. Logs are consistent and provide clear insight into program flow
5. Debug information is only generated when needed
6. Each file can control its own log level
7. Tests can selectively enable logging for specific components
8. No functional behavior has changed
9. Both Type and String identifiers are supported for flexibility

## Risks and Mitigations

**Risk**: Accidentally removing important logging that aids debugging
**Mitigation**: Ensure all critical paths have appropriate logs at proper levels

**Risk**: Performance impact from string formatting
**Mitigation**: Log level checks happen at the filter level, avoiding unnecessary string formatting

**Risk**: Log pollution in production
**Mitigation**: Enforce minimum log level in release mode through the factory

**Risk**: Forgetting to reset log levels between tests
**Mitigation**: Create utility functions that handle setup/teardown of log levels 

**Risk**: Same-named Type and String identifiers causing confusion
**Mitigation**: Document this behavior and use distinct string identifiers 