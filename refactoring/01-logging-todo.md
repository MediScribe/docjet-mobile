# Logging Refactoring Todo List

**Note on File Structure:**

*   **Main Implementation:** `lib/core/utils/log_helpers.dart`
*   **Old System (To Remove):** `lib/core/utils/logger.dart`
*   **Tests for Implementation:** `test/core/utils/log_helpers_test.dart`
*   **Test Utilities Package:** `packages/docjet_test/lib/src/helpers/logging_test_utils.dart`
*   **Example Usage:** `examples/logging_example.dart`
*   **Example Test:** `test/examples/logging_example_test.dart`

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

### 2.1 AudioPlayerAdapter

- [ ] Create test that mocks logger and verifies logging calls
- [ ] Update import statements to use new logging utilities
- [ ] Add static `_tag` field
- [ ] Add logger initialization in constructor
- [ ] Add `enableDebugLogs()` static method
- [ ] Update `resume()` method with new logging pattern
- [ ] Update `pause()` method with new logging pattern
- [ ] Update `seek()` method with new logging pattern
- [ ] Update `setSourceUrl()` method with new logging pattern
- [ ] Update `stop()` method with new logging pattern
- [ ] Run adapter tests to verify no behavior change

### 2.2 PlaybackStateMapper

- [ ] Update import statements to use new logging utilities
- [ ] Add static `_tag` field
- [ ] Add logger initialization in constructor
- [ ] Add `enableDebugLogs()` static method
- [ ] Update stream initialization logging
- [ ] Update subscription handling logging
- [ ] Update state transformation logging
- [ ] Update error handling logging
- [ ] Run mapper tests to verify no behavior change

### 2.3 AudioPlaybackService

- [ ] Update import statements to use new logging utilities
- [ ] Add static `_tag` field
- [ ] Add logger initialization in constructor
- [ ] Add `enableDebugLogs()` static method
- [ ] Update `play()` method with new logging pattern
- [ ] Update `pause()` method with new logging pattern
- [ ] Update `resume()` method with new logging pattern
- [ ] Update `seek()` method with new logging pattern
- [ ] Update `stop()` method with new logging pattern
- [ ] Update state handling logging
- [ ] Run service tests to verify no behavior change

### 2.4 AudioListCubit

- [ ] Update import statements to use new logging utilities
- [ ] Add static `_tag` field
- [ ] Add logger initialization in constructor
- [ ] Add `enableDebugLogs()` static method
- [ ] Update state subscription logging
- [ ] Update `playRecording()` method with new logging pattern
- [ ] Update `pausePlayback()` method with new logging pattern
- [ ] Update `resumePlayback()` method with new logging pattern
- [ ] Update `stopPlayback()` method with new logging pattern
- [ ] Update `seekRecording()` method with new logging pattern
- [ ] Run cubit tests to verify no behavior change

### 2.5 AudioPlayerWidget

- [ ] Update import statements to use new logging utilities
- [ ] Add static `_tag` field
- [ ] Add logger initialization in constructor
- [ ] Update widget lifecycle method logging
- [ ] Update UI interaction logging
- [ ] Update state handling logging
- [ ] Run widget tests to verify no behavior change

## 3. Remove Debug Flags and Commented Logs

- [ ] Search for and remove all `const bool _debug*` flags
- [ ] Search for and remove all commented log statements
- [ ] Convert conditional debug logs to use log levels
- [ ] Standardize log levels across components
- [ ] Run tests to verify behavior remains unchanged

## 4. Update Tests for Component-Specific Logging

- [x] Create `test/helpers/log_test_helpers.dart`
- [x] Implement `TestLogOutput` class in helper file
- [x] Implement `resetLogLevels()` function
- [x] Implement `withDebugLogsFor()` function
- [x] Implement `withLogLevelFor()` function
- [x] Implement `expectNoLogsFrom()` function
- [x] Add support for string-based loggers in test helpers
- [x] Create tests for test helpers in `log_test_helpers_test.dart`
- [x] Implement `expectLogContains()` function
- [x] Implement `expectNoLogsAboveLevel()` function
- [x] Implement `captureLogOutput()` function
- [ ] Update existing tests to use new helpers
- [ ] Add test for each component with debug logs enabled
- [ ] Verify tests pass with different log levels

## 5. Examples & Verification

- [x] Create `examples/logging_example.dart`
- [x] Create `test/examples/logging_example_test.dart`
- [x] Add string-based logger examples

## 6. Final Verification and Documentation

- [ ] Run full test suite
- [ ] Perform manual testing with different log levels
- [ ] Remove any remaining legacy logging code
- [x] Document string-based logger behavior
- [ ] Document the logging system in README
- [ ] Create usage examples for each component
- [ ] Test in release mode to verify log level restrictions 