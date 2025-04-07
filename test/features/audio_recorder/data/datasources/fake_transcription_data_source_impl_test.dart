import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/fake_transcription_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:collection/collection.dart';

void main() {
  late FakeTranscriptionDataSourceImpl dataSource;

  setUp(() {
    // Re-initialize with fresh data for each test
    dataSource = FakeTranscriptionDataSourceImpl();
  });

  group('getUserJobs', () {
    test('should return the predefined list of fake jobs', () async {
      // Act
      final result = await dataSource.getUserJobs();

      // Assert
      expect(result.isRight(), true);
      result.fold((failure) => fail('Expected Right, got Left($failure)'), (
        jobs,
      ) {
        expect(jobs, isA<List<Transcription>>());
        expect(jobs.length, greaterThan(0)); // Check it returns *something*
        // Add more specific checks based on the initial fake data if needed
        expect(jobs.first.id, isNotNull);
        expect(jobs.first.localFilePath, isNotNull);
      });
    });

    test('should simulate an API error when configured', () async {
      // Arrange
      dataSource.simulateApiError =
          true; // Configure the fake to throw an error

      // Act
      final result = await dataSource.getUserJobs();

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        expect(failure.message, contains('Simulated API error'));
      }, (jobs) => fail('Expected Left, got Right($jobs)'));

      // Reset for subsequent tests if needed, though setUp does this
      dataSource.simulateApiError = false;
    });
  });

  group('getTranscriptionJob', () {
    const existingJobId =
        'f47ac10b-58cc-4372-a567-0e02b2c3d479'; // ID from fake data
    const nonExistentJobId = 'non-existent-id';

    test('should return the job when the ID exists', () async {
      // Act
      final result = await dataSource.getTranscriptionJob(existingJobId);

      // Assert
      expect(result.isRight(), true);
      result.fold((failure) => fail('Expected Right, got Left($failure)'), (
        job,
      ) {
        expect(job, isA<Transcription>());
        expect(job.id, existingJobId);
      });
    });

    test('should return ApiFailure when the ID does not exist', () async {
      // Act
      final result = await dataSource.getTranscriptionJob(nonExistentJobId);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        expect(failure.message, contains('Transcription job not found'));
      }, (job) => fail('Expected Left, got Right($job)'));
    });

    test('should simulate an API error when configured', () async {
      // Arrange
      dataSource.simulateApiError = true;

      // Act
      final result = await dataSource.getTranscriptionJob(existingJobId);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        expect(failure.message, contains('Simulated API error'));
      }, (job) => fail('Expected Left, got Right($job)'));
      dataSource.simulateApiError = false; // Reset
    });
  });

  group('uploadForTranscription', () {
    const testFilePath = '/path/to/new_recording.m4a';
    const testUserId = 'test-user-id';

    test(
      'should add the job to the internal list and return it with status submitted',
      () async {
        // Arrange
        final initialJobsResult = await dataSource.getUserJobs();
        final initialJobCount = initialJobsResult.fold(
          (_) => 0,
          (jobs) => jobs.length,
        );

        // Act
        final result = await dataSource.uploadForTranscription(
          localFilePath: testFilePath,
          userId: testUserId,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          newJob,
        ) {
          expect(newJob, isA<Transcription>());
          expect(newJob.localFilePath, testFilePath);
          expect(
            newJob.status,
            TranscriptionStatus.submitted,
          ); // Initial status post-upload
          expect(newJob.id, isNotNull); // Should assign a new ID
        });

        // Verify it was added to the list
        final finalJobsResult = await dataSource.getUserJobs();
        final int finalJobCount = finalJobsResult.fold(
          (_) => 0,
          (jobs) => jobs.length,
        );
        expect(finalJobCount, initialJobCount + 1);

        final addedJob = finalJobsResult.fold<Transcription?>(
          (_) => null,
          (jobs) =>
              jobs.firstWhereOrNull((j) => j.localFilePath == testFilePath),
        );
        expect(addedJob, isNotNull);
        expect(addedJob?.status, TranscriptionStatus.submitted);
      },
    );

    test(
      'should return ApiFailure if file path is invalid (e.g., empty)',
      () async {
        // Act
        final result = await dataSource.uploadForTranscription(
          localFilePath: '', // Invalid path
          userId: testUserId,
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ApiFailure>());
          expect(failure.message, contains('Invalid file path'));
        }, (job) => fail('Expected Left, got Right($job)'));
      },
    );

    test('should simulate an API error when configured', () async {
      // Arrange
      dataSource.simulateApiError = true;

      // Act
      final result = await dataSource.uploadForTranscription(
        localFilePath: testFilePath,
        userId: testUserId,
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        expect(failure.message, contains('Simulated API error'));
      }, (job) => fail('Expected Left, got Right($job)'));
      dataSource.simulateApiError = false; // Reset
    });
  });
}
