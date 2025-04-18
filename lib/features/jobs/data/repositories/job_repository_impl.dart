import 'dart:async';

import 'package:dartz/dartz.dart'; // Import dartz
import 'package:docjet_mobile/core/error/exceptions.dart'; // For potential exceptions
import 'package:docjet_mobile/core/error/failures.dart'; // Import Failure
import 'package:docjet_mobile/core/platform/file_system.dart'; // Corrected Import FileSystem Service
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import Logger
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart'; // Import needed for static calls
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart'; // Import Hive model
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:uuid/uuid.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource remoteDataSource;
  final JobLocalDataSource localDataSource;
  final FileSystem fileSystemService; // Corrected type hint
  final Uuid uuid;
  // final JobMapper mapper; // REMOVED - Mapper methods are static
  // final NetworkInfo networkInfo; // Removed

  // Logger instance
  final Logger _logger = LoggerFactory.getLogger(JobRepositoryImpl);
  static final String _tag = logTag(JobRepositoryImpl);

  // --- ADDED: Staleness threshold ---
  final Duration stalenessThreshold;

  // Define cache duration
  static const Duration _cacheDuration = Duration(minutes: 5);

  JobRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.fileSystemService, // Require FileSystem service
    required this.uuid,
    // Default staleness to 1 hour if not provided
    this.stalenessThreshold = const Duration(hours: 1),
    // required this.mapper, // REMOVED
    // required this.networkInfo, // Removed
  });

  @override
  Future<Either<Failure, List<Job>>> getJobs() async {
    _logger.d('$_tag Attempting to fetch jobs from local cache...');
    try {
      final localJobs = await localDataSource.getAllJobHiveModels();
      _logger.d(
        '$_tag Cache hit with ${localJobs.length} items. Checking freshness...',
      );
      final lastFetchTime = await localDataSource.getLastFetchTime();

      if (localJobs.isNotEmpty &&
          lastFetchTime != null &&
          DateTime.now().difference(lastFetchTime) < _cacheDuration) {
        _logger.d('$_tag Cache is fresh. Returning local data.');
        return Right(JobMapper.fromHiveModelList(localJobs));
      } else {
        _logger.d(
          '$_tag Cache is stale (last fetch: $lastFetchTime) or fetch time unknown. Fetching remote.',
        );
        return await _getJobsFromRemote();
      }
    } on CacheException catch (e, stackTrace) {
      _logger.w(
        '$_tag Cache read error: $e. Proceeding to fetch from remote.',
        error: e,
        stackTrace: stackTrace,
      );
      // Fallback to remote fetch if local cache fails
      return await _getJobsFromRemote();
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during getJobs: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'An unexpected error occurred: $e'));
    }
  }

  /// Helper function to fetch jobs from remote, save to cache, and return.
  /// This contains the logic previously in the main try block of getJobs.
  Future<Either<Failure, List<Job>>> _getJobsFromRemote() async {
    _logger.d('$_tag Fetching jobs from remote data source...');
    try {
      // 1. Fetch from remote
      final remoteJobs = await remoteDataSource.fetchJobs();
      _logger.d(
        '$_tag Successfully fetched ${remoteJobs.length} jobs from remote.',
      );

      // 2. Fetch locally synced jobs for comparison
      _logger.d('$_tag Fetching locally synced jobs for deletion check...');
      final localSyncedHiveJobs =
          await localDataSource.getSyncedJobHiveModels();
      _logger.d(
        '$_tag Found ${localSyncedHiveJobs.length} locally synced jobs for comparison.',
      );

      // 3. Identify server-side deletions
      final remoteJobServerIds = remoteJobs.map((job) => job.serverId).toSet();
      _logger.d('$_tag Remote job server IDs: $remoteJobServerIds');

      for (final localJob in localSyncedHiveJobs) {
        if (localJob.serverId != null &&
            !remoteJobServerIds.contains(localJob.serverId) &&
            localJob.syncStatus == SyncStatus.synced.index) {
          // This job exists locally and is synced, but wasn't returned by the server -> delete it
          // IMPORTANT: We only delete jobs that are in SyncStatus.synced state
          _logger.i(
            '$_tag Deleting local job (localId: ${localJob.localId}, serverId: ${localJob.serverId}) detected as deleted on server.',
          );
          try {
            await localDataSource.deleteJobHiveModel(localJob.localId);
            _logger.d(
              '$_tag Successfully deleted job ${localJob.localId} from local DB.',
            );

            // Attempt to delete associated audio file
            if (localJob.audioFilePath != null &&
                localJob.audioFilePath!.isNotEmpty) {
              _logger.d(
                '$_tag Attempting to delete audio file: ${localJob.audioFilePath}',
              );
              try {
                await fileSystemService.deleteFile(localJob.audioFilePath!);
                _logger.d(
                  '$_tag Successfully deleted audio file: ${localJob.audioFilePath}',
                );
              } catch (fileError, fileStackTrace) {
                _logger.e(
                  '$_tag Failed to delete audio file ${localJob.audioFilePath} for server-deleted job ${localJob.localId}. Continuing sync.',
                  error: fileError,
                  stackTrace: fileStackTrace,
                );
                // Do not rethrow, allow sync to continue
              }
            }
          } catch (dbError, dbStackTrace) {
            // Log DB deletion error, but proceed to save server data if possible
            _logger.e(
              '$_tag Failed to delete local job ${localJob.localId} from DB during server-side deletion check. Proceeding.',
              error: dbError,
              stackTrace: dbStackTrace,
            );
          }
        }
      }

      // 4. Save the fetched remote jobs to local cache
      _logger.d('$_tag Saving ${remoteJobs.length} jobs to local cache...');
      try {
        final hiveModelsToSave = JobMapper.toHiveModelList(remoteJobs);
        await localDataSource.saveJobHiveModels(hiveModelsToSave);
        _logger.d('$_tag Successfully saved jobs to cache.');
      } catch (e, stackTrace) {
        _logger.w(
          '$_tag Failed to save jobs to cache: $e. Returning remote data anyway.',
          error: e,
          stackTrace: stackTrace,
        );
        // Non-fatal: Log and continue, returning the fetched data
      }

      // 5. Save the fetch timestamp
      try {
        await localDataSource.saveLastFetchTime(DateTime.now());
        _logger.d('$_tag Successfully saved fetch time to cache.');
      } catch (e, stackTrace) {
        _logger.w(
          '$_tag Failed to save fetch time to cache: $e',
          error: e,
          stackTrace: stackTrace,
        );
        // Non-fatal: Log and continue
      }

      return Right(remoteJobs);
    } on ApiException catch (e, stackTrace) {
      _logger.e(
        '$_tag ApiException during remote fetch: ${e.message}, Status: ${e.statusCode}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e, stackTrace) {
      _logger.e(
        '$_tag ServerException during remote fetch: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.message));
    } catch (e, stackTrace) {
      // Catch any other unexpected errors
      _logger.e(
        '$_tag Unexpected error during remote fetch: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'An unexpected error occurred: $e'));
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
    _logger.d('$_tag createJob called with path: $audioFilePath');
    try {
      // 1. Generate localId using Uuid
      final localId = uuid.v4();
      _logger.d('$_tag Generated localId: $localId');

      // 2. Create Job entity
      final now = DateTime.now();
      final newJob = Job(
        localId: localId,
        serverId: null, // No serverId yet
        userId: '', // Default or get from auth service later
        status: JobStatus.created, // Initial status
        syncStatus: SyncStatus.pending, // Mark as pending sync
        displayTitle: '', // Default or generate later
        audioFilePath: audioFilePath,
        text: text, // Use provided text
        createdAt: now,
        updatedAt: now,
      );

      // 3. Map to Hive model
      final hiveModel = JobMapper.toHiveModel(newJob);

      // 4. Save to local data source
      _logger.d('$_tag Saving new job $localId to local data source...');
      await localDataSource.saveJobHiveModel(hiveModel);
      _logger.i('$_tag Successfully saved new job $localId locally.');

      // 5. Return the created Job entity
      return Right(newJob);
    } on CacheException catch (e, stackTrace) {
      _logger.e(
        '$_tag CacheException during createJob: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CacheFailure('Failed to save new job locally: ${e.message}'));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during createJob: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<Either<Failure, Job>> updateJob({
    required String jobId,
    required Map<String, dynamic> updates,
  }) async {
    _logger.d(
      '$_tag updateJob called for localId: $jobId with updates: $updates',
    );
    try {
      _logger.d('$_tag Fetching existing job model for $jobId...');
      // 1. Get existing job model from local storage
      final existingModel = await localDataSource.getJobHiveModelById(jobId);
      if (existingModel == null) {
        _logger.w('$_tag Job with localId $jobId not found in local cache.');
        return Left(CacheFailure('Job with ID $jobId not found'));
      }
      _logger.d('$_tag Found existing job model for $jobId.');

      // 2. Create the updated model (manual copy and update)
      // IMPORTANT: Do NOT modify existingModel directly if it's managed by Hive
      final updatedModel = JobHiveModel(
        // Copy existing fields
        localId: existingModel.localId,
        serverId: existingModel.serverId,
        userId: existingModel.userId,
        status: existingModel.status, // Status isn't changed by this method
        createdAt: existingModel.createdAt,
        audioFilePath: existingModel.audioFilePath,
        text: existingModel.text, // Keep original text unless updated
        additionalText: existingModel.additionalText,
        errorCode: existingModel.errorCode,
        errorMessage: existingModel.errorMessage,

        // Apply specific updates
        displayTitle:
            updates.containsKey('displayTitle')
                ? updates['displayTitle'] as String?
                : existingModel.displayTitle,
        displayText:
            updates.containsKey('displayText')
                ? updates['displayText'] as String?
                : existingModel.displayText,
        // Add more updatable fields here as needed...

        // Critical updates: syncStatus and updatedAt
        syncStatus: SyncStatus.pending.index, // Mark as pending
        updatedAt: DateTime.now().toIso8601String(), // Update timestamp
      );
      _logger.d(
        '$_tag Created updated job model for $jobId. Status: ${updatedModel.syncStatus}',
      );

      // 3. Save the updated model
      _logger.d('$_tag Saving updated job model for $jobId...');
      await localDataSource.saveJobHiveModel(updatedModel);
      _logger.i('$_tag Successfully saved updated job $jobId locally.');

      // 4. Map back to Job entity and return
      final updatedJobEntity = JobMapper.fromHiveModel(updatedModel);
      return Right(updatedJobEntity);
    } on CacheException catch (e, stackTrace) {
      _logger.e(
        '$_tag CacheException during updateJob for $jobId: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CacheFailure('Failed to update job $jobId: ${e.message}'));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during updateJob for $jobId: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> syncPendingJobs() async {
    _logger.d('$_tag syncPendingJobs called');
    List<JobHiveModel> pendingHiveModels = []; // Initialize empty list

    try {
      // 1. Get pending jobs (includes pending and pendingDeletion)
      pendingHiveModels = await localDataSource.getJobsToSync();
      _logger.d(
        '$_tag Found ${pendingHiveModels.length} jobs pending sync locally.',
      );

      if (pendingHiveModels.isEmpty) {
        _logger.i('$_tag No pending jobs to sync. Exiting.');
        return const Right(unit); // Nothing to do
      }

      // 2. Map to Job entities
      final jobsToSync = JobMapper.fromHiveModelList(pendingHiveModels);
      _logger.d(
        '$_tag Mapped ${jobsToSync.length} Hive models to Job entities.',
      );

      // 3. Iterate and sync each job individually
      for (final job in jobsToSync) {
        _logger.d(
          '$_tag Processing job ${job.localId} (ServerId: ${job.serverId}, SyncStatus: ${job.syncStatus})',
        );

        try {
          if (job.syncStatus == SyncStatus.pendingDeletion) {
            // --- Handle Deletion ---
            _logger.d('$_tag Job ${job.localId} marked for deletion.');
            if (job.serverId != null) {
              // Only call API if it was ever synced
              _logger.d(
                '$_tag Calling remoteDataSource.deleteJob for serverId ${job.serverId}',
              );
              await remoteDataSource.deleteJob(job.serverId!);
              _logger.i(
                '$_tag Successfully deleted job on remote server: ${job.serverId}',
              );
            } else {
              _logger.d(
                '$_tag Job ${job.localId} was never synced. Skipping remote delete.',
              );
            }
            // Delete locally regardless of remote status (if never synced or remote delete succeeded)
            await localDataSource.deleteJobHiveModel(job.localId);
            _logger.i('$_tag Successfully deleted job locally: ${job.localId}');
            // Delete associated audio file if path exists
            if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
              try {
                _logger.d(
                  '$_tag Attempting to delete audio file: ${job.audioFilePath}',
                );
                await fileSystemService.deleteFile(job.audioFilePath!);
                _logger.i(
                  '$_tag Successfully deleted audio file: ${job.audioFilePath}',
                );
              } catch (e, stackTrace) {
                _logger.w(
                  '$_tag Failed to delete audio file ${job.audioFilePath}: $e. Continuing...',
                  error: e,
                  stackTrace: stackTrace,
                );
              }
            }
          } else if (job.syncStatus == SyncStatus.pending) {
            // --- Handle Creation or Update ---
            Job syncedJob; // To hold the result from remote operation
            if (job.serverId == null) {
              // --- Create New Job ---
              _logger.d(
                '$_tag Job ${job.localId} is new. Calling createJob...',
              );
              syncedJob = await remoteDataSource.createJob(
                userId:
                    job.userId, // Assuming userId is available on the entity
                audioFilePath:
                    job.audioFilePath!, // Assuming audioFilePath is present
                text: job.text,
                additionalText: job.additionalText,
              );
              _logger.i(
                '$_tag Successfully created job on remote. ServerId: ${syncedJob.serverId}, LocalId: ${job.localId}',
              );
              // IMPORTANT: The returned syncedJob might have a different localId
              // if the remote source doesn't echo it back. We MUST ensure
              // the localId from the *original* job is used for updates.
              // We merge the serverId into the original job entity.
              syncedJob = job.copyWith(
                serverId: syncedJob.serverId,
                syncStatus: SyncStatus.synced,
              );
            } else {
              // --- Update Existing Job ---
              _logger.d(
                '$_tag Job ${job.localId} exists (ServerId: ${job.serverId}). Calling updateJob...',
              );
              // Need to determine what fields to send for update.
              // For now, sending editable fields. A better approach might involve
              // tracking changed fields specifically.
              final updates = {
                'text': job.text,
                'additionalText': job.additionalText,
                'displayTitle': job.displayTitle,
                // Add other updatable fields here based on API contract
              };
              syncedJob = await remoteDataSource.updateJob(
                jobId: job.serverId!,
                updates: updates,
              );
              _logger.i(
                '$_tag Successfully updated job on remote: ${job.serverId}',
              );
              // Merge updates back, ensure localId and serverId are preserved.
              syncedJob = job.copyWith(
                // Assuming remote returns the *full* updated entity
                status: syncedJob.status,
                updatedAt: syncedJob.updatedAt,
                displayTitle: syncedJob.displayTitle,
                displayText: syncedJob.displayText,
                errorCode: syncedJob.errorCode,
                errorMessage: syncedJob.errorMessage,
                text: syncedJob.text,
                additionalText: syncedJob.additionalText,
                syncStatus: SyncStatus.synced, // Mark as synced
              );
            }

            // --- Post-Sync Update (for Create/Update) ---
            _logger.d(
              '$_tag Saving updated job data and status locally for ${syncedJob.localId}',
            );
            final syncedHiveModel = JobMapper.toHiveModel(syncedJob);
            await localDataSource.saveJobHiveModel(
              syncedHiveModel,
            ); // Save updated data
            await localDataSource.updateJobSyncStatus(
              syncedJob.localId, // Use the original localId
              SyncStatus.synced,
            ); // Mark as synced *after* successful save
            _logger.d(
              '$_tag Successfully updated local data and status for job ${syncedJob.localId}.',
            );
          } else {
            // Should not happen if getJobsToSync is correct, but log anyway
            _logger.w(
              '$_tag Job ${job.localId} has unexpected syncStatus: ${job.syncStatus}. Skipping.',
            );
          }
        } on ApiException catch (e) {
          _logger.e(
            '$_tag ApiException syncing job ${job.localId}: ${e.message}, Status: ${e.statusCode}. Marking as error.',
          );
          // Mark job as error on API failure
          await localDataSource.updateJobSyncStatus(
            job.localId,
            SyncStatus.error,
          );
        } on ServerException catch (e) {
          _logger.e(
            '$_tag ServerException syncing job ${job.localId}: ${e.message}. Marking as error.',
          );
          // Mark job as error on server failure
          await localDataSource.updateJobSyncStatus(
            job.localId,
            SyncStatus.error,
          );
        } on CacheException catch (e) {
          _logger.e(
            '$_tag CacheException during post-sync update for job ${job.localId}: ${e.toString()}. Status may be inconsistent.',
            error: e,
          );
          // Don't return Failure here, allow loop to continue for other jobs
        } catch (e, stackTrace) {
          _logger.e(
            '$_tag Unexpected error syncing job ${job.localId}: ${e.toString()}. Marking as error.',
            error: e,
            stackTrace: stackTrace,
          );
          // Mark job as error on unexpected failure
          await localDataSource.updateJobSyncStatus(
            job.localId,
            SyncStatus.error,
          );
        }
      } // End of loop

      _logger.i('$_tag syncPendingJobs iteration completed.');
      return const Right(unit);
    } on CacheException catch (e) {
      _logger.e(
        '$_tag CacheException fetching pending jobs: ${e.toString()}. Aborting sync.',
      );
      return Left(
        CacheFailure('Cache error fetching pending jobs: ${e.toString()}'),
      );
    } catch (e, stackTrace) {
      // Catch errors during the initial fetch or mapping
      _logger.e(
        '$_tag Unexpected error during initial phase of syncPendingJobs: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        ServerFailure(
          message: 'An unexpected error occurred during sync setup',
        ),
      );
    }
  }

  // --- ADDED: Implementation for deleteJob ---
  @override
  Future<Either<Failure, Unit>> deleteJob(String jobId) async {
    _logger.d('$_tag deleteJob called for localId: $jobId');
    try {
      // 1. Get the job model from local storage
      _logger.d('$_tag Fetching job $jobId from local data source...');
      final jobModel = await localDataSource.getJobHiveModelById(jobId);

      if (jobModel == null) {
        _logger.w('$_tag Job $jobId not found in local cache for deletion.');
        return Left(CacheFailure('Job with id $jobId not found'));
      }

      // 2. Create updated model with pendingDeletion status
      //    We have to manually create it as JobHiveModel might not have copyWith
      final updatedModel = JobHiveModel(
        localId: jobModel.localId,
        serverId: jobModel.serverId,
        createdAt: jobModel.createdAt,
        updatedAt:
            DateTime.now()
                .toIso8601String(), // Update timestamp on modification
        text: jobModel.text,
        audioFilePath: jobModel.audioFilePath,
        status: jobModel.status,
        syncStatus: SyncStatus.pendingDeletion.index, // Set to pendingDeletion
      );

      // 3. Save the updated model back to local storage
      _logger.d(
        '$_tag Saving job $jobId with syncStatus=pendingDeletion back to local store...',
      );
      await localDataSource.saveJobHiveModel(updatedModel);
      _logger.i('$_tag Successfully marked job $jobId for deletion locally.');

      // 4. Return success (Unit indicates operation was accepted)
      return const Right(unit); // Use dartz unit
    } on CacheException catch (e, stackTrace) {
      _logger.e(
        '$_tag CacheException during deleteJob for $jobId: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CacheFailure('Failed to mark job for deletion: $e'));
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during deleteJob for $jobId: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'An unexpected error occurred: $e'));
    }
  }
}
