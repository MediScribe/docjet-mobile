import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// Service class for job deletion operations.
///
/// Handles marking jobs for deletion locally and permanently removing them
/// along with associated files.
class JobDeleterService {
  final JobLocalDataSource _localDataSource;
  final FileSystem _fileSystem;
  final Logger _logger = Logger();

  static final String _tag = logTag(JobDeleterService);

  /// Creates an instance of [JobDeleterService].
  ///
  /// Requires a [JobLocalDataSource] for database interactions and a
  /// [FileSystem] for managing associated files.
  JobDeleterService({
    required JobLocalDataSource localDataSource,
    required FileSystem fileSystem,
  }) : _localDataSource = localDataSource,
       _fileSystem = fileSystem;

  /// Marks a job for deletion locally by setting its [SyncStatus] to [SyncStatus.pendingDeletion].
  ///
  /// This operation does not immediately remove the job from the database or delete
  /// its associated audio file. The actual deletion is handled later by the sync process.
  ///
  /// - Parameter [localId]: The local identifier of the job to mark for deletion.
  /// - Returns: [Right(unit)] if the job is successfully marked for deletion.
  /// - Returns: [Left(CacheFailure)] if the job with the specified [localId] is not found
  ///   or if there's an error updating the job's status in the local data source.
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
    if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
      try {
        _logger.d('$_tag Deleting audio file: ${job.audioFilePath}');
        await _fileSystem.deleteFile(job.audioFilePath!);
        _logger.i(
          '$_tag Successfully deleted audio file: ${job.audioFilePath}.',
        );
      } catch (e, stackTrace) {
        _logger.e(
          '$_tag Failed to delete audio file during permanent deletion for job $localId, path: ${job.audioFilePath}',
          error: e,
          stackTrace: stackTrace,
        );

        // ---- START: Increment counter on failure ----
        final updatedJob = job.copyWith(
          failedAudioDeletionAttempts: job.failedAudioDeletionAttempts + 1,
        );
        try {
          _logger.w(
            '$_tag Attempting to save job $localId with incremented deletion failure counter.',
          );
          await _localDataSource.saveJob(updatedJob);
          _logger.i(
            '$_tag Successfully saved job $localId with incremented counter.',
          );
        } catch (saveError) {
          _logger.e(
            '$_tag CRITICAL: Failed to save job $localId after audio deletion failure: $saveError',
            error: saveError,
            // Consider adding stack trace if available from saveError
          );
          // Do not return Failure here, as per original requirement
        }
        // ---- END: Increment counter on failure ----
      }
    } else {
      _logger.d(
        '$_tag No audio file path found for job $localId, skipping file deletion.',
      );
    }

    // If we reached here, DB deletion was successful.
    return const Right(unit);
  }
}
