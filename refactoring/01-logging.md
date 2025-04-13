# Step 1: Clean Up Logging

## Overview

This step focuses on standardizing logging without changing any functional behavior. It's an ideal first step as it improves code readability with minimal risk.

**Estimated time:** 7-10 days

**Key Files & Roles Clarification:**

*   **`lib/core/utils/log_helpers.dart`**: Contains the **new `LoggerFactory`** system. This is the target implementation.
*   **`lib/core/utils/logger.dart`**: The **old logger** implementation (often just re-exporting). This will be removed after refactoring.
*   **`test/core/utils/log_helpers_test.dart`**: Contains **unit tests** specifically for `lib/core/utils/log_helpers.dart`.
*   **`test/helpers/log_helpers.dart`**: Contains **test utilities** (e.g., `TestLogOutput`, `withDebugLogsFor`) to help verify logging *within other component tests*.

## Implementation Steps

### 1.1 Create Logging Utilities (1 day)    

1. **Write Tests**
   - Create tests for log formatting helpers
   - Verify logger tag generation works correctly
   - Test conditional logging behavior
   - Test file-specific logging level configuration

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

/// LoggerFactory for creating loggers with appropriate tags and levels
class LoggerFactory {
  /// Get a logger for a specific class with optional custom level
  static Logger getLogger(Type type, {Level? level}) {
    final tag = type.toString();
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
  
  /// Set log level for a specific class
  static void setLogLevel(Type type, Level level) {
    _logLevels[type.toString()] = level;
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
}

/// Custom log filter with per-instance level control
class CustomLogFilter extends LogFilter {
  final Level level;
  
  CustomLogFilter(this.level);
  
  @override
  bool shouldLog(LogEvent event) {
    return event.level.index >= level.index;
  }
}

/// Generate a consistent tag for a class
String logTag(Type type) => type.toString();

/// Format PlaybackState for logging
String formatPlaybackState(PlaybackState state) {
  return state.when(
    initial: () => 'initial',
    loading: () => 'loading',
    playing: (pos, dur) => 'playing(${pos.inMilliseconds}ms/${dur.inMilliseconds}ms)',
    paused: (pos, dur) => 'paused(${pos.inMilliseconds}ms/${dur.inMilliseconds}ms)',
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
// test/helpers/log_helpers.dart

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:logger/logger.dart';

/// Reset all log levels to default before/after tests
void resetLogLevels() {
  LoggerFactory.resetLogLevels();
}

/// Enable debug logs for a specific component during a test
void withDebugLogsFor(Type type, Function() testFn) async {
  try {
    LoggerFactory.setLogLevel(type, Level.debug);
    await testFn();
  } finally {
    LoggerFactory.resetLogLevels();
  }
}
```

2. **Test Example**

```dart
testWidgets('AudioPlayer logs detailed information when debug enabled', (tester) async {
  await withDebugLogsFor(AudioPlayerAdapterImpl, () async {
    // Test with verbose logging enabled for this component
    // ...
  });
});
```

### 1.6 Verify and Cleanup (1 day)

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

## Risks and Mitigations

**Risk**: Accidentally removing important logging that aids debugging
**Mitigation**: Ensure all critical paths have appropriate logs at proper levels

**Risk**: Performance impact from string formatting
**Mitigation**: Log level checks happen at the filter level, avoiding unnecessary string formatting

**Risk**: Log pollution in production
**Mitigation**: Enforce minimum log level in release mode through the factory

**Risk**: Forgetting to reset log levels between tests
**Mitigation**: Create utility functions that handle setup/teardown of log levels 