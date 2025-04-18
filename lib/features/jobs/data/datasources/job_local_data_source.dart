import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/core/error/exceptions.dart'; // Import CacheException
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

// Abstract interface for interacting with the local job cache (e.g., Hive)
// This defines the contract for what the local data source must provide.
abstract class JobLocalDataSource {
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
}
