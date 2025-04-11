/// Represents the possible states of the audio player from the domain's perspective,
/// independent of any specific player library implementation.
enum DomainPlayerState {
  /// The player is idle or hasn't been initialized with a source.
  initial,

  /// The player is actively loading the audio source.
  loading,

  /// The audio is currently playing.
  playing,

  /// The audio playback is paused.
  paused,

  /// The audio playback has been explicitly stopped.
  stopped,

  /// The audio playback has reached the end.
  completed,

  /// An error occurred during playback or loading.
  error,
}
