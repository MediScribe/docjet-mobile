import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart'; // Added repository import
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart'
    as ph; // Alias for openAppSettings

// Removed TODO about use cases

import 'audio_recorder_state.dart'; // Keep existing states

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  // Replaced use case fields with repository field
  final AudioRecorderRepository repository;

  Timer? _durationTimer;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath; // Still needed for duration calculation

  // Updated constructor to inject repository
  AudioRecorderCubit({required this.repository})
    : super(AudioRecorderInitial());

  /// Checks permission and moves to Ready or PermissionDenied state.
  Future<void> checkPermission() async {
    debugPrint(
      '[CUBIT] checkPermission() called. Current state: ${state.runtimeType}',
    );
    emit(AudioRecorderLoading());
    // Call repository directly
    final result = await repository.checkPermission();
    result.fold(
      (failure) {
        debugPrint(
          '[CUBIT] checkPermission failed: ${failure.toString()}. Emitting Error state.',
        );
        emit(
          AudioRecorderError('Permission check failed: ${failure.toString()}'),
        );
      },
      (granted) {
        if (granted) {
          debugPrint('[CUBIT] Permission granted. Emitting Ready state.');
          emit(AudioRecorderReady());
        } else {
          // If not granted, we might need to request it or show denied state.
          // For now, let's assume checkPermission only confirms existing status
          // and `requestPermission` handles the denial flow.
          // Re-evaluating this: If check says no, it likely means denied.
          debugPrint(
            '[CUBIT] Permission check returned false. Emitting PermissionDenied state.',
          );
          emit(AudioRecorderPermissionDenied());
        }
      },
    );
  }

  /// Requests permission and moves to Ready or PermissionDenied state.
  Future<void> requestPermission() async {
    debugPrint("[CUBIT] requestPermission() called.");
    emit(AudioRecorderLoading());
    // Call repository directly
    final result = await repository.requestPermission();
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

    // Call repository directly
    debugPrint('[CUBIT] Calling repository.startRecording()...');
    final result = await repository.startRecording();
    debugPrint('[CUBIT] repository.startRecording() result: $result');

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

      // Call repository directly
      final resultEither = await repository.stopRecording();

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
          // Emit Stopped first, then load recordings
          emit(AudioRecorderStopped());
          // Trigger loading recordings after stopping successfully
          await loadRecordings();
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

    // Call repository directly
    final result = await repository.pauseRecording();

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

    // Call repository directly
    final result = await repository.resumeRecording();

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

  /// Prepares the cubit state specifically for the recorder page.
  /// Checks permission and emits Ready or PermissionDenied.
  Future<void> prepareRecorder() async {
    debugPrint(
      '[CUBIT] prepareRecorder() called. Current state: ${state.runtimeType}',
    );
    // No need to emit loading here, checkPermission handles it.
    await checkPermission();
    // checkPermission will emit Ready or PermissionDenied/Error
    debugPrint(
      '[CUBIT] prepareRecorder() finished. State should now be Ready or Denied/Error.',
    );
  }

  /// Loads the list of existing recordings.
  Future<void> loadRecordings() async {
    debugPrint("[CUBIT] loadRecordings() called.");
    // Optional: Emit loading state if desired
    // emit(AudioRecorderLoading());

    // Call repository directly
    final result = await repository.loadRecordings();

    result.fold(
      (failure) {
        debugPrint("[CUBIT] loadRecordings failed: ${failure.toString()}");
        emit(
          AudioRecorderError(
            'Failed to load recordings: ${failure.toString()}',
          ),
        );
      },
      (records) {
        debugPrint(
          "[CUBIT] loadRecordings successful. Found ${records.length} records.",
        );
        // Assume we need a state to hold the list, like AudioRecorderLoaded
        // For now, let's just transition back to Ready, assuming the UI
        // fetches the list via a selector or another mechanism.
        // A better approach would be an `AudioRecorderLoaded(List<AudioRecord> records)` state.
        // emit(AudioRecorderLoaded(records)); // <<<< Ideal state
        // Let's revert to Ready for now to avoid breaking existing tests/UI
        // If the state machine requires explicit loaded state, we'll add it.
        // emit(AudioRecorderReady()); // Reverted to Ready for compatibility
        emit(AudioRecorderLoaded(records)); // Use the explicit loaded state
      },
    );
  }

  /// Deletes a specific recording.
  Future<void> deleteRecording(String filePath) async {
    debugPrint("[CUBIT] deleteRecording() called for path: $filePath");
    // Optional: Emit loading state? Depends on UX.
    // emit(AudioRecorderLoading());

    // Call repository directly
    // Note: Assuming repository.deleteRecording takes filePath directly.
    // If it needs a Params object, adjust this call.
    final result = await repository.deleteRecording(filePath);

    result.fold(
      (failure) {
        debugPrint("[CUBIT] deleteRecording failed: ${failure.toString()}");
        emit(
          AudioRecorderError(
            'Failed to delete recording: ${failure.toString()}',
          ),
        );
        // Optionally reload recordings even on failure to refresh the list?
        // await loadRecordings();
      },
      (_) async {
        debugPrint("[CUBIT] deleteRecording successful for path: $filePath");
        // After deleting, reload the list to reflect the change.
        await loadRecordings();
      },
    );
  }

  // --- Timer Logic ---

  /// Starts a timer to update the recording duration periodically.
  void _startDurationTimer() {
    _durationTimer?.cancel(); // Cancel any existing timer
    debugPrint('[CUBIT] Timer starting. Current state: ${state.runtimeType}');
    if (_recordingStartTime == null || _currentRecordingPath == null) {
      debugPrint('[CUBIT] Timer not started: missing start time or path.');
      return; // Don't start if we don't have the necessary info
    }

    final startTime = _recordingStartTime!;
    final filePath = _currentRecordingPath!;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state is AudioRecorderRecording) {
        final duration = DateTime.now().difference(startTime);
        // Check if mounted / state is still Recording before emitting
        if (!isClosed && state is AudioRecorderRecording) {
          final newState = AudioRecorderRecording(
            filePath: filePath,
            duration: duration,
          );
          // Avoid emitting if state hasn't actually changed (though duration always will)
          // debugPrint('[CUBIT] Timer tick. Emitting: $newState');
          emit(newState);
        } else {
          debugPrint(
            '[CUBIT] Timer tick skipped: Cubit closed or state changed.',
          );
          timer.cancel(); // Stop timer if state is no longer Recording
        }
      } else {
        debugPrint('[CUBIT] Timer tick skipped: Not in Recording state.');
        timer.cancel(); // Stop timer if state is not Recording
      }
    });
  }

  /// Cleans up the duration timer.
  void _cleanupTimer() {
    debugPrint('[CUBIT] Cleaning up timer...');
    _durationTimer?.cancel();
    _durationTimer = null;
    _recordingStartTime = null;
    _currentRecordingPath = null; // Clear path when timer stops
    debugPrint('[CUBIT] Timer cleaned up.');
  }

  /// Opens the app settings for the user to manually change permissions.
  Future<void> openAppSettings() async {
    debugPrint("[CUBIT] openAppSettings() called.");
    final opened =
        await ph
            .openAppSettings(); // Correctly call the permission_handler function, not the cubit method itself
    if (!opened) {
      debugPrint("[CUBIT] Failed to open app settings.");
      // Optionally emit an error state or log
      emit(AudioRecorderError("Could not open app settings."));
    } else {
      debugPrint("[CUBIT] App settings opened successfully.");
      // Optionally, emit a state indicating settings were opened,
      // or simply wait for the user to return and potentially re-check permission.
    }
  }

  @override
  Future<void> close() {
    _cleanupTimer();
    return super.close();
  }
}

// TODO: Define AudioRecorderLoaded state if not already present
// class AudioRecorderLoaded extends AudioRecorderState {
//   final List<AudioRecord> recordings;
//   const AudioRecorderLoaded(this.recordings);
//   @override List<Object> get props => [recordings];
// }
