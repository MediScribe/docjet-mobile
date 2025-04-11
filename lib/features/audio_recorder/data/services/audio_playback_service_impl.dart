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
    logger.d('[SERVICE_INIT] Creating AudioPlaybackServiceImpl instance.');
    // Immediately subscribe to the mapper's output stream
    _mapperSubscription = _playbackStateMapper.playbackStateStream.listen(
      (state) {
        // COMMENT OUT VERBOSE LOG
        // logger.d('[SERVICE_RX] Received PlaybackState from Mapper: $state');
        _lastKnownState = state; // Update last known state
        _playbackStateSubject.add(state); // Forward state to external listeners
      },
      onError: (error, stackTrace) {
        // Added stackTrace
        logger.e(
          '[SERVICE_RX] Error from mapper stream',
          error: error,
          stackTrace: stackTrace,
        );
        _playbackStateSubject.addError(error, stackTrace); // Forward stackTrace
        // Potentially add a specific error state here?
        _playbackStateSubject.add(
          PlaybackState.error(
            message: 'Playback error: $error',
          ), // Include error
        );
      },
      onDone: () {
        logger.d('[SERVICE_RX] Mapper stream closed');
        _playbackStateSubject.close();
      },
    );
    logger.d('[SERVICE_INIT] Initialized and subscribed to mapper stream.');
  }

  @override
  Stream<PlaybackState> get playbackStateStream {
    logger.d('[SERVICE_STREAM] playbackStateStream accessed.');
    return _playbackStateSubject.stream;
  }

  @override
  Future<void> play(String pathOrUrl) async {
    final trace = StackTrace.current;
    logger.d('[SERVICE PLAY $pathOrUrl] START', stackTrace: trace);
    try {
      final isSameFile = pathOrUrl == _currentFilePath;
      // Check if the last known state was paused
      final isPaused = _lastKnownState.maybeWhen(
        paused: (_, __) => true, // It's paused if it matches the paused state
        orElse:
            () => false, // Otherwise, it's not considered paused for this logic
      );

      logger.d(
        '[SERVICE PLAY $pathOrUrl] State Check: isSameFile: $isSameFile, isPaused: $isPaused, lastKnownState: $_lastKnownState',
      );

      if (isSameFile && isPaused) {
        // Same file and was paused -> Just resume playback
        logger.d('[SERVICE PLAY $pathOrUrl] Action: Resuming paused file...');
        await _audioPlayerAdapter.resume();
        logger.d('[SERVICE PLAY $pathOrUrl] Adapter resume() call completed.');
      } else {
        // Different file OR wasn't paused -> Full stop/load/play sequence
        logger.d(
          '[SERVICE PLAY $pathOrUrl] Action: Performing full restart (different file or not paused)...',
        );

        // Always perform a full stop first to ensure clean state
        logger.d('[SERVICE PLAY $pathOrUrl] Action: Calling adapter.stop()...');
        await _audioPlayerAdapter.stop();
        logger.d('[SERVICE PLAY $pathOrUrl] Adapter stop() call complete.');

        // Update current path ONLY if it's a different file
        if (!isSameFile) {
          logger.d('[SERVICE PLAY $pathOrUrl] Action: Updating file path...');
          _playbackStateMapper.setCurrentFilePath(pathOrUrl);
          _currentFilePath = pathOrUrl; // Update internal tracking
          logger.d('[SERVICE PLAY $pathOrUrl] File path updated.');
        } else {
          logger.d(
            '[SERVICE PLAY $pathOrUrl] Action: Skipping file path update (same file).',
          );
        }

        logger.d(
          '[SERVICE PLAY $pathOrUrl] Action: Calling adapter.setSourceUrl()...',
        );
        await _audioPlayerAdapter.setSourceUrl(pathOrUrl);
        logger.d(
          '[SERVICE PLAY $pathOrUrl] Adapter setSourceUrl() call complete.',
        );

        logger.d(
          '[SERVICE PLAY $pathOrUrl] Action: Calling adapter.resume() (for start)...',
        );
        await _audioPlayerAdapter.resume();
        logger.d(
          '[SERVICE PLAY $pathOrUrl] Adapter resume() (for start) call complete.',
        );
      }

      logger.d('[SERVICE PLAY $pathOrUrl] END (Success)');
    } catch (e, s) {
      logger.e('[SERVICE PLAY $pathOrUrl] FAILED', error: e, stackTrace: s);
      _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    final trace = StackTrace.current;
    logger.d('[SERVICE PAUSE] START', stackTrace: trace);
    try {
      await _audioPlayerAdapter.pause();
      logger.d('[SERVICE PAUSE] Adapter pause() call complete.');
    } catch (e, s) {
      logger.e('[SERVICE PAUSE] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE PAUSE] END');
  }

  @override
  Future<void> resume() async {
    final trace = StackTrace.current;
    logger.d('[SERVICE RESUME] START', stackTrace: trace);
    try {
      // Just resume from current position, no seeking needed
      logger.d('[SERVICE RESUME] Action: Calling adapter.resume()');
      await _audioPlayerAdapter.resume();
      logger.d('[SERVICE RESUME] Adapter resume() call complete.');
    } catch (e, s) {
      logger.e('[SERVICE RESUME] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE RESUME] END');
  }

  @override
  Future<void> seek(Duration position) async {
    final trace = StackTrace.current;
    logger.d(
      '[SERVICE SEEK ${position.inMilliseconds}ms] START',
      stackTrace: trace,
    );
    try {
      logger.d(
        '[SERVICE SEEK] Action: Calling adapter.seek(${position.inMilliseconds}ms)',
      );
      await _audioPlayerAdapter.seek(position);
      logger.d('[SERVICE SEEK] Adapter seek() call complete.');
    } catch (e, s) {
      logger.e('[SERVICE SEEK] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE SEEK ${position.inMilliseconds}ms] END');
  }

  @override
  Future<void> stop() async {
    final trace = StackTrace.current;
    logger.d('[SERVICE STOP] START', stackTrace: trace);
    try {
      logger.d('[SERVICE STOP] Action: Calling adapter.stop()');
      await _audioPlayerAdapter.stop();
      logger.d('[SERVICE STOP] Adapter stop() call complete.');
    } catch (e, s) {
      logger.e('[SERVICE STOP] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE STOP] END');
  }

  @override
  Future<void> dispose() async {
    logger.d('[SERVICE DISPOSE] START');
    try {
      logger.d('[SERVICE DISPOSE] Action: Calling adapter.dispose()');
      await _audioPlayerAdapter.dispose();
      logger.d('[SERVICE DISPOSE] Action: Calling mapper.dispose()');
      _playbackStateMapper.dispose();
      logger.d('[SERVICE DISPOSE] Action: Cancelling mapper subscription');
      await _mapperSubscription.cancel();
      logger.d('[SERVICE DISPOSE] Action: Closing playback state subject');
      await _playbackStateSubject.close();
    } catch (e, s) {
      logger.e(
        '[SERVICE DISPOSE] FAILED during cleanup',
        error: e,
        stackTrace: s,
      );
      // Decide if rethrow is appropriate during dispose
    }
    logger.d('[SERVICE DISPOSE] END');
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
