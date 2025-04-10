import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';
import 'package:logger/logger.dart';

final logger = Logger();

/// Concrete implementation for merging local and remote transcription data.
class TranscriptionMergeServiceImpl implements TranscriptionMergeService {
  @override
  List<Transcription> mergeJobs(
    List<Transcription> remoteJobs,
    List<LocalJob> localJobs,
  ) {
    logger.d(
      '[MergeService] Starting merge. Remote: ${remoteJobs.length}, Local: ${localJobs.length}',
    );
    final Map<String, Transcription> remoteJobsMap = {
      for (var job in remoteJobs)
        if (job.id != null) job.id!: job,
    };
    final List<Transcription> mergedList = [];
    final Set<String> processedLocalPaths = {};

    // Process remote jobs first
    for (final remoteJob in remoteJobs) {
      final backendId = remoteJob.id;
      if (backendId == null) {
        logger.w(
          '[MergeService] Remote job missing backendId (id field), skipping.',
          error: remoteJob,
        );
        continue; // Should ideally not happen
      }

      // Find corresponding local job(s) by backendId
      final matchingLocalJobs =
          localJobs.where((local) => local.backendId == backendId).toList();

      if (matchingLocalJobs.isNotEmpty) {
        if (matchingLocalJobs.length > 1) {
          logger.w(
            '[MergeService] Multiple local jobs found for backendId $backendId. Using the first one.',
          );
        }
        final localJob = matchingLocalJobs.first;
        // Merge: Remote data is primary source of truth for synced jobs
        mergedList.add(
          remoteJob.copyWith(
            localFilePath: localJob.localFilePath, // Keep local path
            localCreatedAt: localJob.localCreatedAt,
            localDurationMillis: localJob.durationMillis,
          ),
        );
        logger.d(
          '[MergeService] Merged synced job (Remote primary): ${localJob.localFilePath}',
        );
        processedLocalPaths.add(localJob.localFilePath);
      } else {
        // Remote job exists, but no matching local job found (e.g., created on web)
        mergedList.add(remoteJob); // Add remote job as is
        logger.w(
          '[MergeService] Backend job ID $backendId not found in local store. Adding with limited local context.',
        );
      }
    }

    // Add local-only jobs (or jobs whose backendId wasn't in remote list)
    for (final localJob in localJobs) {
      if (!processedLocalPaths.contains(localJob.localFilePath)) {
        if (localJob.backendId != null &&
            !remoteJobsMap.containsKey(localJob.backendId)) {
          logger.w(
            '[MergeService] Local job has backendId (${localJob.backendId}) but was not found in remote fetch. Adding as local-only.',
          );
          // Treat as local-only for now, status likely needs update later
          mergedList.add(_createTranscriptionFromLocalJob(localJob));
        } else if (localJob.backendId == null) {
          // Truly local-only job
          mergedList.add(_createTranscriptionFromLocalJob(localJob));
          logger.d(
            '[MergeService] Adding local-only job: ${localJob.localFilePath}',
          );
        }
      }
    }

    // Sort by update/creation date, newest first
    // Prioritize backendUpdatedAt, fallback to localCreatedAt
    mergedList.sort((a, b) {
      final dateA = a.backendUpdatedAt ?? a.localCreatedAt ?? DateTime(0);
      final dateB = b.backendUpdatedAt ?? b.localCreatedAt ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    logger.d(
      '[MergeService] Merge complete. Result count: ${mergedList.length}',
    );
    return mergedList;
  }

  // Helper function to map LocalJob to Transcription (identical to old repo helper)
  Transcription _createTranscriptionFromLocalJob(LocalJob localJob) {
    return Transcription(
      id: localJob.backendId, // Map backendId to id
      localFilePath: localJob.localFilePath,
      status: localJob.status,
      localCreatedAt: localJob.localCreatedAt,
      localDurationMillis: localJob.durationMillis,
      // Other fields (displayTitle, displayText, etc.) will be null
    );
  }
}
