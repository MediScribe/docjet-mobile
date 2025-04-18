import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
// Import the now-existing implementation
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import the enum
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'; // Import SyncStatus
// CORRECTED: Import JobHiveModel
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Import the actual FileSystem class
import 'package:docjet_mobile/core/platform/file_system.dart';
// Import Uuid
import 'package:uuid/uuid.dart';

// Generate mocks for the dependencies
@GenerateMocks([
  JobRemoteDataSource,
  JobLocalDataSource,
  FileSystem,
  Uuid, // Add Uuid here
]) // Add FileSystem here
import 'update_job_test.mocks.dart'; // Adjusted mock file name

void main() {
  late JobRepositoryImpl repository;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockJobLocalDataSource mockLocalDataSource;
  late MockFileSystem mockFileSystem; // Declare mock file system
  late MockUuid mockUuid; // Declare mock Uuid

  setUp(() {
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockLocalDataSource = MockJobLocalDataSource();
    mockFileSystem = MockFileSystem(); // Instantiate mock file system
    mockUuid = MockUuid(); // Instantiate mock Uuid
    // Instantiate the repository
    repository = JobRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      fileSystemService: mockFileSystem, // Provide the mock file system
      uuid: mockUuid, // Provide the mock Uuid
    );
  });

  // Sample data for testing
  // Use the same JobHiveModel for consistency in tests needing it
  final tExistingJobHiveModel = JobHiveModel(
    localId: 'job1-local-id',
    serverId: 'job1-server-id', // Assume it has been synced before
    userId: 'user123',
    status: JobStatus.completed.index, // Store enum index
    syncStatus: SyncStatus.synced.index, // Store enum index
    displayTitle: 'Original Title',
    audioFilePath: '/path/to/test.mp3',
    createdAt:
        DateTime.parse(
          '2023-01-01T10:00:00Z',
        ).toIso8601String(), // Store as String
    updatedAt:
        DateTime.parse(
          '2023-01-01T11:00:00Z',
        ).toIso8601String(), // Store as String
    displayText: 'Original display text', // Use existing field
    text: 'Original text',
  );

  // Map the Hive model to a Job entity for use in tests expecting Job
  final tJob = JobMapper.fromHiveModel(tExistingJobHiveModel);

  group('updateJob', () {
    test(
      'should fetch existing job, update fields, set syncStatus to pending, and save',
      () async {
        // Arrange
        final jobId = tExistingJobHiveModel.localId;
        const updatedTitle = 'Updated Title';
        const updatedDisplayText = 'Updated display text';
        final updates = {
          'displayTitle': updatedTitle,
          'displayText': updatedDisplayText, // Use existing field
          // Note: status updates would likely happen via a separate mechanism/endpoint
        };

        // 1. Stub local fetch to return the existing model using the CORRECT method name
        when(
          mockLocalDataSource.getJobHiveModelById(jobId),
        ).thenAnswer((_) async => tExistingJobHiveModel);

        // 2. Stub local save to succeed
        when(
          mockLocalDataSource.saveJobHiveModel(any),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.updateJob(
          jobId: jobId,
          updates: updates,
        );

        // Assert
        // 1. Check the result is success (Right(Job))
        expect(result, isA<Right<Failure, Job>>());
        result.fold((failure) => fail('Expected success, got $failure'), (
          updatedJob,
        ) {
          // Verify the returned Job entity has the updates
          expect(updatedJob.displayTitle, updatedTitle);
          expect(updatedJob.displayText, updatedDisplayText);
          expect(
            updatedJob.syncStatus,
            SyncStatus.pending,
          ); // Should be pending
          expect(updatedJob.localId, jobId);
          expect(updatedJob.serverId, tExistingJobHiveModel.serverId);
          // Check that updatedAt was likely updated (tricky to test exact value without mocking time)
          expect(
            updatedJob.updatedAt.isAfter(tJob.updatedAt),
            isTrue,
            reason: 'updatedAt should be newer after update',
          );
        });

        // 2. Verify local fetch was called using the CORRECT method name
        verify(mockLocalDataSource.getJobHiveModelById(jobId)).called(1);

        // 3. Verify local save was called with the *correctly updated* model
        final verification = verify(
          mockLocalDataSource.saveJobHiveModel(captureAny),
        );
        verification.called(1);
        final capturedModel = verification.captured.single as JobHiveModel;

        // Deep check the captured argument - ensure it reflects the updates
        expect(capturedModel.localId, jobId);
        expect(capturedModel.serverId, tExistingJobHiveModel.serverId);
        expect(capturedModel.userId, tExistingJobHiveModel.userId);
        expect(
          capturedModel.status,
          tExistingJobHiveModel.status,
        ); // Status shouldn't change here
        expect(
          capturedModel.syncStatus,
          SyncStatus.pending.index, // CRITICAL: Check syncStatus index
          reason: 'SyncStatus should be pending after update',
        );
        expect(capturedModel.displayTitle, updatedTitle);
        expect(capturedModel.displayText, updatedDisplayText);
        expect(
          capturedModel.audioFilePath,
          tExistingJobHiveModel.audioFilePath,
        );
        expect(
          capturedModel.text,
          tExistingJobHiveModel.text,
        ); // Other fields unchanged
        // Check updatedAt string was updated (we expect ISO8601 format)
        expect(
          DateTime.parse(
            capturedModel.updatedAt!,
          ).isAfter(DateTime.parse(tExistingJobHiveModel.updatedAt!)),
          isTrue,
          reason: 'updatedAt timestamp string should be newer after update',
        );
        expect(capturedModel.createdAt, tExistingJobHiveModel.createdAt);

        // 4. Verify no other interactions
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockFileSystem);
        verifyNoMoreInteractions(mockUuid);
      },
    );

    test(
      'should return CacheFailure when local data source fails to get the job',
      () async {
        // Arrange
        final jobId = 'non-existent-job-id';
        final updates = {'displayTitle': 'Doesnt matter'};
        // Use CORRECT method name
        when(
          mockLocalDataSource.getJobHiveModelById(jobId),
        ).thenThrow(CacheException('Not found'));

        // Act
        final result = await repository.updateJob(
          jobId: jobId,
          updates: updates,
        );

        // Assert
        expect(result, isA<Left<Failure, Job>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected failure, got success'),
        );
        // Use CORRECT method name
        verify(mockLocalDataSource.getJobHiveModelById(jobId)).called(1);
        verifyNever(mockLocalDataSource.saveJobHiveModel(any));
        verifyNoMoreInteractions(mockLocalDataSource);
      },
    );

    test(
      'should return CacheFailure when local data source fails to save the job',
      () async {
        // Arrange
        final jobId = tExistingJobHiveModel.localId;
        final updates = {'displayTitle': 'Updated Title'};
        // Use CORRECT method name
        when(
          mockLocalDataSource.getJobHiveModelById(jobId),
        ).thenAnswer((_) async => tExistingJobHiveModel);
        when(
          mockLocalDataSource.saveJobHiveModel(any),
        ).thenThrow(CacheException('Disk full'));

        // Act
        final result = await repository.updateJob(
          jobId: jobId,
          updates: updates,
        );

        // Assert
        expect(result, isA<Left<Failure, Job>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected failure, got success'),
        );
        // Use CORRECT method name
        verify(mockLocalDataSource.getJobHiveModelById(jobId)).called(1);
        verify(
          mockLocalDataSource.saveJobHiveModel(any),
        ).called(1); // Save was attempted
        verifyNoMoreInteractions(mockLocalDataSource);
      },
    );
  }); // END group('updateJob')
} // End of main
