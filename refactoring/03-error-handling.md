# Step 3: Improve Error Handling

## Overview

This step standardizes error handling across the audio player components, improves error reporting, and provides better recovery options.

**Estimated time:** 8 days

## Problem Statement

Error handling is currently scattered across multiple layers with inconsistent approaches:

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

This approach leads to:
- Inconsistent error propagation (sometimes rethrown, sometimes converted to states)
- Duplicate error handling (multiple layers log the same error)
- Limited recovery options (current error handling focuses on reporting, not recovery)
- Generic error messages (not helpful for users or developers)

## Implementation Steps

### 3.1 Create Audio Error Types (2 days)

1. **Write Tests**
   - Create tests for error type classification
   - Test error factory methods and constructors
   - Verify serialization/deserialization if needed

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/entities/audio_error.dart

enum AudioErrorType {
  networkError,
  fileNotFound,
  permissionDenied,
  unsupportedFormat,
  playerError,
  unknown,
}

class AudioError implements Exception {
  final AudioErrorType type;
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;
  
  const AudioError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });
  
  @override
  String toString() => 'AudioError($type): $message';
  
  // Factory constructors for common errors
  factory AudioError.fromException(Object e, [StackTrace? stackTrace]) {
    if (e is FileSystemException) {
      return AudioError(
        type: AudioErrorType.fileNotFound,
        message: 'Audio file not found or inaccessible',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
    
    if (e is FormatException) {
      return AudioError(
        type: AudioErrorType.unsupportedFormat,
        message: 'Audio format not supported',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
    
    // Handle other error types
    
    return AudioError(
      type: AudioErrorType.unknown,
      message: 'An unexpected error occurred: ${e.toString()}',
      originalError: e,
      stackTrace: stackTrace,
    );
  }
  
  factory AudioError.fileNotFound(String path, [Object? originalError]) {
    return AudioError(
      type: AudioErrorType.fileNotFound,
      message: 'Audio file not found: $path',
      originalError: originalError,
    );
  }
  
  // Add other factory methods for common errors
}
```

3. **Update PlaybackState**

```dart
// lib/features/audio_recorder/domain/entities/playback_state.dart

@freezed
abstract class PlaybackState with _$PlaybackState {
  // Existing states...
  
  // Updated error state that includes error type
  const factory PlaybackState.error({
    required String message,
    required AudioErrorType errorType,
    Duration? currentPosition,
    Duration? totalDuration,
  }) = _Error;
}
```

4. **Verification**
   - Run tests for error types and classification
   - Verify PlaybackState updates work with error types

### 3.2 Update Adapter Error Handling (1 day)

1. **Write Tests**
   - Create tests for adapter error handling
   - Test specific error scenarios (file not found, etc)

2. **Implementation**

```dart
// lib/features/audio_recorder/data/adapters/audio_player_adapter_v2_impl.dart

@override
Future<void> setSourceUrl(String url) async {
  final tag = logTag(AudioPlayerAdapterV2Impl);
  logger.d('$tag setSourceUrl: Started ($url)');
  try {
    _currentFilePath = url;
    await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
    logger.d('$tag setSourceUrl: Completed');
  } catch (e, s) {
    logger.e('$tag setSourceUrl: Failed', error: e, stackTrace: s);
    // Convert to domain error
    if (e is PlayerException) {
      throw AudioError(
        type: AudioErrorType.playerError,
        message: 'Failed to load audio source: ${e.message}',
        originalError: e,
        stackTrace: s,
      );
    } else if (e is FormatException) {
      throw AudioError(
        type: AudioErrorType.unsupportedFormat,
        message: 'Audio format not supported',
        originalError: e,
        stackTrace: s,
      );
    } else {
      throw AudioError.fromException(e, s);
    }
  }
}

// Update other methods similarly
```

3. **Verification**
   - Run adapter tests
   - Verify errors are properly converted to domain errors

### 3.3 Update Service Error Handling (2 days)

1. **Write Tests**
   - Create tests for service error handling
   - Test error propagation through PlaybackState

2. **Implementation**

```dart
// lib/features/audio_recorder/data/services/audio_playback_service_v2_impl.dart

@override
Future<void> play(String filePath) async {
  final tag = logTag(AudioPlaybackServiceV2Impl);
  logger.d('$tag play: Started ($filePath)');
  
  try {
    // Check if file exists first
    if (!await _fileSystem.exists(filePath)) {
      final error = AudioError.fileNotFound(filePath);
      logger.e('$tag play: ${error.message}');
      _playbackStateSubject.add(PlaybackState.error(
        message: error.message,
        errorType: error.type,
      ));
      return; // Return early, don't throw
    }
    
    // Existing implementation
    
    logger.d('$tag play: Completed');
  } catch (e, s) {
    logger.e('$tag play: Failed', error: e, stackTrace: s);
    
    // Convert to AudioError if not already
    final audioError = e is AudioError ? e : AudioError.fromException(e, s);
    
    // Emit error state instead of throwing
    _playbackStateSubject.add(PlaybackState.error(
      message: audioError.message,
      errorType: audioError.type,
      currentPosition: _currentPosition,
      totalDuration: _currentDuration,
    ));
    
    // Don't rethrow - errors are now part of the state
  }
}

// Update other methods similarly
```

3. **Verification**
   - Run service tests with different error scenarios
   - Verify errors are correctly propagated as PlaybackState.error

### 3.4 Update UI Error Handling (2 days)

1. **Write Tests**
   - Create widget tests for error states
   - Test error UI components

2. **Implementation**

```dart
// Update PlaybackInfo in audio_list_state.dart

class PlaybackInfo extends Equatable {
  // Existing fields
  final AudioErrorType? errorType;
  
  // Updated constructor
  const PlaybackInfo({
    this.activeFilePath,
    required this.isPlaying,
    required this.isLoading,
    required this.currentPosition,
    required this.totalDuration,
    this.error,
    this.errorType,
  });
}

// Update AudioListCubit state mapping

void _onPlaybackStateChanged(PlaybackState playbackState) {
  // Existing code
  
  // Extract data from the incoming PlaybackState
  playbackState.when(
    // Other states...
    error: (message, errorType, pos, dur) {
      error = message;
      errorType = errorType;
      if (pos != null) currentPosition = pos;
      if (dur != null) totalDuration = dur;
      isPlaying = false;
      isLoading = false;
    },
  );
  
  // Create updated PlaybackInfo with error type
  final newPlaybackInfo = PlaybackInfo(
    activeFilePath: activeFilePath,
    isPlaying: isPlaying,
    isLoading: isLoading,
    currentPosition: currentPosition,
    totalDuration: totalDuration,
    error: error,
    errorType: errorType,
  );
}
```

3. **Enhance Error UI in Widget**

```dart
// lib/features/audio_recorder/presentation/widgets/audio_player_widget.dart

Widget _buildErrorState(String errorMessage, AudioErrorType? errorType) {
  Widget actionButton;
  
  // Choose action based on error type
  switch (errorType) {
    case AudioErrorType.networkError:
      actionButton = IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: widget.onRetry,
        tooltip: 'Retry',
      );
      break;
    case AudioErrorType.fileNotFound:
      actionButton = TextButton(
        onPressed: widget.onDelete,
        child: const Text('Remove'),
      );
      break;
    default:
      actionButton = IconButton(
        onPressed: widget.onDelete,
        icon: const Icon(Icons.delete),
        tooltip: 'Delete Recording',
      );
  }
  
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
        actionButton,
      ],
    ),
  );
}

IconData _getErrorIcon(AudioErrorType? errorType) {
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
```

4. **Verification**
   - Test the UI with different error types
   - Verify appropriate recovery actions are displayed

### 3.5 Integration and Cutover (1 day)

1. **Integration Testing**
   - Test the full error flow from adapter to UI
   - Verify all error types show appropriate UI

2. **Cutover**
   - Update feature flags to use the new implementation
   - Test in staging environment
   - Deploy to production

## Success Criteria

1. All errors are properly categorized with specific error types
2. Each layer handles errors appropriately without duplicating work:
   - Adapter: Converts platform errors to domain errors
   - Service: Converts errors to state without rethrowing
   - UI: Displays appropriate error UI and recovery options
3. Users have clear recovery paths for common errors
4. Developers can easily identify the root cause of issues
5. No functional behavior has changed for non-error paths

## Risks and Mitigations

**Risk**: Missing error cases
**Mitigation**: Thorough testing with mock errors of each type

**Risk**: UI recovery options not appropriate for all errors
**Mitigation**: User testing with simulated errors

**Risk**: Error type proliferation
**Mitigation**: Keep error types focused on user-actionable categories 