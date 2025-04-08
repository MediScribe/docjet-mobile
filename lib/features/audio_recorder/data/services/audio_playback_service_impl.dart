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

  @visibleForTesting // Setter ONLY for test setup convenience
  set currentState(PlaybackState newState) {
    _currentState = newState;
    // Optionally emit here if tests need to react to setup changes via stream?
    // _playbackStateController.add(_currentState); // Probably not needed for setup.
  }

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
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen(
      (state) {
        logger.t('[AudioSvc] Event: onPlayerStateChanged - $state');
        // Determine state updates based on the player state
        bool isNowPlaying = state == PlayerState.playing;
        bool isNowLoading = _currentState.isLoading;
        bool isNowCompleted = _currentState.isCompleted;

        // Set loading to false when playback actually starts or stops/pauses/completes
        if (state == PlayerState.playing ||
            state == PlayerState.paused ||
            state == PlayerState.stopped ||
            state == PlayerState.completed) {
          isNowLoading = false;
          isNowCompleted = false;
        }

        _updateState(
          isPlaying: isNowPlaying,
          isLoading: isNowLoading,
          isCompleted: isNowCompleted,
        );

        // Specific handling for stopped state (reset position)
        if (state == PlayerState.stopped) {
          logger.t(
            '[AudioSvc] Player stopped, resetting state completely (except duration).',
          );
          // Reset state fully on stop, keeping only totalDuration
          _updateState(
            position: Duration.zero,
            isPlaying: false,
            isLoading: false,
            isCompleted: false, // Explicitly ensure completed is false
            // Rely on clearError: true to handle resetting error state
            // hasError: false, // REMOVED - Redundant with clearError: true
            // errorMessage: null, // REMOVED - Redundant with clearError: true
            // totalDuration is kept implicitly by not passing it
            clearCurrentFilePath: true, // MUST clear the path
            clearError: true, // Ensure error flag/message are cleared too
          );
        }
      },
      onError: (error) {
        logger.e('[AudioSvc] Error on PlayerState stream: $error');
        _handleError(
          'PlayerState Stream Error: $error',
          filePath: _currentState.currentFilePath,
        );
      },
    );

    logger.t('[AudioSvc] Subscribing to onDurationChanged...');
    _durationSubscription = _audioPlayer.onDurationChanged.listen(
      (duration) {
        logger.t('[AudioSvc] Event: onDurationChanged - $duration');
        _updateState(totalDuration: duration);
      },
      onError: (error) {
        logger.e('[AudioSvc] Error on Duration stream: $error');
        _handleError(
          'Duration Stream Error: $error',
          filePath: _currentState.currentFilePath,
        );
      },
    );

    logger.t('[AudioSvc] Subscribing to onPositionChanged...');
    _positionSubscription = _audioPlayer.onPositionChanged.listen(
      (position) {
        // Only update position if the duration is known (avoid weird states at start)
        if (_currentState.totalDuration > Duration.zero) {
          logger.t('[AudioSvc] Event: onPositionChanged - $position');
          _updateState(position: position);
        }
      },
      onError: (error) {
        logger.e('[AudioSvc] Error on Position stream: $error');
        _handleError(
          'Position Stream Error: $error',
          filePath: _currentState.currentFilePath,
        );
      },
    );

    logger.t('[AudioSvc] Subscribing to onPlayerComplete...');
    _completionSubscription = _audioPlayer.onPlayerComplete.listen(
      (_) {
        // Go back to start, keep duration, mark as not playing but completed
        logger.t('[AudioSvc] Event: onPlayerComplete');
        _updateState(
          position: Duration.zero,
          isPlaying: false,
          isCompleted: true,
        );
        // Optionally reset fully: _resetState();
      },
      onError: (error) {
        logger.e('[AudioSvc] Error on Complete stream: $error');
        _handleError(
          'Complete Stream Error: $error',
          filePath: _currentState.currentFilePath,
        );
      },
    );

    // Note: onLog is preferred over onError if using newer audioplayers versions
    logger.t('[AudioSvc] Subscribing to onLog...');
    _errorSubscription = _audioPlayer.onLog.listen(
      (msg) {
        // Keep this less verbose unless debugging specific player issues
        // logger.t('[AudioSvc] Event: onLog - $msg');
        if (msg.startsWith('Error') ||
            msg.contains('error') ||
            msg.contains('Exception')) {
          logger.w('[AudioSvc] Player Error Log: $msg');
          _handleError(msg, filePath: _currentState.currentFilePath);
        }
      },
      onError: (e) {
        // This captures errors within the onLog stream handler itself
        logger.e('[AudioSvc] Error in onLog listener: $e');
        _handleError(
          'Listener error: $e',
          filePath: _currentState.currentFilePath,
        );
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
    final PlaybackState previousState =
        _currentState; // Store the state *before* changes

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
      // Pass the flags through to copyWith!
      clearError: clearError,
      clearCurrentFilePath: clearCurrentFilePath,
    );

    // Update the internal state *after* creating the newState and storing the previous state
    _currentState = newState;

    // Emit the *new* state ONLY if it has actually changed from the previous state
    logger.t(
      '[AudioSvc] _updateState: Comparing newState: $newState with previous state: $previousState',
    );
    if (newState != previousState) {
      logger.d('[AudioSvc] State changed: Emitting $newState');
      _playbackStateController?.add(newState); // FIX: Emit the NEW state
    } else {
      logger.t('[AudioSvc] State unchanged. Not emitting.');
    }
  }

  // Centralized error handler
  void _handleError(Object error, {String? filePath}) {
    final pathForError = filePath ?? _currentState.currentFilePath;
    logger.e(
      '[AudioSvc] Handling error for ${pathForError ?? 'unknown path'}: $error',
    );
    _updateState(
      // Preserve or update filePath based on what was passed
      currentFilePath: pathForError,
      isPlaying: false,
      isLoading: false,
      hasError: true,
      // Construct a more informative message if possible
      errorMessage:
          error is String
              ? error // Use string directly if it came from onLog
              : 'Error processing ${pathForError ?? 'audio'}: ${error.toString()}',
      clearCurrentFilePath:
          false, // Ensure path isn't cleared by _updateState logic
      clearError: false, // We are setting an error
    );
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

    // NEW: Wrap in try/catch
    try {
      // NEW: Stop any existing playback first for robustness
      logger.t('[AudioSvc] play(): Stopping potential existing playback...');
      await _audioPlayer.stop();
      logger.t('[AudioSvc] play(): Stop call completed.');

      // Reset relevant state before starting new playback
      logger.t('[AudioSvc] play(): Updating state to loading for: $filePath');
      _updateState(
        currentFilePath: filePath,
        isLoading: true,
        isPlaying: false, // Ensure isPlaying is false initially
        isCompleted: false, // Reset completion
        hasError: false, // Clear previous errors
        errorMessage: null,
        position: Duration.zero, // Reset position
        // Keep existing duration if one was loaded? Or reset?
        // Let's reset duration for now, assuming new file means unknown duration
        totalDuration: Duration.zero,
        clearError: true, // Explicitly clear error fields
        clearCurrentFilePath: false, // We are setting a new one
      );

      // Determine source type
      final Source source;
      if (filePath.startsWith('/') || filePath.startsWith('file://')) {
        // Assume device file if it looks like an absolute path
        logger.t('[AudioSvc] play(): Using DeviceFileSource for: $filePath');
        source = DeviceFileSource(filePath);
      } else {
        // Assume asset file otherwise
        logger.t('[AudioSvc] play(): Using AssetSource for: $filePath');
        source = AssetSource(filePath);
      }

      logger.t('[AudioSvc] play(): Setting source...');
      await _audioPlayer.setSource(source);

      logger.t('[AudioSvc] play(): Calling resume...');
      await _audioPlayer.resume();

      // OLD OPTIMISTIC UPDATE - REMOVED per plan
      // logger.t(
      //   '[AudioSvc] play(): Resume finished, setting isLoading=false, isPlaying=true (optimistic)',
      // );
      // _updateState(isLoading: false, isPlaying: true);

      logger.d('[AudioSvc] play() completed for: $filePath');
    } catch (e) {
      logger.e(
        '[AudioSvc] play(): Error during playback initiation for $filePath',
        error: e,
        stackTrace: StackTrace.current,
      );
      _handleError(e, filePath: filePath);
      // Rethrow? Or let the state stream handle error reporting?
      // Let _handleError manage state and player stop.
    }
  }

  @override
  Future<void> pause() async {
    // Check if playing before attempting to pause
    if (_currentState.isPlaying) {
      logger.d('[AudioSvc] pause() called. Attempting pause.');
      try {
        await _audioPlayer.pause();
        logger.i('[AudioSvc] AudioPlayer paused successfully.');
        // State update will occur via onPlayerStateChanged listener
      } catch (e) {
        logger.e('[AudioSvc] Error pausing audio: $e');
        _handleError(
          'Error pausing audio: $e',
          filePath: _currentState.currentFilePath,
        );
        // Optionally re-throw or handle more gracefully depending on requirements
        // throw Exception('Failed to pause audio playback: $e');
      }
    } else {
      logger.w(
        '[AudioSvc] pause() called but player is not currently playing. State: $_currentState',
      );
      // Do nothing if not playing
    }
  }

  @override
  Future<void> resume() async {
    // Can only resume if paused (i.e., not playing, not completed, and has a file path)
    final bool canResume =
        !_currentState.isPlaying &&
        !_currentState.isCompleted &&
        _currentState.currentFilePath != null;

    if (canResume) {
      logger.d('[AudioSvc] resume() called. Attempting resume.');
      try {
        await _audioPlayer.resume();
        logger.i('[AudioSvc] AudioPlayer resume initiated successfully.');
        // State update (isPlaying=true) will occur via onPlayerStateChanged listener
      } catch (e) {
        logger.e('[AudioSvc] Error resuming audio: $e');
        _handleError(
          'Error resuming audio: $e',
          filePath: _currentState.currentFilePath,
        );
        // throw Exception('Failed to resume audio playback: $e');
      }
    } else {
      logger.w(
        '[AudioSvc] resume() called but cannot resume in current state: $_currentState',
      );
      // Do nothing if playing, stopped, completed, or no file loaded
    }
  }

  @override
  Future<void> seek(Duration position) async {
    logger.d('[AudioSvc] seek() called for position: $position');
    if (_currentState.currentFilePath == null ||
        _currentState.totalDuration == Duration.zero) {
      logger.w(
        '[AudioSvc] seek(): Cannot seek, no file loaded or duration unknown. State: $_currentState',
      );
      return; // Cannot seek if nothing is playing or duration unknown
    }
    try {
      // Clamp the seek position to be within the valid range [0, totalDuration]
      final clampedPosition =
          position.isNegative
              ? Duration.zero
              : (position > _currentState.totalDuration
                  ? _currentState.totalDuration
                  : position);

      logger.d(
        '[AudioSvc] seek(): Clamped position: $clampedPosition. Seeking...',
      );
      await _audioPlayer.seek(clampedPosition);
      logger.d(
        '[AudioSvc] seek(): Player seek call returned. State update relies on event stream.',
      );
      // REMOVED: Optimistic state update - rely on onPositionChanged stream

      logger.d('[AudioSvc] seek() completed for position: $clampedPosition');
    } catch (e) {
      logger.e(
        '[AudioSvc] seek(): Error seeking to $position',
        error: e,
        stackTrace: StackTrace.current,
      );
      _handleError(
        'Error during seek to $position',
        filePath: _currentState.currentFilePath,
      );
    }
  }

  @override
  Future<void> stop() async {
    logger.d('[AudioSvc] stop() called.');

    // If nothing is loaded or we are already stopped/paused/initial, do nothing.
    if (_currentState.currentFilePath == null ||
        _currentState.currentFilePath!.isEmpty ||
        (!_currentState.isPlaying && !_currentState.isLoading)) {
      logger.d(
        '[AudioSvc] stop(): Player already stopped or nothing loaded. Skipping call.',
      );
      return; // Don't proceed
    }

    try {
      logger.t('[AudioSvc] stop(): Calling player stop...');
      await _audioPlayer.stop();
      // Listener should handle state update (PlayerState.stopped -> resets position etc.)
      // But we also explicitly reset the core state here for consistency.
      logger.t(
        '[AudioSvc] stop(): Player stop call returned. Resetting state...',
      );

      // REMOVED: Explicit state reset. Rely on the onPlayerStateChanged listener
      // _updateState(
      //   isPlaying: false,
      //   isLoading: false,
      //   isCompleted: false, // Explicitly reset completed flag
      //   position: Duration.zero,
      //   hasError: false, // Clear any previous error
      //   errorMessage: null,
      //   // totalDuration remains unchanged
      //   clearCurrentFilePath:
      //       true, // MUST set this flag to true to clear the path!
      //   clearError: true, // Also ensure error fields are explicitly cleared
      // );

      logger.d('[AudioSvc] stop() completed.');
    } catch (e) {
      logger.e(
        '[AudioSvc] stop(): Error stopping player',
        error: e,
        stackTrace: StackTrace.current,
      );
      // If stop fails, what state should we be in? Still try to reset.
      _handleError(
        'Error stopping: $e',
        filePath: _currentState.currentFilePath,
      );
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
