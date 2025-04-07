import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart'; // Fixed import
import 'package:uuid/uuid.dart'; // TODO: Add uuid dependency

import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';

/// A fake implementation of [TranscriptionRemoteDataSource] for development and testing.
///
/// Simulates API calls with predefined data and optional delays/errors.
class FakeTranscriptionDataSourceImpl implements TranscriptionRemoteDataSource {
  final Uuid _uuid = const Uuid();

  // In-memory storage for fake transcription jobs
  final Map<String, Transcription> _fakeJobs = {};

  /// If true, methods will return a [Left] with an [ApiFailure].
  bool simulateApiError = false;

  /// Optional delay to simulate network latency.
  final Duration? simulatedDelay;

  FakeTranscriptionDataSourceImpl({this.simulatedDelay}) {
    // Initialize with some default fake data
    _addFakeJob(
      Transcription(
        id: 'f47ac10b-58cc-4372-a567-0e02b2c3d479', // Use the ID from the test
        localFilePath: '/fake/path/recording1.m4a',
        status: TranscriptionStatus.completed,
        localCreatedAt: DateTime.now().subtract(const Duration(days: 1)),
        backendCreatedAt: DateTime.now().subtract(const Duration(days: 1)),
        backendUpdatedAt: DateTime.now().subtract(const Duration(hours: 12)),
        localDurationMillis: 123456,
        displayTitle: 'Completed Recording 1',
        displayText: 'This is the transcript text...',
      ),
    );
    _addFakeJob(
      Transcription(
        id: _uuid.v4(),
        localFilePath: '/fake/path/processing_audio.m4a',
        status: TranscriptionStatus.processing,
        localCreatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        backendCreatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        backendUpdatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        localDurationMillis: 45000,
        displayTitle: 'Processing Notes',
        displayText: null,
      ),
    );
    _addFakeJob(
      Transcription(
        id: _uuid.v4(),
        localFilePath: '/fake/path/failed_audio.m4a',
        status: TranscriptionStatus.failed,
        localCreatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        backendCreatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        backendUpdatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        localDurationMillis: 15200,
        displayTitle: 'Failed Upload Attempt',
        displayText: null,
        errorCode: 'UPLOAD_TIMEOUT',
        errorMessage: 'The upload took too long to complete.',
      ),
    );
  }

  void _addFakeJob(Transcription job) {
    if (job.id != null) {
      _fakeJobs[job.id!] = job;
    }
  }

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

    _addFakeJob(newJob);
    return Right(newJob);
  }

  // Helper methods for testing
  void clearJobs() {
    _fakeJobs.clear();
  }

  void addJob(Transcription job) {
    _addFakeJob(job);
  }

  Map<String, Transcription> get jobs => Map.unmodifiable(_fakeJobs);
}
