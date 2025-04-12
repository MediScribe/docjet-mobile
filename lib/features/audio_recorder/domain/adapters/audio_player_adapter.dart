import 'package:docjet_mobile/features/audio_recorder/domain/entities/domain_player_state.dart';

/// Abstract interface for interacting with an audio player.
/// This isolates the application logic from the specific audio player implementation.
abstract class AudioPlayerAdapter {
  /// Sets the audio source to the given [url].
  Future<void> setSourceUrl(String url);

  /// Pauses the currently playing audio.
  Future<void> pause();

  /// Resumes the paused audio.
  Future<void> resume();

  /// Seeks to the specified [position] in the audio file identified by [filePath].
  Future<void> seek(String filePath, Duration position);

  /// Stops the currently playing audio.
  Future<void> stop();

  /// Releases resources associated with the audio player.
  Future<void> dispose();

  /// Stream of player state changes using the domain-specific state.
  Stream<DomainPlayerState> get onPlayerStateChanged;

  /// Stream of audio duration changes.
  Stream<Duration> get onDurationChanged;

  /// Stream of audio position changes.
  Stream<Duration> get onPositionChanged;

  /// Stream indicating playback completion.
  Stream<void> get onPlayerComplete;
}
