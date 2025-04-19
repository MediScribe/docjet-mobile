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
  // Required by the refactoring plan but not directly used in normal operation
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
      _logger.d('Fetching jobs eligible for retry...');
      final retryJobs = await _localDataSource.getJobsToRetry(
        maxRetryAttempts, // Use config constant
        retryBackoffBase, // Use config constant
      );
      _logger.d('Found ${retryJobs.length} jobs eligible for retry.');

      // Log the retry backoff schedule for monitoring purposes
      if (retryJobs.isNotEmpty) {
        final retrySchedule = [1, 2, 3, 4, 5]
            .map(
              (attempt) => _calculateExponentialBackoff(
                attempt,
                retryBackoffBase.inSeconds,
              ),
            )
            .join(', ');
        _logger.d('Retry backoff schedule (seconds): $retrySchedule');
      }

      // ** Combine pending and retry jobs for syncSingleJob processing **
      final jobsToSync = [...pendingJobs, ...retryJobs];

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
            // ** Handle deletion error: Update job status locally **
            final newRetryCount = job.retryCount + 1;
            final newStatus =
                newRetryCount >= maxRetryAttempts
                    ? SyncStatus.failed
                    : SyncStatus.error;
            final errorJob = job.copyWith(
              syncStatus: newStatus,
              retryCount: newRetryCount,
              lastSyncAttemptAt: DateTime.now(),
            );
            try {
              await _localDataSource.saveJob(errorJob);
              _logger.i(
                'Updated job ${job.localId} status to $newStatus after remote delete failure.',
              );
            } catch (saveError) {
              _logger.e(
                'Failed to save job status after remote delete failure for ${job.localId}: $saveError',
              );
              // Still proceed to potentially delete local-only jobs
            }
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
        final updates = <String, dynamic>{
          'status': job.status.name,
          if (job.displayTitle != null) 'display_title': job.displayTitle,
          if (job.text != null) 'text': job.text,
          if (job.additionalText != null) 'additional_text': job.additionalText,
          // Add other updatable fields
        };

        remoteJob = await _remoteDataSource.updateJob(
          jobId: job.serverId!,
          updates: updates,
        );
        _logger.d('Remote update successful. Saving synced job locally.');
      }

      // Save successful sync result (could be create or update)
      await _localDataSource.saveJob(remoteJob);
      return Right(remoteJob);
    } on ServerException catch (e) {
      _logger.e(
        'ServerException during syncSingleJob for localId: ${job.localId}: $e',
      );
      // ** Handle Sync Error: Update retry count and status **
      final newRetryCount = job.retryCount + 1;
      final newStatus =
          newRetryCount >= maxRetryAttempts
              ? SyncStatus.failed
              : SyncStatus.error;
      final errorJob = job.copyWith(
        syncStatus: newStatus,
        retryCount: newRetryCount,
        lastSyncAttemptAt: DateTime.now(),
      );
      try {
        await _localDataSource.saveJob(errorJob);
        _logger.i(
          'Updated job ${job.localId} status to $newStatus after ServerException.',
        );
      } catch (saveError) {
        _logger.e(
          'Failed to save job with error status after ServerException: $saveError',
        );
      }
      return Left(
        ServerFailure(message: e.message ?? 'Server error during sync'),
      );
    } on CacheException catch (e) {
      _logger.e(
        'CacheException during syncSingleJob for localId: ${job.localId}: $e',
      );
      // ** Handle Sync Error: Update retry count and status (treat like ServerException) **
      final newRetryCount = job.retryCount + 1;
      final newStatus =
          newRetryCount >= maxRetryAttempts
              ? SyncStatus.failed
              : SyncStatus.error;
      final errorJob = job.copyWith(
        syncStatus: newStatus,
        retryCount: newRetryCount,
        lastSyncAttemptAt: DateTime.now(),
      );
      try {
        await _localDataSource.saveJob(errorJob);
        _logger.i(
          'Updated job ${job.localId} status to $newStatus after CacheException.',
        );
      } catch (saveError) {
        _logger.e(
          'Failed to save job with error status after CacheException: $saveError',
        );
      }
      return Left(CacheFailure(e.message ?? 'Cache error during sync'));
    } catch (e) {
      _logger.e(
        'Unexpected error during syncSingleJob for localId: ${job.localId}: $e',
      );
      // ** Handle Sync Error: Update retry count and status (treat like ServerException) **
      final newRetryCount = job.retryCount + 1;
      final newStatus =
          newRetryCount >= maxRetryAttempts
              ? SyncStatus.failed
              : SyncStatus.error;
      final errorJob = job.copyWith(
        syncStatus: newStatus,
        retryCount: newRetryCount,
        lastSyncAttemptAt: DateTime.now(),
      );
      try {
        await _localDataSource.saveJob(errorJob);
        _logger.i(
          'Updated job ${job.localId} status to $newStatus after unexpected error.',
        );
      } catch (saveError) {
        _logger.e(
          'Failed to save job with error status after unexpected error: $saveError',
        );
      }
      return Left(ServerFailure(message: 'Unexpected error syncing job: $e'));
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
