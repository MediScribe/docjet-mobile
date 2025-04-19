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

  final Logger _logger = LoggerFactory.getLogger(JobDeleterService);
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
    _logger.d('$_tag Marking job $localId for deletion.');
    try {
      // Retrieve the job entity to ensure it exists before marking for deletion.
      // Use the Job entity as defined in the interface contract.
      final Job job = await _localDataSource.getJobById(localId);
      _logger.d('$_tag Found job $localId to mark for deletion.');

      // Create an updated entity with the pendingDeletion status.
      final Job jobToDelete = job.copyWith(
        syncStatus: SyncStatus.pendingDeletion,
      );

      // Save the updated job entity back to the local data source.
      // Use the saveJob method from the interface.
      await _localDataSource.saveJob(jobToDelete);
      _logger.i('$_tag Successfully marked job $localId for deletion locally.');
      return const Right(unit);
    } on CacheException catch (e, stackTrace) {
      // Specific handling for when the job is not found in the cache.
      _logger.w(
        '$_tag Job with localId $localId not found when trying to mark for deletion.',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CacheFailure('Job with localId $localId not found.'));
    } catch (e, stackTrace) {
      // Generic catch block for any other unexpected errors during the process.
      _logger.e(
        '$_tag Error marking job $localId for deletion: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CacheFailure('Failed to mark job for deletion: $e'));
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
    _logger.d('$_tag Attempting to permanently delete job $localId.');
    Job? job; // To hold the job details before deletion
    try {
      // Retrieve job details first to get the audio file path.
      // We need this *before* deleting the database record.
      // Use the Job entity as defined in the interface contract.
      job = await _localDataSource.getJobById(localId);
      _logger.d('$_tag Found job $localId details for permanent deletion.');

      // Delete the job record from the local data source.
      // Use the deleteJob method from the interface.
      await _localDataSource.deleteJob(localId);
      _logger.i(
        '$_tag Successfully deleted job $localId from local data source.',
      );

      // If the job had an associated audio file, attempt to delete it.
      if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
        _logger.d(
          '$_tag Attempting to delete audio file ${job.audioFilePath} for job $localId.',
        );
        try {
          await _fileSystem.deleteFile(job.audioFilePath!);
          _logger.i(
            '$_tag Successfully deleted audio file ${job.audioFilePath} for job $localId.',
          );
        } catch (e, stackTrace) {
          // Log the file deletion error but allow the overall operation to succeed.
          // The primary goal is to remove the database record.
          _logger.w(
            '$_tag Failed to delete audio file ${job.audioFilePath} for job $localId: $e',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else {
        _logger.d('$_tag Job $localId has no audio file path to delete.');
      }

      return const Right(unit);
    } on CacheException catch (e, stackTrace) {
      // Handle cases where the job couldn't be found initially or deletion failed.
      if (job == null) {
        _logger.w(
          '$_tag Job with localId $localId not found for permanent deletion.',
          error: e,
          stackTrace: stackTrace,
        );
        return Left(
          CacheFailure(
            'Job with localId $localId not found for permanent deletion.',
          ),
        );
      } else {
        _logger.e(
          '$_tag CacheException during permanent deletion of job $localId from DB: $e',
          error: e,
          stackTrace: stackTrace,
        );
        // Pass the original exception message if available - removed redundant type check
        final String errorMessage = e.message ?? e.toString();
        return Left(
          CacheFailure(
            'Failed to permanently delete job $localId from cache: $errorMessage',
          ),
        );
      }
    } catch (e, stackTrace) {
      // Catch unexpected errors during the database deletion process.
      _logger.e(
        '$_tag Unexpected error during permanent deletion of job $localId: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        CacheFailure(
          'Unexpected error during permanent deletion of job $localId: $e',
        ),
      );
    }
  }
}
