# Error Handling Refactoring Todo List

## 1. Create Audio Error Types

- [ ] Create test file for audio error types and handling
- [ ] Write test for error type classification
- [ ] Write test for error factory methods
- [ ] Write test for error serialization/deserialization
- [ ] Create `AudioErrorType` enum
- [ ] Implement `AudioError` class
- [ ] Create factory constructors for common errors
- [ ] Update `PlaybackState` to include error type
- [ ] Run tests to verify error types behavior

## 2. Update Adapter Error Handling

- [ ] Update adapter tests to include error scenarios
- [ ] Test specific error conditions (file not found, format errors)
- [ ] Modify `setSourceUrl()` to use domain errors
- [ ] Modify `play()` for domain error conversion
- [ ] Modify `pause()` for domain error conversion
- [ ] Modify `resume()` for domain error conversion
- [ ] Modify `seek()` for domain error conversion
- [ ] Modify `stop()` for domain error conversion
- [ ] Run adapter tests to verify error conversion

## 3. Update Service Error Handling

- [ ] Update service tests for error propagation
- [ ] Add file existence check in `play()` method
- [ ] Update error handling in `play()` to use error state
- [ ] Update error handling in `pause()` to use error state
- [ ] Update error handling in `resume()` to use error state
- [ ] Update error handling in `seek()` to use error state
- [ ] Update error handling in `stop()` to use error state
- [ ] Ensure all methods emit error state instead of throwing
- [ ] Run service tests with various error scenarios

## 4. Update UI Error Handling

- [ ] Create widget tests for error states
- [ ] Update `PlaybackInfo` to include error type
- [ ] Update state mapping for error handling in cubit
- [ ] Create error UI components in audio player widget
- [ ] Implement `_buildErrorState()` method
- [ ] Implement `_getErrorIcon()` helper method
- [ ] Add recovery actions based on error type
- [ ] Add retry functionality for network errors
- [ ] Add remove functionality for file not found
- [ ] Run widget tests with different error types

## 5. Integration and Cutover

- [ ] Create integration tests for full error flow
- [ ] Test file not found error path
- [ ] Test format error path
- [ ] Test network error path
- [ ] Test permission error path
- [ ] Test recovery actions for each error type
- [ ] Enable new error handling in test environment
- [ ] Run full test suite with new error handling
- [ ] Plan gradual production deployment 