import 'dart:io';

// import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // UNUSED
import 'package:docjet_mobile/core/error/exceptions.dart';
// import 'package:docjet_mobile/core/interfaces/network_info.dart'; // UNUSED
import 'package:docjet_mobile/core/utils/log_helpers.dart';
// import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'; // UNUSED
// import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart'; // UNUSED
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
// import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart'; // UNUSED
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart'; // NEEDED for maxRetryAttempts
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
    resetTestMocks(_dependencies);
    // Remove explicit reset of remote data source, handled by resetTestMocks
    // if (sl.isRegistered<JobRemoteDataSource>()) {
    //   reset(sl<JobRemoteDataSource>());
    // }

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag --- Tearing down test ---');
    // Any specific cleanup after each test can go here
  });

  group('Job Sync Reset Failed E2E Tests', () {
    // ADJUSTED Group Name
    test(
      'should reset a failed job to pending and allow successful sync afterwards',
      () async {
        _logger.i('$_tag --- Test: Reset Failed Job ---');
        // Arrange: Get dependencies from container
        final jobRepository = _dependencies.jobRepository;
        final localDataSource = _dependencies.jobLocalDataSource;
        final mockRemoteDataSource =
            _dependencies.jobRemoteDataSource as MockApiJobRemoteDataSourceImpl;
        final mockNetworkInfo = _dependencies.mockNetworkInfo;
        final mockAuthSessionProvider = _dependencies.mockAuthSessionProvider;

        // Arrange: Ensure network is online (using mock from container)
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Arrange: Set up auth session provider
        const userId = 'test-user-id-reset-fail';
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenAnswer((_) async => userId);

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'reset_fail_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for reset fail');
        final audioFilePath = dummyAudioFile.path;
        const initialText = 'Job to be failed and reset';
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          audioFilePath: audioFilePath,
          text: initialText,
        );
        expect(createResult.isRight(), true);
        final createdJob = createResult.getOrElse(() => throw Exception());
        final localId = createdJob.localId;
        _logger.d('$_tag Job created locally with localId: $localId');

        // Arrange: Mock remote call to fail repeatedly (using mock from container)
        _logger.d(
          '$_tag Arranging: Mocking remote createJob to fail $maxRetryAttempts times...', // USE config constant
        );
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: audioFilePath,
            text: initialText,
            additionalText: null,
          ),
        ).thenThrow(ApiException(message: 'Repeated Failure', statusCode: 500));

        // Act: Instead of triggering sync multiple times, directly set the job to failed status (using local DS from container)
        _logger.i(
          '$_tag Acting: Directly setting job to failed status to speed up the test...',
        );
        var jobFromDb = await localDataSource.getJobById(localId);
        await localDataSource.saveJob(
          jobFromDb.copyWith(
            syncStatus: SyncStatus.failed,
            retryCount: maxRetryAttempts, // Set the retry count to max
            lastSyncAttemptAt: DateTime.now(),
          ),
        );

        // Verify the job is in failed state (using local DS from container)
        _logger.i('$_tag Verifying job state is failed...');
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.failed);
        expect(jobFromDb.retryCount, maxRetryAttempts);

        // Act: Reset the failed job (using repo from container)
        _logger.i('$_tag Acting: Resetting failed job...');
        final resetResult = await jobRepository.resetFailedJob(localId);
        expect(
          resetResult.isRight(),
          true,
          reason: 'Resetting failed job failed',
        );

        // Assert: Verify job state is now 'pending' and retry count is 0 (using local DS from container)
        _logger.i('$_tag Verifying job state is pending after reset...');
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.pending);
        expect(jobFromDb.retryCount, 0);
        _logger.d('$_tag Job successfully reset to pending.');

        // Arrange: Mock remote call to SUCCEED now (using mocks from container)
        _logger.d('$_tag Arranging: Mocking remote createJob to succeed...');
        final mockServerId = const Uuid().v4();
        reset(
          mockRemoteDataSource,
        ); // Reset the previous failure mock (from container)

        // Make sure auth session provider mock (from container) is still set correctly
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
            syncStatus: SyncStatus.synced,
          ),
        );

        // Act: Trigger sync again (should succeed now) (using repo from container)
        _logger.i('$_tag Acting: Triggering sync after reset...');
        final finalSyncResult = await jobRepository.syncPendingJobs();
        expect(
          finalSyncResult.isRight(),
          true,
          reason: 'Final sync orchestration failed',
        );

        // Assert: Verify job state is 'synced' (using local DS from container)
        _logger.i(
          '$_tag Verifying job state is synced after reset and sync...',
        );
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.synced);
        expect(jobFromDb.serverId, mockServerId);
        expect(jobFromDb.lastSyncAttemptAt, isNull);

        // Cleanup: Delete the dummy audio file
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i('$_tag --- Test: Reset Failed Job Complete ---');
      },
    );
  });
}
