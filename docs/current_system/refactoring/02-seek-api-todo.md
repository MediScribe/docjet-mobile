# Seek API Refactoring Todo List

## 1. Create New Adapter Interface and Implementation

- [ ] Create test file for `AudioPlayerAdapterV2`
- [ ] Write test for updated `seek(Duration)` method
- [ ] Write test for `currentFilePath` getter
- [ ] Create `AudioPlayerAdapterV2` interface
- [ ] Create `AudioPlayerAdapterV2Impl` implementation
- [ ] Update `setSourceUrl()` to store `currentFilePath`
- [ ] Implement simplified `seek(Duration)` method
- [ ] Run tests to verify implementation

## 2. Create Adapter Factory with Feature Flag

- [ ] Create `AudioPlayerAdapterFactory` class
- [ ] Implement feature flag for switching implementations
- [ ] Create `_LegacyAdapterBridge` class
- [ ] Implement bridge to delegate from old to new API
- [ ] Update DI container to use factory
- [ ] Write test for factory and bridge adapter
- [ ] Test switching between implementations

## 3. Update Service Implementation

- [ ] Create test file for `AudioPlaybackServiceV2`
- [ ] Write test for seeking in same file vs different file
- [ ] Create `AudioPlaybackServiceV2Impl` implementation
- [ ] Implement new `seek(String, Duration)` method with context handling
- [ ] Add `_seekInNewContext()` private helper method
- [ ] Create service factory with feature flag
- [ ] Implement `_ForwardAdapterBridge` if needed
- [ ] Update DI container registration
- [ ] Run tests to verify service behavior

## 4. Testing and Cutover

- [ ] Create integration tests for seeking behavior
- [ ] Test seeking with both implementations
- [ ] Test edge cases (seek at start/end, during loading)
- [ ] Test seeking between different files
- [ ] Enable adapter feature flag in test environment
- [ ] Run full test suite with new adapter
- [ ] Enable service feature flag in test environment
- [ ] Run full test suite with new service
- [ ] Plan production deployment with feature flags

## 5. Cleanup and Code Removal

- [ ] Update all direct API users to use new seek API
- [ ] Remove old `seek(String, Duration)` method
- [ ] Remove bridge adapters when safe
- [ ] Remove feature flags when stable
- [ ] Update all tests to use new API
- [ ] Final verification tests for seek functionality 