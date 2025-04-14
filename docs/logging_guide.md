# DocJet Logging Guide

DocJet uses a standardized logging approach with consistent formatting and controllable log levels. Unlike most half-assed logging systems, ours is both simple to use AND fully testable.

## Basic Usage

```dart
class MyComponent {
  // Create a logger for this class
  static final Logger _logger = LoggerFactory.getLogger(MyComponent);
  static final String _tag = logTag(MyComponent);

  void doSomething() {
    _logger.i('$_tag Starting operation');
    try {
      // ... code ...
      _logger.d('$_tag Operation details: $details');
    } catch (e, s) {
      _logger.e('$_tag Operation failed', error: e, stackTrace: s);
      rethrow;
    }
  }
}
```

## String-Based Loggers

For utilities or cross-component modules, you can use string identifiers:

```dart
// Utility function
void processSomething() {
  final logger = LoggerFactory.getLogger("Utils.Processing");
  final tag = logTag("Utils.Processing");
  
  logger.i('$tag Starting process');
  // ... code ...
}
```

## Log Levels

- **trace** - Extremely detailed logs, rarely needed
- **debug** - Helpful for development and troubleshooting
- **info** - Normal operational messages
- **warning** - Potential issues that don't stop execution
- **error** - Failures that impact functionality
- **fatal** - Critical failures

## Controlling Log Levels

You can dynamically control log levels for any component:

```dart
// Set component to debug level
LoggerFactory.setLogLevel(MyComponent, Level.debug);

// Set string logger to error level
LoggerFactory.setLogLevel("Utils.Processing", Level.error);

// Get current level
Level currentLevel = LoggerFactory.getCurrentLevel(MyComponent);

// Reset all to defaults
LoggerFactory.resetLogLevels();
```

## Testing With Logs

Our logging system allows full testing without dependency injection. Here's how:

### Direct Testing Approach

Our core approach is simple: all logs are automatically captured by the framework, and you just need to check for them:

```dart
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyComponent', () {
    setUp(() {
      // Always clear logs before each test
      LoggerFactory.clearLogs();
    });
    
    test('logs error when processing fails', () {
      // Run code that should log
      myComponent.doSomethingBad();
      
      // Verify logs with the containsLog method
      expect(
        LoggerFactory.containsLog('Expected error message', forType: MyComponent),
        isTrue,
      );
    });
  });
}
```

### Test-Specific Loggers

Need a logger just for your tests? No problem:

```dart
// Create a logger for your tests at file level
final testLogger = LoggerFactory.getLogger('MyTestLogger');
final testTag = logTag('MyTestLogger');

void main() {
  setUp(() {
    LoggerFactory.clearLogs();
    
    // Log stuff from your test
    testLogger.i('$testTag Setting up test');
  });
  
  test('does something and logs appropriately', () {
    // Log from the test
    testLogger.i('$testTag Running the test');
    
    // Run the component
    component.doSomething();
    
    // Test code...
    
    // Verify test logger logs
    expect(
      LoggerFactory.containsLog('Running the test', forType: 'MyTestLogger'),
      isTrue,
    );
    
    // Verify component logs separately
    expect(
      LoggerFactory.containsLog('Component log message', forType: MyComponent),
      isTrue,
    );
  });
}
```

### Controlling Log Levels In Tests

Want to enable DEBUG logs for a specific component during tests? Easy:

```dart
test('logs detailed debug information', () {
  // Set component to debug level for this test
  LoggerFactory.setLogLevel(MyComponent, Level.debug);
  
  // Generate logs
  component.doSomething();
  
  // Check for debug logs that would otherwise be filtered out
  expect(
    LoggerFactory.containsLog('Detailed debug info', forType: MyComponent),
    isTrue,
  );
});
```

Change log levels for any component at any time - even ones with static loggers created before your test!

### Testing Log Level Filtering

Need to verify that logs are properly filtered by level? No problem:

```dart
test('respects log level settings', () {
  // Set to WARNING level
  LoggerFactory.setLogLevel(MyComponent, Level.warning);
  
  // Run code that logs at different levels
  component.doSomething();
  
  // Debug logs should be filtered
  expect(
    LoggerFactory.containsLog('Debug message'),
    isFalse,
  );
  
  // Warnings should get through
  expect(
    LoggerFactory.containsLog('Warning message'),
    isTrue,
  );
});
```

### Advanced Features

Need to filter logs by component or get all logs?

```dart
// Get all logs for a specific component
final componentLogs = LoggerFactory.getLogsFor(MyComponent);

// Get all logs captured during the test
final allLogs = LoggerFactory.getAllLogs();

// Use advanced checks on specific logs
final hasErrors = allLogs.any(
  (event) => event.level == Level.error && 
             event.lines.any((line) => line.contains('specific message'))
);
```

## Why This Approach Rules

Unlike most logging frameworks that require:
1. Dependency injection 
2. Constructor modification
3. Mocking
4. Complex setup

Our system requires NONE of that shit. It "just works" because:

1. All loggers share a global filter system that can be controlled from tests
2. Every logger's output is automatically captured for verification
3. Log levels can be changed at ANY time, even for static loggers
4. You can have separate test loggers that don't interfere with component logs

As Axe Capital's Dollar Bill would say: "Why make it complicated when making it simple works so fucking well?"

## Implementation Details 

If you're curious how we implemented this without dependency injection, here's the magic:

```dart
class LoggerFactory {
  // Shared map for log levels - all filters reference this
  static final Map<String, Level> _logLevels = {};
  
  // Get the current level for any logger
  static Level getCurrentLevel(dynamic type) {
    final id = _getLoggerId(type);
    return _logLevels[id] ?? _defaultLevel;
  }
  
  // Set the level for any logger at any time
  static void setLogLevel(dynamic type, Level level) {
    final id = _getLoggerId(type);
    _logLevels[id] = level;
  }
  
  // Each logger gets a filter that does live lookups
  static Logger getLogger(dynamic type) {
    return Logger(
      filter: CustomLogFilter(id, _logLevels, _defaultLevel),
      // ...
    );
  }
}

// The magic: filter does a dynamic lookup instead of caching
class CustomLogFilter extends LogFilter {
  final String id;
  final Map<String, Level> _logLevels;
  final Level _defaultLevel;
  
  @override
  bool shouldLog(LogEvent event) {
    // LIVE lookup of current level - not cached!
    final currentLevel = _logLevels[id] ?? _defaultLevel;
    return event.level.index >= currentLevel.index;
  }
}
```

This pattern allows control of log levels independently of logger instantiation, making testing trivial.

## Important Note About Logger IDs

When a `Type` and a `String` have the **exact same name** (e.g., the class `MyClass` and the string `"MyClass"`), they are treated as the **SAME LOGGER TARGET** internally.

This means:
- `LoggerFactory.getLogger(MyClass)` and `LoggerFactory.getLogger("MyClass")` point to the same log level setting
- Using `LoggerFactory.setLogLevel(MyClass, ...)` **WILL AFFECT** the level for `"MyClass"`, and vice-versa

To keep logger levels independent:
- Use distinct names: `"MyClassTest"` instead of `"MyClass"` for test loggers
- Control class logs with: `LoggerFactory.setLogLevel(MyClass, ...)`
- Control test logs with: `LoggerFactory.setLogLevel("MyClassTestLogger", ...)` 