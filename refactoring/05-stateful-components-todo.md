# Stateful Components Refactoring Todo List

## 1. Move File Path Context to the Adapter

- [ ] Create test file for enhanced adapter
- [ ] Write test for `currentFilePath` tracking
- [ ] Update `AudioPlayerAdapterV3` interface
- [ ] Implement `AudioPlayerAdapterV3Impl` class
- [ ] Add `_currentFilePath` field to track file path
- [ ] Update `setSourceUrl()` to store current file path
- [ ] Add `currentFilePath` getter
- [ ] Update existing bridge adapters
- [ ] Test file path is correctly tracked during playback
- [ ] Verify file path is available to higher layers

## 2. Implement a State Machine Approach in the Service

- [ ] Create test file for state machine service
- [ ] Write tests for state transitions
- [ ] Define `PlayerOperation` enum
- [ ] Create `AudioPlaybackServiceV4Impl` class
- [ ] Implement `_reduceState()` method
- [ ] Handle state transition for `play` operation
- [ ] Handle state transition for `pause` operation
- [ ] Handle state transition for `resume` operation
- [ ] Handle state transition for `seek` operation
- [ ] Handle state transition for `stop` operation
- [ ] Handle state transition for `complete` operation
- [ ] Update `play()` to use state machine approach
- [ ] Update other methods with state machine approach
- [ ] Create service factory with feature flag
- [ ] Test state transitions for all operations

## 3. Use a State-First Approach in the Cubit

- [ ] Create test file for improved cubit
- [ ] Write tests for UI state updates
- [ ] Update `AudioListCubit` implementation
- [ ] Remove `_currentPlayingFilePath` tracking
- [ ] Implement direct state mapping from service state
- [ ] Create `_mapPlaybackStateToInfo()` helper
- [ ] Update `playRecording()` to update state immediately
- [ ] Update `pausePlayback()` to update state immediately
- [ ] Update `resumePlayback()` to update state immediately
- [ ] Update `stopPlayback()` to update state immediately
- [ ] Update `seekRecording()` to update state immediately
- [ ] Test cubit state updates correctly with service state changes

## 4. Simplify Widget State

- [ ] Create test file for simplified widget
- [ ] Write tests for widget state handling
- [ ] Update `AudioPlayerWidget` implementation
- [ ] Remove redundant state variables
- [ ] Keep only local UI state like `_isDragging`
- [ ] Update `didUpdateWidget()` to handle state properly
- [ ] Simplify slider handling
- [ ] Add proper time display formatting
- [ ] Test widget behavior with different inputs
- [ ] Verify no state synchronization issues

## 5. Integration Testing and Cutover

- [ ] Create integration tests for full flow
- [ ] Test different playback scenarios
- [ ] Test consistent state across all layers
- [ ] Enable adapter feature flag in test environment
- [ ] Run test suite with new adapter
- [ ] Enable service feature flag in test environment
- [ ] Run test suite with new service
- [ ] Enable cubit improvements in test environment
- [ ] Run test suite with all improvements
- [ ] Plan gradual production deployment with feature flags 