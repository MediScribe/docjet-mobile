// import 'package:audioplayers/audioplayers.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // ADDED
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';

/// Factory for creating fully configured [AudioPlaybackService] instances.
///
/// This factory encapsulates the creation and wiring of all dependencies required
/// by the audio playback service, ensuring proper initialization and configuration.
class AudioPlaybackServiceFactory {
  /// Creates a new instance of [AudioPlaybackService] with all dependencies
  /// properly configured.
  ///
  /// Returns a ready-to-use service that adheres to the AudioPlaybackService interface.
  static AudioPlaybackService create() {
    // Create the actual AudioPlayer instance from just_audio
    final audioPlayer = AudioPlayer(); // Now refers to just_audio.AudioPlayer

    // Create and configure the adapter
    final adapter = AudioPlayerAdapterImpl(audioPlayer);

    // Create the mapper
    final mapper = PlaybackStateMapperImpl();

    // Create the service with all dependencies injected
    return AudioPlaybackServiceImpl(
      audioPlayerAdapter: adapter,
      playbackStateMapper: mapper,
    );
  }
}
