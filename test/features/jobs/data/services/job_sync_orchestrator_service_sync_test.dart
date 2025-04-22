import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
// import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart'; // No longer needed here
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'; // Updated service name
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart'; // Added processor service
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';

// Generate mocks for dependencies of the Orchestrator
@GenerateMocks([
  JobLocalDataSource,
  NetworkInfo,
  JobSyncProcessorService, // Added processor mock
])
import 'job_sync_orchestrator_service_sync_test.mocks.dart'; // Updated mock file name

// Create a logger instance for test debugging
final _logger = LoggerFactory.getLogger(
  'JobSyncOrchestratorServiceSyncTest',
); // Updated logger name
final _tag = logTag('JobSyncOrchestratorServiceSyncTest'); // Updated tag

void main() {
  _logger.i(
    '$_tag Starting JobSyncOrchestratorService Sync tests...',
  ); // Updated main log

  // --- Test Data Definitions ---
  final tNow = DateTime.now(); // Use a consistent 'now' for comparisons

  // Test data remains largely the same, focused on different job states
  final tPendingJobNew = Job(
    localId: 'pendingNewJob1',
    userId: 'user123',
    status: JobStatus.created,
    syncStatus: SyncStatus.pending,
    displayTitle: 'New Pending Job Sync Test',
    audioFilePath: '/local/new_pending.mp3',
    text: 'Some initial text',
    additionalText: 'Some additional text',
    createdAt: tNow.subtract(const Duration(minutes: 10)),
    updatedAt: tNow.subtract(const Duration(minutes: 5)),
    serverId: null,
    retryCount: 0,
    lastSyncAttemptAt: null,
  );

  final tExistingJobPendingUpdate = Job(
    localId: 'existingJob1-local',
    serverId: 'existingJob1-server',
    userId: 'user456',
    status: JobStatus.transcribing,
    syncStatus: SyncStatus.pending,
    displayTitle: 'Updated Job Title Locally',
    audioFilePath: '/local/existing.mp3',
    text: 'Updated text locally',
    additionalText: null,
    createdAt: tNow.subtract(const Duration(days: 1)),
    updatedAt: tNow.subtract(const Duration(hours: 1)),
    retryCount: 0,
    lastSyncAttemptAt: null,
  );

  final tJobPendingDeletionWithServerId = Job(
    localId: 'deleteMe-local',
    serverId: 'deleteMe-server',
    userId: 'user789',
    status: JobStatus.completed,
    syncStatus: SyncStatus.pendingDeletion,
    displayTitle: 'Job To Be Deleted',
    audioFilePath: '/local/delete_me.mp3',
    text: 'Final text',
    additionalText: null,
    createdAt: tNow.subtract(const Duration(days: 2)),
    updatedAt: tNow.subtract(const Duration(days: 1)),
    retryCount: 0,
    lastSyncAttemptAt: null,
  );

  final tJobInErrorRetryEligible = Job(
    localId: 'errorRetryJob1-local',
    serverId: 'errorRetryJob1-server',
    userId: 'userError1',
    status: JobStatus.transcribing,
    syncStatus: SyncStatus.error,
    displayTitle: 'Job Failed, Ready to Retry',
    audioFilePath: '/local/error_retry.mp3',
    text: 'Some text',
    additionalText: null,
    createdAt: tNow.subtract(const Duration(hours: 2)),
    updatedAt: tNow.subtract(const Duration(hours: 1)),
    retryCount: 2,
    lastSyncAttemptAt: tNow.subtract(
      const Duration(minutes: 30),
    ), // Eligible for retry
  );

  // --- End Test Data Definitions ---

  late MockJobLocalDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockJobSyncProcessorService mockProcessorService; // Renamed/Added mock
  late JobSyncOrchestratorService service; // Updated service type

  setUp(() {
    _logger.d('$_tag Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockProcessorService =
        MockJobSyncProcessorService(); // Instantiate new mock

    service = JobSyncOrchestratorService(
      // Updated instantiation
      localDataSource: mockLocalDataSource,
      networkInfo: mockNetworkInfo,
      processorService: mockProcessorService, // Inject processor mock
    );

    // Default mocks
    _logger.d('$_tag Setting up default mocks...');
    // Network is connected by default for sync tests
    when(mockNetworkInfo.isConnected).thenAnswer((_) async {
      _logger.d('$_tag Mock isConnected called, returning true');
      return true;
    });
    // Default: No jobs returned by local data source
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

    // Default: Processor service calls succeed (return Right(unit) or Right(Job))
    when(mockProcessorService.processJobSync(any)).thenAnswer((
      invocation,
    ) async {
      final jobPassed = invocation.positionalArguments[0] as Job;
      _logger.d(
        '$_tag Mock processJobSync(${jobPassed.localId}) called, returning Right(unit)',
      );
      return const Right(unit);
    });
    when(mockProcessorService.processJobDeletion(any)).thenAnswer((_) async {
      _logger.d('$_tag Mock processJobDeletion called, returning Right(unit)');
      // Corrected: Return Right(unit)
      return const Right(unit);
    });

    _logger.d('$_tag Test setup complete');
  });

  group('syncPendingJobs - Orchestration', () {
    // Updated group description
    test(
      'should fetch and call processorService.processJobSync for NEW pending jobs',
      () async {
        _logger.i(
          '$_tag Starting test: should call processor for NEW pending jobs...',
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

        _logger.d('$_tag Test arranged, starting action...');

        // Act
        _logger.d('$_tag Calling service.syncPendingJobs...');
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        _logger.d('$_tag Asserting expectations...');
        // Verify local DS was queried
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        // Verify processor was called with the correct job
        verify(mockProcessorService.processJobSync(tPendingJobNew)).called(1);
        // Verify other categories were checked
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
        // Verify deletion processor was NOT called
        verifyNever(mockProcessorService.processJobDeletion(any));
        _logger.d('$_tag Assertions complete.');
      },
    );

    test(
      'should fetch and call processorService.processJobSync for UPDATED pending jobs',
      () async {
        _logger.i(
          '$_tag Starting test: should call processor for UPDATED pending jobs...',
        );
        // Arrange
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async => [tExistingJobPendingUpdate]);
        _logger.d(
          '$_tag Mock getJobsByStatus(pending) called, returning [tExistingJobPendingUpdate]',
        );

        // Act
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockProcessorService.processJobSync(tExistingJobPendingUpdate),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
        verifyNever(mockProcessorService.processJobDeletion(any));
      },
    );

    test(
      'should fetch and call processorService.processJobDeletion for jobs pending deletion',
      () async {
        _logger.i(
          '$_tag Starting test: should call processor for jobs pending deletion...',
        );
        // Arrange
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async => [tJobPendingDeletionWithServerId]);
        _logger.d(
          '$_tag Mock getJobsByStatus(pendingDeletion) called, returning [tJobPendingDeletionWithServerId]',
        );

        // Act
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(
          mockProcessorService.processJobDeletion(
            tJobPendingDeletionWithServerId,
          ),
        ).called(1); // Verify deletion call
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
        // Verify sync processor was NOT called
        verifyNever(mockProcessorService.processJobSync(any));
      },
    );

    test(
      'should fetch and call processorService.processJobSync for ERROR jobs eligible for retry',
      () async {
        _logger.i(
          '$_tag Starting test: should call processor for ERROR jobs eligible for retry...',
        );
        // Arrange
        // Corrected: Use any matcher for nullable arguments
        when(
          mockLocalDataSource.getJobsToRetry(
            any, // Use any matcher for maxRetries (nullable int?)
            any, // Use any matcher for backoffDuration (nullable Duration?)
          ),
        ).thenAnswer((_) async => [tJobInErrorRetryEligible]);
        _logger.d(
          '$_tag Mock getJobsToRetry called, returning [tJobInErrorRetryEligible]',
        );

        // Act
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        // Corrected: Use any matcher for nullable arguments
        verify(
          mockLocalDataSource.getJobsToRetry(
            any, // Use any matcher for maxRetries (nullable int?)
            any, // Use any matcher for backoffDuration (nullable Duration?)
          ),
        ).called(1);
        verify(
          mockProcessorService.processJobSync(tJobInErrorRetryEligible),
        ).called(1); // Verify sync call for retry
        verifyNever(mockProcessorService.processJobDeletion(any));
      },
    );

    test(
      'should call processor service for multiple jobs of different types',
      () async {
        _logger.i('$_tag Starting test: should process multiple job types...');
        // Arrange
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async => [tPendingJobNew, tExistingJobPendingUpdate]);
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async => [tJobPendingDeletionWithServerId]);
        when(
          mockLocalDataSource.getJobsToRetry(any, any),
        ).thenAnswer((_) async => [tJobInErrorRetryEligible]);

        // Act
        await service.syncPendingJobs();

        // Assert
        verify(mockProcessorService.processJobSync(tPendingJobNew)).called(1);
        verify(
          mockProcessorService.processJobSync(tExistingJobPendingUpdate),
        ).called(1);
        verify(
          mockProcessorService.processJobSync(tJobInErrorRetryEligible),
        ).called(1);
        verify(
          mockProcessorService.processJobDeletion(
            tJobPendingDeletionWithServerId,
          ),
        ).called(1);
        // Ensure fetches happened
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
      },
    );

    test(
      'should return Right(unit) when sync completes successfully with no jobs',
      () async {
        _logger.i(
          '$_tag Starting test: should return Right(unit) with no jobs...',
        );
        // Arrange: Default setup has no pending jobs
        _logger.d('$_tag Arranging mocks (default setup)...');

        // Act
        final result = await service.syncPendingJobs();
        _logger.d(
          '$_tag service.syncPendingJobs completed with result: $result',
        );

        // Assert
        expect(result, const Right(unit));
        // Verify datasources were queried
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);
        verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
        // Verify processor was never called
        verifyNever(mockProcessorService.processJobSync(any));
        verifyNever(mockProcessorService.processJobDeletion(any));
        _logger.d('$_tag Assertions complete.');
      },
    );

    test('should handle concurrent sync calls using the lock', () async {
      _logger.i('$_tag Starting test: concurrent sync calls...');

      // Arrange
      _logger.d('$_tag Arranging mocks for concurrency test...');
      // Use a completer to control when the first sync process finishes
      final syncCompleter = Completer<void>();
      // Counter to track actual processor calls
      var processorCallCount = 0;

      when(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).thenAnswer((
        _,
      ) async {
        _logger.d(
          '$_tag Mock getJobsByStatus(pending) called, returning [tPendingJobNew] (for concurrency test)',
        );
        // Simulate DB access time only for the first call that gets through the lock
        // We only expect this to be called ONCE if the lock works.
        await Future.delayed(const Duration(milliseconds: 50));
        return [tPendingJobNew];
      });

      when(mockProcessorService.processJobSync(any)).thenAnswer((_) async {
        processorCallCount++;
        _logger.d(
          '$_tag Mock processJobSync called (Count: $processorCallCount). Waiting for completer...',
        );
        // Simulate processing time, wait for external signal to complete
        await syncCompleter.future;
        _logger.d('$_tag Mock processJobSync completer finished.');
        return const Right(unit);
      });

      _logger.d('$_tag Test arranged, starting concurrent actions...');

      // Act
      // Call syncPendingJobs twice without awaiting the first one immediately
      _logger.d('$_tag Calling service.syncPendingJobs (call 1)...');
      final future1 = service.syncPendingJobs();
      // Small delay to ensure the second call happens while the first might be inside the lock
      await Future.delayed(const Duration(milliseconds: 10));
      _logger.d('$_tag Calling service.syncPendingJobs (call 2)...');
      final future2 = service.syncPendingJobs();

      // Now, allow the first sync process (if it started) to complete
      _logger.d('$_tag Completing the sync process completer...');
      syncCompleter.complete();

      // Wait for both calls to finish
      _logger.d('$_tag Awaiting both future results...');
      final results = await Future.wait([future1, future2]);
      _logger.d(
        '$_tag Both syncPendingJobs calls completed with results: $results',
      );

      // Assert
      _logger.d('$_tag Asserting expectations for concurrency...');
      // Verify local DS was queried only ONCE because of the lock
      verify(mockLocalDataSource.getJobsByStatus(SyncStatus.pending)).called(1);
      // Verify processor was called only ONCE
      verify(mockProcessorService.processJobSync(tPendingJobNew)).called(1);
      // Explicitly check the counter
      expect(
        processorCallCount,
        1,
        reason: 'Processor should only be called once due to lock',
      );

      // Verify other categories were still checked (only once, by the winning call)
      verify(
        mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
      ).called(1);
      verify(mockLocalDataSource.getJobsToRetry(any, any)).called(1);
      // Verify deletion processor was NOT called
      verifyNever(mockProcessorService.processJobDeletion(any));
      _logger.d('$_tag Concurrency assertions complete.');
    });
  });
}
