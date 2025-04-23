import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// Service responsible for the low-level processing of syncing a single job
/// or handling a single deletion with the remote server and local state.
///
/// ## Thread Safety
/// This service interacts with the local file system, local database, and remote API.
/// It is designed for use within a single Dart isolate.
/// Concurrent access from multiple isolates is not guaranteed to be safe
/// without external synchronization mechanisms (like mutexes).
class JobSyncProcessorService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  final FileSystem _fileSystem;
  final Logger _logger = LoggerFactory.getLogger(JobSyncProcessorService);
  static final String _tag = logTag(JobSyncProcessorService);

  JobSyncProcessorService({
    required JobLocalDataSource localDataSource,
    required JobRemoteDataSource remoteDataSource,
    required FileSystem fileSystem,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _fileSystem = fileSystem;

  // Placeholder methods - implementation will be moved from JobSyncService

  /// Processes the synchronization (create or update) of a single job.
  Future<Either<Failure, Unit>> processJobSync(Job job) async {
    // Implementation moved from JobSyncService.syncSingleJob
    try {
      Job remoteJob;
      if (job.serverId == null) {
        // CREATE Logic
        _logger.d(
          '$_tag Calling remoteDataSource.createJob for localId: ${job.localId}',
        );
        if (job.audioFilePath == null || job.audioFilePath!.isEmpty) {
          _logger.e(
            '$_tag Cannot create job without audio file path (localId: ${job.localId})',
          );
          return Left(ValidationFailure('Audio file path is required'));
        }
        remoteJob = await _remoteDataSource.createJob(
          userId: job.userId,
          audioFilePath: job.audioFilePath!,
          text: job.text,
          additionalText: job.additionalText,
        );
        _logger.d('$_tag Remote create successful. Saving synced job locally.');
      } else {
        // UPDATE Logic
        _logger.d(
          '$_tag Calling remoteDataSource.updateJob for serverId: ${job.serverId}',
        );
        final updates = <String, dynamic>{
          'status': job.status.name,
          if (job.displayTitle != null) 'display_title': job.displayTitle,
          if (job.text != null) 'text': job.text,
          if (job.additionalText != null) 'additional_text': job.additionalText,
        };
        remoteJob = await _remoteDataSource.updateJob(
          jobId: job.serverId!,
          updates: updates,
        );
        _logger.d('$_tag Remote update successful. Saving synced job locally.');
      }

      // ADD LOGGING HERE
      _logger.d(
        '$_tag Original job state before final save: status=${job.syncStatus}, retryCount=${job.retryCount}, lastAttempt=${job.lastSyncAttemptAt}',
      );
      _logger.d(
        '$_tag Remote job state received: serverId=${remoteJob.serverId}, status=${remoteJob.status}, updatedAt=${remoteJob.updatedAt}',
      );

      final updatedJob = job.copyWith(
        serverId: remoteJob.serverId,
        syncStatus: SyncStatus.synced,
        status: remoteJob.status,
        displayTitle: remoteJob.displayTitle ?? job.displayTitle,
        text: remoteJob.text ?? job.text,
        additionalText: remoteJob.additionalText ?? job.additionalText,
        updatedAt: remoteJob.updatedAt,
        retryCount: 0, // Hard reset on success
        lastSyncAttemptAt: null,
        setLastSyncAttemptAtNull: true, // Explicitly use the flag to force null
      );

      // ADD LOGGING HERE
      _logger.d(
        '$_tag Job state being saved: status=${updatedJob.syncStatus}, retryCount=${updatedJob.retryCount}, lastAttempt=${updatedJob.lastSyncAttemptAt} (explicitly set to null)',
      );

      await _localDataSource.saveJob(updatedJob);
      _logger.i(
        '$_tag Successfully synced and saved job ${updatedJob.localId}',
      );
      return const Right(unit);
    } on CacheException catch (e) {
      _logger.e(
        '$_tag Cache error saving synced job ${job.localId} locally: $e',
      );
      return Left(
        CacheFailure(e.message ?? 'Local cache error saving synced job'),
      );
    } catch (e) {
      final errorException = e is Exception ? e : Exception(e.toString());
      return await _handleRemoteSyncFailure(job, errorException);
    }
  }

  /// Processes the deletion of a single job, including remote API call and local cleanup.
  Future<Either<Failure, Unit>> processJobDeletion(Job jobToDelete) async {
    // Implementation moved from JobSyncService._processSingleDeletion
    bool remoteDeleteSuccess = false;
    if (jobToDelete.serverId != null) {
      try {
        _logger.d(
          '$_tag Deleting job on server (serverId: ${jobToDelete.serverId})...',
        );
        await _remoteDataSource.deleteJob(jobToDelete.serverId!);
        _logger.i(
          '$_tag Successfully deleted job on server (serverId: ${jobToDelete.serverId}).',
        );
        remoteDeleteSuccess = true;
      } catch (e) {
        _logger.e(
          '$_tag Failed to delete job on server (serverId: ${jobToDelete.serverId}): $e. Marking for retry or failure.',
        );
        await _handleSyncError(
          jobToDelete,
          e is Exception ? e : Exception(e.toString()),
          'Remote delete failure',
        );
        // If remote delete fails, update local state and return Failure
        // Construct failure message based on retry status
        final bool maxRetriesReached =
            jobToDelete.retryCount + 1 >= maxRetryAttempts;
        final String retryContext =
            maxRetriesReached ? 'after max retries' : '(retries remain)';
        final failureMessage =
            'Failed to delete job ${jobToDelete.localId} on server $retryContext: $e';
        return Left(ServerFailure(message: failureMessage));
      }
    }

    // Proceed with local deletion if remote delete succeeded OR if the job was local-only
    if (remoteDeleteSuccess || jobToDelete.serverId == null) {
      _logger.d(
        '$_tag Proceeding with permanent local deletion for ${jobToDelete.localId}.',
      );
      // _permanentlyDeleteJob now returns Either<Failure, Unit>
      final localDeleteResult = await _permanentlyDeleteJob(
        jobToDelete.localId,
      );
      // Propagate the result (could be Left<CacheFailure> or Right(unit))
      return localDeleteResult;
    } else {
      // This case implies remote delete failed, and we already returned Left above.
      // Should technically not be reached, but return Left just in case.
      _logger.w(
        '$_tag Skipping permanent local deletion for ${jobToDelete.localId} due to remote failure. Returning Left.',
      );
      // We don't have the original exception here, create a generic one
      return Left(
        ServerFailure(
          message:
              'Skipped local delete for ${jobToDelete.localId} after remote failure',
        ),
      );
    }
  }

  /// Handles the logic when a remote API call (create/update) fails.
  Future<Either<Failure, Unit>> _handleRemoteSyncFailure(
    Job job,
    Exception error,
  ) async {
    // Implementation moved from JobSyncService._handleRemoteSyncFailure
    // Use the shared _handleSyncError helper to update local job state
    try {
      await _handleSyncError(
        job,
        error, // Use the passed error
        job.serverId == null
            ? 'Remote create failure'
            : 'Remote update failure',
      );
    } on CacheException catch (cacheError) {
      // If _handleSyncError itself failed to save the error state, return CacheFailure
      _logger.e(
        '$_tag CacheException occurred while trying to save error state for job ${job.localId}: $cacheError',
      );
      return Left(
        CacheFailure(cacheError.message ?? 'Failed to save error state'),
      );
    }

    // Construct the ServerFailure message for the caller (processJobSync)
    // Use the state *before* _handleSyncError was called for accurate context
    final bool maxRetriesReached = job.retryCount + 1 >= maxRetryAttempts;
    final String retryContext =
        maxRetriesReached ? 'after max retries' : '(retries remain)';
    final failureMessage =
        'Failed to sync job ${job.localId} $retryContext: $error'; // Use passed error

    // The method now returns Either<Failure, Unit>, so Left is correct.
    return Left(ServerFailure(message: failureMessage));
  }

  /// Helper method to handle sync errors consistently (create, update, delete).
  Future<void> _handleSyncError(
    Job job,
    Exception error,
    String context,
  ) async {
    // Implementation moved from JobSyncService._handleSyncError
    _logger.e(
      '$_tag $context for localId: ${job.localId} (attempt ${job.retryCount + 1}/$maxRetryAttempts): $error',
    );

    // Increment retry count.
    final newRetryCount = job.retryCount + 1;
    // Determine new status: 'failed' if max retries reached, otherwise back to 'error'.
    final newStatus =
        newRetryCount >= maxRetryAttempts
            ? SyncStatus.failed
            : SyncStatus.error;
    // Update the job locally with the new status, retry count, and timestamp.
    final updatedJob = job.copyWith(
      syncStatus: newStatus,
      retryCount: newRetryCount,
      lastSyncAttemptAt: DateTime.now(),
    );

    try {
      await _localDataSource.saveJob(updatedJob);
      _logger.i(
        '$_tag Updated job ${job.localId} status to $newStatus after $context.',
      );
    } catch (saveError) {
      _logger.e(
        '$_tag CRITICAL: Failed to save job ${job.localId} with status $newStatus after $context: $saveError',
      );
      if (saveError is CacheException) {
        rethrow;
      }
      throw CacheException(
        'Failed to save error state for job ${job.localId} after $context',
      );
    }
  }

  ///
  /// Handles the permanent deletion of a job locally after successful server deletion.
  ///
  /// Args:
  ///   `job`: The [Job] instance to delete locally.
  ///
  /// Returns:
  ///   A `Future<Either<Failure, Unit>>` that completes when the local deletion is done.
  ///
  /// Note:
  ///   This method assumes the job has already been successfully deleted from the server.
  ///   Any errors during local deletion are logged but not propagated, as the primary
  ///   goal (server deletion) was achieved. Consider implications if local state must
  ///   always be consistent.
  Future<Either<Failure, Unit>> _permanentlyDeleteJob(String localId) async {
    // Implementation moved from JobSyncService._permanentlyDeleteJob
    _logger.i(
      '$_tag Attempting permanent local deletion for job (localId: $localId)...',
    );
    Job job;
    try {
      // Fetch first to get audio file path before deleting
      job = await _localDataSource.getJobById(localId);
      _logger.d('$_tag Found job locally, proceeding with deletion.');
    } on CacheException catch (e) {
      _logger.w(
        '$_tag CacheException getting job $localId (Might be already deleted?): $e',
      );
      // If job not found, consider it successfully deleted.
      return const Right(unit);
    } catch (e) {
      _logger.e(
        '$_tag Unexpected error fetching job $localId details for deletion: $e',
      );
      // Treat unexpected fetch error as a failure to ensure consistency
      return Left(
        CacheFailure(
          'Unexpected error fetching job $localId details for deletion: $e',
        ),
      );
    }

    try {
      // Delete from local storage
      await _localDataSource.deleteJob(localId);
      _logger.i(
        '$_tag Successfully deleted job from local DB (localId: $localId).',
      );

      // Delete associated audio file if it exists (non-critical)
      if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
        try {
          _logger.d('$_tag Deleting audio file: ${job.audioFilePath}');
          await _fileSystem.deleteFile(job.audioFilePath!);
          _logger.i(
            '$_tag Successfully deleted audio file: ${job.audioFilePath}.',
          );
        } catch (e, stackTrace) {
          // Use standard logger now, removing dependency on JobSyncLogger
          _logger.e(
            '$_tag Failed to delete audio file during sync processing permanent deletion for job $localId',
            error: e,
            stackTrace: stackTrace,
          );
          // NOTE: No counter increment here like in JobDeleterService. This service handles sync confirmations.
          // The counter is incremented in JobDeleterService when deletion is user-initiated or fails during final cleanup.
        }
      } else {
        _logger.d(
          '$_tag No audio file path found for job $localId, skipping file deletion.',
        );
      }
      // DB deletion succeeded
      return const Right(unit);
    } on CacheException catch (e) {
      // This specifically catches DB deletion errors now
      _logger.e(
        '$_tag CacheException during DB delete operation for job $localId: $e',
      );
      return Left(CacheFailure('Failed to delete job $localId from DB: $e'));
    } catch (e) {
      // Catch any other unexpected error during delete
      _logger.e(
        '$_tag Unexpected error during permanent local deletion DB operation for job $localId: $e.',
      );
      return Left(
        CacheFailure('Unexpected error deleting job $localId from DB: $e'),
      );
    }
  }
}
