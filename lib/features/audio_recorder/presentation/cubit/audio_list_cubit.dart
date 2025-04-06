import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:flutter/foundation.dart'; // Keep for debugPrint temporarily

import 'audio_list_state.dart';

class AudioListCubit extends Cubit<AudioListState> {
  final AudioRecorderRepository repository;

  AudioListCubit({required this.repository}) : super(AudioListInitial());

  /// Loads the list of existing recordings.
  Future<void> loadRecordings() async {
    debugPrint("[LIST_CUBIT] loadRecordings() called.");
    emit(AudioListLoading());
    // Call repository directly
    final result = await repository.loadRecordings();

    result.fold(
      (failure) {
        debugPrint("[LIST_CUBIT] loadRecordings failed: ${failure.toString()}");
        emit(
          AudioListError('Failed to load recordings: ${failure.toString()}'),
        );
      },
      (recordings) {
        debugPrint(
          "[LIST_CUBIT] loadRecordings successful. Count: ${recordings.length}",
        );
        emit(AudioListLoaded(recordings));
      },
    );
  }

  /// Deletes a specific recording.
  Future<void> deleteRecording(String filePath) async {
    debugPrint("[LIST_CUBIT] deleteRecording() called for path: $filePath");
    // Consider adding a loading state specific to deletion if needed
    // emit(AudioListDeleting()); // Example state
    debugPrint(
      "[LIST_CUBIT] Calling repository.deleteRecording('$filePath')...",
    );
    final result = await repository.deleteRecording(filePath);
    debugPrint(
      "[LIST_CUBIT] repository.deleteRecording('$filePath') completed.",
    );

    result.fold(
      (failure) {
        debugPrint(
          "[LIST_CUBIT] deleteRecording failed: ${failure.toString()}",
        );
        // Emit an error state, but maybe keep the current list loaded?
        // Or emit a specific error state that the UI can show as a snackbar?
        // For now, just log and emit a generic error. Consider UI feedback strategy.
        emit(
          AudioListError('Failed to delete recording: ${failure.toString()}'),
        );
        // Optionally reload the list to ensure consistency after error
        // await loadRecordings();
      },
      (_) async {
        debugPrint("[LIST_CUBIT] deleteRecording successful. Reloading list.");
        // Deletion successful, reload the list to reflect the change.
        await loadRecordings();
        debugPrint("[LIST_CUBIT] Finished reloading list after deletion.");
      },
    );
    debugPrint("[LIST_CUBIT] deleteRecording('$filePath') method finished.");
  }

  // Other list-specific methods if needed (sorting, filtering?)
}
