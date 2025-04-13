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

// Set Logger Level to OFF to disable logging in this file
final logger = Logger(level: Level.off);

// Special debug flag for state transition tracking - set to true to enable detailed transition logs
const bool _debugStateTransitions = true;

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
    logger.t('[STATE_FLOW Cubit] Received state from service: $playbackState');

    if (state is! AudioListLoaded) {
      logger.w(
        '[STATE_FLOW Cubit] Received playback state $playbackState but cubit state is not AudioListLoaded: ${state.runtimeType}. Ignoring.',
      );
      return;
    }
    final currentState = state as AudioListLoaded;
    final currentPlaybackInfo = currentState.playbackInfo;

    // Log how the current PlaybackInfo would map to each widget if there were multiple items
    if (_debugStateTransitions) {
      logger.d(
        '[STATE_TRANSITION] CUBIT: PlaybackState (in) = ${playbackState.runtimeType}',
      );
    }

    // Map the freezed PlaybackState to PlaybackInfo properties
    String? activeFilePath =
        _currentPlayingFilePath; // Start with internally tracked path
    bool isPlaying = false;
    bool isLoading = false;
    Duration currentPosition = Duration.zero;
    Duration totalDuration = Duration.zero;
    String? error;

    // Extract data from the incoming PlaybackState
    playbackState.when(
      initial: () {
        // Keep the existing _currentPlayingFilePath
        // Initial state doesn't imply stopping the current file context
      },
      loading: () {
        isLoading = true;
        // Keep the activeFilePath during loading
      },
      playing: (pos, dur) {
        isPlaying = true;
        currentPosition = pos;
        totalDuration = dur;
      },
      paused: (pos, dur) {
        isPlaying = false;
        currentPosition = pos;
        totalDuration = dur;
      },
      stopped: () {
        // Player stopped, clear the active file in the UI state
        activeFilePath = null;
        isPlaying = false;
        currentPosition = Duration.zero; // Reset position on stop
        // Keep totalDuration? Maybe not, depends on desired UI
      },
      completed: () {
        // Similar to stopped, but might show full duration/position
        activeFilePath = null; // File context is gone
        isPlaying = false;
        currentPosition = totalDuration; // Show end position
        // Keep totalDuration
      },
      error: (message, pos, dur) {
        error = message;
        if (pos != null) currentPosition = pos;
        if (dur != null) totalDuration = dur;
        // Keep activeFilePath to show error in context
        isPlaying = false;
        isLoading = false;
      },
    );

    // Construct the new PlaybackInfo
    final newPlaybackInfo = PlaybackInfo(
      activeFilePath: activeFilePath,
      isPlaying: isPlaying,
      isLoading: isLoading,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      error: error,
    );

    if (_debugStateTransitions) {
      logger.d(
        '[STATE_TRANSITION] CUBIT: PlaybackInfo (out) = activeFilePath:${activeFilePath?.split('/').last}, isPlaying:$isPlaying, isLoading:$isLoading',
      );
    }

    // Only emit if the playback info actually changed
    if (currentPlaybackInfo != newPlaybackInfo) {
      // Add detailed logging of the PlaybackInfo changes, but only for major state changes
      if (currentPlaybackInfo.isPlaying != newPlaybackInfo.isPlaying ||
          currentPlaybackInfo.activeFilePath !=
              newPlaybackInfo.activeFilePath ||
          currentPlaybackInfo.isLoading != newPlaybackInfo.isLoading ||
          currentPlaybackInfo.error != newPlaybackInfo.error) {
        // Demote this detailed log to trace as it can be noisy during seeks
        logger.t(
          '[CUBIT_PLAYBACK_INFO] Changed: '
          'activeFilePath: ${currentPlaybackInfo.activeFilePath?.split('/').last} -> ${newPlaybackInfo.activeFilePath?.split('/').last}, '
          'isPlaying: ${currentPlaybackInfo.isPlaying} -> ${newPlaybackInfo.isPlaying}, '
          'isLoading: ${currentPlaybackInfo.isLoading} -> ${newPlaybackInfo.isLoading}, '
          'state: ${playbackState.runtimeType}',
        );
      }

      logger.t(
        '[STATE_FLOW Cubit] Emitting new state with playbackInfo: $newPlaybackInfo',
      );
      emit(currentState.copyWith(playbackInfo: newPlaybackInfo));
    } else {
      logger.t(
        '[STATE_FLOW Cubit] State unchanged ($playbackState -> $newPlaybackInfo), not emitting.',
      );
    }
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

  /// Initiates playback for a given audio file.
  Future<void> playRecording(String filePath) async {
    _currentPlayingFilePath = filePath; // Set context immediately
    try {
      await _audioPlaybackService.play(filePath);
    } catch (e, s) {
      logger.e('[CUBIT] Error calling play service', error: e, stackTrace: s);
      // Restore error handling
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
  }

  /// Pauses the currently playing audio.
  Future<void> pauseRecording() async {
    // Ensure we keep the current playing file path
    if (_currentPlayingFilePath == null && state is AudioListLoaded) {
      final currentState = state as AudioListLoaded;
      if (currentState.playbackInfo.activeFilePath != null) {
        _currentPlayingFilePath = currentState.playbackInfo.activeFilePath;
        logger.d(
          '[CUBIT ACTION] pauseRecording updated _currentPlayingFilePath from state: $_currentPlayingFilePath',
        );
      }
    }

    try {
      await _audioPlaybackService.pause();
    } catch (e, s) {
      logger.e('[CUBIT] Error calling pause service', error: e, stackTrace: s);
      // Restore error handling
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

  /// Seeks to a specific position in an audio file.
  ///
  /// Note: This implicitly handles pausing if the file is not currently playing.
  Future<void> seekRecording(String filePath, Duration position) async {
    final fileId = filePath.split('/').last;
    logger.d(
      '[CUBIT_SEEK $fileId] Received: pos=${position.inMilliseconds}ms -> Calling service.seek()',
    );
    _currentPlayingFilePath =
        filePath; // Update context immediately when seek is initiated
    try {
      await _audioPlaybackService.seek(filePath, position);
    } catch (e, s) {
      logger.e('[CUBIT] Error calling seek service', error: e, stackTrace: s);
      // Restore error handling that emits an error state
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
  }

  /// Stops the currently playing audio.
  Future<void> stopRecording() async {
    _currentPlayingFilePath = null; // Clear context on explicit stop
    try {
      await _audioPlaybackService.stop();
    } catch (e, s) {
      logger.e('[CUBIT] Error calling stop service', error: e, stackTrace: s);
      // Restore error handling
      if (state is AudioListLoaded) {
        final currentState = state as AudioListLoaded;
        emit(
          currentState.copyWith(
            playbackInfo: currentState.playbackInfo.copyWith(
              error: 'Failed to stop playback: $e',
            ),
          ),
        );
      }
    }
  }

  /// Renames a specific recording file and reloads the list.
  Future<void> renameRecording(String oldPath, String newName) async {
    // ... existing code ...
  }
}
