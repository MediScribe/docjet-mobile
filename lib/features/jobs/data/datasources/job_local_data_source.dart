import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/core/error/exceptions.dart'; // Import CacheException
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart'; // Import Job entity
import 'package:dartz/dartz.dart'; // Import dartz for Unit

// Abstract interface for interacting with the local job cache (e.g., Hive)
// This defines the contract for what the local data source must provide.
abstract class JobLocalDataSource {
  // --- Methods operating on Job Entity (New Style) ---

  /// Retrieves a single Job entity by its localId.
  /// Returns the [Job] if found.
  /// Throws a [CacheException] if not found or on cache access errors.
  Future<Job> getJobById(String localId);

  /// Saves a single [Job] entity to the cache.
  /// Maps the Job entity to the appropriate local storage model (e.g., JobHiveModel)
  /// before saving. Overwrites existing entry with the same localId.
  /// Returns [unit] on success.
  /// Throws a [CacheException] on failure.
  Future<Unit> saveJob(Job job);

  /// Deletes a single Job by its localId.
  /// Handles mapping or finding the corresponding local storage entry.
  /// Returns [unit] on success.
  /// Throws a [CacheException] on failure.
  Future<Unit> deleteJob(String localId);

  /// Retrieves all jobs with a specific [SyncStatus].
  /// Returns a list of [Job] entities.
  /// Throws a [CacheException] if unable to access the cache.
  Future<List<Job>> getJobsByStatus(SyncStatus status);

  // --- Methods operating on JobHiveModel (Old Style - To be refactored/removed?) ---
  // TODO: Review if these are still needed or can be replaced by Job entity methods.

  /// Retrieves all Job models stored in the local cache.
  /// Returns a list of [JobHiveModel].
  /// Throws a [CacheException] if unable to access the cache.
  Future<List<JobHiveModel>> getAllJobHiveModels();

  /// Retrieves a single Job model by its ID from the cache.
  /// Returns the [JobHiveModel] if found, otherwise null.
  /// Throws a [CacheException] on cache access errors.
  Future<JobHiveModel?> getJobHiveModelById(String id);

  /// Saves a single [JobHiveModel] to the cache.
  /// Overwrites existing entry with the same ID.
  /// Throws a [CacheException] on failure.
  Future<void> saveJobHiveModel(JobHiveModel model);

  /// Saves a list of JobHiveModel objects directly to local storage.
  ///
  /// Used for batch save operations.
  /// Throws [CacheException] on error.
  /// Returns true if operation was successful.
  Future<bool> saveJobHiveModels(List<JobHiveModel> models);

  /// Deletes a single Job model by its ID from the cache.
  /// Throws a [CacheException] on failure.
  Future<void> deleteJobHiveModel(String id);

  /// Clears all Job models from the cache.
  /// Throws a [CacheException] on failure.
  Future<void> clearAllJobHiveModels();

  /// Gets the last saved Job model (e.g. by updated_at)
  /// Throws a [CacheException] on failure.
  Future<JobHiveModel?> getLastJobHiveModel();

  /// Gets the timestamp of the last successful fetch from the remote source.
  /// Returns null if no fetch has ever been recorded.
  /// Throws a [CacheException] if unable to access the cache.
  Future<DateTime?> getLastFetchTime();

  /// Saves the timestamp of the last successful fetch.
  /// Throws a [CacheException] on failure.
  Future<void> saveLastFetchTime(DateTime time);

  /// Retrieves all Job models marked with a [SyncStatus.pending].
  /// Used by the repository to know which jobs need syncing with the backend.
  /// Returns a list of [JobHiveModel].
  /// Throws a [CacheException] if unable to access the cache.
  Future<List<JobHiveModel>> getJobsToSync();

  /// Updates the sync status of a specific job by its ID.
  /// Used by the repository after a sync attempt (success or failure).
  /// Throws a [CacheException] if the job is not found or on cache access errors.
  Future<void> updateJobSyncStatus(String id, SyncStatus status);

  /// Retrieves all Job models that have been successfully synced with the server
  /// (i.e., have `SyncStatus.synced` and a non-null `serverId`).
  /// Used by the repository for server-side deletion checks.
  /// Returns a list of [JobHiveModel].
  /// Throws a [CacheException] if unable to access the cache.
  Future<List<JobHiveModel>> getSyncedJobHiveModels();

  // TODO: Add getSyncedJobs method to fetch only server-synced jobs with serverId
}
