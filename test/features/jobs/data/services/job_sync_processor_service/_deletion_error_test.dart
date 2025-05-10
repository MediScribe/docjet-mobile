// ignore_for_file: avoid_print, no_leading_underscores_for_local_identifiers

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../job_sync_processor_service_test.mocks.dart';
import '../job_sync_service_test_helpers.dart';

@GenerateNiceMocks([
  MockSpec<JobLocalDataSource>(),
  MockSpec<JobRemoteDataSource>(),
  MockSpec<FileSystem>(),
])
void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockFileSystem mockFileSystem;
  late JobSyncProcessorService service;
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;

  // Test data needed for deletion error cases
  final tJobPendingDeletionWithServerId = createTestJob(
    localId: 'deleteMe-local',
    serverId: 'deleteMe-server',
    syncStatus: SyncStatus.pendingDeletion,
    audioFilePath: '/local/delete_me.mp3',
    retryCount: 0,
  );

  setUp(() {
    printLog('[JobSyncProcessorTest][DeletionError] Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockFileSystem = MockFileSystem();
    mockJobSyncOrchestratorService = MockJobSyncOrchestratorService();

    service = JobSyncProcessorService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      fileSystem: mockFileSystem,
      isLogoutInProgress:
          () => mockJobSyncOrchestratorService.isLogoutInProgress,
    );

    // Add default stub for isLogoutInProgress
    when(mockJobSyncOrchestratorService.isLogoutInProgress).thenReturn(false);
    printLog('[JobSyncProcessorTest][DeletionError] Test setup complete');
  });

  group('processJobDeletion - Error Handling', () {
    final tServerException = ServerException('Deletion failed');
    final tCacheException = CacheException('DB delete failed');
    final tFileSystemException = FileSystemException('Cannot delete file');

    test(
      'should return Left<ServerFailure> and call _handleSyncError when remote deleteJob fails with retries remaining',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionError] Starting test: processJobDeletion - remote failure...',
        );
        // Arrange
        final initialJob = tJobPendingDeletionWithServerId.copyWith(
          retryCount: 1,
        );
        final expectedFailure = ServerFailure(
          message:
              'Failed to delete job ${initialJob.localId} on server (retries remain): $tServerException',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenThrow(tServerException);
        // Mock saveJob for _handleRemoteSyncFailure
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(initialJob);

        // Assert
        expect(result, Left(expectedFailure));
        verify(mockRemoteDataSource.deleteJob(initialJob.serverId!));
        // Verify saveJob was called to save error state
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        expect(captured.syncStatus, SyncStatus.error); // Check correct status
        expect(captured.retryCount, 2); // Check incremented count
        expect(
          captured.lastSyncAttemptAt,
          isNotNull,
        ); // Check timestamp updated

        verifyNever(
          mockLocalDataSource.getJobById(any),
        ); // Not called on remote failure
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));
        printLog(
          '[JobSyncProcessorTest][DeletionError] Test completed successfully',
        );
      },
    );

    test(
      'should return Left<ServerFailure> and set status to failed when remote deleteJob fails after max retries',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionError] Starting test: processJobDeletion - remote failure after max retries...',
        );
        // Arrange
        final initialJob = tJobPendingDeletionWithServerId.copyWith(
          retryCount: maxRetryAttempts - 1,
        );
        final expectedFailure = ServerFailure(
          message:
              'Failed to delete job ${initialJob.localId} on server after max retries: $tServerException',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenThrow(tServerException);
        // Mock saveJob for _handleRemoteSyncFailure
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(initialJob);

        // Assert
        expect(result, Left(expectedFailure));
        verify(mockRemoteDataSource.deleteJob(initialJob.serverId!));
        // Verify saveJob was called to save error state
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        expect(captured.syncStatus, SyncStatus.failed); // Check correct status
        expect(
          captured.retryCount,
          maxRetryAttempts,
        ); // Check incremented count
        expect(
          captured.lastSyncAttemptAt,
          isNotNull,
        ); // Check timestamp updated

        verifyNever(
          mockLocalDataSource.getJobById(any),
        ); // Not called on remote failure
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));
        printLog(
          '[JobSyncProcessorTest][DeletionError] Test completed successfully',
        );
      },
    );

    test(
      'should return Left<CacheFailure> when local getJobById fails during permanent deletion lookup',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionError] Starting test: processJobDeletion - getJobById failure...',
        );
        // Arrange
        final job = tJobPendingDeletionWithServerId;
        const originalCacheFailure = CacheFailure('DB read failed');
        final expectedFailure = CacheFailure(
          'Unexpected error fetching job ${job.localId} details for deletion: $originalCacheFailure',
        );

        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(job.localId),
        ).thenThrow(originalCacheFailure); // getJobById fails

        // Act
        final result = await service.processJobDeletion(job);

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, expectedFailure),
          (_) => fail('Expected Left, got Right'),
        );
        verify(mockRemoteDataSource.deleteJob(job.serverId!)).called(1);
        verify(mockLocalDataSource.getJobById(job.localId)).called(1);
        verifyNever(
          mockLocalDataSource.deleteJob(any),
        ); // DB delete not reached
        verifyNever(mockFileSystem.deleteFile(any)); // File system not reached
        printLog(
          '[JobSyncProcessorTest][DeletionError] Test completed successfully',
        );
      },
    );

    test(
      'should return Left<CacheFailure> when local deleteJob fails during permanent deletion',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionError] Starting test: processJobDeletion - local delete failure...',
        );
        // Arrange
        final job = tJobPendingDeletionWithServerId;
        final expectedFailure = CacheFailure(
          'Failed to delete job ${job.localId} from DB: $tCacheException',
        );

        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(job.localId),
        ).thenAnswer((_) async => job); // getJobById succeeds
        when(
          mockLocalDataSource.deleteJob(job.localId),
        ).thenThrow(tCacheException); // DB delete fails

        // Act
        final result = await service.processJobDeletion(job);

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, expectedFailure),
          (_) => fail('Expected Left, got Right'),
        );
        verify(mockRemoteDataSource.deleteJob(job.serverId!)).called(1);
        verify(mockLocalDataSource.getJobById(job.localId)).called(1);
        verify(mockLocalDataSource.deleteJob(job.localId)).called(1);
        verifyNever(mockFileSystem.deleteFile(any)); // File system not reached
        printLog(
          '[JobSyncProcessorTest][DeletionError] Test completed successfully',
        );
      },
    );

    test(
      'should return Right(unit) even when fileSystem delete fails (non-fatal)',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionError] Starting test: processJobDeletion - file delete failure...',
        );
        // Arrange
        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).thenAnswer((_) async => tJobPendingDeletionWithServerId);
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockFileSystem.deleteFile(any),
        ).thenThrow(tFileSystemException); // File delete fails

        // Act
        final result = await service.processJobDeletion(
          tJobPendingDeletionWithServerId,
        );

        // Assert
        expect(result, const Right(unit)); // Still succeeds
        verify(
          mockRemoteDataSource.deleteJob(
            tJobPendingDeletionWithServerId.serverId!,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.deleteJob(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).called(1);
        verify(
          mockFileSystem.deleteFile(
            tJobPendingDeletionWithServerId.audioFilePath!,
          ),
        ).called(1); // It was still called
        printLog(
          '[JobSyncProcessorTest][DeletionError] Test completed successfully - file deletion failure ignored',
        );
      },
    );
  }); // End of 'processJobDeletion - Error Handling' group
}

void printLog(String message) {
  print(message);
}
