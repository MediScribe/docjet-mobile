// import 'dart:io'; // Import dart:io for File operations - NO LONGER NEEDED

import 'dart:async';
import 'package:dartz/dartz.dart';

// Core
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

// Data Layer
import '../datasources/audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';
import '../services/audio_file_manager.dart';

// Domain Layer
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';

// Using centralized logger with level OFF
final logger = Logger(level: Level.off);

class AudioRecorderRepositoryImpl implements AudioRecorderRepository {
  final AudioLocalDataSource localDataSource;
  final AudioFileManager fileManager;
  final LocalJobStore localJobStore;
  final TranscriptionRemoteDataSource remoteDataSource;
  final TranscriptionMergeService transcriptionMergeService;

  // --- State Management --- //
  String?
  _currentRecordingPath; // Manages the path of the active recording session

  AudioRecorderRepositoryImpl({
    required this.localDataSource,
    required this.fileManager,
    required this.localJobStore,
    required this.remoteDataSource,
    required this.transcriptionMergeService,
  });

  /// Helper function to execute data source calls and handle specific exceptions
  /// NOTE: This helper does NOT handle Left results from Either-returning functions directly.
  /// Those must be handled in the calling methods (e.g., loadTranscriptions, uploadRecording).
  Future<Either<Failure, T>> _tryCatch<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } on AudioPermissionException catch (e, s) {
      logger.w(
        'Repository caught AudioPermissionException',
        error: e,
        stackTrace: s,
      );
      return Left(PermissionFailure(e.message));
    } on NoActiveRecordingException catch (e, s) {
      logger.w(
        'Repository caught NoActiveRecordingException',
        error: e,
        stackTrace: s,
      );
      return Left(RecordingFailure(e.message));
    } on RecordingFileNotFoundException catch (e, s) {
      logger.w(
        'Repository caught RecordingFileNotFoundException',
        error: e,
        stackTrace: s,
      );
      // Map to FileSystemFailure as it relates to file operations
      return Left(FileSystemFailure(e.message));
    } on AudioRecordingException catch (e, s) {
      logger.w(
        'Repository caught AudioRecordingException',
        error: e,
        stackTrace: s,
      );
      return Left(RecordingFailure(e.message));
    } on AudioFileSystemException catch (e, s) {
      // Includes errors from fileManager like delete failures
      logger.w(
        'Repository caught AudioFileSystemException',
        error: e,
        stackTrace: s,
      );
      return Left(FileSystemFailure(e.message));
    } on CacheFailure catch (e, s) {
      // Catch specific CacheFailures from localJobStore
      logger.w('Repository caught CacheFailure', error: e, stackTrace: s);
      return Left(e); // Return the original CacheFailure
    } on AudioException catch (e, s) {
      // Catch other specific AudioExceptions if needed, otherwise map to PlatformFailure
      logger.w(
        'Repository caught generic AudioException',
        error: e,
        stackTrace: s,
      );
      return Left(PlatformFailure(e.message));
    } on ArgumentError catch (e, s) {
      // Map ArgumentErrors (often validation issues) to ValidationFailure
      logger.w('Repository caught ArgumentError', error: e, stackTrace: s);
      return Left(ValidationFailure(e.message ?? 'Invalid argument'));
    } catch (e, s) {
      // Catch all other unexpected errors
      logger.e('Repository caught unexpected error', error: e, stackTrace: s);
      return Left(
        PlatformFailure('An unexpected error occurred: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> checkPermission() async {
    // Use the refined _tryCatch, removing the manual try/catch and CacheFailure
    return _tryCatch(() => localDataSource.checkPermission());
  }

  @override
  Future<Either<Failure, bool>> requestPermission() async {
    // Use the refined _tryCatch, no need for specific onError mapping here
    return _tryCatch(() => localDataSource.requestPermission());
  }

  @override
  Future<Either<Failure, String>> startRecording() {
    return _tryCatch<String>(() async {
      // Call datasource, store the path
      final path = await localDataSource.startRecording();
      _currentRecordingPath = path; // Store it
      logger.i('[REPO] Started recording, path: $path');
      return path; // Return the path wrapped in Right
    });
  }

  @override
  Future<Either<Failure, String>> stopRecording() {
    return _tryCatch<String>(() async {
      if (_currentRecordingPath == null) {
        logger.w('[REPO] stopRecording called with no active recording path.');
        throw const NoActiveRecordingException(
          'No recording path stored in repository.',
        );
      }
      final path = _currentRecordingPath!;
      logger.i('[REPO] Stopping recording for path: $path');
      // Call datasource with the stored path
      final finalPath = await localDataSource.stopRecording(
        recordingPath: path,
      );
      logger.i('[REPO] Recording stopped, final path: $finalPath');
      _currentRecordingPath = null; // Clear path on successful stop
      return finalPath;
    });
  }

  @override
  Future<Either<Failure, void>> pauseRecording() {
    return _tryCatch<void>(() async {
      if (_currentRecordingPath == null) {
        logger.w('[REPO] pauseRecording called with no active recording path.');
        throw const NoActiveRecordingException(
          'No recording path stored in repository.',
        );
      }
      logger.i('[REPO] Pausing recording for path: $_currentRecordingPath');
      // Call datasource with the stored path
      await localDataSource.pauseRecording(
        recordingPath: _currentRecordingPath!,
      );
      logger.i('[REPO] Recording paused successfully.');
      return;
    });
  }

  @override
  Future<Either<Failure, void>> resumeRecording() {
    return _tryCatch<void>(() async {
      if (_currentRecordingPath == null) {
        logger.w(
          '[REPO] resumeRecording called with no active recording path.',
        );
        throw const NoActiveRecordingException(
          'No recording path stored in repository.',
        );
      }
      logger.i('[REPO] Resuming recording for path: $_currentRecordingPath');
      // Call datasource with the stored path
      await localDataSource.resumeRecording(
        recordingPath: _currentRecordingPath!,
      );
      logger.i('[REPO] Recording resumed successfully.');
      return;
    });
  }

  @override
  Future<Either<Failure, void>> deleteRecording(String filePath) {
    logger.i('[REPO] Attempting to delete recording: $filePath');
    // Use _tryCatch to handle potential errors from both fileManager and localJobStore
    return _tryCatch<void>(() async {
      // First, try deleting the file
      await fileManager.deleteRecording(filePath);
      logger.i('[REPO] File deleted successfully: $filePath');

      // If file deletion is successful, try deleting the job metadata
      await localJobStore.deleteJob(filePath);
      logger.i('[REPO] Job metadata deleted successfully for: $filePath');

      // Only return success (void) if BOTH operations succeed
      return;
    });
    // _tryCatch will automatically handle exceptions from either await call
    // and map them to the appropriate Failure types (FileSystemFailure, CacheFailure, etc.)
  }

  @override
  Future<Either<Failure, List<Transcription>>> loadTranscriptions() async {
    logger.i('[REPO] loadTranscriptions called');
    logger.d('[REPO] loadTranscriptions: Initiating fetch sequence.');

    // 1. Fetch remote job statuses
    logger.d('[REPO] loadTranscriptions: Attempting to fetch remote jobs...');
    final remoteJobsResult = await remoteDataSource.getUserJobs();
    List<Transcription> remoteJobs = [];
    ApiFailure? remoteFailure;

    remoteJobsResult.fold(
      (failure) {
        logger.w('[REPO] Failed to fetch remote jobs', error: failure);
        remoteFailure = failure;
        logger.d(
          '[REPO] loadTranscriptions: Remote fetch FAILED. Stored failure: $remoteFailure',
        );
      },
      (jobs) {
        remoteJobs = jobs;
        logger.i(
          '[REPO] Fetched ${remoteJobs.length} jobs from remote source.',
        );
        logger.d(
          '[REPO] loadTranscriptions: Remote fetch SUCCEEDED. Jobs count: ${remoteJobs.length}',
        );
      },
    );

    // 2. Fetch local job statuses - Use _tryCatch specifically for this call
    logger.d('[REPO] loadTranscriptions: Attempting to fetch local jobs...');
    final localJobsResult = await _tryCatch<List<LocalJob>>(
      () => localJobStore.getAllLocalJobs(),
    );

    return localJobsResult.fold(
      (localFailure) {
        // If fetching local jobs failed (e.g., CacheFailure), return that failure.
        logger.e(
          '[REPO] Failed to fetch local jobs from store',
          error: localFailure,
        );
        logger.d(
          '[REPO] loadTranscriptions: Local fetch FAILED. Returning Left($localFailure).',
        );
        return Left(localFailure);
      },
      (localJobs) {
        logger.i('[REPO] Fetched ${localJobs.length} jobs from local store.');
        logger.d(
          '[REPO] loadTranscriptions: Local fetch SUCCEEDED. Jobs count: ${localJobs.length}',
        );

        // *** Handle remote failure AFTER attempting local fetch ***
        if (remoteFailure != null && localJobs.isEmpty) {
          logger.w(
            '[REPO] Remote fetch failed and no local jobs found. Propagating remote failure.',
          );
          logger.d(
            '[REPO] loadTranscriptions: Remote failed AND local empty. Returning Left($remoteFailure).',
          );
          return Left(
            remoteFailure ??
                const ApiFailure(message: 'Unknown remote API failure'),
          );
        } else if (remoteFailure != null) {
          logger.d(
            '[REPO] loadTranscriptions: Remote failed BUT local jobs exist (${localJobs.length}). Proceeding to merge.',
          );
        }

        // 3. Merge using the injected service
        logger.d(
          '[REPO] loadTranscriptions: Preparing to merge remote (${remoteJobs.length}) and local (${localJobs.length}) jobs.',
        );
        logger.i('[REPO] Delegating merge to TranscriptionMergeService...');
        final mergedJobs = transcriptionMergeService.mergeJobs(
          remoteJobs,
          localJobs,
        );
        logger.i(
          '[REPO] Merge complete via service. Returning ${mergedJobs.length} transcription items.',
        );
        logger.d(
          '[REPO] loadTranscriptions: Merge complete. Returning Right with ${mergedJobs.length} items.',
        );
        return Right(mergedJobs);
      },
    );
  }

  @override
  Future<Either<Failure, Transcription>> uploadRecording({
    required String localFilePath,
    required String userId,
    String? text,
    String? additionalText,
  }) async {
    logger.i('[REPO] uploadRecording called for: $localFilePath');

    // Don't wrap the whole thing, handle specific error points.
    try {
      // 1. Validate Local Job State
      final localJob = await localJobStore.getJob(localFilePath);
      if (localJob == null) {
        logger.e(
          '[REPO] Cannot upload: No local job found for path $localFilePath',
        );
        // Throw ArgumentError for _tryCatch to map to ValidationFailure
        throw ArgumentError('Recording not found in local job store.');
      }
      if (localJob.status != TranscriptionStatus.created) {
        logger.w(
          '[REPO] Job for $localFilePath is not in created state (status: ${localJob.status}). Skipping upload.',
        );
        // Throw ArgumentError for _tryCatch to map to ValidationFailure
        throw ArgumentError(
          'Recording is not in a state to be uploaded (${localJob.status}).',
        );
      }

      logger.i(
        '[REPO] Local job validated. Calling remoteDataSource.uploadForTranscription...',
      );
      // 2. Call Remote Data Source
      final uploadResult = await remoteDataSource.uploadForTranscription(
        localFilePath: localFilePath,
        userId: userId,
        text: text,
        additionalText: additionalText,
      );

      // 3. Handle Remote Data Source Result *Explicitly*
      return await uploadResult.fold(
        (apiFailure) async {
          // If remote upload failed, return the specific ApiFailure
          logger.e(
            '[REPO] Upload failed for $localFilePath',
            error: apiFailure,
          );
          return Left(apiFailure); // <--- Explicitly return Left(ApiFailure)
        },
        (transcription) async {
          // 4. If Remote Upload Successful, Update Local Store
          logger.i(
            '[REPO] Upload successful for $localFilePath. Backend ID: ${transcription.id}',
          );
          try {
            final updatedJob = LocalJob(
              localFilePath: localJob.localFilePath,
              durationMillis: localJob.durationMillis,
              status: TranscriptionStatus.submitted, // Mark as submitted
              localCreatedAt: localJob.localCreatedAt,
              backendId: transcription.id, // Store backend ID
            );
            await localJobStore.saveJob(updatedJob);
            logger.i(
              '[REPO] Local job store updated for $localFilePath with status ${updatedJob.status} and backendId ${updatedJob.backendId}',
            );
            return Right(transcription); // Return success
          } on CacheFailure catch (e, s) {
            logger.e(
              '[REPO] Failed to update local job store after successful upload for $localFilePath',
              error: e,
              stackTrace: s,
            );
            // Propagate CacheFailure if updating the local store fails
            return Left(e);
          } catch (e, s) {
            logger.e(
              '[REPO] Unexpected error updating local job store for $localFilePath',
              error: e,
              stackTrace: s,
            );
            return Left(
              PlatformFailure(
                'Failed to update local cache after upload: ${e.toString()}',
              ),
            );
          }
        },
      );
    } on ArgumentError catch (e, s) {
      // Catch validation errors from step 1
      logger.w(
        '[REPO] Validation Error during upload prep',
        error: e,
        stackTrace: s,
      );
      // Map validation ArgumentErrors to ValidationFailure
      return Left(
        ValidationFailure(e.message ?? 'Invalid argument for upload'),
      );
    } on CacheFailure catch (e, s) {
      // Catch CacheFailure during the initial getJob
      logger.e(
        '[REPO] CacheFailure fetching job for upload: $localFilePath',
        error: e,
        stackTrace: s,
      );
      return Left(e);
    } catch (e, s) {
      // Catch truly unexpected errors during the process
      logger.e(
        '[REPO] Unexpected error during uploadRecording for $localFilePath',
        error: e,
        stackTrace: s,
      );
      return Left(
        PlatformFailure(
          'An unexpected error occurred during upload: ${e.toString()}',
        ),
      );
    }
  }

  // ADDED: Implementation stub for appendToRecording
  @override
  Future<Either<Failure, String>> appendToRecording(String segmentPath) async {
    logger.w('appendToRecording is not implemented yet.');
    // Since AudioFileManager doesn't support concatenation, throw for now.
    return const Left(PlatformFailure('appendToRecording is not implemented.'));
    // OR: throw UnimplementedError('appendToRecording is not implemented.');
  }
} // End of AudioRecorderRepositoryImpl
