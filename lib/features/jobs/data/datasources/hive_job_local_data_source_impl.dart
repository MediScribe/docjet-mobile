import 'package:hive/hive.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging helpers

class HiveJobLocalDataSourceImpl implements JobLocalDataSource {
  final HiveInterface hive;
  // Add logger instance
  final Logger _logger = LoggerFactory.getLogger(HiveJobLocalDataSourceImpl);
  // Define log tag
  static final String _tag = logTag(HiveJobLocalDataSourceImpl);

  // Define a constant for the box name
  static const String jobsBoxName = 'jobs';
  // --- ADDED: Key for storing the last fetch timestamp ---
  static const String _lastFetchTimestampKey = 'lastFetchTimestamp';

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
    _logger.d('$_tag saveJobHiveModel called for id: ${model.id}');
    try {
      // Use the general box because we are writing a JobHiveModel
      final box = await _getOpenBox();
      await box.put(model.id, model);
      _logger.i('$_tag Saved job model with id: ${model.id} to cache.');
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save job model with id: ${model.id} to cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to save job: ${e.toString()}');
    }
  }

  @override
  Future<void> saveJobHiveModels(List<JobHiveModel> models) async {
    final count = models.length;
    _logger.d('$_tag saveJobHiveModels called with $count models.');
    if (models.isEmpty) {
      _logger.w(
        '$_tag saveJobHiveModels called with empty list, doing nothing.',
      );
      return;
    }
    try {
      // Use the general box
      final box = await _getOpenBox();
      // Convert list to map for putAll
      final Map<dynamic, dynamic> modelMap = {
        for (var model in models) model.id: model,
      };
      await box.putAll(modelMap);
      _logger.i('$_tag Saved $count job models to cache.');
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save $count job models to cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to save multiple jobs: ${e.toString()}');
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
      final timestamp = box.get(_lastFetchTimestampKey);
      final count = await box.clear();
      // Restore the timestamp if it existed
      if (timestamp != null) {
        await box.put(_lastFetchTimestampKey, timestamp);
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
        if (jobs[i].updatedAt.isAfter(lastJob.updatedAt)) {
          lastJob = jobs[i];
        }
      }

      _logger.d(
        '$_tag Last job found with id: ${lastJob.id}, updatedAt: ${lastJob.updatedAt}',
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
      final dynamic value = box.get(_lastFetchTimestampKey);

      // --- MODIFIED: Type check before using ---
      if (value is int) {
        final timestampMillis = value;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestampMillis,
          isUtc: true,
        );
        _logger.d('$_tag Found last fetch timestamp: $dateTime');
        return dateTime;
      } else if (value == null) {
        _logger.w('$_tag Last fetch timestamp not found in cache.');
        return null;
      } else {
        // Value exists but is not an int
        _logger.w(
          '$_tag Invalid type found for last fetch timestamp: ${value.runtimeType}. Expected int. Returning null.',
        );
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get last fetch timestamp from cache',
        error: e,
        stackTrace: stackTrace,
      );
      // Added check for HiveError related to adapter registration
      if (e is HiveError && e.message.contains('Type adapter not registered')) {
        _logger.w(
          '$_tag Hint: Possible cause - Box opened with wrong type or adapter missing. Ensure Box is opened as Box<dynamic>.',
        );
      }
      throw CacheException('Failed to get last fetch time: ${e.toString()}');
    }
  }

  @override
  Future<void> saveLastFetchTime(DateTime time) async {
    _logger.d('$_tag saveLastFetchTime called with time: $time');
    try {
      final box = await _getOpenBox();
      final timestampMillis = time.toUtc().millisecondsSinceEpoch;
      await box.put(_lastFetchTimestampKey, timestampMillis);
      _logger.i(
        '$_tag Saved last fetch timestamp ($timestampMillis) to cache.',
      );
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to save last fetch timestamp to cache',
        error: e,
        stackTrace: stackTrace,
      );
      throw CacheException('Failed to save last fetch time: ${e.toString()}');
    }
  }
}
