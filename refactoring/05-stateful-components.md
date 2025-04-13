# Step 5: Reduce Stateful Components

## Overview

This step focuses on consolidating state management by reducing the number of stateful components in the audio player and ensuring state is managed in the appropriate layers.

**Estimated time:** 7 days

## Problem Statement

Currently, both the service and cubit maintain internal state separate from their exposed state:

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

This leads to several issues:
- **Duplicate State**: The same information is tracked in multiple places
- **Race Conditions**: State changes can arrive out of order, requiring complex synchronization
- **Debug Difficulty**: Tracking state across components is challenging
- **Maintenance Burden**: Changes to state handling need updates in multiple places

## Implementation Steps

### 5.1 Move File Path Context to the Adapter (1 day)

1. **Write Tests**
   - Test that adapter correctly maintains the current file path
   - Verify the file path is properly updated when changing sources

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/adapters/audio_player_adapter_v3.dart

abstract class AudioPlayerAdapterV3 {
  // Add to existing AudioPlayerAdapterV2 methods
  
  /// Gets the current file path being played, if any.
  String? get currentFilePath;
}

// lib/features/audio_recorder/data/adapters/audio_player_adapter_v3_impl.dart

class AudioPlayerAdapterV3Impl implements AudioPlayerAdapterV3 {
  final AudioPlayer _audioPlayer;
  String? _currentFilePath;
  
  // Constructor
  
  @override
  String? get currentFilePath => _currentFilePath;
  
  @override
  Future<void> setSourceUrl(String url) async {
    final tag = logTag(AudioPlayerAdapterV3Impl);
    logger.d('$tag setSourceUrl: Started ($url)');
    try {
      _currentFilePath = url;
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      logger.d('$tag setSourceUrl: Completed');
    } catch (e, s) {
      // Error handling from Step 3
    }
  }
  
  // Other methods...
}
```

3. **Update the Bridge Adapter**

```dart
// In _LegacyAdapterBridge or similar adapter
@override
String? get currentFilePath => _newAdapter.currentFilePath;
```

4. **Verification**
   - Run adapter tests
   - Verify that the file path is correctly maintained

### 5.2 Implement a State Machine Approach in the Service (2 days)

1. **Write Tests**
   - Test state transitions for different operations
   - Verify that operations result in expected state changes

2. **Implementation**

```dart
// lib/features/audio_recorder/data/services/audio_playback_service_v4_impl.dart

/// Represents player operations that can trigger state transitions
enum PlayerOperation { 
  play, 
  pause, 
  resume, 
  seek, 
  stop,
  complete
}

class AudioPlaybackServiceV4Impl implements AudioPlaybackService {
  final AudioPlayerAdapterV3 _audioPlayerAdapter;
  final PlaybackStateMapperV2 _playbackStateMapper;
  final BehaviorSubject<PlaybackState> _playbackStateSubject;
  
  // Constructor, initialization, etc.
  
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
      
      case PlayerOperation.pause:
        if (currentState is _Playing) {
          return PlaybackState.paused(
            currentPosition: currentState.currentPosition,
            totalDuration: currentState.totalDuration,
          );
        }
        return currentState; // No change for other states
      
      case PlayerOperation.resume:
        if (currentState is _Paused) {
          return const PlaybackState.loading(); // Transitioning to playing
        }
        return currentState; // No change for other states
      
      case PlayerOperation.seek:
        // If not playing or paused, no state change
        if (!(currentState is _Playing || currentState is _Paused)) {
          return currentState;
        }
        
        // Calculate new position
        final newPosition = position ?? Duration.zero;
        
        // Return appropriate state with updated position
        if (currentState is _Playing) {
          return PlaybackState.playing(
            currentPosition: newPosition,
            totalDuration: currentState.totalDuration,
          );
        } else if (currentState is _Paused) {
          return PlaybackState.paused(
            currentPosition: newPosition,
            totalDuration: currentState.totalDuration,
          );
        }
        return currentState;
      
      case PlayerOperation.stop:
        return const PlaybackState.stopped();
      
      case PlayerOperation.complete:
        return const PlaybackState.completed();
    }
  }
  
  @override
  Future<void> play(String filePath) async {
    final tag = logTag(AudioPlaybackServiceV4Impl);
    logger.d('$tag play: Started ($filePath)');
    
    try {
      // First, check if the file exists
      // (File existence check code from Step 3)
      
      // Reduce state before operation
      final nextState = _reduceState(
        _playbackStateSubject.value, 
        PlayerOperation.play, 
        filePath: filePath
      );
      
      // Update state immediately to show loading/transition
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
      
      logger.d('$tag play: Completed');
    } catch (e, s) {
      // Error handling from Step 3
    }
  }
  
  // Implement other methods similarly with the state machine approach
}
```

3. **Create Updated Factory**

```dart
// Update service factory to include V4

class AudioPlaybackServiceFactory {
  // Existing code...
  
  static bool useV4ServiceImplementation = false;
  
  static AudioPlaybackService create({
    required AudioPlayerAdapter adapter,
    required PlaybackStateMapper mapper
  }) {
    if (useV4ServiceImplementation) {
      // Get or create adapter V3
      final adapterV3 = /* logic to get or create V3 adapter */;
      
      // Get or create mapper V2
      final mapperV2 = /* logic to get or create V2 mapper */;
      
      return AudioPlaybackServiceV4Impl(
        audioPlayerAdapter: adapterV3,
        playbackStateMapper: mapperV2,
      );
    } else if (/* other conditions */) {
      // Existing code for other versions
    }
  }
}
```

4. **Verification**
   - Test state transitions for all operations
   - Verify state is consistent during operations

### 5.3 Use a State-First Approach in the Cubit (2 days)

1. **Write Tests**
   - Test that cubit properly updates UI state
   - Verify that the cubit doesn't maintain duplicate state

2. **Implementation**

```dart
// lib/features/audio_recorder/presentation/cubit/audio_list_cubit.dart

class AudioListCubit extends Cubit<AudioListState> {
  final AudioPlaybackService _audioPlaybackService;
  late final StreamSubscription<PlaybackState> _playbackSubscription;
  
  AudioListCubit({
    required AudioPlaybackService audioPlaybackService,
  }) : _audioPlaybackService = audioPlaybackService,
       super(AudioListInitial()) {
    _listenToPlaybackState();
  }
  
  void _listenToPlaybackState() {
    _playbackSubscription = _audioPlaybackService.playbackStateStream.listen(
      _onPlaybackStateChanged,
      onError: (error, stackTrace) {
        logger.e('$_tag Error in playback stream', error: error, stackTrace: stackTrace);
        // Handle error
      },
    );
  }
  
  void _onPlaybackStateChanged(PlaybackState playbackState) {
    if (state is AudioListLoaded) {
      final currentState = state as AudioListLoaded;
      
      // Map the PlaybackState directly to UI state without intermediate variables
      final newPlaybackInfo = _mapPlaybackStateToInfo(
        playbackState, 
        currentState.playbackInfo.activeFilePath
      );
      
      emit(currentState.copyWith(playbackInfo: newPlaybackInfo));
    }
  }
  
  // Helper method to map domain state to UI state
  PlaybackInfo _mapPlaybackStateToInfo(PlaybackState state, String? currentFilePath) {
    String? activeFilePath = currentFilePath;
    bool isPlaying = false;
    bool isLoading = false;
    Duration currentPosition = Duration.zero;
    Duration totalDuration = Duration.zero;
    String? error;
    AudioErrorType? errorType;
    
    // Map state data using when pattern
    state.when(
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
        activeFilePath = null; // Clear active file when stopped
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
      activeFilePath: activeFilePath,
      isPlaying: isPlaying,
      isLoading: isLoading,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      error: error,
      errorType: errorType,
    );
  }
  
  // Update cubit methods to immediately reflect UI intentions
  
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
  
  // Implement other methods similarly...
}
```

3. **Verification**
   - Test cubit state updates
   - Verify UI shows appropriate state during transitions

### 5.4 Simplify Widget State (1 day)

1. **Write Tests**
   - Test widget handles state changes properly
   - Verify UI controls respond to state changes

2. **Implementation**

```dart
// lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  // Only keep truly local UI state
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
  
  // Handle slider changes
  void _onSliderChanged(double value) {
    setState(() {
      _isDragging = true;
      _sliderValue = value;
    });
  }
  
  void _onSliderChangeEnd(double value) {
    setState(() {
      _isDragging = false;
    });
    
    final newPosition = Duration(milliseconds: value.toInt());
    widget.onSeek?.call(newPosition);
  }
  
  @override
  Widget build(BuildContext context) {
    // Calculate slider properties
    final duration = widget.totalDuration.inMilliseconds.toDouble();
    final max = duration > 0 ? duration : 0.0001; // Avoid zero max value
    
    // Use local slider value while dragging, otherwise use prop value
    final displayValue = _isDragging 
        ? _sliderValue 
        : widget.currentPosition.inMilliseconds.toDouble();
    
    // Display position in mm:ss format
    final position = Duration(milliseconds: displayValue.toInt());
    
    return Column(
      children: [
        // Slider widget
        Slider(
          value: displayValue.clamp(0.0, max),
          max: max,
          onChanged: widget.canSeek ? _onSliderChanged : null,
          onChangeEnd: widget.canSeek ? _onSliderChangeEnd : null,
        ),
        
        // Time display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position)),
            Text(_formatDuration(widget.totalDuration)),
          ],
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

3. **Verification**
   - Test widget behavior with different state inputs
   - Verify there are no state synchronization issues

### 5.5 Integration Testing and Cutover (1 day)

1. **Integration Tests**
   - Test all components together with the simplified state management
   - Verify state consistency across all layers

2. **Cutover Strategy**
   - Enable each component in sequence, testing after each change:
     ```dart
     // Enable the updated adapter first
     AudioPlayerAdapterFactory.useV3AdapterImplementation = true;
     
     // Then enable the updated service
     AudioPlaybackServiceFactory.useV4ServiceImplementation = true;
     ```
   - Deploy with feature flags enabled for gradual rollout

## Success Criteria

1. Each piece of state has a single source of truth
2. UI state is derived directly from domain state without intermediate storage
3. State transitions are predictable and synchronized
4. Widget state is limited to local UI concerns (e.g., drag state)
5. Improved performance due to fewer rebuilds and state synchronization
6. Identical behavior to the original implementation

## Risks and Mitigations

**Risk**: State transitions not capturing all edge cases
**Mitigation**: Comprehensive test coverage for state transitions

**Risk**: Performance regression during state updates
**Mitigation**: Benchmark UI responsiveness with both implementations

**Risk**: Losing important state that was previously duplicated
**Mitigation**: Thorough verification that all state is properly maintained 