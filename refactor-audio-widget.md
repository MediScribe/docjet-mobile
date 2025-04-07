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

6.  **Test the Service:** Create `audio_playback_service_impl_test.dart`. Mock `AudioPlayer`. Verify service methods call player methods correctly and that player events are transformed into the `PlaybackState` stream correctly. Test error handling.
7.  **Test the Cubit:** Update `audio_list_cubit_test.dart`. Mock `AudioPlaybackService`. Test that calling cubit methods (play, pause) calls the service. Mock the service's stream and verify that events emitted by the service cause the Cubit to emit updated `AudioListLoaded` states with correct `PlaybackInfo`.
8.  **Test the Widget:** Create/Update `audio_player_widget_test.dart`. Make it a widget test. Provide a mock `AudioListCubit` using `BlocProvider`. Pump the widget with different input props (playing, paused, error, specific position/duration) and verify the UI renders correctly. Verify tapping buttons finds the mock Cubit in context and calls the correct methods.
9.  **Test the Integration:** Update `audio_recorder_list_page_test.dart`. Provide real or mocked Cubit/Service. Test scenarios like:
    *   Load list, tap play on item 1 -> Item 1 UI updates to playing.
    *   Tap play on item 2 -> Item 1 UI updates to paused/stopped, Item 2 UI updates to playing.
    *   Test seek functionality.
    *   Test error states if the service reports them and the widget displays them. 