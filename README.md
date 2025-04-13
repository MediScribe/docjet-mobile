# DocJet Mobile

A mobile app for the DocJet platform.

## Features

### Logging System

DocJet uses a standardized logging approach with consistent formatting and controllable log levels.

#### Basic Usage

```dart
class MyComponent {
  // Create a logger for this class
  final Logger logger = LoggerFactory.getLogger(MyComponent);
  static final String _tag = logTag(MyComponent);

  void doSomething() {
    logger.i('$_tag Starting operation');
    try {
      // ... code ...
      logger.d('$_tag Operation details: $details');
    } catch (e, s) {
      logger.e('$_tag Operation failed', error: e, stackTrace: s);
      rethrow;
    }
  }
  
  // Add a static method to enable debug logs
  static void enableDebugLogs() {
    LoggerFactory.setLogLevel(MyComponent, Level.debug);
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

// Enable debug logs for this module
void enableProcessingDebugLogs() {
  LoggerFactory.setLogLevel("Utils.Processing", Level.debug);
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

#### Testing with Logs

See the [DocJet Test Utilities](packages/docjet_test/README.md) for information on
testing components that use the logging system.

## Development

### Getting Started

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app in debug mode
