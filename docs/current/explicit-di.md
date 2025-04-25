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

1.  **[✅] Create Explicit Interfaces**
    *   [✓] 1.1 Identify key services for interface extraction (e.g., `AppConfig`)
    *   [✓] 1.2 Extract interfaces capturing public methods/properties 
        * Created `AppConfigInterface` to define contract for AppConfig.
        * Created `DioFactoryInterface` defining the contract for the **target, class-based** factory (receives `AppConfigInterface` via constructor, provides instance methods).
        * How: Created interface files in `lib/core/interfaces` with abstract class definitions for the **target state**.
        * Findings: Aligning interfaces with the target architecture early clarifies the refactoring goal.
    *   [✓] 1.3 Write tests using interfaces
        * Updated AppConfig tests to use AppConfigInterface in type declarations.
        * How: Modified test assertions to work against the interface rather than concrete class.
        * Findings: Using interfaces in tests makes them more robust against implementation changes.
2.  **[✓] Create Test Doubles**
    *   [✓] 2.1 Generate or manually create test doubles for each interface - Using mock concrete classes
    *   [✓] 2.2 Ensure doubles implement the full interface
    *   [✓] 2.3 Write setup methods for common test scenarios
3.  **[✓] Prepare Hybrid Testing Approach**
    *   [✓] 3.1 Create helper methods for direct injection vs. GetIt registration - Mocked variants exist
    *   [✓] 3.2 Develop shared test utilities for consistent setup
    *   [✓] 3.3 Add setup/teardown methods to clean global state

### Phase 2: Core Infrastructure Migration

4.  **[✓] Migrate `AppConfig` to Explicit DI**
    *   [✓] 4.1 RED: Write failing tests for `AppConfig` - Tests exist in `app_config_test.dart`
    *   [✓] 4.2 GREEN: Implement `AppConfig` with constructor parameter dependencies - Private constructor with factory methods
    *   [✓] 4.3 REFACTOR: Clean up, document, and validate the new `AppConfig` - Good docs and test coverage
5.  **[⚠️] Create Factory Functions with Explicit Parameters**
    *   [✓] 5.1 RED: Write failing tests for explicit parameter factory versions (e.g., `DioFactory`) - Tests exist for mock variants
    *   [✓] 5.2 GREEN: Implement explicit parameter factory versions for testing - `createBasicDioMocked` and `createAuthenticatedDioMocked` created
    *   [⚠️] 5.3 REFACTOR: Add deprecation notices to old methods - Not done, regular methods still use service locator
6.  **[⚠️] Update Core Services to Accept `AppConfig`**
    *   [✓] 6.1 RED: Write tests to inject dependencies directly - Tests for mock variants exist
    *   [⚠️] 6.2 GREEN: Add constructor/factory parameters for dependencies - Only for mocked/test variants
    *   [❌] 6.3 REFACTOR: Replace service locator calls with parameter usage - NOT DONE, regular methods still use service locator

### Phase 3: DI Container Integration

7.  **[❌] Create Composable Registration Modules**
    *   [❌] 7.1 RED: Write tests verifying module registration logic - NOT STARTED
    *   [❌] 7.2 GREEN: Implement modules accepting dependencies - NOT STARTED
    *   [❌] 7.3 REFACTOR: Ensure modules are composable - NOT STARTED
8.  **[⚠️] Update `injection_container.dart` to Use Composition**
    *   [✓] 8.1 RED: Write integration tests verifying overrides - Tests exist in `integration_test/app_test.dart`
    *   [✓] 8.2 GREEN: Update container to support overrides - Override system implemented
    *   [❌] 8.3 REFACTOR: Apply explicit composition pattern - NOT DONE, still using service locator for component resolution

### Phase 4: Client Code Migration

9.  **[❌] Refactor DioFactory for Full Explicit DI**
    *   [❌] 9.1 RED: Write tests for fully explicit DioFactory (no service locator) - NOT STARTED
    *   [❌] 9.2 GREEN: Implement explicit constructor DioFactory - NOT STARTED, still static methods using service locator
    *   [❌] 9.3 REFACTOR: Replace static methods with instance methods - NOT STARTED
10. **[❌] Update Remaining Factory Methods**
    *   [❌] 10.1 RED: Update all tests to use the explicit DI approach - NOT STARTED
    *   [❌] 10.2 GREEN: Update factory methods to take explicit dependencies - NOT STARTED
    *   [❌] 10.3 REFACTOR: Deprecate old methods and document new approach - NOT STARTED
11. **[❌] Update Call Sites Incrementally**
    *   [❌] 11.1 RED: Create tests for call sites with explicit parameters - NOT STARTED
    *   [❌] 11.2 GREEN: Update call sites for explicit dependencies - NOT STARTED
    *   [❌] 11.3 REFACTOR: Clean up and ensure consistency - NOT STARTED

### Phase 5: Finalization and Cleanup

12. **[⚠️] Update Mock Server Script**
    *   [✓] 12.1 RED: Test the development mode mechanism - TEST EXISTS in `integration_test/app_test.dart`
    *   [❌] 12.2 GREEN: Update script to use main_dev.dart entry point - NOT DONE, still using `--dart-define-from-file`
    *   [❌] 12.3 REFACTOR: Add detailed comments explaining the approach - NOT DONE
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