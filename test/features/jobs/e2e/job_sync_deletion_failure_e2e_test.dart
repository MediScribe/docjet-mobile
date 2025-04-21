import 'dart:io';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
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
import 'package:uuid/uuid.dart';

// Import the setup helpers
import 'e2e_setup_helpers.dart';
// Import the generated mocks FROM the helper file
import 'e2e_setup_helpers.mocks.dart';

// Use shared handles - these need to be late and initialized in setUpAll
late Process? _mockServerProcess;
late Directory _tempDir;
late Box<JobHiveModel> _jobBox;

// --- Test Globals (Managed by helpers) ---
final sl = GetIt.instance; // Keep for easy access in tests
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
    // REMOVE all the individual setup steps (they are now inside setupE2ETestSuite)
  });

  tearDownAll(() async {
    // --- Shared Teardown ---
    await teardownE2ETestSuite(_mockServerProcess, _tempDir, _jobBox);
    // REMOVE all individual teardown steps (they are now inside teardownE2ETestSuite)
  });

  setUp(() async {
    _logger.d('$_tag --- Setting up test ---');
    // Clear logs before each test
    LoggerFactory.clearLogs();
    // Clear the job box before each test to ensure isolation
    await _jobBox.clear();
    _logger.d('$_tag Job box cleared.');
    // Reset mocks using helper
    resetTestMocks(); // This should reset FileSystem too if setup correctly
    // Ensure mock remote data source is reset if registered
    if (sl.isRegistered<JobRemoteDataSource>()) {
      reset(sl<JobRemoteDataSource>());
    }
    // Ensure mock file system is reset if registered
    if (sl.isRegistered<FileSystem>()) {
      reset(sl<FileSystem>());
    }

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag --- Tearing down test ---');
    // Any specific cleanup after each test can go here
  });

  group('Job Sync Deletion Failure E2E Tests', () {
    // ADJUSTED Group Name
    test(
      'should mark job with error status when server returns 5xx during deletion sync',
      () async {
        _logger.i('$_tag --- Test: Sync Failure - Deletion Server 5xx ---');
        // Arrange: Get dependencies
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();
        final mockRemoteDataSource =
            sl<JobRemoteDataSource>() as MockApiJobRemoteDataSourceImpl;
        final mockFileSystem =
            sl<FileSystem>() as MockFileSystem; // Need for verification
        final mockNetworkInfo = sl<NetworkInfo>() as MockNetworkInfo;

        // Arrange: Ensure network is online
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'delete_5xx_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for delete 5xx fail');
        final audioFilePath = dummyAudioFile.path;
        final userId = 'test-user-id-delete-5xx';
        final initialText = 'Job to fail deletion sync';
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

        // Arrange: Mock the initial createJob call to succeed
        final mockServerId = const Uuid().v4();
        _logger.d(
          '$_tag Arranging: Mocking initial createJob to succeed (ServerId: $mockServerId)...',
        );
        reset(mockRemoteDataSource); // Clear previous mocks if any
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
        // Also mock fetchJobs for the initial sync check
        when(mockRemoteDataSource.fetchJobs()).thenAnswer(
          (_) async => [
            createdJob.copyWith(
              serverId: mockServerId,
              syncStatus: SyncStatus.synced,
            ),
          ],
        );

        // Act: Trigger initial sync
        _logger.i('$_tag Acting: Triggering initial sync...');
        final initialSyncResult = await jobRepository.syncPendingJobs();
        expect(initialSyncResult.isRight(), true);

        // Assert: Verify job is synced locally
        _logger.i('$_tag Verifying job is synced locally...');
        var jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.synced);
        expect(jobFromDb.serverId, mockServerId);
        _logger.d('$_tag Initial sync complete. ServerId: $mockServerId');

        // Arrange: Mark job for deletion locally
        _logger.i('$_tag Arranging: Marking job for deletion locally...');
        final deleteResult = await jobRepository.deleteJob(localId);
        expect(deleteResult.isRight(), true);
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb.syncStatus, SyncStatus.pendingDeletion);
        _logger.d('$_tag Job marked for deletion.');

        // Arrange: Mock the remote deleteJob call to throw a 500 error
        _logger.d(
          '$_tag Arranging: Mocking remote deleteJob to throw 500 error...',
        );
        when(mockRemoteDataSource.deleteJob(mockServerId)).thenThrow(
          ApiException(
            message: 'Deletion Failed Server Error',
            statusCode: 500,
          ),
        );
        // Ensure file delete is NOT called yet
        verifyNever(mockFileSystem.deleteFile(audioFilePath));

        // Act: Trigger synchronization again (for the deletion)
        _logger.i(
          '$_tag Acting: Triggering deletion sync (expecting failure)...',
        );
        final deleteSyncResult = await jobRepository.syncPendingJobs();
        expect(
          deleteSyncResult.isRight(),
          true,
        ); // Orchestration should succeed

        // Assert: Verify job state is now 'error' in local DB
        _logger.i('$_tag Verifying job state is now error...');
        jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb, isNotNull, reason: 'Job should still exist locally');
        expect(
          jobFromDb.syncStatus,
          SyncStatus.error,
          reason: 'Job status should be error after failed deletion sync',
        );
        expect(
          jobFromDb.serverId, // ServerId remains
          mockServerId,
          reason: 'ServerId should still be present',
        );
        expect(
          jobFromDb.retryCount,
          1, // Incremented from 0
          reason: 'Retry count should be incremented to 1',
        );
        expect(
          jobFromDb.lastSyncAttemptAt,
          isNotNull,
          reason: 'Last sync attempt time should be set',
        );

        // Assert: Verify the remote deleteJob was called once
        verify(mockRemoteDataSource.deleteJob(mockServerId)).called(1);
        // Assert: Verify file system delete was NOT called because sync failed
        verifyNever(mockFileSystem.deleteFile(audioFilePath));

        // Cleanup: Delete the dummy audio file (manually, as the deletion failed)
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i(
          '$_tag --- Test: Sync Failure - Deletion Server 5xx Complete ---',
        );
      },
    );
  });
}
