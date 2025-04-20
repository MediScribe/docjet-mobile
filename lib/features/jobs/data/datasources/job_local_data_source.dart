import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/core/error/exceptions.dart'; // Import CacheException
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart'; // Import Job entity
import 'package:dartz/dartz.dart'; // Import dartz for Unit

/// Abstract interface defining operations for local storage of jobs.
///
/// This acts as a contract for interacting with the local job cache,
/// typically implemented using Hive or a similar persistence solution.
abstract class JobLocalDataSource {
  //---------------------------------------------------------------------------
  // JobHiveModel Operations (Legacy/Internal - To be phased out)
  //---------------------------------------------------------------------------
  // TODO: [Refactor] These should eventually be removed or made private if only
  //       needed internally by the implementation. Consumers should use the
  //       Job entity methods below.

  /// Retrieves all job models directly from the cache.
  /// **Use [getJobs] instead for external use.**
  Future<List<JobHiveModel>> getAllJobHiveModels();

  /// Retrieves a single job model by its local ID directly from the cache.
  /// **Use [getJobById] instead for external use.**
  Future<JobHiveModel?> getJobHiveModelById(String id);

  /// Saves a single job model directly to the cache.
  /// **Use [saveJob] instead for external use.**
  Future<void> saveJobHiveModel(JobHiveModel model);

  /// Deletes a job model by its local ID directly from the cache.
  /// **Use [deleteJob] instead for external use.**
  Future<void> deleteJobHiveModel(String id);

  //---------------------------------------------------------------------------
  // Metadata Operations
  //---------------------------------------------------------------------------

  /// Retrieves the timestamp of the last successful fetch from the server.
  Future<DateTime?> getLastFetchTime();

  /// Saves the timestamp of the last successful fetch from the server.
  Future<void> saveLastFetchTime(DateTime time);

  //---------------------------------------------------------------------------
  // Sync Status Methods (Mix of Legacy and potentially useful - review)
  //---------------------------------------------------------------------------

  /// Retrieves jobs that are currently marked as pending synchronization.
  /// Returns Job entities.
  Future<List<Job>> getJobsToSync();

  /// Updates the synchronization status of a specific job by its local ID.
  Future<void> updateJobSyncStatus(String id, SyncStatus status);

  /// Retrieves jobs that have been successfully synchronized (have a serverId
  /// and SyncStatus.synced). Returns Job entities.
  Future<List<Job>>
  getSyncedJobs(); // Note: Renamed from getSyncedJobHiveModels

  /// Retrieves jobs that are in an error state and eligible for a sync retry
  /// based on the provided maximum retries and base backoff duration.
  Future<List<Job>> getJobsToRetry(
    int maxRetries,
    Duration baseBackoffDuration,
  );

  //---------------------------------------------------------------------------
  // Job Entity Operations (New Style - Preferred API)
  //---------------------------------------------------------------------------

  /// Retrieves a list of all jobs from the cache as [Job] entities.
  Future<List<Job>> getJobs();

  /// Retrieves a single job by its local ID as a [Job] entity.
  /// Throws [CacheException] if the job is not found.
  Future<Job> getJobById(String localId);

  /// Saves a [Job] entity to the cache. Handles mapping to the storage model.
  /// Returns [unit] on success. Throws [CacheException] on failure.
  Future<Unit> saveJob(Job job);

  /// Deletes a job by its local ID. Handles underlying storage model deletion.
  /// Returns [unit] on success. Throws [CacheException] on failure.
  Future<Unit> deleteJob(String localId);

  /// Retrieves jobs based on their [SyncStatus].
  Future<List<Job>> getJobsByStatus(SyncStatus status);
}
