# High-Frequency Log Demotion Checklist

**Status:** All identified high-frequency logs below have been demoted from `DEBUG` to `TRACE`. Logs intended for standard debugging remain at `DEBUG` (though some are commented out). Additionally, each relevant file now defines its own `logger` instance set to `DEBUG`.

## Adapter Layer (`audio_player_adapter_impl.dart`)

- [x] **Position Stream Listener**
  - `File:` `lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart`
  - `Context:` Raw `_audioPlayer.positionStream.listen`
  - `Example:` `[ADAPTER_RAW_POS] Position: 12345ms`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **`onPositionChanged` Stream Map**
  - `File:` `lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart`
  - `Context:` `.map()` within `get onPositionChanged`
  - `Example:` `[ADAPTER STREAM MAP] Input Position: 12345ms`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **`onDurationChanged` Stream Map**
  - `File:` `lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart`
  - `Context:` `.map()` within `get onDurationChanged`
  - `Example:` `[ADAPTER STREAM MAP] Input Duration: 60000ms`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **`onPlayerStateChanged` Stream Map (Input)**
  - `File:` `lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart`
  - `Context:` `.map()` within `get onPlayerStateChanged` (logging input state)
  - `Example:` `[ADAPTER STREAM MAP] Input PlayerState: processing=...`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **`onPlayerStateChanged` Stream Map (Output)**
  - `File:` `lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart`
  - `Context:` `.map()` within `get onPlayerStateChanged` (logging output domain state)
  - `Example:` `[ADAPTER STREAM MAP] Output DomainPlayerState: DomainPlayerState.playing`
  - `Level:` `TRACE` (Demoted from DEBUG)

## Mapper Layer (`playback_state_mapper_impl.dart`)

- [x] **Pre-Distinct Log**
  - `File:` `lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart`
  - `Context:` `_createCombinedStream().doOnData` (before `distinct`)
  - `Example:` `[MAPPER_PRE_DISTINCT] State: PlaybackState.playing(...)`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **Post-Distinct Log**
  - `File:` `lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart`
  - `Context:` `_createCombinedStream().doOnData` (after `distinct`)
  - `Example:` `[MAPPER_POST_DISTINCT] State (Emitting): PlaybackState.playing(...)`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **Distinct Comparison Logic**
  - `File:` `lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart`
  - `Context:` Inside `_areStatesEquivalent` method
  - `Example:` `[MAPPER_DISTINCT] Comparing (...)`
  - `Level:` `TRACE` (Demoted from DEBUG, if uncommented)

- [x] **Construct State Log**
  - `File:` `lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart`
  - `Context:` `_constructState()`
  - `Example:` `[MAPPER_CONSTRUCT] Trigger: Position Update`
  - `Level:` `TRACE` (Demoted from DEBUG, if uncommented)

- [ ] **Maybe Clear Error Log** (Not demoted)
  - `File:` `lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart`
  - `Context:` `_maybeClearError()`
  - `Example:` `[MAPPER_LOGIC] Clearing error...`
  - `Level:` `DEBUG` (if uncommented)

## Service Layer (`audio_playback_service_impl.dart`)

- [x] **Service RX Log**
  - `File:` `lib/features/audio_recorder/data/services/audio_playback_service_impl.dart`
  - `Context:` `_playbackStateMapper.playbackStateStream.listen`
  - `Example:` `[SERVICE_RX] Received PlaybackState from Mapper: PlaybackState.playing(...)`
  - `Level:` `TRACE` (Demoted from DEBUG)

## Cubit Layer (`audio_list_cubit.dart`)

- [x] **`_onPlaybackStateChanged` Entry Log**
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Start of `_onPlaybackStateChanged`
  - `Example:` `[CUBIT_onPlaybackStateChanged] Received PlaybackState update: ...`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [ ] **`_onPlaybackStateChanged` Internal - Current Info** (Not demoted)
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Inside `_onPlaybackStateChanged`
  - `Example:` `[CUBIT_onPlaybackStateChanged] Current PlaybackInfo: PlaybackInfo(...)`
  - `Level:` `DEBUG` (commented out)

- [ ] **`_onPlaybackStateChanged` Internal - Current Path** (Not demoted)
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Inside `_onPlaybackStateChanged`
  - `Example:` `[CUBIT_onPlaybackStateChanged] Internal _currentPlayingFilePath: some_file.mp3`
  - `Level:` `DEBUG` (commented out)

- [ ] **`_onPlaybackStateChanged` Internal - Handling State** (Not demoted)
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Inside `_onPlaybackStateChanged -> playbackState.when()`
  - `Example:` `[CUBIT_onPlaybackStateChanged] Handling playing state: pos=12345ms, dur=60000ms`
  - `Level:` `DEBUG` (commented out)

- [ ] **`_onPlaybackStateChanged` Internal - Calculated Info** (Not demoted)
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Inside `_onPlaybackStateChanged` (after `when`)
  - `Example:` `[CUBIT_onPlaybackStateChanged] Calculated New PlaybackInfo: PlaybackInfo(...)`
  - `Level:` `DEBUG` (commented out)

- [ ] **`_onPlaybackStateChanged` Internal - Comparison** (Not demoted)
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Inside `_onPlaybackStateChanged` (before `emit`)
  - `Example:` `[CUBIT_onPlaybackStateChanged] Comparison (current != new): true`
  - `Level:` `DEBUG` (commented out)

- [ ] **`_onPlaybackStateChanged` Internal - Not Emitting** (Not demoted)
  - `File:` `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
  - `Context:` Inside `_onPlaybackStateChanged` (`else` block after comparison)
  - `Example:` `[CUBIT_onPlaybackStateChanged] State is the same, not emitting.`
  - `Level:` `DEBUG` (commented out)

## UI Layer (`audio_recorder_list_page.dart`)

- [x] **UI Listener Log**
  - `File:` `lib/features/audio_recorder/presentation/pages/audio_recorder_list_page.dart`
  - `Context:` `BlocListener` inside `_AudioRecorderListViewState.build`
  - `Example:` `[AudioRecorderListView] Listener received state: AudioListLoaded`
  - `Level:` `TRACE` (Demoted from DEBUG)

- [x] **UI Builder Log**
  - `File:` `lib/features/audio_recorder/presentation/pages/audio_recorder_list_page.dart`
  - `Context:` `BlocBuilder` inside `_AudioRecorderListViewState.build`
  - `Example:` `[AudioRecorderListView] Builder received state: AudioListLoaded`
  - `Level:` `TRACE` (Demoted from DEBUG)

## UI Layer (`audio_player_widget.dart`)

- [x] **Widget Build Log**
  - `File:` `lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart`
  - `Context:` Start of `build` method
  - `Example:` `[WIDGET_BUILD ...] Props: ...`
  - `Level:` `TRACE` (Demoted from DEBUG)

## File-Specific Logger Instances

Each of the following files now contains `final logger = Logger(level: Level.debug);` directly after the imports:

- `lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart`
- `lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart`
- `lib/features/audio_recorder/data/services/audio_playback_service_impl.dart`
- `lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart`
- `lib/features/audio_recorder/presentation/pages/audio_recorder_list_page.dart`
- `lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart`

## Other Findings / Cleanup

- Numerous `DEBUG` level logs that provided intermediate details within methods (e.g., "Adapter call complete", "State Check", "Handling X state") were commented out across all layers to further reduce noise. These can be uncommented locally if deeper tracing is needed.
- Removed dead code comments and redundant log statements.
- Corrected linter errors related to lambda signatures and property access in the Cubit and Mapper that arose during refactoring. (Note: The Cubit linter errors required multiple attempts to resolve correctly due to complexities with the `PlaybackState` freezed class.)

This process allows developers to use `Level.debug` for targeted debugging within a specific file, while `Level.trace` reveals the high-frequency event flow across the entire feature when necessary. 