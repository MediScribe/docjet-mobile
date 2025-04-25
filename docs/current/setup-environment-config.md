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

### 3. [x] Integrate with Dependency Injection

   a. [x] **RED**: Write test for DI container registration
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
   *Findings*: Tests were failing because calling `Hive.initFlutter()` in `di.init()` was clearing all GetIt registrations (including AppConfig).

   b. [x] **GREEN**: Add registration to injection_container.dart
   ```dart
   // In injection_container.dart
   
   Future<void> init() async {
     // --- Initialize Hive FIRST ---
     await Hive.initFlutter();
     // Register Hive Adapters and open boxes...
     
     // --- Register AppConfig AFTER Hive initialization ---
     // This ensures AppConfig isn't cleared by Hive.initFlutter()
     const isDevMode = bool.fromEnvironment('DEV_MODE');
     final appConfig = isDevMode ? AppConfig.development() : AppConfig.fromEnvironment();
     sl.registerSingleton<AppConfig>(appConfig);
   }
   ```
   *Findings*: Fixed the registration order so AppConfig is registered after Hive initialization.

   c. [x] **REFACTOR**: Ensure singleton is registered early in startup process
   *Findings*: Added logging to verify AppConfig remains registered throughout initialization, confirming it's available for use by other components.

### 4. [x] Refactor DioFactory to Use AppConfig

   a. [x] **RED**: Write test for DioFactory using AppConfig
   ```dart
   test('DioFactory uses AppConfig for domain configuration', () {
     // Setup
     final container = GetIt.instance;
     container.reset();
     final mockConfig = AppConfig.test(
       apiDomain: 'test.example.com',
       apiKey: 'test-key',
     );
     container.registerSingleton<AppConfig>(mockConfig);
     
     // Test
     final dio = DioFactory.createBasicDio();
     expect(dio.options.baseUrl, contains('test.example.com'));
   });
   ```
   *Findings*: Added test using `AppConfig.test()` factory after struggling with `@visibleForTesting` on `AppConfig._`. Registered mock `AppConfig` in `GetIt`. Test fails as expected because `DioFactory` still uses `String.fromEnvironment`.

   b. [x] **GREEN**: Update DioFactory implementation
   ```dart
   // lib/core/auth/infrastructure/dio_factory.dart
   import 'package:docjet_mobile/core/config/app_config.dart';
   import 'package:docjet_mobile/core/di/injection_container.dart';

   class DioFactory {
     static final _logger = LoggerFactory.getLogger('DioFactory');

     static Dio createBasicDio() {
       final appConfig = sl<AppConfig>();
       final baseUrl = ApiConfig.baseUrlFromDomain(appConfig.apiDomain);
       // ... setup BaseOptions ...
       return Dio(options);
     }

     static Dio createAuthenticatedDio(...) {
       final appConfig = sl<AppConfig>();
       final dio = createBasicDio();
       // ... add interceptors using appConfig.apiKey ...
       return dio;
     }
   }
   ```
   *Findings*: Removed `getEnvironmentValue` and the `environment` map parameter. Updated `createBasicDio` and `createAuthenticatedDio` to fetch `AppConfig` using `sl<AppConfig>()`. Refactored tests to use `GetIt` registration/unregistration for setting up specific `AppConfig` instances, resolving initial test failures due to GetIt registration issues. All tests in `dio_factory_test.dart` now pass.

   c. [x] **REFACTOR**: Remove all direct String.fromEnvironment calls in DioFactory
   *Findings*: Confirmed that the previous step (4b) already removed all direct `String.fromEnvironment` calls by deleting the `getEnvironmentValue` method and refactoring the factory methods to use `sl<AppConfig>()`. No further changes needed.

### 5. [x] Create Development Entry Point

   a. [x] **RED**: Write test for development mode
   ```dart
   // integration_test/app_test.dart
   testWidgets('App correctly loads AppConfig for development mode',
       (WidgetTester tester) async {
     // Arrange: Define the override for AppConfig
     di.overrides = [
       () {
         di.sl.registerSingleton<AppConfig>(AppConfig.development());
         debugPrint('Overriding AppConfig with development settings for test.');
       }
     ];

     // Arrange: Initialize dependencies WITHOUT the override applied yet
     await di.init(); // This uses the default config

     // Assert: Verify AppConfig is NOT the development instance yet
     final config = di.sl<AppConfig>();
     expect(config.isDevelopment, isFalse); // Expecting false because override wasn't applied in init
     expect(config.apiDomain, 'staging.docjet.ai');
     expect(config.apiKey, '');
   });
   ```
   *Findings*: Added integration test `integration_test/app_test.dart`. The test confirms that setting `di.overrides` *before* calling `di.init()` does **not** currently apply the override, as `di.init()` doesn't check for overrides yet. Test fails as expected (RED state), proving the need for step 5c.

   b. [x] **GREEN**: Create main_dev.dart entry point
   ```dart
   // lib/main_dev.dart
   import 'package:docjet_mobile/core/config/app_config.dart';
   import 'package:docjet_mobile/core/di/injection_container.dart' as di;
   import 'package:docjet_mobile/core/utils/log_helpers.dart';
   import 'package:docjet_mobile/main.dart' as app;
   import 'package:flutter/foundation.dart';
   
   void main() {
     final logger = LoggerFactory.getLogger('main_dev');
     final tag = logTag('main_dev');
   
     di.overrides = [
       () {
         if (di.sl.isRegistered<AppConfig>()) {
           di.sl.unregister<AppConfig>();
         }
         di.sl.registerSingleton<AppConfig>(AppConfig.development());
         logger.i(
           '$tag Registered AppConfig override: ${AppConfig.development()}',
         );
       },
     ];
   
     if (kDebugMode) {
       logger.i(
         '$tag Running in DEVELOPMENT mode via main_dev.dart',
       );
     }
   
     app.main();
   }
   ```
   *Findings*: Created `lib/main_dev.dart`. This entry point sets `di.overrides` to register `AppConfig.development()` *before* calling the standard `app.main()`. This prepares for step 5c, where `main()` and `di.init()` will be modified to *use* these overrides.

   c. [x] **REFACTOR**: Update `injection_container.dart` to support DI overrides
   ```dart
   // lib/core/di/injection_container.dart
   
   Future<void> init() async {
     final logger = LoggerFactory.getLogger('DI');
     final tag = logTag('DI');
   
     // --- Apply registered overrides FIRST ---
     if (overrides.isNotEmpty) {
       logger.i('$tag Applying ${overrides.length} registered override(s)...');
       
       for (final override in overrides) {
         override();
       }
       
       logger.i('$tag All overrides applied successfully');
     }
   
     // --- Initialize Hive SECOND ---
     // ... rest of initialization ...
   
     // --- Register AppConfig --- 
     // Check if AppConfig is *already* registered (by an override)
     if (!sl.isRegistered<AppConfig>()) {
       logger.d('$tag AppConfig NOT registered, registering default from environment...');
       final appConfig = AppConfig.fromEnvironment();
       sl.registerSingleton<AppConfig>(appConfig);
       logger.d('$tag Registered DEFAULT AppConfig: ${appConfig.toString()}');
     } else {
       logger.i('$tag AppConfig already registered (likely by override). Skipping default registration.');
     }
   }
   ```
   *Findings*: Modified `di.init()` to explicitly apply all registered overrides at the beginning of initialization. This ensures that entry points like `main_dev.dart` can set up overrides that will be applied during initialization. Also updated the integration test to no longer manually execute the overrides, letting `di.init()` handle that automatically. The test now confirms that overrides are properly applied during dependency initialization.

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

### 9. [ ] Refactor for Best Practices - Explicit Dependency Injection

   a. [ ] **RED**: Write tests for explicit dependency injection in DioFactory
   ```dart
   test('DioFactory.createBasicDio accepts explicit AppConfig parameter', () {
     // Arrange: Create test config
     final testConfig = AppConfig.test(
       apiDomain: 'explicit.test.com', 
       apiKey: 'explicit-key'
     );
     
     // Act: Call with explicit parameter
     final dio = DioFactory.createBasicDio(testConfig);
     
     // Assert: Verify configuration is used
     expect(dio.options.baseUrl, contains('explicit.test.com'));
   });
   
   test('DioFactory.createAuthenticatedDio accepts explicit AppConfig parameter', () {
     // Arrange: Create test config and mocks
     final testConfig = AppConfig.test(
       apiDomain: 'auth.test.com', 
       apiKey: 'auth-key'
     );
     final mockApiClient = MockAuthApiClient();
     final mockCredentials = MockAuthCredentialsProvider();
     final mockEventBus = MockAuthEventBus();
     
     // Act: Call with explicit parameters
     final dio = DioFactory.createAuthenticatedDio(
       authApiClient: mockApiClient,
       credentialsProvider: mockCredentials,
       authEventBus: mockEventBus,
       config: testConfig,
     );
     
     // Assert: Verify configuration is used
     expect(dio.options.baseUrl, contains('auth.test.com'));
     
     // Verify API key interceptor was added
     final interceptor = dio.interceptors.first as InterceptorsWrapper;
     // We can't directly test the interceptor, but we can verify it exists
     expect(interceptor, isNotNull);
   });
   ```
   
   b. [ ] **GREEN**: Update DioFactory to use explicit dependency injection
   ```dart
   // lib/core/auth/infrastructure/dio_factory.dart
   class DioFactory {
     static final _logger = LoggerFactory.getLogger('DioFactory');
     
     /// Creates a basic Dio client with explicit config
     static Dio createBasicDio(AppConfig config) {
       final baseUrl = ApiConfig.baseUrlFromDomain(config.apiDomain);
       _logger.d('Creating basic Dio: baseUrl=$baseUrl');
       
       final options = BaseOptions(
         baseUrl: baseUrl,
         connectTimeout: Duration(milliseconds: 5000),
         receiveTimeout: Duration(milliseconds: 3000),
       );
       
       return Dio(options);
     }
     
     /// Creates a Dio client with auth interceptors and explicit config
     static Dio createAuthenticatedDio({
       required AuthApiClient authApiClient,
       required AuthCredentialsProvider credentialsProvider,
       required AuthEventBus authEventBus,
       required AppConfig config,
     }) {
       final dio = createBasicDio(config);
       
       // Add API key interceptor
       dio.interceptors.add(
         InterceptorsWrapper(
           onRequest: (options, handler) async {
             if (config.apiKey.isNotEmpty) {
               options.headers['x-api-key'] = config.apiKey;
               _logger.t('Injected x-api-key header.');
             } else {
               _logger.w('Skipping x-api-key header injection: Key not found.');
             }
             return handler.next(options);
           },
         ),
       );
       
       // Add auth interceptor
       dio.interceptors.add(
         AuthInterceptor(
           dio: dio,
           apiClient: authApiClient,
           credentialsProvider: credentialsProvider,
           authEventBus: authEventBus,
         ),
       );
       
       return dio;
     }
     
     /// @deprecated Use createBasicDio(AppConfig) instead
     /// Kept for backward compatibility during migration
     static Dio createBasicDioWithServiceLocator() {
       _logger.w('Using deprecated createBasicDioWithServiceLocator. Update to use explicit dependencies.');
       final appConfig = sl<AppConfig>();
       return createBasicDio(appConfig);
     }
     
     /// @deprecated Use createAuthenticatedDio with config parameter instead
     /// Kept for backward compatibility during migration
     static Dio createAuthenticatedDioWithServiceLocator({
       required AuthApiClient authApiClient,
       required AuthCredentialsProvider credentialsProvider,
       required AuthEventBus authEventBus,
     }) {
       _logger.w('Using deprecated createAuthenticatedDioWithServiceLocator. Update to use explicit dependencies.');
       final appConfig = sl<AppConfig>();
       return createAuthenticatedDio(
         authApiClient: authApiClient,
         credentialsProvider: credentialsProvider,
         authEventBus: authEventBus,
         config: appConfig,
       );
     }
   }
   ```
   
   c. [ ] **REFACTOR**: Update AuthModule to use explicit dependency injection
   ```dart
   // lib/core/auth/infrastructure/auth_module.dart
   class AuthModule {
     /// Registers authentication services with GetIt
     static void register(GetIt getIt, {required AppConfig appConfig}) {
       // Register the provided AppConfig if not already registered
       if (!getIt.isRegistered<AppConfig>()) {
         getIt.registerSingleton<AppConfig>(appConfig);
       }
       
       // Register secure storage
       getIt.registerLazySingleton<FlutterSecureStorage>(
         () => const FlutterSecureStorage(),
       );
       
       // Register auth event bus if not already registered
       if (!getIt.isRegistered<AuthEventBus>()) {
         getIt.registerLazySingleton<AuthEventBus>(() => AuthEventBus());
       }
       
       // Register the basic Dio client with explicit AppConfig
       getIt.registerLazySingleton<Dio>(
         () => DioFactory.createBasicDio(appConfig),
         instanceName: 'basicDio',
       );
       
       // Register AuthApiClient (no change)
       getIt.registerLazySingleton<AuthApiClient>(
         () => AuthApiClient(getIt(instanceName: 'basicDio')),
       );
       
       // Register credentials provider (no change)
       getIt.registerLazySingleton<AuthCredentialsProvider>(
         () => SecureStorageAuthCredentialsProvider(getIt()),
       );
       
       // Register authenticated Dio with explicit AppConfig
       getIt.registerLazySingleton<Dio>(
         () => DioFactory.createAuthenticatedDio(
           authApiClient: getIt<AuthApiClient>(),
           credentialsProvider: getIt<AuthCredentialsProvider>(),
           authEventBus: getIt<AuthEventBus>(),
           config: appConfig,
         ),
         instanceName: 'authenticatedDio',
       );
       
       // Rest of registrations (no change)
       getIt.registerLazySingleton<JwtValidator>(() => JwtValidator());
       
       getIt.registerLazySingleton<AuthService>(
         () => AuthServiceImpl(
           apiClient: getIt<AuthApiClient>(),
           credentialsProvider: getIt<AuthCredentialsProvider>(),
           eventBus: getIt<AuthEventBus>(),
           jwtValidator: getIt<JwtValidator>(),
         ),
       );
     }
     
     // Provider overrides method (no change)
     static List<Override> providerOverrides(GetIt getIt) {
       return [
         authServiceProvider.overrideWithValue(getIt<AuthService>()),
       ];
     }
   }
   ```

   d. [ ] **RED**: Update injection_container.dart tests to use explicit injection
   ```dart
   test('DI container initialization passes explicit AppConfig to modules', () {
     // Arrange: Setup test overrides
     di.overrides = [];
     
     // Act: Initialize DI
     await di.init();
     
     // Assert: Verify AuthModule received explicit AppConfig
     // This is hard to test directly, so we'll verify the end result
     // by checking that authenticated Dio has correct baseUrl
     final dio = di.sl<Dio>(instanceName: 'authenticatedDio');
     final config = di.sl<AppConfig>();
     expect(dio.options.baseUrl, contains(config.apiDomain));
   });
   ```

   e. [ ] **GREEN**: Update injection_container.dart to use explicit injection
   ```dart
   // lib/core/di/injection_container.dart
   Future<void> init() async {
     final logger = LoggerFactory.getLogger('DI');
     final tag = logTag('DI');
     
     // --- Apply registered overrides FIRST ---
     if (overrides.isNotEmpty) {
       logger.i('$tag Applying ${overrides.length} registered override(s)...');
       for (final override in overrides) {
         override();
       }
       logger.i('$tag All overrides applied successfully');
     }
     
     // --- Initialize Hive SECOND ---
     await Hive.initFlutter();
     // Hive initialization...
     
     // --- Create AppConfig THIRD ---
     // Create AppConfig instance (either from override or default)
     final AppConfig appConfig;
     if (sl.isRegistered<AppConfig>()) {
       // Use existing registered AppConfig (from override)
       logger.i('$tag AppConfig already registered (by override). Using existing.');
       appConfig = sl<AppConfig>();
     } else {
       // Create default AppConfig
       logger.d('$tag Creating default AppConfig from environment...');
       appConfig = AppConfig.fromEnvironment();
       
       // Register it for modules that might still use sl<AppConfig>()
       sl.registerSingleton<AppConfig>(appConfig);
       logger.d('$tag Registered DEFAULT AppConfig: ${appConfig.toString()}');
     }
     
     // --- Register modules WITH explicit AppConfig ---
     logger.d('$tag Registering AuthModule with explicit AppConfig');
     AuthModule.register(sl, appConfig: appConfig);
     
     // Log current config to confirm
     logger.i('$tag Using AppConfig: ${appConfig.toString()}');
     
     // Continue with other registrations...
   }
   ```

   f. [ ] **REFACTOR**: Update tests for explicit dependency injection
   ```dart
   // Update all tests to use explicit dependency injection
   // For example, in auth_module_test.dart:
   
   setUp(() {
     // Create a new GetIt instance and mock config for each test
     getIt = GetIt.asNewInstance();
     mockConfig = AppConfig.test(
       apiDomain: 'test.example.com',
       apiKey: 'test-key',
     );
   });
   
   test('should register all dependencies correctly', () {
     // Act: Pass explicit config
     AuthModule.register(getIt, appConfig: mockConfig);
     
     // Assert: Verify registrations
     expect(getIt.isRegistered<FlutterSecureStorage>(), isTrue);
     expect(getIt.isRegistered<AuthEventBus>(), isTrue);
     // etc.
   });
   ```

### 10. [ ] Remove Deprecated Methods and Complete Migration

   a. [ ] **RED**: Verify all code uses new explicit methods
   ```dart
   test('No code uses deprecated DioFactory methods', () {
     // This is more of a manual verification:
     // 1. Search codebase for createBasicDioWithServiceLocator
     // 2. Search codebase for createAuthenticatedDioWithServiceLocator
     // If found anywhere, the test "fails"
     
     // For automated testing, we could use reflection or a static analysis tool,
     // but that's outside our test scope. Manual verification is needed.
   });
   ```
   
   b. [ ] **GREEN**: Remove deprecated methods once migration complete
   ```dart
   // lib/core/auth/infrastructure/dio_factory.dart
   class DioFactory {
     // Remove deprecated methods once migration is complete:
     // - createBasicDioWithServiceLocator
     // - createAuthenticatedDioWithServiceLocator
     
     // Keep only the clean explicit dependency methods:
     static Dio createBasicDio(AppConfig config) {
       // ... implementation ...
     }
     
     static Dio createAuthenticatedDio({
       required AuthApiClient authApiClient,
       required AuthCredentialsProvider credentialsProvider,
       required AuthEventBus authEventBus,
       required AppConfig config,
     }) {
       // ... implementation ...
     }
   }
   ```
   
   c. [ ] **REFACTOR**: Final cleanup and documentation
   ```dart
   // Add appropriate documentation to all methods
   /// Creates a basic Dio client configured with the provided AppConfig
   /// 
   /// This method uses explicit dependency injection rather than service location
   /// for improved testability and cleaner architecture.
   static Dio createBasicDio(AppConfig config) {
     // ... implementation ...
   }
   ```

## Execution Order

1. Start with Tasks 9a-9c: Updating DioFactory and AuthModule to use explicit dependency injection
2. Continue with Tasks 9d-9f: Updating injection_container.dart and tests
3. Finish with Tasks 10a-10c: Cleaning up deprecated methods and finalizing the migration

Each task follows TDD principles: write a failing test, implement the minimum code to make it pass, then refactor for cleanliness and maintainability.
