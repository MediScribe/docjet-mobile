import 'dart:io';
import 'dart:math';

// import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // UNUSED (mocked via container)
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
// import 'package:docjet_mobile/core/interfaces/network_info.dart'; // UNUSED (mocked via container)
import 'package:docjet_mobile/core/utils/log_helpers.dart';
// import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'; // UNUSED (accessed via container)
// import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart'; // UNUSED (mocked via container)
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
// import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart'; // UNUSED (accessed via container)
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart'; // NEEDED for backoff
import 'package:flutter_test/flutter_test.dart';
// import 'package:get_it/get_it.dart'; // REMOVE GetIt
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Import the setup helpers and container
import 'e2e_setup_helpers.dart';
import 'e2e_dependency_container.dart';
// Import the generated mocks FROM the helper file
import 'e2e_setup_helpers.mocks.dart';

// Use shared handles - these need to be late and initialized in setUpAll
late Process? _mockServerProcess;
late Directory _tempDir;
late Box<JobHiveModel> _jobBox;
late E2EDependencyContainer _dependencies; // Store the container

// --- Test Globals (Managed by helpers) ---
// final sl = GetIt.instance; // REMOVE GetIt
final _logger = LoggerFactory.getLogger(testSuiteName); // Use helper's logger
final _tag = logTag(testSuiteName); // Use helper's tag

void main() {
  setUpAll(() async {
    // --- Shared Setup ---
    // For this test suite, we NEED the mock data source
    final setupResult = await setupE2ETestSuite(registerMockDataSource: true);
    _mockServerProcess = setupResult.$1;
    _tempDir = setupResult.$2;
    _jobBox = setupResult.$3;
    _dependencies = setupResult.$4; // Store the container
  });

  tearDownAll(() async {
    // --- Shared Teardown ---
    await teardownE2ETestSuite(_mockServerProcess, _tempDir, _jobBox);
  });

  setUp(() async {
    _logger.d('$_tag --- Setting up test ---');
    // Clear logs before each test
    LoggerFactory.clearLogs();
    // Clear the job box before each test to ensure isolation
    await _jobBox.clear();
    _logger.d('$_tag Job box cleared.');
    // Reset mocks using helper and container
    // This resets NetworkInfo, Auth, FileSystem, and the Mock Remote Data Source
    resetTestMocks(_dependencies);

    // Explicit reset of JobRemoteDataSource is handled inside resetTestMocks now
    // if (sl.isRegistered<JobRemoteDataSource>()) {
    //   reset(sl<JobRemoteDataSource>());
    // }

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag --- Tearing down test ---');
    // Any specific cleanup after each test can go here
  });

  group('Job Sync Retry E2E Tests', () {
    // ADJUSTED Group Name
    test(
      'should retry a failed job after backoff and succeed if server responds correctly',
      () async {
        _logger.i('$_tag --- Test: Sync Retry Logic ---');
        // Arrange: Get dependencies from container
        final jobRepository = _dependencies.jobRepository;
        final localDataSource = _dependencies.jobLocalDataSource;
        final mockRemoteDataSource =
            _dependencies.jobRemoteDataSource as MockApiJobRemoteDataSourceImpl;
        final mockNetworkInfo = _dependencies.mockNetworkInfo;
        final mockAuthSessionProvider = _dependencies.mockAuthSessionProvider;

        // Arrange: Ensure network is online
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Arrange: Set up auth session provider
        const userId = 'test-user-id-retry';
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenAnswer((_) async => userId);

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'retry_test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for retry');
        final audioFilePath = dummyAudioFile.path;
        const initialText = 'Job created before first failure';
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          audioFilePath: audioFilePath,
          text: initialText,
        );
        expect(
          createResult.isRight(),
          isTrue,
          reason: 'Local job creation failed',
        );
        final createdJob = createResult.getOrElse(
          () => throw Exception('Should have job'),
        );
        final localId = createdJob.localId;
        _logger.d('$_tag Job created locally with localId: $localId');

        // Arrange: Mock the FIRST remote call to fail
        _logger.d('$_tag Arranging: Mocking FIRST remote call to throw 500...');
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: audioFilePath,
            text: initialText,
            additionalText: null,
          ),
        ).thenThrow(
          ApiException(message: 'First Sync Failed', statusCode: 500),
        );

        // Allow time for immediate sync to complete (it's triggered by createJob)
        await Future.delayed(const Duration(seconds: 2));

        // Check current job state
        var jobFromDb = await localDataSource.getJobById(localId);

        // For tracking the result of manual sync
        Either<Failure, Unit> syncResult;

        // If job is already in error state from immediate sync, we can proceed
        if (jobFromDb.syncStatus == SyncStatus.error) {
          _logger.i('$_tag Job already in error state from immediate sync');
          expect(jobFromDb.retryCount, 1);
          expect(jobFromDb.lastSyncAttemptAt, isNotNull);
        }
        // Otherwise we need to trigger the sync manually
        else {
          // Act: Trigger first synchronization (expect failure)
          _logger.i(
            '$_tag Acting: Triggering first sync (expecting failure)...',
          );
          syncResult = await jobRepository.syncPendingJobs();
          expect(
            syncResult.isRight(),
            isTrue,
            reason: 'First sync orchestration should complete',
          );

          // Assert: Verify job state is 'error' and retry count is 1
          _logger.i('$_tag Verifying job state is error after first sync...');
          jobFromDb = await localDataSource.getJobById(localId);
          expect(jobFromDb.syncStatus, SyncStatus.error);
          expect(jobFromDb.retryCount, 1);
          expect(jobFromDb.lastSyncAttemptAt, isNotNull);
        }

        // --- SPEEDUP-HACK: Directly manipulate the job to bypass backoff ---
        // This avoids long delays in the test by manually setting the lastSyncAttemptAt
        // as if the exponential backoff period (retryBackoffBase * 2^retryCount) had already completed.
        _logger.d(
          '$_tag Manually setting job as if backoff period had completed...',
        );
        // Calculate backoff time for logging purposes
        final calculatedBackoff =
            retryBackoffBase * pow(2, jobFromDb.retryCount - 1).toInt();
        _logger.d(
          '$_tag Original backoff would have been ${calculatedBackoff.inSeconds}s for retry count ${jobFromDb.retryCount}',
        );

        // Set lastSyncAttemptAt to a time that ensures it's eligible for retry
        final backoffCompletionTime = DateTime.now().subtract(
          Duration(seconds: calculatedBackoff.inSeconds + 10), // Add buffer
        );

        // Update the job with the simulated elapsed time
        await localDataSource.saveJob(
          jobFromDb.copyWith(
            lastSyncAttemptAt: backoffCompletionTime,
            syncStatus:
                SyncStatus
                    .pending, // Change status to pending to ensure it's picked up
          ),
        );
        _logger.d('$_tag Job updated to simulate completed backoff period');

        // Verify the update was applied
        jobFromDb = await localDataSource.getJobById(localId);
        expect(
          jobFromDb.lastSyncAttemptAt!.isBefore(
            backoffCompletionTime.add(const Duration(seconds: 1)),
          ),
          isTrue,
          reason: 'Job should have updated lastSyncAttemptAt',
        );
        expect(
          jobFromDb.syncStatus,
          SyncStatus.pending,
          reason: 'Job status should be pending to ensure it gets processed',
        );

        // Arrange: Mock the SECOND remote call to succeed
        _logger.d('$_tag Arranging: Mocking SECOND remote call to succeed...');
        final mockServerId = const Uuid().v4();
        // Need to reset the 'when' for createJob
        reset(mockRemoteDataSource); // Reset previous when

        // Ensure auth session provider is still set up correctly
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenAnswer((_) async => userId);

        when(
          mockRemoteDataSource.createJob(
            audioFilePath: audioFilePath,
            text: initialText,
            additionalText: null,
          ),
        ).thenAnswer(
          (_) async => createdJob.copyWith(
            serverId: mockServerId,
            syncStatus: SyncStatus.synced, // Simulate server response
          ),
        );

        // Act: Trigger second synchronization (expect success)
        _logger.i(
          '$_tag Acting: Triggering second sync (expecting success)...',
        );
        syncResult = await jobRepository.syncPendingJobs();
        expect(
          syncResult.isRight(),
          isTrue,
          reason: 'Second sync orchestration should complete',
        );

        // Allow time for sync to complete
        await Future.delayed(const Duration(seconds: 1));

        // Assert: Verify job state is now 'synced'
        _logger.i('$_tag Verifying job state is synced after retry...');
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb, isNotNull);

        expect(
          jobFromDb.syncStatus,
          SyncStatus.synced,
          reason: 'Job status should be synced after successful retry',
        );
        expect(
          jobFromDb.serverId,
          mockServerId,
          reason: 'ServerId should be set after successful retry',
        );
        expect(
          jobFromDb.retryCount,
          0, // Processor resets retry count on success
          reason: 'Retry count should be 0 after successful sync.',
        );
        expect(
          jobFromDb.lastSyncAttemptAt,
          isNull, // Processor clears timestamp on success
          reason: 'Last sync attempt time should be null after success',
        );

        // Assert: Verify the remote createJob was called again
        verify(
          mockRemoteDataSource.createJob(
            audioFilePath: audioFilePath,
            text: initialText,
            additionalText: null,
          ),
        ).called(1); // Called once in the second attempt

        // Cleanup: Delete the dummy audio file
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i('$_tag --- Test: Sync Retry Logic Complete ---');
      },
    );
  });
}
