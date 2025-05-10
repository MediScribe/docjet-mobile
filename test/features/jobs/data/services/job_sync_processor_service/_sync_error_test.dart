// ignore_for_file: avoid_print, no_leading_underscores_for_local_identifiers

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart'; // Import Processor
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../job_sync_processor_service_test.mocks.dart';
import '../job_sync_service_test_helpers.dart'; // Re-use helpers for now

// Generate mocks for JobLocalDataSource, JobRemoteDataSource, FileSystem
@GenerateNiceMocks([
  MockSpec<JobLocalDataSource>(),
  MockSpec<JobRemoteDataSource>(),
  MockSpec<FileSystem>(),
])
void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockFileSystem mockFileSystem;
  late JobSyncProcessorService service; // Use Processor service
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;

  // Test data setup (using helpers)
  final tPendingJobNew = createTestJob(
    localId: 'pendingNewJob1',
    serverId: null, // New job, no server ID yet
    syncStatus: SyncStatus.pending,
    retryCount: 0,
    audioFilePath: '/local/new_pending.mp3',
    text: 'Some initial text',
    additionalText: 'Some additional text',
    displayTitle: 'New Pending Job Sync Test',
  );

  final tSyncedJobFromServer = createTestJob(
    localId: 'pendingNewJob1', // Same local ID
    serverId: 'serverGeneratedId123', // Server assigns ID
    syncStatus: SyncStatus.synced, // Status after successful sync
    retryCount: 0,
    status: JobStatus.created, // Server might set initial status
    audioFilePath: '/local/new_pending.mp3',
    text: 'Some initial text',
    additionalText: 'Some additional text',
    displayTitle: 'New Pending Job Sync Test',
    updatedAt: DateTime.parse(
      '2025-04-20T10:41:39.784035Z',
    ), // Server timestamp
  );

  final tExistingJobPendingUpdate = createTestJob(
    localId: 'existingJob1-local',
    serverId: 'existingJob1-server', // Existing job
    syncStatus: SyncStatus.pending, // Marked for sync due to update
    retryCount: 1, // Example: has failed once before
    status: JobStatus.transcribing, // Correct status
    audioFilePath: '/local/existing.mp3',
    text: 'Updated text locally',
    additionalText: null,
    displayTitle: 'Updated Job Title Locally',
  );

  final tUpdatedJobFromServer = createTestJob(
    localId: 'existingJob1-local',
    serverId: 'existingJob1-server',
    syncStatus: SyncStatus.synced,
    retryCount: 0, // Reset on success
    status: JobStatus.transcribing, // Server returns its current state
    audioFilePath: '/local/existing.mp3',
    text: 'Updated text locally', // Server might echo back some fields
    additionalText: null,
    displayTitle: 'Updated Job Title Locally',
    updatedAt: DateTime.parse('2025-04-20T10:41:39.784035Z'), // New timestamp
  );

  // Job for deletion tests
  final tJobPendingDeletionWithServerId = createTestJob(
    localId: 'deleteMe-local',
    serverId: 'deleteMe-server',
    syncStatus: SyncStatus.pendingDeletion,
    audioFilePath: '/local/delete_me.mp3',
    retryCount: 0,
  );

  final tJobPendingDeletionWithoutServerId = createTestJob(
    localId: 'deleteMe-local-only',
    serverId: null, // Never synced
    syncStatus: SyncStatus.pendingDeletion,
    audioFilePath: '/local/delete_me_local.mp3',
    retryCount: 0,
  );

  setUp(() {
    printLog('[JobSyncProcessorTest] Setting up test...');
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

    printLog('[JobSyncProcessorTest] Test setup complete');
  });

  group('processJobSync - Error Handling & Retries', () {
    final tServerException = ServerException('Network Error');
    final tCacheException = CacheException('DB Write Error');

    test(
      'when remote createJob fails and retries remain, should return Left, update status to error, increment count, save locally',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: remote createJob fails with retries remaining',
        );
        // Arrange: Job has retryCount = 0 initially
        final initialJob = tPendingJobNew.copyWith(retryCount: 0);

        printLog('[JobSyncProcessorTest] Arranging mocks for failure scenario');
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(tServerException);

        // Mock successful save of error state - verify specific fields inside
        when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) async {
          final savedJob = invocation.positionalArguments[0] as Job;
          printLog(
            '[JobSyncProcessorTest] Mock saveJob called, returning unit',
          );
          // Verify the state inside the mock interaction
          expect(
            savedJob.syncStatus,
            SyncStatus.error,
            reason: 'Saved job status should be error',
          );
          expect(
            savedJob.retryCount,
            1,
            reason: 'Saved job retry count should be 1',
          );
          expect(
            savedJob.lastSyncAttemptAt,
            isNotNull, // Check if it was set
            reason: 'Saved job lastSyncAttemptAt should be set',
          );
          return unit;
        });
        printLog(
          '[JobSyncProcessorTest] Throwing configured, now starting action',
        );

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync and expecting exception handling',
        );
        final result = await service.processJobSync(initialJob);
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(
            (failure as ServerFailure).message,
            contains('Failed to sync job ${initialJob.localId}'),
          );
          expect((failure).message, contains('(retries remain)'));
        }, (job) => fail('Expected Left, got Right($job)'));

        // Verify create was called
        verify(
          mockRemoteDataSource.createJob(
            audioFilePath: initialJob.audioFilePath!,
            text: initialJob.text,
            additionalText: initialJob.additionalText,
          ),
        );
        // Verify saveJob was called AT LEAST once
        verify(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'when remote createJob fails and max retries reached, should return Left, update status to failed, increment count, save locally',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: remote createJob fails with max retries reached',
        );
        // Arrange: Job has retryCount = max - 1
        final initialJob = tPendingJobNew.copyWith(
          retryCount: maxRetryAttempts - 1,
        );

        printLog('[JobSyncProcessorTest] Arranging mocks for failure scenario');
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(tServerException);

        // Mock successful save of failed state
        when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) async {
          final savedJob = invocation.positionalArguments[0] as Job;
          printLog(
            '[JobSyncProcessorTest] Mock saveJob called, returning unit',
          );
          expect(savedJob.syncStatus, SyncStatus.failed);
          expect(savedJob.retryCount, maxRetryAttempts);
          expect(savedJob.lastSyncAttemptAt, isNotNull);
          return unit;
        });
        printLog(
          '[JobSyncProcessorTest] Throwing configured, now starting action',
        );

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync and expecting exception handling',
        );
        final result = await service.processJobSync(initialJob);
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(
            (failure as ServerFailure).message,
            contains('Failed to sync job ${initialJob.localId}'),
          );
          expect((failure).message, contains('after max retries'));
        }, (job) => fail('Expected Left, got Right($job)'));

        verify(
          mockRemoteDataSource.createJob(
            audioFilePath: initialJob.audioFilePath!,
            text: initialJob.text,
            additionalText: initialJob.additionalText,
          ),
        );
        // Verify saveJob was called AT LEAST once
        verify(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    // Similar tests for updateJob failures (retries remain / max retries)
    test(
      'when remote updateJob fails and retries remain, should return Left, update status to error, increment count, save locally',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: remote updateJob fails with retries remaining',
        );
        // Arrange: Job has retryCount = 1 initially
        final initialJob = tExistingJobPendingUpdate.copyWith(retryCount: 1);
        final expectedUpdates = <String, dynamic>{
          'status': initialJob.status.name,
          'display_title': initialJob.displayTitle,
          'text': initialJob.text,
        };

        printLog('[JobSyncProcessorTest] Arranging mocks for failure scenario');
        when(
          mockRemoteDataSource.updateJob(
            jobId: initialJob.serverId!,
            updates: expectedUpdates,
          ),
        ).thenThrow(tServerException);

        when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) async {
          final savedJob = invocation.positionalArguments[0] as Job;
          printLog(
            '[JobSyncProcessorTest] Mock saveJob called, returning unit',
          );
          expect(savedJob.syncStatus, SyncStatus.error);
          expect(savedJob.retryCount, 2);
          expect(savedJob.lastSyncAttemptAt, isNotNull);
          return unit;
        });
        printLog(
          '[JobSyncProcessorTest] Throwing configured, now starting action',
        );

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync and expecting exception handling',
        );
        final result = await service.processJobSync(initialJob);
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(
            (failure as ServerFailure).message,
            contains('Failed to sync job ${initialJob.localId}'),
          );
          expect((failure).message, contains('(retries remain)'));
        }, (job) => fail('Expected Left, got Right($job)'));

        verify(
          mockRemoteDataSource.updateJob(
            jobId: initialJob.serverId!,
            updates: expectedUpdates,
          ),
        );
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        printLog(
          '[JobSyncProcessorTest] Captured job in saveJob: syncStatus=${captured.syncStatus}, retryCount=${captured.retryCount}',
        );
        expect(captured.syncStatus, SyncStatus.error);
        expect(captured.retryCount, 2);
        expect(captured.lastSyncAttemptAt, isNotNull);
        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'when remote updateJob fails and max retries reached, should return Left, update status to failed, increment count, save locally',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: remote updateJob fails with max retries reached',
        );
        // Arrange: Job has retryCount = max - 1
        final initialJob = tExistingJobPendingUpdate.copyWith(
          retryCount: maxRetryAttempts - 1,
        );
        final expectedUpdates = <String, dynamic>{
          'status': initialJob.status.name,
          'display_title': initialJob.displayTitle,
          'text': initialJob.text,
        };

        printLog('[JobSyncProcessorTest] Arranging mocks for failure scenario');
        when(
          mockRemoteDataSource.updateJob(
            jobId: initialJob.serverId!,
            updates: expectedUpdates,
          ),
        ).thenThrow(tServerException);

        when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) async {
          final savedJob = invocation.positionalArguments[0] as Job;
          printLog(
            '[JobSyncProcessorTest] Mock saveJob called, returning unit',
          );
          expect(savedJob.syncStatus, SyncStatus.failed);
          expect(savedJob.retryCount, maxRetryAttempts);
          expect(savedJob.lastSyncAttemptAt, isNotNull);
          return unit;
        });
        printLog(
          '[JobSyncProcessorTest] Throwing configured, now starting action',
        );

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync and expecting exception handling',
        );
        final result = await service.processJobSync(initialJob);
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(
            (failure as ServerFailure).message,
            contains('Failed to sync job ${initialJob.localId}'),
          );
          expect((failure).message, contains('after max retries'));
        }, (job) => fail('Expected Left, got Right($job)'));

        verify(
          mockRemoteDataSource.updateJob(
            jobId: initialJob.serverId!,
            updates: expectedUpdates,
          ),
        );
        // Verify saveJob was called AT LEAST once
        verify(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Left(CacheFailure) if local saveJob fails after successful remote create',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: saveJob fails after successful remote create',
        );
        // Arrange
        printLog(
          '[JobSyncProcessorTest] Arranging mocks for create success, save failure scenario',
        );
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer((_) async {
          printLog(
            '[JobSyncProcessorTest] Mock createJob called, returning tSyncedJobFromServer',
          );
          return tSyncedJobFromServer;
        });
        when(mockLocalDataSource.saveJob(any)).thenThrow(tCacheException);
        printLog('[JobSyncProcessorTest] Mocks arranged, now starting action');

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync with expected failure on save',
        );
        final result = await service.processJobSync(tPendingJobNew);
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<CacheFailure>());
          expect((failure as CacheFailure).message, tCacheException.message);
        }, (job) => fail('Expected Left, got Right($job)'));

        // Verify remote create was called
        verify(
          mockRemoteDataSource.createJob(
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        );
        // Verify saveJob was called AT LEAST once
        verify(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Left(CacheFailure) if local saveJob fails after successful remote update',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: saveJob fails after successful remote update',
        );
        // Arrange
        printLog(
          '[JobSyncProcessorTest] Arranging mocks for update success, save failure scenario',
        );
        final expectedUpdates = <String, dynamic>{
          'status': tExistingJobPendingUpdate.status.name,
          'display_title': tExistingJobPendingUpdate.displayTitle,
          'text': tExistingJobPendingUpdate.text,
        };
        when(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async {
          printLog(
            '[JobSyncProcessorTest] Mock updateJob called, returning tUpdatedJobFromServer',
          );
          return tUpdatedJobFromServer;
        });
        when(mockLocalDataSource.saveJob(any)).thenThrow(tCacheException);
        printLog('[JobSyncProcessorTest] Mocks arranged, now starting action');

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync with expected failure on save',
        );
        final result = await service.processJobSync(tExistingJobPendingUpdate);
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<CacheFailure>());
          expect((failure as CacheFailure).message, tCacheException.message);
        }, (job) => fail('Expected Left, got Right($job)'));

        verify(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: expectedUpdates,
          ),
        );
        // Verify saveJob was called AT LEAST once
        verify(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Left(CacheFailure) if local saveJob fails when saving error status after remote create failure',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: saveJob fails when saving error state',
        );
        // Arrange
        printLog(
          '[JobSyncProcessorTest] Arranging mocks for double failure scenario (remote then local)',
        );
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(tServerException);
        when(
          mockLocalDataSource.saveJob(any),
        ).thenThrow(tCacheException); // SaveJob fails too
        printLog('[JobSyncProcessorTest] Mocks arranged, now starting action');

        // Act
        printLog(
          '[JobSyncProcessorTest] Calling service.processJobSync with expected failures',
        );
        final result = await service.processJobSync(
          tPendingJobNew.copyWith(retryCount: 0), // Start with 0 retries
        );
        printLog(
          '[JobSyncProcessorTest] processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest] Starting assertions');
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<CacheFailure>());
          expect((failure as CacheFailure).message, tCacheException.message);
        }, (r) => fail('Expected Left, got Right: $r'));
        verify(
          mockRemoteDataSource.createJob(
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        );
        // Verify saveJob was called AT LEAST once
        verify(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );
  }); // End of 'processJobSync - Error Handling & Retries' group

  group('processJobDeletion', () {
    test(
      'should call remote deleteJob, local deleteJob, and fileSystem delete when serverId exists and has audio',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - server delete success...',
        );
        // Arrange
        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).thenAnswer((_) async => tJobPendingDeletionWithServerId);
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(mockFileSystem.deleteFile(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(
          tJobPendingDeletionWithServerId,
        );

        // Assert
        expect(result, const Right(unit));
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
        ).called(1);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should only call local deleteJob and fileSystem delete when serverId is null',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - local-only delete success...',
        );
        // Arrange
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithoutServerId.localId,
          ),
        ).thenAnswer((_) async => tJobPendingDeletionWithoutServerId);
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(mockFileSystem.deleteFile(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(
          tJobPendingDeletionWithoutServerId,
        );

        // Assert
        expect(result, const Right(unit));
        verifyNever(mockRemoteDataSource.deleteJob(any));
        verify(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithoutServerId.localId,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.deleteJob(
            tJobPendingDeletionWithoutServerId.localId,
          ),
        ).called(1);
        verify(
          mockFileSystem.deleteFile(
            tJobPendingDeletionWithoutServerId.audioFilePath!,
          ),
        ).called(1);
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should call remote deleteJob and local deleteJob but NOT fileSystem delete when audioFilePath is null',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - no audio file...',
        );
        // Arrange
        final jobWithoutAudio = createTestJob(
          localId: 'deleteMe-local', // Use same IDs as original
          serverId: 'deleteMe-server',
          syncStatus: SyncStatus.pendingDeletion,
          audioFilePath: null, // Explicitly null
          retryCount: 0,
        );

        printLog(
          '[JobSyncProcessorTest] Configured jobWithoutAudio with audioFilePath: ${jobWithoutAudio.audioFilePath}',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(jobWithoutAudio.localId),
        ).thenAnswer((invocation) async {
          printLog(
            '[JobSyncProcessorTest] Mock getJobById for ${jobWithoutAudio.localId} returning job with audio: ${jobWithoutAudio.audioFilePath}',
          );
          return jobWithoutAudio;
        });
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(jobWithoutAudio);

        // Assert
        expect(result, const Right(unit));
        verify(
          mockRemoteDataSource.deleteJob(jobWithoutAudio.serverId!),
        ).called(1);
        verify(
          mockLocalDataSource.getJobById(jobWithoutAudio.localId),
        ).called(1);
        verify(
          mockLocalDataSource.deleteJob(jobWithoutAudio.localId),
        ).called(1);
        verifyNever(mockFileSystem.deleteFile(any));
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Left<Failure> and call _handleSyncError when remote deleteJob fails',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - remote failure...',
        );
        // Arrange
        final exception = ServerException('Deletion failed');
        final expectedFailure = ServerFailure(
          message:
              'Failed to delete job ${tJobPendingDeletionWithServerId.localId} on server (retries remain): $exception',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenThrow(exception);
        // Mock saveJob for _handleRemoteSyncFailure
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(
          tJobPendingDeletionWithServerId.copyWith(retryCount: 1),
        );

        // Assert
        expect(result, Left(expectedFailure));
        verify(
          mockRemoteDataSource.deleteJob(
            tJobPendingDeletionWithServerId.serverId!,
          ),
        );
        // Verify saveJob was called to save error state
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        expect(captured.syncStatus, SyncStatus.error); // Check correct status
        expect(captured.retryCount, 2); // Check incremented count

        verifyNever(
          mockLocalDataSource.getJobById(any),
        ); // Not called on remote failure
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Left<Failure> and set status to failed when remote deleteJob fails after max retries',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - remote failure after max retries...',
        );
        // Arrange
        final exception = ServerException('Deletion failed');
        final expectedFailure = ServerFailure(
          message:
              'Failed to delete job ${tJobPendingDeletionWithServerId.localId} on server after max retries: $exception',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenThrow(exception);
        // Mock saveJob for _handleRemoteSyncFailure
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

        // Act
        final result = await service.processJobDeletion(
          tJobPendingDeletionWithServerId.copyWith(
            retryCount: maxRetryAttempts - 1,
          ),
        );

        // Assert
        expect(result, Left(expectedFailure));
        verify(
          mockRemoteDataSource.deleteJob(
            tJobPendingDeletionWithServerId.serverId!,
          ),
        );
        // Verify saveJob was called to save error state
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        expect(captured.syncStatus, SyncStatus.failed); // Check correct status
        expect(
          captured.retryCount,
          maxRetryAttempts,
        ); // Check incremented count

        verifyNever(
          mockLocalDataSource.getJobById(any),
        ); // Not called on remote failure
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Left<CacheFailure> when local deleteJob fails during permanent deletion',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - local delete failure...',
        );
        // Arrange
        final job = tJobPendingDeletionWithServerId;
        const originalCacheFailure = CacheFailure('DB delete failed');
        // UPDATE EXPECTED FAILURE TO MATCH WRAPPED MESSAGE
        final expectedFailure = CacheFailure(
          'Unexpected error deleting job ${job.localId} from DB: $originalCacheFailure',
        );

        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(job.localId),
        ).thenAnswer((_) async => job);
        when(
          mockLocalDataSource.deleteJob(job.localId),
        ).thenThrow(originalCacheFailure); // DB delete fails

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
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );

    test(
      'should return Right(unit) even when fileSystem delete fails (non-fatal)',
      () async {
        printLog(
          '[JobSyncProcessorTest] Starting test: processJobDeletion - file delete failure...',
        );
        // Arrange
        final exception = FileSystemException('Cannot delete file');
        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).thenAnswer((_) async => tJobPendingDeletionWithServerId);
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockFileSystem.deleteFile(any),
        ).thenThrow(exception); // File delete fails

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
        printLog('[JobSyncProcessorTest] Test completed successfully');
      },
    );
  }); // End of 'processJobDeletion' group
}

void printLog(String message) {
  print(message);
}
