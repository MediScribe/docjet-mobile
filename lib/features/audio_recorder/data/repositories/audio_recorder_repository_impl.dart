// import 'dart:io'; // Import dart:io for File operations - NO LONGER NEEDED

import 'package:dartz/dartz.dart';
// import 'package:flutter/foundation.dart'; // Import for debugPrint
// Import for @visibleForTesting

// Core
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

// Data Layer
import '../datasources/audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';
import '../services/audio_file_manager.dart';

// Domain Layer
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

class AudioRecorderRepositoryImpl implements AudioRecorderRepository {
  final AudioLocalDataSource localDataSource;
  final AudioFileManager fileManager;

  // --- State Management --- //
  String?
  _currentRecordingPath; // Manages the path of the active recording session

  AudioRecorderRepositoryImpl({
    required this.localDataSource,
    required this.fileManager,
  });

  /// Helper function to execute data source calls and handle exceptions
  Future<Either<Failure, T>> _tryCatch<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } on AudioPermissionException catch (e) {
      logger.w(
        'Repository caught AudioPermissionException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(PermissionFailure(e.message));
    } on NoActiveRecordingException catch (e) {
      logger.w(
        'Repository caught NoActiveRecordingException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(RecordingFailure(e.message));
    } on RecordingFileNotFoundException catch (e) {
      logger.w(
        'Repository caught RecordingFileNotFoundException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(FileSystemFailure(e.message));
    } on AudioRecordingException catch (e) {
      logger.w(
        'Repository caught AudioRecordingException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(RecordingFailure(e.message));
    } on AudioFileSystemException catch (e) {
      logger.w(
        'Repository caught AudioFileSystemException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(FileSystemFailure(e.message));
    } on AudioConcatenationException catch (e) {
      logger.w(
        'Repository caught AudioConcatenationException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(ConcatenationFailure(e.message));
    } on AudioException catch (e) {
      logger.w(
        'Repository caught generic AudioException',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(PlatformFailure(e.message));
    } on ArgumentError catch (e) {
      logger.w(
        'Repository caught ArgumentError',
        error: e,
        stackTrace: StackTrace.current,
      );
      return Left(PlatformFailure('Invalid input: ${e.message}'));
    } catch (e) {
      logger.e(
        'Repository caught unexpected error',
        error: e,
        stackTrace: StackTrace.current,
      );
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
      return path; // Return the path wrapped in Right
    });
  }

  @override
  Future<Either<Failure, String>> stopRecording() {
    return _tryCatch<String>(() async {
      if (_currentRecordingPath == null) {
        throw const NoActiveRecordingException(
          'No recording path stored in repository.',
        );
      }
      final path = _currentRecordingPath!;
      // Call datasource with the stored path
      final finalPath = await localDataSource.stopRecording(
        recordingPath: path,
      );
      _currentRecordingPath = null; // Clear path on successful stop
      return finalPath;
    });
  }

  @override
  Future<Either<Failure, void>> pauseRecording() {
    return _tryCatch<void>(() async {
      if (_currentRecordingPath == null) {
        throw const NoActiveRecordingException(
          'No recording path stored in repository.',
        );
      }
      // Call datasource with the stored path
      await localDataSource.pauseRecording(
        recordingPath: _currentRecordingPath!,
      );
      return;
    });
  }

  @override
  Future<Either<Failure, void>> resumeRecording() {
    return _tryCatch<void>(() async {
      if (_currentRecordingPath == null) {
        throw const NoActiveRecordingException(
          'No recording path stored in repository.',
        );
      }
      // Call datasource with the stored path
      await localDataSource.resumeRecording(
        recordingPath: _currentRecordingPath!,
      );
      return;
    });
  }

  @override
  Future<Either<Failure, void>> deleteRecording(String filePath) {
    return _tryCatch<void>(() => fileManager.deleteRecording(filePath));
  }

  @override
  Future<Either<Failure, List<AudioRecord>>> loadRecordings() {
    return _tryCatch<List<AudioRecord>>(
      () => fileManager.listRecordingDetails(),
    );
  }

  @override
  Future<Either<Failure, String>> appendToRecording(String segmentPath) {
    // Keep throwing UnimplementedError for now
    throw UnimplementedError(
      'Appending recordings (concatenation) is not yet supported.',
    );
    /* return _tryCatch<String>(() async {
      if (_currentRecordingPath == null) {
        throw const NoActiveRecordingException(
          'Cannot append: No base recording is active.',
        );
      }
      final basePath = _currentRecordingPath!;
      // Concatenate the base path and the new segment
      final concatenatedPath = await localDataSource.concatenateRecordings(
        [basePath, segmentPath],
      );
      // Clean up the temporary segment file
      /* try {
        await localDataSource.deleteRecording(segmentPath);
      } catch (e) {
        logger.w('Failed to delete temporary segment file after concatenation', error: e, context: {'segmentPath': segmentPath});
        // Don't fail the whole operation, just log the cleanup failure
      } */

      // Update the current recording path to the new concatenated file
      _currentRecordingPath = concatenatedPath;
      return concatenatedPath;
    }); */
  }
}
