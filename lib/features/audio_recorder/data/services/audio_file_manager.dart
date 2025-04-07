import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

/// Abstract contract for managing audio recording files on the file system.
///
/// Responsibilities include listing existing recordings with details and deleting them.
abstract class AudioFileManager {
  /// Lists the file paths of all recordings (e.g., .m4a files) in the designated directory.
  ///
  /// Throws [AudioFileSystemException] if listing fails.
  Future<List<String>> listRecordingPaths();

  /// Deletes the specified recording file.
  ///
  /// Throws [RecordingFileNotFoundException] if the file doesn't exist.
  /// Throws [AudioFileSystemException] for other deletion errors.
  Future<void> deleteRecording(String filePath);

  /// Retrieves metadata details for a specific recording file.
  /// Deprecated: Use direct file path listing and separate duration retrieval if needed.
  Future<AudioRecord> getRecordingDetails(String filePath);
}
