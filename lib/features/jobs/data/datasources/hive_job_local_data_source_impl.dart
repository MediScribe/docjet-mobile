import 'package:hive/hive.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'dart:math';

/// Concrete implementation of [JobLocalDataSource] using Hive for persistence.
///
/// Manages storing, retrieving, and deleting [JobHiveModel] instances,
/// handling synchronization status, and storing application metadata like
/// the last fetch timestamp.
class HiveJobLocalDataSourceImpl implements JobLocalDataSource {
  final HiveInterface hive;
  final Logger _logger = LoggerFactory.getLogger(HiveJobLocalDataSourceImpl);
  static final String _tag = logTag(HiveJobLocalDataSourceImpl);

  /// Box name for storing [JobHiveModel] objects.
  static const String jobsBoxName = 'jobs';

  /// Box name for storing application-level metadata (e.g., timestamps).
  static const String metadataBoxName = 'app_metadata';

  /// Key within the [metadataBoxName] box for storing the last fetch timestamp
  /// (as UTC milliseconds since epoch).
  static const String metadataTimestampKey = 'lastFetchTimestamp';

  HiveJobLocalDataSourceImpl({required this.hive});

  //---------------------------------------------------------------------------
  // Private Helper Methods
  //---------------------------------------------------------------------------

  /// Safely opens and returns the Hive box strictly typed for [JobHiveModel].
  ///
  /// Handles opening the box if it's not already open.
  /// Throws [CacheException] if opening fails.
  Future<Box<JobHiveModel>> _getOpenBox() async {
    _logger.d('$_tag Attempting to open Hive box: $jobsBoxName (for Jobs)');
    try {
      if (!hive.isBoxOpen(jobsBoxName)) {
        _logger.i('$_tag Box "$jobsBoxName" not open, opening...');
        final box = await hive.openBox<JobHiveModel>(jobsBoxName);
        _logger.i('$_tag Box "$jobsBoxName" opened successfully.');
        return box;
      }
      _logger.d('$_tag Box "$jobsBoxName" already open.');
      return hive.box<JobHiveModel>(jobsBoxName);
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to open Hive box: $jobsBoxName',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to open Hive box: ${e.toString()}');
    }
  }

  /// Safely opens and returns the Hive box used for storing application metadata.
  ///
  /// This box is opened as `Box<dynamic>` to accommodate potentially different
  /// types of metadata in the future.
  /// Handles opening the box if it's not already open.
  /// Throws [CacheException] if opening fails.
  Future<Box<dynamic>> _getMetadataBox() async {
    _logger.d(
      '$_tag Attempting to open Hive box: $metadataBoxName (for Metadata)',
    );
    try {
      if (!hive.isBoxOpen(metadataBoxName)) {
        _logger.i('$_tag Box "$metadataBoxName" not open, opening...');
        final box = await hive.openBox<dynamic>(metadataBoxName);
        _logger.i('$_tag Box "$metadataBoxName" opened successfully.');
        return box;
      }
      _logger.d('$_tag Box "$metadataBoxName" already open.');
      return hive.box<dynamic>(metadataBoxName);
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to open Hive box: $metadataBoxName',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to open metadata box: ${e.toString()}');
    }
  }

  //---------------------------------------------------------------------------
  // JobHiveModel Operations (Legacy/Internal)
  //---------------------------------------------------------------------------

  @override
  Future<List<JobHiveModel>> getAllJobHiveModels() async {
    _logger.d('$_tag getAllJobHiveModels called');
    try {
      final box = await _getOpenBox();
      final models = box.values.toList();
      _logger.d('$_tag Found ${models.length} job models in cache.');
      return models;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get all job models from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get all jobs: ${e.toString()}');
    }
  }

  @override
  Future<JobHiveModel?> getJobHiveModelById(String id) async {
    _logger.d('$_tag getJobHiveModelById called for id: $id');
    try {
      final box = await _getOpenBox();
      final value = box.get(id);
      if (value != null) {
        _logger.d('$_tag Found job model with id: $id in cache.');
        return value;
      } else {
        _logger.w('$_tag Job model with id: $id not found in cache.');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get job model by id: $id from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get job by ID: ${e.toString()}');
    }
  }

  @override
  Future<void> saveJobHiveModel(JobHiveModel model) async {
    _logger.d('$_tag saveJobHiveModel called for id: ${model.localId}');
    try {
      final box = await _getOpenBox();
      await box.put(model.localId, model);
      _logger.i('$_tag Saved job model with id: ${model.localId} to cache.');
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save job model with id: ${model.localId} to cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to save job: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteJobHiveModel(String id) async {
    _logger.d('$_tag deleteJobHiveModel called for id: $id');
    try {
      final box = await _getOpenBox();
      await box.delete(id);
      _logger.i('$_tag Deleted job model with id: $id from cache.');
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to delete job model with id: $id from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to delete job: ${e.toString()}');
    }
  }

  //---------------------------------------------------------------------------
  // Metadata Operations
  //---------------------------------------------------------------------------

  @override
  Future<DateTime?> getLastFetchTime() async {
    _logger.d('$_tag getLastFetchTime called');
    try {
      final box = await _getMetadataBox();
      final value = box.get(metadataTimestampKey);
      if (value == null) {
        _logger.d('$_tag No last fetch timestamp found in cache.');
        return null;
      }
      if (value is int) {
        _logger.d('$_tag Found last fetch timestamp: $value');
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      } else {
        _logger.w(
          '$_tag Invalid type found for last fetch timestamp (Type: ${value.runtimeType}). Expected int. Returning null.',
        );
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get last fetch timestamp from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException(
        'Failed to get last fetch timestamp: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> saveLastFetchTime(DateTime time) async {
    _logger.d('$_tag saveLastFetchTime called with time: $time');
    try {
      final box = await _getMetadataBox();
      final millis = time.toUtc().millisecondsSinceEpoch;
      await box.put(metadataTimestampKey, millis);
      _logger.i('$_tag Saved last fetch timestamp: $millis');
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save last fetch timestamp to cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to save last fetch time: ${e.toString()}');
    }
  }

  //---------------------------------------------------------------------------
  // Sync Status Methods
  //---------------------------------------------------------------------------

  @override
  Future<List<Job>> getJobsToSync() async {
    _logger.d('$_tag getJobsToSync called');
    try {
      final box = await _getOpenBox();
      final pendingModels =
          box.values
              .where((job) => job.syncStatus == SyncStatus.pending.index)
              .toList();
      _logger.d('$_tag Found ${pendingModels.length} models pending sync.');
      // MAP to Job entities
      final pendingJobs =
          pendingModels.map((model) => JobMapper.fromHiveModel(model)).toList();
      return pendingJobs;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get jobs pending sync from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get jobs to sync: ${e.toString()}');
    }
  }

  @override
  Future<void> updateJobSyncStatus(String id, SyncStatus status) async {
    _logger.d('$_tag updateJobSyncStatus called for id: $id, status: $status');
    Box<JobHiveModel>? box;
    try {
      box = await _getOpenBox();
      final value = box.get(id);

      if (value != null) {
        _logger.d('$_tag Found job model with id: $id for status update.');
        value.syncStatus = status.index;
        // Use HiveObject's save method if available and in the box, otherwise use box.put.
        // This handles cases where the object might not be properly linked to the box.
        if (value.isInBox) {
          await value.save();
          _logger.i(
            '$_tag Updated sync status for job $id to $status using model.save().',
          );
        } else {
          _logger.w(
            '$_tag Job model $id was not in box, updating using box.put().',
          );
          await box.put(id, value);
          _logger.i(
            '$_tag Updated sync status for job $id to $status using box.put().',
          );
        }
      } else {
        _logger.e('$_tag Job model with id: $id not found for status update.');
        throw CacheException('Job with id $id not found.');
      }
    } catch (e, stackTrace) {
      // Log the specific error encountered
      _logger.e(
        '$_tag Failed to update sync status for job id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap original error message for context if it's not the one we threw
      final originalMessage = (e is CacheException) ? e.message : e.toString();
      throw CacheException(
        'Failed to update job sync status for $id: $originalMessage',
      );
    }
  }

  @override
  Future<List<Job>> getSyncedJobs() async {
    _logger.d('$_tag getSyncedJobs called');
    try {
      final box = await _getOpenBox();
      final syncedModels =
          box.values.where((model) {
            // Check if serverId is not null AND syncStatus is synced
            return model.serverId != null &&
                model.syncStatus == SyncStatus.synced.index;
          }).toList();
      _logger.d(
        '$_tag Found ${syncedModels.length} models with SyncStatus.synced and non-null serverId.',
      );
      // MAP to Job entities
      final syncedJobs =
          syncedModels.map((model) => JobMapper.fromHiveModel(model)).toList();
      return syncedJobs;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get synced jobs from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get synced jobs: ${e.toString()}');
    }
  }

  //---------------------------------------------------------------------------
  // Job Entity Operations (New Style - Preferred)
  //---------------------------------------------------------------------------

  @override
  Future<Job> getJobById(String localId) async {
    _logger.d('$_tag getJobById (New Style) called for id: $localId');
    try {
      // Use the existing legacy method to get the Hive model
      final hiveModel = await getJobHiveModelById(localId);
      if (hiveModel == null) {
        _logger.w('$_tag Job with localId $localId not found in cache.');
        // Throw CacheException as per the interface contract if not found
        throw CacheException('Job with localId $localId not found');
      }
      _logger.d('$_tag Found and mapping JobHiveModel for id: $localId');
      // Map the Hive model to the Job entity
      return JobMapper.fromHiveModel(hiveModel);
    } catch (e, stackTrace) {
      // Catch specific CacheException from the check above, or any other error
      _logger.e(
        '$_tag Failed to get job by id: $localId',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw specifically as CacheException for consistent error handling
      if (e is CacheException) {
        rethrow; // Keep original CacheException message if thrown above
      } else {
        // Wrap other exceptions in CacheException
        throw CacheException(
          'Failed to retrieve job with localId $localId: ${e.toString()}',
        );
      }
    }
  }

  @override
  Future<Unit> saveJob(Job job) async {
    _logger.d('$_tag saveJob (New Style) called for id: ${job.localId}');
    try {
      _logger.d('$_tag Mapping Job entity to JobHiveModel for saving.');
      // Use the mapper to convert the Job entity to a Hive model
      final hiveModel = JobMapper.toHiveModel(job);
      // Use the existing legacy method to save the Hive model
      await saveJobHiveModel(hiveModel);
      _logger.i(
        '$_tag Successfully saved Job (New Style) with id: ${job.localId}',
      );
      // Return unit on success as per dartz convention
      return unit;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save job (New Style) with id: ${job.localId}',
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap any exception in a CacheException
      throw CacheException(
        'Failed to save job with id ${job.localId}: ${e.toString()}',
      );
    }
  }

  @override
  Future<Unit> deleteJob(String localId) async {
    _logger.d('$_tag deleteJob (New Style) called for id: $localId');
    try {
      // Use the existing legacy method to delete the Hive model
      await deleteJobHiveModel(localId);
      _logger.i('$_tag Successfully deleted Job (New Style) with id: $localId');
      // Return unit on success
      return unit;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to delete job (New Style) with id: $localId',
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap any exception in a CacheException
      throw CacheException(
        'Failed to delete job with id $localId: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<Job>> getJobsByStatus(SyncStatus status) async {
    _logger.d('$_tag getJobsByStatus (New Style) called for status: $status');
    try {
      final box = await _getOpenBox();
      final matchingModels =
          box.values
              .where((model) => model.syncStatus == status.index)
              .toList();
      _logger.d(
        '$_tag Found ${matchingModels.length} models with SyncStatus $status',
      );
      // Map the filtered models to Job entities
      final jobs =
          matchingModels
              .map((model) => JobMapper.fromHiveModel(model))
              .toList();
      _logger.d('$_tag Mapped ${jobs.length} models to Job entities.');
      return jobs;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get jobs by status $status',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException(
        'Failed to get jobs with status $status: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<Job>> getJobs() async {
    _logger.d('$_tag getJobs called (using Job entity)');
    try {
      final hiveModels = await getAllJobHiveModels();
      final jobs =
          hiveModels.map((model) => JobMapper.fromHiveModel(model)).toList();
      _logger.d('$_tag Mapped ${jobs.length} Hive models to Job entities.');
      return jobs;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get and map jobs from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get jobs: ${e.toString()}');
    }
  }

  /// Retrieves jobs that are in an error state and eligible for a sync retry.
  ///
  /// Eligibility is determined by:
  /// 1. Job's [SyncStatus] must be [SyncStatus.error].
  /// 2. Job's [retryCount] must be less than [maxRetries].
  /// 3. The time since the [lastSyncAttemptAt] must exceed the calculated
  ///    exponential backoff duration (`baseBackoffDuration * 2^retryCount`).
  ///
  /// Returns a list of [Job] entities eligible for retry.
  @override
  Future<List<Job>> getJobsToRetry(
    int maxRetries,
    Duration baseBackoffDuration,
  ) async {
    _logger.d(
      '$_tag getJobsToRetry called with maxRetries: $maxRetries, baseBackoff: $baseBackoffDuration',
    );
    try {
      final box = await _getOpenBox();
      final now = DateTime.now();

      final retryableJobs =
          box.values
              .where((model) {
                // 1. Must be in error status
                if (model.syncStatus != SyncStatus.error.index) {
                  return false;
                }

                // 2. Must have retry attempts remaining
                final retryCount = model.retryCount ?? 0;
                if (retryCount >= maxRetries) {
                  return false;
                }

                // 3. Check backoff duration
                if (model.lastSyncAttemptAt == null) {
                  // No last attempt recorded, eligible for retry immediately
                  return true;
                }

                // Parse the stored timestamp string
                final lastAttemptTime = DateTime.tryParse(
                  model.lastSyncAttemptAt!,
                );
                if (lastAttemptTime == null) {
                  // Invalid timestamp format, treat as eligible to avoid getting stuck
                  _logger.w(
                    '$_tag Invalid lastSyncAttemptAt format for job ${model.localId}: ${model.lastSyncAttemptAt}. Considering retryable.',
                  );
                  return true;
                }

                // Calculate backoff duration using exponential backoff with a cap.
                // Formula: wait = min(baseBackoff * pow(2, retryCount), maxBackoff)
                // Example (base=30s, max=1h):
                // retry 0: min(30s * 1, 1h) = 30s
                // retry 1: min(30s * 2, 1h) = 60s
                // retry 2: min(30s * 4, 1h) = 120s
                // ...
                // retry 7: min(30s * 128, 1h) = min(3840s, 3600s) = 3600s (1 hour)
                // retry 8: min(30s * 256, 1h) = min(7680s, 3600s) = 3600s (1 hour)
                final backoffMultiplier = pow(2, retryCount);
                // Use Duration multiplication
                final calculatedWait = baseBackoffDuration * backoffMultiplier;
                final nextRetryTime = lastAttemptTime.add(calculatedWait);

                // Eligible if current time is after the next calculated retry time
                return now.isAfter(nextRetryTime);
              })
              .map((model) => JobMapper.fromHiveModel(model))
              .toList();

      _logger.d('$_tag Found ${retryableJobs.length} jobs eligible for retry.');
      return retryableJobs;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get jobs eligible for retry from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get jobs to retry: ${e.toString()}');
    }
  }
}
