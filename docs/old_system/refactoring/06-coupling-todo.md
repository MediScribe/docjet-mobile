# Coupling Reduction Refactoring Todo List

## 1. Create a PlaybackRequest Object

- [ ] Create test file for PlaybackRequest
- [ ] Write tests for PlaybackRequest creation and properties
- [ ] Write tests for `copyWith()` functionality
- [ ] Create `PlaybackRequest` class
- [ ] Add `filePath` property
- [ ] Add `initialPosition` property
- [ ] Add `autoStart` property
- [ ] Add `loop` property
- [ ] Implement `copyWith()` method
- [ ] Implement `toString()` method
- [ ] Test serialization if needed
- [ ] Verify PlaybackRequest correctly encapsulates parameters

## 2. Create a PlaybackSession in the Service

- [ ] Create test file for PlaybackSession
- [ ] Write tests for session creation
- [ ] Write tests for state transitions
- [ ] Write tests for session lifecycle
- [ ] Create `PlaybackSession` class
- [ ] Add `request`, `state`, and `id` properties
- [ ] Implement factory constructor
- [ ] Implement `copyWith()` method
- [ ] Implement `withState()` helper method
- [ ] Create `AudioPlaybackServiceV5` interface
- [ ] Add session-based methods to interface
- [ ] Implement `AudioPlaybackServiceV5Impl` class
- [ ] Add session management
- [ ] Implement state change handling
- [ ] Implement error handling
- [ ] Implement all service methods
- [ ] Create service factory with feature flag
- [ ] Create bridge adapter for backward compatibility
- [ ] Test service with different playback requests

## 3. Update Cubit to Use Session-Based API

- [ ] Create test file for session-based cubit
- [ ] Write tests for session handling
- [ ] Write tests for UI state updates
- [ ] Create `AudioListCubitV2` class
- [ ] Add session subscription
- [ ] Implement `_onSessionChanged()` method
- [ ] Create `_mapSessionToPlaybackInfo()` helper
- [ ] Update playback methods to use request objects
- [ ] Create bridge to legacy cubit if needed
- [ ] Test all cubit operations
- [ ] Verify UI updates correctly

## 4. Create Advanced Playback Features

- [ ] Create test file for advanced features
- [ ] Write tests for playlist functionality
- [ ] Write tests for looping
- [ ] Write tests for position setting
- [ ] Create `Playlist` class
- [ ] Create `PlaylistService` interface
- [ ] Add playlist methods (create, update, delete)
- [ ] Create `PlaylistCubit` for UI interaction
- [ ] Implement playlist loading
- [ ] Implement playlist playback
- [ ] Create playlist repository
- [ ] Test playlist functionality
- [ ] Verify smooth playback transitions

## 5. Integration Testing and Cutover

- [ ] Create integration tests for session-based flow
- [ ] Test playlist functionality
- [ ] Test advanced features like looping
- [ ] Test context-based operations
- [ ] Enable session-based service in test environment
- [ ] Run test suite with new service
- [ ] Enable session-based cubit in test environment
- [ ] Run test suite with new cubit
- [ ] Enable advanced features in test environment
- [ ] Run test suite with all features
- [ ] Plan production deployment with feature flags 