import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart'; // Assuming Failure is defined here
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

/// Abstract contract for interacting with audio recording data.
///
/// Methods return [Either] to handle success ([Right]) or failure ([Left]).
abstract class AudioRecorderRepository {
  /// Checks if microphone permission is granted.
  Future<Either<Failure, bool>> checkPermission();

  /// Requests microphone permission.
  Future<Either<Failure, bool>> requestPermission();

  /// Starts a new audio recording.
  ///
  /// Returns the path where the recording is being saved.
  Future<Either<Failure, String>> startRecording();

  /// Stops the current recording.
  ///
  /// Returns the completed [AudioRecord] entity.
  Future<Either<Failure, AudioRecord>> stopRecording();

  /// Pauses the current recording.
  Future<Either<Failure, void>> pauseRecording();

  /// Resumes a paused recording.
  Future<Either<Failure, void>> resumeRecording();

  /// Deletes a specific audio recording.
  Future<Either<Failure, void>> deleteRecording(String filePath);

  /// Appends new audio to an existing recording.
  ///
  /// Takes the existing [AudioRecord] and returns the updated [AudioRecord].
  /// This is where the concatenation logic will eventually be triggered.
  Future<Either<Failure, AudioRecord>> appendToRecording(
    AudioRecord existingRecord,
  );

  /// Loads all existing audio recordings.
  Future<Either<Failure, List<AudioRecord>>> loadRecordings();

  /// Lists all existing audio recordings.
  Future<Either<Failure, List<AudioRecord>>> listRecordings();
}
