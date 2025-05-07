/// A facade that provides a unified interface to the audio recorder and player services.
///
/// This provides a single entry point for audio functionality and helps abstract the
/// complexities of the underlying services. May be simplified or removed in future cycles
/// if the AudioCubit provides sufficient abstraction on its own.
abstract class AudioFacade {
  /// A stream that emits the current elapsed recording time.
  ///
  /// This stream MUST be a broadcast stream so multiple listeners can subscribe without throwing.
  Stream<Duration> get recordingElapsed$;

  /// A stream that emits the current playback position.
  ///
  /// This stream MUST be a broadcast stream so multiple listeners can subscribe without throwing.
  Stream<Duration> get playbackPosition$;

  /// A stream that emits the total duration of the loaded audio.
  ///
  /// This stream MUST be a broadcast stream so multiple listeners can subscribe without throwing.
  Stream<Duration> get playbackDuration$;

  /// Starts recording audio.
  Future<void> startRecording();

  /// Pauses the current recording.
  Future<void> pauseRecording();

  /// Resumes recording after it has been paused.
  Future<void> resumeRecording();

  /// Stops the current recording.
  ///
  /// Returns a [Future] that completes with the absolute path to the
  /// recorded audio file.
  Future<String> stopRecording();

  /// Loads an audio file for playback.
  ///
  /// [filePath] The path to the audio file.
  Future<void> loadAudio(String filePath);

  /// Starts or resumes playback of the loaded audio.
  Future<void> playAudio();

  /// Pauses playback of the loaded audio.
  Future<void> pauseAudio();

  /// Seeks to a specific position in the audio.
  ///
  /// [position] The position to seek to.
  Future<void> seekAudio(Duration position);

  /// Disposes of any resources used by this facade.
  ///
  /// This method is async to allow proper cleanup of any underlying resources.
  Future<void> dispose();
}
