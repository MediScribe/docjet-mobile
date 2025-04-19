import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/core/error/failures.dart';
// REMOVE import 'package:docjet_mobile/core/platform/file_system.dart';
// import 'dart:io' show FileSystemException; // Not needed if mocking

// Import the services to mock them
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart';

// Update GenerateMocks to mock the services
@GenerateMocks([
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  JobSyncService,
])
import 'job_lifecycle_test.mocks.dart';

// Add custom NetworkFailure for testing
class NetworkFailure extends Failure {}

void main() {
  late JobRepositoryImpl repository;
  // Declare mocks for the services
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  late MockJobSyncService mockSyncService;

  setUp(() {
    // Instantiate service mocks
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    mockSyncService = MockJobSyncService();

    // Instantiate repository with mocked services
    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      syncService: mockSyncService,
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
        final now = DateTime.now();

        // Initial job state (after creation)
        final initialJob = createJobEntity(
          localId: localId,
          text: jobText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.pending, // Status after creation
          createdAt: now,
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

        // --- Mock Service Behaviors ---

        // Create Job
        when(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).thenAnswer((_) async => Right(initialJob));

        // Sync (All sync logic is delegated to JobSyncService)
        when(
          mockSyncService.syncPendingJobs(),
        ).thenAnswer((_) async => const Right(unit));

        // Update Job
        const updateData = JobUpdateData(text: updatedText);
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
        verify(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).called(1);

        // 2. Initial Sync
        final syncResult1 = await repository.syncPendingJobs();
        expect(syncResult1, const Right(unit));
        verify(mockSyncService.syncPendingJobs()).called(1);

        // 3. Update Job
        final updateResult = await repository.updateJob(
          localId: localId,
          updates: updateData, // Use JobUpdateData object
        );
        expect(updateResult, Right(updatedJobPending));
        verify(
          mockWriterService.updateJob(localId: localId, updates: updateData),
        ).called(1);

        // 4. Second Sync
        final syncResult2 = await repository.syncPendingJobs();
        expect(syncResult2, const Right(unit));
        verify(mockSyncService.syncPendingJobs()).called(1); // Called again

        // 5. Delete Job (Mark)
        final deleteResult = await repository.deleteJob(localId);
        expect(deleteResult, const Right(unit));
        verify(mockDeleterService.deleteJob(localId)).called(1);

        // 6. Final Sync (Deletion process)
        final syncResult3 = await repository.syncPendingJobs();
        expect(syncResult3, const Right(unit));
        verify(
          mockSyncService.syncPendingJobs(),
        ).called(1); // Called a third time

        // Verify no more interactions
        verifyNoMoreInteractions(mockReaderService);
        verifyNoMoreInteractions(mockWriterService);
        verifyNoMoreInteractions(mockDeleterService);
        verifyNoMoreInteractions(mockSyncService);
      },
    );

    // DELETE ALL OTHER TESTS FROM THIS FILE
  });
}
