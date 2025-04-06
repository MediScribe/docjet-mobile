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

  /// Starts a new recording session.
  /// Returns [Right(String)] with the recording path on success, or a [Failure] on the Left.
  Future<Either<Failure, String>> startRecording();

  /// Stops the current recording session.
  /// Returns [Right(String)] with the final recording path on success,
  /// or a [Failure] on the Left.
  Future<Either<Failure, String>> stopRecording();

  /// Pauses the current recording session.
  /// Returns [Right(void)] on success, or a [Failure] on the Left.
  Future<Either<Failure, void>> pauseRecording();

  /// Resumes a paused recording session.
  /// Returns [Right(void)] on success, or a [Failure] on the Left.
  Future<Either<Failure, void>> resumeRecording();

  /// Deletes a specific recording file.
  /// Returns [Right(void)] on success, or a [Failure] on the Left.
  Future<Either<Failure, void>> deleteRecording(String filePath);

  /// Appends a new recording segment to the currently active recording.
  ///
  /// [segmentPath]: The path of the new audio segment to append.
  /// Returns [Right(String)] with the path to the *new*, concatenated file on success,
  /// or a [Failure] on the Left.
  /// Note: The implementation should handle cleanup of the original files.
  Future<Either<Failure, String>> appendToRecording(String segmentPath);

  /// Loads metadata for all existing recordings.
  /// Returns [Right(List<AudioRecord>)] on success, or a [Failure] on the Left.
  Future<Either<Failure, List<AudioRecord>>> loadRecordings();

  /// Appends the currently stopped recording segment to an existing recording file.
}
