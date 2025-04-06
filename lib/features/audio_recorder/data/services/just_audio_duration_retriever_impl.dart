import 'package:just_audio/just_audio.dart';

import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';

import 'audio_duration_retriever.dart';

/// Implementation of [AudioDurationRetriever] using the `just_audio` package.
class JustAudioDurationRetrieverImpl implements AudioDurationRetriever {
  // No longer needs FileSystem, the caller (AudioFileManager) guarantees existence.

  // Allow injecting AudioPlayer for testing, default to a new instance.
  // Using a factory function type for easier mocking/provision.
  final AudioPlayer Function() _playerFactory;

  JustAudioDurationRetrieverImpl({
    AudioPlayer Function()? playerFactory, // Optional factory for testing
  }) : _playerFactory = playerFactory ?? (() => AudioPlayer());

  @override
  Future<Duration> getDuration(String filePath) async {
    final player = _playerFactory(); // Get player from factory
    try {
      // Try setting the file path and getting duration
      final duration = await player.setFilePath(filePath);
      if (duration == null) {
        throw AudioPlayerException(
          'Could not determine duration for file $filePath (possibly invalid/corrupt).',
        );
      }
      return duration;
    } on PlayerException catch (e) {
      // Catch specific player exceptions
      throw AudioPlayerException(
        'Failed to get audio duration for $filePath due to player error: ${e.message}',
        e,
      );
    } catch (e) {
      // Rethrow known exceptions or wrap unknown ones
      if (e is AudioPlayerException) {
        // RecordingFileNotFoundException is no longer thrown here
        rethrow;
      }
      throw AudioPlayerException(
        'An unexpected error occurred while getting duration for $filePath',
        e,
      );
    } finally {
      // Ensure player is always disposed
      await player.dispose();
    }
  }
}
