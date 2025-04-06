// import 'dart:io'; // Import dart:io for File operations - NO LONGER NEEDED

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import '../exceptions/audio_exceptions.dart'; // Import specific exceptions

class AudioRecorderRepositoryImpl implements AudioRecorderRepository {
  final AudioLocalDataSource localDataSource;

  AudioRecorderRepositoryImpl({required this.localDataSource});

  /// Helper function to execute data source calls and handle specific exceptions,
  /// mapping them to appropriate Failure types.
  Future<Either<Failure, T>> _tryCatch<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } on AudioPermissionException catch (e) {
      // TODO: Consider adding structured logging here and in other catch blocks
      return Left(PermissionFailure(e.message));
    } on AudioFileSystemException catch (e) {
      return Left(FileSystemFailure(e.message));
    } on AudioRecordingException catch (e) {
      return Left(RecordingFailure(e.message));
    } on NoActiveRecordingException catch (e) {
      // Map to RecordingFailure as it indicates an invalid state for the operation
      return Left(RecordingFailure(e.message));
    } on RecordingFileNotFoundException catch (e) {
      // File not found is a file system issue
      return Left(FileSystemFailure(e.message));
    } on AudioPlayerException catch (e) {
      // Treat player issues as Platform failures, as it's an external component interaction
      return Left(PlatformFailure('Audio player error: ${e.message}'));
    } on AudioConcatenationException catch (e) {
      return Left(ConcatenationFailure(e.message));
    } on UnimplementedError catch (e) {
      // Specific handling for unimplemented features, mapping to ConcatenationFailure
      // might be temporary if other features are marked Unimplemented.
      return Left(ConcatenationFailure(e.message ?? 'Feature not implemented'));
    } on ArgumentError catch (e) {
      // Catch invalid arguments specifically (e.g., from concatenation service)
      return Left(
        ValidationFailure(e.message),
      ); // Assuming ValidationFailure exists or is desired
    } catch (e) {
      // Catch-all for unexpected errors from the data source or other issues
      return Left(
        PlatformFailure(
          'An unexpected repository error occurred: ${e.toString()}',
        ),
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
  Future<Either<Failure, String>> startRecording() async {
    // Use the refined _tryCatch
    return _tryCatch(() => localDataSource.startRecording());
  }

  @override
  Future<Either<Failure, String>> stopRecording() async {
    // Just call the data source method and return the path.
    // Details like duration/creation are now handled by loadRecordings.
    return _tryCatch(() => localDataSource.stopRecording());
  }

  @override
  Future<Either<Failure, void>> pauseRecording() async {
    // Use the refined _tryCatch
    return _tryCatch(() => localDataSource.pauseRecording());
  }

  @override
  Future<Either<Failure, void>> resumeRecording() async {
    // Use the refined _tryCatch
    return _tryCatch(() => localDataSource.resumeRecording());
  }

  @override
  Future<Either<Failure, void>> deleteRecording(String filePath) async {
    // Use the refined _tryCatch
    return _tryCatch(() => localDataSource.deleteRecording(filePath));
  }

  @override
  Future<Either<Failure, List<AudioRecord>>> loadRecordings() async {
    // Simply call the new DataSource method which returns the full list
    // The _tryCatch helper handles potential exceptions from the DataSource
    // (like AudioFileSystemException if the directory fails)
    return _tryCatch(() => localDataSource.listRecordingDetails());
  }

  @override
  Future<Either<Failure, AudioRecord>> appendToRecording(
    AudioRecord existingRecord,
  ) async {
    // Immediately signal that the underlying concatenation is not implemented.
    // The _tryCatch helper will catch this and convert it appropriately
    // (likely to ConcatenationFailure based on current _tryCatch logic).
    return _tryCatch<AudioRecord>(() async {
      throw UnimplementedError(
        'Audio concatenation service not implemented (awaiting native solution).',
      );
    });
  }
}
