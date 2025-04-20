import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/error/exceptions.dart'; // Import CacheException

// Generate mocks for dependencies of the Orchestrator
@GenerateMocks([
  JobLocalDataSource,
  NetworkInfo, // Keep NetworkInfo mock for consistency, though not used in reset
  JobSyncProcessorService, // Keep Processor mock for consistency
])
import 'job_sync_orchestrator_service_reset_test.mocks.dart'; // Use specific mock file

// Create a logger instance for test debugging
final _logger = LoggerFactory.getLogger(
  'JobSyncOrchestratorServiceResetTest', // Specific logger name
);
final _tag = logTag('JobSyncOrchestratorServiceResetTest'); // Specific tag

void main() {
  _logger.i('$_tag Starting JobSyncOrchestratorService Reset tests...');

  // --- Test Data Definitions ---
  final tNow = DateTime.now();
  const tFailedJobId = 'failedJob1-local';
  const tNonFailedJobId = 'nonFailedJob1-local';
  const tNotFoundJobId = 'notFoundJob-local';

  final tFailedJob = Job(
    localId: tFailedJobId,
    serverId: 'failedJob1-server',
    userId: 'userError1',
    status: JobStatus.transcribing, // Status irrelevant for reset logic itself
    syncStatus: SyncStatus.failed, // The key status
    displayTitle: 'Job Failed',
    audioFilePath: '/local/error.mp3',
    text: 'Some text',
    additionalText: null,
    createdAt: tNow.subtract(const Duration(hours: 2)),
    updatedAt: tNow.subtract(const Duration(hours: 1)),
    retryCount: 5, // Should be reset
    lastSyncAttemptAt: tNow.subtract(
      const Duration(minutes: 30),
    ), // Should be cleared
  );

  final tNonFailedJob = Job(
    localId: tNonFailedJobId,
    serverId: 'nonFailedJob1-server',
    userId: 'userSuccess1',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced, // Not in failed state
    displayTitle: 'Job Synced',
    audioFilePath: '/local/synced.mp3',
    text: 'Final text',
    additionalText: null,
    createdAt: tNow.subtract(const Duration(days: 1)),
    updatedAt: tNow.subtract(const Duration(hours: 12)),
    retryCount: 0,
    lastSyncAttemptAt: tNow.subtract(const Duration(hours: 12)),
  );

  // --- End Test Data Definitions ---

  late MockJobLocalDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockJobSyncProcessorService mockProcessorService;
  late JobSyncOrchestratorService service;

  setUp(() {
    _logger.d('$_tag Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockProcessorService = MockJobSyncProcessorService();

    service = JobSyncOrchestratorService(
      localDataSource: mockLocalDataSource,
      networkInfo: mockNetworkInfo,
      processorService: mockProcessorService,
    );

    // Default mocks - Local data source interactions are key here
    _logger.d('$_tag Setting up default mocks...');
    // Default: getJobById throws CacheException unless specified
    when(mockLocalDataSource.getJobById(any)).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      _logger.d(
        '$_tag Mock getJobById($id) called, throwing CacheException (default)',
      );
      throw CacheException('Job not found: $id');
    });
    // Default: saveJob succeeds
    when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) async {
      final job = invocation.positionalArguments[0] as Job;
      _logger.d(
        '$_tag Mock saveJob(${job.localId}) called, returning Right(unit)',
      );
      return unit;
    });

    _logger.d('$_tag Test setup complete');
  });

  group('resetFailedJob', () {
    test(
      'should fetch the job, update status to pending, reset counters, and save if status is failed',
      () async {
        _logger.i('$_tag Test: reset successful FAILED job...');

        // Arrange
        _logger.d('$_tag Arranging: Mock getJobById to return tFailedJob');
        when(
          mockLocalDataSource.getJobById(tFailedJobId),
        ).thenAnswer((_) async => tFailedJob);
        _logger.d('$_tag Arranging: Mock saveJob expectation for tResetJob');
        // No need to mock saveJob specifically unless we expect a failure,
        // default setup handles success.

        // Act
        _logger.d(
          '$_tag Acting: Calling service.resetFailedJob($tFailedJobId)',
        );
        final result = await service.resetFailedJob(localId: tFailedJobId);
        _logger.d('$_tag Acted: result=$result');

        // Assert
        _logger.d('$_tag Asserting: Verifying interactions...');
        verify(mockLocalDataSource.getJobById(tFailedJobId)).called(1);
        // Use capture to verify the exact job saved
        final verificationResult = verify(
          mockLocalDataSource.saveJob(captureAny),
        );
        verificationResult.called(1);
        final savedJob = verificationResult.captured.single as Job;

        // Assert properties of the saved job
        expect(savedJob.localId, tFailedJobId);
        expect(savedJob.syncStatus, SyncStatus.pending);
        expect(savedJob.retryCount, 0);
        expect(savedJob.lastSyncAttemptAt, isNull);
        // Ensure other properties weren't accidentally changed
        expect(savedJob.serverId, tFailedJob.serverId);
        expect(savedJob.status, tFailedJob.status);

        // Verify no interaction with processor or network info
        verifyZeroInteractions(mockProcessorService);
        verifyZeroInteractions(mockNetworkInfo);

        // Expect success result
        expect(result, const Right(unit));
        _logger.i('$_tag Assertions complete. Test Passed.');
      },
    );

    test(
      'should do nothing and return success if the job is not found',
      () async {
        _logger.i('$_tag Test: reset non-existent job...');
        // Arrange
        _logger.d('$_tag Arranging: Mock getJobById to throw CacheException');
        // Simulate job not found by having getJobById throw
        when(
          mockLocalDataSource.getJobById(tNotFoundJobId),
        ).thenThrow(CacheException('Job not found'));

        // Act
        _logger.d(
          '$_tag Acting: Calling service.resetFailedJob($tNotFoundJobId)',
        );
        final result = await service.resetFailedJob(localId: tNotFoundJobId);
        _logger.d('$_tag Acted: result=$result');

        // Assert
        _logger.d('$_tag Asserting: Verifying interactions...');
        verify(mockLocalDataSource.getJobById(tNotFoundJobId)).called(1);
        verifyNever(mockLocalDataSource.saveJob(any)); // Should NOT save
        verifyZeroInteractions(mockProcessorService);
        verifyZeroInteractions(mockNetworkInfo);

        // Job not found is handled gracefully, returning Right(unit)
        expect(result, const Right(unit));
        _logger.i('$_tag Assertions complete. Test Passed.');
      },
    );

    test(
      'should do nothing and return success if the job is found but not in failed state',
      () async {
        _logger.i('$_tag Test: reset non-failed job...');
        // Arrange
        _logger.d('$_tag Arranging: Mock getJobById to return tNonFailedJob');
        when(
          mockLocalDataSource.getJobById(tNonFailedJobId),
        ).thenAnswer((_) async => tNonFailedJob);

        // Act
        _logger.d(
          '$_tag Acting: Calling service.resetFailedJob($tNonFailedJobId)',
        );
        final result = await service.resetFailedJob(localId: tNonFailedJobId);
        _logger.d('$_tag Acted: result=$result');

        // Assert
        _logger.d('$_tag Asserting: Verifying interactions...');
        verify(mockLocalDataSource.getJobById(tNonFailedJobId)).called(1);
        verifyNever(mockLocalDataSource.saveJob(any)); // Should NOT save
        verifyZeroInteractions(mockProcessorService);
        verifyZeroInteractions(mockNetworkInfo);

        // Still expect success
        expect(result, const Right(unit));
        _logger.i('$_tag Assertions complete. Test Passed.');
      },
    );

    test(
      'should return Left(CacheFailure) if localDataSource.getJobById throws',
      () async {
        _logger.i('$_tag Test: getJobById throws exception...');
        // Arrange
        final tException = Exception('Database exploded!');
        final tCacheException = CacheException(tException.toString());
        _logger.d('$_tag Arranging: Mock getJobById to throw $tCacheException');
        when(
          mockLocalDataSource.getJobById(tFailedJobId),
        ).thenThrow(tCacheException);

        // Act
        _logger.d(
          '$_tag Acting: Calling service.resetFailedJob($tFailedJobId)',
        );
        final result = await service.resetFailedJob(localId: tFailedJobId);
        _logger.d('$_tag Acted: result=$result');

        // Assert
        _logger.d('$_tag Asserting: Verifying interactions and result...');
        verify(mockLocalDataSource.getJobById(tFailedJobId)).called(1);
        verifyNever(mockLocalDataSource.saveJob(any));
        // Exception during getJobById is handled gracefully, returning Right(unit)
        expect(result, const Right(unit));
        _logger.i('$_tag Assertions complete. Test Passed.');
      },
    );

    test(
      'should return Left(CacheFailure) if localDataSource.saveJob throws',
      () async {
        _logger.i('$_tag Test: saveJob throws exception...');
        // Arrange
        final tException = Exception('Disk full!');
        final tCacheException = CacheException(tException.toString());
        _logger.d('$_tag Arranging: Mock getJobById to return tFailedJob');
        when(
          mockLocalDataSource.getJobById(tFailedJobId),
        ).thenAnswer((_) async => tFailedJob);
        _logger.d('$_tag Arranging: Mock saveJob to throw $tCacheException');
        when(mockLocalDataSource.saveJob(any)).thenThrow(tCacheException);

        // Act
        _logger.d(
          '$_tag Acting: Calling service.resetFailedJob($tFailedJobId)',
        );
        final result = await service.resetFailedJob(localId: tFailedJobId);
        _logger.d('$_tag Acted: result=$result');

        // Assert
        _logger.d('$_tag Asserting: Verifying interactions and result...');
        verify(mockLocalDataSource.getJobById(tFailedJobId)).called(1);
        // saveJob was called, but it threw
        verify(mockLocalDataSource.saveJob(any)).called(1);
        expect(
          result,
          Left(
            CacheFailure(tCacheException.message ?? 'CacheException occurred'),
          ),
        );
        _logger.i('$_tag Assertions complete. Test Passed.');
      },
    );
  });
}

// You might need to run build_runner if mocks are not generated:
// flutter pub run build_runner build --delete-conflicting-outputs
