import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';

/// Abstract interface for getting audio duration.
/// This allows decoupling the DataSource from specific audio player implementations.
abstract class AudioDurationGetter {
  /// Gets the duration of the audio file at the specified [filePath].
  ///
  /// Throws [RecordingFileNotFoundException] if the file doesn't exist.
  /// Throws [AudioPlayerException] if the duration cannot be determined
  /// (e.g., invalid file format, player error).
  Future<Duration> getDuration(String filePath);
}
