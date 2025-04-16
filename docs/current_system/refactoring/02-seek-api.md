# Step 2: Fix the `seek` API Inconsistency

## Overview

This step resolves the inconsistency where the adapter's `seek` method takes a `filePath` parameter but doesn't use it. This change clarifies responsibilities between layers.

**Estimated time:** 8 days

## Problem Statement

The current `AudioPlayerAdapter` interface defines:

```dart
Future<void> seek(String filePath, Duration position);
```

But the implementation with `just_audio` doesn't use the `filePath` parameter:

```dart
@override
Future<void> seek(String filePath, Duration position) async {
  // Note: filePath is required by the interface, but just_audio's seek only uses position.
  logger.d('$_tag seek: Started (file: $filePath, pos: ${position.inMilliseconds}ms)');
  try {
    await _audioPlayer.seek(position);
    logger.d('$_tag seek: Completed');
  } catch (e, s) {
    logger.e('$_tag seek: Failed', error: e, stackTrace: s);
    rethrow;
  }
}
```

This creates confusion about whether the file path is actually needed, and how seek behaves across different audio files.

## Implementation Steps

### 2.1 Create New Adapter Interface and Implementation (2 days)

1. **Write Tests**
   - Create tests for the new adapter interface with the updated `seek` method
   - Ensure tests cover all use cases of seeking

2. **Implementation**

```dart
// lib/features/audio_recorder/domain/adapters/audio_player_adapter_v2.dart

abstract class AudioPlayerAdapterV2 {
  // Other method signatures remain the same
  
  // Updated seek method signature without filePath
  Future<void> seek(Duration position);
  
  // Add getter for current file path
  String? get currentFilePath;
}

// lib/features/audio_recorder/data/adapters/audio_player_adapter_v2_impl.dart

class AudioPlayerAdapterV2Impl implements AudioPlayerAdapterV2 {
  final AudioPlayer _audioPlayer;
  String? _currentFilePath;
  
  // Constructor
  
  @override
  String? get currentFilePath => _currentFilePath;
  
  @override
  Future<void> setSourceUrl(String url) async {
    _currentFilePath = url;
    // Existing implementation
    await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
  }
  
  @override
  Future<void> seek(Duration position) async {
    final tag = logTag(AudioPlayerAdapterV2Impl);
    logger.d('$tag seek: Started (${position.inMilliseconds}ms)');
    try {
      await _audioPlayer.seek(position);
      logger.d('$tag seek: Completed');
    } catch (e, s) {
      logger.e('$tag seek: Failed', error: e, stackTrace: s);
      rethrow;
    }
  }
  
  // Other methods...
}
```

3. **Verification**
   - Run tests for the new adapter implementation
   - Verify it correctly handles seeking behavior

### 2.2 Create Adapter Factory with Feature Flag (1 day)

Implement a factory to control which adapter implementation is used:

1. **Implementation**

```dart
// lib/features/audio_recorder/data/factories/audio_player_adapter_factory.dart

class AudioPlayerAdapterFactory {
  // Feature flag for using new adapter
  static bool useNewAdapterImplementation = false;
  
  static AudioPlayerAdapter create(AudioPlayer audioPlayer) {
    if (useNewAdapterImplementation) {
      // Create legacy adapter that delegates to new adapter
      return _LegacyAdapterBridge(
        AudioPlayerAdapterV2Impl(audioPlayer)
      );
    } else {
      return AudioPlayerAdapterImpl(audioPlayer);
    }
  }
}

// Bridge adapter to maintain backward compatibility
class _LegacyAdapterBridge implements AudioPlayerAdapter {
  final AudioPlayerAdapterV2 _newAdapter;
  
  _LegacyAdapterBridge(this._newAdapter);
  
  @override
  Future<void> seek(String filePath, Duration position) async {
    // Ignore filePath parameter, use position only
    await _newAdapter.seek(position);
  }
  
  // Other delegated methods...
}
```

2. **Update DI Container**

```dart
// lib/core/di/injection_container.dart

sl.registerLazySingleton<AudioPlayerAdapter>(
  () => AudioPlayerAdapterFactory.create(sl<just_audio.AudioPlayer>()),
);
```

3. **Verification**
   - Run tests with both adapter implementations
   - Verify the bridge correctly translates between interfaces

### 2.3 Update Service Implementation (2 days)

Create a new version of `AudioPlaybackService` that works with the updated adapter:

1. **Write Tests**
   - Create tests for the new service implementation
   - Ensure tests cover all seeking scenarios (same file, different file)

2. **Implementation**

```dart
// lib/features/audio_recorder/data/services/audio_playback_service_v2_impl.dart

class AudioPlaybackServiceV2Impl implements AudioPlaybackService {
  final AudioPlayerAdapterV2 _audioPlayerAdapter;
  final PlaybackStateMapper _playbackStateMapper;
  
  // Constructor and other members
  
  @override
  Future<void> seek(String filePath, Duration position) async {
    final tag = logTag(AudioPlaybackServiceV2Impl);
    logger.d('$tag seek: Started (file: $filePath, pos: ${position.inMilliseconds}ms)');
    
    try {
      final isCurrentFile = filePath == _audioPlayerAdapter.currentFilePath;
      
      if (isCurrentFile) {
        // Simple case: seeking within current file
        await _audioPlayerAdapter.seek(position);
      } else {
        // Complex case: seeking in a different file
        await _seekInNewContext(filePath, position);
      }
      
      logger.d('$tag seek: Completed');
    } catch (e, s) {
      logger.e('$tag seek: Failed', error: e, stackTrace: s);
      rethrow;
    }
  }
  
  // Private helper for seeking in a new file
  Future<void> _seekInNewContext(String filePath, Duration position) async {
    await _audioPlayerAdapter.stop();
    await _audioPlayerAdapter.setSourceUrl(filePath);
    await _audioPlayerAdapter.seek(position);
    await _audioPlayerAdapter.pause(); // Prevent auto-play
  }
  
  // Other methods...
}
```

3. **Create Service Factory**

```dart
// lib/features/audio_recorder/data/factories/audio_playback_service_factory.dart

class AudioPlaybackServiceFactory {
  static bool useNewServiceImplementation = false;
  
  static AudioPlaybackService create({
    required AudioPlayerAdapter adapter,
    required PlaybackStateMapper mapper
  }) {
    if (useNewServiceImplementation) {
      // Cast adapter to new version if using new implementation
      // or wrap legacy adapter in a forward adapter
      final adapterV2 = adapter is _LegacyAdapterBridge
          ? (adapter as _LegacyAdapterBridge)._newAdapter
          : _ForwardAdapterBridge(adapter);
      
      return AudioPlaybackServiceV2Impl(
        audioPlayerAdapter: adapterV2,
        playbackStateMapper: mapper,
      );
    } else {
      return AudioPlaybackServiceImpl(
        audioPlayerAdapter: adapter,
        playbackStateMapper: mapper,
      );
    }
  }
}
```

4. **Update DI Container**

```dart
sl.registerLazySingleton<AudioPlaybackService>(() {
  final adapter = sl<AudioPlayerAdapter>();
  final mapper = sl<PlaybackStateMapper>();
  
  // Initialize mapper with adapter streams
  (mapper as PlaybackStateMapperImpl).initialize(
    playerStateStream: adapter.onPlayerStateChanged,
    positionStream: adapter.onPositionChanged,
    durationStream: adapter.onDurationChanged,
    completeStream: adapter.onPlayerComplete,
  );
  
  // Create service using factory
  return AudioPlaybackServiceFactory.create(
    adapter: adapter,
    mapper: mapper,
  );
});
```

5. **Verification**
   - Run tests with both configurations
   - Test all seek scenarios

### 2.4 Testing and Cutover (2 days)

1. **Integration Testing**
   - Test both implementations through the UI
   - Verify seeking works identically in both implementations
   - Test edge cases (seeking at start/end, during loading, etc.)

2. **Gradual Cutover**
   - Enable new adapter in test environment:
     ```dart
     AudioPlayerAdapterFactory.useNewAdapterImplementation = true;
     ```
   - Test thoroughly
   - Enable new service:
     ```dart
     AudioPlaybackServiceFactory.useNewServiceImplementation = true;
     ```
   - Test thoroughly

3. **Production Rollout**
   - Deploy with feature flags enabled
   - Monitor for issues
   - If successful, update code to remove old implementations and bridges

### 2.5 Cleanup (1 day)

1. **Remove Old Code**
   - Delete the old `AudioPlayerAdapter.seek` API
   - Update all references to use the new API
   - Remove bridge adapters and factories
   - Update tests to use the new API directly

2. **Final Verification**
   - Run full test suite
   - Verify all seek functionality works correctly

## Success Criteria

1. The adapter API accurately reflects its behavior (not requiring unused parameters)
2. The service layer correctly handles seeking in both same-file and different-file contexts
3. All tests pass with the new implementation
4. Feature flags can be safely removed after successful verification
5. Seeking behavior is identical to the original implementation

## Risks and Mitigations

**Risk**: Breaking changes to API consumers
**Mitigation**: Use bridge adapters to maintain backward compatibility during transition

**Risk**: Edge cases in seeking behavior being overlooked
**Mitigation**: Comprehensive test coverage for different seeking scenarios

**Risk**: Performance regression
**Mitigation**: Benchmark seeking performance with both implementations 