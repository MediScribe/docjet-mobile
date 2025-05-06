import 'dart:async'; // Import async for StreamTransformer
import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart'; // Now actively used
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart'; // Add import for JobApiDTO
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Service class for job read operations
class JobReaderService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  final JobDeleterService _deleterService;
  final NetworkInfo _networkInfo;
  final Logger _logger = LoggerFactory.getLogger(JobReaderService);

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
        _logger.d('$_tag Returning ${localJobs.length} local jobs (offline).');
        return Right(localJobs);
      } on CacheException catch (e, stackTrace) {
        _logger.w(
          '$_tag CacheException fetching local jobs while offline: ${e.message}',
          error: e,
          stackTrace: stackTrace,
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
      _logger.d('$_tag Step 1: Fetching local jobs with SyncStatus.synced...');
      List<Job> localSyncedJobs;
      try {
        localSyncedJobs = await _localDataSource.getJobsByStatus(
          SyncStatus.synced,
        );
        _logger.d(
          '$_tag Found ${localSyncedJobs.length} local jobs marked as synced.',
        );
        if (localSyncedJobs.isNotEmpty && localSyncedJobs.length <= 10) {
          final ids = localSyncedJobs
              .map((j) => '(${j.localId} / ${j.serverId})')
              .join(', ');
          _logger.d('$_tag    Local Synced Job IDs (local/server): $ids');
        }
        // For large data sets, only log count to avoid log spam
        else if (localSyncedJobs.isNotEmpty) {
          _logger.d(
            '$_tag    Only logging count for >10 entries to avoid log spam',
          );
        }
      } on CacheException catch (e, stackTrace) {
        _logger.w(
          '$_tag CacheException fetching synced local jobs: ${e.message}. Aborting online sync.',
          error: e,
          stackTrace: stackTrace,
        );
        return Left(
          CacheFailure(
            e.message ?? 'Failed to fetch local synced jobs for deletion check',
          ),
        );
      }

      // 2. Fetch remote jobs (Source of Truth)
      _logger.d('$_tag Step 2: Fetching remote jobs from API...');
      final List<JobApiDTO> remoteDtos = await _remoteDataSource.fetchJobs();
      _logger.d('$_tag Fetched ${remoteDtos.length} job DTOs from remote.');

      // 3. Build server-to-local ID mapping
      // TODO: Critical architectural component - Server/Local ID Mapping System
      // This mapping is crucial for maintaining the dual-ID system where:
      // 1. Each job has a stable localId (UUID) used throughout the app
      // 2. Each synced job also has a serverId assigned by the backend
      // The mapping ensures we don't create duplicate local entities when
      // fetching from the API, but instead update existing entities while
      // preserving their localIds. This avoids the previous bug where
      // jobs were created with empty localIds that broke UI callbacks.
      _logger.d('$_tag Step 3: Building server-to-local ID mapping...');
      final Map<String, String> serverIdToLocalIdMap = {};

      // First, populate map from local synced jobs
      _logger.d(
        '$_tag   Examining ${localSyncedJobs.length} local jobs for server-to-local ID mapping',
      );
      int mappedCount = 0;
      for (final localJob in localSyncedJobs) {
        if (localJob.serverId != null && localJob.serverId!.isNotEmpty) {
          serverIdToLocalIdMap[localJob.serverId!] = localJob.localId;
          mappedCount++;
          _logger.d(
            '$_tag   Mapped server ID ${localJob.serverId} to local ID ${localJob.localId}',
          );
        } else {
          _logger.d(
            '$_tag   Skipping job ${localJob.localId} - no server ID available for mapping',
          );
        }
      }
      _logger.d('$_tag   Created mapping with $mappedCount entries');

      // Log mapping details for debugging (limit to 10 entries to avoid spam)
      if (serverIdToLocalIdMap.isNotEmpty &&
          serverIdToLocalIdMap.length <= 10) {
        _logger.d('$_tag   Full ID mapping: $serverIdToLocalIdMap');
      }

      // 4. Convert DTOs to Jobs using the mapping
      _logger.d(
        '$_tag Step 4: Converting ${remoteDtos.length} DTOs to Job entities with correct localIds...',
      );
      final List<Job> remoteJobs = JobMapper.fromApiDtoList(
        remoteDtos,
        serverIdToLocalIdMap: serverIdToLocalIdMap,
      );

      // Log mapping outcomes statistics
      int reusedIds = 0;
      int newlyGeneratedIds = 0;
      for (int i = 0; i < remoteDtos.length; i++) {
        final dto = remoteDtos[i];
        final job = remoteJobs[i];
        if (serverIdToLocalIdMap.containsKey(dto.id)) {
          reusedIds++;
          _logger.d(
            '$_tag   Reused existing localId ${job.localId} for server ID ${dto.id}',
          );
        } else {
          newlyGeneratedIds++;
          _logger.d(
            '$_tag   Generated new localId ${job.localId} for server ID ${dto.id}',
          );
        }
      }
      _logger.d(
        '$_tag   Mapping summary: $reusedIds localIds reused, $newlyGeneratedIds new localIds generated',
      );

      if (remoteJobs.isNotEmpty && remoteJobs.length <= 10) {
        final ids = remoteJobs
            .map((j) => '(${j.localId} / ${j.serverId})')
            .join(', ');
        _logger.d('$_tag   Mapped Remote Job IDs (local/server): $ids');
      }
      // For large data sets, only log count to avoid log spam
      else if (remoteJobs.isNotEmpty) {
        _logger.d(
          '$_tag   Only logging count for >10 entries to avoid log spam',
        );
      }

      // 5. Identify server-deleted jobs
      _logger.d('$_tag Step 5: Identifying server-deleted jobs...');
      final List<Job> serverDeletedJobs = [];
      final Set<String?> remoteServerIds =
          remoteDtos.map((dto) => dto.id).toSet();

      _logger.d('$_tag   Remote Server IDs Set: $remoteServerIds');

      if (localSyncedJobs.isNotEmpty) {
        for (final localJob in localSyncedJobs) {
          _logger.d(
            '$_tag   Checking local synced job: ${localJob.localId} (Server ID: ${localJob.serverId})',
          );
          if (localJob.serverId != null &&
              !remoteServerIds.contains(localJob.serverId)) {
            _logger.i(
              '$_tag Detected server-deleted job: ${localJob.localId} (Server ID: ${localJob.serverId})',
            );
            serverDeletedJobs.add(localJob);
          } else {
            _logger.d(
              '$_tag   Job ${localJob.localId} (Server ID: ${localJob.serverId}) is present on server or has no serverId.',
            );
          }
        }
      } else {
        _logger.d('$_tag No local synced jobs found to check for deletions.');
      }
      _logger.d(
        '$_tag Identified ${serverDeletedJobs.length} jobs deleted on server.',
      );

      // 6. Permanently delete server-deleted jobs locally
      _logger.d(
        '$_tag Step 6: Deleting ${serverDeletedJobs.length} server-deleted jobs locally...',
      );
      if (serverDeletedJobs.isNotEmpty) {
        int deletionSuccessCount = 0;
        int deletionFailureCount = 0;
        for (final jobToDelete in serverDeletedJobs) {
          _logger.i(
            '$_tag Triggering permanent local deletion for job ${jobToDelete.localId} (Server ID: ${jobToDelete.serverId})',
          );
          final deleteResult = await _deleterService.permanentlyDeleteJob(
            jobToDelete.localId,
          );
          deleteResult.fold(
            (failure) {
              deletionFailureCount++;
              _logger.e(
                '$_tag Failed to locally delete server-deleted job ${jobToDelete.localId}: $failure',
              );
            },
            (_) {
              deletionSuccessCount++;
              _logger.i(
                '$_tag Successfully locally deleted server-deleted job ${jobToDelete.localId}.',
              );
            },
          );
        }
        _logger.d(
          '$_tag Deletion attempts complete: $deletionSuccessCount succeeded, $deletionFailureCount failed.',
        );
      } else {
        _logger.d('$_tag No server-side deletions needed processing.');
      }

      // 7. Cache the mapped remote jobs locally
      _logger.d(
        '$_tag Step 7: Caching ${remoteJobs.length} mapped remote jobs locally...',
      );
      int savedCount = 0;
      int saveFailedCount = 0;
      for (final remoteJob in remoteJobs) {
        try {
          _logger.d(
            '$_tag DEBUG: Inspecting remoteJob before saving to cache: ',
          );
          _logger.d('$_tag   - Local ID: ${remoteJob.localId}');
          _logger.d('$_tag   - Server ID: ${remoteJob.serverId}');
          _logger.d('$_tag   - Status: ${remoteJob.status}');
          _logger.d('$_tag   - Sync Status: ${remoteJob.syncStatus}');

          await _localDataSource.saveJob(remoteJob);
          savedCount++;
        } on CacheException catch (e, stackTrace) {
          saveFailedCount++;
          _logger.w(
            '$_tag CacheException saving job ${remoteJob.localId} (Server ID: ${remoteJob.serverId}) to local cache: ${e.message}. Skipping this job.',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
      _logger.d(
        '$_tag Finished caching remote jobs: $savedCount saved, $saveFailedCount failed.',
      );

      // 8. Return the list of mapped jobs from the remote source
      _logger.d(
        '$_tag Step 8: Returning ${remoteJobs.length} mapped remote jobs as result.',
      );
      return Right(remoteJobs);
    } on ApiException catch (e, stackTrace) {
      _logger.e(
        '$_tag API Exception fetching remote jobs: ${e.message} (Status: ${e.statusCode})',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in getJobs (Online Path)',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Unexpected error getting jobs: $e'));
    }
  }

  Future<Either<Failure, Job>> getJobById(String localId) async {
    _logger.d('$_tag Getting job by ID: $localId');
    try {
      // Use the entity-based method
      final job = await _localDataSource.getJobById(localId);
      _logger.d('$_tag   Found job locally: ${job.localId}');
      return Right(job);
    } on CacheException catch (e, stackTrace) {
      // CacheException from getJobById likely means not found or DB error
      _logger.w(
        '$_tag CacheException getting job $localId: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        CacheFailure(
          e.message ?? 'Job with ID $localId not found or cache error',
        ),
      );
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in getJobById($localId)',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Unexpected error getting job by ID: $e'));
    }
  }

  Future<Either<Failure, List<Job>>> getJobsByStatus(SyncStatus status) async {
    _logger.d('$_tag Getting jobs by status: $status');
    try {
      // Use the entity-based method directly
      final filteredJobs = await _localDataSource.getJobsByStatus(status);
      _logger.d('$_tag Found ${filteredJobs.length} jobs with status $status');
      return Right(filteredJobs);
    } on CacheException catch (e, stackTrace) {
      _logger.w(
        '$_tag CacheException getting jobs by status $status: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CacheFailure(e.message ?? 'Failed to get jobs by status'));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in getJobsByStatus($status)',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        UnknownFailure('Unexpected error getting jobs by status: $e'),
      );
    }
  }

  // --- Stream Operations ---

  /// Watches the local data source for changes to the list of all jobs.
  Stream<Either<Failure, List<Job>>> watchJobs() {
    _logger.d('Delegating watchJobs to local data source...');
    try {
      return _localDataSource.watchJobs().transform(
        StreamTransformer.fromHandlers(
          handleData: (
            Either<Failure, List<Job>> data,
            EventSink<Either<Failure, List<Job>>> sink,
          ) {
            _logger.d('watchJobs emitting new list...');
            sink.add(data);
          },
          handleError: (
            Object error,
            StackTrace stackTrace,
            EventSink<Either<Failure, List<Job>>> sink,
          ) {
            _logger.e(
              'Error within watchJobs stream:',
              error: error,
              stackTrace: stackTrace,
            );
            sink.add(
              Left(CacheFailure('Error in job stream: ${error.toString()}')),
            );
          },
        ),
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Unexpected error initiating watchJobs stream',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.value(
        Left(CacheFailure('Failed to start watching jobs: ${e.toString()}')),
      );
    }
  }

  /// Watches the local data source for changes to a specific job.
  Stream<Either<Failure, Job?>> watchJobById(String localId) {
    _logger.d('Delegating watchJobById($localId) to local data source...');
    try {
      return _localDataSource
          .watchJobById(localId)
          .transform(
            StreamTransformer.fromHandlers(
              handleData: (
                Either<Failure, Job?> data,
                EventSink<Either<Failure, Job?>> sink,
              ) {
                _logger.d('watchJobById($localId) emitting new value...');
                sink.add(data);
              },
              handleError: (
                Object error,
                StackTrace stackTrace,
                EventSink<Either<Failure, Job?>> sink,
              ) {
                _logger.e(
                  'Error within watchJobById($localId) stream:',
                  error: error,
                  stackTrace: stackTrace,
                );
                sink.add(
                  Left(
                    CacheFailure(
                      'Error in job stream for $localId: ${error.toString()}',
                    ),
                  ),
                );
              },
            ),
          );
    } catch (e, stackTrace) {
      _logger.e(
        'Unexpected error initiating watchJobById($localId) stream',
        error: e,
        stackTrace: stackTrace,
      );
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
