# DocJet Mobile

A mobile app for the DocJet platform.

## Features

### Logging System

DocJet uses a standardized logging approach with consistent formatting and controllable log levels. Unlike most half-assed logging systems, ours is both simple to use AND fully testable.

#### Basic Usage

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

#### String-Based Loggers

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

#### Log Levels

- **trace** - Extremely detailed logs, rarely needed
- **debug** - Helpful for development and troubleshooting
- **info** - Normal operational messages
- **warning** - Potential issues that don't stop execution
- **error** - Failures that impact functionality
- **fatal** - Critical failures

#### Release Mode Behavior

In release mode, logs below `warning` level are automatically filtered out,
regardless of the configured level. This ensures production performance
is not impacted by debug logging.

#### Controlling Log Levels

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

#### Testing with Logs

Our logging system allows full testing without dependency injection. You can:

1. Control log levels of any component from tests
2. Capture and verify logs from components
3. Use test-specific loggers that don't interfere with component logs

```dart
test('logs error when processing fails', () {
  // Clear logs before test
  LoggerFactory.clearLogs();
  
  // Run code that should log
  processor.process("invalid task");
  
  // Verify logs
  expect(
    LoggerFactory.containsLog("Failed to process task", forType: TaskProcessor),
    isTrue,
  );
});
```

See [Logging Guide](docs/logging_guide.md) for comprehensive examples and implementation details.

## Development

### Getting Started

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app in debug mode
