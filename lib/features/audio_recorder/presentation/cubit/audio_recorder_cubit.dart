import 'dart:async';

import 'package:docjet_mobile/core/usecases/usecase.dart'; // For NoParams
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/check_permission.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/delete_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/load_recordings.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/pause_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/resume_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/start_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/stop_recording.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart'; // Import for openAppSettings

// TODO: Import LoadRecordingsUseCase and potentially append-related use cases

import 'audio_recorder_state.dart'; // Keep existing states

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  final CheckPermission checkPermissionUseCase;
  final StartRecording startRecordingUseCase;
  final StopRecording stopRecordingUseCase;
  final PauseRecording pauseRecordingUseCase;
  final ResumeRecording resumeRecordingUseCase;
  final DeleteRecording deleteRecordingUseCase;
  final LoadRecordings loadRecordingsUseCase;
  // TODO: Add LoadRecordingsUseCase etc.

  Timer? _durationTimer;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath; // Still needed for duration calculation

  AudioRecorderCubit({
    required this.checkPermissionUseCase,
    required this.startRecordingUseCase,
    required this.stopRecordingUseCase,
    required this.pauseRecordingUseCase,
    required this.resumeRecordingUseCase,
    required this.deleteRecordingUseCase,
    required this.loadRecordingsUseCase,
    // TODO: Add required LoadRecordingsUseCase
  }) : super(AudioRecorderInitial());

  /// Checks permission and moves to Ready or PermissionDenied state.
  void checkPermission() async {
    emit(AudioRecorderLoading()); // Indicate checking
    final result = await checkPermissionUseCase(NoParams());
    result.fold(
      (failure) => emit(
        AudioRecorderError('Permission check failed: ${failure.toString()}'),
      ), // Map Failure
      (hasPermission) => emit(
        hasPermission ? AudioRecorderReady() : AudioRecorderPermissionDenied(),
      ),
    );
  }

  /// Starts a new recording.
  void startRecording({AudioRecord? appendTo}) async {
    // TODO: Implement append logic using separate use cases if needed
    if (appendTo != null) {
      emit(AudioRecorderError("Append functionality not implemented yet."));
      return;
    }

    emit(AudioRecorderLoading());
    final result = await startRecordingUseCase(NoParams());

    result.fold(
      (failure) {
        _cleanupTimer();
        emit(
          AudioRecorderError(
            'Failed to start recording: ${failure.toString()}',
          ),
        );
      },
      (filePath) {
        _recordingStartTime = DateTime.now();
        _currentRecordingPath = filePath;
        emit(
          AudioRecorderRecording(filePath: filePath, duration: Duration.zero),
        );
        _startDurationTimer();
      },
    );
  }

  /// Stops the current recording.
  void stopRecording() async {
    _cleanupTimer(); // Stop the UI timer first
    emit(AudioRecorderLoading()); // Indicate processing

    final result = await stopRecordingUseCase(NoParams());

    _recordingStartTime = null;
    _currentRecordingPath = null;

    result.fold(
      (failure) => emit(
        AudioRecorderError('Failed to stop recording: ${failure.toString()}'),
      ),
      (audioRecord) {
        // Map Domain entity to Presentation state entity
        final recordState = AudioRecordState(
          filePath: audioRecord.filePath,
          duration: audioRecord.duration,
          createdAt: audioRecord.createdAt,
        );
        emit(AudioRecorderStopped(record: recordState));
      },
    );
    // TODO: Potentially trigger loadRecordings here or rely on UI to refresh
  }

  /// Pauses the current recording.
  void pauseRecording() async {
    if (state is! AudioRecorderRecording) {
      // Can only pause if currently recording
      emit(AudioRecorderError('Cannot pause: Not currently recording.'));
      return;
    }

    final currentRecordingState = state as AudioRecorderRecording;
    _durationTimer?.cancel(); // Pause the UI timer

    final result = await pauseRecordingUseCase(NoParams());

    result.fold(
      (failure) {
        _startDurationTimer(); // Restart timer on failure
        emit(AudioRecorderError('Failed to pause: ${failure.toString()}'));
      },
      (_) {
        // Transition to Paused state
        emit(
          AudioRecorderPaused(
            filePath: currentRecordingState.filePath,
            duration: currentRecordingState.duration,
          ),
        );
      },
    );
  }

  /// Resumes a paused recording.
  void resumeRecording() async {
    if (state is! AudioRecorderPaused) {
      // Can only resume if currently paused
      emit(AudioRecorderError('Cannot resume: Not currently paused.'));
      return;
    }
    final pausedState = state as AudioRecorderPaused;

    // Emit loading before calling use case? Optional, depends on desired UX
    // emit(AudioRecorderLoading());

    final result = await resumeRecordingUseCase(NoParams());

    result.fold(
      (failure) {
        // If resume fails, stay in Paused state but maybe show error?
        // Or transition back to ready? Let's show error and stay paused for now.
        emit(AudioRecorderError('Failed to resume: ${failure.toString()}'));
        // Keep the Paused state data? Or revert to the error state fully?
        // Let's emit error but maybe we should revert to Paused state explicitly
        // emit(pausedState); // Re-emit paused state after error if needed
      },
      (_) {
        // Transition back to Recording state
        _recordingStartTime = DateTime.now().subtract(pausedState.duration);
        _currentRecordingPath = pausedState.filePath; // Ensure path is set
        emit(
          AudioRecorderRecording(
            filePath: pausedState.filePath,
            duration: pausedState.duration,
          ),
        );
        _startDurationTimer(); // Restart the UI timer
      },
    );
  }

  /// Deletes a specific recording file.
  void deleteRecording(String filePath) async {
    emit(AudioRecorderLoading()); // Or a specific "Deleting" state
    final result = await deleteRecordingUseCase(
      DeleteRecordingParams(filePath: filePath),
    );
    result.fold(
      (failure) => emit(
        AudioRecorderError('Failed to delete $filePath: ${failure.toString()}'),
      ),
      (_) {
        // Deletion successful, transition back to Ready or reload list
        emit(AudioRecorderReady()); // Simple transition
        // TODO: Trigger loadRecordings here
      },
    );
  }

  // --- Timer Logic ---

  void _startDurationTimer() {
    _cleanupTimer(); // Ensure any existing timer is stopped
    if (_recordingStartTime != null && _currentRecordingPath != null) {
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state is AudioRecorderRecording) {
          final duration = DateTime.now().difference(_recordingStartTime!);
          // Ensure we're still in a recording state before emitting
          // (stopRecording might have been called but state update delayed)
          if (isClosed) {
            return; // Corrected: Check if the cubit itself is closed
          }
          if (state is AudioRecorderRecording) {
            // Double check state
            emit(
              AudioRecorderRecording(
                filePath: _currentRecordingPath!,
                duration: duration,
              ),
            );
          } else {
            _cleanupTimer(); // State changed unexpectedly, stop timer
          }
        } else {
          _cleanupTimer(); // Stop timer if not in recording state
        }
      });
    }
  }

  void _cleanupTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  Future<void> close() {
    _cleanupTimer();
    return super.close();
  }

  /// Opens the application settings page for the user to manage permissions.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Loads the list of existing recordings.
  void loadRecordings() async {
    emit(AudioRecorderLoading()); // Indicate loading
    final result = await loadRecordingsUseCase(NoParams());

    result.fold(
      (failure) => emit(
        AudioRecorderError('Failed to load recordings: ${failure.toString()}'),
      ),
      (recordings) {
        // Map domain entities to presentation state entities
        final recordStates =
            recordings
                .map(
                  (record) => AudioRecordState(
                    filePath: record.filePath,
                    duration: record.duration,
                    createdAt: record.createdAt,
                  ),
                )
                .toList();
        emit(AudioRecorderListLoaded(recordings: recordStates));
      },
    );
  }

  // TODO: Implement appendToRecording logic flow using appropriate use cases
  // This will likely involve new states like AudioRecorderAppending
  // and coordinating start/stop/concatenate use cases.
}

// Note: The original _concatenateAudioFiles and _getAudioDuration methods are GONE.
// All direct file I/O, permission checks, and recording logic are GONE.
// It now relies purely on injected UseCases.
