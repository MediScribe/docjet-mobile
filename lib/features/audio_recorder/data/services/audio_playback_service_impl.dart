import 'dart:async';

import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:rxdart/rxdart.dart';

// Set Logger Level to DEBUG for active development/debugging in this file
final logger = Logger(level: Level.debug);

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
        logger.t('[STATE_FLOW Service] Received state from mapper: $state');
        _lastKnownState = state;
        _playbackStateSubject.add(state);
      },
      onError: (error, stackTrace) {
        logger.e(
          '[STATE_FLOW Service] Error in playback state stream',
          error: error,
          stackTrace: stackTrace,
        );
        _playbackStateSubject.add(
          PlaybackState.error(message: error.toString()),
        );
      },
      onDone: () {
        logger.i('[STATE_FLOW Service] Playback state stream closed.');
        _playbackStateSubject.close();
      },
    );
    logger.d('[SERVICE_INIT] Initialized and subscribed to mapper stream.');
  }

  @override
  Stream<PlaybackState> get playbackStateStream {
    // logger.d('[SERVICE_STREAM] playbackStateStream accessed.'); // Removed: Noisy
    return _playbackStateSubject.stream;
  }

  @override
  Future<void> play(String pathOrUrl) async {
    final flowId = DateTime.now().millisecondsSinceEpoch % 10000;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    logger.d(
      '[FLOW #$flowId] [SERVICE PLAY DECISION] START for path: ${_truncatePath(pathOrUrl)}',
    );
    final trace = StackTrace.current;
    logger.d(
      '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] START',
      stackTrace: trace,
    );
    try {
      final isSameFile = pathOrUrl == _currentFilePath;
      final isPaused = _lastKnownState.maybeWhen(
        paused: (_, __) => true,
        orElse: () => false,
      );

      logger.d(
        '[FLOW #$flowId] [SERVICE PLAY DECISION] State Check: isSameFile: $isSameFile, isPaused: $isPaused, _lastKnownState: $_lastKnownState',
      );

      if (isSameFile && isPaused) {
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY DECISION] Same file and paused, just resuming',
        );
        await _audioPlayerAdapter.resume();
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Adapter resume() call complete.',
        );
      } else {
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY DECISION] Different file or not paused, performing full restart',
        );
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Action: Calling adapter.stop()...',
        );
        await _audioPlayerAdapter.stop();
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Adapter stop() call complete.',
        );

        // Only update _currentFilePath if the path is actually changing
        if (pathOrUrl != _currentFilePath) {
          _currentFilePath = pathOrUrl;
          // logger.d('  -> _currentFilePath SET to: $pathOrUrl');
        }

        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Action: Calling adapter.setSourceUrl()...',
        );
        await _audioPlayerAdapter.setSourceUrl(pathOrUrl);
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Adapter setSourceUrl() call complete.',
        );

        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Action: Calling adapter.resume() (for start)...',
        );
        await _audioPlayerAdapter.resume();
        logger.d(
          '[FLOW #$flowId] [SERVICE PLAY $pathOrUrl] Adapter resume() (for start) call complete.',
        );
      }
    } catch (e, s) {
      logger.e(
        '[FLOW #$flowId] [SERVICE PLAY DECISION] ERROR',
        error: e,
        stackTrace: s,
      );
      _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
      rethrow;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
    logger.d(
      '[FLOW #$flowId] [SERVICE TIMING] play() took ${elapsed}ms to complete',
    );
    logger.d('[FLOW #$flowId] [SERVICE PLAY DECISION] END');
  }

  @override
  Future<void> pause() async {
    logger.d(
      '[SERVICE PAUSE DECISION] START, current state: ${_lastKnownState.runtimeType}',
    );
    final trace = StackTrace.current;
    logger.d('[SERVICE PAUSE] START', stackTrace: trace);
    try {
      await _audioPlayerAdapter.pause();
      // logger.d('[SERVICE PAUSE] Adapter pause() call complete.'); // Keep DEBUG
    } catch (e, s) {
      logger.e('[SERVICE PAUSE DECISION] ERROR', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE PAUSE DECISION] END');
  }

  @override
  Future<void> resume() async {
    final trace = StackTrace.current;
    logger.d('[SERVICE RESUME] START', stackTrace: trace);
    try {
      // Just resume from current position, no seeking needed
      logger.d('[SERVICE RESUME] Action: Calling adapter.resume()');
      await _audioPlayerAdapter.resume();
      // logger.d('[SERVICE RESUME] Adapter resume() call complete.'); // Keep DEBUG
    } catch (e, s) {
      logger.e('[SERVICE RESUME] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE RESUME] END');
  }

  @override
  Future<void> seek(String filePath, Duration position) async {
    logger.d(
      '[SERVICE SEEK DECISION] START for path: ${_truncatePath(filePath)}, position: ${position.inMilliseconds}ms',
    );
    try {
      final isTargetSameAsCurrent = filePath == _currentFilePath;

      // Scenario 1: Seeking within the currently playing/paused file
      if (isTargetSameAsCurrent && _currentFilePath != null) {
        logger.d('[SERVICE SEEK DECISION] Same file, seeking within current');
        // logger.d(
        //   '[SERVICE SEEK $filePath] Action: Seeking within current file. Calling adapter.seek...',
        // );
        await _audioPlayerAdapter.seek(_currentFilePath!, position);
        // logger.d('[SERVICE SEEK $filePath] Adapter seek() call complete.');

        // If seeking while paused, adapter might emit paused. If seeking while playing,
        // it should continue playing from new position (adapter handles state).
        // We don't need to explicitly pause/resume here.
      }
      // Scenario 2: Seeking to a new file or seeking when player is stopped/initial
      else {
        logger.d(
          '[SERVICE SEEK DECISION] New file or null current, priming the pump',
        );
        // 1. Stop any current playback
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: Calling adapter.stop()...',
        // );
        await _audioPlayerAdapter.stop();

        // 2. Update internal state and load new source
        _currentFilePath = filePath;
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: Updated _currentFilePath. Calling adapter.setSourceUrl()...',
        // );
        await _audioPlayerAdapter.setSourceUrl(filePath);
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: adapter.setSourceUrl() complete.',
        // );

        // 3. Seek to the desired position
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: Calling adapter.seek($position)...',
        // );
        await _audioPlayerAdapter.seek(filePath, position);
        // logger.d('[SERVICE SEEK $filePath] Priming: adapter.seek() complete.');

        // 4. CRITICAL: Pause immediately after seek when priming
        // This prevents auto-play and ensures the state reflects a seek-to-paused state.
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: Calling adapter.pause()...',
        // );
        await _audioPlayerAdapter.pause();
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: adapter.pause() complete. _seekPerformedWhileNotPlaying=true.',
        // );
      }
    } catch (e, s) {
      logger.e('[SERVICE SEEK DECISION] ERROR', error: e, stackTrace: s);
      _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
      rethrow;
    }
    logger.d('[SERVICE SEEK DECISION] END');
  }

  @override
  Future<void> stop() async {
    final trace = StackTrace.current;
    logger.d('[SERVICE STOP] START', stackTrace: trace);
    try {
      logger.d('[SERVICE STOP] Action: Calling adapter.stop()');
      await _audioPlayerAdapter.stop();
      // logger.d('[SERVICE STOP] Adapter stop() call complete.'); // Keep DEBUG
    } catch (e, s) {
      logger.e('[SERVICE STOP] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    // Clear context on explicit stop?
    _currentFilePath = null;
    logger.d('[SERVICE STOP] END (Context Cleared)');
  }

  @override
  Future<void> dispose() async {
    logger.d('[SERVICE DISPOSE] START');
    try {
      logger.d('[SERVICE DISPOSE] Action: Calling adapter.dispose()');
      await _audioPlayerAdapter.dispose();
      // logger.d('[SERVICE DISPOSE] Action: Calling mapper.dispose()'); // Keep DEBUG
      _playbackStateMapper.dispose(); // Ensure mapper is disposed
      // logger.d('[SERVICE DISPOSE] Action: Cancelling mapper subscription'); // Keep DEBUG
      await _mapperSubscription.cancel();
      // logger.d('[SERVICE DISPOSE] Action: Closing playback state subject'); // Keep DEBUG
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

  // Helper method to truncate long file paths in logs
  String _truncatePath(String path) {
    const maxLength = 20;
    if (path.length <= maxLength) return path;
    return '...${path.substring(path.length - maxLength)}';
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
