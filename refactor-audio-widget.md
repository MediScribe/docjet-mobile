# Refactoring Audio Playback Architecture (Consolidated)

This plan outlines the steps to refactor the audio playback logic, moving state management from individual `AudioPlayerWidget` instances to a central `AudioListCubit` interacting with a dedicated `AudioPlaybackService`.

**Phase 1: Build the Engine (The Service)**

1.  **Define the Contract (`AudioPlaybackService`):**
    *   Create in `lib/features/audio_recorder/domain/services/audio_playback_service.dart`.
    *   Define an `abstract class AudioPlaybackService`.
    *   Define methods: `Future<void> play(String filePath)`, `Future<void> pause()`, `Future<void> seek(Duration position)`, `Future<void> stop()`, `Future<void> dispose()`.
    *   Define a `Stream<PlaybackState> get playbackStateStream`.
    *   Create `lib/features/audio_recorder/domain/models/playback_state.dart`.
    *   Define a `class PlaybackState` (using `Equatable`) containing fields: `String? currentFilePath`, `bool isPlaying`, `bool isLoading`, `bool isCompleted`, `bool hasError`, `String? errorMessage`, `Duration position`, `Duration totalDuration`. Include an initial/default state.

2.  **Build the Implementation (`AudioPlaybackServiceImpl`):**
    *   Create in `lib/features/audio_recorder/data/services/audio_playback_service_impl.dart`.
    *   Implement `AudioPlaybackService`.
    *   Hold a single `final AudioPlayer _audioPlayer;` instance (from `audioplayers`). Inject via constructor for testing (e.g., `AudioPlaybackServiceImpl({required AudioPlayer audioPlayer})`), default to `AudioPlayer()` if not provided.
    *   Implement the service methods, calling corresponding `_audioPlayer` methods.
        *   Handle `AssetSource` vs `DeviceFileSource` logic explicitly within `play()`. Use relative paths for assets (e.g., remove `assets/` prefix).
        *   Ensure `play()` stops/disposes previous playback before starting new.
    *   Use `StreamController<PlaybackState>` internally to manage the `playbackStateStream`. Listeners should be managed carefully.
    *   Listen to `_audioPlayer.onPlayerStateChanged`, `onDurationChanged`, `onPositionChanged`, `onPlayerComplete`, `onLog`/`onError` streams.
    *   Translate these raw events into comprehensive `PlaybackState` objects and add them to the internal stream controller. Handle loading, playing, paused, completed, stopped, and error states correctly.
    *   Implement the `dispose()` method to close the stream controller and dispose the `_audioPlayer`.

3.  **Wire it Up (`injection_container.dart`):**
    *   Register `AudioPlaybackService` as a lazy singleton in `sl`:
        ```dart
        sl.registerLazySingleton<AudioPlaybackService>(() => AudioPlaybackServiceImpl(audioPlayer: sl()));
        // Assuming AudioPlayer itself might be registered or just create new:
        // sl.registerLazySingleton<AudioPlaybackService>(() => AudioPlaybackServiceImpl(audioPlayer: AudioPlayer()));
        // Ensure AudioPlayer is also registered if injected:
        // sl.registerLazySingleton(() => AudioPlayer());
        ```

**Phase 2: Install the Engine (Integrate with Cubit)**

4.  **Enhance `AudioListCubit`:** (`lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`)
    *   Inject `AudioPlaybackService sl()` into `AudioListCubit`'s constructor. Store it: `final AudioPlaybackService _audioPlaybackService;`.
    *   Hold a `StreamSubscription? _playbackSubscription;`.
    *   **Enhance State (`AudioListState`):** Modify `AudioListLoaded` state in `lib/features/audio_recorder/presentation/cubit/audio_list_state.dart`:
        *   Define a nested helper class/record `PlaybackInfo` (make it `Equatable`): `String? activeFilePath`, `bool isPlaying`, `bool isLoading`, `Duration currentPosition`, `Duration totalDuration`, `String? error`. Include factory for initial state.
        *   Add `final PlaybackInfo playbackInfo;` to `AudioListLoaded`. Initialize this appropriately in the constructor (e.g., `this.playbackInfo = const PlaybackInfo.initial()`). Update `copyWith` method if needed.
    *   **Add Control Methods:**
        *   `Future<void> playRecording(String filePath)`: Calls `_audioPlaybackService.play(filePath)`. Might update state to show loading immediately for the specific item if desired (though service stream might handle this).
        *   `Future<void> pauseRecording()`: Calls `_audioPlaybackService.pause()`.
        *   `Future<void> seekRecording(Duration position)`: Calls `_audioPlaybackService.seek(position)`.
        *   `Future<void> stopPlayback()`: Calls `_audioPlaybackService.stop()`.
    *   **Listen for Updates:**
        *   In the Cubit's constructor (or an init method): start listening: `_listenToPlaybackService();`.
        *   Create `void _listenToPlaybackService()` method: `_playbackSubscription = _audioPlaybackService.playbackStateStream.listen(_onPlaybackStateChanged);`.
        *   Create `void _onPlaybackStateChanged(PlaybackState playbackState)` method.
        *   Inside `_onPlaybackStateChanged`, check if the current cubit state is `AudioListLoaded`.
        *   If it is, create a new `PlaybackInfo` instance based on the incoming `playbackState`.
        *   `emit( (state as AudioListLoaded).copyWith(playbackInfo: newPlaybackInfo) );`.
    *   **Clean Up:** Override the `close()` method in the Cubit:
        ```dart
        @override
        Future<void> close() {
          _playbackSubscription?.cancel();
          // DO NOT dispose the singleton service here.
          // Optionally call stop if playback should cease when the list view is disposed:
          // _audioPlaybackService.stop();
          return super.close();
        }
        ```

**Phase 3: Rip Out the Old Transmission (Gut the Widget)**

5.  **Neuter `AudioPlayerWidget`:** (`lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart`)
    *   Change `AudioPlayerWidget` to a `StatelessWidget`.
    *   Remove the `State` class (`_AudioPlayerWidgetState`).
    *   Remove all internal state variables, `AudioPlayer` instance, stream subscriptions, `initState`, `dispose`.
    *   **Receive State Props:** The constructor will now need parameters like:
        *   `required String filePath` (already has)
        *   `required VoidCallback onDelete` (already has)
        *   `required bool isPlaying`
        *   `required bool isLoading`
        *   `required Duration currentPosition`
        *   `required Duration totalDuration`
        *   `required String? error` // To display specific errors
    *   **UI Adapts:** The `build` method will directly use these passed-in props to configure the UI (Icon, Slider value, Text displaying error).
    *   **Dispatch Events:** Button `onPressed` / Slider `onChanged` callbacks will now call `context.read<AudioListCubit>().playRecording(filePath)`, `pauseRecording()`, `seekRecording(duration)`. Ensure context is available (pass it to helper methods if extracted).
    *   **Parent Widget (`AudioRecorderListView` in `lib/features/audio_recorder/presentation/pages/audio_recorder_list_page.dart`):**
        *   Inside the `ListView.builder`'s `itemBuilder`, when creating the `AudioPlayerWidget`, wrap its creation or use `BlocSelector` to get the relevant playback state for *that specific item*.
        *   Define a helper class/record `PlaybackDisplayState` (could be a `({bool isPlaying, bool isLoading, Duration position, Duration duration, String? error})` record tuple):
        *   Inside `itemBuilder`, before building `AudioPlayerWidget`:
            ```dart
            // Assuming 'state' is the current AudioListLoaded state from BlocBuilder/BlocConsumer
            final playbackInfo = state.playbackInfo;
            final transcription = sortedTranscriptions[index]; // Current item data
            final isActiveItem = playbackInfo.activeFilePath == transcription.localFilePath;

            final displayState = PlaybackDisplayState(
              isPlaying: isActiveItem && playbackInfo.isPlaying,
              isLoading: isActiveItem && playbackInfo.isLoading,
              currentPosition: isActiveItem ? playbackInfo.currentPosition : Duration.zero,
              totalDuration: isActiveItem ? playbackInfo.totalDuration : Duration.zero, // Or fetch duration differently if needed when inactive
              error: isActiveItem ? playbackInfo.error : null,
            );

            return Card(
              // ... other card content ...
              child: Column(
                children: [
                  // ... ListTile ...
                  AudioPlayerWidget(
                    filePath: transcription.localFilePath,
                    onDelete: () => context.read<AudioListCubit>().deleteRecording(transcription.localFilePath),
                    isPlaying: displayState.isPlaying,
                    isLoading: displayState.isLoading,
                    currentPosition: displayState.currentPosition,
                    totalDuration: displayState.totalDuration,
                    error: displayState.error,
                  ),
                ],
              ),
            );
            ```
        *   Using `BlocSelector` is still a good optimization if the list rebuilds frequently for other reasons. The selector would perform the logic above to extract the `PlaybackDisplayState`.

**Phase 4: Verify the Damn Thing Works (Testing)**

6.  Test the Service: Create `audio_playback_service_impl_test.dart`. Mock `AudioPlayer`. Verify service methods call player methods correctly and that player events are transformed into the `PlaybackState` stream correctly. Test error handling.
7.  Test the Cubit: Update `audio_list_cubit_test.dart`. Mock `AudioPlaybackService`. Test that calling cubit methods (play, pause) calls the service. Mock the service's stream and verify that events emitted by the service cause the Cubit to emit updated `AudioListLoaded` states with correct `PlaybackInfo`.
8.  Test the Widget: Create/Update `audio_player_widget_test.dart`. Make it a widget test. Provide a mock `AudioListCubit` using `BlocProvider`. Pump the widget with different input props (playing, paused, error, specific position/duration) and verify the UI renders correctly. Verify tapping buttons finds the mock Cubit in context and calls the correct methods.
9.  Test the Integration: Update `audio_recorder_list_page_test.dart`. Provide real or mocked Cubit/Service. Test scenarios like:
    *   Load list, tap play on item 1 -> Item 1 UI updates to playing.
    *   Tap play on item 2 -> Item 1 UI updates to paused/stopped, Item 2 UI updates to playing.
    *   Test seek functionality.
    *   Test error states if the service reports them and the widget displays them.

**IMPORTANT TESTING NOTES (Extended Learnings from Debugging Hell):**
*   **`testWidgets` HANGS with `AudioPlayer` Instantiation:** Initial hangs occurred when using `mockito` for `AudioPlayer` within `testWidgets`, seemingly due to complex interactions between the mocking framework, async setup/teardown (even when moved inside the test), and the `testWidgets` environment.
*   **Removing Mocks Did NOT Fix Hang:** Contrary to initial assumptions, removing `mockito` entirely and instantiating the *real* `AudioPlayer` within `testWidgets` *still* resulted in hangs. The hang occurred specifically during `AudioPlayer()` instantiation, regardless of whether it was in the constructor or delayed until after the first `tester.pump()`.
*   **Conclusion:** Instantiating the real `AudioPlayer` (which likely involves initializing native platform channels) is fundamentally incompatible with the `testWidgets` environment, causing deadlocks/hangs.
*   **Plain `test()` Runs But Hits `MissingPluginException`:** Switching the problematic lifecycle tests from `testWidgets()` to plain `test()` resolved the hang. However, when using the *real* `AudioPlayer` in a plain `test()` environment, calls to native methods (like `create`, `stop`, `release`) fail with `MissingPluginException`. This is because the necessary native plugin implementations aren't available in a pure Dart VM test.
*   **`TestWidgetsFlutterBinding.ensureInitialized()`:** Required at the start of `main()` in plain `test()` files that interact with Flutter plugins (like `audioplayers`) to set up the framework side of platform channels.
*   **Stream Assertion Timing:** Plain `test()` timing differs from `testWidgets()`. Asserting stream states requires `expectLater` or careful use of `await Future.delayed(Duration.zero)` to allow async events to propagate (e.g., `expect(states.first, ...)` failed due to the list being empty).

**Current Status & Revised Testing Strategy:**

1.  **Status:** Service code refactored for lazy initialization. Lifecycle tests (`audio_playback_service_lifecycle_test.dart`) converted to plain `test()` to avoid hangs, but currently failing due to `MissingPluginException` when using the real player and stream timing issues.
2.  **Revised Strategy:** Mock `AudioPlayer` within the plain `test()` environment for the service tests (`audio_playback_service_*.dart`). This avoids both the `testWidgets` hang *and* the `MissingPluginException` while allowing verification of the service's logic and its interactions with the (mocked) player.
    *   Use `mockito` for `AudioPlayer`.
    *   Run tests using `flutter test` (or `dart test` if no Flutter dependencies remain after mocking).
    *   Use `expectLater` for stream assertions.
    *   Verify calls to mocked player methods (`stop`, `release`, `dispose`, etc.).
3.  **Next Steps:**
    *   Reintroduce `mockito` to `audio_playback_service_lifecycle_test.dart`.
    *   Add optional `AudioPlayer` parameter back to `AudioPlaybackServiceImpl` constructor for mock injection.
    *   Run `build_runner`.
    *   Fix the lifecycle tests using mocks and `expectLater`.
    *   Restore and adapt other service test files (`play`, `pause_seek_stop`, `event_handling`) using the `test()` + mock pattern.
    *   Consider separate `integration_test` if testing real audio playback on a device/emulator is required later.

**Original Debugging Notes (Still potentially relevant for context):**
*   **Initialization within `testWidgets` is FICKLE:** Initial attempts to instantiate `AudioPlaybackServiceImpl` or register its listeners (even mocked ones) in a global `setUp` or early in a `testWidgets` block before the first `tester.pump()` caused persistent hangs.
*   **Avoid `setUp` for Service Instantiation:** Do **NOT** instantiate `AudioPlaybackServiceImpl` in a global `setUp` block when using `testWidgets`. Instantiate it *directly within each* `testWidgets` block.
*   **Initialization Sequence:**
    1.  Instantiate the service: `service = AudioPlaybackServiceImpl(...)`.
    2.  Pump **immediately**: `await tester.pump();`.
    3.  Attach listeners if needed: `final sub = service.playbackStateStream.listen(...)`.
    4.  Initialize listeners: `service.initializeListeners();` (Prefer synchronous `void` if possible).
    5.  Pump again: `await tester.pump();`.
*   **Synchronous Initialization Preferred:** The hangs seemed related to `async` operations during initialization within the test environment. Make initialization steps like creating controllers or registering listeners synchronous (`void`) where feasible.
*   **Global `setUp`/`tearDown` Interference:** There appears to be a cursed interaction where even *unused* mocks or controllers created in global `setUp` can interfere with `testWidgets` execution after the first pump. Be wary of complex global setup when debugging hangs.
*   **Splitting Tests:** While splitting the large test file helped organization, it did not resolve the underlying initialization hang. The core issue was the timing and context of initialization relative to `tester.pump()`.

**Current Status & Next Steps (as of debugging hangs):**

1.  **Status:** Service code refactored for synchronous initialization. Tests confirmed to hang due to mocking infrastructure interference in `testWidgets`, not the service logic itself.
2.  **Run `build_runner`:** Done.
3.  **Run Lifecycle Test with Mocks:** Execute `audio_playback_service_lifecycle_test.dart` (now fully restored with mocks and sync init pattern).
    *   **If PASSES:** Great! Restore other test files (`play`, `pause_seek_stop`, `event_handling`) using the confirmed pattern and uncomment their internal logic.
    *   **If HANGS:** Mockito for `AudioPlayer` in `testWidgets` is likely untenable. **Investigate Alternatives:** Platform channel mocking, different mock library, or shift strategy away from mocking `AudioPlayer` directly in `testWidgets`. 