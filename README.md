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
  - [Linting](#linting)
- [Audio Recording](#audio-recording)
  - [Platform Setup](#platform-setup)
    - [iOS](#ios)
    - [Android](#android)
  - [File Path Normalization](#file-path-normalization)

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

> **⚠️ IMPORTANT FOR iOS DEVICE TESTING:** The app is configured without special entitlements to allow running on physical iOS devices without a paid Apple Developer account. If you restore any entitlements to `ios/Runner/Runner.entitlements` (such as Autofill Provider capabilities), you will need a paid Apple Developer Program membership to run on physical devices. If you encounter "not eligible for this feature" errors, check that file for entitlements that require paid membership.

## iOS Development Gotchas

### Debug Build Crashes on Standalone Launch

**Symptom:** Your app runs perfectly when launched from Xcode or `flutter run` directly to an iOS device. However, if you stop the app (or disconnect the debugger) and then try to launch it by tapping the app icon on the device, it crashes immediately.

**Cause:** This is expected behavior for **debug builds** on iOS. Debug builds maintain an active connection to the Flutter tooling (Dart VM service) on your development machine for features like hot reload. When this connection is severed and the app is launched standalone, it crashes because it cannot find the required VM service.

**Solution:** This issue does **not** affect `profile` or `release` builds.

*   **For regular development and testing where you want the app to run independently on the device:**
    Build and run in **release mode**:
    ```bash
    flutter run --release
    ```
*   **For performance profiling on the device:**
    Build and run in **profile mode**:
    ```bash
    flutter run --profile
    ```

**Key Takeaway:** If you need to hand off a build to someone to run on their device, or if you want to test the app's cold launch behavior as a user would experience it, **always use a release build (`flutter run --release`)**. Don't be alarmed if a debug build crashes when launched directly on the device after the debugger is detached.

### Linting

We use the standard `dart analyze` for basic analysis, but we also have custom lint rules (e.g., to prevent misuse of the service locator). To run these custom rules, use the `custom_lint` package runner:

```bash
flutter pub run custom_lint
```

To enforce these rules strictly (e.g., in CI), use the `--fatal-infos` and `--fatal-warnings` flags:

```bash
flutter pub run custom_lint --fatal-infos --fatal-warnings
```

*Note: The standard `dart analyze` command does **not** run these custom rules.*

### Integration Tests

The project includes integration tests that use a mock API server to simulate the backend.

#### Running Integration Tests with Mock Server

1. **Start the mock server:**
   ```bash
   cd packages/mock_api_server && dart bin/server.dart
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
   cd packages/mock_api_server && dart bin/server.dart &
   flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```

3. **One-liner (recommended):**
   For the cleanest test run that ensures no stale servers are running:
   ```bash
   cd packages/mock_api_server && pkill -f "dart bin/server.dart" || true && echo "Mock server stopped. Now running the integration test:" && flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
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

For more details on the available API endpoints, check the mock server implementation in `packages/mock_api_server/bin/server.dart`.

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
1. Starts the mock API server on port 8080 (if not already running)
2. Runs the Flutter app using the dedicated development entry point (`flutter run -t lib/main_dev.dart`), which automatically configures the app for the mock server via runtime DI overrides.
3. Handles automatic cleanup on exit

> **Note:** When running the app with the mock server (via `main_dev.dart`), you can use any email/password combination for login, as the mock server accepts all credentials. The app will display a simulated user profile from the mock server.

For more details about the mock server, see `packages/mock_api_server/README.md`.

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

The app uses an `AppConfig` object (managed via Dependency Injection) to hold configuration values like API keys and domains. We primarily use **runtime DI overrides** for development and testing, and **compile-time definitions** (`--dart-define`) for release builds.

**Key Concepts:**

*   **`AppConfig`**: Contains different configurations (e.g., `development()`, `fromEnvironment()`).
*   **`main_dev.dart`**: Development entry point. Automatically uses `AppConfig.development()` (pointing to `localhost:8080` with `test-api-key`) via a runtime DI override. **This is the recommended way for local development/testing.**
*   **`main.dart`**: Standard entry point. Uses `AppConfig.fromEnvironment()`, which reads compile-time `--dart-define` variables. **Use this for release builds.**
*   **`--dart-define` / `--dart-define-from-file`**: Compile-time mechanism used primarily to inject secrets/config into **release builds** run via `main.dart`.

**Variables managed by `AppConfig`:**

*   `apiKey`: Your API key. (`test-api-key` in `development()`)
*   `apiDomain`: The domain/host for the API (e.g., `api.docjet.com` or `localhost:8080`). (`localhost:8080` in `development()`)

**API Versioning**:
We use a centralized approach to API versioning with `ApiConfig`. The version is specified in a single location and used consistently across the app. See [API Versioning](docs/current/architecture-api-versioning.md) for details.

**How to Run/Build:**

*   **Running Locally with Mock Server (Recommended):**
    Use the dedicated development entry point and the provided script. It handles starting the server and running the app configured for the mock server.
    ```bash
    # This script now simply runs: flutter run -t lib/main_dev.dart
    ./scripts/run_with_mock.sh
    ```
    The `main_dev.dart` entry point ensures the app connects to `http://localhost:8080/api/v1` using the test API key, without needing `--dart-define` or `secrets.json` for local runs.

*   **Running E2E Tests (Handled by `run_e2e_tests.sh`):**
    The E2E test script (`scripts/run_e2e_tests.sh`) likely still uses `--dart-define` or `--dart-define-from-file=secrets.test.json` for configuration, as E2E tests might require specific compile-time setup. Refer to the script itself and `secrets.test.json.example` for details.
    ```bash
    ./scripts/run_e2e_tests.sh
    ```
    Ensure you have copied `secrets.test.json.example` to `

## Audio Recording

### Platform Setup

#### iOS
- Add microphone usage description to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone to record audio.</string>
```

#### Android
- Add microphone permission to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```
- For Android < Q (API level 29), also add storage permissions:
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### File Path Normalization
The `record` package provides absolute file paths when recording is stopped. To ensure proper file handling within the app:

1. **Always convert absolute paths** to relative paths within the app's documents directory before passing to other components.
2. Use `FileSystem.resolvePath()` for all file operations to prevent path traversal issues.
3. Example conversion:
   ```dart
   // Convert absolute path to relative path within app documents directory
   String getRelativePath(String absolutePath) {
     final docsDir = getApplicationDocumentsDirectory().path;
     if (absolutePath.startsWith(docsDir)) {
       // Return path relative to docs directory WITHOUT leading slash
       // e.g., "recordings/audio_123.m4a" instead of "/recordings/audio_123.m4a"
       return absolutePath.substring(docsDir.length + 1); // +1 to remove leading slash
     }
     throw Exception('File is outside of app documents directory');
   }
   
   // When using the relative path with FileSystem:
   final String relativePath = getRelativePath(absoluteRecordingPath);
   // FileSystem.resolvePath() will properly handle this relative path format
   final String resolvedPath = FileSystem.resolvePath(relativePath);
   ```