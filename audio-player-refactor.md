# Audio Player Refactoring Guide

## Executive Summary

The current audio player architecture implements the Adapter-Mapper-Service pattern with a Clean Architecture approach. While the implementation is functional and well-structured overall, there are several areas where simplification could lead to more maintainable code, better performance, and fewer race conditions. This guide provides detailed recommendations for refactoring the audio player implementation.

## 1. Simplify the Stream Flow

### Current Implementation

The `PlaybackStateMapperImpl` manages **five separate `StreamController`s**:

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

### Problems

1. **Complex State Synchronization**: Managing five separate streams and corresponding state variables creates complex synchronization challenges.
2. **Potential Memory Leaks**: Multiple `StreamSubscription`s to manage, with complex cleanup requirements.
3. **Excessive Transformations**: Events undergo multiple transformations, potentially leading to inefficiencies.
4. **Code Bloat**: The mapper contains ~400 lines of code, much of it dedicated to plumbing.
5. **Multiple Debounce Points**: Debouncing happens at different layers (mapper, widget) rather than once at a strategic location.

### Recommendation

1. **Simplify the Mapper to a Direct Transformer**:

```dart
class PlaybackStateMapperImpl implements PlaybackStateMapper {
  // Single output stream
  late final Stream<PlaybackState> _playbackStateStream;
  
  // A single subscription to the main player state changes 
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;
  
  @override
  void initialize({
    required Stream<PlayerState> playerStateStream, 
    required Stream<Duration> positionStream,
    required Stream<Duration?> durationStream,
  }) {
    // Create a single combined stream using RxDart's CombineLatest
    _playbackStateStream = Rx.combineLatest3<PlayerState, Duration, Duration?, PlaybackState>(
      playerStateStream,
      positionStream,
      durationStream,
      (playerState, position, duration) {
        // Direct transformation logic here
        // Avoids the need for internal state variables
        return _mapToPlaybackState(playerState, position, duration);
      }
    )
    .debounceTime(const Duration(milliseconds: 100))
    .distinct()
    .asBroadcastStream();
  }
  
  // Simple mapping function
  PlaybackState _mapToPlaybackState(PlayerState state, Duration position, Duration? duration) {
    // Simplified mapping logic
    if (/* loading check */) return const PlaybackState.loading();
    // etc.
  }
  
  @override
  void dispose() {
    _playerStateSubscription?.cancel();
  }
}
```

2. **Make the Adapter Expose Fewer, More Cohesive Streams**:

```dart
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final AudioPlayer _audioPlayer;
  
  @override
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  
  @override 
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  
  @override
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  
  // No need for separate completed stream, it's derived from playerStateStream
}
```

3. **Benefits**:
   - Significantly reduced code
   - Fewer points of failure
   - Cleaner separation of concerns
   - Simpler testing
   - Unified debouncing strategy
   - No internal state to maintain in the mapper

## 2. Resolve the `seek` API Inconsistency

### Current Implementation

The `AudioPlayerAdapter` interface defines:

```dart
Future<void> seek(String filePath, Duration position);
```

But the implementation with `just_audio` doesn't use the `filePath` parameter:

```dart
@override
Future<void> seek(String filePath, Duration position) async {
  // Note: filePath is required by the interface, but just_audio's seek only uses position.
  logger.d('[ADAPTER SEEK $filePath @ ${position.inMilliseconds}ms] START');
  try {
    await _audioPlayer.seek(position);
    logger.d('[ADAPTER SEEK] Call complete.');
  } catch (e, s) {
    logger.e('[ADAPTER SEEK] FAILED', error: e, stackTrace: s);
    rethrow;
  }
  logger.d('[ADAPTER SEEK $filePath @ ${position.inMilliseconds}ms] END');
}
```

This creates confusion about whether the file path is actually needed, and how seek behaves across different audio files.

### Problems

1. **Misleading API**: The interface suggests that you need a file path to seek, but the implementation ignores it.
2. **Inconsistent Behavior**: The service layer has complex logic to handle seeking in different contexts (same file, different file), but this isn't reflected in the adapter API.
3. **Knowledge Leakage**: The service needs to know too much about how seeking works with the specific adapter.

### Recommendation

1. **Simplify the `seek` API to be File-Agnostic**:

```dart
// In AudioPlayerAdapter interface
Future<void> seek(Duration position);

// In the implementation
@override
Future<void> seek(Duration position) async {
  logger.d('[ADAPTER SEEK ${position.inMilliseconds}ms] START');
  try {
    await _audioPlayer.seek(position);
    logger.d('[ADAPTER SEEK] Call complete.');
  } catch (e, s) {
    logger.e('[ADAPTER SEEK] FAILED', error: e, stackTrace: s);
    rethrow;
  }
}
```

2. **Add Context-Aware Methods to the Service**:

```dart
// Private helper method in AudioPlaybackServiceImpl
Future<void> _seekInCurrentContext(Duration position) async {
  await _audioPlayerAdapter.seek(position);
}

// Private helper method for seeking in a new file context
Future<void> _seekInNewContext(String filePath, Duration position) async {
  await _audioPlayerAdapter.stop();
  _currentFilePath = filePath;
  await _audioPlayerAdapter.setSourceUrl(filePath);
  await _audioPlayerAdapter.seek(position);
  await _audioPlayerAdapter.pause(); // Prevent auto-play
}

// Public method remains the same but delegates to the helpers
@override
Future<void> seek(String filePath, Duration position) async {
  if (filePath == _currentFilePath) {
    await _seekInCurrentContext(position);
  } else {
    await _seekInNewContext(filePath, position);
  }
}
```

3. **Benefits**:
   - Cleaner, more honest API
   - Simplifies the adapter implementation
   - Makes the service's responsibility for context-switching explicit
   - Better separation of concerns

## 3. Clean Up Logging Code

### Current Implementation

The current implementation has extensive logging with inconsistent patterns:

1. **Inconsistent Log Levels**:
   ```dart
   final logger = Logger(level: Level.off); // Sometimes Level.debug
   ```

2. **Commented-Out Log Statements**:
   ```dart
   // logger.d('[SERVICE PAUSE] Adapter pause() call complete.'); // Keep DEBUG
   ```

3. **Multiple Debug Flags**:
   ```dart
   const bool _debugStateTransitions = true;
   ```

4. **Excessive Logging Points**:
   ```dart
   logger.t('[MAPPER_PRE_DISTINCT] State: $state');
   logger.t('[MAPPER_DEBOUNCE_IN] State: $state');
   logger.t('[MAPPER_DEBOUNCE_OUT] State: $state');
   ```

### Problems

1. **Code Bloat**: Logging code becomes a significant portion of the implementation.
2. **Maintenance Burden**: Need to manage which logs are commented out/enabled.
3. **Performance Impact**: Extensive string concatenation for logs, even when disabled.
4. **Inconsistent Visibility**: Different log levels across components obscure the flow.
5. **Cognitive Load**: Developers must mentally filter out logging code to understand core logic.

### Recommendation

1. **Standardize Logging Approach**:

```dart
// Use const for Logger to ensure compile-time optimization
const logger = Logger(level: kReleaseMode ? Level.off : Level.info);

// In each class, use a consistent pattern
class SomeClass {
  // For method entry/exit logging, use a simple pattern
  void someMethod() {
    logger.d('${_TAG} someMethod: Started');
    // Method body
    logger.d('${_TAG} someMethod: Completed');
  }
  
  // For errors, always include error and stackTrace
  void errorProneMethod() {
    try {
      // Risky code
    } catch (e, s) {
      logger.e('${_TAG} errorProneMethod: Failed', error: e, stackTrace: s);
      rethrow;
    }
  }
  
  // Define a TAG constant for each class
  static const _TAG = 'SomeClass';
}
```

2. **Create a Log Helper for Complex Objects**:

```dart
// In a utility file like log_helpers.dart
String formatPlaybackState(PlaybackState state) {
  return state.when(
    initial: () => 'initial',
    loading: () => 'loading',
    playing: (pos, dur) => 'playing(${pos.inMilliseconds}ms/${dur.inMilliseconds}ms)',
    // etc.
  );
}

// Then in code:
logger.d('${_TAG} Received state: ${formatPlaybackState(state)}');
```

3. **Use Conditional Logging for Verbose Areas**:

```dart
// Instead of flags like _debugStateTransitions, use logger.level check
if (logger.level <= Level.debug) {
  logger.d('${_TAG} Detailed info: ${complexObject.expensiveToString()}');
}
```

4. **Eliminate Commented Logs**:
   - Remove all commented log statements completely
   - If they contain valuable information, convert to code comments
   - Use log levels (trace, debug, info) rather than commenting/uncommenting

5. **Benefits**:
   - Cleaner, more consistent code
   - Better performance in release mode
   - Easier to maintain and update
   - More useful logs during development
   - Reduced cognitive load when reading code

## 4. Reduce Stateful Components

### Current Implementation

Both the service and cubit maintain internal state separate from their exposed state:

**AudioPlaybackServiceImpl**:
```dart
String? _currentFilePath;
PlaybackState _lastKnownState = const PlaybackState.initial();
```

**AudioListCubit**:
```dart
String? _currentPlayingFilePath; // Internal tracking of the active file
```

**AudioPlayerWidget**:
```dart
bool _isDragging = false;
double _dragValue = 0.0;
bool _waitingForSeekConfirm = false;
double _finalDragValue = 0.0;
Timer? _seekConfirmTimer;
```

### Problems

1. **Duplicate State**: The same information is tracked in multiple places.
2. **Race Conditions**: State changes can arrive out of order, requiring complex synchronization.
3. **Debug Difficulty**: Tracking state across components becomes challenging.
4. **Maintenance Burden**: Changes to state handling need updates in multiple places.
5. **Mental Model Complexity**: Developers must understand all state pieces and their interactions.

### Recommendation

1. **Move File Path Context to the Adapter**:

```dart
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  String? _currentFilePath;
  
  @override
  String? get currentFilePath => _currentFilePath;
  
  @override
  Future<void> setSourceUrl(String url) async {
    _currentFilePath = url;
    await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
  }
}
```

2. **Use a State Machine Approach in the Service**:

```dart
enum PlayerOperation { play, pause, resume, seek, stop }

class AudioPlaybackServiceImpl implements AudioPlaybackService {
  // Use a reducer pattern to determine the next state
  PlaybackState _reduceState(
    PlaybackState currentState, 
    PlayerOperation operation,
    {String? filePath, Duration? position}
  ) {
    switch (operation) {
      case PlayerOperation.play:
        if (filePath == _audioPlayerAdapter.currentFilePath && 
            currentState is _Paused) {
          return const PlaybackState.loading(); // Transitioning to resume
        } else {
          return const PlaybackState.loading(); // Fresh play
        }
      // Other cases
    }
  }
  
  @override
  Future<void> play(String filePath) async {
    final nextState = _reduceState(
      _playbackStateSubject.value, 
      PlayerOperation.play, 
      filePath: filePath
    );
    
    _playbackStateSubject.add(nextState);
    
    // Execute the actual operation based on the reduced state
    if (filePath == _audioPlayerAdapter.currentFilePath && 
        _playbackStateSubject.value is _Paused) {
      await _audioPlayerAdapter.resume();
    } else {
      await _audioPlayerAdapter.stop();
      await _audioPlayerAdapter.setSourceUrl(filePath);
      await _audioPlayerAdapter.resume();
    }
  }
}
```

3. **Use a State-First Approach in the Cubit**:

Instead of maintaining parallel state, update the actual Cubit state immediately to reflect UI intentions, then update once the operation completes:

```dart
Future<void> playRecording(String filePath) async {
  if (state is AudioListLoaded) {
    final currentState = state as AudioListLoaded;
    
    // Update state immediately to show loading indicator
    emit(currentState.copyWith(
      playbackInfo: currentState.playbackInfo.copyWith(
        activeFilePath: filePath,
        isLoading: true,
      ),
    ));
    
    // Perform operation
    await _audioPlaybackService.play(filePath);
  }
}
```

4. **Simplify Widget State**:

```dart
class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  // Only keep truly local UI state
  bool _isDragging = false;
  double _dragValue = 0.0;
  
  // A single method that handles all drag operations
  void _handleSliderDrag(double value, {bool isComplete = false}) {
    if (isComplete) {
      // Immediately seek on drag complete
      final position = Duration(milliseconds: value.round());
      context.read<AudioListCubit>().seekRecording(widget.filePath, position);
      setState(() => _isDragging = false);
    } else {
      // Just update local drag value
      setState(() {
        _isDragging = true;
        _dragValue = value;
      });
    }
  }
}
```

5. **Benefits**:
   - Single source of truth for each piece of state
   - Clearer flow of state changes
   - Easier to debug and maintain
   - Less code overall
   - Fewer race conditions

## 5. Improve UI Performance

### Current Implementation

The current UI implementation attempts to prevent jank during seeks with complex state tracking:

```dart
bool _isDragging = false;
double _dragValue = 0.0;
bool _waitingForSeekConfirm = false;
double _finalDragValue = 0.0;
Timer? _seekConfirmTimer;
```

```dart
setState(() {
  _isDragging = false;
  _waitingForSeekConfirm = true; // Lock UI
  _finalDragValue = value; // Store final value
});
// Cancel any previous timer
_seekConfirmTimer?.cancel();
// Start timer to unlock UI after debounce+buffer
_seekConfirmTimer = Timer(
  const Duration(milliseconds: 150),
  () {
    if (mounted) {
      // Check if widget is still mounted
      setState(() => _waitingForSeekConfirm = false);
    }
  },
);
```

### Problems

1. **Complex State Logic**: The widget maintains multiple flags and timers.
2. **Jank During Seeks**: Despite the complexity, seek operations can still cause UI jank.
3. **Unpredictable UX**: The slider behavior can be inconsistent due to race conditions.
4. **Performance Overhead**: Frequent rebuilds are tracked with timing code.

### Recommendation

1. **Adopt a Controlled-Component Pattern**:

```dart
class AudioPlayerWidget extends StatefulWidget {
  // Props including a callback for position changes
  final void Function(Duration position)? onPositionChanged;
  
  // Constructor
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  // Local state only for UI interactions
  bool _isDragging = false;
  late double _sliderValue;
  
  @override
  void initState() {
    super.initState();
    _sliderValue = widget.currentPosition.inMilliseconds.toDouble();
  }
  
  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update from props if not currently dragging
    if (!_isDragging && oldWidget.currentPosition != widget.currentPosition) {
      _sliderValue = widget.currentPosition.inMilliseconds.toDouble();
    }
  }
}
```

2. **Use a Specialized Slider Implementation**:

Consider using a more specialized slider implementation designed for media playback, or extend the base `Slider` widget:

```dart
class AudioSlider extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration>? onChangeEnd;
  final bool enabled;
  
  // Constructor and createState
}

class _AudioSliderState extends State<AudioSlider> {
  // Internal drag state
  
  // Override build with optimized slider implementation
}
```

3. **Optimize State Updates**:

```dart
// In AudioListCubit
Future<void> seekRecording(String filePath, Duration position) async {
  if (state is AudioListLoaded) {
    final currentState = state as AudioListLoaded;
    
    // Optimistic update - immediately show new position
    emit(currentState.copyWith(
      playbackInfo: currentState.playbackInfo.copyWith(
        currentPosition: position,
      ),
    ));
    
    // Perform actual seek
    await _audioPlaybackService.seek(filePath, position);
  }
}
```

4. **Leverage Flutter's Rendering Pipeline**:

```dart
// Use RepaintBoundary to isolate slider repaints
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // Other widgets
      RepaintBoundary(
        child: AudioSlider(
          currentPosition: displayPosition,
          totalDuration: widget.totalDuration,
          onChangeEnd: _handleSliderChangeEnd,
          enabled: canSeek,
        ),
      ),
      // Other widgets
    ],
  );
}
```

5. **Use ValueNotifier for Fine-Grained Updates**:

```dart
// In widget state
late final ValueNotifier<double> _positionNotifier;

@override
void initState() {
  super.initState();
  _positionNotifier = ValueNotifier(
    widget.currentPosition.inMilliseconds.toDouble(),
  );
}

// In build method
ValueListenableBuilder<double>(
  valueListenable: _positionNotifier,
  builder: (context, value, child) {
    return Slider(
      value: value,
      // Other properties
    );
  },
)
```

6. **Benefits**:
   - Smoother slider operation
   - Less complex state management
   - Fewer rebuilds
   - More predictable user experience
   - Better performance on lower-end devices

## 6. Simplify Error Handling

### Current Implementation

Error handling is scattered across multiple layers with inconsistent approaches:

```dart
// In adapter
try {
  await _audioPlayer.resume();
} catch (e, s) {
  logger.e('[ADAPTER RESUME] FAILED', error: e, stackTrace: s);
  rethrow;
}

// In service
try {
  await _audioPlayerAdapter.resume();
} catch (e, s) {
  logger.e('[SERVICE RESUME] FAILED', error: e, stackTrace: s);
  _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
  rethrow;
}

// In cubit
_playbackSubscription = _audioPlaybackService.playbackStateStream.listen(
  (state) => _onPlaybackStateChanged(state),
  onError: (error, stackTrace) {
    logger.e(
      '[CUBIT] Error in playback service stream',
      error: error,
      stackTrace: stackTrace, // Log stack trace
    );
    // Handle error in cubit state
  },
);
```

### Problems

1. **Inconsistent Error Propagation**: Errors are sometimes rethrown, sometimes converted to states.
2. **Duplicate Error Handling**: Multiple layers log the same error.
3. **Mixed Approaches**: Combination of try-catch and stream error handlers.
4. **Limited Recovery Options**: Current error handling focuses on reporting, not recovery.
5. **Low Error Granularity**: Generic error messages don't help users or developers.

### Recommendation

1. **Define Error Types**:

```dart
enum AudioErrorType {
  networkError,
  fileNotFound,
  permissionDenied,
  unsupportedFormat,
  playerError,
  unknown
}

class AudioError {
  final AudioErrorType type;
  final String message;
  final Object? originalError;
  
  const AudioError({
    required this.type,
    required this.message,
    this.originalError,
  });
  
  // Factory constructors for common errors
  factory AudioError.fromException(Object e) {
    if (e is FileSystemException) {
      return AudioError(
        type: AudioErrorType.fileNotFound,
        message: 'Audio file not found or inaccessible',
        originalError: e,
      );
    }
    // Other error mappings
    return AudioError(
      type: AudioErrorType.unknown,
      message: 'An unexpected error occurred: ${e.toString()}',
      originalError: e,
    );
  }
}
```

2. **Handle Errors at the Source**:

```dart
// In adapter
try {
  await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
} catch (e, s) {
  logger.e('[ADAPTER] Failed to set source', error: e, stackTrace: s);
  throw AudioError.fromException(e);
}
```

3. **Use Result Types for Error Returns**:

```dart
// Using Either from dartz package
Future<Either<AudioError, void>> play(String filePath) async {
  try {
    // Implementation
    return right(unit);
  } catch (e, s) {
    logger.e('[SERVICE] play failed', error: e, stackTrace: s);
    return left(AudioError.fromException(e));
  }
}
```

4. **Centralize Error Handling in the Service**:

```dart
Future<void> play(String filePath) async {
  try {
    // Implementation
  } catch (e, s) {
    final audioError = e is AudioError ? e : AudioError.fromException(e);
    logger.e('[SERVICE] Play failed', error: audioError, stackTrace: s);
    _playbackStateSubject.add(PlaybackState.error(
      message: audioError.message,
      errorType: audioError.type,
    ));
    // Don't rethrow - errors are now part of the state
  }
}
```

5. **Provide Recovery Options in UI**:

```dart
Widget _buildErrorState(AudioErrorType errorType, String errorMessage) {
  Widget actionButton;
  
  switch (errorType) {
    case AudioErrorType.networkError:
      actionButton = ElevatedButton(
        onPressed: () => widget.onRetry?.call(),
        child: const Text('Retry'),
      );
      break;
    case AudioErrorType.fileNotFound:
      actionButton = ElevatedButton(
        onPressed: widget.onDelete,
        child: const Text('Remove'),
      );
      break;
    // Other error types
    default:
      actionButton = IconButton(
        onPressed: widget.onDelete,
        icon: const Icon(Icons.delete),
      );
  }
  
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        actionButton,
      ],
    ),
  );
}
```

6. **Benefits**:
   - More targeted error handling
   - Better user experience
   - Clearer error propagation
   - Recovery options when possible
   - Easier debugging

## 7. Reduce Coupling with Context Objects

### Current Implementation

Currently, the playback flow requires knowledge of file paths at every layer:
- The widget has `filePath`
- The cubit tracks `_currentPlayingFilePath`
- The service tracks `_currentFilePath`
- The adapter receives file paths but doesn't store them

### Problems

1. **Redundant State**: File paths are tracked in multiple places.
2. **Context Fragmentation**: Each layer only has partial context.
3. **Interface Pollution**: Methods carry context information that could be stored once.
4. **Coupling**: Every component must understand file paths.

### Recommendation

1. **Use a PlaybackRequest Object**:

```dart
class PlaybackRequest {
  final String filePath;
  final Duration? initialPosition;
  final bool autoStart;
  
  const PlaybackRequest({
    required this.filePath,
    this.initialPosition,
    this.autoStart = true,
  });
}
```

2. **Create a PlaybackSession in the Service**:

```dart
class PlaybackSession {
  final String filePath;
  PlaybackState state;
  
  PlaybackSession({
    required this.filePath,
    this.state = const PlaybackState.initial(),
  });
}

class AudioPlaybackServiceImpl implements AudioPlaybackService {
  PlaybackSession? _currentSession;
  
  @override
  Stream<PlaybackSession> get sessionStream => _sessionSubject.stream;
  
  @override
  Future<void> play(PlaybackRequest request) async {
    // If no current session or different file
    if (_currentSession == null || _currentSession!.filePath != request.filePath) {
      // Create new session
      _currentSession = PlaybackSession(filePath: request.filePath);
      _sessionSubject.add(_currentSession!);
      
      // Load and play
      await _audioPlayerAdapter.stop();
      await _audioPlayerAdapter.setSourceUrl(request.filePath);
      
      if (request.initialPosition != null) {
        await _audioPlayerAdapter.seek(request.initialPosition!);
      }
      
      if (request.autoStart) {
        await _audioPlayerAdapter.resume();
      }
    } else {
      // Resume existing session
      await _audioPlayerAdapter.resume();
    }
  }
}
```

3. **Simplify Cubit Logic with Sessions**:

```dart
class AudioListCubit extends Cubit<AudioListState> {
  final AudioPlaybackService _audioPlaybackService;
  StreamSubscription? _sessionSubscription;
  
  AudioListCubit({required AudioPlaybackService audioPlaybackService})
      : _audioPlaybackService = audioPlaybackService,
        super(AudioListInitial()) {
    _listenToSessions();
  }
  
  void _listenToSessions() {
    _sessionSubscription = _audioPlaybackService.sessionStream.listen(
      (session) {
        if (state is AudioListLoaded) {
          final currentState = state as AudioListLoaded;
          
          emit(currentState.copyWith(
            playbackInfo: PlaybackInfo(
              activeFilePath: session.filePath,
              isPlaying: session.state.maybeWhen(
                playing: (_, __) => true,
                orElse: () => false,
              ),
              // Other mappings
            ),
          ));
        }
      },
    );
  }
  
  Future<void> playRecording(String filePath) async {
    await _audioPlaybackService.play(
      PlaybackRequest(filePath: filePath),
    );
  }
}
```

4. **Benefits**:
   - Single source of truth for playback context
   - Cleaner APIs with fewer parameters
   - More cohesive state management
   - Easier to add new capabilities (like playlists)
   - Better testability

## Conclusion

The current audio player implementation demonstrates good architecture but could benefit from simplification in several areas. The key themes in these recommendations are:

1. **Simplify and Consolidate**: Reduce the number of streams, state containers, and transformations.
2. **Clarify Responsibilities**: Make each layer's role and the flow of data/events between them clearer.
3. **Use Consistent Patterns**: Apply consistent approaches to logging, error handling, and state management.
4. **Optimize for UX**: Focus on making the UI responsive and jank-free, even during complex operations.
5. **Reduce Duplication**: Eliminate duplicate state and logic across layers.

Implementing these recommendations will result in a more maintainable, performant, and reliable audio player while preserving the clean architecture benefits of the current implementation.
