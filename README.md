# DocJet Mobile

A mobile app for the DocJet platform.

## Table of Contents

- [Features](#features)
  - [Logging System](#logging-system)
- [Development](#development)
  - [Getting Started](#getting-started)
  - [Integration Tests](#integration-tests)
  - [End-to-End (E2E) Tests (integration_test)](#end-to-end-e2e-tests-integration_test)
  - [Configuring the App (API Key & Base URL)](#configuring-the-app-api-key--base-url)

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
4. Run `flutter run` to start the app in debug mode.
   *Note: For configuring API keys and endpoints (e.g., using the mock server), see the "Configuring the App (API Key & Base URL)" section below.*

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

### End-to-End (E2E) Tests (integration_test)

These tests drive the actual application UI on a device or emulator, interacting with widgets like a real user would. They use the `integration_test` package and require a mock backend for reliable execution.

#### Running E2E Tests

We use a wrapper script to handle the mock server lifecycle, as direct process management from tests is restricted on some platforms (like iOS).

1.  **Ensure a device or emulator is running and connected.** You can check with `flutter devices`.

2.  **Make the script executable (if you haven't already):**
    ```bash
    chmod +x ./run_e2e_tests.sh
    ```

3.  **Run the E2E tests using the script:**
    The `run_e2e_tests.sh` script is designed to automatically pass the necessary `--dart-define` flags to point the app to the mock server.
    ```bash
    ./run_e2e_tests.sh
    ```
    This script will:
    *   Start the `mock_api_server` in the background.
    *   Run `flutter test integration_test/app_test.dart` *with* the appropriate `--dart-define` flags for the mock API key and URL.
    *   Automatically stop the mock server when tests are complete (or if the script fails).

#### Configuring the App (API Key & Base URL)

Forget `.env` files like some amateur. We use compile-time definitions via `--dart-define` for configuration. It's cleaner, safer (keeps secrets out of the repo), and the standard Flutter way.

The app expects two main variables:
- `API_KEY`: Your API key.
- `API_BASE_URL`: The base URL for the API endpoint.

**How to Use:**

Pass these variables when running or building the app:

*   **Running with Mock Server (Handled by `run_e2e_tests.sh`):**
    The test script sets:
    `--dart-define=API_KEY=test-api-key`
    `--dart-define=API_BASE_URL=http://localhost:8080/api/v1`

*   **Running Manually (e.g., against a Dev API):**
    ```bash
    flutter run \\
      --dart-define=API_KEY=YOUR_DEV_API_KEY \\
      --dart-define=API_BASE_URL=https://your.dev.api.com/api/v1
    ```

*   **Building for Production:**
    Inject your production keys via your CI/CD pipeline or build script:
    ```bash
    flutter build <target> \\
      --dart-define=API_KEY=YOUR_PROD_API_KEY \\
      --dart-define=API_BASE_URL=https://your.prod.api.com/api/v1
    ```

*   **Using a JSON File (for multiple variables):**
    For managing different environments (test, dev, prod), create separate files like `secrets.test.json`, `secrets.dev.json`, etc. (add these to `.gitignore`!). A template for the test configuration is provided in `secrets.test.json.example`. After cloning, copy it: `cp secrets.test.json.example secrets.test.json`.

    Example `secrets.dev.json`:
    ```json
    {
      "API_KEY": "some_key",
      "API_BASE_URL": "some_url"
    }
    ```
    Then run/build with the appropriate file:
    ```bash
    flutter run --dart-define-from-file=secrets.dev.json
    # or for tests, the run_e2e_tests.sh script uses secrets.test.json
    ```

Inside the Dart code (e.g., `lib/core/config/app_config.dart` or wherever your API client is setup), access these like so:
```dart
const apiKey = String.fromEnvironment('API_KEY', defaultValue: 'MISSING_API_KEY');
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'MISSING_BASE_URL');

// Add checks to ensure these aren't the default values in production!
```
