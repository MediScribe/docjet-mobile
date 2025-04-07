import 'dart:async';

import 'package:docjet_mobile/features/audio_recorder/domain/models/playback_state.dart';

/// Abstract interface for a service that handles audio playback logic.
abstract class AudioPlaybackService {
  /// Starts playing the audio file at the given [filePath].
  /// Stops any currently playing audio before starting the new one.
  Future<void> play(String filePath);

  /// Pauses the currently playing audio.
  Future<void> pause();

  /// Seeks to the specified [position] in the currently playing audio.
  Future<void> seek(Duration position);

  /// Stops the currently playing audio and resets the player state.
  Future<void> stop();

  /// Releases resources held by the service, like the audio player and stream controllers.
  /// Should be called when the service is no longer needed.
  Future<void> dispose();

  /// A stream that emits [PlaybackState] updates whenever the playback status changes
  /// (e.g., playing, paused, completed, error, position updates).
  Stream<PlaybackState> get playbackStateStream;
}
