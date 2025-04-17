# DocJet Mobile

A mobile app for the DocJet platform.

## Features

### Logging System

DocJet uses a standardized logging approach with consistent formatting and controllable log levels. Unlike most half-assed logging systems, ours is both simple to use AND fully testable.

#### Basic Usage

```dart
class MyComponent {
  // Create a logger for this class.
  // BEST PRACTICE: Default to Level.off unless component logging is needed
  // during normal operation. Tests will override this level as needed.
  static final Logger _logger = LoggerFactory.getLogger(MyComponent, level: Level.off);
  static final String _tag = logTag(MyComponent);

  void doSomething() {
    _logger.i('$_tag Starting operation');
    try {
      // ... code ...
      // This debug log will only show if the level is raised (e.g., in tests)
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

You can dynamically control log levels for any component. Setting a level with `setLogLevel` **overrides** any default level specified in `getLogger` or the global default.

```dart
// Set component to debug level. This becomes the effective level.
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

1. Control log levels of any component from tests using `setLogLevel`.
2. Capture and verify logs from components using `containsLog` or `getLogsFor`.
3. Use test-specific loggers that don't interfere with component logs.

```dart
test('logs error when processing fails', () {
  // Clear logs and set desired level for the SUT
  LoggerFactory.clearLogs();
  LoggerFactory.setLogLevel(TaskProcessor, Level.debug); // Enable SUT logs for test
  
  // Arrange: Create the processor (assuming its default is Level.off)
  final processor = TaskProcessor();

  // Act: Run code that should log
  processor.process("invalid task");
  
  // Assert: Verify logs
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

### Integration Tests

The project includes integration tests that use a mock API server to simulate the backend.

#### Running Integration Tests with Mock Server

1. **Start the mock server:**
   ```bash
   cd mock_api_server && dart bin/server.dart
   ```
   The mock server will start on port 8080 with predefined API endpoints.

2. **Run the Job Datasource integration test:**
   ```bash
   flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```
   
   This test:
   - Automatically manages the mock server (starts/stops it)
   - Tests the complete flow of creating jobs with file uploads
   - Validates the integration between remote and local datasources
   
   If you need to run the test manually with a pre-running server, use:
   ```bash
   cd mock_api_server && dart bin/server.dart &
   flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```

3. **One-liner (recommended):**
   For the cleanest test run that ensures no stale servers are running:
   ```bash
   cd mock_api_server && pkill -f "dart bin/server.dart" || true && echo "Mock server stopped. Now running the integration test:" && flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```
   This command kills any existing mock server, outputs a status message, and runs the test with verbose output.

4. **Stopping the mock server:**
   If you started the server in the background, you can stop it with:
   ```bash
   lsof -ti :8080 | xargs kill -9
   ```

#### Mock Server Details

- **API Key:** `test-api-key` (required in X-API-Key header)
- **Base URL:** `http://localhost:8080/api/v1` 
- **Authentication:** Bearer token (any non-empty token works for testing)
- **Supported endpoints:** auth/login, jobs (GET/POST/PATCH), jobs/:id, jobs/:id/documents

For more details on the available API endpoints, check the mock server implementation in `mock_api_server/bin/server.dart`.
