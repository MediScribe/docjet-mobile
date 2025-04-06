import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

import 'audio_list_state.dart';

class AudioListCubit extends Cubit<AudioListState> {
  final AudioRecorderRepository repository;

  AudioListCubit({required this.repository}) : super(AudioListInitial());

  /// Loads the list of existing recordings.
  Future<void> loadRecordings() async {
    logger.i("[LIST_CUBIT] loadRecordings() called.");
    emit(AudioListLoading());
    // Call repository directly
    final result = await repository.loadRecordings();

    result.fold(
      (failure) {
        logger.e("[LIST_CUBIT] loadRecordings failed", error: failure);
        emit(
          AudioListError('Failed to load recordings: ${failure.toString()}'),
        );
      },
      (recordings) {
        logger.i(
          "[LIST_CUBIT] loadRecordings successful. Count: ${recordings.length}",
        );
        emit(AudioListLoaded(recordings));
      },
    );
  }

  /// Deletes a specific recording.
  Future<void> deleteRecording(String filePath) async {
    logger.i("[LIST_CUBIT] deleteRecording() called for path: $filePath");
    // Consider adding a loading state specific to deletion if needed
    // emit(AudioListDeleting()); // Example state
    logger.d("[LIST_CUBIT] Calling repository.deleteRecording('$filePath')...");
    final result = await repository.deleteRecording(filePath);
    logger.d("[LIST_CUBIT] repository.deleteRecording('$filePath') completed.");

    result.fold(
      (failure) {
        logger.e(
          "[LIST_CUBIT] deleteRecording failed for path: $filePath",
          error: failure,
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
        logger.i(
          "[LIST_CUBIT] deleteRecording successful for path: $filePath. Reloading list.",
        );
        // Deletion successful, reload the list to reflect the change.
        await loadRecordings();
        logger.d("[LIST_CUBIT] Finished reloading list after deletion.");
      },
    );
    logger.i(
      "[LIST_CUBIT] deleteRecording method finished for path: $filePath",
    );
  }

  // Other list-specific methods if needed (sorting, filtering?)
}
