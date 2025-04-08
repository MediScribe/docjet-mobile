import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/fake_transcription_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

void main() {
  late FakeTranscriptionDataSourceImpl dataSource;

  setUp(() {
    // Re-initialize with fresh data for each test
    dataSource = FakeTranscriptionDataSourceImpl();
  });

  group('getUserJobs', () {
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

    test(
      'getUserJobs returns initial empty list when no jobs are added',
      () async {
        // Arrange: DataSource is already initialized empty

        // Act
        final result = await dataSource.getUserJobs();

        // Assert
        result.fold(
          (failure) => fail('Expected success but got failure: $failure'),
          (jobs) {
            expect(jobs, isA<List<Transcription>>());
            expect(jobs.length, 0); // Check it returns exactly 0 jobs now
          },
        );
      },
    );

    test('getTranscriptionJob returns failure for non-existent ID', () async {
      // Arrange: DataSource is empty

      // Act
      final result = await dataSource.getTranscriptionJob('non-existent-id');

      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure.message,
          'Transcription job not found',
        ), // Check error
        (job) => fail('Expected failure but got success: $job'),
      );
    });

    test('getUserJobs returns jobs previously added via addJob', () async {
      // Arrange
      final testJob = Transcription(
        id: 'test-job-1',
        localFilePath: '/test/path',
        status: TranscriptionStatus.completed,
        localCreatedAt: DateTime.now(),
      );
      dataSource.addJob(testJob); // Manually add the job

      // Act
      final result = await dataSource.getUserJobs();

      // Assert
      result.fold(
        (failure) => fail('Expected success but got failure: $failure'),
        (jobs) {
          expect(jobs, isA<List<Transcription>>());
          expect(jobs.length, 1); // Expect the 1 job we added
          expect(jobs.first.id, 'test-job-1');
        },
      );
    });

    test('getUserJobs should simulate an API error when configured', () async {
      // Arrange
      dataSource.simulateApiError = true;

      // Act
      final result = await dataSource.getUserJobs();

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        expect(failure.message, contains('Simulated API error'));
      }, (jobs) => fail('Expected Left, got Right($jobs)'));
      dataSource.simulateApiError = false; // Reset
    });
  });

  group('getTranscriptionJob', () {
    // Define the sample job HERE, before the tests that use it
    final testJob = Transcription(
      id: 'existing-job-id-2', // Use a distinct ID
      localFilePath: '/test/existing',
      status: TranscriptionStatus.completed,
      localCreatedAt: DateTime.now(),
    );
    const nonExistentJobId = 'non-existent-id';

    test('should return ApiFailure when the ID does not exist', () async {
      // Act
      final result = await dataSource.getTranscriptionJob(nonExistentJobId);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        expect(failure.message, contains('Transcription job not found'));
      }, (job) => fail('Expected Left, got Right($job)'));
      dataSource.simulateApiError = false; // Reset
    });

    test('should return the job when the ID exists after adding it', () async {
      // Arrange
      dataSource.addJob(testJob); // Add the job first

      // Act
      final result = await dataSource.getTranscriptionJob(
        testJob.id!,
      ); // Use the added job's ID

      // Assert
      expect(result.isRight(), isTrue);
      result.fold((failure) => fail('Expected Right, got Left($failure)'), (
        job,
      ) {
        expect(job, isA<Transcription>());
        expect(job.id, testJob.id);
        expect(job.localFilePath, testJob.localFilePath);
      });
    });

    test('should simulate an API error when configured', () async {
      // Arrange
      dataSource.simulateApiError = true;

      // Act
      final result = await dataSource.getTranscriptionJob(testJob.id!);

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
    const testFilePath = '/path/to/test/audio.m4a';
    const testUserId = 'user-123';

    test('successfully adds a job and returns it', () async {
      // Arrange: Check initial state is empty
      final initialResult = await dataSource.getUserJobs();
      int initialJobCount = 0;
      initialResult.fold(
        (l) => fail('Failed to get initial jobs'),
        (r) => initialJobCount = r.length,
      );
      expect(
        initialJobCount,
        0,
        reason: 'DataSource should start empty', // Expect 0 jobs initially
      );

      // Act
      final result = await dataSource.uploadForTranscription(
        localFilePath: testFilePath,
        userId: testUserId,
      );

      // Assert: Check the returned result
      expect(result.isRight(), isTrue);
      result.fold((failure) => fail('Upload failed unexpectedly: $failure'), (
        newJob,
      ) {
        expect(newJob, isA<Transcription>());
        expect(newJob.localFilePath, testFilePath);
        expect(newJob.status, TranscriptionStatus.submitted);
        expect(newJob.id, isNotNull);
      });

      // Assert: Check the job list state after upload
      final finalResult = await dataSource.getUserJobs();
      finalResult.fold(
        (failure) => fail('Failed to get jobs after upload: $failure'),
        (jobs) {
          expect(
            jobs.length,
            1, // Expect 1 job after upload
            reason: 'Job count should increase by one after upload',
          );
          expect(jobs.first.localFilePath, testFilePath);
        },
      );
    });

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
