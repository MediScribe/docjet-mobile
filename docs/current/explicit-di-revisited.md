# Explicit Dependency Injection: Revised Migration Plan

## Executive Summary

We are migrating from service location (GetIt/sl) to explicit dependency injection to achieve:
- No hidden dependencies in business logic
- Improved testability with clear dependency contracts
- Elimination of initialization order sensitivity
- Clean separation of concerns

This document provides a structured, component-based migration plan following strict TDD methodology.

## Core Principles

1. **No Hidden Dependencies**: All dependencies must be explicitly passed via constructor or method parameters
2. **No Service Location in Business Logic**: `GetIt`/`sl` should only appear at application boundaries
3. **Single Responsibility**: Each component should do one thing well
4. **Clean Testing**: Tests should not depend on global state
5. **Clear API Contracts**: Dependencies should be obvious from method signatures

## Current Status

### Completed Components ✅

1. **AppConfig**
   - Implemented with explicit constructor parameters
   - Factory methods (`fromEnvironment`, `test`, `development`) for controlled instantiation
   - Tests verify all creation paths and behavior

2. **DioFactory**
   - Converted from static methods to instance-based class
   - Constructor accepts `AppConfigInterface` explicitly
   - Instance methods replace static methods
   - Tests verify both basic and authenticated Dio creation

3. **CoreModule**
   - Centralizes registration of:
     - External libraries (Uuid, Connectivity, HiveInterface, FlutterSecureStorage)
     - Platform utils (FileSystem, NetworkInfo)
     - Core infrastructure (DioFactory, AuthEventBus)
     - AuthCredentialsProvider
   - Async `register()` method for file system initialization
   - Tests verify proper registration sequence

4. **JobsModule**
   - Takes explicit dependencies via constructor
   - Serves as template pattern for other modules
   - Tests verify registration behavior

5. **Injection Container**
   - Established clear registration sequence: 
     1. Hive 
     2. AppConfig 
     3. CoreModule 
     4. AuthModule 
     5. JobsModule
   - Enhanced logging for registration clarity
   - Tests verify full initialization works correctly

### Partially Completed ⚠️

1. **AuthModule**
   - Takes some explicit dependencies but still relies on service locator
   - Still uses `GetIt.isRegistered` checks internally

### Not Started ❌

1. **Call Site Updates** (Task 11)
2. **Deprecated Method Removal** (Task 13)
3. **Compile-Time Checks** (Task 14)
4. **Documentation Updates** (Task 15)

## Component Migration Path

This section outlines the remaining work organized by component dependencies, not chronological phases. Each component follows strict TDD with explicit RED, GREEN, REFACTOR steps.

### 1. AuthModule (Immediate Next Focus)

#### RED Phase
1. **[ ] Write Tests for Explicit DI Version**
   - [ ] 1.1 Update `test/core/auth/infrastructure/auth_module_test.dart`
   - [ ] 1.2 Create tests showing AuthModule instantiated with all dependencies explicitly passed
   - [ ] 1.3 Verify registration behavior without service locator usage

#### GREEN Phase
2. **[ ] Implement Explicit DI for AuthModule**
   - [ ] 2.1 Implement constructor accepting all dependencies:
     ```dart
     class AuthModule {
       final DioFactory _dioFactory;
       final AuthCredentialsProvider _credentialsProvider;
       final AuthEventBus _authEventBus;
       
       AuthModule({
         required DioFactory dioFactory,
         required AuthCredentialsProvider credentialsProvider,
         required AuthEventBus authEventBus,
       }) : _dioFactory = dioFactory,
            _credentialsProvider = credentialsProvider,
            _authEventBus = authEventBus;
     
       void register(GetIt getIt) {
         // Registration logic using explicit dependencies
       }
     }
     ```
   - [ ] 2.2 Remove all internal service locator dependencies
   - [ ] 2.3 Use JobsModule pattern as reference implementation

#### REFACTOR Phase
3. **[ ] Update Injection Container to Use Explicit AuthModule**
   - [ ] 3.1 Update `lib/core/di/injection_container.dart` to instantiate AuthModule with explicit dependencies
   - [ ] 3.2 Ensure proper initialization order
   - [ ] 3.3 Add detailed comments explaining the registration pattern

4. **[ ] Run All Auth Tests to Verify**
   - [ ] 4.1 Execute `flutter test test/core/auth` to verify all auth tests still pass
   - [ ] 4.2 Verify no regressions in other feature tests

### 2. Call Site Analysis

#### RED Phase
1. **[ ] Identify All Service Locator Usage**
   - [ ] 1.1 Run `grep` to identify all `sl<T>()` calls outside injection_container.dart
   - [ ] 1.2 Create test file `test/analysis/service_locator_usage_test.dart` that fails with list of usage sites
   - [ ] 1.3 Categorize by:
     - [ ] Business Logic (highest priority to fix)
     - [ ] UI Components (secondary priority)
     - [ ] Tests (should be updated to use explicit construction)

#### GREEN Phase
2. **[ ] Create Migration Plan for Each Usage Site**
   - [ ] 2.1 Prioritize based on component dependencies (repositories before services, services before UI)
   - [ ] 2.2 For each usage site:
     - [ ] Identify required dependencies
     - [ ] Create constructor/method parameters to accept dependencies
     - [ ] Update call sites to provide dependencies

#### REFACTOR Phase
3. **[ ] Document Boundary Pattern for UI Components**
   - [ ] 3.1 Define where service locator is still acceptable (main.dart, top-level providers)
   - [ ] 3.2 Create examples showing proper DI at UI boundaries

### 3. JobRepository/Services Migration

#### RED Phase
1. **[ ] Update Existing Tests for Explicit DI**
   - [ ] 1.1 Modify repository and service tests to use constructor injection exclusively
   - [ ] 1.2 Remove any remaining GetIt setup in tests

#### GREEN Phase
2. **[ ] Update Repository and Service Implementation**
   - [ ] 2.1 Add explicit constructor parameters for all dependencies
   - [ ] 2.2 Remove direct service locator usage
   - [ ] 2.3 Ensure consistency with existing pattern in JobsModule

#### REFACTOR Phase
3. **[ ] Update Repository Registration in Modules**
   - [ ] 3.1 Ensure proper registration in respective modules
   - [ ] 3.2 Pass dependencies explicitly when registering repositories

### 4. UI Layer Migration

#### RED Phase
1. **[ ] Identify UI Components Using Service Locator**
   - [ ] 1.1 Focus on Cubit/Bloc components first
   - [ ] 1.2 Create/update tests showing proper constructor injection

#### GREEN Phase
2. **[ ] Refactor UI Components**
   - [ ] 2.1 Update constructors to accept repositories/services explicitly
   - [ ] 2.2 Remove direct service locator usage
   - [ ] 2.3 For complex dependency trees, consider factory methods

#### REFACTOR Phase
3. **[ ] Integrate with Feature Modules**
   - [ ] 3.1 Ensure UI components are properly registered in feature modules
   - [ ] 3.2 Maintain consistency with established patterns

### 5. Deprecated Method Removal

#### RED Phase
1. **[ ] Verify No References to Deprecated Methods**
   - [ ] 1.1 Search codebase for deprecated method usage
   - [ ] 1.2 Ensure tests exist for replacement functionality

#### GREEN Phase
2. **[ ] Remove Deprecated Methods**
   - [ ] 2.1 Systematically remove deprecated methods
   - [ ] 2.2 Ensure compilation succeeds after removal

#### REFACTOR Phase
3. **[ ] Document Migration Patterns**
   - [ ] 3.1 Update comments explaining migration approach
   - [ ] 3.2 Ensure consistency in approach

### 6. Compile-Time Checks & Documentation

#### RED Phase
1. **[ ] Create Custom Lint Rules**
   - [ ] 1.1 Create custom analyzer rules to flag service locator misuse
   - [ ] 1.2 Set up CI to enforce these rules

#### GREEN Phase
2. **[ ] Update Developer Documentation**
   - [ ] 2.1 Create comprehensive guide for explicit DI pattern
   - [ ] 2.2 Include examples for new development

#### REFACTOR Phase
3. **[ ] Review and Improve Code Examples**
   - [ ] 3.1 Ensure all examples follow established patterns
   - [ ] 3.2 Verify documentation accuracy

## Testing Strategy

### Unit Tests
- All components must have unit tests demonstrating explicit dependency acceptance
- Tests should NOT use service locator internally
- Mock dependencies should be created and passed explicitly
- Example pattern:
  ```dart
  test('should create repository with explicit dependencies', () {
    // Arrange
    final mockApiClient = MockApiClient();
    final mockLocalDataSource = MockLocalDataSource();
    
    // Act
    final repository = RepositoryImpl(
      apiClient: mockApiClient,
      localDataSource: mockLocalDataSource,
    );
    
    // Assert
    expect(repository, isNotNull);
  });
  ```

### Integration Tests
- Verify modules compose correctly
- Test initialization sequence works correctly
- Verify DI container properly resolves dependencies

### E2E Tests
- Verify application works end-to-end with new DI approach
- Check for performance regressions

## Key Learnings & Pitfalls

1. **Hive.initFlutter() Resets GetIt**: Biggest landmine discovered. Dependencies registered before `Hive.initFlutter()` were wiped out.

2. **Implicit Dependency Order is Fragile**: Even with modularization, initialization order remains critical.

3. **Testing with Global State is Hell**: Mocking via global service locator is error-prone and causes test interference.

4. **Hybrid Approaches Add Complexity**: Supporting both styles simultaneously increases cognitive load.

## Success Criteria

A successful migration will meet these criteria:

1. **No Service Locator in Business Logic**
   - All business logic components receive dependencies via constructor
   - Only app boundaries (main.dart, top-level providers) use service locator

2. **All Dependencies Explicit**
   - Component dependencies are clear from method signatures
   - No hidden dependencies discovered during testing

3. **Tests Run Reliably**
   - Tests can run in parallel without interference
   - No test setup requires manipulating global state

4. **Developer Experience**
   - New components can be developed without knowledge of service locator
   - IDE provides assistance via type checking for dependencies

5. **No Regression**
   - All existing functionality works identically
   - No new bugs introduced during migration

## Proof of Concept: DioFactory Pattern

The DioFactory implementation demonstrates our target pattern:

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

This pattern will be replicated across all components that currently use service locator or static factories.

## Immediate Next Steps

Based on the assessment and handover brief, the following immediate actions are prioritized:

1. **[ ] Complete AuthModule Refactoring** (HIGHEST PRIORITY)
   - [ ] 1.1 Follow pattern established by JobsModule
   - [ ] 1.2 Take all dependencies explicitly through constructor
   - [ ] 1.3 Update `injection_container.dart` to provide these dependencies

2. **[ ] Identify and Categorize All `sl<T>()` Usage** 
   - [ ] 2.1 Run systematic grep to find all direct usage
   - [ ] 2.2 Prioritize business logic components over UI components

3. **[ ] Begin Systematic Repository Migration**
   - [ ] 3.1 Target repositories that depend on AuthModule
   - [ ] 3.2 Use established pattern from JobsModule 