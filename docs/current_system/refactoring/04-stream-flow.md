# Step 4: Simplify Stream Flow

## Overview

This step focuses on reducing the complexity of the stream flow in the PlaybackStateMapper, which currently manages five separate streams and their internal state.

**Estimated time:** 9 days

## Problem Statement

The current `PlaybackStateMapperImpl` manages **five separate `StreamController`s**:

```dart
final positionController = StreamController<Duration>.broadcast();
final durationController = StreamController<Duration>.broadcast();
final completeController = StreamController<void>.broadcast();
final playerStateController = StreamController<DomainPlayerState>.broadcast();
final errorController = StreamController<String>.broadcast();
```

Each controller has associated subscriptions and maintains its own piece of state:

```dart
DomainPlayerState _currentPlayerState = DomainPlayerState.initial;
Duration _currentDuration = Duration.zero;
Duration _currentPosition = Duration.zero;
String? _currentError;
```

This creates a complex flow where:
1. Events come from `just_audio` into the `AudioPlayerAdapter`
2. `AudioPlayerAdapter` forwards these to streams that emit `DomainPlayerState`s, `Duration`s, etc.
3. `PlaybackStateMapper` subscribes to all adapter streams and pipes them into internal controllers
4. These controllers trigger updates to internal state variables
5. The mapper then combines this state to create a unified `PlaybackState`
6. This all happens through a complex RxDart pipeline with multiple operators

## Implementation Steps

### 4.1 Create a Simpler Mapper Interface (2 days)

1. **Write Tests**
   - Create tests for the simplified mapper interface
   - Test stream combination behavior

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/mappers/playback_state_mapper_v2.dart

abstract class PlaybackStateMapperV2 {
  /// The unified stream of playback states.
  Stream<PlaybackState> get playbackStateStream;
  
  /// Initializes the mapper with the core streams needed for state mapping.
  void initialize({
    required Stream<PlayerState> playerStateStream, 
    required Stream<Duration> positionStream,
    required Stream<Duration?> durationStream,
  });
  
  /// Cleans up resources.
  void dispose();
}

// lib/features/audio_recorder/data/mappers/playback_state_mapper_v2_impl.dart

class PlaybackStateMapperV2Impl implements PlaybackStateMapperV2 {
  // Single output stream
  late final Stream<PlaybackState> _playbackStateStream;
  
  // Subscription to the combined stream for cleanup
  StreamSubscription<PlaybackState>? _combinedStreamSubscription;
  
  // Stream controller for the output stream
  final _outputController = BehaviorSubject<PlaybackState>.seeded(
    const PlaybackState.initial()
  );
  
  @override
  Stream<PlaybackState> get playbackStateStream => _outputController.stream;
  
  @override
  void initialize({
    required Stream<PlayerState> playerStateStream,
    required Stream<Duration> positionStream,
    required Stream<Duration?> durationStream,
  }) {
    final tag = logTag(PlaybackStateMapperV2Impl);
    logger.d('$tag initialize: Creating combined stream');
    
    // Create a combined stream that emits a new state whenever any input changes
    final combinedStream = Rx.combineLatest3<PlayerState, Duration, Duration?, PlaybackState>(
      playerStateStream,
      positionStream,
      durationStream,
      (playerState, position, duration) {
        return _mapToPlaybackState(
          playerState, 
          position, 
          duration ?? Duration.zero,
        );
      },
    )
    .debounceTime(const Duration(milliseconds: 80))
    .distinct();
    
    // Subscribe to the combined stream and forward events to the output controller
    _combinedStreamSubscription = combinedStream.listen(
      (state) {
        logger.t('$tag Combined stream emitted: ${formatPlaybackState(state)}');
        _outputController.add(state);
      },
      onError: (e, s) {
        logger.e('$tag Error in combined stream', error: e, stackTrace: s);
        final audioError = e is AudioError 
            ? e 
            : AudioError.fromException(e, s);
        _outputController.add(PlaybackState.error(
          message: audioError.message,
          errorType: audioError.type,
        ));
      },
    );
    
    logger.d('$tag initialize: Combined stream setup complete');
  }
  
  @override
  void dispose() {
    logger.d('$tag dispose: Cleaning up resources');
    _combinedStreamSubscription?.cancel();
    _outputController.close();
  }
  
  /// Maps the raw player state and timing information to a domain PlaybackState
  PlaybackState _mapToPlaybackState(
    PlayerState playerState, 
    Duration position, 
    Duration duration,
  ) {
    final tag = logTag(PlaybackStateMapperV2Impl);
    logger.t('$tag Mapping state: playing=${playerState.playing}, processing=${playerState.processingState}, pos=${position.inMilliseconds}ms, dur=${duration.inMilliseconds}ms');
    
    // Map from just_audio's ProcessingState to our domain PlaybackState
    switch (playerState.processingState) {
      case ProcessingState.idle:
        return const PlaybackState.stopped();
        
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return const PlaybackState.loading();
        
      case ProcessingState.ready:
        if (playerState.playing) {
          return PlaybackState.playing(
            currentPosition: position,
            totalDuration: duration,
          );
        } else {
          return PlaybackState.paused(
            currentPosition: position,
            totalDuration: duration,
          );
        }
        
      case ProcessingState.completed:
        return const PlaybackState.completed();
    }
  }
}
```

3. **Create Factory and Adapters**

```dart
// lib/features/audio_recorder/data/factories/playback_state_mapper_factory.dart

class PlaybackStateMapperFactory {
  static bool useNewMapperImplementation = false;
  
  static PlaybackStateMapper create() {
    if (useNewMapperImplementation) {
      return _MapperBridge(PlaybackStateMapperV2Impl());
    } else {
      return PlaybackStateMapperImpl();
    }
  }
}

/// Bridge adapter that implements the old interface but delegates to new implementation
class _MapperBridge implements PlaybackStateMapper {
  final PlaybackStateMapperV2 _newMapper;
  
  _MapperBridge(this._newMapper);
  
  @override
  Stream<PlaybackState> get playbackStateStream => _newMapper.playbackStateStream;
  
  @override
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<DomainPlayerState> playerStateStream,
  }) {
    // Map DomainPlayerState stream to PlayerState stream
    final playerStateStream2 = playerStateStream.map((domainState) {
      // Convert domain state to just_audio PlayerState equivalent
      switch (domainState) {
        case DomainPlayerState.initial:
          return PlayerState(false, ProcessingState.idle);
        case DomainPlayerState.loading:
          return PlayerState(false, ProcessingState.loading);
        case DomainPlayerState.playing:
          return PlayerState(true, ProcessingState.ready);
        case DomainPlayerState.paused:
          return PlayerState(false, ProcessingState.ready);
        case DomainPlayerState.stopped:
          return PlayerState(false, ProcessingState.idle);
        case DomainPlayerState.completed:
          return PlayerState(false, ProcessingState.completed);
        case DomainPlayerState.error:
          // This is handled separately in the error stream
          return PlayerState(false, ProcessingState.idle);
      }
    });
    
    // Initialize the new mapper with the converted streams
    _newMapper.initialize(
      playerStateStream: playerStateStream2,
      positionStream: positionStream,
      durationStream: durationStream.map((d) => d),
    );
  }
  
  @override
  void dispose() => _newMapper.dispose();
}
```

4. **Update DI Registration**

```dart
// lib/core/di/injection_container.dart

sl.registerLazySingleton<PlaybackStateMapper>(
  () => PlaybackStateMapperFactory.create(),
);
```

5. **Verification**
   - Run mapper tests to verify behavior
   - Ensure that PlaybackStateMapper and PlaybackStateMapperV2 work identically

### 4.2 Create Direct Adapter Stream Access (2 days)

1. **Write Tests**
   - Test that adapter correctly exposes the required streams
   - Verify stream behavior matches just_audio's behavior

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/adapters/audio_player_adapter_v2.dart

abstract class AudioPlayerAdapterV2 {
  // Other methods...
  
  /// Stream of just_audio PlayerState changes.
  /// This is a more direct representation of the player's state.
  Stream<PlayerState> get playerStateStream;
  
  /// Stream of position changes.
  Stream<Duration> get positionStream;
  
  /// Stream of duration changes.
  Stream<Duration?> get durationStream;
}

// lib/features/audio_recorder/data/adapters/audio_player_adapter_v2_impl.dart

class AudioPlayerAdapterV2Impl implements AudioPlayerAdapterV2 {
  final AudioPlayer _audioPlayer;
  
  // Other methods...
  
  @override
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  
  @override
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  
  @override
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
}
```

3. **Add to Bridge Adapter**

```dart
// Update in _LegacyAdapterBridge class

@override
Stream<PlayerState> get playerStateStream => _newAdapter.playerStateStream;

@override
Stream<Duration> get positionStream => _newAdapter.positionStream;

@override
Stream<Duration?> get durationStream => _newAdapter.durationStream;

// Map these to the older streams
@override
Stream<DomainPlayerState> get onPlayerStateChanged => 
  playerStateStream.map(_mapToDomainState);

@override
Stream<Duration> get onPositionChanged => positionStream;

@override
Stream<Duration> get onDurationChanged => 
  durationStream.where((d) => d != null).map((d) => d!);

@override
Stream<void> get onPlayerComplete => 
  playerStateStream
      .where((state) => state.processingState == ProcessingState.completed)
      .map((_) => null);

// Helper method to map PlayerState to DomainPlayerState
DomainPlayerState _mapToDomainState(PlayerState state) {
  switch (state.processingState) {
    case ProcessingState.idle:
      return DomainPlayerState.stopped;
    case ProcessingState.loading:
    case ProcessingState.buffering:
      return DomainPlayerState.loading;
    case ProcessingState.ready:
      return state.playing 
          ? DomainPlayerState.playing 
          : DomainPlayerState.paused;
    case ProcessingState.completed:
      return DomainPlayerState.completed;
  }
}
```

4. **Verification**
   - Run adapter tests
   - Verify that both interfaces provide the expected stream behavior

### 4.3 Create New Service Implementation (3 days)

1. **Write Tests**
   - Test that the service correctly initializes the mapper
   - Verify the service responds to state changes correctly

2. **Implementation**

```dart
// lib/features/audio_recorder/data/services/audio_playback_service_v3_impl.dart

class AudioPlaybackServiceV3Impl implements AudioPlaybackService {
  final AudioPlayerAdapterV2 _audioPlayerAdapter;
  final PlaybackStateMapperV2 _playbackStateMapper;
  
  final BehaviorSubject<PlaybackState> _playbackStateSubject;
  late final StreamSubscription<PlaybackState> _mapperSubscription;
  
  AudioPlaybackServiceV3Impl({
    required AudioPlayerAdapterV2 audioPlayerAdapter,
    required PlaybackStateMapperV2 playbackStateMapper,
  }) : _audioPlayerAdapter = audioPlayerAdapter,
       _playbackStateMapper = playbackStateMapper,
       _playbackStateSubject = BehaviorSubject<PlaybackState>() {
    
    final tag = logTag(AudioPlaybackServiceV3Impl);
    logger.d('$tag Constructor: Initializing service');
    
    // Initialize the mapper with the adapter's streams
    _playbackStateMapper.initialize(
      playerStateStream: _audioPlayerAdapter.playerStateStream,
      positionStream: _audioPlayerAdapter.positionStream,
      durationStream: _audioPlayerAdapter.durationStream,
    );
    
    // Subscribe to the mapper's state stream
    _mapperSubscription = _playbackStateMapper.playbackStateStream.listen(
      (state) {
        logger.t('$tag Received state from mapper: ${formatPlaybackState(state)}');
        _playbackStateSubject.add(state);
      },
      onError: (error, stackTrace) {
        logger.e('$tag Error in mapper stream', error: error, stackTrace: stackTrace);
        if (error is AudioError) {
          _playbackStateSubject.add(PlaybackState.error(
            message: error.message,
            errorType: error.type,
          ));
        } else {
          _playbackStateSubject.add(PlaybackState.error(
            message: 'Playback error: $error',
            errorType: AudioErrorType.unknown,
          ));
        }
      },
    );
    
    logger.d('$tag Constructor: Initialization complete');
  }
  
  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;
  
  // Implement other methods, keeping the same interface
  // but with simplified internal logic due to more direct streams
  
  @override
  Future<void> dispose() async {
    final tag = logTag(AudioPlaybackServiceV3Impl);
    logger.d('$tag dispose: Cleaning up resources');
    await _mapperSubscription.cancel();
    await _playbackStateSubject.close();
    await _playbackStateMapper.dispose();
    logger.d('$tag dispose: Cleanup complete');
  }
}
```

3. **Create Service Factory**

```dart
// Update the factory to support the V3 implementation

class AudioPlaybackServiceFactory {
  static bool useNewServiceImplementation = false;
  static bool useNewestServiceImplementation = false;
  
  static AudioPlaybackService create({
    required AudioPlayerAdapter adapter,
    required PlaybackStateMapper mapper
  }) {
    if (useNewestServiceImplementation) {
      final adapterV2 = adapter is _LegacyAdapterBridge
          ? (adapter as _LegacyAdapterBridge)._newAdapter
          : _ForwardAdapterBridge(adapter);
          
      final mapperV2 = mapper is _MapperBridge
          ? (mapper as _MapperBridge)._newMapper
          : _ForwardMapperBridge(mapper);
          
      return AudioPlaybackServiceV3Impl(
        audioPlayerAdapter: adapterV2,
        playbackStateMapper: mapperV2,
      );
    } else if (useNewServiceImplementation) {
      // Existing V2 implementation code
    } else {
      return AudioPlaybackServiceImpl(
        audioPlayerAdapter: adapter,
        playbackStateMapper: mapper,
      );
    }
  }
}
```

4. **Verification**
   - Run service tests for all implementations
   - Ensure identical behavior with simpler code

### 4.4 Integration Testing and Cutover (1 day)

1. **Integration Tests**
   - Test all components together
   - Verify the simplified flow works correctly
   - Test error cases and edge conditions

2. **Cutover Strategy**
   - Enable the new mapper in test environment:
     ```dart
     PlaybackStateMapperFactory.useNewMapperImplementation = true;
     ```
   - Test thoroughly
   - Enable the newest service implementation:
     ```dart
     AudioPlaybackServiceFactory.useNewestServiceImplementation = true;
     ```
   - Test thoroughly in staging
   - Deploy to production with feature flags enabled

### 4.5 Cleanup and Code Removal (1 day)

1. **Remove Redundant Code**
   - Delete the old `PlaybackStateMapperImpl` implementation once stable
   - Remove bridge adapters and factories
   - Refactor to use the simplified interfaces directly

2. **Final Verification**
   - Run tests with the simplified implementation
   - Verify all functionality still works as expected

## Success Criteria

1. Reduced code complexity in the mapper (30-40% fewer lines of code)
2. Fewer stream transformations and state variables
3. Simplified stream flow that is easier to reason about
4. Identical behavior to the original implementation
5. Proper cleanup of resources
6. No memory leaks or resource leaks
7. Better performance due to fewer transformations

## Risks and Mitigations

**Risk**: Complex state transitions being missed in the simplified implementation
**Mitigation**: Comprehensive test coverage and parallel testing of both implementations

**Risk**: Event ordering changes affecting behavior
**Mitigation**: Thorough testing of edge cases like rapid state changes

**Risk**: Stream backpressure and buffering behaviors changing
**Mitigation**: Performance testing with large streams of events

**Risk**: Memory leaks from improper stream disposal
**Mitigation**: Leak detection tests and careful resource management 