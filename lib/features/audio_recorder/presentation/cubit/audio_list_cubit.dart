import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

part 'audio_list_state.dart';

// RE-ENABLE DEBUG FOR CUBIT
final logger = Logger(level: Level.debug);

class AudioListCubit extends Cubit<AudioListState> {
  final AudioRecorderRepository repository;
  final AudioPlaybackService _audioPlaybackService;
  StreamSubscription? _playbackSubscription;
  String? _currentPlayingFilePath;

  AudioListCubit({
    required this.repository,
    required AudioPlaybackService audioPlaybackService,
  }) : _audioPlaybackService = audioPlaybackService,
       super(AudioListInitial()) {
    _listenToPlaybackService();
  }

  String mapFailureToMessage(Failure failure) {
    return failure.toString();
  }

  void _listenToPlaybackService() {
    logger.d('[CUBIT] Subscribing to AudioPlaybackService stream...');
    _playbackSubscription = _audioPlaybackService.playbackStateStream.listen(
      (state) => _onPlaybackStateChanged(state),
      onError: (error) {
        logger.e('[CUBIT] Error in playback service stream: $error');
        if (state is AudioListLoaded) {
          final currentState = state as AudioListLoaded;
          emit(
            currentState.copyWith(
              playbackInfo: currentState.playbackInfo.copyWith(
                error: 'Playback service stream error: $error',
                isPlaying: false,
                isLoading: false,
              ),
            ),
          );
        }
      },
    );
    logger.d('[CUBIT] Subscribed to AudioPlaybackService stream.');
  }

  void _onPlaybackStateChanged(PlaybackState playbackState) {
    // Use more verbose logging temporarily
    final logPrefix = '[CUBIT_onPlaybackStateChanged]';
    logger.d(
      '$logPrefix Received PlaybackState update: ${playbackState.runtimeType}',
    );

    if (state is! AudioListLoaded) {
      logger.w(
        '$logPrefix Current state is not AudioListLoaded, ignoring update.',
      );
      return;
    }
    final currentState = state as AudioListLoaded;
    final currentPlaybackInfo = currentState.playbackInfo;
    logger.d('$logPrefix Current PlaybackInfo: $currentPlaybackInfo');
    logger.d(
      '$logPrefix Internal _currentPlayingFilePath: ${_currentPlayingFilePath?.split('/').last ?? 'null'}',
    );

    // Map the freezed PlaybackState to PlaybackInfo properties
    String? filePath = _currentPlayingFilePath; // Start with internal path
    bool isPlaying = false;
    bool isLoading = false;
    Duration position = Duration.zero;
    Duration totalDuration = Duration.zero;
    String? errorMessage;

    // Handle the different state variants from freezed
    playbackState.when(
      initial: () {
        logger.d('$logPrefix Handling initial state');
        // ResetfilePath = null; // Usually cleared on stop/complete
      },
      loading: () {
        logger.d('$logPrefix Handling loading state');
        isLoading = true;
      },
      playing: (currentPosition, duration) {
        logger.d(
          '$logPrefix Handling playing state: pos=${currentPosition.inMilliseconds}ms, dur=${duration.inMilliseconds}ms',
        );
        isPlaying = true;
        position = currentPosition;
        totalDuration = duration;
        if (filePath == null)
          logger.w('$logPrefix Playing state received but filePath is null!');
      },
      paused: (currentPosition, duration) {
        logger.d(
          '$logPrefix Handling paused state: pos=${currentPosition.inMilliseconds}ms, dur=${duration.inMilliseconds}ms',
        );
        isPlaying = false; // Set isPlaying to false
        position = currentPosition;
        totalDuration = duration;
        if (filePath == null)
          logger.w('$logPrefix Paused state received but filePath is null!');
      },
      stopped: () {
        logger.d('$logPrefix Handling stopped state');
        // Usually clear path on explicit stop
        // filePath = null;
        // _currentPlayingFilePath = null;
      },
      completed: () {
        logger.d('$logPrefix Handling completed state');
        filePath = null; // Clear path on completion
        _currentPlayingFilePath = null;
      },
      error: (message, currentPosition, duration) {
        logger.d('$logPrefix Handling error state: $message');
        errorMessage = message;
        if (currentPosition != null) position = currentPosition;
        if (duration != null) totalDuration = duration;
      },
    );

    final newPlaybackInfo = PlaybackInfo(
      activeFilePath: filePath,
      isPlaying: isPlaying,
      isLoading: isLoading,
      currentPosition: position,
      totalDuration: totalDuration,
      error: errorMessage,
    );

    logger.d('$logPrefix Calculated New PlaybackInfo: $newPlaybackInfo');
    final areDifferent = currentPlaybackInfo != newPlaybackInfo;
    logger.d('$logPrefix Comparison (current != new): $areDifferent');

    if (areDifferent) {
      logger.i('$logPrefix Emitting updated AudioListLoaded state...');
      emit(currentState.copyWith(playbackInfo: newPlaybackInfo));
    } else {
      logger.d('$logPrefix State is the same, not emitting.');
    }
  }

  /// Loads the list of existing recordings.
  Future<void> loadAudioRecordings() async {
    emit(AudioListLoading());
    logger.d('[CUBIT] Loading audio recordings...');
    final failureOrRecordings = await repository.loadTranscriptions();

    failureOrRecordings.fold(
      (failure) {
        logger.e('[CUBIT] Error loading recordings: $failure');
        emit(AudioListError(message: mapFailureToMessage(failure)));
      },
      (transcriptions) {
        logger.i(
          '[CUBIT] Loaded ${transcriptions.length} recordings successfully.',
        );
        final mutableRecordings = List<Transcription>.from(transcriptions);
        mutableRecordings.sort((a, b) {
          final dateA = a.localCreatedAt;
          final dateB = b.localCreatedAt;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        emit(AudioListLoaded(transcriptions: mutableRecordings));
      },
    );
  }

  /// Deletes a specific recording.
  Future<void> deleteRecording(String filePath) async {
    logger.i("[LIST_CUBIT] deleteRecording() called for path: $filePath");
    logger.d("[LIST_CUBIT] Calling repository.deleteRecording('$filePath')...");
    final result = await repository.deleteRecording(filePath);
    logger.d("[LIST_CUBIT] repository.deleteRecording('$filePath') completed.");

    result.fold(
      (failure) {
        logger.e('[CUBIT] Error deleting recording', error: failure);
        emit(
          AudioListError(
            message:
                'Failed to delete recording: ${mapFailureToMessage(failure)}',
          ),
        );
      },
      (_) async {
        logger.i(
          "[LIST_CUBIT] deleteRecording successful for path: $filePath. Reloading list.",
        );
        await loadAudioRecordings();
        logger.d("[LIST_CUBIT] Finished reloading list after deletion.");
      },
    );
    logger.i(
      "[LIST_CUBIT] deleteRecording method finished for path: $filePath",
    );
  }

  /// Plays the specified recording.
  Future<void> playRecording(String filePath) async {
    logger.i(
      '[CUBIT_playRecording] START - Req Path: ${filePath.split('/').last}',
    );
    _currentPlayingFilePath = filePath;
    logger.d(
      '  -> _currentPlayingFilePath SET to: ${_currentPlayingFilePath?.split('/').last}',
    ); // DEBUG detail
    try {
      // <<< REMOVE CUBIT PLAY LOG 2 >>>
      logger.d(
        '[CUBIT_playRecording] ABOUT TO CALL _audioPlaybackService.play($filePath)',
      );
      // // ignore: avoid_print
      // print(
      //   '[RAW PRINT CUBIT CHECK] About to call service.play() with filePath: $filePath');
      await _audioPlaybackService.play(filePath);
      logger.d('  -> Service call complete.'); // DEBUG detail
    } catch (e) {
      logger.e('[CUBIT_playRecording] Error calling play on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              activeFilePath: filePath,
              isLoading: false,
              isPlaying: false,
              error: 'Failed to start playback: $e',
            ),
          ),
        );
      }
    }
  }

  /// Pauses the current playback.
  Future<void> pauseRecording() async {
    logger.i('[CUBIT_pauseRecording] START'); // Use INFO for action start
    try {
      logger.d('  -> Calling service.pause()'); // DEBUG detail
      await _audioPlaybackService.pause();
      logger.d('  -> Service call complete.'); // DEBUG detail
    } catch (e) {
      logger.e('[CUBIT_pauseRecording] Error calling pause on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              error: 'Failed to pause playback: $e',
            ),
          ),
        );
      }
    }
  }

  /// Seeks to a specific position in the specified playback file.
  Future<void> seekRecording(String filePath, Duration position) async {
    logger.i(
      '[CUBIT] seekRecording called for path: $filePath, position: $position',
    );
    // NOTE: No need to check state here, service handles context.
    // Let the service handle checking if it can seek.

    // Set the internal path for context IF NEEDED by play/pause later?
    // Consider if this is still necessary or if service solely manages context.
    // For now, let's keep it to ensure play/pause know the target after seek.
    _currentPlayingFilePath = filePath;
    logger.d(
      '  -> _currentPlayingFilePath SET to: ${_currentPlayingFilePath?.split('/').last}',
    );

    try {
      // Just tell the service to seek. The service will emit the updated state.
      await _audioPlaybackService.seek(position);
      logger.d(
        '[CUBIT] Called _audioPlaybackService.seek($position) on path $filePath',
      );

      // --- REMOVED Optimistic Update ---
      // The service now emits the state immediately after seek completes.
    } catch (e) {
      logger.e('[CUBIT] Error calling seek on service: $e');
      // Emit an error state for the UI if seek fails at the service level
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              activeFilePath: filePath, // Provide context for the error
              error: 'Failed to seek playback: $e',
              isLoading: false, // Ensure loading is false on error
            ),
          ),
        );
      } else {
        // If state is not loaded, maybe just log or emit a generic error?
        logger.e(
          '[CUBIT] Seek error occurred but state was not AudioListLoaded.',
        );
      }
    }
  }

  /// Stops the current playback completely.
  Future<void> stopRecording() async {
    logger.i('[CUBIT_stopRecording] START'); // Use INFO for action start
    // final previousFilePath = _currentPlayingFilePath; // Keep commented out if not needed
    _currentPlayingFilePath = null;
    logger.d('  -> _currentPlayingFilePath CLEARED'); // DEBUG detail
    try {
      logger.d('  -> Calling service.stop()'); // DEBUG detail
      await _audioPlaybackService.stop();
      logger.d('  -> Service call complete.'); // DEBUG detail

      // Emit state update ONLY if something was actually playing
      if (state is AudioListLoaded &&
          (state as AudioListLoaded).playbackInfo.activeFilePath != null) {
        logger.d(
          '  -> Emitting state update after explicit stop.',
        ); // DEBUG detail
        emit(
          (state as AudioListLoaded).copyWith(
            playbackInfo: const PlaybackInfo.initial(),
          ),
        );
      }
    } catch (e) {
      logger.e('[CUBIT] Error calling stop on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              error: 'Failed to stop playback: $e',
              isPlaying: false,
              isLoading: false,
            ),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    logger.d('[CUBIT] close() called, cancelling playback subscription...');
    _playbackSubscription?.cancel();
    logger.d('[CUBIT] Playback subscription cancelled.');
    return super.close();
  }
}
