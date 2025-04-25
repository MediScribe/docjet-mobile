# Environment Configuration Guide

This document outlines how to configure the DocJet Mobile app for different environments.

## Environment Variables

The app uses the following environment variables:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `API_KEY` | API key for authentication | None (required) |
| `API_DOMAIN` | Domain for API calls | `staging.docjet.ai` |

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
1. Starts the mock server on port 8080
2. Uses `secrets.test.json` which contains:
   ```json
   {
     "API_KEY": "test-api-key",
     "API_DOMAIN": "localhost:8080"
   }
   ```
3. Automatically connects the app to the mock server
4. Cleans up when you exit

## How It Works

The app determines the API URL based on the provided domain:

- For `localhost` or IP addresses: Uses `http://` protocol
- For all other domains: Uses `https://` protocol
- Automatically adds `/api/v1` to all URLs

For example:
- `localhost:8080` → `http://localhost:8080/api/v1`
- `api.docjet.com` → `https://api.docjet.com/api/v1`

## Technical Implementation

- The `DioFactory` reads environment variables using a centralized approach:
  - A `_environmentDefaults` map contains all default values in one place
  - The `getEnvironmentValue` method provides consistent access with proper fallbacks
  - Environment values can be overridden for testing via an optional map parameter
- `ApiConfig.baseUrlFromDomain()` determines the appropriate protocol based on the domain
- Authentication endpoints use the configured domain for all requests

## Adding New Environment Variables

When adding new environment variables to the app:

1. Add the variable name as a constant in the appropriate class (e.g., `DioFactory._newVarKey`)
2. Add a default value to the `_environmentDefaults` map in that class
3. Use `getEnvironmentValue` to retrieve the value
4. Update this documentation with the new variable name and purpose

This approach ensures consistency and makes maintenance easier when new environment variables are added. 



# DocJet Mobile Environment Configuration - Corrected Guide

## Critical Misunderstanding in Current Implementation

The current approach to environment configuration has a fundamental flaw: **`String.fromEnvironment()` values are resolved at compile-time, not runtime**. 

When you call `flutter run --dart-define=API_DOMAIN=localhost:8080`, this only affects newly compiled code, not an existing build. The current implementation incorrectly assumes these values can be changed at startup time.

## Implementation Plan - TDD Approach

### 1. [x] Fix URL Construction Bug
   
   a. [x] **RED**: Write a failing test for ApiConfig URL construction
   ```dart
   test('ApiConfig constructs URLs without double slashes', () {
     expect(ApiConfig.fullLoginEndpoint('staging.docjet.ai'),
         'https://staging.docjet.ai/api/v1/auth/login'); // Should not have double slash
   });
   ```
   *Findings*: Added the test, but it passed immediately. The assumption of a double-slash bug was incorrect; the existing code correctly constructs URLs without double slashes. **Verified again: Code in `lib/core/config/api_config.dart` and tests in `test/core/config/api_config_test.dart` confirm no double slashes or missing slashes in standard URL construction.**
   
   b. [x] **GREEN**: Fix the implementation by removing trailing slash
   *Findings*: No fix needed as the implementation was already correct.
   
   c. [x] **REFACTOR**: Run all ApiConfig tests to verify no regressions
   *Findings*: Ran the specific test (`ApiConfig constructs URLs without double slashes`) which passed. No other changes were made, so no further regression testing needed for this specific (non-existent) bug.

### 2. [x] Create AppConfig Class

   a. [x] **RED**: Write a failing test for AppConfig
   ```dart
   test('AppConfig correctly loads environment values', () {
     // Test now checks default values
     final config = AppConfig.fromEnvironment();
     expect(config.apiDomain, 'staging.docjet.ai'); 
     expect(config.apiKey, ''); 
   });
   ```
   *Findings*: Created `test/core/config/app_config_test.dart`. Initial test failed due to missing class.

   b. [x] **GREEN**: Implement AppConfig class
   ```dart
   // lib/core/config/app_config.dart
   class AppConfig {
     final String apiDomain;
     final String apiKey;
     
     const AppConfig._({required this.apiDomain, required this.apiKey});
     
     factory AppConfig.fromEnvironment() {
       return AppConfig._(
         apiDomain: String.fromEnvironment('API_DOMAIN', defaultValue: 'staging.docjet.ai'),
         apiKey: String.fromEnvironment('API_KEY', defaultValue: ''),
       );
     }
     
     factory AppConfig.development() {
       return const AppConfig._(
         apiDomain: 'localhost:8080',
         apiKey: 'test-api-key',
       );
     }
   }
   ```
   *Findings*: Created `lib/core/config/app_config.dart` with basic implementation. Initial test passed.

   c. [x] **REFACTOR**: Add toString and isDevelopment helper methods
   *Findings*: Added `toString()` (redacting key) and `isDevelopment` getter. Added tests for `development()` factory, `isDevelopment`, and `toString()`. All tests in `app_config_test.dart` pass.

### 3. [ ] Integrate with Dependency Injection

   a. [ ] **RED**: Write test for DI container registration
   ```dart
   test('AppConfig can be registered and retrieved from DI container', () {
     // Setup test container
     final container = GetIt.instance;
     container.registerSingleton<AppConfig>(AppConfig.fromEnvironment());
     
     // Verify retrieval
     final config = container.get<AppConfig>();
     expect(config, isA<AppConfig>());
   });
   ```
   
   b. [ ] **GREEN**: Add registration to injection_container.dart
   ```dart
   // In injection_container.dart
   
   // Add this to the init() method
   sl.registerSingleton<AppConfig>(() {
     // Check if we're in development mode
     const inDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);
     
     // Choose appropriate configuration
     final config = inDevMode ? AppConfig.development() : AppConfig.fromEnvironment();
     
     // Log the configuration for debugging
     print('Initialized AppConfig: ${config.toString()}');
     return config;
   }());
   ```
   
   c. [ ] **REFACTOR**: Ensure singleton is registered early in startup process

### 4. [ ] Refactor DioFactory to Use AppConfig

   a. [ ] **RED**: Write test for DioFactory using AppConfig
   ```dart
   test('DioFactory uses AppConfig for domain configuration', () {
     // Setup
     final mockConfig = AppConfig._(apiDomain: 'test.example.com', apiKey: 'test-key');
     final container = GetIt.instance;
     container.registerSingleton<AppConfig>(mockConfig);
     
     // Test
     final dio = DioFactory.createBasicDio();
     expect(dio.options.baseUrl, contains('test.example.com'));
   });
   ```
   
   b. [ ] **GREEN**: Update DioFactory implementation
   ```dart
   static Dio createBasicDio({Map<String, String>? environment}) {
     // Use AppConfig from DI container instead of direct environment access
     final appConfig = sl<AppConfig>();
     final baseUrl = ApiConfig.baseUrlFromDomain(appConfig.apiDomain);
     _logger.i('Creating Dio with domain: ${appConfig.apiDomain} -> $baseUrl');
     
     // Rest of implementation remains the same
     // ...
   }
   
   // Similar update for createAuthenticatedDio to use appConfig.apiKey
   ```
   
   c. [ ] **REFACTOR**: Remove all direct String.fromEnvironment calls in DioFactory

### 5. [ ] Create Development Entry Point

   a. [ ] **RED**: Write test for development mode
   ```dart
   test('App can be configured for development mode', () {
     // This would be an integration test that verifies
     // the development app connects to localhost
   });
   ```
   
   b. [ ] **GREEN**: Create main_dev.dart entry point
   ```dart
   // lib/main_dev.dart
   import 'package:flutter/foundation.dart';
   import 'package:docjet_mobile/core/di/injection_container.dart' as di;
   import 'package:docjet_mobile/core/config/app_config.dart';
   import 'package:docjet_mobile/main.dart' as app;
   
   void main() {
     // Override DI registration for AppConfig
     di.overrides = [
       () {
         di.sl.registerSingleton<AppConfig>(AppConfig.development());
         if (kDebugMode) {
           print('Running in DEVELOPMENT mode with mock server configuration');
         }
       }
     ];
     
     // Start the app with overrides
     app.main();
   }
   ```
   
   c. [ ] **REFACTOR**: Update main.dart to support DI overrides

### 6. [ ] Update Mock Server Script

   a. [ ] **RED**: Test that the mock server script works correctly
   
   b. [ ] **GREEN**: Create improved mock server script
   ```bash
   #!/bin/bash
   # scripts/run_with_mock_improved.sh
   
   echo "========================================================"
   echo "NOTICE: Using development build for mock server testing"
   echo "This uses the main_dev.dart entry point with localhost:8080"
   echo "========================================================"
   
   # Start the mock server (similar to before)
   # ...server startup code...
   
   # Run the app using the development entry point
   flutter run -t lib/main_dev.dart
   
   # Clean up on exit
   # ...cleanup code...
   ```
   
   c. [ ] **REFACTOR**: Add detailed comments explaining the approach

### 7. [ ] Update Documentation

   a. [ ] **RED**: Review existing docs for accuracy
   
   b. [ ] **GREEN**: Update environment configuration guide
   ```markdown
   # Environment Configuration Guide (REVISED)
   
   ## Critical Note About Environment Variables
   
   Flutter/Dart environment variables set with `--dart-define` are **compile-time constants**, 
   not runtime values. Any changes to these values require recompiling the app.
   
   ## Recommended Approach
   
   ### For Production/Staging
   Compile with environment variables:
   ```bash
   flutter build --dart-define=API_DOMAIN=api.docjet.com --dart-define=API_KEY=your-key
   ```
   
   ### For Local Development with Mock Server
   Use the development entry point:
   ```bash
   flutter run -t lib/main_dev.dart
   ```
   
   OR use the script:
   ```bash
   ./scripts/run_with_mock_improved.sh
   ```
   ```
   
   c. [ ] **REFACTOR**: Ensure all documentation is consistent and accurate

### 8. [ ] IDE Integration

   a. [ ] **RED**: Check if IDE launch configurations work
   
   b. [ ] **GREEN**: Create launch configurations
   ```json
   // .vscode/launch.json
   {
     "configurations": [
       {
         "name": "DocJet - Production",
         "request": "launch",
         "type": "dart",
         "program": "lib/main.dart",
         "args": [
           "--dart-define=API_DOMAIN=api.docjet.com",
           "--dart-define=API_KEY=your-production-key"
         ]
       },
       {
         "name": "DocJet - Development with Mock",
         "request": "launch",
         "type": "dart",
         "program": "lib/main_dev.dart"
       }
     ]
   }
   ```
   
   c. [ ] **REFACTOR**: Add Android Studio run configurations if needed

## Execution Order

1. Start with the URL construction fix (Task 1) - this is a simple, isolated change
2. Create the AppConfig class (Task 2) - this is the foundation for the new approach
3. Integrate with DI (Task 3) and refactor DioFactory (Task 4) - these together implement the core solution
4. Create the development entry point (Task 5) - this enables easy local development
5. Update the mock server script (Task 6) - this simplifies the dev workflow
6. Update documentation (Task 7) and IDE integration (Task 8) - these improve developer experience

Each task follows TDD principles: write a failing test, implement the minimum code to make it pass, then refactor for cleanliness and maintainability.
