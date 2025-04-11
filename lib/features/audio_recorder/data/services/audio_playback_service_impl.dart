import 'dart:async';

import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:rxdart/rxdart.dart';

/// Concrete implementation of [AudioPlaybackService] using the adapter and mapper pattern.
/// This service orchestrates the interactions between the [AudioPlayerAdapter] and
/// [PlaybackStateMapper] to provide a clean, testable audio playback service.
class AudioPlaybackServiceImpl implements AudioPlaybackService {
  final AudioPlayerAdapter _audioPlayerAdapter;
  final PlaybackStateMapper _playbackStateMapper;

  final BehaviorSubject<PlaybackState> _playbackStateSubject;
  late final StreamSubscription<PlaybackState> _mapperSubscription;

  // Keep track of the currently loaded path and the last known state
  String? _currentFilePath;
  PlaybackState _lastKnownState = const PlaybackState.initial();

  /// Creates an instance of [AudioPlaybackServiceImpl].
  ///
  /// Requires an [AudioPlayerAdapter] and [PlaybackStateMapper] to be injected.
  AudioPlaybackServiceImpl({
    required AudioPlayerAdapter audioPlayerAdapter,
    required PlaybackStateMapper playbackStateMapper,
  }) : _audioPlayerAdapter = audioPlayerAdapter,
       _playbackStateMapper = playbackStateMapper,
       _playbackStateSubject = BehaviorSubject<PlaybackState>() {
    // Immediately subscribe to the mapper's output stream
    _mapperSubscription = _playbackStateMapper.playbackStateStream.listen(
      (state) {
        logger.d('[SERVICE] Received PlaybackState from Mapper: $state');
        _lastKnownState = state; // Update last known state
        _playbackStateSubject.add(state); // Forward state to external listeners
      },
      onError: (error) {
        logger.e('[SERVICE] Error from mapper stream: $error');
        _playbackStateSubject.addError(error);
        // Potentially add a specific error state here?
        _playbackStateSubject.add(
          const PlaybackState.error(message: 'Playback error'),
        );
      },
      onDone: () {
        logger.d('[SERVICE] Mapper stream closed');
        _playbackStateSubject.close();
      },
    );
    logger.d('[SERVICE] Initialized and subscribed to mapper stream.');
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;

  @override
  Future<void> play(String pathOrUrl) async {
    logger.d('SERVICE PLAY [$pathOrUrl]: START');
    try {
      final isSameFile = pathOrUrl == _currentFilePath;
      // Check if the last known state was paused
      final isPaused = _lastKnownState.maybeWhen(
        paused: (_, __) => true, // It's paused if it matches the paused state
        orElse:
            () => false, // Otherwise, it's not considered paused for this logic
      );

      logger.d(
        'SERVICE PLAY [$pathOrUrl]: isSameFile: $isSameFile, isPaused: $isPaused',
      );

      if (isSameFile && isPaused) {
        // Same file and was paused -> Just resume playback
        logger.d('SERVICE PLAY [$pathOrUrl]: Resuming paused file...');
        await _audioPlayerAdapter
            .resume(); // This maps to the underlying player's play/resume
        logger.d('SERVICE PLAY [$pathOrUrl]: Resume call completed.');
      } else {
        // Different file OR wasn't paused -> Full stop/load/play sequence
        logger.d(
          'SERVICE PLAY [$pathOrUrl]: Performing full restart (different file or not paused)...',
        );

        // Always perform a full stop first to ensure clean state
        logger.d('SERVICE PLAY [$pathOrUrl]: Calling stop...');
        await _audioPlayerAdapter.stop();
        logger.d('SERVICE PLAY [$pathOrUrl]: Stop complete.');

        // Update current path ONLY if it's a different file
        if (!isSameFile) {
          logger.d('SERVICE PLAY [$pathOrUrl]: Setting mapper path...');
          _playbackStateMapper.setCurrentFilePath(pathOrUrl);
          _currentFilePath = pathOrUrl; // Update internal tracking
          logger.d('SERVICE PLAY [$pathOrUrl]: Mapper path set.');
        }

        logger.d('SERVICE PLAY [$pathOrUrl]: Calling setSourceUrl...');
        await _audioPlayerAdapter.setSourceUrl(pathOrUrl);
        logger.d('SERVICE PLAY [$pathOrUrl]: setSourceUrl complete.');

        logger.d('SERVICE PLAY [$pathOrUrl]: Calling resume (for start)...');
        await _audioPlayerAdapter.resume(); // Start playback from beginning
        logger.d('SERVICE PLAY [$pathOrUrl]: Resume (for start) complete.');
      }

      logger.d('SERVICE PLAY [$pathOrUrl]: END (Success)');
    } catch (e, s) {
      logger.e('SERVICE PLAY [$pathOrUrl]: FAILED', error: e, stackTrace: s);
      _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
      // Rethrow or handle as needed
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    logger.d('SERVICE PAUSE: START');
    await _audioPlayerAdapter.pause();
    logger.d('SERVICE PAUSE: Complete');
  }

  @override
  Future<void> resume() async {
    logger.d('SERVICE RESUME: START');

    // Just resume from current position, no seeking needed
    logger.d('SERVICE RESUME: Calling adapter.resume()');
    await _audioPlayerAdapter.resume();

    logger.d('SERVICE RESUME: Complete');
  }

  @override
  Future<void> seek(Duration position) async {
    logger.d(
      'SERVICE SEEK: Calling adapter.seek(${position.inMilliseconds}ms)',
    );
    await _audioPlayerAdapter.seek(position);
    logger.d('SERVICE SEEK: Complete');
  }

  @override
  Future<void> stop() async {
    logger.d('SERVICE STOP: Calling adapter.stop()');
    await _audioPlayerAdapter.stop();
    logger.d('SERVICE STOP: Complete');
  }

  @override
  Future<void> dispose() async {
    logger.d('SERVICE DISPOSE: Starting');
    await _audioPlayerAdapter.dispose();
    _playbackStateMapper.dispose();
    // Also cancel the subscription to avoid leaks
    await _mapperSubscription.cancel();
    // Close the subject
    await _playbackStateSubject.close();
    logger.d('SERVICE DISPOSE: Complete');
  }
}

// Helper extension moved here to access private members for testing
// @visibleForTesting // REMOVED - Causes issues, use direct access in test if needed
// extension AudioPlaybackServiceTestExtension on AudioPlaybackServiceImpl {
//   void setCurrentFilePathForTest(String path) {
//     // This exposes internal state for testing. Use with caution.
//     // Consider if tests can be structured differently to avoid this.
//     _currentFilePath = path;
//   }
// }
