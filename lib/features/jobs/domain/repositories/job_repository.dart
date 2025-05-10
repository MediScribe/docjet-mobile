import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';

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
  Future<Either<Failure, Job?>> getJobById(String localId);

  /// --- STREAM OPERATIONS ---

  /// Watches the local cache for changes to the list of all jobs.
  ///
  /// Returns a stream that emits the complete list of [Job] entities whenever
  /// a change occurs in the underlying data source. Emits an initial list
  /// upon subscription.
  ///
  /// Emits [Right<List<Job>>] on success or updates.
  /// Emits [Left<Failure>] if there's an error accessing or watching the cache.
  Stream<Either<Failure, List<Job>>> watchJobs();

  /// Watches the local cache for changes to a specific job identified by [localId].
  ///
  /// Returns a stream that emits the [Job] entity corresponding to the [localId]
  /// whenever its data changes in the underlying source. Emits `null` if the job
  /// is deleted. Emits the initial state upon subscription.
  ///
  /// Emits [Right<Job?>] on success or updates (Job or null).
  /// Emits [Left<Failure>] if there's an error accessing or watching the cache.
  Stream<Either<Failure, Job?>> watchJobById(String localId);

  /// --- WRITE OPERATIONS ---

  /// Creates a new job locally with the provided audio file path and optional text.
  /// A unique [localId] is generated and assigned internally.
  /// The job is initially marked with [SyncStatus.pending].
  /// The user ID is obtained from the AuthSessionProvider internally.
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
    required JobUpdateDetails updates,
  });

  /// --- DELETE OPERATIONS ---

  /// Marks a job for deletion locally using its [localId].
  /// This sets the job's [SyncStatus] to [SyncStatus.pendingDeletion].
  /// The actual deletion from local storage and the remote server occurs during the sync process.
  /// Returns [Right(unit)] on successful marking for deletion.
  /// Returns [Left(Failure)] if the job is not found or if a cache error occurs.
  Future<Either<Failure, Unit>> deleteJob(String localId);

  /// Intelligently deletes a job based on its syncing status:
  /// - If the job is an orphan (no serverId or confirmed non-existent on server),
  ///   purges it locally immediately.
  /// - Otherwise, marks it for deletion with [SyncStatus.pendingDeletion] like
  ///   the standard [deleteJob] method.
  ///
  /// Returns [Right(bool)] where the boolean value indicates:
  /// - `true` if the job was purged immediately
  /// - `false` if the job was marked for standard sync-based deletion
  ///
  /// Returns [Left(Failure)] if the job cannot be found or deletion fails.
  Future<Either<Failure, bool>> smartDeleteJob(String localId);

  /// --- SYNC OPERATIONS ---

  /// Synchronizes all locally pending jobs (created, updated, marked for deletion)
  /// with the remote server.
  /// Requires network connectivity.
  /// Returns [Right(unit)] when the sync process completes, even if individual jobs failed.
  /// Returns [Left(Failure)] if a critical error occurs (e.g., network failure before starting).
  Future<Either<Failure, Unit>> syncPendingJobs();

  /// Reconciles the local job cache with the server to detect server-side deletions.
  ///
  /// This operation triggers a full fetch from the server via [JobReaderService.getJobs],
  /// which compares the server list with local synced records and removes any local
  /// records that no longer exist on the server.
  ///
  /// Returns [Right(unit)] when the reconciliation process completes successfully.
  /// Returns [Left(Failure)] if an error occurs during server fetch or local update.
  Future<Either<Failure, Unit>> reconcileJobsWithServer();

  /// Resets a job stuck in the SyncStatus.failed state back to SyncStatus.pending.
  /// Returns [Right(unit)] on success, [Left(Failure)] otherwise.
  Future<Either<Failure, Unit>> resetFailedJob(String localId);
}
