import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/core/error/exceptions.dart'; // Import CacheException

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

  /// Saves a list of [JobHiveModel] objects to the cache.
  /// Useful for batch updates (e.g., after fetching from API).
  /// Throws a [CacheException] on failure.
  Future<void> saveJobHiveModels(List<JobHiveModel> models);

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
}
