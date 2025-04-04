import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

class AudioRecorderRepositoryImpl implements AudioRecorderRepository {
  final AudioLocalDataSource localDataSource;

  AudioRecorderRepositoryImpl({required this.localDataSource});

  /// Helper function to execute data source calls and handle exceptions
  Future<Either<Failure, T>> _tryCatch<T>(
    Future<T> Function() action, {
    Failure Function(Object e)? onError,
  }) async {
    try {
      final result = await action();
      return Right(result);
    } catch (e) {
      // TODO: Implement more specific exception-to-failure mapping
      if (onError != null) {
        return Left(onError(e));
      }
      // Default/fallback failure
      if (e is UnimplementedError) {
        return Left(
          ConcatenationFailure('Concatenation feature not implemented'),
        );
      }
      return Left(PlatformFailure('Repository error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkPermission() async {
    try {
      final result = await localDataSource.checkPermission();
      return Right(result);
    } on Exception catch (_) {
      // TODO: Implement more specific exception-to-failure mapping
      // print('Failed to check permission: $e'); // Logging needed
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermission() async {
    return _tryCatch(
      () => localDataSource.requestPermission(),
      onError: (e) => PermissionFailure('Failed to request permission: $e'),
    );
  }

  @override
  Future<Either<Failure, String>> startRecording() async {
    return _tryCatch(
      () => localDataSource.startRecording(),
      onError: (e) => RecordingFailure('Failed to start recording: $e'),
    );
  }

  @override
  Future<Either<Failure, AudioRecord>> stopRecording() async {
    return _tryCatch<AudioRecord>(() async {
      final filePath = await localDataSource.stopRecording();
      final duration = await localDataSource.getAudioDuration(filePath);
      return AudioRecord(
        filePath: filePath,
        duration: duration,
        createdAt:
            DateTime.now(), // Ideally, get creation time from file metadata
      );
    }, onError: (e) => RecordingFailure('Failed to stop recording: $e'));
  }

  @override
  Future<Either<Failure, void>> pauseRecording() async {
    return _tryCatch(
      () => localDataSource.pauseRecording(),
      onError: (e) => RecordingFailure('Failed to pause recording: $e'),
    );
  }

  @override
  Future<Either<Failure, void>> resumeRecording() async {
    return _tryCatch(
      () => localDataSource.resumeRecording(),
      onError: (e) => RecordingFailure('Failed to resume recording: $e'),
    );
  }

  @override
  Future<Either<Failure, void>> deleteRecording(String filePath) async {
    return _tryCatch(
      () => localDataSource.deleteRecording(filePath),
      onError:
          (e) => FileSystemFailure('Failed to delete recording $filePath: $e'),
    );
  }

  @override
  Future<Either<Failure, List<AudioRecord>>> loadRecordings() async {
    try {
      final filePaths = await localDataSource.listRecordingFiles();
      final List<AudioRecord> records = [];
      for (final path in filePaths) {
        try {
          final duration = await localDataSource.getAudioDuration(path);
          // TODO: Get actual creation date from file system
          records.add(
            AudioRecord(
              filePath: path,
              duration: duration,
              createdAt: DateTime.now(),
            ),
          );
        } catch (e) {
          // TODO: Specific failure types based on exception 'e'
          // print('Error loading record $path: $e'); // Skip problematic files - Logging needed
          // Continue processing other files
        }
      }
      // Optionally sort records by date?
      return Right(records);
    } catch (e) {
      // TODO: Specific failure types based on exception 'e'
      // print('Failed to load recordings: $e'); // Logging needed
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, AudioRecord>> appendToRecording(
    AudioRecord existingRecord,
  ) async {
    // This involves starting a new recording, stopping it, then concatenating
    return _tryCatch<AudioRecord>(
      () async {
        // 1. Start a new temporary recording (this returns the *new* segment path)
        // final newSegmentPath = await localDataSource.startRecording(); // Result unused before error
        await localDataSource.startRecording(); // Call without assignment
        // print('Started temp recording for append at: $newSegmentPath'); // Removed print
        // --- User interacts, then triggers stop/append ---
        // Assume stopRecording below is triggered externally when user is done adding audio
        // You might need a different flow depending on UI interaction.
        // This implementation implies stopRecording *completes* the append operation.

        // 2. Stop the temporary recording
        // We actually don't call stopRecording directly here in this model,
        // the stopRecording call below will handle the temporary segment
        // This needs careful state management in the Cubit/Use Case
        throw UnimplementedError(
          'Append flow needs refinement in UseCase/Cubit',
        );
      },
      onError: (e) {
        // This error handling might be too simplistic
        if (e is UnimplementedError) {
          return ConcatenationFailure('Append/Concatenation not implemented');
        }
        return RecordingFailure('Failed during append operation: $e');
      },
    );

    // ===> REVISED stopRecording logic needed <===
    // The standard stopRecording needs to be aware if it's stopping a
    // regular recording OR the second part of an append operation.
    // Let's adjust the standard stopRecording to handle this concept later
    // or create a dedicated stopAndAppendUseCase.
    // For now, let's modify stopRecording's _tryCatch

    /* Alternative flow for append:
       1. Cubit calls a startAppendRecording(existingRecord) use case.
       2. UseCase tells repo to start temp recording.
       3. Cubit state changes to `RecordingAppend(existingRecord, tempPath)`.
       4. User hits stop.
       5. Cubit calls stopAndAppendRecording() use case.
       6. UseCase tells repo to stop temp recording.
       7. UseCase tells repo to concatenate(existingRecord.path, tempPath).
       8. UseCase tells repo to delete original and temp files.
       9. UseCase returns final AudioRecord.
     */
  }

  @override
  Future<Either<Failure, List<AudioRecord>>> listRecordings() async {
    try {
      final filePaths = await localDataSource.listRecordingFiles();
      final List<AudioRecord> records = [];
      for (final filePath in filePaths) {
        // TODO: Improve efficiency - maybe get duration/created date in bulk?
        final duration = await localDataSource.getAudioDuration(filePath);
        // TODO: Get actual creation date from file system metadata
        final createdAt = DateTime.now(); // Placeholder
        records.add(
          AudioRecord(
            filePath: filePath,
            duration: duration,
            createdAt: createdAt,
          ),
        );
      }
      return Right(records);
    } catch (e) {
      // TODO: Specific failure types based on exception 'e'
      // print('Error listing recordings: $e'); // Removed print
      return Left(CacheFailure()); // Or a more specific failure
    }
  }
}
