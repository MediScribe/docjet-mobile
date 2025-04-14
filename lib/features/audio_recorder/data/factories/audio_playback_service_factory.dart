// import 'package:audioplayers/audioplayers.dart'; // REMOVED
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:get_it/get_it.dart';

/// Helper to get the [AudioPlaybackService] from the dependency injection container.
///
/// This replaces the previous factory approach which created redundant instances.
class AudioPlaybackServiceProvider {
  /// Returns the singleton [AudioPlaybackService] instance from the DI container.
  ///
  /// This ensures we're using the properly wired instance with all dependencies.
  static AudioPlaybackService getService() {
    return GetIt.instance<AudioPlaybackService>();
  }
}
