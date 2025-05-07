import 'dart:async';

import 'package:docjet_mobile/core/audio/audio_player_service.dart';
import 'package:docjet_mobile/core/audio/audio_recorder_service.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:equatable/equatable.dart';

/// A cubit that manages audio recording and playback state.
///
/// This cubit combines the [AudioRecorderService] and [AudioPlayerService]
/// into a single state management solution, providing a unified API for
/// recording and playing audio.
class AudioCubit extends Cubit<AudioState> {
  /// Logger for this class
  static final Logger _logger = LoggerFactory.getLogger(AudioCubit);
  static final String _tag = logTag(AudioCubit);

  /// The recorder service used for recording audio.
  final AudioRecorderService _recorderService;

  /// The player service used for playing audio.
  final AudioPlayerService _playerService;

  /// Combined subscription merging recorder & player metrics.
  StreamSubscription<_Metrics>? _combinedSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  /// Creates a new [AudioCubit] instance.
  ///
  /// [recorderService] - The recorder service.
  /// [playerService] - The player service.
  AudioCubit({
    required AudioRecorderService recorderService,
    required AudioPlayerService playerService,
  }) : _recorderService = recorderService,
       _playerService = playerService,
       super(const AudioState.initial()) {
    _bindStreams();
  }

  /// Binds to recorder & player streams via a single combined stream.
  void _bindStreams() {
    _combinedSubscription =
        Rx.combineLatest3<Duration, Duration, Duration, _Metrics>(
              _recorderService.elapsed$.startWith(Duration.zero),
              _playerService.position$.startWith(Duration.zero),
              _playerService.duration$.startWith(Duration.zero),
              (recElapsed, playerPos, playerDur) =>
                  _Metrics(recElapsed, playerPos, playerDur),
            )
            .distinct()
            .debounceTime(const Duration(milliseconds: 60))
            .listen(_handleMetrics);

    _processingStateSubscription = _playerService.processingState$.listen(
      _handleProcessingState,
    );
  }

  void _handleMetrics(_Metrics m) {
    AudioState next = state;

    if (_isInRecordingPhase()) {
      next = next.copyWith(position: m.recorderElapsed);
    } else if (state.phase == AudioPhase.playing ||
        state.phase == AudioPhase.playingPaused) {
      final shouldUpdateDuration =
          m.playerDuration != Duration.zero &&
          m.playerDuration != state.duration;
      final shouldUpdatePosition =
          m.playerPosition != Duration.zero &&
          m.playerPosition != state.position;

      next = next.copyWith(
        position: shouldUpdatePosition ? m.playerPosition : null,
        duration: shouldUpdateDuration ? m.playerDuration : null,
      );
    } else if (m.playerDuration != state.duration) {
      next = next.copyWith(duration: m.playerDuration);
    }

    if (next != state) {
      emit(next);
    }
  }

  void _handleProcessingState(ProcessingState processingState) {
    if (processingState == ProcessingState.completed &&
        state.phase == AudioPhase.playing) {
      // Explicitly pause then seek to start so player stays idle.
      unawaited(_playerService.pause());
      unawaited(_playerService.seek(Duration.zero));
      emit(
        state.copyWith(
          phase: AudioPhase.playingPaused,
          position: Duration.zero,
        ),
      );
    }
  }

  /// Checks if the current phase is related to recording.
  bool _isInRecordingPhase() {
    return state.phase == AudioPhase.recording ||
        state.phase == AudioPhase.recordingPaused;
  }

  /// Starts recording audio.
  Future<void> startRecording() async {
    try {
      // Start recording
      await _recorderService.start();

      // Update state
      emit(
        state.copyWith(
          phase: AudioPhase.recording,
          position: Duration.zero,
          duration: Duration.zero,
          clearFilePath: true,
        ),
      );
    } catch (e) {
      _logger.e('$_tag Error starting recording: $e');
      // Keep phase as idle if there was an error
    }
  }

  /// Pauses the current recording.
  Future<void> pauseRecording() async {
    if (state.phase != AudioPhase.recording) {
      _logger.w('$_tag Cannot pause recording when not recording');
      return;
    }

    try {
      await _recorderService.pause();
      emit(state.copyWith(phase: AudioPhase.recordingPaused));
    } catch (e) {
      _logger.e('$_tag Error pausing recording: $e');
    }
  }

  /// Resumes recording after it has been paused.
  Future<void> resumeRecording() async {
    if (state.phase != AudioPhase.recordingPaused) {
      _logger.w('$_tag Cannot resume recording when not paused');
      return;
    }

    try {
      await _recorderService.resume();
      emit(state.copyWith(phase: AudioPhase.recording));
    } catch (e) {
      _logger.e('$_tag Error resuming recording: $e');
    }
  }

  /// Stops the current recording and loads it into the player.
  Future<void> stopRecording() async {
    if (!_isInRecordingPhase()) {
      _logger.w('$_tag Cannot stop recording when not recording or paused');
      return;
    }

    try {
      // Stop recording and get the file path
      final absolutePath = await _recorderService.stop();

      // Load the file in the player
      await _playerService.load(absolutePath);

      // Update state
      emit(
        state.copyWith(
          phase: AudioPhase.idle,
          position: Duration.zero,
          filePath: absolutePath,
        ),
      );
    } catch (e) {
      _logger.e('$_tag Error stopping recording: $e');
      // Reset to idle state on error
      emit(state.copyWith(phase: AudioPhase.idle, position: Duration.zero));
    }
  }

  /// Loads an audio file for playback.
  Future<void> loadAudio(String filePath) async {
    try {
      await _playerService.load(filePath);

      emit(
        state.copyWith(
          phase: AudioPhase.idle,
          position: Duration.zero,
          filePath: filePath,
        ),
      );
    } catch (e) {
      _logger.e('$_tag Error loading audio: $e');
    }
  }

  /// Starts or resumes playback of the loaded audio.
  Future<void> play() async {
    if (state.filePath == null) {
      _logger.w('$_tag Cannot play when no file is loaded');
      return;
    }

    // Emit first so UI updates immediately; revert on failure.
    emit(state.copyWith(phase: AudioPhase.playing));
    try {
      await _playerService.play();
    } catch (e) {
      _logger.e('$_tag Error playing audio: $e');
      // Roll back phase so UI is consistent.
      emit(state.copyWith(phase: AudioPhase.playingPaused));
    }
  }

  /// Pauses playback of the loaded audio.
  Future<void> pause() async {
    if (state.phase != AudioPhase.playing) {
      _logger.w('$_tag Cannot pause playback when not playing');
      return;
    }

    // Emit first so UI toggles instantly; revert if call fails.
    emit(state.copyWith(phase: AudioPhase.playingPaused));
    try {
      await _playerService.pause();
    } catch (e) {
      _logger.e('$_tag Error pausing playback: $e');
      // Re-enter playing if pause failed.
      emit(state.copyWith(phase: AudioPhase.playing));
    }
  }

  /// Seeks to a specific position in the audio.
  Future<void> seek(Duration position) async {
    if (state.filePath == null) {
      _logger.w('$_tag Cannot seek when no file is loaded');
      return;
    }

    try {
      await _playerService.seek(position);
      emit(state.copyWith(position: position));
    } catch (e) {
      _logger.e('$_tag Error seeking audio: $e');
    }
  }

  /// Resets the player state and clears position/duration.
  Future<void> reset() async {
    try {
      await _playerService.reset();
      emit(
        state.copyWith(
          phase: AudioPhase.idle,
          position: Duration.zero,
          duration: Duration.zero,
        ),
      );
    } catch (e) {
      _logger.e('$_tag Error resetting audio: $e');
    }
  }

  @override
  Future<void> close() async {
    // Clean up subscriptions
    await _combinedSubscription?.cancel();
    await _processingStateSubscription?.cancel();

    // Dispose services *after* cancelling subscriptions to close their streams cleanly
    await _recorderService.dispose();
    await _playerService.dispose();

    return super.close();
  }
}

/// Helper value object bundling recorder & player metrics.
class _Metrics extends Equatable {
  final Duration recorderElapsed;
  final Duration playerPosition;
  final Duration playerDuration;

  const _Metrics(
    this.recorderElapsed,
    this.playerPosition,
    this.playerDuration,
  );

  @override
  List<Object> get props => [recorderElapsed, playerPosition, playerDuration];
}
