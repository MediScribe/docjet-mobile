import 'package:audioplayers/audioplayers.dart';

/// Abstract interface for interacting with an audio player.
/// This isolates the application logic from the specific audio player implementation.
abstract class AudioPlayerAdapter {
  /// Plays the audio from the specified [url].
  /// Assumes `setSourceUrl` has been called previously or handles source setting internally.
  Future<void> play(
    String url,
  ); // Note: Test plan mentions testing play() delegation. Let's keep it.

  /// Sets the audio source to the given [url].
  Future<void> setSourceUrl(String url);

  /// Pauses the currently playing audio.
  Future<void> pause();

  /// Resumes the paused audio.
  Future<void> resume();

  /// Seeks to the specified [position] in the audio.
  Future<void> seek(Duration position);

  /// Stops the currently playing audio.
  Future<void> stop();

  /// Releases resources associated with the audio player.
  Future<void> dispose();

  /// Stream of player state changes.
  Stream<PlayerState> get onPlayerStateChanged;

  /// Stream of audio duration changes.
  Stream<Duration> get onDurationChanged;

  /// Stream of audio position changes.
  Stream<Duration> get onPositionChanged;

  /// Stream indicating playback completion.
  Stream<void> get onPlayerComplete;
}
