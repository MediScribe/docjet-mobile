import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

part 'audio_list_state.dart';

// Set Logger Level to DEBUG for active development/debugging in this file
final logger = Logger(level: Level.debug);

class AudioListCubit extends Cubit<AudioListState> {
  final AudioRecorderRepository repository;
  final AudioPlaybackService _audioPlaybackService;
  StreamSubscription? _playbackSubscription;
  String? _currentPlayingFilePath; // Internal tracking of the active file

  AudioListCubit({
    required this.repository,
    required AudioPlaybackService audioPlaybackService,
  }) : _audioPlaybackService = audioPlaybackService,
       super(AudioListInitial()) {
    _listenToPlaybackService();
  }

  @override
  Future<void> close() {
    _playbackSubscription?.cancel();
    // Avoid disposing service here if it's managed globally by DI
    return super.close();
  }

  String mapFailureToMessage(Failure failure) {
    // Simple mapping for now, can be expanded
    if (failure is ServerFailure) {
      return 'Server Error: ${failure.toString()}';
    } else if (failure is CacheFailure) {
      return 'Cache Error: ${failure.toString()}';
    } else if (failure is FileSystemFailure) {
      return 'File System Error: ${failure.message}';
    } else {
      return 'An unexpected error occurred: ${failure.toString()}';
    }
  }

  void _listenToPlaybackService() {
    logger.d('[CUBIT] Subscribing to AudioPlaybackService stream...');
    _playbackSubscription = _audioPlaybackService.playbackStateStream.listen(
      (state) => _onPlaybackStateChanged(state),
      onError: (error, stackTrace) {
        logger.e(
          '[CUBIT] Error in playback service stream',
          error: error,
          stackTrace: stackTrace, // Log stack trace
        );
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
      // onDone: () => logger.d('[CUBIT] Playback service stream closed.'), // Optional
    );
    // logger.d('[CUBIT] Subscribed to AudioPlaybackService stream.'); // Redundant
  }

  void _onPlaybackStateChanged(PlaybackState playbackState) {
    // Demoted from DEBUG to TRACE due to high frequency potential
    final logPrefix = '[CUBIT_onPlaybackStateChanged]';
    // final timestamp = DateTime.now().millisecondsSinceEpoch; // REVERTED: Removed timestamp
    // logger.t(
    //   '$logPrefix Time: ${timestamp}ms - Received PlaybackState update: ${playbackState.runtimeType} ($playbackState)',
    // );
    logger.t(
      '$logPrefix Received PlaybackState update: ${playbackState.runtimeType}',
    );

    if (state is! AudioListLoaded) {
      // logger.w(
      //   '$logPrefix Current state is not AudioListLoaded, ignoring update.',
      // ); // Keep DEBUG
      return;
    }
    final currentState = state as AudioListLoaded;
    final currentPlaybackInfo = currentState.playbackInfo;
    // logger.d('$logPrefix Current PlaybackInfo: $currentPlaybackInfo'); // Keep DEBUG
    // logger.d(
    //   '$logPrefix Internal _currentPlayingFilePath: ${_currentPlayingFilePath?.split('/').last ?? 'null'}',
    // ); // Keep DEBUG

    // Map the freezed PlaybackState to PlaybackInfo properties
    String? filePath =
        _currentPlayingFilePath; // Use the internally tracked path
    bool isPlaying = false;
    bool isLoading = false;
    Duration position = Duration.zero;
    Duration totalDuration = Duration.zero;
    String? errorMessage;

    // Extract data from the incoming PlaybackState
    playbackState.when(
      initial: () {
        // logger.d('$logPrefix Handling initial state'); // Keep DEBUG
      },
      loading: () {
        // logger.d('$logPrefix Handling loading state'); // Keep DEBUG
        isLoading = true;
      },
      playing: (currentPosition, duration) {
        // logger.d(
        //   '$logPrefix Handling playing state: pos=${currentPosition.inMilliseconds}ms, dur=${duration.inMilliseconds}ms',
        // ); // Keep DEBUG
        isPlaying = true;
        position = currentPosition;
        totalDuration = duration;
      },
      paused: (currentPosition, duration) {
        // logger.d(
        //   '$logPrefix Handling paused state: pos=${currentPosition.inMilliseconds}ms, dur=${duration.inMilliseconds}ms',
        // ); // Keep DEBUG
        isPlaying = false;
        position = currentPosition;
        totalDuration = duration;
      },
      stopped: () {
        // logger.d('$logPrefix Handling stopped state'); // Keep DEBUG
      },
      completed: () {
        // logger.d('$logPrefix Handling completed state'); // Keep DEBUG
        position = totalDuration;
      },
      error: (message, currentPosition, duration) {
        // logger.d('$logPrefix Handling error state: $message'); // Keep DEBUG
        errorMessage = message;
        if (currentPosition != null) position = currentPosition;
        if (duration != null) totalDuration = duration;
      },
    );

    // Construct the new PlaybackInfo based on extracted data and internal file path
    final newPlaybackInfo = PlaybackInfo(
      activeFilePath: filePath, // Use the potentially updated internal path
      isPlaying: isPlaying,
      isLoading: isLoading,
      currentPosition: position,
      totalDuration: totalDuration,
      error: errorMessage,
    );

    // logger.d('$logPrefix Calculated New PlaybackInfo: $newPlaybackInfo'); // Keep DEBUG
    final areDifferent = currentPlaybackInfo != newPlaybackInfo;
    // logger.d('$logPrefix Comparison (current != new): $areDifferent'); // Keep DEBUG

    if (areDifferent) {
      // logger.i('$logPrefix Emitting updated AudioListLoaded state...'); // Keep INFO
      emit(currentState.copyWith(playbackInfo: newPlaybackInfo));
    }
    // else {
    // logger.d('$logPrefix State is the same, not emitting.'); // Keep DEBUG
    // }
  }

  /// Loads the list of existing recordings from the repository.
  Future<void> loadAudioRecordings() async {
    emit(AudioListLoading());
    // logger.d('[CUBIT] Loading audio recordings...'); // Keep DEBUG
    final failureOrRecordings = await repository.loadTranscriptions();

    failureOrRecordings.fold(
      (failure) {
        logger.e('[CUBIT] Error loading recordings: $failure');
        emit(AudioListError(message: mapFailureToMessage(failure)));
      },
      (transcriptions) {
        // logger.i(
        //   '[CUBIT] Loaded ${transcriptions.length} recordings successfully.',
        // ); // Keep INFO
        final mutableRecordings = List<Transcription>.from(transcriptions);
        // Sort by creation date, newest first
        mutableRecordings.sort((a, b) {
          final dateA = a.localCreatedAt;
          final dateB = b.localCreatedAt;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1; // Null dates go last
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending order
        });
        emit(AudioListLoaded(transcriptions: mutableRecordings));
      },
    );
  }

  /// Deletes a specific recording file and reloads the list.
  Future<void> deleteRecording(String filePath) async {
    // logger.i("[LIST_CUBIT] deleteRecording() called for path: $filePath"); // Keep INFO
    // logger.d("[LIST_CUBIT] Calling repository.deleteRecording('$filePath')..."); // Keep DEBUG
    final result = await repository.deleteRecording(filePath);
    // logger.d("[LIST_CUBIT] repository.deleteRecording('$filePath') completed."); // Keep DEBUG

    result.fold(
      (failure) {
        logger.e('[CUBIT] Error deleting recording', error: failure);
        // Show error to user? For now, just emit error state.
        emit(
          AudioListError(
            message:
                'Failed to delete recording: ${mapFailureToMessage(failure)}',
          ),
        );
        // Consider reloading list even on failure to reflect FS state?
      },
      (_) async {
        // logger.i(
        //   "[LIST_CUBIT] deleteRecording successful for path: $filePath. Reloading list.",
        // ); // Keep INFO
        await loadAudioRecordings(); // Reload to update UI
        // logger.d("[LIST_CUBIT] Finished reloading list after deletion."); // Keep DEBUG
      },
    );
    // logger.i(
    //   "[LIST_CUBIT] deleteRecording method finished for path: $filePath",
    // ); // Keep INFO
  }

  /// Initiates playback of the specified recording file.
  Future<void> playRecording(String filePath) async {
    // logger.i(
    //   '[CUBIT_playRecording] START - Req Path: ${filePath.split('/').last}',
    // ); // Keep INFO
    _currentPlayingFilePath = filePath; // Set context immediately
    // logger.d(
    //   '  -> _currentPlayingFilePath SET to: ${_currentPlayingFilePath?.split('/').last}',
    // ); // Keep DEBUG
    try {
      // logger.d(
      //   '[CUBIT_playRecording] ABOUT TO CALL _audioPlaybackService.play($filePath)',
      // ); // Keep DEBUG
      await _audioPlaybackService.play(filePath);
      // logger.d('  -> Service call complete.'); // Keep DEBUG
    } catch (e) {
      logger.e('[CUBIT_playRecording] Error calling play on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              activeFilePath: filePath, // Reflect the attempted file
              isLoading: false,
              isPlaying: false,
              error: 'Failed to start playback: $e',
            ),
          ),
        );
      } else {
        // If not loaded, maybe emit a general error?
        emit(AudioListError(message: 'Failed to start playback: $e'));
      }
    }
    // logger.d('[CUBIT_playRecording] END'); // Keep DEBUG
  }

  /// Pauses the currently playing audio via the service.
  Future<void> pauseRecording() async {
    // logger.i('[CUBIT_pauseRecording] START'); // Keep INFO
    // No need to check _currentPlayingFilePath, service handles current state
    try {
      // logger.d('[CUBIT_pauseRecording] Calling _audioPlaybackService.pause()...'); // Keep DEBUG
      await _audioPlaybackService.pause();
      // logger.d('  -> Service pause call complete.'); // Keep DEBUG
    } catch (e) {
      logger.e('[CUBIT_pauseRecording] Error calling pause on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              // Don't change isPlaying optimistically, rely on stream
              error: 'Failed to pause playback: $e',
            ),
          ),
        );
      }
    }
    // logger.d('[CUBIT_pauseRecording] END'); // Keep DEBUG
  }

  /// Resumes the currently paused audio via the service.
  Future<void> resumeRecording() async {
    // logger.i('[CUBIT_resumeRecording] START'); // Keep INFO
    if (_currentPlayingFilePath == null) {
      logger.w('[CUBIT_resumeRecording] Cannot resume, no active file path.');
      // TODO: Maybe try to play the first file instead?
      return;
    }
    // No need to check state, service handles it
    try {
      // logger.d(
      //   '[CUBIT_resumeRecording] Calling _audioPlaybackService.resume()...',
      // ); // Keep DEBUG
      await _audioPlaybackService.resume();
      // logger.d('  -> Service resume call complete.'); // Keep DEBUG
    } catch (e) {
      logger.e('[CUBIT_resumeRecording] Error calling resume on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              // Don't change isPlaying optimistically
              error: 'Failed to resume playback: $e',
            ),
          ),
        );
      }
    }
    // logger.d('[CUBIT_resumeRecording] END'); // Keep DEBUG
  }

  /// Seeks to a specific position in the specified recording file.
  Future<void> seekRecording(String filePath, Duration position) async {
    // logger.d(
    //   '[CUBIT_seekRecording] START - File: ${filePath.split('/').last}, Seek Request: ${position.inMilliseconds}ms',
    // ); // Keep DEBUG

    // Update internal path immediately so subsequent play/resume work
    _currentPlayingFilePath = filePath;
    // logger.d(
    //   '  -> _currentPlayingFilePath SET to: ${_currentPlayingFilePath?.split('/').last}',
    // ); // Keep DEBUG

    // logger.d(
    //   '[CUBIT_seekRecording] Seeking in file: ${filePath.split('/').last}',
    // ); // Keep DEBUG

    try {
      // Rely on service stream for authoritative state, no optimistic UI update here.
      // logger.d(
      //   '[CUBIT_seekRecording] Calling _audioPlaybackService.seek($filePath, $position)...',
      // ); // Keep DEBUG
      await _audioPlaybackService.seek(filePath, position);
      // logger.d('  -> Service seek call complete.'); // Keep DEBUG
    } catch (e) {
      logger.e('[CUBIT_seekRecording] Error calling seek on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              activeFilePath: filePath, // Provide context for the error
              error: 'Seek failed: $e',
              isLoading: false,
            ),
          ),
        );
      } else {
        logger.e(
          '[CUBIT_seekRecording] Seek error occurred but state was not AudioListLoaded.',
        );
      }
    }
    // logger.d('[CUBIT_seekRecording] END'); // Keep DEBUG
  }

  /// Stops the currently playing audio via the service.
  Future<void> stopRecording() async {
    // logger.i('[CUBIT_stopRecording] START'); // Keep INFO
    try {
      // logger.d('[CUBIT_stopRecording] Calling _audioPlaybackService.stop()...'); // Keep DEBUG
      await _audioPlaybackService.stop();
      // logger.d('  -> Service stop call complete.'); // Keep DEBUG
      // Service should clear context now, _onPlaybackStateChanged will update internal path
    } catch (e) {
      logger.e('[CUBIT_stopRecording] Error calling stop on service: $e');
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              error: 'Failed to stop playback: $e',
              // isPlaying should be handled by stream
            ),
          ),
        );
      }
    }
    // logger.d('[CUBIT_stopRecording] END'); // Keep DEBUG
  }
}
