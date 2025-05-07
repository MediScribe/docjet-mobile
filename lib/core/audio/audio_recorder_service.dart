/// Interface for the audio recorder service that handles recording audio
/// and provides information about the recording progress.
abstract class AudioRecorderService {
  /// A stream that emits the elapsed recording time.
  /// This stream should be throttled to emit at most every 250ms.
  ///
  /// This stream MUST be a broadcast stream so multiple listeners
  /// (Cubit, tests, widgets) can subscribe without throwing.
  Stream<Duration> get elapsed$;

  /// Starts recording audio.
  ///
  /// Returns a [Future] that completes when recording has started.
  Future<void> start();

  /// Pauses the current recording.
  ///
  /// Note: On iOS < 13, the pause operation is silently ignored, and this
  /// implementation must manually emit a paused state.
  ///
  /// Returns a [Future] that completes when recording has been paused.
  Future<void> pause();

  /// Resumes recording after it has been paused.
  ///
  /// Returns a [Future] that completes when recording has been resumed.
  Future<void> resume();

  /// Stops the current recording.
  ///
  /// Returns a [Future] that completes with the absolute path to the
  /// recorded audio file.
  Future<String> stop();

  /// Disposes of any resources used by this service.
  ///
  /// This method is async to allow proper cleanup of any underlying resources.
  Future<void> dispose();
}
