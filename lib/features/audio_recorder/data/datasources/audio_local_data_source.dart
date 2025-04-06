/// Abstract contract for low-level audio operations (permissions, file system, recording package).
///
/// Methods in the implementation should throw specific exceptions on failure,
/// which the Repository implementation will catch and convert to [Failure] types.
abstract class AudioLocalDataSource {
  /// Checks permission status directly using the required package(s).
  Future<bool> checkPermission();

  /// Requests permission using the required package(s).
  Future<bool> requestPermission();

  /// Starts a new audio recording.
  ///
  /// Returns the file path where the recording is being saved.
  /// Throws [AudioPermissionException] if microphone permission is denied.
  /// Throws [AudioRecordingException] if starting fails for other reasons.
  Future<String> startRecording();

  /// Stops the current audio recording.
  ///
  /// [recordingPath]: The path of the recording to stop, typically obtained from [startRecording].
  /// Returns the final file path of the saved recording.
  /// Throws [NoActiveRecordingException] if called when not recording (logically, though state is external now).
  /// Throws [RecordingFileNotFoundException] if the file is missing after stop.
  /// Throws [AudioRecordingException] if stopping fails.
  Future<String> stopRecording({required String recordingPath});

  /// Pauses the current audio recording.
  ///
  /// [recordingPath]: The path of the recording to pause.
  /// Throws [NoActiveRecordingException] if called when not recording (logically).
  /// Throws [AudioRecordingException] if pausing fails.
  Future<void> pauseRecording({required String recordingPath});

  /// Resumes a paused audio recording.
  ///
  /// [recordingPath]: The path of the recording to resume.
  /// Throws [NoActiveRecordingException] if called when not recording (logically).
  /// Throws [AudioRecordingException] if resuming fails.
  Future<void> resumeRecording({required String recordingPath});

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
  // Future<List<AudioRecord>> listRecordingDetails();

  // @visibleForTesting
  // void testingSetCurrentRecordingPath(String? path);
}
