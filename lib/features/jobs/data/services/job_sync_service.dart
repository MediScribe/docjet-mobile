import 'package:dartz/dartz.dart';
// Import math for pow function - used by the retry calculation in HiveJobLocalDataSourceImpl
// but kept here for consistency with the refactoring plan
import 'dart:math' as math;
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:mutex/mutex.dart'; // Import Mutex
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart'; // Import config
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import LoggerFactory

/// Service class for job synchronization with remote server
class JobSyncService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final FileSystem _fileSystem;
  final Logger _logger = LoggerFactory.getLogger(
    JobSyncService,
  ); // Use LoggerFactory
  final Mutex _syncMutex = Mutex(); // Add mutex for sync control

  JobSyncService({
    required JobLocalDataSource localDataSource,
    required JobRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required FileSystem fileSystem,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo,
       _fileSystem = fileSystem;

  // This function is used only for satisfying the linter regarding dart:math import
  // Required by the refactoring plan for calculating exponential backoff in tests
  // and logging the schedule, but the actual backoff delay check happens
  // in the local data source's getJobsToRetry method.
  int _calculateExponentialBackoff(int retryCount, int baseSeconds) {
    return (baseSeconds * math.pow(2, retryCount)).toInt();
  }

  Future<Either<Failure, Unit>> syncPendingJobs() async {
    _logger.i('Attempting to start syncPendingJobs...');

    // Prevent concurrent execution
    if (_syncMutex.isLocked) {
      _logger.i('Sync already in progress. Skipping this run.');
      return const Right(unit);
    }

    await _syncMutex.acquire();
    _logger.i('Acquired sync lock. Starting sync process.');

    try {
      if (!await _networkInfo.isConnected) {
        _logger.w('Network offline, skipping sync.');
        return Left(ServerFailure(message: 'No internet connection'));
      }

      _logger.d('Fetching jobs pending sync...');
      final pendingJobs = await _localDataSource.getJobsByStatus(
        SyncStatus.pending,
      );
      _logger.d('Found ${pendingJobs.length} jobs pending create/update.');

      _logger.d('Fetching jobs pending deletion...');
      final deletionJobs = await _localDataSource.getJobsByStatus(
        SyncStatus.pendingDeletion,
      );
      _logger.d('Found ${deletionJobs.length} jobs pending deletion.');

      // ** Fetch jobs eligible for retry **
      // We fetch jobs that previously failed (status=error),
      // haven't exhausted their retries, and whose last attempt
      // was long enough ago based on an exponential backoff strategy.
      // The backoff logic (time check) is handled within the local data source.
      _logger.d('Fetching jobs eligible for retry...');
      final retryJobs = await _localDataSource.getJobsToRetry(
        maxRetryAttempts, // Use config constant
        retryBackoffBase, // Use config constant
      );
      _logger.d('Found ${retryJobs.length} jobs eligible for retry.');

      // Log the retry backoff schedule for monitoring purposes
      if (retryJobs.isNotEmpty) {
        final retrySchedule = List.generate(
              maxRetryAttempts,
              (index) => index,
            ) // Generate attempts 0 to max-1
            .map(
              (attempt) => _calculateExponentialBackoff(
                attempt, // Use the actual attempt number for calculation
                retryBackoffBase.inSeconds,
              ),
            )
            .join(', ');
        _logger.d(
          'Retry backoff schedule (seconds for attempts 0-${maxRetryAttempts - 1}): $retrySchedule',
        );
      }

      // ** Combine pending and retry jobs for syncSingleJob processing **
      final jobsToSync = [...pendingJobs, ...retryJobs];
      _logger.d(
        'Total jobs to attempt sync (pending + retry): ${jobsToSync.length}',
      );

      // Process creates/updates/retries
      for (final job in jobsToSync) {
        // Iterate over combined list
        _logger.i(
          'Syncing job (localId: ${job.localId}, status: ${job.syncStatus})...',
        );
        // syncSingleJob now handles error state updates internally
        await syncSingleJob(job);
      }

      // Process deletions
      for (final job in deletionJobs) {
        _logger.i(
          'Processing deletion for job (localId: ${job.localId}, serverId: ${job.serverId})...',
        );
        bool remoteDeleteSuccess = false;
        if (job.serverId != null) {
          try {
            _logger.d('Deleting job on server (serverId: ${job.serverId})...');
            await _remoteDataSource.deleteJob(job.serverId!);
            _logger.i(
              'Successfully deleted job on server (serverId: ${job.serverId}).',
            );
            remoteDeleteSuccess = true;
          } catch (e) {
            _logger.e(
              'Failed to delete job on server (serverId: ${job.serverId}): $e. Marking for retry or failure.',
            );
            // ** Error Handling for Deletion **
            // If remote deletion fails, we use the same error handling logic
            // as create/update failures. The job's status will be set to
            // SyncStatus.error (or SyncStatus.failed if max retries reached),
            // its retryCount incremented, and lastSyncAttemptAt updated.
            // It will be picked up again in a future sync cycle by getJobsToRetry.
            await _handleSyncError(
              job,
              e is Exception ? e : Exception(e.toString()),
              'Remote delete failure',
            );
            // remoteDeleteSuccess remains false
          }
        }

        // ** Only permanently delete if remote delete succeeded OR job was never on server **
        if (remoteDeleteSuccess || job.serverId == null) {
          _logger.d(
            'Proceeding with permanent local deletion for ${job.localId}.',
          );
          await _permanentlyDeleteJob(job.localId);
        } else {
          _logger.w(
            'Skipping permanent local deletion for ${job.localId} due to remote failure.',
          );
        }
      }

      _logger.i('syncPendingJobs completed successfully inside lock.');
      return const Right(unit);
    } on CacheException catch (e) {
      _logger.e('Cache error during sync: $e');
      return Left(CacheFailure(e.message ?? 'Unknown cache error'));
    } on ServerException catch (e) {
      _logger.e('Server error during sync: $e');
      return Left(ServerFailure(message: e.message ?? 'Unknown server error'));
    } catch (e) {
      _logger.e('Unexpected error during sync: $e');
      return Left(ServerFailure(message: 'Unexpected error during sync: $e'));
    } finally {
      _syncMutex.release();
      _logger.i('Released sync lock.');
    }
  }

  // Helper method to handle sync errors consistently
  // This is called whenever a remote operation (create, update, delete) fails.
  // It updates the job's local state to track the failure and prepare for retry.
  Future<void> _handleSyncError(
    // Takes the job, the exception, and a context string for logging.
    Job job,
    Exception error,
    String context,
  ) async {
    _logger.e(
      '$context for localId: ${job.localId} (attempt ${job.retryCount + 1}/$maxRetryAttempts): $error',
    );

    // Increment retry count.
    final newRetryCount = job.retryCount + 1;
    // Determine new status: 'failed' if max retries reached, otherwise back to 'error'.
    // Jobs in the 'error' state are eligible for retry based on the exponential
    // backoff strategy checked by `getJobsToRetry`.
    // Jobs in the 'failed' state will no longer be automatically retried.
    final newStatus =
        newRetryCount >= maxRetryAttempts
            ? SyncStatus.failed
            : SyncStatus.error;
    // Update the job locally with the new status, retry count, and timestamp.
    // The `lastSyncAttemptAt` timestamp is crucial for the backoff calculation.
    final updatedJob = job.copyWith(
      syncStatus: newStatus,
      retryCount: newRetryCount,
      lastSyncAttemptAt: DateTime.now(),
    );

    try {
      await _localDataSource.saveJob(updatedJob);
      _logger.i(
        'Updated job ${job.localId} status to $newStatus after $context.',
      );
    } catch (saveError) {
      _logger.e(
        'CRITICAL: Failed to save job ${job.localId} with status $newStatus after $context: $saveError',
      );
      // Rethrow or handle appropriately if saving the error state is critical
      // Rethrow the CacheException so the caller knows the state update failed.
      if (saveError is CacheException) {
        throw saveError;
      }
      // Optionally, wrap other errors if needed, but CacheException is the focus.
      throw CacheException(
        'Failed to save error state for job ${job.localId} after $context',
      );
    }
  }

  Future<Either<Failure, Job>> syncSingleJob(Job job) async {
    try {
      Job remoteJob;
      if (job.serverId == null) {
        // CREATE Logic
        _logger.d(
          'Calling remoteDataSource.createJob for localId: ${job.localId}',
        );
        if (job.audioFilePath == null || job.audioFilePath!.isEmpty) {
          _logger.e(
            'Cannot create job without audio file path (localId: ${job.localId})',
          );
          // Don't update retry count for validation failure
          return Left(ValidationFailure('Audio file path is required'));
        }
        remoteJob = await _remoteDataSource.createJob(
          userId: job.userId,
          audioFilePath: job.audioFilePath!,
          text: job.text,
          additionalText: job.additionalText,
        );
        _logger.d('Remote create successful. Saving synced job locally.');
      } else {
        // UPDATE Logic
        _logger.d(
          'Calling remoteDataSource.updateJob for serverId: ${job.serverId}',
        );

        // TODO: Use JobUpdateData instead of raw map when available
        // Prepare the update payload. This should ideally be more structured.
        final updates = <String, dynamic>{
          'status': job.status.name,
          if (job.displayTitle != null) 'display_title': job.displayTitle,
          if (job.text != null) 'text': job.text,
          if (job.additionalText != null) 'additional_text': job.additionalText,
          // Note: Sync-related fields (retryCount, lastSyncAttemptAt, syncStatus)
          // are managed locally and are NOT sent in the update payload.
        };
        remoteJob = await _remoteDataSource.updateJob(
          jobId: job.serverId!,
          updates: updates,
        );
        _logger.d('Remote update successful. Saving synced job locally.');
      }

      // ** Success Path **
      // Update local job with server details (especially serverId if it was null)
      // and mark as synced. Reset retry count and timestamp upon success.
      final updatedJob = job.copyWith(
        serverId:
            remoteJob.serverId ??
            job.serverId, // Keep local if server didn't return one
        syncStatus: SyncStatus.synced,
        // ** CORRECTLY MERGE FIELDS FROM REMOTE JOB **
        // Overwrite local fields with the server's authoritative state if provided.
        // Keep original local data if remote data is null (shouldn't happen often).
        status: remoteJob.status, // Use status from remote job
        displayTitle: remoteJob.displayTitle ?? job.displayTitle,
        text: remoteJob.text ?? job.text,
        additionalText: remoteJob.additionalText ?? job.additionalText,
        // Use the server's updatedAt timestamp if available, otherwise keep local.
        // This assumes the server sends back an updatedAt timestamp.
        // If remoteJob doesn't have updatedAt, we should perhaps use DateTime.now().
        // Let's assume for now remoteJob always provides it after a successful sync.
        updatedAt: remoteJob.updatedAt,

        // Crucially, reset retry state on successful sync.
        retryCount: 0,
        lastSyncAttemptAt: null,
      );

      await _localDataSource.saveJob(updatedJob);
      _logger.i('Successfully synced and saved job ${updatedJob.localId}');
      return Right(updatedJob);
    } on CacheException catch (e) {
      // If saving the successfully synced job locally fails, it's a local cache issue.
      // Do NOT treat this as a remote failure (don't call _handleSyncError).
      _logger.e('Cache error saving synced job ${job.localId} locally: $e');
      return Left(
        CacheFailure(e.message ?? 'Local cache error saving synced job'),
      );
    } catch (e) {
      // ** Failure Path for Remote Operations **
      // Use the helper method to handle the error, update local state,
      // and prepare for potential retry ONLY for remote errors.
      final errorException = e is Exception ? e : Exception(e.toString());
      try {
        await _handleSyncError(
          job,
          errorException,
          job.serverId == null
              ? 'Remote create failure'
              : 'Remote update failure',
        );
      } on CacheException catch (cacheError) {
        // If _handleSyncError itself failed to save the error state, return CacheFailure
        _logger.e(
          'CacheException occurred while trying to save error state for job ${job.localId}: $cacheError',
        );
        return Left(
          CacheFailure(cacheError.message ?? 'Failed to save error state'),
        );
      }

      // If _handleSyncError succeeded, construct the original ServerFailure message
      final bool maxRetriesReached = job.retryCount + 1 >= maxRetryAttempts;
      final String retryContext =
          maxRetriesReached ? 'after max retries' : '(retries remain)';
      final failureMessage =
          'Failed to sync job ${job.localId} $retryContext: $errorException';

      // Return a failure, indicating this specific job sync failed.
      // The overall syncPendingJobs process will still complete.
      return Left(ServerFailure(message: failureMessage));
    }
  }

  // Internal helper method to delete job permanently
  Future<void> _permanentlyDeleteJob(String localId) async {
    _logger.i(
      'Attempting permanent local deletion for job (localId: $localId)...',
    );
    try {
      // Fetch first to get audio file path before deleting
      final job = await _localDataSource.getJobById(localId);
      _logger.d('Found job locally, proceeding with deletion.');

      // Delete from local storage
      await _localDataSource.deleteJob(localId);
      _logger.i('Successfully deleted job from local DB (localId: $localId).');

      // Delete associated audio file if it exists
      if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
        try {
          _logger.d('Deleting audio file: ${job.audioFilePath}');
          await _fileSystem.deleteFile(job.audioFilePath!);
          _logger.i('Successfully deleted audio file: ${job.audioFilePath}.');
        } catch (e) {
          _logger.w(
            'Failed to delete audio file (${job.audioFilePath}) for job $localId: $e. This is non-critical.',
          );
          // Log but don't fail the overall operation
        }
      } else {
        _logger.d(
          'No audio file path found for job $localId, skipping file deletion.',
        );
      }
    } on CacheException catch (e) {
      _logger.w(
        'CacheException during permanent deletion attempt for job $localId (Might be already deleted?): $e',
      );
    } catch (e) {
      _logger.e(
        'Error during permanent local deletion for job $localId: $e. Sync cycle continues.',
      );
    }
  }
}
