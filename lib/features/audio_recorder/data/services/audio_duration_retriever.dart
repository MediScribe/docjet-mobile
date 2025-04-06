import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';

/// Abstract contract for retrieving the duration of an audio file.
abstract class AudioDurationRetriever {
  /// Retrieves the duration for the audio file at the given [filePath].
  ///
  /// Throws specific exceptions (e.g., [AudioPlayerException],
  /// [RecordingFileNotFoundException]) if the file doesn't exist or the duration cannot be determined.
  Future<Duration> getDuration(String filePath);
}
