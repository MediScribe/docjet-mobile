import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
// import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart'; // Unused
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Service class for job read operations
class JobReaderService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  final JobDeleterService _deleterService;
  final NetworkInfo _networkInfo;
  final Logger _logger = Logger();

  static final String _tag = logTag(JobReaderService);

  JobReaderService({
    required JobLocalDataSource localDataSource,
    required JobRemoteDataSource remoteDataSource,
    required JobDeleterService deleterService,
    required NetworkInfo networkInfo,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _deleterService = deleterService,
       _networkInfo = networkInfo;

  Future<Either<Failure, List<Job>>> getJobs() async {
    _logger.d('$_tag Getting jobs...');

    if (!await _networkInfo.isConnected) {
      _logger.i('$_tag Network offline, returning only local jobs.');
      try {
        // Fetch using the entity-based method if available, fallback to hive models
        // Assuming getJobs() is the preferred method now.
        final localJobs = await _localDataSource.getJobs();
        return Right(localJobs);
      } on CacheException catch (e) {
        _logger.w(
          '$_tag CacheException fetching local jobs while offline: ${e.message}',
        );
        return Left(
          CacheFailure(e.message ?? 'Failed to get local jobs while offline'),
        );
      }
    }

    // --- Online Path ---
    _logger.d(
      '$_tag Network online, fetching remote jobs and checking for server deletions.',
    );
    try {
      // 1. Get LOCAL jobs that are marked as SYNCED (candidates for server deletion)
      List<Job> localSyncedJobs;
      try {
        localSyncedJobs = await _localDataSource.getJobsByStatus(
          SyncStatus.synced,
        );
        _logger.d(
          '$_tag Found ${localSyncedJobs.length} local jobs marked as synced using getJobsByStatus.',
        );
      } on CacheException catch (e) {
        // If we can't get local synced jobs, we cannot reliably proceed with online sync/deletion check.
        _logger.w(
          '$_tag CacheException fetching synced local jobs: ${e.message}. Aborting online sync.',
        );
        // FIX: Return CacheFailure immediately if this critical step fails.
        return Left(
          CacheFailure(
            e.message ?? 'Failed to fetch local synced jobs for deletion check',
          ),
        );
      }

      // 2. Fetch remote jobs (Source of Truth)
      final remoteJobs = await _remoteDataSource.fetchJobs();
      _logger.d('$_tag Fetched ${remoteJobs.length} jobs from remote.');

      // 3. Identify server-deleted jobs (only if localSyncedJobs were fetched)
      final List<Job> serverDeletedJobs = [];
      if (localSyncedJobs.isNotEmpty) {
        final remoteServerIds =
            remoteJobs.map((j) => j.serverId).where((id) => id != null).toSet();
        for (final localJob in localSyncedJobs) {
          if (localJob.serverId != null &&
              !remoteServerIds.contains(localJob.serverId)) {
            serverDeletedJobs.add(localJob);
          }
        }
      }

      // 4. Permanently delete server-deleted jobs locally
      if (serverDeletedJobs.isNotEmpty) {
        _logger.i(
          '$_tag Found ${serverDeletedJobs.length} jobs deleted on server. Removing locally...',
        );
        for (final jobToDelete in serverDeletedJobs) {
          _logger.d(
            '$_tag Triggering permanent local deletion for job ${jobToDelete.localId} (Server ID: ${jobToDelete.serverId})',
          );
          final deleteResult = await _deleterService.permanentlyDeleteJob(
            jobToDelete.localId,
          );
          deleteResult.fold(
            (failure) => _logger.e(
              '$_tag Failed to locally delete server-deleted job ${jobToDelete.localId}: $failure',
            ),
            (_) => _logger.i(
              '$_tag Successfully locally deleted server-deleted job ${jobToDelete.localId}.',
            ),
          );
        }
      } else {
        _logger.d('$_tag No server-side deletions detected.');
      }

      // 5. Cache the fetched remote jobs locally
      _logger.d(
        '$_tag Caching ${remoteJobs.length} fetched remote jobs locally...',
      );
      int savedCount = 0;
      for (final remoteJob in remoteJobs) {
        try {
          await _localDataSource.saveJob(remoteJob);
          savedCount++;
        } on CacheException catch (e) {
          _logger.w(
            '$_tag CacheException saving job ${remoteJob.localId} to local cache: ${e.message}. Skipping this job.',
          );
        }
      }
      _logger.d(
        '$_tag Successfully cached $savedCount out of ${remoteJobs.length} remote jobs.',
      );

      // 6. Return the list fetched from the remote source
      _logger.d('$_tag Returning ${remoteJobs.length} remote jobs as result.');
      return Right(remoteJobs);
    } on ApiException catch (e) {
      _logger.e('$_tag API Exception fetching remote jobs: $e');
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e, stacktrace) {
      // Catch-all for other unexpected errors during the online path
      _logger.e(
        '$_tag Unexpected error in getJobs (Online Path): $e\n$stacktrace',
      );
      return Left(UnknownFailure('Unexpected error getting jobs: $e'));
    }
  }

  Future<Either<Failure, Job>> getJobById(String localId) async {
    _logger.d('$_tag Getting job by ID: $localId');
    try {
      // Use the entity-based method
      final job = await _localDataSource.getJobById(localId);
      return Right(job);
    } on CacheException catch (e) {
      // CacheException from getJobById likely means not found or DB error
      _logger.w('$_tag CacheException getting job $localId: ${e.message}');
      return Left(
        CacheFailure(
          e.message ?? 'Job with ID $localId not found or cache error',
        ),
      );
    } catch (e, stacktrace) {
      _logger.e(
        '$_tag Unexpected error in getJobById($localId): $e\n$stacktrace',
      );
      return Left(UnknownFailure('Unexpected error getting job by ID: $e'));
    }
  }

  Future<Either<Failure, List<Job>>> getJobsByStatus(SyncStatus status) async {
    _logger.d('$_tag Getting jobs by status: $status');
    try {
      // Use the entity-based method directly
      final filteredJobs = await _localDataSource.getJobsByStatus(status);
      return Right(filteredJobs);
    } on CacheException catch (e) {
      _logger.w(
        '$_tag CacheException getting jobs by status $status: ${e.message}',
      );
      return Left(CacheFailure(e.message ?? 'Failed to get jobs by status'));
    } catch (e, stacktrace) {
      _logger.e(
        '$_tag Unexpected error in getJobsByStatus($status): $e\n$stacktrace',
      );
      return Left(
        UnknownFailure('Unexpected error getting jobs by status: $e'),
      );
    }
  }

  // --- Stream Operations ---

  /// Watches the local data source for changes to the list of all jobs.
  Stream<Either<Failure, List<Job>>> watchJobs() {
    _logger.d('$_tag Delegating watchJobs to local data source...');
    try {
      return _localDataSource.watchJobs();
    } catch (e, stacktrace) {
      _logger.e(
        '$_tag Unexpected error initiating watchJobs stream: $e\n$stacktrace',
      );
      // Return a stream that emits a single error
      return Stream.value(
        Left(CacheFailure('Failed to start watching jobs: ${e.toString()}')),
      );
    }
  }

  /// Watches the local data source for changes to a specific job.
  Stream<Either<Failure, Job?>> watchJobById(String localId) {
    _logger.d(
      '$_tag Delegating watchJobById($localId) to local data source...',
    );
    try {
      return _localDataSource.watchJobById(localId);
    } catch (e, stacktrace) {
      _logger.e(
        '$_tag Unexpected error initiating watchJobById($localId) stream: $e\n$stacktrace',
      );
      // Return a stream that emits a single error
      return Stream.value(
        Left(
          CacheFailure(
            'Failed to start watching job $localId: ${e.toString()}',
          ),
        ),
      );
    }
  }
}
