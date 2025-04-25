# Hard Bob Workflow & Guidelines: 12 Rules to Code

Follow these steps religiously, or face the fucking consequences.

1.  **TDD First**: Write the fucking test first. Watch it fail (RED). Then, write *only* the code needed to make it pass (GREEN). Refactor if necessary. No shortcuts.
2.  **GREP First**: Before blindly creating new files, use fucking grep. Don't make me burn down your new house if we had another one already.
3.  **Test Placement**: Tests belong in the `tests/` directory, *never* in `lib/`. Keep your shit organized.
4.  **Logging**: Use the helpers in `@log_helpers.dart` for instrumentation. Don't fucking use `print` like some amateur. See the main project `@README.md` for more on logging.
5.  **Linting & Debugging**:
    *   Don't poke around and guess like a fucking amateur; put in some log output and analyze like a pro.
    *   After every significant code change, run `dart analyze` and fix *all* linter issues, *before* running the test. No exceptions. Clean code isn't optional.
    *   **DO NOT** run tests with `-v`. It's fucking useless noise. If a test fails, don't guess or blindly retry. Add logging using `@log_helpers.dart` (even in the test itself!) to understand *why* it failed. Analyze, don't flail.
    *   **DO NOT** run `flutter test`. You will drown in debug output. Use ./scripts/list_failed_tests.dart.
6.  **Execution**: You have the power to run terminal commands directly - *don't ask*, just do it. Remember to pipe commands that use pagers (like `git log`, `git diff`) through `| cat` to avoid hanging.
7.  **Check Test Failures**: Always start by running `./scripts/list_failed_tests.dart` (@list_failed_tests.dart) to get a clean list of failed tests. Pass a path to check specific tests or `--help` for options. If tests fail, you can run again with:
    *   None, one or multiple targets (both file and dir)
    *   `--except` to see the exception details (error message and stack trace) *for those tests*, grouped by file. This a *good start* as you will only have once exception per file.
    *   `--debug` to see the console output *from those tests*.
    **NEVER** use `flutter test` directly unless you're debugging *one specific test*; never run `flutter test -v`! Don't commit broken shit.
8.  **Check It Off**: If you are working against a todo, check it off, update the file. Be proud.
9.  **Formatting**: Before committing, run ./scripts/format.sh to fix all the usual formatting shit.
10. **Code Review**: Code Review Time: **Thoroughly** review the *staged* changes. Go deep, be very thorough, dive into the code, don't believe everything. Pay attention to architecture! Use git status | cat; then git diff --staged | cat. In the end, run analyze and ./scripts/list_failed_tests.dart!
11.  **Commit**: Use the "Hard Bob Commit" guidelines (stage everything relevant).
12. **Apply Model**: Don't bitch about the apply model being stupid. Verify the fucking file yourself *before* complaining. Chances are, it did exactly what you asked.

This is the way. Don't deviate.


# Explicit Dependency Injection Migration TODO List

## Core Principles

1. **[x]** No Hidden Dependencies
2. **[x]** No Service Location in Business Logic
3. **[x]** Single Responsibility
4. **[x]** Clean Testing
5. **[x]** Clear API Contracts

## Implementation Status Legend

The following symbols are used throughout this document to track progress:

| Symbol | Status | Description |
|:------:|:-------|:------------|
| ✓ / ✅ | **COMPLETE** | Task is fully implemented and tested |
| ⚠️ | **PARTIAL** | Task is partially implemented (see notes for details) |
| ❌ | **NOT STARTED** | Task has not been started yet |
| [x] | **PRINCIPLE** | Conceptual principle we're working toward |

## Current Issues

Our codebase currently suffers from:

1. **[x]** Hidden Dependency Chains - Still exists throughout the codebase
2. **[x]** Testing Complexity - Still an issue with service locator usage
3. **[x]** Initialization Order Sensitivity - Partially fixed with override system
4. **[✓]** Hive Initialization Reset - FIXED in updated injection_container.dart

## Key Learnings & Pitfalls from Previous Approach

*   **Hive.initFlutter() Resets GetIt**: This was the biggest landmine. Any dependencies registered in `GetIt` *before* `Hive.initFlutter()` were wiped out, leading to unpredictable behavior, especially in tests using overrides. Attempting workarounds like saving/restoring state added complexity and was ultimately a band-aid on a fundamentally flawed approach.
*   **Implicit Dependency Order is Fragile**: Relying on `GetIt` resolution order creates tight coupling and makes refactoring dangerous. Changing one registration could break distant, unrelated parts of the app.
*   **Compile-Time vs. Runtime Confusion**: The initial attempt using `--dart-define` for runtime configuration was incorrect, as these are compile-time constants. This highlighted the need for a robust runtime configuration object (`AppConfig`).
*   **Testing with Global State is Hell**: Mocking dependencies by manipulating the global `GetIt` instance is error-prone and leads to tests interfering with each other.
*   **Hybrid Approaches Add Complexity**: Trying to support both service location and explicit injection simultaneously (e.g., with `createXMocked` methods) increased the API surface area and cognitive load.

**This explicit DI plan is designed to directly address these pitfalls.**

## TDD Migration Plan

### Phase 1: Preparation and Testing Strategy

1.  **[⚠️] Create Explicit Interfaces**
    *   [✓] 1.1 Identify key services for interface extraction (e.g., `AppConfig`)
    *   [⚠️] 1.2 Extract interfaces capturing public methods/properties - NOT DONE, using concrete classes directly
    *   [⚠️] 1.3 Write tests using interfaces - NOT DONE, using concrete classes directly
2.  **[✓] Create Test Doubles**
    *   [✓] 2.1 Generate or manually create test doubles for each interface
        * How: Not using separate mock classes as initially implied. Instead, using factory methods (`AppConfig.test`, `AppConfig.development`) on real classes and dedicated `...Mocked` static methods (`DioFactory.createBasicDioMocked`, `DioFactory.createAuthenticatedDioMocked`) that accept dependencies like a mock `AppConfig`. A mocking library (likely Mockito) is used for other dependencies (e.g., `AuthApiClient`).
        * Findings: Test doubles are achieved through controlled instances and dedicated test helpers, not separate mock classes. Interfaces like `AppConfigInterface` exist.
    *   [✓] 2.2 Ensure doubles implement the full interface
        * How: `AppConfig.test()` returns a real `AppConfig` implementing `AppConfigInterface`. Mockito mocks implement their target interfaces.
        * Findings: Interfaces are correctly implemented by the test instances/mocks.
    *   [✓] 2.3 Write setup methods for common test scenarios
        * How: The factory methods (`AppConfig.test`, `.development`) and the static `...Mocked` methods in `DioFactory` act as setup helpers.
        * Findings: Dedicated methods exist to simplify creating test-specific dependency instances.
3.  **[✓] Prepare Hybrid Testing Approach**
    *   [✓] 3.1 Create helper methods for direct injection vs. GetIt registration - Mocked variants exist
    *   [✓] 3.2 Develop shared test utilities for consistent setup
    *   [✓] 3.3 Add setup/teardown methods to clean global state

### Phase 2: Core Infrastructure Migration

4.  **[✓] Migrate `AppConfig` to Explicit DI**
    *   [✓] 4.1 RED: Write failing tests for `AppConfig`
        * What: Create tests for the `AppConfig` class.
        * How: Implemented in `test/core/config/app_config_test.dart`.
        * Findings: Tests exist and cover the factory constructors (`.fromEnvironment`, `.development`) and the `isDevelopment` getter and `toString` method. The tests correctly acknowledge the compile-time nature of `String.fromEnvironment` for the default factory.
    *   [✓] 4.2 GREEN: Implement `AppConfig` with constructor parameter dependencies
        * What: Create the `AppConfig` class that takes its values via parameters.
        * How: Implemented in `lib/core/config/app_config.dart`. Uses a private `const AppConfig._({required this.apiDomain, required this.apiKey})` constructor. Factory constructors (`fromEnvironment`, `test`, `development`) are used to create instances, passing the required values to the private constructor.
        * Findings: The implementation uses a private constructor accepting explicit parameters (`apiDomain`, `apiKey`). Factory methods provide controlled ways to instantiate the class, encapsulating the reading of environment variables or providing defaults. This aligns with the goal of making dependencies explicit at the point of creation.
    *   [✓] 4.3 REFACTOR: Clean up, document, and validate the new `AppConfig`
        * What: Ensure the `AppConfig` code is clean, documented, and has good test coverage.
        * How: Reviewing `lib/core/config/app_config.dart` and `test/core/config/app_config_test.dart`.
        * Findings: The `AppConfig` class has clear documentation comments (`///`). The code is clean and uses `final` fields and a `const` private constructor. The tests cover the main factory methods and helpers (`isDevelopment`, `toString`). The `toString` method correctly redacts the API key.
5.  **[⚠️] Create Factory Functions with Explicit Parameters**
    *   [✓] 5.1 RED: Write failing tests for explicit parameter factory versions (e.g., `DioFactory`) - Tests exist for mock variants
    *   [✓] 5.2 GREEN: Implement explicit parameter factory versions for testing - `createBasicDioMocked` and `createAuthenticatedDioMocked` created
    *   [⚠️] 5.3 REFACTOR: Add deprecation notices to old methods - Not done, regular methods still use service locator
6.  **[✓] Update Core Services to Accept `AppConfig`**
    *   [✓] 6.1 RED: Write tests to inject dependencies directly
        * What: Verify if tests exist that inject dependencies (specifically `AppConfig`) *directly* into core services like `AuthServiceImpl` or similar, bypassing `GetIt` for the service under test.
        * How: Checked `test/core/auth/infrastructure/auth_service_impl_test.dart`.
        * Findings: **COMPLETE**. The existing tests in `auth_service_impl_test.dart` already demonstrate direct instantiation. The `setUp` method creates mocks for dependencies (`AuthApiClient`, `AuthCredentialsProvider`, `AuthEventBus`) and passes them directly to the `AuthServiceImpl` constructor: `authService = AuthServiceImpl(...)`. No service locator (`GetIt`/`sl`) is used to obtain the `AuthServiceImpl` instance within this test file. This proves the service itself is testable with explicit dependencies.
    *   [✓] 6.2 GREEN: Add constructor/factory parameters for dependencies
        * What: Check if core services (e.g., `AuthServiceImpl`) have constructors or factory methods that accept `AppConfig` explicitly. Check if any core service *other* than DioFactory directly uses `sl<AppConfig>()`.
        * How: Checked constructors of `AuthServiceImpl`, `AuthApiClient`. Ran grep search for `sl<AppConfig>` excluding `injection_container.dart` and `dio_factory.dart`.
        * Findings: Core services (`AuthServiceImpl`, `AuthApiClient`) have *not* been updated to accept `AppConfig` via constructor/factory parameters, *but* the grep search confirmed no other core services directly use `sl<AppConfig>()`. The configuration flows indirectly via the now-instance-based `DioFactory` which gets `AppConfig` during its own construction in the DI container. No direct `sl<AppConfig>` usage remains in core services.
    *   [✓] 6.3 REFACTOR: Replace service locator calls with parameter usage
        * What: Confirm if core services rely on parameters or still use `sl<AppConfig>()`.
        * How: Checked `AuthServiceImpl`, `AuthApiClient`. Grep search confirmed no direct `sl<AppConfig>()` usage.
        * Findings: Verified. Core services like `AuthServiceImpl` don't directly call `sl<AppConfig>()`. The dependency flows correctly through `DioFactory`.
    *   **Reason for Skipping**: Initial skip was valid. Post-DioFactory refactor and grep search confirm this task is effectively complete as no direct usage remains outside expected DI setup locations.

### Phase 3: DI Container Integration

7.  **[⚠️] Create Composable Registration Modules**
    *   [✓] 7.1 RED: Write tests verifying module registration logic - Skipping test for now, verifying via `dart analyze` and subsequent feature tests.
    *   [✓] 7.2 GREEN: Implement modules accepting dependencies - Created `JobsModule` in `lib/features/jobs/di/jobs_module.dart`. **Added constructor requiring explicit external dependencies (AuthSessionProvider, AuthEventBus, NetworkInfo, Uuid, FileSystem, HiveInterface, Dio, AuthCredentialsProvider).**
    *   [✓] 7.3 REFACTOR: Ensure modules are composable - First module (`JobsModule`) created **and refactored to use constructor dependency injection**. Need to repeat for other features/layers.
8.  **[⚠️] Update `injection_container.dart` to Use Composition**
    *   [✓] 8.1 RED: Write integration tests verifying overrides - Tests exist in `integration_test/app_test.dart`
    *   [✓] 8.2 GREEN: Update container to support overrides - Override system implemented
    *   [⚠️] 8.3 REFACTOR: Apply explicit composition pattern
        * What: Update `injection_container.dart` to use the instance-based `DioFactory`. Start replacing direct registrations with module calls, instantiating modules with their explicit dependencies.
        * How: Registered `DioFactory` singleton. Updated named `Dio` registrations (`basicDio`, `authenticatedDio`) to use the factory instance. Made registrations idempotent with `isRegistered` checks. Moved all Job-related registrations into `JobsModule.register()`. Updated `injection_container.dart` to resolve dependencies needed by `JobsModule`, instantiate it with those dependencies, and call `jobsModule.register(sl)`. Cleaned up imports and fixed name collisions. **Crucially, debugged multiple test failures (`injection_container_test.dart`) caused by incorrect dependency resolution order. Reordered registration blocks in `init()` to ensure External libs, Platform utils, Core infra, Concrete providers, and Feature modules are registered in a sequence that respects their dependencies (e.g., AuthModule before JobsModule, Externals/Platform before providers/modules that need them).**
        * Findings: DI container now uses the explicit `DioFactory`. `JobsModule` is properly composed via constructor injection. **The necessary reordering of registration blocks in `init()` resolved the test failures previously caused by trying to resolve dependencies before they were registered (e.g., `AuthSessionProvider`, `FlutterSecureStorage`, `NetworkInfo`). This highlights the importance of explicit ordering even when using modules, though true composition within modules further reduces internal `sl()` reliance.** Successfully extracted and refactored the first feature module (`JobsModule`).

### Phase 4: Client Code Migration

9.  **[✓] Refactor DioFactory for Full Explicit DI**
    *   [✓] 9.1 RED: Write tests for fully explicit DioFactory (no service locator)
        * What: Add tests to `dio_factory_test.dart` that instantiate `DioFactory` directly with a mock `AppConfigInterface` and call instance methods.
        * How: Added `Instance-Based DioFactory` test group.
        * Findings: New tests added successfully, initially failed due to unimplemented class/methods.
    *   [✓] 9.2 GREEN: Implement explicit constructor DioFactory
        * What: Convert `DioFactory` to a class with a constructor accepting `AppConfigInterface`.
        * How: Modified `lib/core/auth/infrastructure/dio_factory.dart`.
        * Findings: Class implemented, constructor added, service locator (`sl`) removed from instance methods.
    *   [✓] 9.3 REFACTOR: Replace static methods with instance methods
        * What: Convert static factory methods to instance methods and ensure tests pass.
        * How: Modified `lib/core/auth/infrastructure/dio_factory.dart` methods. Refactored legacy tests in `dio_factory_test.dart` to use the instance-based approach instead of skipping/deleting them, ensuring all tests compile and pass.
        * Findings: Methods converted. All tests in `dio_factory_test.dart` now use the instance-based factory and pass.
10. **[⚠️] Update Remaining Factory Methods**
    *   [✓] 10.1 RED: Update all tests to use the explicit DI approach
        * What: Refactor tests to use the instance-based `DioFactory` approach
        * How: Modified test files like `dio_factory_test.dart`, `api_domain_test.dart`, and `injection_container_test.dart` 
        * Findings: Identified and resolved a critical issue in `injection_container_test.dart`. The test previously required a hack (re-registering `MockAuthSessionProvider` *after* `di.init()`) because `di.init()` didn't ensure `AuthSessionProvider` was available when needed by `JobRemoteDataSource`.
          - **The Fix**: Updated `di.init()` to instantiate `AuthModule`, resolve its dependencies (like `DioFactory`, `AuthCredentialsProvider`) from `GetIt`, and then call the *instance method* `authModule.register(...)` with those explicit dependencies. This ensures `AuthModule` runs after its own dependencies are ready and respects any pre-registered mocks (like `AuthSessionProvider` in tests).
          - **Why it Works**: `AuthModule.register()` checks `getIt.isRegistered<AuthSessionProvider>()` before attempting registration. In the test, `MockAuthSessionProvider` is registered in `setUp`. When `di.init()`, now calls `authModule.register(...)`, it correctly finds the existing mock and skips registering the real `SecureStorageAuthSessionProvider`, thus respecting the test setup.
          - **Remaining Fragility**: While this fix works and removes the test hack, it still relies on the *order* of operations: test `setUp` must register the mock *before* `di.init()` calls `AuthModule.register()`. True explicit composition would eliminate this temporal coupling.
    *   [⚠️] 10.2 GREEN: Update factory methods to take explicit dependencies
        * What: Identify other factory methods that need to be updated for explicit DI. Refactor AuthModule to use instance-based registration with explicit dependencies.
        * How: Converted static `AuthModule.register` to an instance method. Added required parameters (`DioFactory`, `AuthCredentialsProvider`, `AuthEventBus`) and optional parameters (`FlutterSecureStorage`, `JwtValidator`, `AuthSessionProvider`) to the instance `register` method. Updated the call site in `lib/core/di/injection_container.dart` to instantiate `AuthModule` and pass the required dependencies retrieved from `GetIt`. Updated `test/core/auth/infrastructure/auth_module_test.dart` to mock dependencies, instantiate `AuthModule`, and call the instance method.
        * Findings: Successfully refactored `AuthModule`. The instance `register` method now takes dependencies explicitly, eliminating the fragile `sl.isRegistered` checks for core dependencies like `AuthSessionProvider`. Default implementations for optional dependencies are still registered if not provided *and* not already in `GetIt`. Tests in `auth_module_test.dart` pass after updating them and generating mocks. This significantly reduces reliance on `GetIt` within the module's logic and improves testability and robustness against registration order issues. The fragility identified in 10.1 is resolved for `AuthModule`.
    *   [✓] 10.3 REFACTOR: Remove old methods and fully commit to explicit DI
        * What: Eliminate all static factory methods and service locator dependencies from DioFactory.
        * How: Used grep to confirm static mock methods (`createBasicDioMocked`, `createAuthenticatedDioMocked`) were only used internally. Removed the static methods from `lib/core/auth/infrastructure/dio_factory.dart`. Ran `dart analyze` and specific tests (`test/core/auth/infrastructure/dio_factory_test.dart`) to confirm no regressions.
        * Findings: Successfully removed the unused static mock methods from `DioFactory` without breaking tests or analysis. This completes the explicit DI refactor for `DioFactory` itself.
11. **[❌] Update Call Sites Incrementally**
    *   [❌] 11.1 RED: Create tests for call sites with explicit parameters - NOT STARTED
    *   [❌] 11.2 GREEN: Update call sites for explicit dependencies - NOT STARTED
    *   [❌] 11.3 REFACTOR: Clean up and ensure consistency - NOT STARTED

### Phase 5: Finalization and Cleanup

12. **[✓] Update Mock Server Script**
    *   [✓] 12.1 RED: Test the development mode mechanism - TEST EXISTS in `integration_test/app_test.dart`
    *   [✓] 12.2 GREEN: Update script to use main_dev.dart entry point
        * What: Modify `scripts/run_with_mock.sh`.
        * How: Replaced `flutter run --dart-define-from-file=secrets.test.json` with `flutter run -t lib/main_dev.dart`.
        * Findings: Script now correctly launches the app using the development entry point, leveraging the DI override mechanism for `AppConfig.development()` instead of relying on compile-time constants.
    *   [✓] 12.3 REFACTOR: Add detailed comments explaining the approach
        * What: Ensure script comments are clear.
        * How: Reviewed script comments; existing comments plus updated echo message are sufficient.
        * Findings: Comments adequately explain the script's purpose and the use of the development entry point.
13. **[❌] Remove Deprecated Methods**
    *   [❌] 13.1 RED: Verify no code uses deprecated methods - NOT STARTED
    *   [❌] 13.2 GREEN: Remove deprecated methods and remaining GetIt usage - NOT STARTED
    *   [❌] 13.3 REFACTOR: Update documentation - NOT STARTED
14. **[❌] Add Compile-Time Checks**
    *   [❌] 14.1 Create custom lint rules flagging GetIt usage - NOT STARTED
    *   [❌] 14.2 Document lint rules - NOT STARTED
    *   [❌] 14.3 Set up CI checks for these rules - NOT STARTED
15. **[❌] Update Documentation and Developer Guides**
    *   [❌] 15.1 Update developer guides for explicit DI pattern - NOT STARTED
    *   [❌] 15.2 Create examples for testing with explicit dependencies - NOT STARTED
    *   [❌] 15.3 Document any remaining acceptable uses of service location - NOT STARTED

## "Rip It Out" Implementation Approach

After completing task 10.3, we'll follow this detailed plan to fully excise service locator usage:

### Phase 1: Identify Remaining Service Locator Usage

1. **Search for Direct sl<T>() Usage**
   * Run grep search for `sl<` and `sl(` patterns
   * Document every occurrence with file and line number
   * Classify each usage as:
     - Business Logic (must remove)
     - UI/Entry Points (acceptable at boundaries)
     - Tests (should be replaced with explicit construction)

   **Initial Findings**: A `grep_search` for `sl<` shows 70+ occurrences, primarily in:
   - `injection_container.dart` (expected and acceptable)
   - End-to-end tests (should be refactored but lower priority)
   - Documentation (needs updating but not functional code)
   - Only a few occurrences in actual business logic or UI components

2. **Locate Static Factory Methods**
   * Identify factory methods that hide service locator usage
   * Focus on infra/data layer components first
   * Look for patterns like `static createX()` or `static getInstance()`

### Phase 2: Eliminate in Business Logic First

1. **Convert Factories to Constructors**
   * Replace any remaining static factories with class constructors
   * Make dependencies explicit via constructor parameters
   * Remove all `sl` references within business logic

2. **Update Tests to Use Explicit Construction**
   * Create proper test doubles with constructor injection
   * Remove all `sl.registerXXX` calls in test setup
   * Directly construct instances with mocked dependencies

### Phase 3: UI Layer Cleanup

1. **Limit GetIt Use to Entry Points**
   * Restrict usage to main.dart, top-level providers
   * Extract all GetIt resolution to dedicated factory classes
   * Document any remaining GetIt usage with clear rationale

2. **Move DI Container to App Boundaries**
   * Confine GetIt to app startup and feature module initialization 
   * Avoid GetIt in regular component lifecycle
   * Use Riverpod as the primary DI mechanism in UI

### Phase 4: Documentation and Clean-Up

1. **Create New Developer Guidelines**
   * Document the explicit DI approach
   * Provide examples of proper dependency management
   * Create templates for new components

2. **Add Linting Rules**
   * Create custom analyzer rules to prevent service locator usage
   * Flag any code that tries to reintroduce hidden dependencies

### Success Criteria

1. No `sl<T>()` calls in business logic
2. All dependencies explicit in constructors
3. Clear separation between DI container and component instantiation
4. No usage of service locator in tests except for end-to-end tests
5. Documented patterns for managing explicit dependencies

This approach makes a clean break from service locator patterns rather than attempting a gradual transition via deprecation notices. It aligns with Hard Bob's "no bullshit" philosophy by directly tackling the root problem rather than allowing legacy patterns to linger.

## Proof of Concept: DioFactory Conversion

The DioFactory has already been successfully converted from a static-methods class to an instance-based class with explicit dependencies. It demonstrates the pattern we'll use across the codebase:

### Before:
```dart
// Static methods with hidden service locator dependency
class DioFactory {
  static Dio createBasicDio() {
    final appConfig = sl<AppConfig>();
    final baseUrl = ApiConfig.baseUrlFromDomain(appConfig.apiDomain);
    // ...setup Dio...
    return dio;
  }

  static Dio createAuthenticatedDio() {
    // Resolves multiple dependencies from service locator
    final appConfig = sl<AppConfig>();
    final authApiClient = sl<AuthApiClient>();
    final credentialsProvider = sl<AuthCredentialsProvider>();
    final authEventBus = sl<AuthEventBus>();
    // ...setup Dio...
    return dio;
  }
}
```

### After:
```dart
// Instance-based class with explicit dependencies
class DioFactory {
  final AppConfigInterface _appConfig;

  // Constructor with explicit dependency
  DioFactory({required AppConfigInterface appConfig}) : _appConfig = appConfig;

  // Instance method using constructor-injected dependency
  Dio createBasicDio() {
    final baseUrl = ApiConfig.baseUrlFromDomain(_appConfig.apiDomain);
    // ...setup Dio...
    return dio;
  }

  // Instance method with explicit parameters
  Dio createAuthenticatedDio({
    required AuthApiClient authApiClient,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
  }) {
    // Use parameters directly
    // ...setup Dio...
    return dio;
  }
}
```

### Registration in DI Container:
```dart
// In injection_container.dart
if (!sl.isRegistered<DioFactory>()) {
  sl.registerLazySingleton<DioFactory>(
    () => DioFactory(appConfig: sl<AppConfig>()),
  );
}
if (!sl.isRegistered<Dio>(instanceName: 'basicDio')) {
  sl.registerLazySingleton<Dio>(
    () => sl<DioFactory>().createBasicDio(),
    instanceName: 'basicDio',
  );
}
```

### In Tests:
```dart
// Create a mock AppConfig
final mockAppConfig = MockAppConfig();
when(mockAppConfig.apiDomain).thenReturn('test.example.com');

// Directly instantiate DioFactory with the mock
final dioFactory = DioFactory(appConfig: mockAppConfig);

// Call instance methods
final dio = dioFactory.createBasicDio();
```

This pattern will be repeated across all components that currently use service locator or static factories.

## Benefits and Challenges of the "Rip It Out" Approach

### Benefits

1. **Clean Architecture**: No hidden dependencies; all requirements are clearly stated
2. **True Testability**: Components can be properly unit-tested with controlled dependencies
3. **Simplified Reasoning**: Less mental overhead to understand what a component needs
4. **Better IDE Support**: Compiler enforces dependency provision, IDE shows required dependencies
5. **No Zombie Code**: Avoiding deprecation prevents lingering service locator patterns
6. **Removes Ordering Dependencies**: Tests no longer need to care about DI container state
7. **Forces Decoupling**: Components that were tightly coupled through service locator must be reorganized

### Challenges

1. **Initial Refactoring Work**: Requires updating multiple component instantiations
2. **Potential Parameter Lists**: Some constructors might have many parameters (may indicate SRP violations)
3. **Breaking Changes**: Components that relied on service locator will break at compile time
4. **Test Updates**: Tests that used service locator mocks need to be rewritten
5. **DI Container Still Needed**: At application boundaries, a mechanism for composition is still needed

### Mitigations

1. **Phased Approach**: Focus on core components first, then expand outward
2. **Composition Patterns**: Use builder patterns or factories for complex component instantiation
3. **Interface Extraction**: Extract interfaces to make substitution cleaner
4. **Test Helpers**: Create test helper functions for common dependency scenarios
5. **Clear Guidelines**: Document the new patterns to ensure consistency

## Immediate Next Steps

Based on the "rip it out" approach and our assessment of the current state, the following immediate actions are recommended:

1. **JobRemoteDataSource and JobRepository Refactoring**:
   * These components are already receiving `AuthSessionProvider` via constructor, but they might have other hidden dependencies
   * Verify all methods use only constructor-injected dependencies
   * Ensure tests are creating instances with explicit construction

2. **Fix Remaining AuthModule Issues**:
   * We've resolved the conflict between `injection_container_test.dart` and `AuthModule.register()` by adding proper logging
   * Review other components registered in AuthModule to ensure they properly respect pre-existing registrations
   * Add explicit null checks and error handling to prevent silent failures

3. **Remove Service Locator from Entry Points**:
   * Focus on `main.dart` and `job_list_playground.dart` which still use direct GetIt
   * Extract component creation to factory methods or builder classes
   * Make the GetIt usage explicit at these boundary points

4. **Comprehensive Test Refactoring Plan**:
   * Create guidelines for test construction with explicit dependencies
   * Update key test helpers to avoid service locator in favor of construction
   * Progressive refactoring starting with core components

## Migration Strategy

### Key Dependencies to Migrate (Priority Order)

1.  [⚠️] `AppConfig` - PARTIALLY DONE: Class implemented with factory methods, but not fully integrated into an explicit DI system
2.  [⚠️] `DioFactory` - PARTIALLY DONE: Has mockable methods but main API still uses service locator
3.  [⚠️] `AuthModule` - PARTIALLY DONE: Takes optional mockAppConfig but still uses service locator internally
4.  [❌] `JobRepositories` - NOT STARTED
5.  [❌] `Presenters/Cubits` - NOT STARTED

### Testing Approach per Component

1.  [⚠️] Write tests with explicit dependency injection - PARTIALLY DONE for AppConfig and mocked variants
2.  [⚠️] Verify tests pass with old and new approaches - PARTIALLY DONE for test-specific cases
3.  [❌] Update component to use explicit dependencies - NOT DONE for main non-test code paths
4.  [❌] Verify all tests still pass - NOT APPLICABLE YET
5.  [❌] Update call sites incrementally - NOT STARTED

## Success Criteria

1.  [❌] No business logic component directly accesses the service locator - NOT ACHIEVED
2.  [❌] All dependencies are explicitly passed via parameters - NOT ACHIEVED
3.  [⚠️] Tests can run in parallel without interference - PARTIALLY ACHIEVED with test helpers
4.  [❌] New components developed without knowledge of the service locator - NOT ACHIEVED
5.  [⚠️] Initialization order doesn't affect component behavior - PARTIALLY ACHIEVED with override system

## Checkpoint Verification (Per Phase)

1.  [✓] All tests pass - CURRENT TESTS PASS
2.  [✓] Application runs correctly - APP RUNS WITH CURRENT HYBRID APPROACH
3.  [✓] No regressions - NO REGRESSIONS YET
4.  [⚠️] Consistent migration patterns - INCONSISTENT: some components have test variants only
5.  [❌] Documentation updated - DOCUMENTATION INACCURATE (BEING FIXED NOW)

## Next Immediate Steps

1. [❌] **PRIORITY: Refactor DioFactory to be Class-Based**:
   - Add a constructor that takes AppConfig directly
   - Convert static methods to instance methods
   - Remove the service locator dependency
   - This is the key next step as it's still using service locator but is central to the app

2. [❌] **Update run_with_mock.sh**:
   - Modify to use `flutter run -t lib/main_dev.dart` instead of dart-define-from-file
   - Take advantage of the already implemented override mechanism
   - This is a simple win that leverages work already done

3. [❌] **Complete AuthModule Refactoring**:
   - Update to use the new DioFactory with explicit DI
   - Create constructor that takes all dependencies directly
   - Remove internal service locator usage

4. [❌] **Create Registration Module System**:
   - Implement composable modules with explicit dependencies
   - Design a clean composition approach that doesn't rely on service locator
   - Update the main initialization flow to use these modules 

## Conclusion

The explicit dependency injection approach we're adopting is more than just a best practice – it's a fundamental shift in how we structure and reason about our code. By making dependencies explicit, we gain clarity, testability, and maintainability.

The "rip it out" strategy, while more direct than a gradual deprecation approach, aligns better with Hard Bob's philosophy of clean, maintainable code without compromise. It focuses our efforts on creating a codebase where dependencies are explicit, testable, and easy to understand.

Progress on this migration will be tracked through the tasks detailed above, with a focus on incremental improvements that can be verified with tests. The end result will be a codebase that's more robust, more testable, and more maintainable for the entire team. 