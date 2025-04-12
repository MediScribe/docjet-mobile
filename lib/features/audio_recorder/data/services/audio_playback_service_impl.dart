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
  // Flag to differentiate pause-after-seek from natural pause
  bool _seekPerformedWhileNotPlaying = false;

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
        // Demoted from DEBUG to TRACE due to high frequency
        logger.t('[SERVICE_RX] Received PlaybackState from Mapper: $state');
        _lastKnownState = state; // Update last known state
        // Reset flag on natural state changes if appropriate
        if (state.maybeMap(playing: (_) => true, orElse: () => false)) {
          _seekPerformedWhileNotPlaying = false; // Reset on natural play
        }
        // TODO: Consider resetting _seekPerformedWhileNotPlaying on stop/complete/error as well?
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
    // logger.d('[SERVICE_STREAM] playbackStateStream accessed.'); // Removed: Noisy
    return _playbackStateSubject.stream;
  }

  @override
  Future<void> play(String pathOrUrl) async {
    final trace = StackTrace.current;
    logger.d('[SERVICE PLAY $pathOrUrl] START', stackTrace: trace);
    try {
      final isSameFile = pathOrUrl == _currentFilePath;
      // Use maybeWhen for concise state checking
      final isPaused = _lastKnownState.maybeWhen(
        paused: (_, __) => true, // Check if the state is paused
        orElse: () => false, // Default to false for all other states
      );

      logger.d(
        '[SERVICE PLAY $pathOrUrl] State Check: isSameFile: $isSameFile, isPaused: $isPaused, _lastKnownState: $_lastKnownState',
      );

      // --- Restore Resume Logic ---
      if (isSameFile && isPaused) {
        // If paused on the same file, just resume
        logger.d('[SERVICE PLAY $pathOrUrl] Action: Resuming playback.');
        await _audioPlayerAdapter.resume();
        logger.d('[SERVICE PLAY $pathOrUrl] Adapter resume() call complete.');
        // No explicit state emission here; rely on adapter events via mapper
      } else {
        // --- Full Restart Logic ---
        logger.d(
          '[SERVICE PLAY $pathOrUrl] Action: Full restart needed (different file or not paused).',
        );

        logger.d('[SERVICE PLAY $pathOrUrl] Action: Calling adapter.stop()...');
        await _audioPlayerAdapter.stop();
        logger.d('[SERVICE PLAY $pathOrUrl] Adapter stop() call complete.');

        // Update current path ONLY if it's a different file
        // Also update the mapper context if the file changes
        // This logic remains within the 'else' (full restart) block implicitly
        // because it only needs to happen when not resuming.
        if (!isSameFile) {
          logger.d(
            '[SERVICE PLAY $pathOrUrl] Action: Updating file path & mapper context...',
          );
          _currentFilePath = pathOrUrl;
          // Let the mapper know the context for accurate duration mapping etc.
          // This might not be strictly necessary if duration comes from adapter
          // events, but good practice to keep mapper informed.
          // Consider if _playbackStateMapper needs setCurrentFilePath method
          // If it does, call it: _playbackStateMapper.setCurrentFilePath(pathOrUrl);
          logger.d(
            '[SERVICE PLAY $pathOrUrl] File path updated, mapper context set (if applicable).',
          );
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
        await _audioPlayerAdapter
            .resume(); // resume() starts playback after setSourceUrl
        logger.d(
          '[SERVICE PLAY $pathOrUrl] Adapter resume() (for start) call complete.',
        );
      }
    } catch (e, s) {
      logger.e('[SERVICE PLAY $pathOrUrl] FAILED', error: e, stackTrace: s);
      _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
      rethrow;
    }
    logger.d('[SERVICE PLAY $pathOrUrl] END (Success)');
  }

  @override
  Future<void> pause() async {
    final trace = StackTrace.current;
    logger.d('[SERVICE PAUSE] START', stackTrace: trace);
    try {
      await _audioPlayerAdapter.pause();
      // logger.d('[SERVICE PAUSE] Adapter pause() call complete.'); // Keep DEBUG
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
      // logger.d('[SERVICE RESUME] Adapter resume() call complete.'); // Keep DEBUG
    } catch (e, s) {
      logger.e('[SERVICE RESUME] FAILED', error: e, stackTrace: s);
      rethrow;
    }
    logger.d('[SERVICE RESUME] END');
  }

  @override
  Future<void> seek(String filePath, Duration position) async {
    final trace = StackTrace.current;
    // logger.d(
    //   '[SERVICE SEEK $filePath ${position.inMilliseconds}ms] START', // Update log
    //   stackTrace: trace,
    // );
    try {
      final isCurrentlyPlaying = _lastKnownState.maybeWhen(
        playing: (_, __) => true,
        orElse: () => false,
      );

      final isTargetSameAsCurrent = filePath == _currentFilePath;

      // logger.d(
      //   '[SERVICE SEEK $filePath] State Check: isCurrentlyPlaying: $isCurrentlyPlaying, isTargetSameAsCurrent: $isTargetSameAsCurrent, _lastKnownState: $_lastKnownState',
      // );

      // Scenario 1: Seeking within the currently playing/paused file
      if (isTargetSameAsCurrent && _currentFilePath != null) {
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
        // --- Prime the Pump --- Needs explicit pause after seek
        // logger.d(
        //   '[SERVICE SEEK $filePath] Action: Priming the pump (new file or stopped state)...',
        // );

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
        _seekPerformedWhileNotPlaying = true; // Set flag
        // logger.d(
        //   '[SERVICE SEEK $filePath] Priming: adapter.pause() complete. _seekPerformedWhileNotPlaying=true.',
        // );
      }
    } catch (e) {
      // logger.e(
      //   '[SERVICE SEEK $filePath ${position.inMilliseconds}ms] FAILED',
      //   error: e,
      //   stackTrace: s,
      // );
      _playbackStateSubject.add(PlaybackState.error(message: e.toString()));
      rethrow;
    }
    // logger.d(
    //   '[SERVICE SEEK $filePath ${position.inMilliseconds}ms] END (Success)',
    // );
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
