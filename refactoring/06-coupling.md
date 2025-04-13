# Step 6: Reduce Coupling

## Overview

This step introduces context objects for better encapsulation, reducing the coupling between different layers of the audio player implementation.

**Estimated time:** 7 days

## Problem Statement

Currently, the playback flow requires knowledge of file paths at every layer:
- The widget has `filePath`
- The cubit tracks `_currentPlayingFilePath` (after Step 5, this is fixed but the parameter is still passed around)
- The service tracks the current file path
- The adapter receives file paths but doesn't store them (after Step 2, it does store the file path)

This creates several issues:
- **Redundant State**: File paths are tracked in multiple places
- **Context Fragmentation**: Each layer only has partial context
- **Interface Pollution**: Methods carry context information that could be stored once
- **Coupling**: Every component must understand file paths
- **Limited Extensibility**: Adding new features like playlists requires changes in multiple layers

## Implementation Steps

### 6.1 Create a PlaybackRequest Object (1 day)

1. **Write Tests**
   - Test PlaybackRequest creation and properties
   - Test serialization if needed

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/entities/playback_request.dart

/// Represents a request to play audio with specific parameters
class PlaybackRequest {
  /// The file path to be played
  final String filePath;
  
  /// The initial position to start playback from, if any
  final Duration? initialPosition;
  
  /// Whether to start playing automatically after loading
  final bool autoStart;
  
  /// Whether to loop playback
  final bool loop;
  
  const PlaybackRequest({
    required this.filePath,
    this.initialPosition,
    this.autoStart = true,
    this.loop = false,
  });
  
  /// Creates a copy of this request with the given fields replaced
  PlaybackRequest copyWith({
    String? filePath,
    Duration? initialPosition,
    bool? autoStart,
    bool? loop,
  }) {
    return PlaybackRequest(
      filePath: filePath ?? this.filePath,
      initialPosition: initialPosition ?? this.initialPosition,
      autoStart: autoStart ?? this.autoStart,
      loop: loop ?? this.loop,
    );
  }
  
  @override
  String toString() => 
    'PlaybackRequest(file: $filePath, pos: ${initialPosition?.inMilliseconds}ms, autoStart: $autoStart, loop: $loop)';
}
```

3. **Verification**
   - Run tests for the PlaybackRequest entity
   - Verify it correctly encapsulates playback parameters

### 6.2 Create a PlaybackSession in the Service (2 days)

1. **Write Tests**
   - Test PlaybackSession creation and state transitions
   - Test session lifecycle

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/entities/playback_session.dart

/// Represents a playback session with its current state and context
class PlaybackSession {
  /// The current request being processed
  final PlaybackRequest request;
  
  /// The current playback state
  final PlaybackState state;
  
  /// A unique identifier for this session
  final String id;
  
  /// Creates a new playback session
  const PlaybackSession({
    required this.request,
    required this.state,
    required this.id,
  });
  
  /// Creates a session with initial state
  factory PlaybackSession.create(PlaybackRequest request) {
    return PlaybackSession(
      request: request,
      state: const PlaybackState.initial(),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
  
  /// Creates a copy of this session with the given fields replaced
  PlaybackSession copyWith({
    PlaybackRequest? request,
    PlaybackState? state,
    String? id,
  }) {
    return PlaybackSession(
      request: request ?? this.request,
      state: state ?? this.state,
      id: id ?? this.id,
    );
  }
  
  /// Creates a copy with updated state
  PlaybackSession withState(PlaybackState state) {
    return copyWith(state: state);
  }
}
```

3. **Update Service Interface**

```dart
// lib/features/audio_recorder/domain/services/audio_playback_service_v5.dart

abstract class AudioPlaybackServiceV5 {
  /// Stream of playback sessions
  Stream<PlaybackSession> get sessionStream;
  
  /// Gets the current session, if any
  PlaybackSession? get currentSession;
  
  /// Plays audio using the given request
  Future<void> play(PlaybackRequest request);
  
  /// Pauses the current playback
  Future<void> pause();
  
  /// Resumes playback of the current audio
  Future<void> resume();
  
  /// Stops playback completely
  Future<void> stop();
  
  /// Seeks to a specific position in the current audio
  Future<void> seek(Duration position);
  
  /// Disposes of resources
  Future<void> dispose();
}
```

4. **Implement Updated Service**

```dart
// lib/features/audio_recorder/data/services/audio_playback_service_v5_impl.dart

class AudioPlaybackServiceV5Impl implements AudioPlaybackServiceV5 {
  final AudioPlayerAdapterV3 _audioPlayerAdapter;
  final PlaybackStateMapperV2 _playbackStateMapper;
  
  final BehaviorSubject<PlaybackSession> _sessionSubject = BehaviorSubject<PlaybackSession>();
  PlaybackSession? _currentSession;
  
  late final StreamSubscription<PlaybackState> _stateSubscription;
  
  AudioPlaybackServiceV5Impl({
    required AudioPlayerAdapterV3 audioPlayerAdapter,
    required PlaybackStateMapperV2 playbackStateMapper,
  }) : _audioPlayerAdapter = audioPlayerAdapter,
       _playbackStateMapper = playbackStateMapper {
    
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag Constructor: Initializing service');
    
    // Initialize the mapper with adapter streams
    _playbackStateMapper.initialize(
      playerStateStream: _audioPlayerAdapter.playerStateStream,
      positionStream: _audioPlayerAdapter.positionStream,
      durationStream: _audioPlayerAdapter.durationStream,
    );
    
    // Subscribe to playback state changes
    _stateSubscription = _playbackStateMapper.playbackStateStream.listen(
      _onPlaybackStateChanged,
      onError: _onPlaybackStateError,
    );
    
    logger.d('$tag Constructor: Service initialized');
  }
  
  @override
  Stream<PlaybackSession> get sessionStream => _sessionSubject.stream;
  
  @override
  PlaybackSession? get currentSession => _currentSession;
  
  void _onPlaybackStateChanged(PlaybackState state) {
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.t('$tag State changed: ${formatPlaybackState(state)}');
    
    if (_currentSession != null) {
      _currentSession = _currentSession!.withState(state);
      _sessionSubject.add(_currentSession!);
    }
  }
  
  void _onPlaybackStateError(Object error, StackTrace stackTrace) {
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.e('$tag Error in state stream', error: error, stackTrace: stackTrace);
    
    final audioError = error is AudioError 
        ? error 
        : AudioError.fromException(error, stackTrace);
    
    if (_currentSession != null) {
      _currentSession = _currentSession!.withState(PlaybackState.error(
        message: audioError.message,
        errorType: audioError.type,
      ));
      _sessionSubject.add(_currentSession!);
    }
  }
  
  @override
  Future<void> play(PlaybackRequest request) async {
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag play: Started with request: $request');
    
    try {
      // Create new session
      _currentSession = PlaybackSession.create(request);
      _sessionSubject.add(_currentSession!);
      
      // Select the source
      if (_audioPlayerAdapter.currentFilePath != request.filePath) {
        await _audioPlayerAdapter.stop();
        await _audioPlayerAdapter.setSourceUrl(request.filePath);
      }
      
      // Set initial position if provided
      if (request.initialPosition != null) {
        await _audioPlayerAdapter.seek(request.initialPosition!);
      }
      
      // Start playback if auto-start is enabled
      if (request.autoStart) {
        await _audioPlayerAdapter.resume();
      } else {
        await _audioPlayerAdapter.pause();
      }
      
      // Configure looping if needed
      await _audioPlayerAdapter.setLooping(request.loop);
      
      logger.d('$tag play: Completed');
    } catch (e, s) {
      logger.e('$tag play: Failed', error: e, stackTrace: s);
      
      final audioError = e is AudioError ? e : AudioError.fromException(e, s);
      
      if (_currentSession != null) {
        _currentSession = _currentSession!.withState(PlaybackState.error(
          message: audioError.message,
          errorType: audioError.type,
        ));
        _sessionSubject.add(_currentSession!);
      }
    }
  }
  
  @override
  Future<void> pause() async {
    if (_currentSession == null) return;
    
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag pause: Started');
    
    try {
      await _audioPlayerAdapter.pause();
      logger.d('$tag pause: Completed');
    } catch (e, s) {
      logger.e('$tag pause: Failed', error: e, stackTrace: s);
      // Error handling similar to play method
    }
  }
  
  @override
  Future<void> resume() async {
    if (_currentSession == null) return;
    
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag resume: Started');
    
    try {
      await _audioPlayerAdapter.resume();
      logger.d('$tag resume: Completed');
    } catch (e, s) {
      logger.e('$tag resume: Failed', error: e, stackTrace: s);
      // Error handling similar to play method
    }
  }
  
  @override
  Future<void> stop() async {
    if (_currentSession == null) return;
    
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag stop: Started');
    
    try {
      await _audioPlayerAdapter.stop();
      _currentSession = null;
      logger.d('$tag stop: Completed');
    } catch (e, s) {
      logger.e('$tag stop: Failed', error: e, stackTrace: s);
      // Error handling similar to play method
    }
  }
  
  @override
  Future<void> seek(Duration position) async {
    if (_currentSession == null) return;
    
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag seek: Started (${position.inMilliseconds}ms)');
    
    try {
      await _audioPlayerAdapter.seek(position);
      logger.d('$tag seek: Completed');
    } catch (e, s) {
      logger.e('$tag seek: Failed', error: e, stackTrace: s);
      // Error handling similar to play method
    }
  }
  
  @override
  Future<void> dispose() async {
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag dispose: Started');
    
    await _stateSubscription.cancel();
    await _sessionSubject.close();
    await _playbackStateMapper.dispose();
    
    logger.d('$tag dispose: Completed');
  }
}
```

5. **Create Service Factory**

```dart
// Update the factory to support the V5 implementation

class AudioPlaybackServiceFactory {
  // Previous flags
  static bool useV5ServiceImplementation = false;
  
  static AudioPlaybackService create({
    required AudioPlayerAdapter adapter,
    required PlaybackStateMapper mapper
  }) {
    if (useV5ServiceImplementation) {
      // Get adapter V3
      final adapterV3 = /* get or create adapter V3 */;
      
      // Get mapper V2
      final mapperV2 = /* get or create mapper V2 */;
      
      // Create V5 service
      final serviceV5 = AudioPlaybackServiceV5Impl(
        audioPlayerAdapter: adapterV3,
        playbackStateMapper: mapperV2,
      );
      
      // Bridge adapter to maintain backward compatibility
      return _ServiceBridgeV5ToV4(serviceV5);
    } else {
      // Previous implementations
    }
  }
}

// Bridge adapter to maintain backward compatibility
class _ServiceBridgeV5ToV4 implements AudioPlaybackService {
  final AudioPlaybackServiceV5 _serviceV5;
  late final StreamSubscription<PlaybackSession> _sessionSubscription;
  final BehaviorSubject<PlaybackState> _stateSubject = BehaviorSubject<PlaybackState>();
  
  _ServiceBridgeV5ToV4(this._serviceV5) {
    _sessionSubscription = _serviceV5.sessionStream.listen(
      (session) => _stateSubject.add(session.state),
    );
  }
  
  @override
  Stream<PlaybackState> get playbackStateStream => _stateSubject.stream;
  
  @override
  Future<void> play(String filePath) async {
    await _serviceV5.play(PlaybackRequest(filePath: filePath));
  }
  
  @override
  Future<void> pause() async {
    await _serviceV5.pause();
  }
  
  @override
  Future<void> resume() async {
    await _serviceV5.resume();
  }
  
  @override
  Future<void> stop() async {
    await _serviceV5.stop();
  }
  
  @override
  Future<void> seek(String filePath, Duration position) async {
    final currentSession = _serviceV5.currentSession;
    
    if (currentSession?.request.filePath == filePath) {
      await _serviceV5.seek(position);
    } else {
      await _serviceV5.play(PlaybackRequest(
        filePath: filePath,
        initialPosition: position,
        autoStart: false,
      ));
    }
  }
  
  @override
  Future<void> dispose() async {
    await _sessionSubscription.cancel();
    await _stateSubject.close();
    await _serviceV5.dispose();
  }
}
```

6. **Verification**
   - Test service with different playback requests
   - Verify session state changes correctly

### 6.3 Update Cubit to Use Session-Based API (2 days)

1. **Write Tests**
   - Test cubit with the session-based service
   - Test UI state updates

2. **Implementation**

```dart
// lib/features/audio_recorder/presentation/cubit/audio_list_cubit_v2.dart

class AudioListCubitV2 extends Cubit<AudioListState> {
  final AudioPlaybackServiceV5 _audioPlaybackService;
  late final StreamSubscription<PlaybackSession> _sessionSubscription;
  
  static final _tag = logTag(AudioListCubitV2);
  
  AudioListCubitV2({
    required AudioPlaybackServiceV5 audioPlaybackService,
  }) : _audioPlaybackService = audioPlaybackService, 
       super(AudioListInitial()) {
    _listenToSessions();
  }
  
  void _listenToSessions() {
    _sessionSubscription = _audioPlaybackService.sessionStream.listen(
      _onSessionChanged,
      onError: (error, stackTrace) {
        logger.e('$_tag Error in session stream', error: error, stackTrace: stackTrace);
      },
    );
  }
  
  void _onSessionChanged(PlaybackSession session) {
    if (state is AudioListLoaded) {
      final currentState = state as AudioListLoaded;
      final newPlaybackInfo = _mapSessionToPlaybackInfo(session);
      
      emit(currentState.copyWith(
        playbackInfo: newPlaybackInfo,
      ));
    }
  }
  
  // Maps a session to UI-friendly PlaybackInfo
  PlaybackInfo _mapSessionToPlaybackInfo(PlaybackSession session) {
    final filePath = session.request.filePath;
    
    // Extract state information
    bool isPlaying = false;
    bool isLoading = false;
    Duration currentPosition = Duration.zero;
    Duration totalDuration = Duration.zero;
    String? error;
    AudioErrorType? errorType;
    
    // Map state data using when pattern
    session.state.when(
      initial: () {
        isPlaying = false;
        isLoading = false;
      },
      loading: () {
        isPlaying = false;
        isLoading = true;
      },
      playing: (pos, dur) {
        isPlaying = true;
        isLoading = false;
        currentPosition = pos;
        totalDuration = dur;
      },
      paused: (pos, dur) {
        isPlaying = false;
        isLoading = false;
        currentPosition = pos;
        totalDuration = dur;
      },
      stopped: () {
        isPlaying = false;
        isLoading = false;
      },
      completed: () {
        isPlaying = false;
        isLoading = false;
      },
      error: (msg, type, pos, dur) {
        isPlaying = false;
        isLoading = false;
        error = msg;
        errorType = type;
        if (pos != null) currentPosition = pos;
        if (dur != null) totalDuration = dur;
      },
    );
    
    return PlaybackInfo(
      activeFilePath: filePath,
      isPlaying: isPlaying,
      isLoading: isLoading,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      error: error,
      errorType: errorType,
    );
  }
  
  // UI action methods
  
  Future<void> playRecording(String filePath, {bool loop = false}) async {
    if (state is AudioListLoaded) {
      final request = PlaybackRequest(
        filePath: filePath,
        autoStart: true,
        loop: loop,
      );
      
      await _audioPlaybackService.play(request);
    }
  }
  
  Future<void> pausePlayback() async {
    await _audioPlaybackService.pause();
  }
  
  Future<void> resumePlayback() async {
    await _audioPlaybackService.resume();
  }
  
  Future<void> stopPlayback() async {
    await _audioPlaybackService.stop();
  }
  
  Future<void> seekTo(Duration position) async {
    await _audioPlaybackService.seek(position);
  }
  
  @override
  Future<void> close() async {
    await _sessionSubscription.cancel();
    await super.close();
  }
}
```

3. **Create Bridge to Legacy Cubit**

```dart
// Bridge adapter if needed for compatibility
class _CubitBridgeV2ToV1 extends AudioListCubit {
  final AudioListCubitV2 _cubitV2;
  
  _CubitBridgeV2ToV1(AudioPlaybackService service, this._cubitV2)
      : super(service);
  
  // Override methods to delegate to V2 cubit
  @override
  Future<void> playRecording(String filePath) async {
    await _cubitV2.playRecording(filePath);
  }
  
  // Other overrides...
}
```

4. **Verification**
   - Test cubit integration with service
   - Verify UI state updates correctly

### 6.4 Create Advanced Playback Features (1 day)

1. **Write Tests**
   - Test advanced features like looping, playlists, etc.

2. **Implementation - Playlist Support**

```dart
// lib/features/audio_recorder/domain/entities/playlist.dart

class Playlist {
  final String id;
  final String name;
  final List<String> filePaths;
  
  const Playlist({
    required this.id,
    required this.name,
    required this.filePaths,
  });
}

// lib/features/audio_recorder/domain/services/playlist_service.dart

abstract class PlaylistService {
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> createPlaylist(String name, List<String> filePaths);
  Future<void> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addToPlaylist(String playlistId, String filePath);
  Future<void> removeFromPlaylist(String playlistId, String filePath);
}

// lib/features/audio_recorder/presentation/cubit/playlist_cubit.dart

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistService _playlistService;
  final AudioPlaybackServiceV5 _audioPlaybackService;
  
  PlaylistCubit({
    required PlaylistService playlistService,
    required AudioPlaybackServiceV5 audioPlaybackService,
  }) : _playlistService = playlistService,
       _audioPlaybackService = audioPlaybackService,
       super(PlaylistInitial());
       
  // Load playlists
  
  Future<void> loadPlaylists() async {
    emit(PlaylistLoading());
    
    try {
      final playlists = await _playlistService.getPlaylists();
      emit(PlaylistLoaded(playlists: playlists));
    } catch (e) {
      emit(PlaylistError(message: e.toString()));
    }
  }
  
  // Play a playlist from a specific index
  
  Future<void> playPlaylist(Playlist playlist, int startIndex) async {
    if (startIndex < 0 || startIndex >= playlist.filePaths.length) {
      return;
    }
    
    // Play the first file
    final firstFile = playlist.filePaths[startIndex];
    
    // Create a playlist context object
    final playlistContext = {
      'playlistId': playlist.id,
      'currentIndex': startIndex,
      'totalCount': playlist.filePaths.length,
    };
    
    // Create a request with context
    final request = PlaybackRequest(
      filePath: firstFile,
      autoStart: true,
      // We could add playlist context to the request if needed
    );
    
    await _audioPlaybackService.play(request);
  }
}
```

3. **Verification**
   - Test playlist functionality
   - Verify smooth playback transitions

### 6.5 Integration Testing and Cutover (1 day)

1. **Integration Tests**
   - Test full playback flow with sessions
   - Test advanced features

2. **Cutover Strategy**
   ```dart
   // Enable session-based service
   AudioPlaybackServiceFactory.useV5ServiceImplementation = true;
   ```

3. **Verification**
   - Verify all features work with the new implementation
   - Test with various usage patterns

## Success Criteria

1. File paths and playback parameters are encapsulated in request objects
2. A session provides complete context for all playback operations
3. Layers communicate through well-defined session/request objects
4. Adding new features like playlists is easier
5. API is more consistent and predictable
6. Performance is maintained or improved

## Risks and Mitigations

**Risk**: Session context adds complexity
**Mitigation**: Well-documented APIs and comprehensive tests

**Risk**: Breaking changes to existing code
**Mitigation**: Bridge adapters maintain backward compatibility

**Risk**: Performance overhead from additional objects
**Mitigation**: Benchmark critical paths, optimize if needed 