/// Interface for the audio player service that handles playing audio
/// and provides information about the playback progress.
abstract class AudioPlayerService {
  /// A stream that emits the current playback position.
  /// This stream should be throttled to emit at most every 200ms.
  ///
  /// This stream MUST be a broadcast stream so multiple listeners
  /// (Cubit, tests, widgets) can subscribe without throwing.
  Stream<Duration> get position$;

  /// A stream that emits the total duration of the loaded audio.
  ///
  /// This stream MUST be a broadcast stream so multiple listeners
  /// can subscribe without throwing.
  Stream<Duration> get duration$;

  /// Loads an audio file from the given path.
  ///
  /// [filePath] The absolute or relative path to the audio file.
  ///
  /// Returns a [Future] that completes when the audio has been loaded.
  Future<void> load(String filePath);

  /// Starts or resumes playback of the loaded audio.
  ///
  /// Returns a [Future] that completes when playback has started.
  Future<void> play();

  /// Pauses playback of the loaded audio.
  ///
  /// Returns a [Future] that completes when playback has been paused.
  Future<void> pause();

  /// Seeks to a specific position in the audio.
  ///
  /// [position] The position to seek to.
  ///
  /// Returns a [Future] that completes when seeking is complete.
  Future<void> seek(Duration position);

  /// Resets the player state and releases resources for the current audio file.
  ///
  /// Returns a [Future] that completes when the player has been reset.
  Future<void> reset();

  /// Disposes of any resources used by this service.
  ///
  /// This method is async to allow proper cleanup of any underlying resources.
  Future<void> dispose();
}
