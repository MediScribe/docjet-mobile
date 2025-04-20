import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';

/// Manages job data including local persistence, remote sync, and CRUD operations.
/// This is the single public interface for interacting with job data.
abstract class JobRepository {
  /// --- FETCHING OPERATIONS ---

  /// Fetches all jobs for the current user.
  /// Returns [Right(List<Job>)] containing the list of jobs on success.
  /// Returns [Left(Failure)] on error (e.g., network or cache issues).
  Future<Either<Failure, List<Job>>> getJobs();

  /// Fetches a single job by its unique local identifier.
  /// Returns [Right(Job)] if the job is found.
  /// Returns [Left(Failure)] if the job with the specified [localId] is not found
  /// or if another error occurs.
  Future<Either<Failure, Job>> getJobById(String localId);

  /// --- WRITE OPERATIONS ---

  /// Creates a new job locally with the provided audio file path and optional text.
  /// A unique [localId] is generated and assigned internally.
  /// The job is initially marked with [SyncStatus.pending].
  /// Returns [Right(Job)] containing the newly created job object on success.
  /// Returns [Left(Failure)] if the creation process fails (e.g., cache error).
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath,
    String? text,
  });

  /// Updates an existing job identified by its [localId].
  /// Applies the changes specified in the [updates] object.
  /// Sets the job's [SyncStatus] to [SyncStatus.pending] to trigger synchronization.
  /// Returns [Right(Job)] containing the updated job object on success.
  /// Returns [Left(Failure)] if the job is not found or if the update fails.
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateData updates, // Use JobUpdateData instead of Map
  });

  /// --- DELETE OPERATIONS ---

  /// Marks a job for deletion locally using its [localId].
  /// This sets the job's [SyncStatus] to [SyncStatus.pendingDeletion].
  /// The actual deletion from local storage and the remote server occurs during the sync process.
  /// Returns [Right(unit)] on successful marking for deletion.
  /// Returns [Left(Failure)] if the job is not found or if a cache error occurs.
  Future<Either<Failure, Unit>> deleteJob(String localId);

  /// --- SYNC OPERATIONS ---

  /// Synchronizes all locally pending jobs (created, updated, marked for deletion)
  /// with the remote server.
  /// Requires network connectivity.
  /// Returns [Right(unit)] when the sync process completes, even if individual jobs failed.
  /// Returns [Left(Failure)] if a critical error occurs (e.g., network failure before starting).
  Future<Either<Failure, Unit>> syncPendingJobs();

  /// Resets a job stuck in the SyncStatus.failed state back to SyncStatus.pending
  Future<Either<Failure, Job>> resetFailedJob(String localId);
}
