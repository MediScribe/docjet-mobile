import 'package:dartz/dartz.dart'; // Import dartz
import 'package:docjet_mobile/core/error/exceptions.dart'; // For potential exceptions
import 'package:docjet_mobile/core/error/failures.dart'; // Import Failure
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import Logger
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart'; // Import needed for static calls
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
// import 'package:docjet_mobile/core/network/network_info.dart'; // Removed
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource remoteDataSource;
  final JobLocalDataSource localDataSource;
  // final JobMapper mapper; // REMOVED - Mapper methods are static
  // final NetworkInfo networkInfo; // Removed

  // Logger instance
  final Logger _logger = LoggerFactory.getLogger(JobRepositoryImpl);
  static final String _tag = logTag(JobRepositoryImpl);

  // --- ADDED: Staleness threshold ---
  final Duration stalenessThreshold;

  JobRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    // Default staleness to 1 hour if not provided
    this.stalenessThreshold = const Duration(hours: 1),
    // required this.mapper, // REMOVED
    // required this.networkInfo, // Removed
  });

  @override
  Future<Either<Failure, List<Job>>> getJobs() async {
    try {
      // 1. Try fetching from local cache first
      _logger.i('$_tag Attempting to fetch jobs from local cache...');
      final localHiveModels = await localDataSource.getAllJobHiveModels();

      // 2. Check if cache has data AND if it's fresh
      if (localHiveModels.isNotEmpty) {
        _logger.i(
          '$_tag Cache hit with ${localHiveModels.length} items. Checking freshness...',
        );
        // --- ADDED: Staleness check ---
        final lastFetchTime = await localDataSource.getLastFetchTime();
        if (lastFetchTime != null &&
            DateTime.now().difference(lastFetchTime) <= stalenessThreshold) {
          _logger.i('$_tag Cache is fresh. Returning local data.');
          // Map HiveModels to Job Entities and return
          final localJobs = JobMapper.fromHiveModelList(localHiveModels);
          return Right(localJobs);
        } else {
          _logger.i(
            '$_tag Cache is stale (last fetch: $lastFetchTime) or fetch time unknown. Fetching remote.',
          );
          // Proceed to fetch from remote if cache is stale or timestamp is missing
          return await _getJobsFromRemote();
        }
        // --- END: Staleness check ---
      } else {
        _logger.i(
          '$_tag Cache miss or empty. Proceeding to fetch from remote.',
        );
        // Proceed to fetch from remote if cache is empty
        return await _getJobsFromRemote();
      }
    } on CacheException catch (e) {
      _logger.w('$_tag Cache read error: $e. Proceeding to fetch from remote.');
      // If cache read fails, fallback to remote fetch
      return await _getJobsFromRemote();
    }
    // Removed the outer try-catch for remote exceptions, handled in _getJobsFromRemote
  }

  /// Helper function to fetch jobs from remote, save to cache, and return.
  /// This contains the logic previously in the main try block of getJobs.
  Future<Either<Failure, List<Job>>> _getJobsFromRemote() async {
    _logger.i('$_tag Fetching jobs from remote data source...');
    try {
      // 1. Fetch from remote
      final remoteJobs = await remoteDataSource.fetchJobs();
      _logger.i(
        '$_tag Successfully fetched ${remoteJobs.length} jobs from remote.',
      );

      // 2. Map to Hive Models (using static mapper)
      final hiveModels = JobMapper.toHiveModelList(remoteJobs);

      // 3. Try to save jobs to local cache (log warning on failure)
      try {
        _logger.i('$_tag Saving ${hiveModels.length} jobs to local cache...');
        await localDataSource.saveJobHiveModels(hiveModels);
        _logger.i('$_tag Successfully saved jobs to cache.');
      } on CacheException catch (e) {
        // Log the cache write failure as a warning but don't fail the operation
        _logger.w('$_tag Failed to save jobs to cache: $e');
      }

      // --- ADDED: Always try save fetch time after successful remote fetch ---
      try {
        await localDataSource.saveLastFetchTime(DateTime.now());
        _logger.i('$_tag Successfully saved fetch time to cache.');
      } on CacheException catch (e) {
        _logger.w('$_tag Failed to save fetch time to cache: $e');
      }

      // 4. Return success with fetched data
      return Right(remoteJobs);
    } on ServerException catch (e) {
      _logger.e('$_tag ServerException during remote fetch: ${e.message}');
      return Left(
        ServerFailure(message: e.message ?? 'An unknown server error occurred'),
      );
    } on ApiException catch (e) {
      _logger.e(
        '$_tag ApiException during remote fetch: ${e.message}, Status: ${e.statusCode}',
      );
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during remote fetch: ${e.toString()}', // Only pass message
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        ServerFailure(message: 'An unexpected error occurred: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Job>> getJobById(String id) async {
    // TODO: Implement later
    return Left(ServerFailure(message: 'getJobById not implemented'));
  }

  @override
  Future<Either<Failure, Job>> createJob({
    // Parameters MUST match the JobRepository interface
    // required String userId, // REMOVED - Not in interface
    required String audioFilePath,
    String? text,
    // String? additionalText, // REMOVED - Not in interface
  }) async {
    // TODO: Implement later
    return Left(ServerFailure(message: 'createJob not implemented'));
  }

  Future<Either<Failure, Job>> updateJob({
    required String jobId,
    required Map<String, dynamic> updates,
  }) async {
    // TODO: Implement later
    return Left(ServerFailure(message: 'updateJob not implemented'));
  }

  @override
  Future<Either<Failure, void>> syncPendingJobs() async {
    // TODO: Implement sync logic based on the test
    // Placeholder implementation to satisfy the interface and initial test setup
    _logger.i('$_tag syncPendingJobs called - Placeholder Implementation');
    try {
      // 1. Get pending jobs
      final pendingHiveModels = await localDataSource.getJobsToSync();
      _logger.d(
        '$_tag Found ${pendingHiveModels.length} jobs pending sync locally.',
      );

      if (pendingHiveModels.isEmpty) {
        _logger.i('$_tag No pending jobs to sync. Exiting.');
        return const Right(unit); // Nothing to do
      }

      // 2. Map to Job entities for remote sync
      final jobsToSync = JobMapper.fromHiveModelList(pendingHiveModels);

      // 3. Call remote sync (currently mocked in test)
      // In real implementation, this would involve try/catch for Server/ApiExceptions
      _logger.d(
        '$_tag Attempting to sync ${jobsToSync.length} jobs with remote...',
      );
      final syncedJobs = await remoteDataSource.syncJobs(jobsToSync);
      _logger.i(
        '$_tag Remote sync successful. Received ${syncedJobs.length} updated jobs.',
      );

      // 4. Update local status and save updated job data (handle potential errors)
      // This simple version assumes full success and updates all
      for (final syncedJob in syncedJobs) {
        try {
          // Save the potentially updated job data from the server
          final syncedHiveModel = JobMapper.toHiveModel(syncedJob);
          await localDataSource.saveJobHiveModel(syncedHiveModel);

          // Update sync status to synced *after* saving
          await localDataSource.updateJobSyncStatus(
            syncedJob.id, // Use ID from the synced job entity
            SyncStatus.synced,
          );
          _logger.d(
            '$_tag Updated local status to synced for job ${syncedJob.id}.',
          );
        } catch (e, stackTrace) {
          _logger.e(
            '$_tag Error updating local status/data for synced job ${syncedJob.id}: $e',
            error: e,
            stackTrace: stackTrace,
          );
          // Decide how to handle partial failures. For now, just log and continue.
          // Could potentially mark this specific job with SyncStatus.error
        }
      }

      _logger.i('$_tag syncPendingJobs completed successfully.');
      return const Right(unit);
    } on ApiException catch (e) {
      _logger.e(
        '$_tag ApiException during sync: ${e.message}, Status: ${e.statusCode}',
      );
      // Depending on the error, might need to mark jobs as error
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      _logger.e('$_tag ServerException during sync: ${e.message}');
      return Left(ServerFailure(message: e.message ?? 'Sync failed'));
    } on CacheException catch (e) {
      _logger.e('$_tag CacheException during sync process: ${e.toString()}');
      return Left(CacheFailure('Cache error during sync: ${e.toString()}'));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during syncPendingJobs: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        ServerFailure(message: 'An unexpected error occurred during sync'),
      );
    }
  }
}
