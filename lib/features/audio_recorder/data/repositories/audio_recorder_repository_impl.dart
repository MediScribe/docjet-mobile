import 'dart:io'; // Import dart:io for File operations

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
  Future<Either<Failure, AudioRecord>> stopRecording() async {
    return _tryCatch<AudioRecord>(() async {
      final filePath = await localDataSource.stopRecording();
      // If stopRecording succeeded, attempt to get duration and file stats
      final duration = await localDataSource.getAudioDuration(filePath);
      // Get file stats to find the modification time
      final fileStat = await File(filePath).stat();
      return AudioRecord(
        filePath: filePath,
        duration: duration,
        createdAt: fileStat.modified, // Use actual file modification time
      );
    });
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
    final filePathsEither = await _tryCatch(localDataSource.listRecordingFiles);

    return filePathsEither.fold((failure) => Left(failure), (filePaths) async {
      final List<AudioRecord> records = [];
      for (final path in filePaths) {
        try {
          // Get duration and file stats individually
          final duration = await localDataSource.getAudioDuration(path);
          final fileStat = await File(path).stat();
          records.add(
            AudioRecord(
              filePath: path,
              duration: duration,
              createdAt: fileStat.modified, // Use actual file modification time
            ),
          );
        } on AudioPlayerException /* catch (e) */ {
          // Log or handle skipped file due to player error
        } on RecordingFileNotFoundException /* catch (e) */ {
          // Log or handle skipped file due to not found error
        } on FileSystemException /* catch (e) */ {
          // Log or handle skipped file due to stat() error
        } catch (_) {
          // Use catch (_) since 'e' is unused
          // Log or handle skipped file due to unexpected error
        }
      }
      // Optionally sort records by date?
      return Right(records);
    });
  }

  @override
  Future<Either<Failure, AudioRecord>> appendToRecording(
    AudioRecord existingRecord,
  ) async {
    // Use the refined _tryCatch. It will handle the UnimplementedError.
    return _tryCatch<AudioRecord>(() async {
      // Current logic still throws UnimplementedError
      await localDataSource.startRecording(); // Example step
      throw UnimplementedError('Append flow needs refinement in UseCase/Cubit');
    });
  }

  @override
  Future<Either<Failure, List<AudioRecord>>> listRecordings() async {
    final filePathsEither = await _tryCatch(localDataSource.listRecordingFiles);

    return filePathsEither.fold((failure) => Left(failure), (filePaths) async {
      final List<AudioRecord> records = [];
      for (final filePath in filePaths) {
        try {
          // Get duration and file stats individually
          final duration = await localDataSource.getAudioDuration(filePath);
          final fileStat = await File(filePath).stat();
          records.add(
            AudioRecord(
              filePath: filePath,
              duration: duration,
              createdAt: fileStat.modified, // Use actual file modification time
            ),
          );
        } on AudioPlayerException /* catch (e) */ {
          // Log or handle skipped file due to player error
        } on RecordingFileNotFoundException /* catch (e) */ {
          // Log or handle skipped file due to not found error
        } on FileSystemException /* catch (e) */ {
          // Log or handle skipped file due to stat() error
        } catch (_) {
          // Use catch (_) since 'e' is unused
          // Log or handle skipped file due to unexpected error
        }
      }
      return Right(records);
    });
  }
}
