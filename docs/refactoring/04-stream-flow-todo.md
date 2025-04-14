# Stream Flow Refactoring Todo List

## 1. Create a Simpler Mapper Interface

- [ ] Create test file for simpler mapper
- [ ] Write test for stream combination behavior
- [ ] Write test for distinct state handling
- [ ] Write test for debouncing behavior
- [ ] Create `PlaybackStateMapperV2` interface
- [ ] Implement `PlaybackStateMapperV2Impl` class
- [ ] Create `_mapToPlaybackState()` helper method
- [ ] Set up combined stream using RxDart
- [ ] Add proper error handling for streams
- [ ] Create `MapperFactory` with feature flag
- [ ] Implement `_MapperBridge` for backward compatibility
- [ ] Update DI registration to use factory
- [ ] Run tests to verify mapper behavior

## 2. Create Direct Adapter Stream Access

- [ ] Update adapter tests for direct stream exposure
- [ ] Update `AudioPlayerAdapterV2` interface
- [ ] Add stream getter methods to adapter interface
- [ ] Implement stream getters in adapter implementation
- [ ] Add stream delegation in bridge adapter
- [ ] Add stream mapping in bridge adapter
- [ ] Test stream behavior matches just_audio streams
- [ ] Verify both interfaces provide correct behavior

## 3. Create New Service Implementation

- [ ] Create test file for simplified service
- [ ] Write tests for service initialization
- [ ] Write tests for service state changes
- [ ] Create `AudioPlaybackServiceV3Impl` class
- [ ] Initialize mapper with adapter streams
- [ ] Subscribe to mapper's state stream
- [ ] Add error handling for streams
- [ ] Implement simplified service methods
- [ ] Create proper cleanup in `dispose()` method
- [ ] Update service factory with new option
- [ ] Verify service behavior with different mapper/adapter combinations

## 4. Integration Testing and Cutover

- [ ] Create integration tests for complete flow
- [ ] Test stream behavior with different implementations
- [ ] Test with various state transitions
- [ ] Test error propagation through streams
- [ ] Enable new mapper in test environment
- [ ] Run full test suite with new mapper
- [ ] Enable new service in test environment
- [ ] Run full test suite with new service
- [ ] Benchmark stream performance in both implementations
- [ ] Plan gradual production deployment

## 5. Cleanup and Code Removal

- [ ] Remove old `PlaybackStateMapperImpl` when stable
- [ ] Remove bridge adapters when safe
- [ ] Remove feature flags when stable
- [ ] Refactor to use simplified interfaces directly
- [ ] Update all tests to use new implementations
- [ ] Verify all functionality works with simplified implementation 