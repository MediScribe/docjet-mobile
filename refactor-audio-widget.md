# Refactoring Audio Playback Architecture (TDD Approach)

**Goal:** Move audio playback state management from individual `AudioPlayerWidget` instances to a central `AudioListCubit` interacting with a dedicated, **cleanly architected**, and **testable** `AudioPlaybackService`. We use TDD where feasible.

**Problem Statement (Lesson Learned):** The initial `AudioPlaybackServiceImpl` became a monolith, mixing direct player interaction, complex event stream translation, and state management. This made unit testing, especially asynchronous stream logic, difficult and unreliable (e.g., hanging tests).

**New Strategy:** Refactor the service layer *first* by separating concerns before integrating with the `AudioListCubit`.

**Current Status:** Service refactoring underway. Files deleted during mock generation issues, need recreation or restoration.

**Existing Code Structure:**

*   **Monolithic Service:** `lib/features/audio_recorder/data/services/audio_playback_service_impl.dart` currently handles player interaction, state management, and stream processing directly, confirming the need for this refactor.
*   **Split Service Tests:** Tests for the service are already split across multiple files in `test/features/audio_recorder/data/services/` (e.g., `_play_test.dart`, `_event_handling_test.dart`, `_pause_seek_stop_test.dart`, `_lifecycle_test.dart`). These will need significant refactoring or replacement (per Step 68). A minimal generic file (`audio_playback_service_impl_test.dart`) also currently exists but is planned for deletion (Step 67).
*   **Partially Refactored Cubit/State:** `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart` and `audio_list_state.dart` already incorporate the `PlaybackInfo` concept and basic service interaction logic (aligning with parts of Phase 4).
*   **Partially Refactored Widget:** `lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart` is a `StatelessWidget` driven by props passed from the Cubit (aligning with parts of Phase 5).

## TODO List

**Phase 1: Service Refactoring - Isolate Dependencies (Adapter)**

*   [x] **1.** Create directory `lib/features/audio_recorder/domain/adapters`.
*   [x] **2.** Define `AudioPlayerAdapter` interface in `audio_player_adapter.dart` with raw methods and streams.
*   [x] **3.** Create directory `lib/features/audio_recorder/data/adapters`.
*   [x] **4.** Implement `AudioPlayerAdapterImpl` in `audio_player_adapter_impl.dart`, injecting `AudioPlayer`.
*   [x] **5.** Delegate adapter methods directly to the `AudioPlayer`.
*   [x] **6.** Expose raw `AudioPlayer` streams directly in the adapter.
*   [x] **7.** Create directory `test/features/audio_recorder/data/adapters`.
*   [x] **8.** Create `audio_player_adapter_impl_test.dart` test file.
*   [x] **9.** Add `@GenerateMocks([AudioPlayer])` to the test file.
*   [x] **10.** Run `flutter pub run build_runner build --delete-conflicting-outputs` to generate mocks.
*   [x] **11.** Write test verifying `play()` delegates correctly.
*   [x] **12.** Write test verifying `pause()` delegates correctly.
*   [x] **13.** Write test verifying `resume()` delegates correctly.
*   [x] **14.** Write test verifying `seek()` delegates correctly.
*   [x] **15.** Write test verifying `stop()` delegates correctly.
*   [x] **16.** Write test verifying `setSource()` delegates correctly.
*   [x] **17.** Write test verifying `dispose()` delegates correctly (checks `release` and `dispose`).
*   [x] **18.** Write test verifying `onPlayerStateChanged` stream is exposed correctly.
*   [x] **19.** Write test verifying `onDurationChanged` stream is exposed correctly.
*   [x] **20.** Write test verifying `onPositionChanged` stream is exposed correctly.
*   [x] **21.** Write test verifying `onPlayerComplete` stream is exposed correctly.
*   [ ] **22.** Write test verifying `onLog` stream is exposed correctly. Skipped for now, deemed superflous.

**Phase 2: Service Refactoring - Isolate Logic (State Mapper)**

*   [x] **23.** Create directory `lib/features/audio_recorder/domain/mappers`.
*   [x] **24.** Define `PlaybackStateMapper` interface in `playback_state_mapper.dart` with mapping method signature.
*   [x] **25.** Create directory `lib/features/audio_recorder/data/mappers`.
*   [x] **26.** Implement `PlaybackStateMapperImpl` in `playback_state_mapper_impl.dart`.
*   [x] **27.** Move stream listening logic (from old `_registerListeners`) into the mapper.
*   [x] **28.** Move state update logic (from old `_updateState`) into the mapper.
*   [x] **29.** Use stream transformations (e.g., `rxdart` if needed) to map raw streams to `Stream<PlaybackState>`.
*   [x] **30.** Handle stream errors within the mapper, incorporating them into `PlaybackState`.
*   [x] **31.** Create directory `test/features/audio_recorder/data/mappers`.
*   [x] **32.** Create `playback_state_mapper_impl_test.dart` test file.
*   [x] **33.** Write test using `StreamController` to verify mapping for `PlayerState.playing` event.
*   [x] **34.** Write test using `StreamController` to verify mapping for `onDurationChanged` event.
*   [x] **35.** Write test using `StreamController` to verify mapping for `onPositionChanged` event.
*   [x] **36.** Write test using `StreamController` to verify mapping for `PlayerState.paused` event.
*   [x] **37.** Write test using `StreamController` to verify mapping for `PlayerState.stopped` event.
*   [x] **38.** Write test using `StreamController` to verify mapping for `onPlayerComplete` event.
*   [x] **39.** Write test using `StreamController` to verify mapping for error events (`onLog` or `onError`).
*   [x] **40.** Write test verifying combined sequences of events map to correct states (e.g., play -> pause -> resume).

**Phase 3: Service Refactoring - Orchestration & DI**

*   [x] **41.** Refactor `AudioPlaybackServiceImpl` (`lib/.../data/services/audio_playback_service_impl.dart`).
*   [x] **42.** Add `AudioPlayerAdapter` and `PlaybackStateMapper` constructor injection.
*   [x] **43.** Remove direct `AudioPlayer` field and `_playerInjected` flag.
*   [x] **44.** Remove internal stream controllers (`_playbackStateController`) and subscriptions (`_durationSubscription`, etc.).
*   [x] **45.** Remove `initializeListeners` and `_registerListeners` methods.
*   [x] **46.** Remove `_updateState` and `_handleError` methods (logic moved to mapper).
*   [x] **47.** Implement `play()` method: Call adapter `setSource`, then `resume`. Handle potential errors briefly (or let mapper handle via stream).
*   [x] **48.** Implement `pause()` method: Call adapter `pause()`.
*   [x] **49.** Implement `resume()` method: Call adapter `resume()`.
*   [x] **50.** Implement `seek()` method: Call adapter `seek()`.
*   [x] **51.** Implement `stop()` method: Call adapter `stop()`.
*   [x] **52.** Implement `playbackStateStream` getter: Return stream from the injected mapper.
*   [x] **53.** Implement `dispose()` method: Call adapter `dispose()`.
*   [x] **54.** Adapt existing service tests or create new `audio_playback_service_orchestration_test.dart`.
*   [x] **55.** Add mocks for `AudioPlayerAdapter`

**Note on Widget Testing:**

*   [x] **Widget Unit Tests Completed:** The `AudioPlayerWidget` (`lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart`) has been thoroughly unit tested (`test/features/audio_recorder/presentation/widgets/audio_player_widget_test.dart`). These tests verify its rendering based on props (loading, error, playing states) and confirm that user interactions (play, pause, delete taps, slider seek) correctly trigger the expected callbacks/Cubit methods (verified via mocks).

**Phase 4: Cubit Integration**