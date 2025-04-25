# DocJet Mobile

A mobile app for the DocJet platform.

## Table of Contents

- [Features](#features)
  - [Logging System](#logging-system)
- [Development](#development)
  - [Getting Started](#getting-started)
  - [Integration Tests](#integration-tests)
    - [Running Integration Tests with Mock Server](#running-integration-tests-with-mock-server)
    - [Mock Server Details](#mock-server-details)
    - [Mock Server Capabilities & Limitations](#mock-server-capabilities--limitations)
  - [End-to-End (E2E) Tests (integration_test)](#end-to-end-e2e-tests-integration_test)
  - [Configuring the App (API Key & Domain)](#configuring-the-app-api-key--domain)

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
   *Note: For configuring API keys and endpoints (e.g., using the mock server), see the "Configuring the App (API Key & Domain)" section below.*

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
- **API Domain:** `localhost:8080` (API version is managed centrally)
- **Authentication:** Bearer token (any non-empty token works for testing)
- **Supported endpoints:** auth/login, jobs (GET/POST/PATCH), jobs/:id, jobs/:id/documents

For more details on the available API endpoints, check the mock server implementation in `mock_api_server/bin/server.dart`.

#### Mock Server Capabilities & Limitations

Our mock server provides a comprehensive simulation of the backend API for testing and development:

**What it can do:**
- ✅ Full authentication flow (login, refresh token, user profile)
- ✅ Complete job CRUD operations (Create, Read, Update, Delete)
- ✅ Multipart form handling for file uploads
- ✅ In-memory job storage with proper relationships
- ✅ API key and token validation
- ✅ Error simulation with proper status codes
- ✅ Job document associations

**What it cannot do:**
- ❌ Persist data between server restarts (uses in-memory storage)
- ❌ Process audio files (just stores a reference, no actual processing)
- ❌ Simulate network latency or throttling (responses are immediate)
- ❌ Validate actual JWT token contents (any non-empty token is accepted)

**Running the App with Mock Server:**

For the best development experience using the mock server, use our convenience script:
```bash
./scripts/run_with_mock.sh
```

This script:
1. Starts the mock API server on port 8080
2. Configures proper environment variables via `secrets.test.json`
3. Runs the Flutter app with the correct configuration
4. Handles automatic cleanup on exit

> **Note:** When running the app with the mock server, you can use any email/password combination for login, as the mock server accepts all credentials. The app will display a simulated user profile from the mock server.

For more details about the mock server, see `mock_api_server/README.md`.

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
    *   Run `flutter test integration_test/app_test.dart` *with* the appropriate `--dart-define` flags for the mock API key and domain.
    *   Automatically stop the mock server when tests are complete (or if the script fails).

#### Configuring the App (API Key & Domain)

Forget `.env` files like some amateur. We use compile-time definitions via `--dart-define` for configuration. It's cleaner, safer (keeps secrets out of the repo), and the standard Flutter way.

The app expects two main variables:
- `API_KEY`: Your API key.
- `API_DOMAIN`: The domain for the API (e.g., `api.docjet.com` or `localhost:8080`).

**API Versioning**:
We use a centralized approach to API versioning with `ApiConfig`. The version is specified in a single location and used consistently across the app. See [API Versioning](docs/current/api_versioning.md) for details.

**How to Use:**

Pass these variables when running or building the app:

*   **Running Locally with Mock Server:**
    For easy local development against the mock server, use the provided script. It handles starting the server, running the app with the correct configuration (`secrets.test.json`), and stopping the server automatically when you quit.
    ```bash
    # Make sure it's executable (first time only)
    chmod +x ./scripts/run_with_mock.sh
    # Run the app
    ./scripts/run_with_mock.sh
    ```
    This is the recommended way to run the app for testing features that require a backend.

*   **Running E2E Tests (Handled by `run_e2e_tests.sh`):**
    The E2E test script (`scripts/run_e2e_tests.sh`) uses the `secrets.test.json` file to load configuration automatically:
    `--dart-define-from-file=secrets.test.json`
    Ensure you have copied `secrets.test.json.example` to `secrets.test.json`.

*   **Running Manually (e.g., against a Staging API):**
    ```bash
    flutter run \
      --dart-define=API_KEY=YOUR_STAGING_API_KEY \
      --dart-define=API_DOMAIN=staging.docjet.com
    ```

*   **Building for Production:**
    Inject your production keys via your CI/CD pipeline or build script:
    ```bash
    flutter build <target> \
      --dart-define=API_KEY=YOUR_PROD_API_KEY \
      --dart-define=API_DOMAIN=www.docjet.com
    ```

*   **Using a JSON File (for multiple variables):**
    For managing different environments (test, dev, prod), create separate files like `secrets.test.json`, `secrets.dev.json`, etc. (add these to `.gitignore`!). A template for the test configuration is provided in `secrets.test.json.example`. After cloning, copy it: `cp secrets.test.json.example secrets.test.json`.

    Example `secrets.json` files:
    ```json
    // secrets.test.json (for local mock server)
    {
      "API_KEY": "test-api-key",
      "API_DOMAIN": "localhost:8080"
    }

    // secrets.staging.json (for staging environment)
    {
      "API_KEY": "staging-api-key",
      "API_DOMAIN": "staging.docjet.com"
    }

    // secrets.prod.json (for production)
    {
      "API_KEY": "prod-api-key",
      "API_DOMAIN": "www.docjet.com"
    }
    ```
    Then run/build with the appropriate file:
    ```bash
    flutter run --dart-define-from-file=secrets.staging.json
    # The E2E test script (`./scripts/run_e2e_tests.sh`) uses secrets.test.json
    # The local run script (`./scripts/run_with_mock.sh`) also uses secrets.test.json
    ```

Inside the Dart code, the domain is transformed into a full URL with the correct API version using `ApiConfig`:
```dart
// In DioFactory
final baseUrl = ApiConfig.baseUrlFromDomain(_apiDomain);
```