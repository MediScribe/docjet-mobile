import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/core/error/failures.dart';
// REMOVE import 'package:docjet_mobile/core/platform/file_system.dart';
// import 'dart:io' show FileSystemException; // Not needed if mocking

// Import the services to mock them
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
// import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart'; // OLD
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'; // NEW
// Added this line

// Update GenerateMocks to mock the services
@GenerateMocks([
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  // JobSyncService, // OLD
  JobSyncOrchestratorService, // NEW
  AuthSessionProvider, // Add AuthSessionProvider
])
import 'job_lifecycle_test.mocks.dart';

// Add custom NetworkFailure for testing
class NetworkFailure extends Failure {
  @override
  String get message => 'Network connection failed'; // Provide a default message
}

void main() {
  late JobRepositoryImpl repository;
  // Declare mocks for the services
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  // late MockJobSyncService mockSyncService; // OLD
  late MockJobSyncOrchestratorService mockOrchestratorService; // NEW
  late MockAuthSessionProvider mockAuthSessionProvider;

  setUp(() {
    // Instantiate service mocks
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    // mockSyncService = MockJobSyncService(); // OLD
    mockOrchestratorService = MockJobSyncOrchestratorService(); // NEW
    mockAuthSessionProvider = MockAuthSessionProvider();

    // Instantiate repository with mocked services
    // This needs the processor too now, which wasn't mocked here.
    // Since this test focuses on lifecycle delegation *through* the repo,
    // and sync is now split, mocking just the orchestrator might be enough
    // for *this specific test's current scope*, but it's fragile.
    // For now, let's update the constructor call as per JobRepositoryImpl's signature.
    // We'll need to add the processor mock if tests fail later.
    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      // syncService: mockSyncService, // OLD
      orchestratorService: mockOrchestratorService, // NEW
      authSessionProvider: mockAuthSessionProvider,
      // TODO: Add processor mock if needed for more detailed sync tests
      // processorService:
      //     MockJobSyncProcessorService(), // REMOVED: Repo doesn't take processor
    );
  });

  // Helper function to create a Job entity
  Job createJobEntity({
    required String localId,
    String? serverId,
    required String text,
    required String audioFilePath,
    required SyncStatus syncStatus,
    required DateTime createdAt,
    JobStatus status = JobStatus.created,
    String userId = 'test-user-id',
  }) {
    return Job(
      localId: localId,
      serverId: serverId,
      text: text,
      audioFilePath: audioFilePath,
      syncStatus: syncStatus,
      status: status,
      createdAt: createdAt,
      updatedAt: createdAt,
      userId: userId,
      displayTitle: '',
      displayText: '',
    );
  }

  group('Job Lifecycle Integration Tests', () {
    // KEEP ONLY THIS TEST - Focus on repository delegation in a lifecycle
    test(
      'should delegate lifecycle operations correctly: create → sync → update → sync → delete → sync',
      () async {
        // --- Arrange ---
        const audioPath = '/path/to/audio.mp3';
        const jobText = 'Test transcription';
        const updatedText = 'Updated transcription';
        const localId = 'local-uuid-1234';
        const serverId = 'server-id-5678';
        const userId = 'integration-test-user';
        final now = DateTime.now();

        // Set up the mock auth session provider to return the test user ID
        when(mockAuthSessionProvider.getCurrentUserId()).thenReturn(userId);

        // Initial job state (after creation)
        final initialJob = createJobEntity(
          localId: localId,
          text: jobText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.pending, // Status after creation
          createdAt: now,
          userId: userId,
        );

        // Synced job state (after first sync)
        final syncedJob = initialJob.copyWith(
          serverId: serverId,
          syncStatus: SyncStatus.synced,
        );

        // Updated job state (after update call, before second sync)
        final updatedJobPending = syncedJob.copyWith(
          text: updatedText,
          syncStatus: SyncStatus.pending, // Status after update
        );

        // Define both domain and data objects for clarity in the test
        final JobUpdateDetails updateDetails = JobUpdateDetails(
          text: updatedText,
        );
        final JobUpdateData updateData = JobUpdateData(text: updatedText);

        // --- Mock Service Behaviors ---

        // Create Job
        when(
          mockWriterService.createJob(
            userId: userId,
            audioFilePath: audioPath,
            text: jobText,
          ),
        ).thenAnswer((_) async => Right(initialJob));

        // Sync (All sync logic is delegated to JobSyncOrchestratorService now)
        when(
          mockOrchestratorService.syncPendingJobs(), // Use orchestrator mock
        ).thenAnswer((_) async => const Right(unit));

        // Update Job
        when(
          mockWriterService.updateJob(localId: localId, updates: updateData),
        ).thenAnswer((_) async => Right(updatedJobPending));

        // Delete Job (mark for deletion)
        when(
          mockDeleterService.deleteJob(localId),
        ).thenAnswer((_) async => const Right(unit));

        // --- Act & Assert ---

        // 1. Create Job
        final createResult = await repository.createJob(
          audioFilePath: audioPath,
          text: jobText,
        );
        expect(createResult, Right(initialJob));
        verify(mockAuthSessionProvider.getCurrentUserId()).called(1);
        verify(
          mockWriterService.createJob(
            userId: userId,
            audioFilePath: audioPath,
            text: jobText,
          ),
        ).called(1);

        // 2. Initial Sync
        final syncResult1 = await repository.syncPendingJobs();
        expect(syncResult1, const Right(unit));
        verify(
          mockOrchestratorService.syncPendingJobs(),
        ).called(1); // Verify orchestrator

        // 3. Update Job
        final updateResult = await repository.updateJob(
          localId: localId,
          updates: updateDetails, // Pass the DOMAIN object here
        );
        expect(updateResult, Right(updatedJobPending));
        verify(
          mockWriterService.updateJob(localId: localId, updates: updateData),
        ).called(1);

        // 4. Second Sync
        final syncResult2 = await repository.syncPendingJobs();
        expect(syncResult2, const Right(unit));
        verify(
          mockOrchestratorService.syncPendingJobs(),
        ).called(1); // Called again

        // 5. Delete Job (Mark)
        final deleteResult = await repository.deleteJob(localId);
        expect(deleteResult, const Right(unit));
        verify(mockDeleterService.deleteJob(localId)).called(1);

        // 6. Final Sync (Deletion process)
        final syncResult3 = await repository.syncPendingJobs();
        expect(syncResult3, const Right(unit));
        verify(
          mockOrchestratorService.syncPendingJobs(), // Verify orchestrator
        ).called(1); // Called a third time

        // Verify no more interactions
        verifyNoMoreInteractions(mockReaderService);
        verifyNoMoreInteractions(mockWriterService);
        verifyNoMoreInteractions(mockDeleterService);
        verifyNoMoreInteractions(
          mockOrchestratorService,
        ); // Check orchestrator mock
        verifyNoMoreInteractions(mockAuthSessionProvider);
      },
    );

    // DELETE ALL OTHER TESTS FROM THIS FILE
  });
}

// REMOVED: Manual mock class definition
// class MockJobSyncProcessorService extends Mock
//     implements JobSyncProcessorService {}
