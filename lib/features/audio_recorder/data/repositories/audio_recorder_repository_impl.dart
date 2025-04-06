// import 'dart:io'; // Import dart:io for File operations - NO LONGER NEEDED

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
// Import for @visibleForTesting

// Core
import 'package:docjet_mobile/core/error/failures.dart';

// Data Layer
import '../datasources/audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

// Domain Layer
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

class AudioRecorderRepositoryImpl implements AudioRecorderRepository {
  final AudioLocalDataSource localDataSource;

  // --- State Management --- //
  String?
  _currentRecordingPath; // Manages the path of the active recording session

  AudioRecorderRepositoryImpl({required this.localDataSource});

  /// Helper function to execute data source calls and handle exceptions
  Future<Either<Failure, T>> _tryCatch<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } on AudioPermissionException catch (e) {
      debugPrint(
        'AudioPermissionException caught in Repository: ${e.message}, Original: ${e.originalException}',
      );
      return Left(PermissionFailure(e.message));
    } on NoActiveRecordingException catch (e) {
      debugPrint(
        'NoActiveRecordingException caught in Repository: ${e.message}',
      );
      return Left(RecordingFailure(e.message));
    } on RecordingFileNotFoundException catch (e) {
      debugPrint(
        'RecordingFileNotFoundException caught in Repository: ${e.message}',
      );
      return Left(FileSystemFailure(e.message));
    } on AudioRecordingException catch (e) {
      debugPrint(
        'AudioRecordingException caught in Repository: ${e.message}, Original: ${e.originalException}',
      );
      return Left(RecordingFailure(e.message));
    } on AudioFileSystemException catch (e) {
      debugPrint(
        'AudioFileSystemException caught in Repository: ${e.message}, Original: ${e.originalException}',
      );
      return Left(FileSystemFailure(e.message));
    } on AudioConcatenationException catch (e) {
      debugPrint(
        'AudioConcatenationException caught in Repository: ${e.message}, Original: ${e.originalException}',
      );
      return Left(ConcatenationFailure(e.message));
    } on AudioException catch (e) {
      // Catch any other specific audio exceptions that might not be listed above
      debugPrint(
        'Generic AudioException caught in Repository: ${e.message}, Original: ${e.originalException}',
      );
      return Left(PlatformFailure(e.message));
    } on ArgumentError catch (e) {
      // Catch argument errors specifically (e.g., from concatenation service)
      debugPrint('ArgumentError caught in Repository: ${e.message}');
      return Left(PlatformFailure('Invalid input: ${e.message}'));
    } catch (e) {
      // Catch all other unexpected errors
      debugPrint('Unexpected error caught in Repository: $e');
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
    return _tryCatch<void>(() => localDataSource.deleteRecording(filePath));
  }

  @override
  Future<Either<Failure, List<AudioRecord>>> loadRecordings() {
    // This now directly calls the data source method which handles listing
    return _tryCatch<List<AudioRecord>>(
      () => localDataSource.listRecordingDetails(),
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
      try {
        await localDataSource.deleteRecording(segmentPath);
      } catch (e) {
        debugPrint(
          'Warning: Failed to delete temporary segment file $segmentPath after concatenation: $e',
        );
        // Don't fail the whole operation, just log the cleanup failure
      }

      // Update the current recording path to the new concatenated file
      _currentRecordingPath = concatenatedPath;
      return concatenatedPath;
    }); */
  }
}
