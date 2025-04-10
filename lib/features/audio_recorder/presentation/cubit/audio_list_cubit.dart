import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

part 'audio_list_state.dart';
// Using centralized logger with level OFF
final logger = Logger(level: Level.off);

class AudioListCubit extends Cubit<AudioListState> {
  final AudioRecorderRepository repository;
  final AudioPlaybackService _audioPlaybackService;
  StreamSubscription? _playbackSubscription;

  AudioListCubit({
    required this.repository,
    required AudioPlaybackService audioPlaybackService,
  }) : _audioPlaybackService = audioPlaybackService,
       super(AudioListInitial()) {
    _listenToPlaybackService();
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
    logger.d('[CUBIT] Received PlaybackState update: $playbackState');
    if (state is AudioListLoaded) {
      final currentState = state as AudioListLoaded;
      logger.t(
        '[CUBIT] Current state is AudioListLoaded, updating playbackInfo...',
      );

      // Map the freezed PlaybackState to PlaybackInfo properties
      String? filePath;
      bool isPlaying = false;
      bool isLoading = false;
      Duration position = Duration.zero;
      Duration totalDuration = Duration.zero;
      String? errorMessage;

      // Handle the different state variants from freezed
      playbackState.when(
        initial: () {
          // No changes needed, use defaults
        },
        loading: () {
          isLoading = true;
        },
        playing: (currentPosition, duration) {
          isPlaying = true;
          position = currentPosition;
          totalDuration = duration;
        },
        paused: (currentPosition, duration) {
          position = currentPosition;
          totalDuration = duration;
        },
        stopped: () {
          // No changes needed
        },
        completed: () {
          // Mark as completed
        },
        error: (message, currentPosition, duration) {
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

      logger.t('[CUBIT] New PlaybackInfo created: $newPlaybackInfo');

      if (currentState.playbackInfo != newPlaybackInfo) {
        emit(currentState.copyWith(playbackInfo: newPlaybackInfo));
        logger.d(
          '[CUBIT] Emitted updated AudioListLoaded state with new playbackInfo.',
        );
      } else {
        logger.t('[CUBIT] PlaybackInfo unchanged, state not emitted.');
      }
    } else {
      logger.t(
        '[CUBIT] Current state is not AudioListLoaded (${state.runtimeType}), ignoring playback update.',
      );
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
        emit(AudioListError(message: _mapFailureToMessage(failure)));
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
                'Failed to delete recording: ${_mapFailureToMessage(failure)}',
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
    logger.i('[CUBIT] playRecording called for: $filePath');
    try {
      await _audioPlaybackService.play(filePath);
      logger.d('[CUBIT] Called _audioPlaybackService.play() for $filePath');
    } catch (e) {
      logger.e('[CUBIT] Error calling play on service: $e');
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
    logger.i('[CUBIT] pauseRecording called.');
    try {
      await _audioPlaybackService.pause();
      logger.d('[CUBIT] Called _audioPlaybackService.pause()');
    } catch (e) {
      logger.e('[CUBIT] Error calling pause on service: $e');
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

  /// Seeks to a specific position in the current playback.
  Future<void> seekRecording(Duration position) async {
    logger.i('[CUBIT] seekRecording called for position: $position');
    try {
      await _audioPlaybackService.seek(position);
      logger.d('[CUBIT] Called _audioPlaybackService.seek() to $position');
    } catch (e) {
      logger.e('[CUBIT] Error calling seek on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              error: 'Failed to seek playback: $e',
            ),
          ),
        );
      }
    }
  }

  /// Stops the current playback completely.
  Future<void> stopPlayback() async {
    logger.i('[CUBIT] stopPlayback called.');
    try {
      await _audioPlaybackService.stop();
      logger.d('[CUBIT] Called _audioPlaybackService.stop()');
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

  String _mapFailureToMessage(Failure failure) {
    return failure.toString();
  }

  @override
  Future<void> close() {
    logger.d('[CUBIT] close() called, cancelling playback subscription...');
    _playbackSubscription?.cancel();
    logger.d('[CUBIT] Playback subscription cancelled.');
    return super.close();
  }
}
