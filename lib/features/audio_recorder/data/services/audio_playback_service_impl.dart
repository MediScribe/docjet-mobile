import 'dart:async';

import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:rxdart/rxdart.dart';

// Set local log level EXPLICITLY to debug to ensure all logs are visible
final logger = Logger(level: Level.debug);

// Make sure to call in main or tests: setLogLevel(Level.debug);

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
      final isPaused = _lastKnownState.maybeWhen(
        paused: (_, __) => true,
        orElse: () => false,
      );

      // Add debug logs for decision-making process
      logger.d('SERVICE PLAY [$pathOrUrl]: DECISION VARIABLES:');
      logger.d(
        'SERVICE PLAY [$pathOrUrl]: - Current file path: "$_currentFilePath"',
      );
      logger.d('SERVICE PLAY [$pathOrUrl]: - New file path: "$pathOrUrl"');
      logger.d('SERVICE PLAY [$pathOrUrl]: - isSameFile=$isSameFile');
      logger.d(
        'SERVICE PLAY [$pathOrUrl]: - Current state type: ${_lastKnownState.runtimeType}',
      );
      logger.d(
        'SERVICE PLAY [$pathOrUrl]: - isPaused=$isPaused - state is ${isPaused ? "paused" : "not paused, it is ${_lastKnownState.runtimeType}"}',
      );
      logger.d(
        'SERVICE PLAY [$pathOrUrl]: - Subscription active: ${_mapperSubscription != null}',
      );
      logger.d(
        'SERVICE PLAY [$pathOrUrl]: DECISION - isSameFile=$isSameFile, isPaused=$isPaused, will resume directly: ${isSameFile && isPaused}',
      );

      if (isSameFile && isPaused) {
        // Same file and paused - just resume from current position
        logger.d(
          'SERVICE PLAY [$pathOrUrl]: Same file and paused, resuming from current position...',
        );
        await _audioPlayerAdapter.resume();
        logger.d('SERVICE PLAY [$pathOrUrl]: Resume complete.');
      } else {
        // Different file or not paused - perform full restart
        logger.d(
          'SERVICE PLAY [$pathOrUrl]: New file or not paused, playing from beginning...',
        );
        logger.d('SERVICE PLAY [$pathOrUrl]: Calling stop...');
        await _audioPlayerAdapter.stop();
        logger.d('SERVICE PLAY [$pathOrUrl]: Stop complete.');

        // Update current path only if it's different
        if (!isSameFile) {
          logger.d('SERVICE PLAY [$pathOrUrl]: Setting mapper path...');
          // Let the mapper know the context
          _playbackStateMapper.setCurrentFilePath(pathOrUrl);
          _currentFilePath = pathOrUrl; // Update current file path
          logger.d('SERVICE PLAY [$pathOrUrl]: Mapper path set.');
        }

        logger.d('SERVICE PLAY [$pathOrUrl]: Calling setSourceUrl...');
        await _audioPlayerAdapter.setSourceUrl(pathOrUrl);
        logger.d('SERVICE PLAY [$pathOrUrl]: setSourceUrl complete.');

        logger.d('SERVICE PLAY [$pathOrUrl]: Calling resume...');
        await _audioPlayerAdapter.resume();
        logger.d('SERVICE PLAY [$pathOrUrl]: Resume complete.');
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
    logger.d('SERVICE PAUSE: Current state before pause: $_lastKnownState');

    // Call the adapter's pause method
    await _audioPlayerAdapter.pause();

    // Pause doesn't directly update _lastKnownState
    // It will be updated asynchronously via the _mapperSubscription when the adapter emits state changes
    logger.d('SERVICE PAUSE: Adapter pause call complete');
    logger.d(
      'SERVICE PAUSE: Current state after pause call (before event propagation): $_lastKnownState',
    );
    logger.d(
      'SERVICE PAUSE: NOTE: State will be updated asynchronously when adapter events propagate to mapper',
    );

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
    logger.d('SERVICE SEEK: START with position ${position.inMilliseconds}ms');

    // Log current state information before seeking
    logger.d('SERVICE SEEK: Current file path: $_currentFilePath');
    logger.d('SERVICE SEEK: Current state before seek: $_lastKnownState');

    // Perform the seek operation
    logger.d(
      'SERVICE SEEK: Calling adapter.seek(${position.inMilliseconds}ms)',
    );
    await _audioPlayerAdapter.seek(position);

    // Additional logging to verify the operation completed
    logger.d('SERVICE SEEK: Adapter seek call complete');
    logger.d('SERVICE SEEK: END');
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

// Helper extension for testing purposes
// Note: This is ONLY for use in tests to enable direct state inspection.
// @visibleForTesting - removed due to issues
extension AudioPlaybackServiceTestExtension on AudioPlaybackServiceImpl {
  // Expose internal state for test verification
  String? get currentFilePathForTest => _currentFilePath;

  PlaybackState get lastKnownStateForTest => _lastKnownState;

  bool get isCurrentlyPausedForTest =>
      _lastKnownState.maybeWhen(paused: (_, __) => true, orElse: () => false);

  // Force internal state for testing - use with caution
  void setInternalStateForTest(String filePath, PlaybackState state) {
    _currentFilePath = filePath;
    _lastKnownState = state;
  }
}
