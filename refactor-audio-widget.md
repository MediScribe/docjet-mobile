# Refactoring Audio Playback Architecture

This plan outlines the steps to refactor the audio playback logic, moving state management from individual `AudioPlayerWidget` instances to a central `AudioListCubit` interacting with a dedicated `AudioPlaybackService`. This addresses issues like simultaneous playback and lack of central control.

## Phase 1: Build the Engine (The Service)

1.  **Define the Contract (`AudioPlaybackService`):**
    *   Create `lib/core/services/audio_playback_service.dart` (or `lib/features/audio_recorder/domain/services/`).
    *   Define an `abstract class AudioPlaybackService`.
    *   Define methods: `Future<void> play(String filePath)`, `Future<void> pause()`, `Future<void> seek(Duration position)`, `Future<void> stop()`, `Future<void> dispose()`.
    *   Define a `Stream<PlaybackState> get playbackStateStream`.
    *   Create a `lib/core/models/playback_state.dart` (or similar location).
    *   Define a `class PlaybackState` (likely using `Equatable`) containing fields: `String? filePath`, `bool isPlaying`, `bool isLoading`, `bool hasError`, `String? errorMessage`, `Duration position`, `Duration totalDuration`. Include an initial/default state.

2.  **Build the Implementation (`AudioPlaybackServiceImpl`):**
    *   Create `lib/features/audio_recorder/data/services/audio_playback_service_impl.dart`.
    *   Implement `AudioPlaybackService`.
    *   Hold a single `final AudioPlayer _audioPlayer;` instance (from `audioplayers` package).
    *   Inject `AudioPlayer` potentially via constructor for testing, default to `AudioPlayer()`.
    *   Implement the service methods, calling corresponding `_audioPlayer` methods.
        *   Handle `AssetSource` vs `DeviceFileSource` logic internally within `play()`, using relative paths for assets.
        *   Ensure `play()` stops/disposes previous playback before starting new.
    *   Use `StreamController<PlaybackState>` internally to manage the `playbackStateStream`.
    *   Listen to `_audioPlayer.onPlayerStateChanged`, `onDurationChanged`, `onPositionChanged`, `onPlayerComplete`, `onLog` streams.
    *   Translate these raw events into comprehensive `PlaybackState` objects and add them to the internal stream controller. Handle loading, playing, paused, completed, and error states correctly.
    *   Implement the `dispose()` method to close the stream controller and dispose the `_audioPlayer`.

3.  **Wire it Up (`injection_container.dart`):**
    *   Register `AudioPlaybackService` as a lazy singleton in `sl`:
        ```dart
        sl.registerLazySingleton<AudioPlaybackService>(() => AudioPlaybackServiceImpl());
        ```

## Phase 2: Install the Engine (Integrate with Cubit)

4.  **Give the Cubit the Keys (`AudioListCubit`):**
    *   Inject `AudioPlaybackService sl()` into `AudioListCubit`'s constructor.
    *   Store it: `final AudioPlaybackService _audioPlaybackService;`.
    *   Hold a `StreamSubscription? _playbackSubscription;`.
    *   **Enhance State (`AudioListState`):** Modify `AudioListLoaded` state:
        *   Add fields: `String? activePlaybackFilePath`, `bool isPlaybackLoading`, `bool isPlaying`, `Duration currentPosition`, `Duration totalDuration`, `String? playbackError`. Initialize these appropriately.
    *   **Add Control Methods:**
        *   `Future<void> playRecording(String filePath)`: Calls `_audioPlaybackService.play(filePath)`. Might update state to show loading immediately.
        *   `Future<void> pauseRecording()`: Calls `_audioPlaybackService.pause()`.
        *   `Future<void> seekRecording(Duration position)`: Calls `_audioPlaybackService.seek(position)`.
        *   `Future<void> stopPlayback()`: Calls `_audioPlaybackService.stop()`. (Useful if needed)
    *   **Listen for Updates:**
        *   In the Cubit's constructor or an init method, start listening: `_playbackSubscription = _audioPlaybackService.playbackStateStream.listen(_onPlaybackStateChanged);`.
        *   Create `void _onPlaybackStateChanged(PlaybackState playbackState)` method.
        *   Inside `_onPlaybackStateChanged`, if the current cubit state is `AudioListLoaded`, update its playback-related fields based on the incoming `playbackState` and `emit()` the new `AudioListLoaded` state.
    *   **Clean Up:** Override the `close()` method in the Cubit:
        ```dart
        @override
        Future<void> close() {
          _playbackSubscription?.cancel();
          // Optionally call _audioPlaybackService.stop() or dispose() if the service is only used here.
          return super.close();
        }
        ```

## Phase 3: Rip Out the Old Transmission (Gut the Widget)

5.  **Neuter `AudioPlayerWidget`:**
    *   Change `AudioPlayerWidget` to a `StatelessWidget`.
    *   Remove the `State` class (`_AudioPlayerWidgetState`).
    *   Remove all internal state variables and `AudioPlayer` instance.
    *   **Receive State Props:** The constructor will now need parameters like:
        *   `required String filePath` (already has)
        *   `required VoidCallback onDelete` (already has)
        *   `required bool isCurrentlyPlaying`
        *   `required bool isPlaybackLoading` // To show loading indicator maybe
        *   `required Duration currentPosition`
        *   `required Duration totalDuration`
        *   `required String? playbackError` // To display specific errors
    *   **UI Adapts:** The `build` method will directly use these passed-in props to configure the UI (Icon, Slider value, Text).
    *   **Dispatch Events:** Button `onPressed` / Slider `onChanged` callbacks will now call `context.read<AudioListCubit>().playRecording(filePath)`, `pauseRecording()`, `seekRecording(duration)`.
    *   **Parent Widget (`AudioRecorderListView`):**
        *   Inside the `ListView.builder`, wrap the `AudioPlayerWidget` creation with a `BlocSelector<AudioListCubit, AudioListState, PlaybackDisplayState>` (where `PlaybackDisplayState` is a small helper class/record holding just the props needed by the widget for *that specific item*).
        *   The `selector` function will check if the `state` is `AudioListLoaded` and if `state.activePlaybackFilePath == transcription.localFilePath`, and return the relevant props (`isPlaying`, `currentPosition`, etc.). Otherwise, return default/inactive state props.
        *   Pass the selected state down to the `AudioPlayerWidget`.

## Phase 4: Verify the Damn Thing Works (Testing)

6.  **Test the Service:** Create `audio_playback_service_impl_test.dart`. Mock `AudioPlayer` using Mockito/Mocktail. Verify service methods call player methods correctly and that player events are transformed into the `PlaybackState` stream correctly.
7.  **Test the Cubit:** Create/Update `audio_list_cubit_test.dart`. Mock `AudioPlaybackService`. Test that calling cubit methods (play, pause) calls the service. Mock the service's stream and verify that events emitted by the service cause the Cubit to emit updated `AudioListLoaded` states.
8.  **Test the Widget:** Create/Update `audio_player_widget_test.dart`. Make it a widget test. Provide a mock `AudioListCubit` using `BlocProvider`. Pump the widget with different input props (playing, paused, specific position/duration) and verify the UI renders correctly (correct icon, slider value). Verify tapping buttons finds the mock Cubit in context and calls the correct methods (`playRecording`, `pauseRecording`, etc.).
9.  **Test the Integration:** Update `audio_recorder_list_page_test.dart`. Provide real Cubit/Service or mocked versions. Test scenarios like:
    *   Load list, tap play on item 1 -> UI updates to playing.
    *   Tap play on item 2 -> Item 1 UI updates to paused/stopped, item 2 UI updates to playing.
    *   Test seek functionality.
    *   Test error states if the service reports them. 