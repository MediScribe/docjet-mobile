import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging utilities
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_sync_service_test.mocks.dart'; // Assuming mocks are generated here
import 'job_sync_service_test_helpers.dart';

// Create a logger instance for test debugging
final _logger = LoggerFactory.getLogger('SyncPendingJobsTest');
final _tag = logTag('SyncPendingJobsTest');

// Regenerate mocks if needed
@GenerateMocks([
  JobLocalDataSource,
  JobRemoteDataSource,
  NetworkInfo,
  FileSystem,
])
void main() {
  _logger.i('$_tag Starting syncPendingJobs tests...');

  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockFileSystem mockFileSystem;
  late JobSyncService service;

  setUp(() {
    _logger.d('$_tag Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockFileSystem = MockFileSystem();

    service = JobSyncService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      networkInfo: mockNetworkInfo,
      fileSystem: mockFileSystem,
    );

    // Default mocks (adjust as needed per test)
    _logger.d('$_tag Setting up default mocks...');
    when(mockNetworkInfo.isConnected).thenAnswer((_) async {
      _logger.d('$_tag Mock isConnected called, returning true');
      return true;
    });
    when(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).thenAnswer((
      _,
    ) async {
      _logger.d('$_tag Mock getJobsByStatus(pending) called, returning []');
      return [];
    });
    when(
      mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
    ).thenAnswer((_) async {
      _logger.d(
        '$_tag Mock getJobsByStatus(pendingDeletion) called, returning []',
      );
      return [];
    });
    when(mockLocalDataSource.getJobsToRetry(any, any)).thenAnswer((_) async {
      _logger.d('$_tag Mock getJobsToRetry called, returning []');
      return [];
    });
    when(mockLocalDataSource.getJobById(any)).thenAnswer((_) async {
      _logger.d(
        '$_tag Mock getJobById called, returning tJobPendingDeletionWithServerId',
      );
      return tJobPendingDeletionWithServerId;
    }); // Default for deletion tests
    when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async {
      _logger.d('$_tag Mock saveJob called, returning unit');
      return unit;
    });
    when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async {
      _logger.d('$_tag Mock deleteJob called, returning unit');
      return unit;
    });
    when(mockFileSystem.deleteFile(any)).thenAnswer((_) async {
      _logger.d('$_tag Mock deleteFile called, returning unit');
      return;
    });
    when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async {
      _logger.d('$_tag Mock remote deleteJob called, returning unit');
      return unit;
    });

    // Mock the internal syncSingleJob call result by default (can override per test)
    // This is tricky without a proper spy setup. Let's mock the dependencies called BY syncSingleJob
    // when it's invoked by syncPendingJobs.
    when(
      mockRemoteDataSource.createJob(
        userId: anyNamed('userId'),
        audioFilePath: anyNamed('audioFilePath'),
        text: anyNamed('text'),
        additionalText: anyNamed('additionalText'),
      ),
    ).thenAnswer((_) async {
      _logger.d(
        '$_tag Mock createJob called by syncSingleJob, returning tSyncedJobFromServer',
      );
      return tSyncedJobFromServer;
    }); // Default success for create
    when(
      mockRemoteDataSource.updateJob(
        jobId: anyNamed('jobId'),
        updates: anyNamed('updates'),
      ),
    ).thenAnswer((_) async {
      _logger.d(
        '$_tag Mock updateJob called by syncSingleJob, returning tUpdatedJobFromServer',
      );
      return tUpdatedJobFromServer;
    }); // Default success for update

    _logger.d('$_tag Test setup complete');
  });

  group('syncPendingJobs', () {
    test(
      'should call syncSingleJob for NEW pending jobs and save the result',
      () async {
        _logger.i(
          '$_tag Starting test: should call syncSingleJob for NEW pending jobs...',
        );

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock getJobsByStatus(pending) called, returning [tPendingJobNew]',
          );
          return [tPendingJobNew];
        });

        // We already mocked the successful outcome of createJob and saveJob called by syncSingleJob in setUp
        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncPendingJobs...');
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(const Right(unit)));
        verify(mockNetworkInfo.isConnected).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);

        // Verify the underlying calls made BY the syncSingleJob for the NEW job
        verify(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).called(1);
        // This save happens inside syncSingleJob
        verify(mockLocalDataSource.saveJob(tSyncedJobFromServer)).called(1);

        // Verify no deletion logic was triggered for this job
        verifyNever(mockRemoteDataSource.deleteJob(any));
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));

        verifyNoMoreInteractions(mockNetworkInfo);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'should call syncSingleJob for PENDING UPDATE jobs and save the result',
      () async {
        _logger.i(
          '$_tag Starting test: should call syncSingleJob for PENDING UPDATE jobs...',
        );

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock getJobsByStatus(pending) called, returning [tExistingJobPendingUpdate]',
          );
          return [tExistingJobPendingUpdate];
        });

        // We already mocked the successful outcome of updateJob and saveJob called by syncSingleJob in setUp
        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncPendingJobs...');
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(const Right(unit)));
        verify(mockNetworkInfo.isConnected).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);

        // Verify the underlying calls made BY the syncSingleJob for the UPDATE job
        verify(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed('updates'), // Job details are mapped internally
          ),
        ).called(1);
        // This save happens inside syncSingleJob
        verify(mockLocalDataSource.saveJob(tUpdatedJobFromServer)).called(1);

        // Verify no creation/deletion logic was triggered for this job
        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        );
        verifyNever(mockRemoteDataSource.deleteJob(any));
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));

        verifyNoMoreInteractions(mockNetworkInfo);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'should call remote delete and permanently delete locally for PENDING DELETION job',
      () async {
        _logger.i(
          '$_tag Starting test: should call remote delete and permanently delete locally...',
        );

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock getJobsByStatus(pendingDeletion) called, returning [tJobPendingDeletionWithServerId]',
          );
          return [tJobPendingDeletionWithServerId];
        });
        when(
          mockRemoteDataSource.deleteJob(
            tJobPendingDeletionWithServerId.serverId!,
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock remote deleteJob called with server ID: ${tJobPendingDeletionWithServerId.serverId}',
          );
          return unit;
        }); // Mock successful remote delete
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock getJobById called with localId: ${tJobPendingDeletionWithServerId.localId}',
          );
          return tJobPendingDeletionWithServerId;
        }); // Needed for file path
        when(
          mockLocalDataSource.deleteJob(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock local deleteJob called with localId: ${tJobPendingDeletionWithServerId.localId}',
          );
          return unit;
        }); // Mock successful local delete
        when(
          mockFileSystem.deleteFile(
            tJobPendingDeletionWithServerId.audioFilePath!,
          ),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock deleteFile called with path: ${tJobPendingDeletionWithServerId.audioFilePath}',
          );
          return;
        }); // Mock successful file delete

        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncPendingJobs...');
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(const Right(unit)));
        verify(mockNetworkInfo.isConnected).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);

        // Verify deletion orchestration
        verify(
          mockRemoteDataSource.deleteJob(
            tJobPendingDeletionWithServerId.serverId!,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).called(1); // Verify lookup before permanent delete
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

        // Verify no syncSingleJob related calls (create/update/save)
        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        );
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );
        verifyNever(mockLocalDataSource.saveJob(any));

        verifyNoMoreInteractions(mockNetworkInfo);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
        _logger.i('$_tag Test completed successfully');
      },
    );

    test('should fetch and call syncSingleJob for retry-eligible jobs', () async {
      _logger.i(
        '$_tag Starting test: should fetch and call syncSingleJob for retry-eligible jobs...',
      );

      // Arrange
      _logger.d('$_tag Arranging mocks...');
      when(mockLocalDataSource.getJobsToRetry(any, any)).thenAnswer((_) async {
        _logger.d(
          '$_tag Mock getJobsToRetry called, returning [tJobInErrorRetryEligible]',
        );
        return [tJobInErrorRetryEligible];
      });

      // Mock the successful syncSingleJob outcome for the retry job (update)
      final tSyncedRetryJob = tJobInErrorRetryEligible.copyWith(
        syncStatus: SyncStatus.synced,
      );
      when(
        mockRemoteDataSource.updateJob(
          jobId: tJobInErrorRetryEligible.serverId!,
          updates: anyNamed('updates'),
        ),
      ).thenAnswer((_) async {
        _logger.d(
          '$_tag Mock updateJob called for retry job, returning tSyncedRetryJob',
        );
        return tSyncedRetryJob;
      });
      when(mockLocalDataSource.saveJob(tSyncedRetryJob)).thenAnswer((_) async {
        _logger.d('$_tag Mock saveJob called for retry job, returning unit');
        return unit;
      });

      _logger.d('$_tag Test arranged, starting action...');

      // Act
      _logger.d('$_tag Calling service.syncPendingJobs...');
      final result = await service.syncPendingJobs();
      _logger.d('$_tag service.syncPendingJobs completed with result: $result');

      // Assert
      _logger.d('$_tag Starting assertions');
      expect(result, equals(const Right(unit)));
      verify(mockNetworkInfo.isConnected).called(1);
      verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).called(1);
      verify(
        mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
      ).called(1);
      verify(
        mockLocalDataSource.getJobsToRetry(maxRetryAttempts, retryBackoffBase),
      ).called(1);

      // Verify syncSingleJob calls for the retry job
      verify(
        mockRemoteDataSource.updateJob(
          jobId: tJobInErrorRetryEligible.serverId!,
          updates: anyNamed('updates'),
        ),
      ).called(1);
      verify(mockLocalDataSource.saveJob(tSyncedRetryJob)).called(1);

      verifyNoMoreInteractions(mockNetworkInfo);
      verifyNoMoreInteractions(mockRemoteDataSource);
      verifyNoMoreInteractions(mockLocalDataSource);
      verifyNoMoreInteractions(mockFileSystem);
      _logger.i('$_tag Test completed successfully');
    });

    test('should prevent concurrent execution if sync is already running', () async {
      _logger.i('$_tag Starting test: should prevent concurrent execution...');

      // Arrange
      _logger.d('$_tag Arranging mocks for concurrency test...');
      // Remove the unused completer
      // final completer = Completer<Either<Failure, Unit>>();

      // Make the first call return a future that we control
      when(mockNetworkInfo.isConnected).thenAnswer((_) async {
        _logger.d('$_tag Mock isConnected called, returning true');
        return true;
      });
      when(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).thenAnswer((
        _,
      ) async {
        _logger.d(
          '$_tag Mock getJobsByStatus(pending) called, returning [tPendingJobNew]',
        );
        return [tPendingJobNew];
      });

      // Mock the *first* call to syncPendingJobs to return the completer
      // This requires a more complex setup, potentially using a flag or call count.
      // Simpler approach: Let the first call proceed but simulate its internal delay.
      _logger.d(
        '$_tag Setting up delayed completion for remote create operation',
      );
      final internalCompleter = Completer<Job>();
      when(
        mockRemoteDataSource.createJob(
          userId: tPendingJobNew.userId,
          audioFilePath: tPendingJobNew.audioFilePath!,
          text: tPendingJobNew.text,
          additionalText: tPendingJobNew.additionalText,
        ),
      ).thenAnswer((_) {
        _logger.d('$_tag Mock createJob called but delaying completion...');
        return internalCompleter.future;
      }); // Delay the create call

      _logger.d('$_tag Test arranged, starting action...');

      // Act
      // Start the first sync but don't await it yet
      _logger.d('$_tag Starting first sync call (not awaited)...');
      final firstCallFuture = service.syncPendingJobs();

      // Give the first call a moment to set the _isSyncing flag
      _logger.d('$_tag Delaying to let first call acquire lock...');
      await Future.delayed(Duration.zero);

      // Immediately start the second sync
      _logger.d('$_tag Starting second sync call...');
      final secondCallResult = await service.syncPendingJobs();
      _logger.d('$_tag Second call completed with result: $secondCallResult');

      // Now complete the first sync's internal operation
      _logger.d('$_tag Completing delayed remote operation...');
      internalCompleter.complete(tSyncedJobFromServer);

      // Await the first sync's completion
      _logger.d('$_tag Awaiting first call completion...');
      final firstCallResult = await firstCallFuture;
      _logger.d('$_tag First call completed with result: $firstCallResult');

      // Assert
      _logger.d('$_tag Starting assertions');
      // 1. The second call should return immediately with Right(unit)
      expect(
        secondCallResult,
        equals(const Right(unit)),
        reason: "Second call should exit early due to concurrency lock",
      );

      // 2. The first call should complete successfully after the completer finishes
      expect(
        firstCallResult,
        equals(const Right(unit)),
        reason: "First call should complete successfully",
      );

      // 3. Verify critical operations happened only ONCE (for the first call)
      verify(mockNetworkInfo.isConnected).called(1);
      verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).called(1);
      verify(
        mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
      ).called(1);
      verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
      verify(
        mockRemoteDataSource.createJob(
          userId: tPendingJobNew.userId,
          audioFilePath: tPendingJobNew.audioFilePath!,
          text: tPendingJobNew.text,
          additionalText: tPendingJobNew.additionalText,
        ),
      ).called(1);
      verify(mockLocalDataSource.saveJob(tSyncedJobFromServer)).called(1);

      // Verify no more interactions beyond the single successful sync run
      verifyNoMoreInteractions(mockNetworkInfo);
      verifyNoMoreInteractions(mockRemoteDataSource);
      verifyNoMoreInteractions(mockLocalDataSource);
      verifyNoMoreInteractions(mockFileSystem);
      _logger.i('$_tag Test completed successfully');
    });

    // --- Tests for failures during deletion within syncPendingJobs ---

    test(
      'when remote deleteJob fails and retries remain, should save job with error status and NOT delete locally',
      () async {
        _logger.i(
          '$_tag Starting test: remote deleteJob fails with retries remaining...',
        );

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        final initialJob = tJobPendingDeletionWithServerId.copyWith(
          retryCount: 1,
        );
        final serverException = ServerException('Delete failed');
        // Remove the unused expectedErrorJob variable
        // final expectedErrorJob = initialJob.copyWith(
        //   syncStatus: SyncStatus.error, // Back to error
        //   retryCount: initialJob.retryCount + 1,
        //   lastSyncAttemptAt: DateTime.now(), // Set by the error handler
        // );

        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock getJobsByStatus(pendingDeletion) called, returning [initialJob]',
          );
          return [initialJob];
        });
        when(
          mockRemoteDataSource.deleteJob(initialJob.serverId!),
        ).thenThrow(serverException);
        _logger.d(
          '$_tag Configured mock remote.deleteJob to throw: $serverException',
        );

        // Mock the saveJob call that happens in the catch block
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock saveJob called for error state, returning unit',
          );
          return unit;
        });

        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncPendingJobs...');
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed, checking result...',
        );

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(const Right(unit)));
        verify(mockRemoteDataSource.deleteJob(initialJob.serverId!)).called(1);

        // Verify the job was saved with error status
        final verification = verify(mockLocalDataSource.saveJob(captureAny));
        verification.called(1);
        final savedJob = verification.captured.single as Job;
        _logger.d(
          '$_tag Captured job in saveJob: syncStatus=${savedJob.syncStatus}, retryCount=${savedJob.retryCount}',
        );
        expect(savedJob.syncStatus, SyncStatus.error);
        expect(savedJob.retryCount, initialJob.retryCount + 1);
        expect(savedJob.lastSyncAttemptAt, isNotNull);
        expect(savedJob.localId, initialJob.localId);

        // CRITICAL: Verify permanent deletion did NOT happen
        verifyNever(mockLocalDataSource.deleteJob(initialJob.localId));
        verifyNever(mockFileSystem.deleteFile(initialJob.audioFilePath!));
        _logger.i('$_tag Test completed successfully');
      },
    );

    test(
      'when remote deleteJob fails and max retries reached, should save job with failed status and NOT delete locally',
      () async {
        _logger.i(
          '$_tag Starting test: remote deleteJob fails with max retries reached...',
        );

        // Arrange
        _logger.d('$_tag Arranging mocks...');
        final initialJob = tJobPendingDeletionWithServerId.copyWith(
          retryCount: maxRetryAttempts - 1,
        );
        final serverException = ServerException('Delete failed finally');
        // Remove the unused expectedFailedJob variable
        // final expectedFailedJob = initialJob.copyWith(
        //   syncStatus: SyncStatus.failed, // Should be failed
        //   retryCount: initialJob.retryCount + 1,
        //   lastSyncAttemptAt: DateTime.now(),
        // );

        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock getJobsByStatus(pendingDeletion) called, returning [initialJob]',
          );
          return [initialJob];
        });
        when(
          mockRemoteDataSource.deleteJob(initialJob.serverId!),
        ).thenThrow(serverException);
        _logger.d(
          '$_tag Configured mock remote.deleteJob to throw: $serverException',
        );

        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async {
          _logger.d(
            '$_tag Mock saveJob called for failed state, returning unit',
          );
          return unit;
        });

        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncPendingJobs...');
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed, checking result...',
        );

        // Assert
        _logger.d('$_tag Starting assertions');
        expect(result, equals(const Right(unit)));
        verify(mockRemoteDataSource.deleteJob(initialJob.serverId!)).called(1);

        // Verify the job was saved with failed status
        final verification = verify(mockLocalDataSource.saveJob(captureAny));
        verification.called(1);
        final savedJob = verification.captured.single as Job;
        _logger.d(
          '$_tag Captured job in saveJob: syncStatus=${savedJob.syncStatus}, retryCount=${savedJob.retryCount}',
        );
        expect(savedJob.syncStatus, SyncStatus.failed);
        expect(savedJob.retryCount, maxRetryAttempts);
        expect(savedJob.lastSyncAttemptAt, isNotNull);
        expect(savedJob.localId, initialJob.localId);

        // CRITICAL: Verify permanent deletion did NOT happen
        verifyNever(mockLocalDataSource.deleteJob(initialJob.localId));
        verifyNever(mockFileSystem.deleteFile(initialJob.audioFilePath!));
        _logger.i('$_tag Test completed successfully');
      },
    );

    // Add more tests for syncPendingJobs orchestration logic as needed
    // e.g., network offline, combinations of job types, etc.
  });
}
