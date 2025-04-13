# Step 7: Improve UI Performance

## Overview

This step focuses on enhancing the UI rendering and responsiveness of the audio player widget, particularly during seek operations and state transitions.

**Estimated time:** 5 days

## Problem Statement

The current UI implementation attempts to prevent jank during seeks with complex state tracking but still has performance issues:

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

Key issues include:
- **Complex State Logic**: Multiple flags and timers to track UI state
- **Jank During Seeks**: UI stutters when seeking, especially on slower devices
- **Unpredictable UX**: Race conditions between timers and state updates
- **Excessive Rebuilds**: Widget rebuilds too frequently during playback

## Implementation Steps

### 7.1 Create a Specialized AudioSlider Component (2 days)

1. **Write Tests**
   - Create widget tests for slider behavior
   - Test performance with simulated input

2. **Implementation**

```dart
// lib/features/audio_recorder/presentation/widgets/audio_slider.dart

class AudioSlider extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration>? onChangeEnd;
  final bool enabled;
  final double thumbRadius;
  final Color activeColor;
  final Color inactiveColor;
  
  const AudioSlider({
    Key? key,
    required this.currentPosition,
    required this.totalDuration,
    this.onChangeEnd,
    this.enabled = true,
    this.thumbRadius = 10.0,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
  }) : super(key: key);
  
  @override
  State<AudioSlider> createState() => _AudioSliderState();
}

class _AudioSliderState extends State<AudioSlider> {
  // Local slider state
  bool _isDragging = false;
  late ValueNotifier<double> _sliderPosition;
  
  // Calculate slider value based on durations
  double get _maxValue => widget.totalDuration.inMilliseconds.toDouble().max(1.0);
  double get _calculatedValue => widget.currentPosition.inMilliseconds.toDouble().clamp(0.0, _maxValue);
  
  @override
  void initState() {
    super.initState();
    _sliderPosition = ValueNotifier<double>(_calculatedValue);
  }
  
  @override
  void didUpdateWidget(AudioSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update from props if not dragging
    if (!_isDragging && 
        (oldWidget.currentPosition != widget.currentPosition ||
         oldWidget.totalDuration != widget.totalDuration)) {
      _sliderPosition.value = _calculatedValue;
    }
  }
  
  void _handleChangeStart(double value) {
    setState(() => _isDragging = true);
  }
  
  void _handleChanged(double value) {
    // Update value notifier without setState to avoid rebuilds
    _sliderPosition.value = value;
  }
  
  void _handleChangeEnd(double value) {
    setState(() => _isDragging = false);
    
    if (widget.onChangeEnd != null) {
      // Convert to Duration and call handler
      final position = Duration(milliseconds: value.round());
      widget.onChangeEnd!(position);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // Main slider
            ValueListenableBuilder<double>(
              valueListenable: _sliderPosition,
              builder: (context, position, _) {
                return SliderTheme(
                  data: SliderThemeData(
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: widget.thumbRadius,
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: widget.thumbRadius * 2,
                    ),
                    trackHeight: 4.0,
                  ),
                  child: Slider(
                    value: position.clamp(0.0, _maxValue),
                    max: _maxValue,
                    onChangeStart: widget.enabled ? _handleChangeStart : null,
                    onChanged: widget.enabled ? _handleChanged : null,
                    onChangeEnd: widget.enabled ? _handleChangeEnd : null,
                    activeColor: widget.activeColor,
                    inactiveColor: widget.inactiveColor,
                  ),
                );
              },
            ),
            
            // Optional: Add buffer indicator
          ],
        ),
        
        // Time display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ValueListenableBuilder<double>(
            valueListenable: _sliderPosition,
            builder: (context, position, _) {
              final currentTimeText = _formatDuration(
                _isDragging 
                    ? Duration(milliseconds: position.round()) 
                    : widget.currentPosition
              );
              
              final totalTimeText = _formatDuration(widget.totalDuration);
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentTimeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    totalTimeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  @override
  void dispose() {
    _sliderPosition.dispose();
    super.dispose();
  }
}
```

3. **Verification**
   - Test slider with various durations
   - Verify smooth dragging and seeking

### 7.2 Optimize Player Widget with ChangeNotifier (1 day)

1. **Write Tests**
   - Test widget rebuilds with performance tracking
   - Verify state updates are properly isolated

2. **Implementation**

```dart
// lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart

class AudioPlayerWidget extends StatefulWidget {
  // Props
  final String filePath;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final AudioErrorType? errorType;
  
  // Callbacks
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  
  const AudioPlayerWidget({
    Key? key,
    required this.filePath,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    required this.isLoading,
    this.error,
    this.errorType,
    this.onPlay,
    this.onPause,
    this.onSeek,
    this.onDelete,
    this.onRetry,
  }) : super(key: key);
  
  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  // Use ValueNotifier for each item that may need independent updates
  late final ValueNotifier<bool> _playingNotifier;
  late final ValueNotifier<bool> _loadingNotifier;
  late final ValueNotifier<String?> _errorNotifier;
  
  bool get _hasError => widget.error != null;
  bool get _canSeek => !widget.isLoading && !_hasError && widget.totalDuration > Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _playingNotifier = ValueNotifier(widget.isPlaying);
    _loadingNotifier = ValueNotifier(widget.isLoading);
    _errorNotifier = ValueNotifier(widget.error);
  }
  
  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update notifiers only when values change
    if (oldWidget.isPlaying != widget.isPlaying) {
      _playingNotifier.value = widget.isPlaying;
    }
    
    if (oldWidget.isLoading != widget.isLoading) {
      _loadingNotifier.value = widget.isLoading;
    }
    
    if (oldWidget.error != widget.error) {
      _errorNotifier.value = widget.error;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        elevation: 2.0,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // File name display
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _getFileName(widget.filePath),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Error display
              ValueListenableBuilder<String?>(
                valueListenable: _errorNotifier,
                builder: (context, error, _) {
                  if (error != null) {
                    return _buildErrorState(error, widget.errorType);
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Slider with position and duration
              AudioSlider(
                currentPosition: widget.currentPosition,
                totalDuration: widget.totalDuration,
                onChangeEnd: _canSeek ? widget.onSeek : null,
                enabled: _canSeek,
              ),
              
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause button with loading indicator
                  ValueListenableBuilder<bool>(
                    valueListenable: _loadingNotifier,
                    builder: (context, isLoading, _) {
                      if (isLoading) {
                        return const SizedBox(
                          width: 48.0,
                          height: 48.0,
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      return ValueListenableBuilder<bool>(
                        valueListenable: _playingNotifier,
                        builder: (context, isPlaying, _) {
                          return IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            iconSize: 36.0,
                            onPressed: _hasError 
                                ? null 
                                : (isPlaying ? widget.onPause : widget.onPlay),
                          );
                        },
                      );
                    },
                  ),
                  
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorState(String errorMessage, AudioErrorType? errorType) {
    // Error UI from Step 3
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Icon(
            _getErrorIcon(errorType),
            color: Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _getErrorAction(errorType),
        ],
      ),
    );
  }
  
  Widget _getErrorAction(AudioErrorType? errorType) {
    switch (errorType) {
      case AudioErrorType.networkError:
        return IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: widget.onRetry,
          tooltip: 'Retry',
        );
      case AudioErrorType.fileNotFound:
        return TextButton(
          onPressed: widget.onDelete,
          child: const Text('Remove'),
        );
      default:
        return IconButton(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.delete),
          tooltip: 'Delete Recording',
        );
    }
  }
  
  IconData _getErrorIcon(AudioErrorType? errorType) {
    // Error icon logic from Step 3
    switch (errorType) {
      case AudioErrorType.networkError:
        return Icons.cloud_off;
      case AudioErrorType.fileNotFound:
        return Icons.file_copy_off;
      case AudioErrorType.permissionDenied:
        return Icons.no_accounts;
      case AudioErrorType.unsupportedFormat:
        return Icons.music_off;
      default:
        return Icons.error_outline;
    }
  }
  
  String _getFileName(String path) {
    return path.split('/').last;
  }
  
  @override
  void dispose() {
    _playingNotifier.dispose();
    _loadingNotifier.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }
}
```

3. **Verification**
   - Run Flutter performance tests
   - Verify widget rebuilds are minimized

### 7.3 Apply Rendering Optimizations (1 day)

1. **Write Tests**
   - Test rendering performance
   - Benchmark different device scenarios

2. **Implementation**

```dart
// lib/features/audio_recorder/presentation/widgets/audio_player_list.dart

class AudioPlayerList extends StatelessWidget {
  final List<String> filePaths;
  final PlaybackInfo? playbackInfo;
  final ValueChanged<String>? onPlayTap;
  final VoidCallback? onPauseTap;
  final Function(String, Duration)? onSeek;
  final ValueChanged<String>? onDelete;
  
  const AudioPlayerList({
    Key? key,
    required this.filePaths,
    this.playbackInfo,
    this.onPlayTap,
    this.onPauseTap,
    this.onSeek,
    this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Apply these optimizations for better scrolling performance
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      itemCount: filePaths.length,
      itemBuilder: (context, index) {
        final filePath = filePaths[index];
        final isActive = playbackInfo?.activeFilePath == filePath;
        
        // Use const constructor for inactive items
        if (!isActive) {
          return _InactiveAudioItem(
            key: ValueKey(filePath),
            filePath: filePath,
            onTap: () => onPlayTap?.call(filePath),
            onDelete: () => onDelete?.call(filePath),
          );
        }
        
        // Only the active item gets full player widget
        return AudioPlayerWidget(
          key: ValueKey('player_$filePath'),
          filePath: filePath,
          currentPosition: playbackInfo?.currentPosition ?? Duration.zero,
          totalDuration: playbackInfo?.totalDuration ?? Duration.zero,
          isPlaying: playbackInfo?.isPlaying ?? false,
          isLoading: playbackInfo?.isLoading ?? false,
          error: playbackInfo?.error,
          errorType: playbackInfo?.errorType,
          onPlay: () => onPlayTap?.call(filePath),
          onPause: onPauseTap,
          onSeek: (position) => onSeek?.call(filePath, position),
          onDelete: () => onDelete?.call(filePath),
        );
      },
    );
  }
}

// Simple widget for inactive items
class _InactiveAudioItem extends StatelessWidget {
  final String filePath;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  
  const _InactiveAudioItem({
    Key? key,
    required this.filePath,
    this.onTap,
    this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.0,
      child: ListTile(
        title: Text(
          filePath.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.audio_file),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
```

3. **Add Rendering Helpers to Main Screen**

```dart
// lib/features/audio_recorder/presentation/screens/audio_list_screen.dart

class AudioListScreen extends StatelessWidget {
  const AudioListScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioListCubit, AudioListState>(
      // Optimize bloc rebuilds
      buildWhen: (previous, current) {
        // Only rebuild for certain state changes
        if (previous is AudioListLoaded && current is AudioListLoaded) {
          final prevFiles = previous.files;
          final currFiles = current.files;
          final prevInfo = previous.playbackInfo;
          final currInfo = current.playbackInfo;
          
          // Skip rebuilds if only position changed slightly
          if (prevFiles == currFiles && 
              prevInfo?.activeFilePath == currInfo?.activeFilePath &&
              prevInfo?.isPlaying == currInfo?.isPlaying &&
              prevInfo?.isLoading == currInfo?.isLoading &&
              prevInfo?.error == currInfo?.error) {
            
            // If only position changed by less than 500ms, don't rebuild
            final prevPos = prevInfo?.currentPosition ?? Duration.zero;
            final currPos = currInfo?.currentPosition ?? Duration.zero;
            if ((currPos - prevPos).abs().inMilliseconds < 500) {
              return false;
            }
          }
        }
        return true;
      },
      builder: (context, state) {
        if (state is AudioListInitial || state is AudioListLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (state is AudioListError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        
        if (state is AudioListLoaded) {
          // Apply caching for list items
          return AudioPlayerList(
            filePaths: state.files,
            playbackInfo: state.playbackInfo,
            onPlayTap: (filePath) => 
                context.read<AudioListCubit>().playRecording(filePath),
            onPauseTap: () => 
                context.read<AudioListCubit>().pausePlayback(),
            onSeek: (filePath, position) => 
                context.read<AudioListCubit>().seekRecording(filePath, position),
            onDelete: (filePath) => 
                context.read<AudioListCubit>().deleteRecording(filePath),
          );
        }
        
        return const Center(child: Text('No recordings found'));
      },
    );
  }
}
```

3. **Verification**
   - Test scrolling performance
   - Verify rendering efficiency with Flutter DevTools

### 7.4 Implement Seek Debouncing in the Service Layer (0.5 day)

1. **Write Tests**
   - Test seek debouncing behavior
   - Verify rapid seeks are properly coalesced

2. **Implementation**

```dart
// Update AudioPlaybackServiceV5Impl or create new implementation

class AudioPlaybackServiceV5Impl implements AudioPlaybackServiceV5 {
  // Other members...
  
  Timer? _seekDebounceTimer;
  Duration? _pendingSeekPosition;
  
  // Improved seek method with debouncing
  @override
  Future<void> seek(Duration position) async {
    if (_currentSession == null) return;
    
    final tag = logTag(AudioPlaybackServiceV5Impl);
    logger.d('$tag seek: Requested (${position.inMilliseconds}ms)');
    
    // Store the requested position
    _pendingSeekPosition = position;
    
    // Cancel any existing timer
    _seekDebounceTimer?.cancel();
    
    // Start a new timer to debounce seeks
    _seekDebounceTimer = Timer(const Duration(milliseconds: 50), () async {
      if (_pendingSeekPosition != null) {
        final finalPosition = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        
        logger.d('$tag seek: Executing with debounce (${finalPosition.inMilliseconds}ms)');
        
        try {
          await _audioPlayerAdapter.seek(finalPosition);
          logger.d('$tag seek: Completed');
        } catch (e, s) {
          logger.e('$tag seek: Failed', error: e, stackTrace: s);
          // Error handling
        }
      }
    });
  }
  
  @override
  Future<void> dispose() async {
    // Existing disposal code
    _seekDebounceTimer?.cancel();
    // Rest of disposal
  }
}
```

3. **Verification**
   - Test rapid seek operations
   - Verify correct final position

### 7.5 Integration Testing and Optimization (0.5 day)

1. **Write Performance Tests**
   - Create test scripts to measure UI responsiveness
   - Benchmark before/after improvements

2. **Integration**
   - Apply all optimizations together
   - Test on various device types and screen sizes

3. **Final Optimizations**
   ```dart
   // Use memory cache for loaded files to avoid reloads
   // lib/features/audio_recorder/data/repositories/audio_file_repository_impl.dart
   
   class AudioFileRepositoryImpl implements AudioFileRepository {
     final _cache = <String, Uint8List>{};
     
     @override
     Future<Uint8List> loadAudioFile(String path) async {
       // Check cache first
       if (_cache.containsKey(path)) {
         return _cache[path]!;
       }
       
       // Load and cache
       final file = File(path);
       final bytes = await file.readAsBytes();
       _cache[path] = bytes;
       return bytes;
     }
     
     // Implement cache cleanup when files are deleted
   }
   ```

4. **Verification**
   - Run final performance tests
   - Verify improvements across different devices

## Success Criteria

1. Smooth slider operation during seeking
2. No UI jank during playback
3. Efficient list scrolling, even with many items
4. Reduced widget rebuilds (measurable in Flutter DevTools)
5. Improved responsiveness to user input
6. Memory usage remains controlled

## Risks and Mitigations

**Risk**: ValueNotifier updates causing too many rebuilds
**Mitigation**: Careful scoping of ValueListenableBuilder widgets

**Risk**: Debouncing affects user experience
**Mitigation**: Tune debounce timings to balance responsiveness and performance

**Risk**: Performance optimizations increase code complexity
**Mitigation**: Clear documentation and extensive tests 