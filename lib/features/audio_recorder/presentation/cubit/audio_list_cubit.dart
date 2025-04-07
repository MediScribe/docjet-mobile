import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/utils/logger.dart';

part 'audio_list_state.dart';

class AudioListCubit extends Cubit<AudioListState> {
  final AudioRecorderRepository repository;

  AudioListCubit({required this.repository}) : super(AudioListInitial());

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
      (recordings) {
        logger.i(
          '[CUBIT] Loaded ${recordings.length} recordings successfully.',
        );
        // Create a mutable copy before sorting
        final mutableRecordings = List<Transcription>.from(recordings);
        // Sort the mutable list by creation date, newest first (handle nulls)
        mutableRecordings.sort((a, b) {
          final dateA = a.localCreatedAt;
          final dateB = b.localCreatedAt;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1; // Nulls last
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        emit(
          AudioListLoaded(recordings: mutableRecordings),
        ); // Emit the sorted mutable list
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
        logger.e('[CUBIT] Error deleting recording', error: failure);
        // Use the named parameter for the message
        emit(
          AudioListError(
            message:
                'Failed to delete recording: ${_mapFailureToMessage(failure)}',
          ),
        );
        // Optionally reload the list to ensure consistency after error
        // await loadAudioRecordings();
      },
      (_) async {
        logger.i(
          "[LIST_CUBIT] deleteRecording successful for path: $filePath. Reloading list.",
        );
        // Deletion successful, reload the list to reflect the change.
        await loadAudioRecordings();
        logger.d("[LIST_CUBIT] Finished reloading list after deletion.");
      },
    );
    logger.i(
      "[LIST_CUBIT] deleteRecording method finished for path: $filePath",
    );
  }

  // Helper to map Failure types to user-friendly error messages
  String _mapFailureToMessage(Failure failure) {
    // Use toString() for a consistent message representation
    return failure.toString();
    /* // Keep specific formatting if needed later
    switch (failure.runtimeType) {
      case ServerFailure:
      case CacheFailure:
      case PermissionFailure:
      case RecordingFailure:
      case FileSystemFailure:
      case ConcatenationFailure:
      case PlatformFailure:
      case ApiFailure:
      default:
        return failure.toString(); // Fallback to toString()
    }
    */
  }

  // Other list-specific methods if needed (sorting, filtering?)
}
