import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart'; // Fixed import
import 'package:docjet_mobile/core/utils/logger.dart'; // Import the logger
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:uuid/uuid.dart'; // TODO: Add uuid dependency

/// A fake implementation of [TranscriptionRemoteDataSource] for development and testing.
///
/// Simulates API calls with predefined data and optional delays/errors.
class FakeTranscriptionDataSourceImpl implements TranscriptionRemoteDataSource {
  final Uuid _uuid = const Uuid();
  final Duration? simulatedDelay;
  final Map<String, Transcription> _fakeJobs = {};

  /// If true, methods will return a [Left] with an [ApiFailure].
  bool simulateApiError = false;

  FakeTranscriptionDataSourceImpl({this.simulatedDelay}) {
    // Constructor body intentionally left empty - NO SAMPLE DATA ADDED HERE
    logger.i('[FAKE DATASOURCE] Initialized (starts empty).'); // Use logger.i
  }

  /// Helper to add a job (used internally, e.g., by upload)
  // void _addFakeJob(TranscriptionModel job) {
  //   _fakeJobs[job.id] = job;
  // }

  @override
  Future<Either<ApiFailure, List<Transcription>>> getUserJobs() async {
    await Future.delayed(simulatedDelay ?? const Duration(milliseconds: 300));

    if (simulateApiError) {
      // TODO: Define specific ApiFailure types
      return const Left(ApiFailure(message: "Simulated API error"));
    }

    return Right(_fakeJobs.values.toList());
  }

  @override
  Future<Either<ApiFailure, Transcription>> getTranscriptionJob(
    String backendId,
  ) async {
    await Future.delayed(simulatedDelay ?? const Duration(milliseconds: 300));

    if (simulateApiError) {
      return const Left(ApiFailure(message: "Simulated API error"));
    }

    final job = _fakeJobs[backendId];
    if (job != null) {
      return Right(job);
    } else {
      // TODO: Define specific ApiFailure types (e.g., NotFoundFailure)
      return const Left(ApiFailure(message: "Transcription job not found"));
    }
  }

  @override
  Future<Either<ApiFailure, Transcription>> uploadForTranscription({
    required String localFilePath,
    required String userId, // Included but not used in fake
    String? text,
    String? additionalText,
  }) async {
    await Future.delayed(simulatedDelay ?? const Duration(milliseconds: 300));

    if (simulateApiError) {
      return const Left(ApiFailure(message: "Simulated API error"));
    }

    // --- Add Input Validation ---
    if (localFilePath.isEmpty) {
      return const Left(
        ApiFailure(message: "Invalid file path: cannot be empty."),
      );
    }
    // You could add more checks here, e.g., basic path format
    // --- End Validation ---

    final newId = _uuid.v4();
    final now = DateTime.now();
    final newJob = Transcription(
      id: newId,
      localFilePath: localFilePath,
      status: TranscriptionStatus.submitted, // Initial status after upload
      localCreatedAt: now, // Should ideally come from LocalJob, but faked here
      backendCreatedAt: now,
      backendUpdatedAt: now,
      // Duration should come from LocalJob; faked if needed for testing
      localDurationMillis:
          30000 + (localFilePath.hashCode % 30000), // Fake duration
      displayTitle: 'New Upload: ${localFilePath.split('/').last}',
    );

    // Uncomment the line below to actually add the job to the map
    _fakeJobs[newJob.id!] = newJob;
    // _addFakeJob(newJob); // Remove reference to the potentially non-existent helper
    return Right(newJob);
  }

  // Helper methods for testing
  void clearJobs() {
    _fakeJobs.clear();
  }

  void addJob(Transcription job) {
    if (job.id != null) {
      _fakeJobs[job.id!] = job;
      logger.d(
        '[FAKE DATASOURCE] Manually added job: ${job.id}',
      ); // Use logger.d
    } else {
      logger.w(
        '[FAKE DATASOURCE] Attempted to add job with null ID. Skipping.',
      ); // Use logger.w
    }
  }

  Map<String, Transcription> get jobs => Map.unmodifiable(_fakeJobs);
}
