import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_sync_processor_service/_deletion_error_test.dart' as deletion_error;
import 'job_sync_processor_service/_deletion_success_test.dart'
    as deletion_success;
import 'job_sync_processor_service/_sync_error_test.dart' as sync_error;
// Import the individual test files
import 'job_sync_processor_service/_sync_success_test.dart' as sync_success;
import 'job_sync_processor_service/_logout_guard_test.dart' as logout_guard;
// Import generated mocks
import 'job_sync_processor_service_test.mocks.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';

// Generate mocks for all processor tests
@GenerateNiceMocks([
  MockSpec<JobLocalDataSource>(),
  MockSpec<JobRemoteDataSource>(),
  MockSpec<FileSystem>(),
  MockSpec<JobSyncOrchestratorService>(),
])
void main() {
  // Define Mocks and Service Instance variables
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockFileSystem mockFileSystem;
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;
  late JobSyncProcessorService jobSyncProcessorService;

  // Setup common mock behaviors before each test in the group
  setUp(() {
    // Re-initialize mocks before each test to ensure isolation
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockFileSystem = MockFileSystem();
    mockJobSyncOrchestratorService = MockJobSyncOrchestratorService();
    jobSyncProcessorService = JobSyncProcessorService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      fileSystem: mockFileSystem,
      isLogoutInProgress:
          () => mockJobSyncOrchestratorService.isLogoutInProgress,
    );

    // Add default stub for isLogoutInProgress for the main test file's service instance
    when(mockJobSyncOrchestratorService.isLogoutInProgress).thenReturn(false);

    // Default success for file deletion (can be overridden in specific tests)
    when(mockFileSystem.deleteFile(any)).thenAnswer((_) async => true);
  });

  group('JobSyncProcessorService Tests', () {
    // Run the tests from each imported file
    sync_success.main();
    sync_error.main();
    deletion_success.main();
    deletion_error.main();
    logout_guard.main();

    // Test case for retrying failed jobs after backoff
    test(
      'should retry a failed job after backoff period if manually triggered',
      () async {
        // Arrange: Create a job in error status that should be eligible for retry
        final backoffCompletionTime = DateTime.now().subtract(
          const Duration(minutes: 5),
        );

        final failedJob = Job(
          localId: 'local1',
          serverId: 'server1', // Existing job on server
          userId: 'user1',
          displayTitle: 'Test Job',
          status: JobStatus.created,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
          syncStatus: SyncStatus.error,
          retryCount: 1,
          // Set timestamp to simulate that backoff period has passed
          lastSyncAttemptAt: backoffCompletionTime,
          audioFilePath: null,
        );

        // Prepare server response data (updatedJob that will be returned)
        final updatedJob = failedJob.copyWith(
          syncStatus: SyncStatus.synced,
          retryCount: 1, // Retry count remains the same after successful retry
          lastSyncAttemptAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Explicitly assert and store serverId to satisfy analyzer
        final serverId = failedJob.serverId;
        expect(
          serverId,
          isNotNull,
          reason: 'Test setup assumes serverId exists',
        );
        if (serverId == null) return; // To satisfy analyzer

        // Mock the remote updateJob call to succeed
        when(
          mockRemoteDataSource.updateJob(
            jobId: serverId,
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async => updatedJob);

        // Mock the local saveJob call
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

        // Act: Process the job
        final result = await jobSyncProcessorService.processJobSync(failedJob);

        // Assert: Verify result is successful
        expect(
          result.isRight(),
          isTrue,
          reason: 'Job sync after backoff period should succeed',
        );

        // Verify remote updateJob was called
        verify(
          mockRemoteDataSource.updateJob(
            jobId: serverId,
            updates: anyNamed('updates'),
          ),
        ).called(1);

        // Verify local saveJob was called and captured the job
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;

        // Assert the saved job has proper values
        expect(
          captured.syncStatus,
          SyncStatus.synced,
          reason: 'Job should be marked as synced',
        );
        expect(
          captured.serverId,
          serverId,
          reason: 'ServerId should remain the same',
        );
      },
    );
  });
}
