import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';

/// Service class for job write operations
class JobWriterService {
  final JobLocalDataSource _localDataSource;
  final Uuid _uuid;

  JobWriterService({
    required JobLocalDataSource localDataSource,
    required Uuid uuid,
  }) : _localDataSource = localDataSource,
       _uuid = uuid;

  /// Creates a new job with the given audio file path and optional text.
  ///
  /// Generates a unique local ID for the job, assigns the initial
  /// [SyncStatus.pending], saves it to the local data source, and returns
  /// the created job entity.
  ///
  /// Returns [Right] with the created [Job] on success.
  /// Returns [Left] with a [CacheFailure] on exception.
  Future<Either<Failure, Job>> createJob({
    required String userId,
    required String audioFilePath,
    String? text,
  }) async {
    try {
      final localId = _uuid.v4();
      final now = DateTime.now(); // Capture consistent timestamp

      final job = Job(
        localId: localId,
        serverId: null, // No server ID on creation
        userId: userId,
        status: JobStatus.created, // Initial status
        syncStatus: SyncStatus.pending, // Needs sync
        displayTitle: '', // TODO: Define how displayTitle is set initially
        audioFilePath: audioFilePath,
        text: text, // Use provided text or null
        createdAt: now,
        updatedAt: now,
      );

      await _localDataSource.saveJob(job);
      return Right(job);
    } on CacheException catch (_) {
      // TODO: Add proper logging/tracing
      return Left(CacheFailure()); // Removed message parameter
    } on Exception catch (_) {
      // Catch any other unexpected exceptions during the process
      // TODO: Add proper logging/tracing for unexpected errors
      return Left(CacheFailure()); // Removed message parameter
    }
  }

  /// Updates an existing job identified by its [localId] with the provided [updates].
  ///
  /// Fetches the existing job, applies the changes from [updates],
  /// sets the [SyncStatus.pending] to mark it for synchronization,
  /// saves the updated job, and returns the updated job entity.
  ///
  /// Returns [Right] with the updated [Job] on success.
  /// Returns [Left] with a [CacheFailure] if the job is not found or on exception.
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateData updates,
  }) async {
    try {
      // 1. Fetch the existing job
      final existingJob = await _localDataSource.getJobById(localId);

      // Add validation: return early if no actual changes are provided
      if (!updates.hasChanges) {
        return Right(existingJob); // Return the unchanged job directly
      }

      // 2. Apply updates and mark for sync
      final updatedJob = existingJob.copyWith(
        text: updates.text ?? existingJob.text,
        // status: updates.status ?? existingJob.status, // Status not updated here per old test logic
        // serverId: updates.serverId ?? existingJob.serverId, // serverId update happens during sync
        syncStatus: SyncStatus.pending, // CRITICAL: Mark as needing sync
        updatedAt: DateTime.now(), // Update timestamp
      );

      // 3. Save the updated job
      await _localDataSource.saveJob(updatedJob);

      // 4. Return the updated job
      return Right(updatedJob);
    } on CacheException catch (_) {
      // Handle cases where job not found or save fails
      // TODO: Add proper logging/tracing
      return Left(CacheFailure()); // Removed message parameter
    } on Exception catch (_) {
      // Catch any other unexpected exceptions
      // TODO: Add proper logging/tracing
      return Left(CacheFailure()); // Removed message parameter
    }
  }

  /// Updates the synchronization status of an existing job identified by its [localId].
  ///
  /// Fetches the existing job, updates its [syncStatus],
  /// saves the updated job, and returns [unit] to indicate completion.
  ///
  /// Returns [Right] with [unit] on success.
  /// Returns [Left] with a [CacheFailure] if the job is not found or on exception.
  Future<Either<Failure, Unit>> updateJobSyncStatus({
    required String localId,
    required SyncStatus status,
  }) async {
    try {
      // 1. Fetch the existing job
      final existingJob = await _localDataSource.getJobById(localId);

      // 2. Update only the sync status
      // Note: We don't update 'updatedAt' here, as this is an internal status change
      final updatedJob = existingJob.copyWith(syncStatus: status);

      // 3. Save the updated job
      await _localDataSource.saveJob(updatedJob);

      // 4. Return success
      return Right(unit);
    } on CacheException catch (_) {
      // Handle cases where job not found or save fails
      // TODO: Add proper logging/tracing
      return Left(CacheFailure()); // Removed message parameter
    } on Exception catch (_) {
      // Catch any other unexpected exceptions
      // TODO: Add proper logging/tracing
      return Left(CacheFailure()); // Removed message parameter
    }
  }
}
