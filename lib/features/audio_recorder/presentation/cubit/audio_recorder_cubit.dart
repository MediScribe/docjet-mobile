import 'dart:async';
import 'package:flutter/foundation.dart'; // Add this import

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/check_permission.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/delete_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/load_recordings.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/pause_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/request_permission.dart';
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
  final RequestPermission requestPermissionUseCase;
  // TODO: Add LoadRecordingsUseCase etc.

  Timer? _durationTimer;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath; // Still needed for duration calculation

  AudioRecorderCubit({
    required this.checkPermissionUseCase,
    required this.requestPermissionUseCase,
    required this.startRecordingUseCase,
    required this.stopRecordingUseCase,
    required this.pauseRecordingUseCase,
    required this.resumeRecordingUseCase,
    required this.deleteRecordingUseCase,
    required this.loadRecordingsUseCase,
    // TODO: Add required LoadRecordingsUseCase
  }) : super(AudioRecorderInitial());

  /// Checks permission and moves to Ready or PermissionDenied state.
  Future<void> checkPermission() async {
    debugPrint("[CUBIT] checkPermission() called.");
    emit(AudioRecorderLoading());
    final result = await checkPermissionUseCase(NoParams());
    result.fold(
      (failure) => emit(
        AudioRecorderError('Permission check failed: ${failure.toString()}'),
      ),
      (hasPermission) async {
        if (hasPermission) {
          debugPrint("[CUBIT] Permission granted. Emitting Ready state.");
          emit(AudioRecorderReady());
        } else {
          debugPrint("[CUBIT] Permission denied.");
          emit(AudioRecorderPermissionDenied());
        }
      },
    );
  }

  /// Requests permission and moves to Ready or PermissionDenied state.
  Future<void> requestPermission() async {
    debugPrint("[CUBIT] requestPermission() called.");
    emit(AudioRecorderLoading());
    final result = await requestPermissionUseCase(NoParams());
    result.fold(
      (failure) => emit(
        AudioRecorderError('Permission request failed: ${failure.toString()}'),
      ),
      (granted) async {
        if (granted) {
          debugPrint(
            "[CUBIT] Permission granted via request. Emitting Ready state.",
          );
          emit(AudioRecorderReady());
        } else {
          debugPrint("[CUBIT] Permission request denied.");
          emit(AudioRecorderPermissionDenied());
        }
      },
    );
  }

  /// Starts a new recording.
  void startRecording({AudioRecord? appendTo}) async {
    debugPrint(
      '[CUBIT] startRecording called. appendTo: ${appendTo?.filePath}',
    );
    // TODO: Implement append logic using separate use cases if needed
    if (appendTo != null) {
      final errorState = AudioRecorderError(
        "Append functionality not implemented yet.",
      );
      debugPrint('[CUBIT] Emitting state: $errorState');
      emit(errorState);
      return;
    }

    final loadingState = AudioRecorderLoading();
    debugPrint('[CUBIT] Emitting state: $loadingState');
    emit(loadingState);

    debugPrint('[CUBIT] Calling startRecordingUseCase...');
    final result = await startRecordingUseCase(NoParams());
    debugPrint('[CUBIT] startRecordingUseCase result: $result');

    result.fold(
      (failure) {
        _cleanupTimer();
        final errorState = AudioRecorderError(
          'Failed to start recording: ${failure.toString()}',
        );
        debugPrint('[CUBIT] Emitting state: $errorState');
        emit(errorState);
      },
      (filePath) {
        _recordingStartTime = DateTime.now();
        _currentRecordingPath = filePath;
        final recordingState = AudioRecorderRecording(
          filePath: filePath,
          duration: Duration.zero,
        );
        debugPrint('[CUBIT] Emitting state: $recordingState');
        emit(recordingState);
        debugPrint('[CUBIT] Starting duration timer...');
        _startDurationTimer();
      },
    );
  }

  /// Stops the current recording.
  Future<void> stopRecording() async {
    debugPrint("[CUBIT] stopRecording() called.");
    if (state is AudioRecorderRecording || state is AudioRecorderPaused) {
      emit(AudioRecorderLoading());
      _cleanupTimer();

      final resultEither = await stopRecordingUseCase(NoParams());

      resultEither.fold(
        (failure) async {
          debugPrint("[CUBIT] stopRecording failed: ${failure.toString()}");
          emit(
            AudioRecorderError(
              'Failed to stop recording: ${failure.toString()}',
            ),
          );
        },
        (filePath) async {
          debugPrint(
            "[CUBIT] stopRecording successful. Path: $filePath. Emitting Stopped state.",
          );
          emit(AudioRecorderStopped());
        },
      );
    } else {
      debugPrint(
        "[CUBIT] stopRecording called but not in Recording/Paused state. No action taken.",
      );
    }
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
  Future<void> deleteRecording(String filePath) async {
    debugPrint("[CUBIT] deleteRecording() called for: $filePath");
    emit(AudioRecorderLoading());
    final params = DeleteRecordingParams(filePath: filePath);
    final result = await deleteRecordingUseCase(params);

    result.fold(
      (failure) {
        debugPrint("[CUBIT] deleteRecording failed: ${failure.toString()}");
        emit(
          AudioRecorderError(
            'Failed to delete $filePath: ${failure.toString()}',
          ),
        );
        debugPrint(
          "[CUBIT] deleteRecording failed. Calling loadRecordings() anyway.",
        );
        loadRecordings();
      },
      (_) async {
        debugPrint(
          "[CUBIT] deleteRecording successful. Calling loadRecordings().",
        );
        await loadRecordings();
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
  Future<void> loadRecordings() async {
    debugPrint("[CUBIT] loadRecordings() called.");
    emit(AudioRecorderLoading());
    debugPrint("[CUBIT] Calling loadRecordingsUseCase...");
    final result = await loadRecordingsUseCase(NoParams());
    debugPrint("[CUBIT] loadRecordingsUseCase finished.");

    result.fold(
      (failure) {
        debugPrint("[CUBIT] loadRecordings failed: ${failure.toString()}");
        emit(
          AudioRecorderError(
            'Failed to load recordings: ${failure.toString()}',
          ),
        );
      },
      (recordings) {
        debugPrint(
          "[CUBIT] loadRecordings succeeded. Found ${recordings.length} recordings.",
        );
        // Map domain entities to presentation state entities
        final recordingStates =
            recordings
                .map(
                  (r) => AudioRecordState(
                    filePath: r.filePath,
                    duration: r.duration,
                    createdAt: r.createdAt,
                  ),
                )
                .toList();
        emit(AudioRecorderListLoaded(recordings: recordingStates));
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
