import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../job_sync_processor_service_test.mocks.dart'; // Import the main test's mocks

void main() {
  // Re-declare mocks and service for this scope, they will be set up in the main test file's setUp
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;
  late JobSyncProcessorService jobSyncProcessorService;

  // Helper to create a dummy job
  Job createTestJob({
    String localId = 'local1',
    String? serverId,
    SyncStatus syncStatus = SyncStatus.pending,
    int retryCount = 0,
    String? audioFilePath = 'path/to/audio.aac',
  }) {
    return Job(
      localId: localId,
      serverId: serverId,
      userId: 'user1',
      displayTitle: 'Test Job',
      status: JobStatus.created,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      syncStatus: syncStatus,
      retryCount: retryCount,
      audioFilePath: audioFilePath,
    );
  }

  group('Logout Guard in JobSyncProcessorService', () {
    // This setUp will be called by the main test file's group.
    // We need to access the mocks initialized in the main test's setUp.
    // This is a bit of a workaround for Dart's test structure.
    // The actual instances are passed from the main test file's setUp via a shared context or re-initialization.
    // For now, we assume they are available via the testWidgets environment or similar.
    // A cleaner way would be to pass them as parameters to this main() function.

    setUp(() {
      // IMPORTANT: This assumes that the main test file's setUp has already run
      // and initialized these mocks. We are effectively "re-linking" them here
      // for the scope of these tests. This is not ideal but a common pattern
      // when splitting tests across files like this.
      // A better approach might be to pass the initialized mocks to this function.
      // However, to keep it simple and aligned with the existing structure of
      // _sync_error_test.dart etc., we'll rely on the main file's setUp.

      // These would be re-assigned from the main test file's setUp.
      // For the purpose of this example, we'll re-initialize them,
      // but in a real scenario, you'd ensure they are the SAME instances.
      mockLocalDataSource = MockJobLocalDataSource();
      mockRemoteDataSource = MockJobRemoteDataSource();
      mockJobSyncOrchestratorService = MockJobSyncOrchestratorService();

      // The service needs to be instantiated with the mock orchestrator
      jobSyncProcessorService = JobSyncProcessorService(
        localDataSource: mockLocalDataSource,
        remoteDataSource: mockRemoteDataSource,
        fileSystem: MockFileSystem(),
        isLogoutInProgress:
            () => mockJobSyncOrchestratorService.isLogoutInProgress,
      );
    });

    test(
      'processJobSync: when logout is in progress, _handleSyncError should NOT call localDataSource.saveJob on remote CREATE failure',
      () async {
        // Arrange
        final jobToCreate = createTestJob(serverId: null); // Create operation
        when(
          mockJobSyncOrchestratorService.isLogoutInProgress,
        ).thenReturn(true);
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(ServerException('Simulated API error'));

        // Act
        final result = await jobSyncProcessorService.processJobSync(
          jobToCreate,
        );

        // Assert
        expect(result.isLeft(), isTrue); // Should return a failure
        verifyNever(mockLocalDataSource.saveJob(any));
        verify(mockJobSyncOrchestratorService.isLogoutInProgress).called(1);
      },
    );

    test(
      'processJobSync: when logout is in progress, _handleSyncError should NOT call localDataSource.saveJob on remote UPDATE failure',
      () async {
        // Arrange
        final jobToUpdate = createTestJob(
          serverId: 'server1',
        ); // Update operation
        when(
          mockJobSyncOrchestratorService.isLogoutInProgress,
        ).thenReturn(true);
        when(
          mockRemoteDataSource.updateJob(
            jobId: jobToUpdate.serverId!,
            updates: anyNamed('updates'),
          ),
        ).thenThrow(ServerException('Simulated API error'));

        // Act
        final result = await jobSyncProcessorService.processJobSync(
          jobToUpdate,
        );

        // Assert
        expect(result.isLeft(), isTrue); // Should return a failure
        verifyNever(mockLocalDataSource.saveJob(any));
        verify(mockJobSyncOrchestratorService.isLogoutInProgress).called(1);
      },
    );

    test(
      'processJobDeletion: when logout is in progress, _handleSyncError should NOT call localDataSource.saveJob on remote DELETE failure',
      () async {
        // Arrange
        final jobToDelete = createTestJob(
          serverId: 'server1',
        ); // Has serverId, so remote delete will be attempted
        when(
          mockJobSyncOrchestratorService.isLogoutInProgress,
        ).thenReturn(true);
        when(
          mockRemoteDataSource.deleteJob(jobToDelete.serverId!),
        ).thenThrow(ServerException('Simulated API error'));

        // Act
        final result = await jobSyncProcessorService.processJobDeletion(
          jobToDelete,
        );

        // Assert
        expect(result.isLeft(), isTrue); // Should return a failure
        // saveJob might be called to mark pendingDeletion if smartDelete was involved,
        // but for _handleSyncError path, it shouldn't save the error state.
        // Let's be specific: ensure it's not called with SyncStatus.error or SyncStatus.failed
        // For now, simpler: verifyNever, assuming _handleSyncError is the only saver in this path.
        // If the processor itself saves a "pending delete" state before _handleSyncError, this test needs refinement.
        // Based on current processor logic, remote failure in deleteJob calls _handleSyncError.
        verifyNever(mockLocalDataSource.saveJob(any));
        verify(mockJobSyncOrchestratorService.isLogoutInProgress).called(1);
      },
    );

    test(
      'processJobSync: when logout is NOT in progress, _handleSyncError SHOULD call localDataSource.saveJob on remote CREATE failure',
      () async {
        // Arrange
        final jobToCreate = createTestJob(serverId: null, retryCount: 0);
        when(
          mockJobSyncOrchestratorService.isLogoutInProgress,
        ).thenReturn(false); // Logout NOT in progress
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(ServerException('Simulated API error'));
        // Mock saveJob to capture argument and simulate success
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

        // Act
        final result = await jobSyncProcessorService.processJobSync(
          jobToCreate,
        );

        // Assert
        expect(result.isLeft(), isTrue); // Should return a failure
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single
                as Job;
        expect(captured.syncStatus, SyncStatus.error);
        expect(captured.retryCount, 1);
        verify(mockJobSyncOrchestratorService.isLogoutInProgress).called(1);
      },
    );
  });
}
