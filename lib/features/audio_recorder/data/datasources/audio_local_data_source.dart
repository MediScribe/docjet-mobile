import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

/// Abstract contract for low-level audio operations (permissions, file system, recording package).
///
/// Methods in the implementation should throw specific exceptions on failure,
/// which the Repository implementation will catch and convert to [Failure] types.
abstract class AudioLocalDataSource {
  /// Checks permission status directly using the required package(s).
  Future<bool> checkPermission();

  /// Requests permission using the required package(s).
  Future<bool> requestPermission();

  /// Starts recording to a temporary path.
  ///
  /// Returns the temporary file path.
  Future<String> startRecording();

  /// Stops the current recording.
  ///
  /// Returns the final file path of the stopped segment.
  Future<String> stopRecording();

  /// Pauses the current recording.
  Future<void> pauseRecording();

  /// Resumes a paused recording.
  Future<void> resumeRecording();

  /// Deletes the audio file at the given path.
  Future<void> deleteRecording(String filePath);

  /// Concatenates multiple audio recording files into a single new file.
  ///
  /// Takes a list of [inputFilePaths] to concatenate in the specified order.
  /// Returns the path to the newly created concatenated file.
  /// Throws [AudioConcatenationException] if concatenation fails.
  /// Throws [AudioFileSystemException] for underlying file system errors.
  /// Throws [ArgumentError] if [inputFilePaths] is empty or contains invalid paths.
  Future<String> concatenateRecordings(List<String> inputFilePaths);

  /// Retrieves details (path, duration, created date) for all relevant audio files.
  /// Returns a list of [AudioRecord] objects.
  /// Errors encountered while processing individual files should be handled
  /// internally (e.g., logged), and the method should return details for files
  /// that were processed successfully. If the directory cannot be accessed,
  /// it might throw an [AudioFileSystemException].
  Future<List<AudioRecord>> listRecordingDetails();

  // @visibleForTesting
  // void testingSetCurrentRecordingPath(String? path);
}
