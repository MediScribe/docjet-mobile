import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

/// Abstract contract for managing audio recording files on the file system.
///
/// Responsibilities include listing existing recordings with details and deleting them.
abstract class AudioFileManager {
  /// Retrieves details (path, duration, created date) for all relevant audio files.
  /// Returns a list of [AudioRecord] objects.
  /// Errors encountered while processing individual files should be handled
  /// internally (e.g., logged), and the method should return details for files
  /// that were processed successfully. If the directory cannot be accessed,
  /// it might throw an [AudioFileSystemException].
  Future<List<AudioRecord>> listRecordingDetails();

  /// Deletes a recording file.
  ///
  /// [filePath]: The path of the recording file to delete.
  /// Throws [RecordingFileNotFoundException] if the file is missing.
  /// Throws [AudioFileSystemException] for underlying file system errors.
  Future<void> deleteRecording(String filePath);
}
