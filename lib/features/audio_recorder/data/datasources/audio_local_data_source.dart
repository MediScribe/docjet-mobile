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

  /// Concatenates the `newSegmentPath` onto the `originalFilePath`.
  ///
  /// Returns the path to the final concatenated file.
  /// This requires a robust implementation (e.g., ffmpeg).
  Future<String> concatenateRecordings(
    String originalFilePath,
    String newSegmentPath,
  );

  /// Gets the duration of an audio file.
  Future<Duration> getAudioDuration(String filePath);

  /// Lists all relevant audio files from the storage directory.
  /// Returns a list of file paths.
  Future<List<String>> listRecordingFiles();
}
