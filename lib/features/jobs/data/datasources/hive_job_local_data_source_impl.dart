import 'package:hive/hive.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging helpers
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'; // Import SyncStatus
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart'; // Import Job entity
import 'package:dartz/dartz.dart'; // Import dartz for Unit

class HiveJobLocalDataSourceImpl implements JobLocalDataSource {
  final HiveInterface hive;
  // Add logger instance
  final Logger _logger = LoggerFactory.getLogger(HiveJobLocalDataSourceImpl);
  // Define log tag
  static final String _tag = logTag(HiveJobLocalDataSourceImpl);

  // Define a constant for the box name
  static const String jobsBoxName = 'jobs';
  // --- ADDED: Key for storing the last fetch timestamp ---
  static const String lastFetchTimestampKey =
      'lastFetchTimestamp'; // Corrected key name

  HiveJobLocalDataSourceImpl({required this.hive});

  // Helper function to safely open and return the box
  // --- MODIFIED: Returns Box<dynamic> to allow storing timestamp ---
  Future<Box<dynamic>> _getOpenBox() async {
    _logger.d('$_tag Attempting to open Hive box: $jobsBoxName');
    try {
      if (!hive.isBoxOpen(jobsBoxName)) {
        _logger.i('$_tag Box "$jobsBoxName" not open, opening...');
        // Open as Box<dynamic> to accommodate both JobHiveModel and the timestamp (int)
        final box = await hive.openBox<dynamic>(jobsBoxName);
        _logger.i('$_tag Box "$jobsBoxName" opened successfully.');
        return box;
      }
      _logger.d('$_tag Box "$jobsBoxName" already open.');
      return hive.box<dynamic>(jobsBoxName);
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to open Hive box: $jobsBoxName',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to open Hive box: ${e.toString()}');
    }
  }

  @override
  Future<List<JobHiveModel>> getAllJobHiveModels() async {
    _logger.d('$_tag getAllJobHiveModels called');
    try {
      // Use the general box
      final box = await _getOpenBox();
      // Filter out non-JobHiveModel entries (like our timestamp)
      final models = box.values.whereType<JobHiveModel>().toList();
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
      // Use the general box
      final box = await _getOpenBox();
      // Get the value and check its type
      final value = box.get(id);
      if (value is JobHiveModel) {
        _logger.d('$_tag Found job model with id: $id in cache.');
        return value;
      } else if (value != null) {
        // Log if the key exists but isn't a JobHiveModel (e.g., it's the timestamp)
        _logger.w(
          '$_tag Value found for id: $id, but it is not a JobHiveModel (Type: ${value.runtimeType}). Returning null.',
        );
        return null;
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
      // Use the general box because we are writing a JobHiveModel
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
  Future<bool> saveJobHiveModels(List<JobHiveModel> models) async {
    _logger.d('$_tag saveJobHiveModels called with ${models.length} models.');
    try {
      final box = await _getOpenBox();

      // Fix the type issue by using more explicit Map<String, dynamic>
      final Map<String, JobHiveModel> modelsMap = {
        for (var model in models) model.localId: model,
      };

      await box.putAll(modelsMap);
      _logger.d('$_tag Saved ${models.length} job models to cache.');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save ${models.length} job models to cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to save job models to cache');
    }
  }

  @override
  Future<void> deleteJobHiveModel(String id) async {
    _logger.d('$_tag deleteJobHiveModel called for id: $id');
    try {
      // Use the general box
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

  @override
  Future<void> clearAllJobHiveModels() async {
    _logger.d('$_tag clearAllJobHiveModels called');
    try {
      // Use the general box
      final box = await _getOpenBox();
      // Save the timestamp before clearing if it exists
      final timestamp = box.get(lastFetchTimestampKey);
      final count = await box.clear();
      // Restore the timestamp if it existed
      if (timestamp != null) {
        await box.put(lastFetchTimestampKey, timestamp);
        _logger.i(
          '$_tag Cleared Hive box "$jobsBoxName", removed ${count - 1} job entries and restored timestamp.',
        );
      } else {
        _logger.i(
          '$_tag Cleared Hive box "$jobsBoxName", removed $count entries.',
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to clear Hive box "$jobsBoxName"',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to clear jobs box: ${e.toString()}');
    }
  }

  @override
  Future<JobHiveModel?> getLastJobHiveModel() async {
    _logger.d('$_tag getLastJobHiveModel called');
    try {
      // Use general box
      final box = await _getOpenBox();
      // Filter out non-JobHiveModel entries before processing
      final jobs = box.values.whereType<JobHiveModel>().toList();
      if (jobs.isEmpty) {
        _logger.d('$_tag No jobs found in cache for getLastJobHiveModel.');
        return null;
      }
      _logger.d(
        '$_tag Found ${jobs.length} jobs, iterating to find the most recent...',
      );

      // Iterate to find the job with the maximum updatedAt timestamp
      JobHiveModel lastJob = jobs[0]; // Initialize with the first element
      for (int i = 1; i < jobs.length; i++) {
        // Parse the date strings to DateTime objects for comparison
        final currentDate = DateTime.tryParse(jobs[i].updatedAt ?? '');
        final lastDate = DateTime.tryParse(lastJob.updatedAt ?? '');

        // Only compare if both dates are valid
        if (currentDate != null &&
            lastDate != null &&
            currentDate.isAfter(lastDate)) {
          lastJob = jobs[i];
        }
      }

      _logger.d(
        '$_tag Last job found with id: ${lastJob.localId}, updatedAt: ${lastJob.updatedAt}',
      );
      return lastJob;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get last job model from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get last job: ${e.toString()}');
    }
  }

  @override
  Future<DateTime?> getLastFetchTime() async {
    _logger.d('$_tag getLastFetchTime called');
    try {
      final box = await _getOpenBox();
      final value = box.get(lastFetchTimestampKey);
      if (value == null) {
        _logger.d('$_tag No last fetch timestamp found in cache.');
        return null;
      }
      if (value is int) {
        _logger.d('$_tag Found last fetch timestamp: $value');
        return DateTime.fromMillisecondsSinceEpoch(value);
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
      final box = await _getOpenBox();
      // --- FIXED: Convert to UTC before getting milliseconds ---
      final millis = time.toUtc().millisecondsSinceEpoch;
      await box.put(lastFetchTimestampKey, millis);
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

  // --- Sync Status Methods --- //

  @override
  Future<List<JobHiveModel>> getJobsToSync() async {
    _logger.d('$_tag getJobsToSync called');
    try {
      final box = await _getOpenBox();
      final pendingJobs =
          box.values
              .whereType<JobHiveModel>()
              .where(
                (job) => job.syncStatus == SyncStatus.pending.index,
              ) // Compare with index
              .toList();
      _logger.d('$_tag Found ${pendingJobs.length} jobs pending sync.');
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
    Box<dynamic>? box; // Declare box outside try for use in catch
    try {
      box = await _getOpenBox(); // Assign inside try
      final value = box.get(id);

      if (value is JobHiveModel) {
        _logger.d('$_tag Found job model with id: $id for status update.');
        value.syncStatus = status.index; // Assign the index, not the enum
        // --- FIXED: Check isInBox and use put as fallback ---
        if (value.isInBox) {
          await value.save(); // Use HiveObject's save method if in box
          _logger.i(
            '$_tag Updated sync status for job $id to $status using model.save().',
          );
        } else {
          // Fallback if model isn't properly associated with the box
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
        // --- FIXED: Standardized error message ---
        throw CacheException('Job with id $id not found.');
      }
    } catch (e, stackTrace) {
      // --- FIXED: Removed redundant CacheException check/rethrow ---
      // Log the specific error encountered
      _logger.e(
        '$_tag Failed to update sync status for job id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      // --- FIXED: Standardized error message ---
      // Wrap original error message for context if it's not the one we threw
      final originalMessage = (e is CacheException) ? e.message : e.toString();
      throw CacheException(
        'Failed to update job sync status for $id: $originalMessage',
      );
    }
  }

  @override
  Future<List<JobHiveModel>> getSyncedJobHiveModels() async {
    _logger.d('$_tag getSyncedJobHiveModels called');
    try {
      final box = await _getOpenBox();
      final syncedModels =
          box.values.whereType<JobHiveModel>().where((model) {
            // Check if serverId is not null AND syncStatus is synced
            return model.serverId != null &&
                model.syncStatus == SyncStatus.synced.index;
          }).toList();
      _logger.d(
        '$_tag Found ${syncedModels.length} models with SyncStatus.synced and non-null serverId.',
      );
      return syncedModels;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get synced job models from cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to get synced job models: ${e.toString()}');
    }
  }

  // --- Methods operating on Job Entity (New Style) ---

  @override
  Future<Job> getJobById(String localId) async {
    _logger.d('$_tag getJobById (New Style) called for id: $localId');
    // TODO: Implement mapping from JobHiveModel to Job
    // For now, just throw unimplemented as the implementation needs thought
    throw UnimplementedError(
      'getJobById needs proper implementation with mapping',
    );
  }

  @override
  Future<Unit> saveJob(Job job) async {
    _logger.d('$_tag saveJob (New Style) called for id: ${job.localId}');
    // TODO: Implement mapping from Job to JobHiveModel
    // For now, just throw unimplemented as the implementation needs thought
    throw UnimplementedError(
      'saveJob needs proper implementation with mapping',
    );
  }

  @override
  Future<Unit> deleteJob(String localId) async {
    _logger.d('$_tag deleteJob (New Style) called for id: $localId');
    // TODO: Implement deletion logic, likely using existing deleteJobHiveModel
    throw UnimplementedError('deleteJob needs proper implementation');
  }

  @override
  Future<List<Job>> getJobsByStatus(SyncStatus status) async {
    _logger.d('$_tag getJobsByStatus (New Style) called for status: $status');
    // TODO: Implement logic to filter by status and map to Job entities
    throw UnimplementedError('getJobsByStatus needs proper implementation');
  }
}
