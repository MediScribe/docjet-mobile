import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:logger/logger.dart'; // Import Logger

/// Service class for job synchronization with remote server
class JobSyncService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final FileSystem _fileSystem;
  final Logger _logger = Logger(); // Add a logger instance

  JobSyncService({
    required JobLocalDataSource localDataSource,
    required JobRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required FileSystem fileSystem,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo,
       _fileSystem = fileSystem;

  Future<Either<Failure, Unit>> syncPendingJobs() async {
    _logger.i('Starting syncPendingJobs...');
    if (!await _networkInfo.isConnected) {
      _logger.w('Network offline, skipping sync.');
      return Left(ServerFailure(message: 'No internet connection'));
    }

    try {
      _logger.d('Fetching jobs pending sync...');
      final pendingJobs = await _localDataSource.getJobsByStatus(
        SyncStatus.pending,
      );
      _logger.d('Found ${pendingJobs.length} jobs pending create/update.');

      _logger.d('Fetching jobs pending deletion...');
      final deletionJobs = await _localDataSource.getJobsByStatus(
        SyncStatus.pendingDeletion,
      );
      _logger.d('Found ${deletionJobs.length} jobs pending deletion.');

      // Process creates/updates
      for (final job in pendingJobs) {
        _logger.i('Syncing job (localId: ${job.localId})...');
        await syncSingleJob(job);
      }

      // Process deletions
      for (final job in deletionJobs) {
        _logger.i('Processing deletion for job (localId: ${job.localId})...');
        if (job.serverId != null) {
          try {
            _logger.d('Deleting job on server (serverId: ${job.serverId})...');
            await _remoteDataSource.deleteJob(job.serverId!);
            _logger.i(
              'Successfully deleted job on server (serverId: ${job.serverId}).',
            );
          } catch (e) {
            _logger.e(
              'Failed to delete job on server (serverId: ${job.serverId}): $e. Proceeding with local deletion.',
            );
            // Don't return failure, still attempt local deletion
          }
        }
        await _permanentlyDeleteJob(job.localId);
      }

      _logger.i('syncPendingJobs completed successfully.');
      return const Right(unit);
    } on CacheException catch (e) {
      _logger.e('Cache error during sync: $e');
      return Left(CacheFailure(e.message ?? 'Unknown cache error'));
    } on ServerException catch (e) {
      _logger.e('Server error during sync: $e');
      return Left(ServerFailure(message: e.message ?? 'Unknown server error'));
    } catch (e) {
      _logger.e('Unexpected error during sync: $e');
      return Left(ServerFailure(message: 'Unexpected error during sync: $e'));
    }
  }

  Future<Either<Failure, Job>> syncSingleJob(Job job) async {
    try {
      if (job.serverId == null) {
        _logger.d(
          'Calling remoteDataSource.createJob for localId: ${job.localId}',
        );
        if (job.audioFilePath == null || job.audioFilePath!.isEmpty) {
          _logger.e(
            'Cannot create job without audio file path (localId: ${job.localId})',
          );
          return Left(ValidationFailure('Audio file path is required'));
        }
        final remoteJob = await _remoteDataSource.createJob(
          userId: job.userId,
          audioFilePath: job.audioFilePath!,
          text: job.text,
          additionalText: job.additionalText,
        );
        _logger.d('Remote create successful. Saving synced job locally.');
        await _localDataSource.saveJob(remoteJob);
        return Right(remoteJob);
      } else {
        _logger.d(
          'Calling remoteDataSource.updateJob for serverId: ${job.serverId}',
        );

        final updates = <String, dynamic>{
          'status': job.status.name,
          if (job.displayTitle != null) 'display_title': job.displayTitle,
          if (job.text != null) 'text': job.text,
          if (job.additionalText != null) 'additional_text': job.additionalText,
        };

        final remoteJob = await _remoteDataSource.updateJob(
          jobId: job.serverId!,
          updates: updates,
        );
        _logger.d('Remote update successful. Saving synced job locally.');
        await _localDataSource.saveJob(remoteJob);
        return Right(remoteJob);
      }
    } on ServerException catch (e) {
      _logger.e(
        'ServerException during syncSingleJob for localId: ${job.localId}: $e',
      );
      final errorJob = job.copyWith(syncStatus: SyncStatus.error);
      try {
        await _localDataSource.saveJob(errorJob);
      } catch (saveError) {
        _logger.e(
          'Failed to save job with error status after ServerException: $saveError',
        );
      }
      return Left(
        ServerFailure(message: e.message ?? 'Server error during sync'),
      );
    } on CacheException catch (e) {
      _logger.e(
        'CacheException during syncSingleJob for localId: ${job.localId}: $e',
      );
      final errorJob = job.copyWith(syncStatus: SyncStatus.error);
      try {
        await _localDataSource.saveJob(errorJob);
      } catch (saveError) {
        _logger.e(
          'Failed to save job with error status after CacheException: $saveError',
        );
      }
      return Left(CacheFailure(e.message ?? 'Cache error during sync'));
    } catch (e) {
      _logger.e(
        'Unexpected error during syncSingleJob for localId: ${job.localId}: $e',
      );
      final errorJob = job.copyWith(syncStatus: SyncStatus.error);
      try {
        await _localDataSource.saveJob(errorJob);
      } catch (saveError) {
        _logger.e(
          'Failed to save job with error status after unexpected error: $saveError',
        );
      }
      return Left(ServerFailure(message: 'Unexpected error syncing job: $e'));
    }
  }

  // Internal helper method to delete job permanently
  Future<void> _permanentlyDeleteJob(String localId) async {
    _logger.i(
      'Attempting permanent local deletion for job (localId: $localId)...',
    );
    try {
      // Fetch first to get audio file path before deleting
      final job = await _localDataSource.getJobById(localId);
      _logger.d('Found job locally, proceeding with deletion.');

      // Delete from local storage
      await _localDataSource.deleteJob(localId);
      _logger.i('Successfully deleted job from local DB (localId: $localId).');

      // Delete associated audio file if it exists
      if (job.audioFilePath != null && job.audioFilePath!.isNotEmpty) {
        try {
          _logger.d('Deleting audio file: ${job.audioFilePath}');
          await _fileSystem.deleteFile(job.audioFilePath!);
          _logger.i('Successfully deleted audio file: ${job.audioFilePath}.');
        } catch (e) {
          _logger.w(
            'Failed to delete audio file (${job.audioFilePath}) for job $localId: $e. This is non-critical.',
          );
          // Log but don't fail the overall operation
        }
      } else {
        _logger.d(
          'No audio file path found for job $localId, skipping file deletion.',
        );
      }
    } on CacheException catch (e) {
      _logger.w(
        'CacheException during permanent deletion attempt for job $localId (Might be already deleted?): $e',
      );
    } catch (e) {
      _logger.e(
        'Error during permanent local deletion for job $localId: $e. Sync cycle continues.',
      );
    }
  }
}
