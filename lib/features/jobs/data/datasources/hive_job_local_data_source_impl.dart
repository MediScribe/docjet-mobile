import 'package:hive/hive.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';

class HiveJobLocalDataSourceImpl implements JobLocalDataSource {
  final HiveInterface hive;

  // Define a constant for the box name
  static const String jobsBoxName = 'jobs';

  HiveJobLocalDataSourceImpl({required this.hive});

  // Helper function to safely open and return the box
  Future<Box<JobHiveModel>> _getOpenBox() async {
    try {
      if (!hive.isBoxOpen(jobsBoxName)) {
        return await hive.openBox<JobHiveModel>(jobsBoxName);
      }
      return hive.box<JobHiveModel>(jobsBoxName);
    } catch (e) {
      // Log the error e?
      throw CacheException('Failed to open Hive box: ${e.toString()}');
    }
  }

  @override
  Future<List<JobHiveModel>> getAllJobHiveModels() async {
    try {
      final box = await _getOpenBox();
      return box.values.toList();
    } catch (e) {
      throw CacheException('Failed to get all jobs: ${e.toString()}');
    }
  }

  @override
  Future<JobHiveModel?> getJobHiveModelById(String id) async {
    try {
      final box = await _getOpenBox();
      return box.get(id);
    } catch (e) {
      throw CacheException('Failed to get job by ID: ${e.toString()}');
    }
  }

  @override
  Future<void> saveJobHiveModel(JobHiveModel model) async {
    try {
      final box = await _getOpenBox();
      await box.put(model.id, model);
    } catch (e) {
      throw CacheException('Failed to save job: ${e.toString()}');
    }
  }

  @override
  Future<void> saveJobHiveModels(List<JobHiveModel> models) async {
    try {
      final box = await _getOpenBox();
      // Convert list to map for putAll
      final Map<String, JobHiveModel> modelMap = {
        for (var model in models) model.id: model,
      };
      await box.putAll(modelMap);
    } catch (e) {
      throw CacheException('Failed to save multiple jobs: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteJobHiveModel(String id) async {
    try {
      final box = await _getOpenBox();
      await box.delete(id);
    } catch (e) {
      throw CacheException('Failed to delete job: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllJobHiveModels() async {
    try {
      final box = await _getOpenBox();
      await box.clear(); // Returns the number of entries cleared, await it.
    } catch (e) {
      throw CacheException('Failed to clear jobs box: ${e.toString()}');
    }
  }

  @override
  Future<JobHiveModel?> getLastJobHiveModel() async {
    try {
      final box = await _getOpenBox();
      final jobs = box.values.toList();
      if (jobs.isEmpty) {
        return null;
      }
      // Sort by updatedAt descending and return the first one
      jobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return jobs.first;
    } catch (e) {
      throw CacheException('Failed to get last job: ${e.toString()}');
    }
  }
}
