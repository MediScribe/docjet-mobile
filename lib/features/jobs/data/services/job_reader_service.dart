import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/sync_status.dart';
import '../datasources/job_local_data_source.dart';
import '../datasources/job_remote_data_source.dart';
import '../mappers/job_mapper.dart';

/// Service class for job read operations
class JobReaderService {
  final JobLocalDataSource _localDataSource;

  JobReaderService({
    required JobLocalDataSource localDataSource,
    required JobRemoteDataSource remoteDataSource,
  }) : _localDataSource = localDataSource;

  Future<Either<Failure, List<Job>>> getJobs() async {
    try {
      // 1. Get Hive models from local source
      final localHiveModels = await _localDataSource.getAllJobHiveModels();
      // 2. Map Hive models to Job entities
      final localJobs = JobMapper.fromHiveModelList(localHiveModels);
      // NOTE: Per discussion, remote fetch logic is handled elsewhere.
      // This service simply fetches from local and maps.
      return Right(localJobs);
    } on CacheException {
      return Left(CacheFailure());
    } catch (e) {
      // Catching generic Exception as a fallback
      // TODO: Consider more specific error handling if needed
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, Job>> getJobById(String localId) async {
    try {
      final hiveModel = await _localDataSource.getJobHiveModelById(localId);
      if (hiveModel == null) {
        return Left(CacheFailure('Job with ID $localId not found'));
      }
      final job = JobMapper.fromHiveModel(hiveModel);
      return Right(job);
    } on CacheException {
      return Left(CacheFailure());
    } catch (e) {
      // Catching generic Exception as a fallback
      return Left(CacheFailure(e.toString()));
    }
  }

  // TODO: Implement getJobsByStatus if needed by the plan
  Future<Either<Failure, List<Job>>> getJobsByStatus(SyncStatus status) async {
    try {
      // 1. Get ALL Hive models from local source
      final allHiveModels = await _localDataSource.getAllJobHiveModels();
      // 2. Filter by the provided sync status
      final filteredHiveModels =
          allHiveModels
              .where((model) => model.syncStatus == status.index)
              .toList();
      // 3. Map the filtered Hive models to Job entities
      final filteredJobs = JobMapper.fromHiveModelList(filteredHiveModels);
      return Right(filteredJobs);
    } on CacheException {
      return Left(CacheFailure());
    } catch (e) {
      // Catching generic Exception as a fallback
      return Left(CacheFailure(e.toString()));
    }
  }
}
