import 'package:dartz/dartz.dart';
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
import 'sync_pending_jobs_test.mocks.dart'; // Adjusted mock file name

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
  // Removed unused variable
  // final tExistingJobHiveModel = JobHiveModel(
  //   localId: 'job1-local-id',
  //   serverId: 'job1-server-id', // Assume it has been synced before
  //   userId: 'user123',
  //   status: JobStatus.completed.index, // Store enum index
  //   syncStatus: SyncStatus.synced.index, // Store enum index
  //   displayTitle: 'Original Title',
  //   audioFilePath: '/path/to/test.mp3',
  //   createdAt:
  //       DateTime.parse(
  //         '2023-01-01T10:00:00Z',
  //       ).toIso8601String(), // Store as String
  //   updatedAt:
  //       DateTime.parse(
  //         '2023-01-01T11:00:00Z',
  //       ).toIso8601String(), // Store as String
  //   displayText: 'Original display text', // Use existing field
  //   text: 'Original text',
  // );

  // Map the Hive model to a Job entity for use in tests expecting Job
  // final tJob = JobMapper.fromHiveModel(tExistingJobHiveModel); // Removed unused variable

  // --- NEW GROUP: syncPendingJobs ---
  group('syncPendingJobs', () {
    test(
      'should fetch pending jobs from local, create with remote, and update local status to synced on success',
      () async {
        // Arrange
        // --- Setup for a NEW pending job (serverId is null) ---
        final tPendingJobNew = Job(
          localId: 'pendingNewJob1',
          userId: 'user123',
          status: JobStatus.created,
          syncStatus: SyncStatus.pending,
          displayTitle: 'New Pending Job Sync Test',
          audioFilePath: '/local/new_pending.mp3',
          text: 'Some initial text',
          additionalText: 'Some additional text',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        final tPendingJobHiveModelNew = JobMapper.toHiveModel(tPendingJobNew);
        final tPendingJobsHiveListNew = [tPendingJobHiveModelNew];
        // Simulate the job returned by the server after creation (has serverId)
        final tSyncedJobFromServer = tPendingJobNew.copyWith(
          serverId: 'serverGeneratedId123', // Server assigns an ID
          status: JobStatus.submitted, // Status might change after API call
          syncStatus: SyncStatus.synced, // Should be synced after API call
          updatedAt: DateTime.now(), // Update timestamp
        );

        // 1. Stub localDataSource.getJobsToSync to return the new pending job
        when(
          mockLocalDataSource.getJobsToSync(),
        ).thenAnswer((_) async => tPendingJobsHiveListNew);

        // 2. Stub remoteDataSource.createJob to succeed
        when(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).thenAnswer((_) async => tSyncedJobFromServer);

        // 3. Stub localDataSource.updateJobSyncStatus to succeed
        when(
          mockLocalDataSource.updateJobSyncStatus(
            tPendingJobNew.localId, // Use the original localId
            SyncStatus.synced,
          ),
        ).thenAnswer((_) async => Future.value());

        // 4. Stub localDataSource.saveJobHiveModel to succeed for the updated job
        when(
          mockLocalDataSource.saveJobHiveModel(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await repository.syncPendingJobs();

        // Assert
        // 1. Check result is Right (success)
        expect(
          result,
          isA<Right<Failure, Unit>>(),
        ); // Expect Right<Failure, Unit>

        // 2. Verify localDataSource.getJobsToSync was called
        verify(mockLocalDataSource.getJobsToSync()).called(1);

        // 3. Verify remoteDataSource.createJob was called with correct arguments
        verify(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).called(1);

        // 4. Verify localDataSource.saveJobHiveModel was called to save the updated job
        final capturedHiveModel =
            verify(
                  mockLocalDataSource.saveJobHiveModel(captureAny),
                ).captured.single
                as JobHiveModel;
        // Check key fields of the saved model
        expect(
          capturedHiveModel.localId,
          tPendingJobNew.localId,
        ); // Must retain localId
        expect(
          capturedHiveModel.serverId,
          tSyncedJobFromServer.serverId,
        ); // Should have serverId
        expect(
          capturedHiveModel.syncStatus,
          SyncStatus.synced.index,
        ); // Should be synced

        // 5. Verify localDataSource.updateJobSyncStatus was called for the job ID with SyncStatus.synced
        verify(
          mockLocalDataSource.updateJobSyncStatus(
            tPendingJobNew.localId,
            SyncStatus.synced,
          ),
        ).called(1);

        // 6. Verify no other interactions with remote source or file system for this case
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );
        verifyNever(mockRemoteDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));

        // Verify no more interactions than expected
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    // TODO: Add test case for sync failure (remote throws exception) -> updates status to error
    // TODO: Add test case for partial sync success/failure
    // TODO: Add test case when there are no pending jobs to sync
    // TODO: Add integration tests covering full job lifecycle
  });
  // --- END NEW GROUP ---
} // End of main
