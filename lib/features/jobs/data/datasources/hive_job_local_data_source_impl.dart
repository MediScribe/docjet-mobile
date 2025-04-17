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

  HiveJobLocalDataSourceImpl({required this.hive});

  // Helper function to safely open and return the box
  Future<Box<JobHiveModel>> _getOpenBox() async {
    _logger.d('$_tag Attempting to open Hive box: $jobsBoxName');
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
      final model = box.get(id);
      if (model == null) {
        _logger.w('$_tag Job model with id: $id not found in cache.');
      } else {
        _logger.d('$_tag Found job model with id: $id in cache.');
      }
      return model;
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
      final box = await _getOpenBox();
      // Convert list to map for putAll
      final Map<String, JobHiveModel> modelMap = {
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
      final box = await _getOpenBox();
      final count = await box.clear();
      _logger.i(
        '$_tag Cleared Hive box "$jobsBoxName", removed $count entries.',
      );
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
    // TODO: Performance Warning: This loads ALL jobs into memory and sorts them.
    // This could become very slow if the number of cached jobs becomes large.
    // Consider alternative strategies if performance becomes an issue, such as:
    // 1. Storing the ID of the last updated job separately.
    // 2. Using a different local storage solution that supports indexing/querying.
    try {
      final box = await _getOpenBox();
      final jobs = box.values.toList();
      if (jobs.isEmpty) {
        _logger.d('$_tag No jobs found in cache for getLastJobHiveModel.');
        return null;
      }
      _logger.d(
        '$_tag Found ${jobs.length} jobs, sorting to find the last one...',
      );
      // Sort by updatedAt descending and return the first one
      jobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final lastJob = jobs.first;
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
}
