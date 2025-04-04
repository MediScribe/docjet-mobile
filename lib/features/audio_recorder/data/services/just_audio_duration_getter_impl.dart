import 'package:just_audio/just_audio.dart';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';

import 'audio_duration_getter.dart';

/// Implementation of [AudioDurationGetter] using the `just_audio` package.
class JustAudioDurationGetterImpl implements AudioDurationGetter {
  final FileSystem fileSystem; // Inject FileSystem to check existence

  JustAudioDurationGetterImpl({required this.fileSystem});

  @override
  Future<Duration> getDuration(String filePath) async {
    final player = AudioPlayer(); // Create player instance locally
    try {
      // Check file existence first using injected FileSystem
      if (!await fileSystem.fileExists(filePath)) {
        throw RecordingFileNotFoundException(
          'Audio file not found at $filePath for getting duration.',
        );
      }

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
      if (e is RecordingFileNotFoundException || e is AudioPlayerException) {
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
