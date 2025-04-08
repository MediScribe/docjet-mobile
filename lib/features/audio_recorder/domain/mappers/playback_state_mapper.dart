import 'dart:async';

import 'package:audioplayers/audioplayers.dart'; // Import for PlayerState
import 'package:docjet_mobile/features/audio_recorder/domain/entities/playback_state.dart';

/// Interface for a mapper that transforms raw audio player streams into a unified
/// [PlaybackState] stream.
abstract class PlaybackStateMapper {
  /// The unified stream of playback states.
  Stream<PlaybackState> get playbackStateStream;

  /// Initializes the mapper, potentially setting up stream subscriptions.
  /// Takes the adapter streams as input.
  /// Note: The exact mechanism (constructor injection vs. init method) is an
  /// implementation detail, but the interface signals the need for input streams.
  void initialize({
    required Stream<Duration> positionStream,
    required Stream<Duration> durationStream,
    required Stream<void> completeStream,
    required Stream<PlayerState>
    playerStateStream, // Assuming PlayerState is from audioplayers
    // Add error stream input if needed later
  });

  /// Cleans up resources, like stream subscriptions.
  void dispose();
}
