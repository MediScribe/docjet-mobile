// Import math for pow function - used by the retry calculation in HiveJobLocalDataSourceImpl
// but kept here for consistency with the refactoring plan

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import LoggerFactory
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart'; // Import config
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart'; // Import the processor
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart'; // Import Job entity
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:mutex/mutex.dart'; // Import Mutex

/// Service class for orchestrating job synchronization with remote server
class JobSyncOrchestratorService {
  final JobLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final JobSyncProcessorService _processorService; // Inject processor
  final Logger _logger = LoggerFactory.getLogger(
    JobSyncOrchestratorService,
  ); // Use LoggerFactory
  final Mutex _syncMutex = Mutex(); // Add mutex for sync control

  JobSyncOrchestratorService({
    required JobLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
    required JobSyncProcessorService
    processorService, // Add processor dependency
  }) : _localDataSource = localDataSource,
       _networkInfo = networkInfo,
       _processorService = processorService; // Assign processor

  // This function is used only for satisfying the linter regarding dart:math import
  // Required by the refactoring plan for calculating exponential backoff in tests
  // and logging the schedule, but the actual backoff delay check happens
  // in the local data source's getJobsToRetry method.
  // REMOVED - This logic is not needed in the orchestrator.
  // int _calculateExponentialBackoff(int retryCount, int baseSeconds) {
  //   return (baseSeconds * math.pow(2, retryCount)).toInt();
  // }

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
        // Return success (Right) because skipping due to offline is expected
        return const Right(unit);
      }

      List<Job> pendingJobs = [];
      List<Job> deletionJobs = [];
      List<Job> retryJobs = [];

      // Inner try-catch specifically for data source fetching
      try {
        _logger.d('Fetching jobs pending sync...');
        pendingJobs = await _localDataSource.getJobsByStatus(
          SyncStatus.pending,
        );
        _logger.d('Found ${pendingJobs.length} jobs pending create/update.');

        _logger.d('Fetching jobs pending deletion...');
        deletionJobs = await _localDataSource.getJobsByStatus(
          SyncStatus.pendingDeletion,
        );
        _logger.d('Found ${deletionJobs.length} jobs pending deletion.');

        _logger.d('Fetching jobs eligible for retry...');
        retryJobs = await _localDataSource.getJobsToRetry(
          maxRetryAttempts,
          retryBackoffBase,
        );
        _logger.d('Found ${retryJobs.length} jobs eligible for retry.');
      } on CacheException catch (e) {
        // Log the fetch error, but allow the orchestrator to continue
        // It might still be able to process other job types fetched successfully
        _logger.e('Cache error during job fetching phase: $e');
        // Do NOT return Left(...) here. Allow processing of any successfully fetched jobs.
      }

      // Log the retry backoff schedule for monitoring purposes
      if (retryJobs.isNotEmpty) {
        // REMOVED - No longer calculating backoff here. Logging simple count instead.
        // final retrySchedule = List.generate(
        //       maxRetryAttempts,
        //       (index) => index,
        //     ) // Generate attempts 0 to max-1
        //     .map(
        //       (attempt) => _calculateExponentialBackoff(
        //         attempt, // Use the actual attempt number for calculation
        //         retryBackoffBase.inSeconds,
        //       ),
        //     )
        //     .join(', ');
        _logger.d(
          // 'Retry backoff schedule (seconds for attempts 0-${maxRetryAttempts - 1}): $retrySchedule',
          'Found ${retryJobs.length} jobs to retry (backoff logic handled by LocalDataSource).',
        );
      }

      // ** Combine pending and retry jobs for syncSingleJob processing **
      final jobsToSync = [...pendingJobs, ...retryJobs];
      _logger.d(
        'Total jobs to attempt sync (pending + retry): ${jobsToSync.length}',
      );

      // Process creates/updates/retries using the processor
      for (final job in jobsToSync) {
        _logger.i(
          'Orchestrating sync for job (localId: ${job.localId}, status: ${job.syncStatus})...',
        );
        // Call the processor service
        await _processorService.processJobSync(job);
      }

      // Process deletions using the processor
      for (final job in deletionJobs) {
        _logger.i(
          'Orchestrating deletion for job (localId: ${job.localId}, serverId: ${job.serverId})...',
        );
        // Call the processor service
        await _processorService.processJobDeletion(job);
      }

      _logger.i('syncPendingJobs completed successfully inside lock.');
      return const Right(unit);
    } on ServerException catch (e) {
      // This might still happen if network check fails, but less likely for job-specific errors now
      _logger.e('Server error during sync orchestration: $e');
      return Left(ServerFailure(message: e.message ?? 'Unknown server error'));
    } catch (e) {
      _logger.e('Unexpected error during sync orchestration: $e');
      return Left(ServerFailure(message: 'Unexpected error during sync: $e'));
    } finally {
      _syncMutex.release();
      _logger.i('Released sync lock.');
    }
  }

  /// Resets a job stuck in the [SyncStatus.failed] state back to [SyncStatus.pending].
  ///
  /// If the job is found and is in the failed state, its status is updated to pending,
  /// the retry count is reset to 0, and the last sync attempt timestamp is cleared.
  /// If the job is not found or not in the failed state, it does nothing.
  /// Returns [Right(unit)] on success (including cases where no action was needed)
  /// or [Left(Failure)] if a cache error occurs during fetching or saving.
  Future<Either<Failure, Unit>> resetFailedJob({
    required String localId,
  }) async {
    _logger.i('Attempting to reset job with localId: $localId');
    try {
      Job job;
      try {
        job = await _localDataSource.getJobById(localId);
        _logger.d('Found job: ${job.localId}, syncStatus: ${job.syncStatus}');
      } on CacheException catch (e) {
        // If the job is not found, it's not an error for the reset operation.
        // Log it and return success (Right(unit)).
        _logger.w('Job with localId $localId not found in cache: $e');
        return const Right(unit);
      }

      // Only proceed if the job is actually in the failed state
      if (job.syncStatus == SyncStatus.failed) {
        _logger.i(
          'Job ${job.localId} is in failed state. Proceeding with reset.',
        );
        final updatedJob = job.copyWith(
          syncStatus: SyncStatus.pending,
          retryCount: 0,
          setLastSyncAttemptAtToNull: true,
        );

        await _localDataSource.saveJob(updatedJob);
        _logger.i(
          'Successfully reset job ${updatedJob.localId} to pending state.',
        );
        return const Right(unit);
      } else {
        _logger.i(
          'Job ${job.localId} is not in failed state (${job.syncStatus}). No action taken.',
        );
        return const Right(unit); // No action needed, still considered success
      }
    } on CacheException catch (e) {
      // This catches errors during the saveJob call
      _logger.e(
        'Cache error during resetFailedJob (save operation) for $localId: $e',
      );
      return Left(
        CacheFailure(e.message ?? 'Failed to save updated job during reset'),
      );
    } catch (e) {
      // Catch any other unexpected errors
      _logger.e('Unexpected error during resetFailedJob for $localId: $e');
      return Left(CacheFailure('Unexpected error resetting job: $e'));
    }
  }
}
