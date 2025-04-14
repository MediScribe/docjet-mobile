# Logging Refactoring Todo List

## Status Update - April 2024

**Completed**: The core logging system has been completely refactored. The new implementation:

1. Provides a centralized `LoggerFactory` with dynamic log level control
2. Supports fully testable logging without dependency injection
3. Includes a comprehensive testing API built directly into `LoggerFactory`
4. Allows controlling log levels per component at runtime

**Key Changes**:
- ✅ Deprecated `lib/core/utils/logger.dart` (can be safely removed)
- ✅ Implemented new system in `lib/core/utils/log_helpers.dart`
- ✅ Created documentation in `docs/logging_guide.md`
- ✅ Removed redundant `docjet_test` package (testing built into core)

**Next Steps**: Individual components still need to be updated to use the new logger format. The recommended minimal change approach is:

```dart
import 'package:docjet_mobile/core/utils/log_helpers.dart';

class MyComponent {
  final logger = LoggerFactory.getLogger(MyComponent, level: Level.off);
  
  void doSomething() {
    logger.i('Starting operation');
    // ...
  }
}
```

**IMPORTANT - Logger Usage Pattern**:
1. **SUT (System Under Test)**: Logger MUST be defined as a class member inside the SUT class.
   ```dart
   class MyImplementation {
     final logger = LoggerFactory.getLogger(MyImplementation, level: Level.off);
     // ...
   }
   ```

2. **Test Files**: Logger SHOULD REMAIN as file-level variable in test files.
   ```dart
   // Top of test file
   final logger = LoggerFactory.getLogger('MyComponentTest', level: Level.debug);
   ```

3. **Setting Debug Levels in Tests**: 
   - In test files, set the SUT class's logger level to debug in setUp or at the top of main():
   ```dart
   void main() {
     // Enable debug logs for the SUT component
     LoggerFactory.setLogLevel(MyImplementation, Level.debug);
     
     // ...test code...
   }
   ```

**Testing Practice**:

```dart
setUp(() {
  // Set SUT component's logger to debug level for better test visibility
  LoggerFactory.setLogLevel(MyComponent, Level.debug);
  // ... other setup ...
});
```

**Optional Enhancements** (do only if improving a specific component):
- Add tags for better log readability: `static final String _tag = logTag(MyComponent);`
- Add debug log enabler: `static void enableDebugLogs() => LoggerFactory.setLogLevel(MyComponent, Level.debug);`

For full documentation, see [Logging Guide](../logging_guide.md).

## 1. Create Logging Utilities

- [x] Create test file for log formatting helpers
- [x] Write test for `logTag()` function
- [x] Write test for `formatPlaybackState()` function
- [x] Write test for log level configuration
- [x] Implement `LoggerFactory` class
- [x] Implement `CustomLogFilter` class
- [x] Implement helper functions
- [x] Run tests to verify implementation
- [x] Add support for string-based loggers
- [x] Update tests for string-based loggers
- [x] Document string-based logger behavior

## 2. Update Components

For each component, follow the MINIMAL change approach:

### 2.1 AudioPlayerAdapter

- [x] Update import statements (remove old logger, add new log_helpers)
- [x] Replace logger initialization with `LoggerFactory.getLogger(AudioPlayerAdapter)`
- [x] Run adapter tests to verify no behavior change

### 2.2 PlaybackStateMapper

- [x] Update import statements (remove old logger, add new log_helpers)
- [x] Replace logger initialization with `LoggerFactory.getLogger(PlaybackStateMapper)`
- [x] Run mapper tests to verify no behavior change

### 2.3 AudioPlaybackService

- [x] Update import statements (remove old logger, add new log_helpers)
- [x] Replace logger initialization with `LoggerFactory.getLogger(AudioPlaybackService)`
- [x] Run service tests to verify no behavior change

### 2.4 AudioListCubit

- [x] Update import statements (remove old logger, add new log_helpers)
- [x] Replace logger initialization with `LoggerFactory.getLogger(AudioListCubit)`
- [x] Run cubit tests to verify no behavior change

### 2.5 AudioPlayerWidget

- [x] Update import statements (remove old logger, add new log_helpers)
- [x] Replace logger initialization with `LoggerFactory.getLogger(AudioPlayerWidget)`
- [x] Run widget tests to verify no behavior change

## 3. Remove Debug Flags and Commented Logs

- [ ] Search for and remove all `const bool _debug*` flags
- [ ] Search for and remove all commented log statements
- [ ] Convert conditional debug logs to use log levels
- [ ] Standardize log levels across components

## 4. Testing Support

- [x] ~~Create `test/helpers/log_test_helpers.dart`~~ (Obsolete - now built into LoggerFactory)
- [x] ~~Implement `TestLogOutput` class in helper file~~ (Obsolete - now built into LoggerFactory)
- [x] ~~Implement `resetLogLevels()` function~~ (Now available as LoggerFactory.resetLogLevels())
- [x] ~~Implement test helper functions~~ (Now available through LoggerFactory APIs)
- [x] ~~Add support for string-based loggers in test helpers~~ (Built into core)
- [x] ~~Create tests for test helpers~~ (Core testing is validated)
- [x] Update existing component tests to use new logging test APIs
    - [x] AudioPlayerAdapterImpl
    - [x] PlaybackStateMapperImpl
- [ ] Add test for each component with debug logs enabled
- [ ] Verify tests pass with different log levels

## 5. Examples & Verification

- [x] Create example implementation
- [x] Create comprehensive tests for examples
- [x] Add string-based logger examples

## 6. Final Verification and Documentation

- [x] Document logging system (complete in `docs/logging_guide.md`)
- [x] Create usage examples for components
- [x] Test in release mode to verify log level restrictions 
- [ ] Run full test suite with new logging system
- [ ] Remove any remaining legacy logging code 