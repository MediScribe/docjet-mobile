# Environment Configuration Guide

This document outlines how to configure the DocJet Mobile app for different environments.

## Environment Variables

The app uses the following environment variables:

| Variable     | Description                 | Default Value        |
| :----------- | :-------------------------- | :------------------- |
| `API_KEY`    | API key for authentication  | None (required)      |
| `API_DOMAIN` | Domain for API calls        | `staging.docjet.ai`  |

## Running with Different Configurations

### Using secrets.json (Recommended)

Create a `secrets.json` file at the project root with your environment variables:

```json
{
  "API_KEY": "your-api-key",
  "API_DOMAIN": "api.docjet.com"
}
```

Then run the app with:

```bash
flutter run --dart-define-from-file=secrets.json
```

### Using Direct Parameters

Alternatively, you can pass the parameters directly:

```bash
flutter run --dart-define=API_KEY=your-api-key --dart-define=API_DOMAIN=api.docjet.com
```

## Testing with Mock Server

For local testing with the mock server, use:

```bash
./scripts/run_with_mock.sh
```

This script:

1.  Starts the mock server on port 8080
2.  Uses `secrets.test.json` which contains:
    ```json
    {
      "API_KEY": "test-api-key",
      "API_DOMAIN": "localhost:8080"
    }
    ```
3.  Runs the app using these environment variables via `--dart-define-from-file`
4.  Cleans up when you exit

## How It Works

The app determines the API URL based on the provided domain:

*   For `localhost` or IP addresses: Uses `http://` protocol
*   For all other domains: Uses `https://` protocol
*   Automatically adds `/api/v1` to all URLs

For example:

*   `localhost:8080` → `http://localhost:8080/api/v1`
*   `api.docjet.com` → `https://api.docjet.com/api/v1`

## Important Notes

1.  **Compile-Time Variables**: `--dart-define` variables are **compile-time constants**. Changing them requires recompiling the app.
2.  **Runtime Configuration**: The app uses an `AppConfig` object, managed via dependency injection, to handle configuration at runtime. This allows for different configurations (e.g., development vs. production) without recompiling.
3.  **Dependency Injection**: For details on how configuration is managed and injected, see the [Explicit Dependency Injection Migration Guide](./explicit-di.md). That document contains the active implementation plan.

## Technical Implementation

- The `AppConfig` class manages all environment values:
  - `AppConfig.fromEnvironment()` reads values at compile time
  - `AppConfig.development()` provides development defaults
  - All values are exposed as immutable fields
- `ApiConfig.baseUrlFromDomain()` determines the appropriate protocol based on the domain
- Authentication endpoints use the configured domain for all requests
- `DioFactory` reads from the `AppConfig` singleton in the DI container

## Adding New Environment Variables

When adding new environment variables to the app:

1. Add the variable name as a constant in the AppConfig class
2. Add a default value to the factory methods
3. Update test doubles and mocks
4. Update this documentation with the new variable name and purpose

This approach ensures consistency and makes maintenance easier when new environment variables are added.

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

### 6. [❌] Update Mock Server Script (NOT DONE)

   a. [❌] **RED**: Test that the mock server script works correctly
   *Status*: Not started. Current script still uses `--dart-define-from-file`
   
   b. [❌] **GREEN**: Create improved mock server script
   *Status*: Not implemented. Should use `flutter run -t lib/main_dev.dart`
   
   c. [❌] **REFACTOR**: Add detailed comments explaining the approach
   *Status*: Not implemented

### 7. [❌] Complete DioFactory Refactoring to Full Explicit DI (NOT DONE)

   a. [❌] **RED**: Write tests for fully explicit DioFactory
   *Status*: Not started. Current implementation still uses static methods with service locator
   
   b. [❌] **GREEN**: Implement explicit constructor DioFactory
   *Status*: Not implemented. This is a priority for the next phase
   
   c. [❌] **REFACTOR**: Replace static methods with instance methods
   *Status*: Not implemented

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
5. ⚠️ **DioFactory Migration**: Partial (mock methods only, main code still uses service locator)
6. ❌ **Mock Server Script**: Not updated to use main_dev.dart
7. ❌ **Full Explicit DI**: Not implemented for most components

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
