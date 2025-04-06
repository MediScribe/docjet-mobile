import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' // Import PermissionStatus
    as ph; // Alias for openAppSettings

import 'audio_recording_state.dart';

class AudioRecordingCubit extends Cubit<AudioRecordingState> {
  final AudioRecorderRepository repository;

  Timer? _durationTimer;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath; // Still needed for duration calculation

  AudioRecordingCubit({required this.repository})
    : super(AudioRecordingInitial());

  /// Checks permission and moves to Ready or PermissionDenied state.
  Future<void> checkPermission() async {
    debugPrint(
      '[REC_CUBIT] checkPermission() called. Current state: ${state.runtimeType}',
    );
    emit(AudioRecordingLoading());
    final result = await repository.checkPermission();
    result.fold(
      (failure) {
        debugPrint(
          '[REC_CUBIT] checkPermission failed: ${failure.toString()}. Emitting Error state.',
        ); // Use toString()
        emit(
          AudioRecordingError('Permission check failed: ${failure.toString()}'),
        ); // Use toString()
      },
      (granted) {
        if (granted) {
          debugPrint('[REC_CUBIT] Permission granted. Emitting Ready state.');
          emit(AudioRecordingReady());
        } else {
          debugPrint(
            '[REC_CUBIT] Permission check returned false. Emitting PermissionDenied state.',
          );
          emit(AudioRecordingPermissionDenied());
        }
      },
    );
  }

  /// Requests permission and moves to Ready or PermissionDenied state.
  Future<void> requestPermission() async {
    debugPrint("[REC_CUBIT] requestPermission() called.");
    emit(AudioRecordingLoading());
    final result = await repository.requestPermission();
    result.fold(
      (failure) => emit(
        AudioRecordingError('Permission request failed: ${failure.toString()}'),
      ), // Use toString()
      (granted) async {
        if (granted) {
          debugPrint(
            "[REC_CUBIT] Permission granted via request. Emitting Ready state.",
          );
          emit(AudioRecordingReady());
        } else {
          debugPrint("[REC_CUBIT] Permission request denied.");
          // TODO(HardBob): Implement getPermissionStatus in Repository and uncomment this check
          /*
          // Check if permanently denied to guide user
          final statusResult =
              await repository.getPermissionStatus(); // Need repo method
          statusResult.fold(
            (statusFailure) {
              debugPrint(
                "[REC_CUBIT] Failed to get permission status after denial: ${statusFailure.toString()}",
              );
              // Fallback to simple denied state if status check fails
              emit(AudioRecordingPermissionDenied());
            },
            (status) {
              // Use ph.PermissionStatus directly
              if (status.isPermanentlyDenied || status.isRestricted) {
                debugPrint(
                  "[REC_CUBIT] Permission permanently denied/restricted.",
                );
                // Optionally emit a specific state or just Denied
                emit(
                  AudioRecordingPermissionDenied(),
                ); // Keep it simple for now
                // Consider adding a method/event to trigger opening settings
              } else {
                emit(AudioRecordingPermissionDenied());
              }
            },
          );
          */
          // For now, just emit denied if not granted
          emit(AudioRecordingPermissionDenied());
        }
      },
    );
  }

  /// Opens the application settings page for the user to manually change permissions.
  Future<void> openAppSettings() async {
    debugPrint("[REC_CUBIT] openAppSettings() called.");
    await ph.openAppSettings();
    // After returning from settings, re-check the permission
    // Debatable: Should the cubit automatically recheck, or wait for UI interaction?
    // Let's re-check proactively for now.
    await checkPermission();
  }

  /// Starts a new recording.
  void startRecording() async {
    // Removed appendTo parameter
    debugPrint('[REC_CUBIT] startRecording called.');

    // Removed append logic - keep it simple

    final loadingState = AudioRecordingLoading();
    debugPrint('[REC_CUBIT] Emitting state: $loadingState');
    emit(loadingState);

    debugPrint('[REC_CUBIT] Calling repository.startRecording()...');
    final result = await repository.startRecording();
    debugPrint('[REC_CUBIT] repository.startRecording() result: $result');

    result.fold(
      (failure) {
        _cleanupTimer();
        final errorState = AudioRecordingError(
          'Failed to start recording: ${failure.toString()}',
        ); // Use toString()
        debugPrint('[REC_CUBIT] Emitting state: $errorState');
        emit(errorState);
      },
      (filePath) {
        _recordingStartTime = DateTime.now();
        _currentRecordingPath = filePath;
        final recordingState = AudioRecordingInProgress(
          filePath: filePath,
          duration: Duration.zero,
        );
        debugPrint('[REC_CUBIT] Emitting state: $recordingState');
        emit(recordingState);
        debugPrint('[REC_CUBIT] Starting duration timer...');
        _startDurationTimer();
      },
    );
  }

  /// Stops the current recording. Returns the file path on success.
  Future<String?> stopRecording() async {
    debugPrint("[REC_CUBIT] stopRecording() called.");
    if (state is AudioRecordingInProgress || state is AudioRecordingPaused) {
      emit(AudioRecordingLoading());
      _cleanupTimer();

      final resultEither = await repository.stopRecording();

      return resultEither.fold(
        (failure) {
          debugPrint(
            "[REC_CUBIT] stopRecording failed: ${failure.toString()}",
          ); // Use toString()
          emit(
            AudioRecordingError(
              'Failed to stop recording: ${failure.toString()}',
            ),
          ); // Use toString()
          return null; // Indicate failure
        },
        (filePath) {
          debugPrint(
            "[REC_CUBIT] stopRecording successful. Path: $filePath. Emitting Stopped state.",
          );
          emit(AudioRecordingStopped(filePath)); // Emit stopped with path
          return filePath; // Indicate success with path
        },
      );
    } else {
      debugPrint(
        "[REC_CUBIT] stopRecording called but not in Recording/Paused state. No action taken.",
      );
      return null; // Indicate no action taken/failure
    }
  }

  /// Pauses the current recording.
  void pauseRecording() async {
    if (state is! AudioRecordingInProgress) {
      emit(AudioRecordingError('Cannot pause: Not currently recording.'));
      return;
    }

    final currentRecordingState = state as AudioRecordingInProgress;
    _durationTimer?.cancel();

    final result = await repository.pauseRecording();

    result.fold(
      (failure) {
        _startDurationTimer(); // Restart timer on failure
        emit(
          AudioRecordingError('Failed to pause: ${failure.toString()}'),
        ); // Use toString()
      },
      (_) {
        emit(
          AudioRecordingPaused(
            filePath: currentRecordingState.filePath,
            duration: currentRecordingState.duration,
          ),
        );
      },
    );
  }

  /// Resumes a paused recording.
  void resumeRecording() async {
    if (state is! AudioRecordingPaused) {
      emit(AudioRecordingError('Cannot resume: Not currently paused.'));
      return;
    }
    final pausedState = state as AudioRecordingPaused;

    final result = await repository.resumeRecording();

    result.fold(
      (failure) {
        emit(
          AudioRecordingError('Failed to resume: ${failure.toString()}'),
        ); // Use toString()
        // Consider re-emitting pausedState here if desired UX
      },
      (_) {
        // Recalculate start time based on paused duration
        _recordingStartTime = DateTime.now().subtract(pausedState.duration);
        _currentRecordingPath = pausedState.filePath; // Ensure path is set
        emit(
          AudioRecordingInProgress(
            filePath: pausedState.filePath,
            duration: pausedState.duration,
          ),
        );
        _startDurationTimer();
      },
    );
  }

  /// Prepares the cubit state specifically for the recorder page.
  /// Checks permission and emits Ready or PermissionDenied.
  Future<void> prepareRecorder() async {
    debugPrint(
      '[REC_CUBIT] prepareRecorder() called. Current state: ${state.runtimeType}',
    );
    // No need to emit loading here, checkPermission handles it.
    await checkPermission();
    debugPrint(
      '[REC_CUBIT] prepareRecorder() finished. State should now be Ready or Denied/Error.',
    );
  }

  // --- Timer Logic ---

  void _startDurationTimer() {
    _cleanupTimer(); // Ensure no existing timer is running
    if (_recordingStartTime != null && _currentRecordingPath != null) {
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state is AudioRecordingInProgress) {
          final now = DateTime.now();
          final duration = now.difference(
            _recordingStartTime!,
          ); // Ensure non-null
          // Important: Create a NEW state instance
          emit(
            AudioRecordingInProgress(
              filePath: _currentRecordingPath!,
              duration: duration,
            ),
          ); // Ensure non-null
        } else {
          // If state changed somehow (e.g., paused externally), stop the timer
          _cleanupTimer();
        }
      });
    } else {
      debugPrint(
        "[REC_CUBIT] Error: Tried to start timer without start time or path.",
      );
      // Maybe emit an error state here?
    }
  }

  void _cleanupTimer() {
    if (_durationTimer != null) {
      debugPrint("[REC_CUBIT] Cleaning up duration timer.");
      _durationTimer?.cancel();
      _durationTimer = null;
    }
    // Reset time/path only when stopping or erroring, maybe not here?
    // _recordingStartTime = null;
    // _currentRecordingPath = null;
  }

  @override
  Future<void> close() {
    _cleanupTimer();
    return super.close();
  }
}
