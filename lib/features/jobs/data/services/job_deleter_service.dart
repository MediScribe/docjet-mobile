import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// Service class for job deletion operations.
///
/// Handles marking jobs for deletion locally and permanently removing them
/// along with associated files.
///
/// ## Thread Safety
/// This service interacts with the local file system and database.
/// It is designed for use within a single Dart isolate.
/// Concurrent access from multiple isolates is not guaranteed to be safe
/// without external synchronization mechanisms (like mutexes).
class JobDeleterService {
  final JobLocalDataSource _localDataSource;
  final FileSystem _fileSystem;
  final NetworkInfo? _networkInfo;
  final JobRemoteDataSource? _remoteDataSource;
  final Logger _logger = LoggerFactory.getLogger(JobDeleterService);

  static final String _tag = logTag(JobDeleterService);

  // Timeout duration for server existence check
  static const Duration _serverCheckTimeout = Duration(seconds: 2);

  /// Creates an instance of [JobDeleterService].
  ///
  /// Requires a [JobLocalDataSource] for database interactions and a
  /// [FileSystem] for managing associated files.
  ///
  /// Optionally takes [NetworkInfo] and [JobRemoteDataSource] for smart
  /// deletion functionality that checks server existence.
  JobDeleterService({
    required JobLocalDataSource localDataSource,
    required FileSystem fileSystem,
    NetworkInfo? networkInfo,
    JobRemoteDataSource? remoteDataSource,
  }) : _localDataSource = localDataSource,
       _fileSystem = fileSystem,
       _networkInfo = networkInfo,
       _remoteDataSource = remoteDataSource;

  /// Marks a job for deletion locally by setting its [SyncStatus] to [SyncStatus.pendingDeletion].
  ///
  /// This operation does not immediately remove the job from the database or delete
  /// its associated audio file. The actual deletion is handled later by the sync process.
  ///
  /// - Parameter [localId]: The local identifier of the job to mark for deletion.
  /// - Returns: [Right(unit)] if the job is successfully marked for deletion.
  /// - Returns: [Left(CacheFailure)] if the job with the specified [localId] is not found
  ///   or if there's an error updating the job's status in the local data source.
  ///
  /// Note: Unlike [permanentlyDeleteJob], this method returns a [CacheFailure] if the job
  /// is not found in the local data source.
  Future<Either<Failure, Unit>> deleteJob(String localId) async {
    _logger.i('$_tag Marking job for deletion (localId: $localId)...');
    try {
      final job = await _localDataSource.getJobById(localId);
      final jobToDelete = job.copyWith(syncStatus: SyncStatus.pendingDeletion);
      await _localDataSource.saveJob(jobToDelete);
      _logger.i(
        '$_tag Successfully marked job for deletion (localId: $localId).',
      );
      return const Right(unit);
    } on CacheException catch (e) {
      _logger.e(
        '$_tag Failed to mark job for deletion (localId: $localId): $e',
      );
      return Left(CacheFailure(e.message ?? 'Failed to find or save job'));
    } catch (e) {
      _logger.e(
        '$_tag Unexpected error marking job for deletion (localId: $localId): $e',
      );
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Permanently deletes a job from the local data source and removes its associated audio file.
  ///
  /// This operation is typically invoked by the synchronization service after a job deletion
  /// has been successfully confirmed with the remote server, or for jobs that only existed locally.
  ///
  /// - Parameter [localId]: The local identifier of the job to permanently delete.
  /// - Returns: [Right(unit)] if the job is successfully deleted from the local data source.
  ///   File deletion errors are logged but do not result in a [Failure].
  /// - Returns: [Left(CacheFailure)] if the job cannot be found or deleted from the local data source.
  ///
  /// Note: Unlike [deleteJob], this method returns a [Right(unit)] if the job is not found
  /// (treating it as already successfully deleted).
  Future<Either<Failure, Unit>> permanentlyDeleteJob(String localId) async {
    _logger.i(
      '$_tag Attempting permanent local deletion (localId: $localId)...',
    );
    Job job; // Need job details for file path

    // Step 1: Get Job Details (handle not found)
    try {
      job = await _localDataSource.getJobById(localId);
      _logger.d('$_tag Found job locally, proceeding with deletion.');
    } on CacheException catch (e) {
      // Job not found exception is expected if already deleted elsewhere. Treat as success.
      _logger.w(
        '$_tag CacheException getting job $localId (Maybe already deleted?): $e',
      );
      return const Right(unit);
    } catch (e) {
      // Any other error fetching job details is a failure.
      _logger.e(
        '$_tag Unexpected error fetching job $localId details for deletion: $e',
      );
      return Left(
        CacheFailure('Failed to fetch job details before deletion: $e'),
      );
    }

    // Step 2: Delete from DB (handle failure)
    try {
      await _localDataSource.deleteJob(localId);
      _logger.i(
        '$_tag Successfully deleted job from local DB (localId: $localId).',
      );
    } catch (e) {
      _logger.e('$_tag Error deleting job $localId from local DB: $e.');
      // Failure to delete from DB is a critical error for this operation.
      return Left(
        CacheFailure('Failed to delete job $localId from local DB: $e'),
      );
    }

    // Step 3: Delete File (handle failure non-critically)
    await _safelyDeleteFileAndHandleFailure(job);

    // If we reached here, DB deletion was successful.
    return const Right(unit);
  }

  /// Attempts to smartly delete a job by:
  /// - Immediately purging it if it's an orphan (no serverId or confirmed non-existent on server)
  /// - Otherwise marking it for sync-based deletion (like standard deleteJob)
  ///
  /// - Parameter [localId]: The local identifier of the job to delete.
  /// - Returns: [Right(true)] if the job was purged immediately (orphan case).
  /// - Returns: [Right(false)] if the job was marked for regular sync-based deletion.
  /// - Returns: [Left(Failure)] on error fetching job or performing deletion operations.
  Future<Either<Failure, bool>> attemptSmartDelete(String localId) async {
    _logger.i('$_tag Attempting smart delete for job (localId: $localId)...');

    Job job;

    // Step 1: Get the job details
    try {
      job = await _localDataSource.getJobById(localId);
      _logger.d('$_tag Found job locally, checking for orphan status');
    } on CacheException catch (e) {
      _logger.e('$_tag Failed to find job for smart delete: $e');
      return Left(CacheFailure(e.message ?? 'Failed to find job'));
    } catch (e) {
      _logger.e('$_tag Unexpected error fetching job for smart delete: $e');
      return Left(UnknownFailure('Unexpected error: $e'));
    }

    // Step 2: Handle case where job has no serverId (immediate purge)
    if (job.serverId == null || job.serverId!.isEmpty) {
      _logger.i('$_tag Job has no serverId - purging immediately');
      return _purgeImmediately(localId);
    }

    // Step 3: For jobs with a serverId, check if we should attempt server existence check
    bool isOnline = false;
    if (_networkInfo != null && _remoteDataSource != null) {
      try {
        isOnline = await _networkInfo.isConnected;
      } catch (e) {
        _logger.w('$_tag Error checking network status: $e, assuming offline');
        isOnline = false;
      }
    }

    // Step 4a: If offline or missing dependencies, fall back to standard deletion
    if (!isOnline || _networkInfo == null || _remoteDataSource == null) {
      _logger.i(
        '$_tag Device offline or missing dependencies - marking for sync-based deletion',
      );
      return _markForSyncDeletion(localId);
    }

    // Step 4b: If online with all dependencies, check server existence with timeout
    try {
      _logger.d('$_tag Checking if job exists on server...');
      bool jobExistsOnServer = true; // Default to true (safer)

      // Apply timeout to server check to avoid UI lag
      try {
        await _remoteDataSource
            .fetchJobById(job.serverId!)
            .timeout(_serverCheckTimeout);
        _logger.i('$_tag Job exists on server (200/204)');
        jobExistsOnServer = true;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          _logger.i('$_tag Job does not exist on server (404)');
          jobExistsOnServer = false;
        } else {
          // Other API errors - fall back to standard deletion
          _logger.w('$_tag Error checking job existence: API error $e');
          jobExistsOnServer = true; // Assume it exists to be safe
        }
      } catch (e) {
        // Network errors, timeouts, or other unexpected errors
        _logger.w('$_tag Error checking job existence: $e');
        jobExistsOnServer = true; // Assume it exists to be safe
      }

      // Step 5: Delete based on server existence check
      if (jobExistsOnServer) {
        // If job exists on server, use standard deletion
        _logger.i(
          '$_tag Job exists or cannot confirm non-existence - marking for sync-based deletion',
        );
        return _markForSyncDeletion(localId);
      } else {
        // Job doesn't exist on server, purge immediately
        _logger.i('$_tag Job confirmed not on server - purging immediately');
        return _purgeImmediately(localId);
      }
    } catch (e) {
      // Any unexpected error during server check process
      _logger.e('$_tag Unexpected error during smart delete server check: $e');
      // Fall back to standard deletion
      return _markForSyncDeletion(localId);
    }
  }

  /// Helper method to purge a job immediately by delegating to permanentlyDeleteJob
  /// Returns [Right(true)] if successful or passes through the failure
  Future<Either<Failure, bool>> _purgeImmediately(String localId) async {
    return (await permanentlyDeleteJob(localId)).fold(
      (failure) => Left(failure),
      (_) => const Right(true), // true indicates immediate purge
    );
  }

  /// Helper method to mark a job for sync-based deletion by delegating to deleteJob
  /// Returns [Right(false)] if successful or passes through the failure
  Future<Either<Failure, bool>> _markForSyncDeletion(String localId) async {
    return (await deleteJob(localId)).fold(
      (failure) => Left(failure),
      (_) => const Right(false), // false indicates standard deletion
    );
  }

  /// Helper method to attempt file deletion and handle failures non-critically.
  ///
  /// Logs errors and increments the job's `failedAudioDeletionAttempts` counter
  /// if deletion fails, attempting to save the updated job state.
  Future<void> _safelyDeleteFileAndHandleFailure(Job job) async {
    if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
      try {
        _logger.d('$_tag Deleting audio file: ${job.audioFilePath}');
        await _fileSystem.deleteFile(job.audioFilePath!);
        _logger.i(
          '$_tag Successfully deleted audio file: ${job.audioFilePath}.',
        );
      } catch (e, stackTrace) {
        _logger.e(
          '$_tag Failed to delete audio file during permanent deletion for job ${job.localId}, path: ${job.audioFilePath}',
          error: e,
          stackTrace: stackTrace,
        );

        // ---- START: Increment counter on failure ----
        final updatedJob = job.copyWith(
          failedAudioDeletionAttempts: job.failedAudioDeletionAttempts + 1,
        );
        try {
          _logger.w(
            '$_tag Attempting to save job ${job.localId} with incremented deletion failure counter.',
          );
          await _localDataSource.saveJob(updatedJob);
          _logger.i(
            '$_tag Successfully saved job ${job.localId} with incremented counter.',
          );
        } catch (saveError, st) {
          _logger.e(
            '$_tag CRITICAL: Failed to save job ${job.localId} after audio deletion failure: $saveError',
            error: saveError,
            stackTrace: st,
          );
          // Do not return Failure here, as per original requirement
        }
        // ---- END: Increment counter on failure ----
      }
    } else {
      _logger.d(
        '$_tag No audio file path found for job ${job.localId}, skipping file deletion.',
      );
    }
  }
}
