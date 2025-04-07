import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/models/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:logger/logger.dart'; // Keep this logger import

/// Concrete implementation of [AudioPlaybackService] using the `audioplayers` package.
class AudioPlaybackServiceImpl implements AudioPlaybackService {
  // Make logger late final as well
  late final Logger logger;

  // Make _audioPlayer late final, but allow injection via constructor for tests
  late final AudioPlayer _audioPlayer;

  final bool _playerInjected; // Flag to track if player was injected

  // Restore StreamController - lazy init in getter
  StreamController<PlaybackState>? _playbackStateController;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _completionSubscription;
  StreamSubscription? _errorSubscription;

  PlaybackState _currentState = const PlaybackState.initial();

  // Add a getter for testing purposes
  @visibleForTesting
  PlaybackState get currentState => _currentState;

  /// Creates an instance of [AudioPlaybackServiceImpl].
  ///
  /// The AudioPlayer instance is created lazily during listener initialization,
  /// unless an instance is explicitly provided (e.g., for testing).
  AudioPlaybackServiceImpl({AudioPlayer? audioPlayer})
    : _playerInjected = audioPlayer != null {
    // Initialize logger in the constructor
    logger = Logger();
    logger.d('[AudioSvc] Constructor: Logger instance created.');

    // Set the flag
    if (_playerInjected) {
      _audioPlayer = audioPlayer!; // Assign if injected (non-null asserted)
    }
    // Removed logger usage as it's not initialized yet.
  }

  /// Initializes the audio player listeners SYNCHRONOUSLY.
  /// This should be called after construction and ideally after an initial pump in tests.
  void initializeListeners() {
    // Logger is now initialized in the constructor

    if (!_playerInjected) {
      try {
        _audioPlayer = AudioPlayer();
        logger.d('[AudioSvc] AudioPlayer instance created lazily.');
      } catch (e) {
        logger.e('[AudioSvc] Failed to create AudioPlayer lazily: $e');
        throw Exception('Failed to initialize AudioPlayer: $e');
      }
    } else {
      logger.d(
        '[AudioSvc] AudioPlayer instance was injected, skipping lazy creation.',
      );
    }

    // REMOVE StreamController creation from initializeListeners
    // _playbackStateController =
    //     StreamController<PlaybackState>.broadcast(); // Use broadcast as intended
    logger.d(
      '[AudioSvc] Initializing listeners... (Controller creation DEFERRED to getter)',
    );

    // Comment out listener registration for diagnostic purposes
    _registerListeners();
    // logger.w('[AudioSvc] DIAGNOSTIC: Listener registration is still SKIPPED.'); // Commented out the warning

    // Restore adding initial state - BUT COMMENTED OUT FOR THIS TEST
    logger.d(
      '[AudioSvc] Adding initial state after listener init: $_currentState (Add call DEFERRED to getter)',
    );
    // _playbackStateController?.add(_currentState); // Deferred to getter

    logger.d(
      '[AudioSvc] Listener initialization complete (controller deferred, add deferred).', // Updated log message
    );
  }

  void _registerListeners() {
    logger.d('[AudioSvc] Registering player listeners...');
    logger.t('[AudioSvc] Subscribing to onPlayerStateChanged...');
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      logger.t('[AudioSvc] Event: onPlayerStateChanged - $state');
      _updateState(isPlaying: state == PlayerState.playing);
      if (state == PlayerState.stopped) {
        // Reset position on stop, but keep duration and file path
        _updateState(position: Duration.zero, isPlaying: false);
      }
    }, onError: _handleError);

    logger.t('[AudioSvc] Subscribing to onDurationChanged...');
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      logger.t('[AudioSvc] Event: onDurationChanged - $duration');
      _updateState(totalDuration: duration);
    }, onError: _handleError);

    logger.t('[AudioSvc] Subscribing to onPositionChanged...');
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      // Only update position if the duration is known (avoid weird states at start)
      if (_currentState.totalDuration > Duration.zero) {
        logger.t('[AudioSvc] Event: onPositionChanged - $position');
        _updateState(position: position);
      }
    }, onError: _handleError);

    logger.t('[AudioSvc] Subscribing to onPlayerComplete...');
    _completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      // Go back to start, keep duration, mark as not playing but completed
      logger.t('[AudioSvc] Event: onPlayerComplete');
      _updateState(
        position: Duration.zero,
        isPlaying: false,
        isCompleted: true,
      );
      // Optionally reset fully: _resetState();
    }, onError: _handleError);

    // Note: onLog is preferred over onError if using newer audioplayers versions
    logger.t('[AudioSvc] Subscribing to onLog...');
    _audioPlayer.onLog.listen(
      (msg) {
        // Keep this less verbose unless debugging specific player issues
        // logger.t('[AudioSvc] Event: onLog - $msg');
        if (msg.startsWith('Error') ||
            msg.contains('error') ||
            msg.contains('Exception')) {
          logger.w('[AudioSvc] Player Error Log: $msg');
          _handleError(msg);
        }
      },
      onError: (e) {
        // This captures errors within the onLog stream handler itself
        logger.e('[AudioSvc] Error in onLog listener: $e');
        _handleError('Listener error: $e');
      },
    );

    logger.d('[AudioSvc] Listeners registered.');
  }

  void _updateState({
    String? currentFilePath,
    bool? isPlaying,
    bool? isLoading,
    bool? isCompleted, // Explicitly manage completion state
    bool? hasError,
    String? errorMessage,
    Duration? position,
    Duration? totalDuration,
    bool clearError = false, // Flag to clear error state
    bool clearCurrentFilePath = false, // Flag to clear file path
  }) {
    logger.t(
      '[AudioSvc] Requesting state update: isPlaying=$isPlaying, isLoading=$isLoading, isCompleted=$isCompleted, hasError=$hasError, pos=$position, dur=$totalDuration, path=$currentFilePath',
    );
    final newState = _currentState.copyWith(
      // Use flags to allow setting null explicitly
      currentFilePath:
          clearCurrentFilePath
              ? null
              : (currentFilePath ?? _currentState.currentFilePath),
      isPlaying: isPlaying ?? _currentState.isPlaying,
      isLoading: isLoading ?? _currentState.isLoading,
      // Reset completion unless explicitly set true
      isCompleted: isCompleted ?? false,
      // Use flag to clear error, otherwise update as usual
      hasError: clearError ? false : (hasError ?? _currentState.hasError),
      errorMessage:
          clearError ? null : (errorMessage ?? _currentState.errorMessage),
      position: position ?? _currentState.position,
      totalDuration: totalDuration ?? _currentState.totalDuration,
    );

    // ONLY emit if state actually changed
    if (newState != _currentState) {
      logger.d('[AudioSvc] State changed: $newState');
      _currentState = newState;
      _playbackStateController?.add(_currentState); // RESTORED
    } else {
      logger.t(
        '[AudioSvc] State update requested, but no change detected from: $_currentState',
      );
    }
  }

  void _handleError(Object error) {
    logger.e('[AudioSvc] Handling error: $error');
    _updateState(
      isPlaying: false,
      isLoading: false,
      hasError: true,
      errorMessage: error.toString(),
      position: Duration.zero, // Reset position on error
    );
    // Stop playback on error
    _audioPlayer.stop().catchError((e) {
      logger.e('[AudioSvc] Error stopping player after handling error: $e');
      // Potentially update state again if stop fails, though unlikely
    });
  }

  void _resetState() {
    logger.d('[AudioSvc] Resetting state to initial.');
    _currentState = const PlaybackState.initial();
    _playbackStateController?.add(_currentState); // RESTORED
  }

  @override
  Stream<PlaybackState> get playbackStateStream {
    // Lazy initialization of the StreamController
    if (_playbackStateController == null) {
      logger.d(
        '[AudioSvc] playbackStateStream getter: Controller is null, creating broadcast controller...',
      );
      _playbackStateController = StreamController<PlaybackState>.broadcast();
      // Add the initial state immediately after creation
      logger.d(
        '[AudioSvc] playbackStateStream getter: Adding initial state: $_currentState',
      );
      // Use try-add in case controller is closed unexpectedly, though unlikely here
      try {
        _playbackStateController!.add(_currentState);
      } catch (e) {
        logger.e(
          '[AudioSvc] playbackStateStream getter: Error adding initial state: $e',
        );
      }
    }
    return _playbackStateController!.stream; // Assert non-null now
  }

  @override
  Future<void> play(String filePath) async {
    logger.d('[AudioSvc] play() called for: $filePath');
    try {
      // Stop and reset previous state before playing new file
      if (_currentState.isPlaying ||
          _currentState.isLoading ||
          _currentState.currentFilePath != null) {
        logger.t(
          '[AudioSvc] play(): Current state requires stop first. State: $_currentState',
        );
        await stop(); // Ensure full stop and state reset happens
      }

      // Update state immediately to loading and set the new file path
      // Clear any previous error state when starting new playback
      logger.t('[AudioSvc] play(): Updating state to loading for: $filePath');
      _updateState(
        currentFilePath: filePath,
        isLoading: true,
        isPlaying: false,
        isCompleted: false,
        position: Duration.zero,
        totalDuration: Duration.zero,
        clearError: true,
      );

      Source source;
      // Heuristic: Check if it looks like a typical asset path structure.
      // This isn't foolproof but covers common cases. Assume assets are defined in pubspec.yaml.
      // A more robust solution might involve checking `rootBundle.load`.
      final isAsset =
          !filePath.startsWith('/') &&
          !filePath.contains(':') &&
          !kIsWeb; // Basic check for local file path or web URL
      // TODO: Improve asset detection if needed

      if (isAsset) {
        // Note: audioplayers AssetSource expects path relative to pubspec assets definition
        // E.g., if pubspec has 'assets/audio/', path should be 'audio/myfile.mp3'
        // The plan says "remove assets/ prefix", implying paths might include it.
        // Let's assume the passed filePath is CORRECT for AssetSource.
        // If filePath is like "assets/audio/sound.mp3", AssetSource("audio/sound.mp3") might be needed.
        // For now, trust the input path. Adjust if testing reveals issues.
        source = AssetSource(filePath);
        logger.t('[AudioSvc] play(): Using AssetSource for: $filePath');
      } else {
        source = DeviceFileSource(filePath);
        logger.t('[AudioSvc] play(): Using DeviceFileSource for: $filePath');
      }

      // Set the source *before* calling play
      logger.t('[AudioSvc] play(): Setting source...');
      await _audioPlayer.setSource(source);
      // Calling play() after setSource() is often required.
      // Some versions might auto-play on setSource, others need explicit play.
      logger.t('[AudioSvc] play(): Calling resume...');
      await _audioPlayer
          .resume(); // Use resume as it handles both start and resume-after-pause

      // Once playing starts, the 'onPlayerStateChanged' listener will update isPlaying=true
      // and 'onDurationChanged' will update totalDuration. isLoading should become false.
      // We *could* optimistically set isPlaying=true here, but relying on the event is safer.
      // Let's mark loading as false once resume returns without error.
      logger.t(
        '[AudioSvc] play(): Resume finished, setting isLoading=false, isPlaying=true (optimistic)',
      );
      _updateState(
        isLoading: false,
        isPlaying: true,
      ); // Optimistically update state
      logger.d('[AudioSvc] play() completed for: $filePath');
    } catch (e) {
      logger.e('[AudioSvc] play(): Error playing $filePath', error: e);
      _handleError('Error playing $filePath: $e');
      // Explicitly ensure loading is false on error during play initiation
      _updateState(isLoading: false);
    }
  }

  @override
  Future<void> pause() async {
    logger.d('[AudioSvc] pause() called.');
    try {
      if (_currentState.isPlaying) {
        logger.t('[AudioSvc] pause(): Player is playing, calling pause...');
        await _audioPlayer.pause();
        logger.t('[AudioSvc] pause(): Player pause call returned.');
      } else {
        logger.t('[AudioSvc] pause(): Player not playing, doing nothing.');
      }
      logger.d('[AudioSvc] pause() completed.');
    } catch (e) {
      logger.e('[AudioSvc] pause(): Error pausing', error: e);
      _handleError('Error pausing: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    logger.d('[AudioSvc] seek() called for position: $position');
    // Only seek if a file is loaded and duration is known
    if (_currentState.currentFilePath != null &&
        _currentState.totalDuration > Duration.zero) {
      try {
        // Ensure seek position is within bounds
        final seekPosition =
            position > _currentState.totalDuration
                ? _currentState.totalDuration
                : position;
        logger.t(
          '[AudioSvc] seek(): Clamped position: $seekPosition. Seeking...',
        );
        await _audioPlayer.seek(seekPosition);
        // Update state immediately for responsiveness, listener will also fire
        logger.t(
          '[AudioSvc] seek(): Player seek call returned. Updating state...',
        );
        _updateState(
          position: seekPosition,
          isCompleted: false,
        ); // Seeking resets completed flag
        logger.d('[AudioSvc] seek() completed for position: $seekPosition');
      } catch (e) {
        logger.e('[AudioSvc] seek(): Error seeking', error: e);
        _handleError('Error seeking: $e');
      }
    } else {
      logger.w(
        '[AudioSvc] seek(): Cannot seek. No file loaded or duration unknown. State: $_currentState',
      );
    }
  }

  @override
  Future<void> stop() async {
    logger.d('[AudioSvc] stop() called.');
    try {
      logger.t('[AudioSvc] stop(): Calling player stop...');
      await _audioPlayer.stop();
      // Listener should handle state update (PlayerState.stopped -> resets position etc.)
      // But we also explicitly reset the core state here for consistency.
      logger.t(
        '[AudioSvc] stop(): Player stop call returned. Resetting state...',
      );
      _resetState();
      logger.d('[AudioSvc] stop() completed.');
    } catch (e) {
      logger.e('[AudioSvc] stop(): Error stopping', error: e);
      _handleError('Error stopping: $e');
      // Ensure state reflects stop attempt even if player throws error
      _resetState();
    }
  }

  @override
  Future<void> dispose() async {
    logger.d('[AudioSvc] dispose() called.');
    logger.t('[AudioSvc] dispose(): Cancelling stream subscriptions...');
    await _durationSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _completionSubscription?.cancel();
    await _errorSubscription?.cancel(); // If using onError stream
    logger.t('[AudioSvc] dispose(): Subscriptions cancelled.');

    // Stop and release player resources
    try {
      logger.d('[AudioSvc] dispose(): Stopping player...');
      await _audioPlayer.stop();
      logger.d('[AudioSvc] dispose(): Player stopped.');
    } catch (e) {
      logger.e('[AudioSvc] dispose(): Error stopping player: $e');
      // Decide if we should continue dispose or rethrow
    }

    try {
      logger.d('[AudioSvc] dispose(): Releasing player resources...');
      await _audioPlayer.release();
      // dispose is called by release on newer versions, but call explicitly for safety
      await _audioPlayer.dispose();
      logger.d('[AudioSvc] dispose(): Player resources released.');
    } catch (e) {
      logger.e('[AudioSvc] dispose(): Error releasing/disposing player: $e');
      // Decide if we should continue dispose or rethrow
    }

    // Close the stream controller
    logger.t('[AudioSvc] dispose(): Closing stream controller...');
    await _playbackStateController?.close(); // RESTORED
    logger.d('[AudioSvc] dispose() completed.');
  }
}
