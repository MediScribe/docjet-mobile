import 'dart:io';
import 'dart:math';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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

    test(
      'should retry a failed job after backoff and succeed if server responds correctly',
      () async {
        _logger.i('$_tag --- Test: Sync Retry Logic ---');
        // Arrange: Get dependencies
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();
        final mockRemoteDataSource =
            sl<JobRemoteDataSource>() as MockApiJobRemoteDataSourceImpl;
        final mockNetworkInfo = sl<NetworkInfo>() as MockNetworkInfo;
        // const initialBackoff = Duration(
        //   seconds: 1,
        // ); // REMOVE: Don't assume, use config!

        // Arrange: Ensure network is online
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'retry_test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for retry');
        final audioFilePath = dummyAudioFile.path;
        final userId = 'test-user-id-retry';
        final initialText = 'Job created before first failure';
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          userId: userId,
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
            userId: userId,
            audioFilePath: audioFilePath,
            text: initialText,
            additionalText: null,
          ),
        ).thenThrow(
          ApiException(message: 'First Sync Failed', statusCode: 500),
        );

        // Act: Trigger first synchronization (expect failure)
        _logger.i('$_tag Acting: Triggering first sync (expecting failure)...');
        var syncResult = await jobRepository.syncPendingJobs();
        expect(
          syncResult.isRight(),
          isTrue,
          reason: 'First sync orchestration should complete',
        );

        // Assert: Verify job state is 'error' and retry count is 1
        _logger.i('$_tag Verifying job state is error after first sync...');
        var jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.error);
        expect(jobFromDb.retryCount, 1);
        expect(jobFromDb.lastSyncAttemptAt, isNotNull);
        final firstAttemptTime = jobFromDb.lastSyncAttemptAt!;

        // Arrange: Mock the SECOND remote call to succeed
        _logger.d('$_tag Arranging: Mocking SECOND remote call to succeed...');
        final mockServerId = const Uuid().v4();
        // Need to reset the 'when' for createJob
        reset(mockRemoteDataSource); // Reset previous when
        when(
          mockRemoteDataSource.createJob(
            userId: userId,
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

        // Act: Wait longer than the calculated backoff period (retryCount is 1)
        // Backoff = base * 2^retryCount = 1m * 2^1 = 2 minutes. Wait 2m 1s.
        final calculatedBackoff =
            retryBackoffBase *
            pow(
              2,
              jobFromDb.retryCount,
            ).toInt(); // USE retryBackoffBase from config
        final waitDuration =
            calculatedBackoff + const Duration(seconds: 1); // Wait 1s extra
        _logger.d(
          '$_tag Waiting for backoff period (${waitDuration.inSeconds}s)... Calculated backoff was ${calculatedBackoff.inSeconds}s for retry count ${jobFromDb.retryCount} using base ${retryBackoffBase.inSeconds}s.',
        );
        await Future.delayed(waitDuration);

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
          1, // Successful retry leaves retry count at 1 (doesn't reset)
          reason: 'Retry count should be 1 after one failure and one success.',
        );
        expect(
          jobFromDb.lastSyncAttemptAt,
          isNotNull,
          reason: 'Last sync attempt time should be updated',
        );
        // Ensure the timestamp was actually updated
        expect(
          jobFromDb.lastSyncAttemptAt!.isAfter(firstAttemptTime),
          isTrue,
          reason: 'Last sync time should be later than the first attempt',
        );

        // Assert: Verify the remote createJob was called again
        verify(
          mockRemoteDataSource.createJob(
            userId: userId,
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

    test('should detect server-side deletion and remove the job locally', () async {
      _logger.i('$_tag --- Test: Server-Side Deletion Detection ---');
      // Arrange: Get dependencies
      final jobRepository = sl<JobRepository>();
      final localDataSource = sl<JobLocalDataSource>();
      final mockRemoteDataSource =
          sl<JobRemoteDataSource>() as MockApiJobRemoteDataSourceImpl;
      final mockFileSystem = sl<FileSystem>() as MockFileSystem;
      final mockNetworkInfo = sl<NetworkInfo>() as MockNetworkInfo;

      // Arrange: Ensure network is online
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      // Arrange: Create a job locally
      _logger.d('$_tag Arranging: Creating job locally...');
      final dummyAudioFileName =
          'server_delete_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
      await dummyAudioFile.writeAsString('dummy audio for server delete');
      final audioFilePath = dummyAudioFile.path;
      final userId = 'test-user-id-server-delete';
      final initialText = 'Job to be deleted by server';
      expect(await dummyAudioFile.exists(), isTrue);

      final createResult = await jobRepository.createJob(
        userId: userId,
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

      // Arrange: Mock the FIRST remote createJob call to succeed
      final mockServerId = const Uuid().v4();
      _logger.d(
        '$_tag Arranging: Mocking FIRST remote createJob to succeed (ServerId: $mockServerId)...',
      );
      when(
        mockRemoteDataSource.createJob(
          userId: userId,
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
      // Also mock fetchJobs for the initial sync check (return the job)
      when(mockRemoteDataSource.fetchJobs()).thenAnswer(
        (_) async => [
          createdJob.copyWith(
            serverId: mockServerId,
            syncStatus: SyncStatus.synced,
          ),
        ],
      );

      // Act: Trigger first synchronization (to get serverId and synced status)
      _logger.i('$_tag Acting: Triggering first sync...');
      var syncResult = await jobRepository.syncPendingJobs();
      expect(
        syncResult.isRight(),
        isTrue,
        reason: 'First sync orchestration should complete',
      );

      // Assert: Verify job is synced locally
      _logger.i('$_tag Verifying job is synced after first sync...');
      var jobFromDb = await localDataSource.getJobById(localId);
      expect(jobFromDb.syncStatus, SyncStatus.synced);
      expect(jobFromDb.serverId, mockServerId);
      _logger.d('$_tag Job synced initially. ServerId: $mockServerId');

      // Arrange: Mock the SECOND remote fetchJobs call to return an EMPTY list
      _logger.d(
        '$_tag Arranging: Mocking SECOND remote fetchJobs to return EMPTY list...',
      );
      // Reset fetchJobs mock specifically - NO, just re-when it below
      // reset(mockRemoteDataSource); <-- REMOVED
      when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => []);
      // Mock file deletion expectation
      when(mockFileSystem.deleteFile(audioFilePath)).thenAnswer((_) async {});

      // Act: Trigger second synchronization (this should trigger the deletion check)
      _logger.i(
        '$_tag Acting: Triggering second sync (expecting deletion detection)...',
      );
      // Note: syncPendingJobs might not directly trigger the fetchJobs comparison
      // depending on implementation. Let's call getJobs which SHOULD trigger it.
      // await jobRepository.syncPendingJobs(); // May not be enough
      await jobRepository
          .getJobs(); // This often includes the remote fetch and comparison

      // Assert: Verify job is GONE from local DB
      _logger.i('$_tag Verifying job is removed locally...');
      expect(
        () async => await localDataSource.getJobById(localId),
        throwsA(isA<CacheException>()),
        reason:
            'Job should be deleted locally after server-side removal detection',
      );

      // Assert: Verify file system delete was called
      _logger.i('$_tag Verifying file deletion was called...');
      verify(mockFileSystem.deleteFile(audioFilePath)).called(1);

      // Cleanup: Ensure dummy file is gone if verify failed for some reason
      _logger.d('$_tag Cleaning up dummy audio file (final check)...');
      if (await dummyAudioFile.exists()) {
        await dummyAudioFile.delete();
      }
      expect(await dummyAudioFile.exists(), isFalse);
      _logger.i('$_tag --- Test: Server-Side Deletion Detection Complete ---');
    });

    test(
      'should reset a failed job to pending and allow successful sync afterwards',
      () async {
        _logger.i('$_tag --- Test: Reset Failed Job ---');
        // Arrange: Get dependencies
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();
        final mockRemoteDataSource =
            sl<JobRemoteDataSource>() as MockApiJobRemoteDataSourceImpl;
        final mockNetworkInfo = sl<NetworkInfo>() as MockNetworkInfo;
        // const maxRetries = 5; // Assume this is the configured max retries <-- REMOVED Use config constant

        // Arrange: Ensure network is online
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'reset_fail_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for reset fail');
        final audioFilePath = dummyAudioFile.path;
        final userId = 'test-user-id-reset-fail';
        final initialText = 'Job to be failed and reset';
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          userId: userId,
          audioFilePath: audioFilePath,
          text: initialText,
        );
        expect(createResult.isRight(), true);
        final createdJob = createResult.getOrElse(() => throw Exception());
        final localId = createdJob.localId;
        _logger.d('$_tag Job created locally with localId: $localId');

        // Arrange: Mock remote call to fail repeatedly
        _logger.d(
          '$_tag Arranging: Mocking remote createJob to fail $maxRetryAttempts times...', // USE config constant
        );
        when(
          mockRemoteDataSource.createJob(
            userId: userId,
            audioFilePath: audioFilePath,
            text: initialText,
            additionalText: null,
          ),
        ).thenThrow(ApiException(message: 'Repeated Failure', statusCode: 500));

        // Act: Trigger sync repeatedly until it fails permanently
        _logger.i(
          '$_tag Acting: Triggering sync $maxRetryAttempts times to force failure...', // USE config constant
        );
        for (var i = 0; i < maxRetryAttempts; i++) {
          // USE config constant
          _logger.d(
            '$_tag Sync attempt ${i + 1}/$maxRetryAttempts...',
          ); // USE config constant
          final syncResult = await jobRepository.syncPendingJobs();
          expect(
            syncResult.isRight(),
            true,
            reason: 'Sync orchestration failed',
          );
          // Add a small delay if needed, depends on backoff implementation test setup
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Assert: Verify job state is 'failed'
        _logger.i('$_tag Verifying job state is failed...');
        var jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.failed);
        expect(jobFromDb.retryCount, maxRetryAttempts); // USE config constant

        // Act: Reset the failed job
        _logger.i('$_tag Acting: Resetting failed job...');
        final resetResult = await jobRepository.resetFailedJob(localId);
        expect(
          resetResult.isRight(),
          true,
          reason: 'Resetting failed job failed',
        );

        // Assert: Verify job state is now 'pending' and retry count is 0
        _logger.i('$_tag Verifying job state is pending after reset...');
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.pending);
        expect(jobFromDb.retryCount, 0);
        _logger.d('$_tag Job successfully reset to pending.');

        // Arrange: Mock remote call to SUCCEED now
        _logger.d('$_tag Arranging: Mocking remote createJob to succeed...');
        final mockServerId = const Uuid().v4();
        reset(mockRemoteDataSource); // Reset the previous failure mock
        when(
          mockRemoteDataSource.createJob(
            userId: userId,
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

        // Act: Trigger sync again (should succeed now)
        _logger.i('$_tag Acting: Triggering sync after reset...');
        final finalSyncResult = await jobRepository.syncPendingJobs();
        expect(
          finalSyncResult.isRight(),
          true,
          reason: 'Final sync orchestration failed',
        );

        // Assert: Verify job state is 'synced'
        _logger.i(
          '$_tag Verifying job state is synced after reset and sync...',
        );
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.synced);
        expect(jobFromDb.serverId, mockServerId);

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
