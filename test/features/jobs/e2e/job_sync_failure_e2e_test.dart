import 'dart:io';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

// Import the setup helpers
import 'e2e_setup_helpers.dart';
// Import the generated mocks FROM the helper file
import 'e2e_setup_helpers.mocks.dart';

// --- Test Globals (Managed by helpers) ---
final sl = GetIt.instance; // Keep for easy access in tests
final _logger = LoggerFactory.getLogger(
  'JobSyncFailureE2eTest',
); // Use specific name
final _tag = logTag('JobSyncFailureE2eTest'); // Use specific name
Process? _mockServerProcess;
late Directory _tempDir;
late Box<JobHiveModel> _jobBox;
// Note: dynamicMockServerUrl and mockServerPort are managed within setUpAll

void main() {
  setUpAll(() async {
    // --- Logging Setup ---
    LoggerFactory.setLogLevel(
      'JobSyncFailureE2eTest', // Use specific name
      Level.debug,
    );
    _logger.i('$_tag --- Starting Failure E2E Test Suite ---');

    // --- Mock Server Setup (using helper) ---
    _logger.i('$_tag Starting mock server...');
    final serverResult = await startMockServer();
    _mockServerProcess = serverResult.$1;
    final mockServerPort = serverResult.$2;
    if (_mockServerProcess == null) {
      throw Exception('Mock server process failed to start.');
    }
    final dynamicMockServerUrl = 'http://localhost:$mockServerPort';
    _logger.i(
      '$_tag Mock server started on $dynamicMockServerUrl (PID: ${_mockServerProcess?.pid})',
    );

    // --- Hive Setup (using helper) ---
    final hiveResult = await setupHive();
    _tempDir = hiveResult.$1;
    _jobBox = hiveResult.$2;

    // --- DI Setup (using helper, including mock remote source) ---
    await setupDI(
      dynamicMockServerUrl: dynamicMockServerUrl,
      jobBox: _jobBox,
      registerMockDataSource: true,
    );
  });

  tearDownAll(() async {
    _logger.i('$_tag --- Tearing Down Failure E2E Test Suite ---');
    // --- DI Teardown (using helper) ---
    await teardownDI();

    // --- Hive Teardown (using helper) ---
    await teardownHive(_tempDir, _jobBox);

    // --- Mock Server Teardown (using helper) ---
    await stopMockServer(_mockServerProcess);

    _logger.i('$_tag --- Failure E2E Test Suite Teardown Complete ---');
  });

  setUp(() async {
    _logger.d('$_tag --- Setting up test ---');
    // Clear logs before each test
    LoggerFactory.clearLogs();
    // Clear the job box before each test to ensure isolation
    await _jobBox.clear();
    _logger.d('$_tag Job box cleared.');
    // Reset mocks using helper
    resetTestMocks();
    // Ensure mock remote data source is reset if registered
    if (sl.isRegistered<JobRemoteDataSource>()) {
      reset(sl<JobRemoteDataSource>());
    }

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag --- Tearing down test ---');
    // Any specific cleanup after each test can go here
  });

  group('Job Sync Failure E2E Tests', () {
    // Test Sync Failure (Server 5xx)
    test(
      'should mark job with error status when server returns 5xx during sync',
      () async {
        _logger.i('$_tag --- Test: Sync Failure - Server 5xx ---');
        // Arrange: Get dependencies
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();
        final mockRemoteDataSource =
            sl<JobRemoteDataSource>() as MockApiJobRemoteDataSourceImpl;
        final mockNetworkInfo = sl<NetworkInfo>() as MockNetworkInfo;

        // Arrange: Ensure network is online
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'server_5xx_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for 5xx fail');
        final audioFilePath = dummyAudioFile.path;
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          userId: 'test-user-id-5xx-fail',
          audioFilePath: audioFilePath,
          text: 'Job created before server 5xx failure',
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

        // Arrange: Verify initial status is pending
        var jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.pending);

        // Arrange: Mock the remote data source to throw a 500 server error
        _logger.d(
          '$_tag Arranging: Mocking remote createJob to throw 500 error...',
        );
        // Use the named arguments matching the createJob signature
        when(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenThrow(
          ApiException(message: 'Internal Server Error', statusCode: 500),
        );

        // Act: Trigger synchronization
        _logger.i(
          '$_tag Acting: Triggering sync expecting server 5xx error...',
        );
        final syncResult = await jobRepository.syncPendingJobs();

        // Assert: Sync orchestration should still succeed (it delegates error handling)
        expect(
          syncResult.isRight(),
          isTrue,
          reason: 'Sync orchestration should complete',
        );

        // Assert: Verify job state is now 'error' in local DB
        _logger.i('$_tag Verifying job state is now error...');
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb, isNotNull, reason: 'Job should still exist locally');
        expect(
          jobFromDb.syncStatus,
          SyncStatus.error,
          reason: 'Job status should be error after 5xx',
        );
        expect(
          jobFromDb.serverId,
          isNull,
          reason: 'ServerId should remain null',
        );
        expect(
          jobFromDb.retryCount,
          1,
          reason: 'Retry count should be incremented to 1',
        );
        expect(
          jobFromDb.lastSyncAttemptAt,
          isNotNull,
          reason: 'Last sync attempt time should be set',
        );

        // Assert: Verify the remote createJob was called once
        verify(
          mockRemoteDataSource.createJob(
            userId: 'test-user-id-5xx-fail',
            audioFilePath: audioFilePath,
            text: 'Job created before server 5xx failure',
            additionalText: null, // Explicitly null if not provided
          ),
        ).called(1);

        // Cleanup: Delete the dummy audio file
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i('$_tag --- Test: Sync Failure - Server 5xx Complete ---');
      },
    );

    // TODO: Test Retry Logic: Create -> Fail Sync -> Verify Error -> Wait -> Sync -> Verify Success or Failed

    // TODO: Test Server-Side Deletion Detection: Create -> Sync -> Mock Job Gone -> Sync -> Verify Local Deletion

    // TODO: Test Reset Failed Job: Create -> Fail Sync -> Verify Failed -> Reset -> Verify Pending -> Sync -> Verify Synced
  });
}
