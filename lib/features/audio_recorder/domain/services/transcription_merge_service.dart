import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';

/// Abstract contract for merging local job data with remote transcription data.
abstract class TranscriptionMergeService {
  /// Merges remote transcription data with local job data.
  ///
  /// Takes a list of [Transcription] objects (typically from a remote source)
  /// and a list of [LocalJob] objects (from local storage).
  ///
  /// Returns a sorted list of [Transcription] objects representing the merged view,
  /// prioritizing remote data for synced items where applicable. Sorting is typically
  /// by creation/update time, newest first.
  List<Transcription> mergeJobs(
    List<Transcription> remoteJobs,
    List<LocalJob> localJobs,
  );
}
