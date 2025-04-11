import 'dart:async';

import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';

/// Abstract interface for a service that handles audio playback logic.
abstract class AudioPlaybackService {
  /// Starts playing the audio file at the given [filePath].
  /// Stops any currently playing audio before starting the new one.
  Future<void> play(String filePath);

  /// Pauses the currently playing audio.
  Future<void> pause();

  /// Resumes the paused audio.
  Future<void> resume();

  /// Seeks to the specified [position] in the audio file identified by [pathOrUrl].
  Future<void> seek(String pathOrUrl, Duration position);

  /// Stops the currently playing audio and releases some resources.
  Future<void> stop();

  /// Disposes of the service and releases all resources.
  Future<void> dispose();

  /// A stream that emits [PlaybackState] updates whenever the playback status changes
  /// (e.g., playing, paused, completed, error, position updates).
  Stream<PlaybackState> get playbackStateStream;
}
