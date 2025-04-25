# Environment Configuration Guide (Runtime DI Approach)

This document outlines how to configure the DocJet Mobile app for different environments using **runtime dependency injection overrides**. The previous method relying solely on compile-time `--dart-define` variables is **deprecated** for development and testing workflows.

## Core Concept: Runtime Configuration via `AppConfig` and DI

The app uses an `AppConfig` class to hold configuration values like API keys and domains. Instead of relying only on compile-time constants, we now primarily use Dependency Injection (DI) overrides to provide the correct `AppConfig` at **runtime**:

1.  **`AppConfig` Class**: Contains factory methods like `AppConfig.development()` (for local/mock server) and `AppConfig.fromEnvironment()` (reads compile-time `--dart-define` variables, primarily for **production builds**).
2.  **Entry Points**:
    *   `lib/main.dart`: Standard entry point. Uses `AppConfig.fromEnvironment()` by default. Intended for production builds where `--dart-define` might be used.
    *   `lib/main_dev.dart`: Development entry point. **Crucially**, this file adds a DI override *before* initializing the container (`di.init()`) to register `AppConfig.development()`.
3.  **DI Container (`injection_container.dart`)**:
    *   The `di.init()` function now applies any registered `di.overrides` **first**.
    *   It then registers `AppConfig.fromEnvironment()` **only if** an `AppConfig` instance hasn't already been registered by an override.
    *   Services like `DioFactory` fetch the currently registered `AppConfig` instance from the DI container (`sl<AppConfig>()`) at runtime.

This approach allows us to switch configurations easily for development and testing without recompiling.

## Environment Variables (via `AppConfig`)

The `AppConfig` object manages the following values:

| Variable     | Description                       | `development()` Value | `fromEnvironment()` Default | Notes                                     |
| :----------- | :-------------------------------- | :-------------------- | :-------------------------- | :---------------------------------------- |
| `apiKey`     | API key for authentication        | `test-api-key`        | `String.fromEnvironment('API_KEY')`    | Required for production via `--dart-define=API_KEY=...` |
| `apiDomain`  | Domain/Host for API calls         | `localhost:8080`      | `String.fromEnvironment('API_DOMAIN', defaultValue: 'staging.docjet.ai')` | Used to construct base URL             |
| `appName`    | Application Name                  | `DocJet Dev`          | `String.fromEnvironment('APP_NAME', defaultValue: 'DocJet')` | Display name                              |
| `appVersion` | Application Version             | `dev`                 | `String.fromEnvironment('APP_VERSION', defaultValue: '0.0.1')` | Build version info                        |

## Running with Different Configurations

### Development / Mock Server (Recommended Workflow)

Use the dedicated development entry point. This automatically configures the app to use `AppConfig.development()` values, pointing to `localhost:8080`.

```bash
# Run using the development entry point
flutter run -t lib/main_dev.dart
```

### Testing with Mock Server Script

For local testing with the integrated mock server, use the provided script:

```bash
./scripts/run_with_mock.sh
```

This script now simply:

1.  Starts the mock server (if not already running).
2.  Runs the app using the development entry point: `flutter run -t lib/main_dev.dart`.
3.  The `main_dev.dart` entry point ensures the `AppConfig.development()` override is used, connecting the app to the mock server at `http://localhost:8080/api/v1`.

*(The script no longer uses `secrets.test.json` or `--dart-define`)*.

### Production Builds (Using `--dart-define`)

For release builds targeting staging or production, use the standard `main.dart` entry point and provide configuration via `--dart-define`. The `AppConfig.fromEnvironment()` factory will read these compile-time values.

```bash
# Example for Staging (default domain)
flutter build apk --release --dart-define=API_KEY=your-staging-key 
# flutter run --dart-define=API_KEY=your-staging-key # (if running locally)

# Example for Production
flutter build apk --release --dart-define=API_KEY=your-prod-key --dart-define=API_DOMAIN=api.docjet.com
# flutter run --dart-define=API_KEY=your-prod-key --dart-define=API_DOMAIN=api.docjet.com # (if running locally)
```

You can also use `--dart-define-from-file=secrets.json` for production builds if preferred, ensuring `secrets.json` contains the required production `API_KEY` and `API_DOMAIN`.

## How It Works (URL Construction)

The app determines the API base URL based on the `apiDomain` value provided by the **runtime** `AppConfig` instance fetched from DI:

*   If `apiDomain` is `localhost` or an IP address: Uses `http://` protocol.
*   For all other domains: Uses `https://` protocol.
*   Automatically adds `/api/v1` to the constructed URL.

**Examples (Runtime Result):**

*   Running via `main_dev.dart`: `AppConfig.development().apiDomain` is `localhost:8080` → `http://localhost:8080/api/v1`
*   Running `main.dart` with `--dart-define=API_DOMAIN=api.docjet.com`: `AppConfig.fromEnvironment().apiDomain` is `api.docjet.com` → `https://api.docjet.com/api/v1`

## Important Notes & Technical Implementation

1.  **Runtime Configuration is Key**: The primary way to configure the app for different environments (dev, test, prod) is now through selecting the entry point (`main.dart` vs `main_dev.dart`) and potentially using DI overrides (`di.addOverride`).
2.  **`--dart-define` for Production**: Use `--dart-define` primarily for injecting production secrets/URLs into release builds using the standard `main.dart` entry point.
3.  **`AppConfig` via DI**: Services like `DioFactory` **must** get the `AppConfig` instance from the DI container (`sl<AppConfig>()`) to ensure they use the correct runtime configuration. They should **not** call `AppConfig.fromEnvironment()` directly.
4.  **DI Overrides**: The `di.addOverride()` mechanism allows tests and `main_dev.dart` to register specific `AppConfig` instances *before* `di.init()` runs, taking precedence over the default `AppConfig.fromEnvironment()`.
5.  **Dependency Injection Details**: For the full DI implementation, refer to the [Explicit Dependency Injection Migration Guide](./explicit-di-revisited.md).

## Adding New Configuration Variables

1.  Add the variable to the `AppConfig` class fields.
2.  Add a corresponding parameter to the `AppConfig` constructor.
3.  Provide a default value in `AppConfig.development()`.
4.  Add reading logic (e.g., `String.fromEnvironment`) in `AppConfig.fromEnvironment()`.
5.  Update test doubles and mocks.
6.  Update this documentation table.

--- 

# DocJet Mobile Environment Configuration - Implementation Status

## Critical Misunderstanding in Current Implementation

The current approach to environment configuration has a fundamental flaw: **`String.fromEnvironment()` values are resolved at compile-time, not runtime**. 

When you call `flutter run --dart-define=API_DOMAIN=localhost:8080`, this only affects newly compiled code, not an existing build. The current implementation incorrectly assumes these values can be changed at startup time.

## Implementation Status Legend

The following symbols are used throughout this document to track implementation progress:

| Symbol | Status | Description |
|:------:|:-------|:------------|
| ✓ / ✅ | **COMPLETE** | Task is fully implemented and tested |
| ⚠️ | **PARTIAL** | Task is partially implemented (see notes for details) |
| ❌ | **NOT STARTED** | Task has not been started yet |

## Implementation Plan - TDD Approach

### 1. [✓] Fix URL Construction Bug
   
   a. [✓] **RED**: Write a failing test for ApiConfig URL construction
   *Findings*: Added the test, but it passed immediately. The assumption of a double-slash bug was incorrect; the existing code correctly constructs URLs without double slashes.
   
   b. [✓] **GREEN**: Fix the implementation by removing trailing slash
   *Findings*: No fix needed as the implementation was already correct.
   
   c. [✓] **REFACTOR**: Run all ApiConfig tests to verify no regressions
   *Findings*: Ran the specific test which passed. No changes were made.

### 2. [✓] Create AppConfig Class

   a. [✓] **RED**: Write a failing test for AppConfig
   *Findings*: Created `test/core/config/app_config_test.dart`. Initial test failed due to missing class.

   b. [✓] **GREEN**: Implement AppConfig class
   *Findings*: Created `lib/core/config/app_config.dart` with basic implementation. Initial test passed.

   c. [✓] **REFACTOR**: Add toString and isDevelopment helper methods
   *Findings*: Added `toString()` and `isDevelopment` getter. All tests in `app_config_test.dart` pass.

### 3. [✓] Integrate with Dependency Injection

   a. [✓] **RED**: Write test for DI container registration
   *Findings*: Tests were failing because calling `Hive.initFlutter()` in `di.init()` was clearing all GetIt registrations.

   b. [✓] **GREEN**: Add registration to injection_container.dart
   *Findings*: Fixed the registration order so AppConfig is registered after Hive initialization.

   c. [✓] **REFACTOR**: Ensure singleton is registered early in startup process
   *Findings*: Added logging to verify AppConfig remains registered throughout initialization.

### 4. [✓] Refactor DioFactory to Use AppConfig

   a. [✓] **RED**: Write test for DioFactory using AppConfig
   *Findings*: Added test using `AppConfig.test()`. Test fails as expected because `DioFactory` still uses `String.fromEnvironment`.

   b. [✓] **GREEN**: Update DioFactory implementation
   *Findings*: Updated `createBasicDio` and `createAuthenticatedDio` to fetch `AppConfig` using `sl<AppConfig>()`. Tests pass.

   c. [✓] **REFACTOR**: Remove all direct String.fromEnvironment calls in DioFactory
   *Findings*: Confirmed all direct `String.fromEnvironment` calls were removed.

### 5. [✓] Create Development Entry Point (main_dev.dart)

   a. [✓] **RED**: Write test for development mode
   *Findings*: Added integration test `integration_test/app_test.dart`. Test confirms `di.init()` doesn't apply overrides.

   b. [✓] **GREEN**: Create main_dev.dart entry point
   *Findings*: Created `lib/main_dev.dart` that sets `di.overrides` to register `AppConfig.development()`.

   c. [✓] **REFACTOR**: Update `injection_container.dart` to support DI overrides
   *Findings*: Modified `di.init()` to apply registered overrides at the beginning of initialization.

### 6. [✓] Update Mock Server Script

   a. [✓] **RED**: Test that the mock server script works correctly
   *Status*: Implicitly tested by running the script; main test is ensuring app connects using dev config.
   *Findings*: Original script ran but used incorrect mechanism (`--dart-define`).
   
   b. [✓] **GREEN**: Create improved mock server script
   *Status*: Completed.
   *How*: Modified `scripts/run_with_mock.sh` to use `flutter run -t lib/main_dev.dart` instead of `--dart-define-from-file=secrets.test.json`.
   *Findings*: Script now correctly uses the development entry point and DI overrides, aligning with the `AppConfig` strategy.
   
   c. [✓] **REFACTOR**: Add detailed comments explaining the approach
   *Status*: Completed.
   *How*: Reviewed script comments and updated echo messages.
   *Findings*: Comments are sufficient to explain the process.

### 7. [✓] Complete DioFactory Refactoring to Full Explicit DI (NOT DONE)

   a. [✓] **RED**: Write tests for fully explicit DioFactory
     *Status*: Not started. Current implementation still uses static methods with service locator
   
   b. [✓] **GREEN**: Implement explicit constructor DioFactory
     *Status*: Not implemented. This is a priority for the next phase
   
   c. [✓] **REFACTOR**: Replace static methods with instance methods
     *Status*: Not implemented
     *Findings*: DioFactory refactoring is complete. It now uses explicit constructor injection (`AppConfigInterface`) and instance methods, serving as the pattern for other modules. See `docs/current/explicit-di-revisited.md`.

### 8. [❌] Update Documentation (BEING DONE NOW)

   a. [✓] **RED**: Review existing docs for accuracy
   *Findings*: Found documentation inaccuracies claiming more work was completed than actual code shows
   
   b. [❌] **GREEN**: Update environment configuration guide
   *Status*: Being done now. Will reflect actual implementation state
   
   c. [❌] **REFACTOR**: Ensure all documentation is consistent
   *Status*: In progress

### 9. [❌] IDE Integration (NOT DONE)

   a. [❌] **RED**: Check if IDE launch configurations work
   *Status*: Not started
   
   b. [❌] **GREEN**: Create launch configurations for VSCode and/or Android Studio
   *Status*: Not implemented
   
   c. [❌] **REFACTOR**: Add Android Studio run configurations
   *Status*: Not implemented

## Current Implementation Status

1. ✅ **AppConfig Class**: Implemented and working with tests
2. ✅ **Dependency Injection Overrides**: Working with tests
3. ✅ **Hive Initialization Fix**: Implemented and working
4. ✅ **Development Entry Point**: main_dev.dart exists and works
5. ✅ **DioFactory Migration**: Complete (Instance-based, uses explicit constructor injection)
6. ✓ **Mock Server Script**: Updated to use main_dev.dart
7. ⚠️ **Full Explicit DI**: Partial (DioFactory, CoreModule, JobsModule, AuthModule done. Other components may still use sl indirectly or need refactoring).

## Priority Next Steps

1. **Update Mock Server Script**: 
   - Modify `scripts/run_with_mock.sh` to use `flutter run -t lib/main_dev.dart`
   - This is a simple win that takes advantage of work already done

2. **Implement Class-Based DioFactory**:
   - Replace static methods with instance methods
   - Add constructor that takes AppConfig directly
   - Remove all service locator usage

3. **Update Auth Module**:
   - Update to use the new class-based DioFactory 
   - Implement proper dependency injection
