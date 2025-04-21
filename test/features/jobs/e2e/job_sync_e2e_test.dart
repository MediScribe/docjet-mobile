// import 'dart:convert'; // No longer needed directly
import 'dart:io';
import 'package:path/path.dart' as p; // Added path import back

// import 'package:dio/dio.dart'; // Handled by DI setup
// import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart'; // Mocked via DI
import 'package:docjet_mobile/core/interfaces/network_info.dart'; // Add this import
import 'package:docjet_mobile/core/platform/file_system.dart'; // Still needed for MockFileSystem type
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
// import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart'; // DI
// import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart'; // DI
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'; // Needed for type
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart'; // Needed for type
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart'; // Needed for type
// import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart'; // DI
// import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart'; // DI
// import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart'; // DI
// import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'; // DI
// import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart'; // DI
// import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart'; // DI
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:mockito/annotations.dart'; // Moved to helpers
import 'package:mockito/mockito.dart'; // Still needed for verify
// import 'package:path/path.dart' as p; // Moved to helpers
import 'package:uuid/uuid.dart';

// Import the setup helpers
import 'e2e_setup_helpers.dart';
// Import the generated mocks FROM the helper file
import 'e2e_setup_helpers.mocks.dart';

// --- Test Globals (Managed by helpers) ---
final sl = GetIt.instance; // Keep for easy access in tests
final _logger = LoggerFactory.getLogger(testSuiteName); // Use helper's logger
final _tag = logTag(testSuiteName); // Use helper's tag
Process? _mockServerProcess;
late Directory _tempDir;
late Box<JobHiveModel> _jobBox;
// Note: dynamicMockServerUrl and mockServerPort are managed within setUpAll

// Remove duplicate mock generation
// @GenerateMocks([NetworkInfo, AuthCredentialsProvider, FileSystem])
// import 'job_sync_e2e_test.mocks.dart';

// REMOVE ALL HELPER FUNCTIONS (_logHelper, _startMockServer, _stopMockServer, _setupDI)
// ... existing code ...

void main() {
  // Note: TestWidgetsFlutterBinding.ensureInitialized() MUST NOT be used for network tests

  setUpAll(() async {
    // --- Logging Setup ---
    LoggerFactory.setLogLevel(
      testSuiteName,
      Level.debug,
    ); // Use constant from helper
    _logger.i('$_tag --- Starting E2E Test Suite --- GOGO');

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

    // --- DI Setup (using helper, AFTER server URL and jobBox are known) ---
    await setupDI(
      dynamicMockServerUrl: dynamicMockServerUrl,
      jobBox: _jobBox,
      // registerMockDataSource: false, // Default is false
    );
  });

  tearDownAll(() async {
    _logger.i('$_tag --- Tearing Down E2E Test Suite ---');
    // --- DI Teardown (using helper) ---
    await teardownDI();

    // --- Hive Teardown (using helper) ---
    await teardownHive(_tempDir, _jobBox);

    // --- Mock Server Teardown (using helper) ---
    await stopMockServer(_mockServerProcess);

    _logger.i('$_tag --- E2E Test Suite Teardown Complete ---');
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

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag --- Tearing down test ---');
    // Any specific cleanup after each test can go here
  });

  group('Job Sync E2E Tests', () {
    test('Setup and Teardown Check', () {
      _logger.i('$_tag Running dummy test to verify setup...');
      expect(sl.isRegistered<JobRepository>(), isTrue);
      expect(_jobBox.isOpen, isTrue);
      expect(_mockServerProcess, isNotNull);
      // Check if the CORRECT FileSystem mock is registered
      expect(sl.isRegistered<FileSystem>(), isTrue);
      _logger.i('$_tag Dummy test passed.');
    });

    // MVT: Create job locally, sync to mock server, verify status and serverId
    test(
      'should create a job locally and sync it successfully with the mock server',
      () async {
        _logger.i('$_tag --- Test: Create and Sync Job ---');
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();

        // Arrange: Create a dummy audio file
        final dummyAudioFileName =
            'test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        // Use _tempDir which is correctly initialized in setUpAll
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio content');
        _logger.d('$_tag Created dummy audio file: ${dummyAudioFile.path}');
        expect(await dummyAudioFile.exists(), isTrue);

        // Act: Create the job locally
        _logger.i('$_tag Creating job locally...');
        final createResult = await jobRepository.createJob(
          userId: 'test-user-id-123',
          audioFilePath: dummyAudioFile.path,
          text: 'Initial test text',
        );

        // Assert: Verify local creation was successful
        expect(
          createResult.isRight(),
          isTrue,
          reason: 'Expected job creation to succeed',
        );
        final createdJob = createResult.getOrElse(
          () => throw Exception('Should have returned job'),
        );
        final localId = createdJob.localId;
        _logger.d('$_tag Job created locally with localId: $localId');

        // Assert: Verify initial state in local DB
        final jobFromDbInitial = await localDataSource.getJobById(localId);
        expect(
          jobFromDbInitial,
          isNotNull,
          reason: 'Job should exist in local DB after creation',
        );
        expect(
          jobFromDbInitial.syncStatus,
          SyncStatus.pending,
          reason: 'Initial status should be pending',
        );
        expect(
          jobFromDbInitial.serverId,
          isNull,
          reason: 'Initial serverId should be null',
        );
        expect(jobFromDbInitial.text, 'Initial test text');
        expect(jobFromDbInitial.audioFilePath, dummyAudioFile.path);

        // Act: Trigger synchronization
        _logger.i('$_tag Triggering sync...');
        final syncResult = await jobRepository.syncPendingJobs();

        // Assert: Sync orchestration should report success (doesn't guarantee individual job success yet)
        expect(
          syncResult.isRight(),
          isTrue,
          reason: 'Sync orchestration should succeed',
        );

        // Allow time for async operations (API call, DB update)
        _logger.d('$_tag Waiting for sync operations to complete...');
        await Future.delayed(const Duration(seconds: 2)); // Adjust if needed

        // Assert: Verify final state in local DB
        _logger.i('$_tag Verifying final job state in local DB...');
        final jobFromDbFinal = await localDataSource.getJobById(localId);
        expect(
          jobFromDbFinal,
          isNotNull,
          reason: 'Job should still exist in local DB after sync',
        );
        expect(
          jobFromDbFinal.syncStatus,
          SyncStatus.synced,
          reason: 'Final status should be synced',
        );
        expect(
          jobFromDbFinal.serverId,
          isNotNull,
          reason: 'Final serverId should not be null',
        );
        // Mock server generates UUIDs for serverId
        expect(
          Uuid.isValidUUID(fromString: jobFromDbFinal.serverId!),
          isTrue,
          reason: 'ServerId should be a valid UUID',
        );
        _logger.d(
          '$_tag Job synced successfully. ServerId: ${jobFromDbFinal.serverId}',
        );

        // Cleanup: Delete the dummy audio file
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i('$_tag --- Test: Create and Sync Job Complete ---');
      },
    );

    // Test Update Sync: Create -> Sync -> Update -> Sync -> Verify
    test(
      'should update a job locally, sync the update, and verify the changes',
      () async {
        _logger.i('$_tag --- Test: Update and Sync Job ---');
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();

        // Arrange Part 1: Create and initial sync
        _logger.d('$_tag Arranging: Creating initial job...');
        final dummyAudioFileName =
            'update_test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        // Use _tempDir
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio content for update');
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          userId: 'test-user-id-update',
          audioFilePath: dummyAudioFile.path,
          text: 'Initial text before update',
        );
        expect(
          createResult.isRight(),
          isTrue,
          reason: 'Initial creation failed',
        );
        final createdJob = createResult.getOrElse(
          () => throw Exception('Should have job'),
        );
        final localId = createdJob.localId;
        _logger.d('$_tag Initial job created with localId: $localId');

        _logger.d('$_tag Arranging: Performing initial sync...');
        final initialSyncResult = await jobRepository.syncPendingJobs();
        expect(
          initialSyncResult.isRight(),
          isTrue,
          reason: 'Initial sync failed',
        );
        await Future.delayed(const Duration(seconds: 2)); // Allow sync time

        final jobAfterInitialSync = await localDataSource.getJobById(localId);
        expect(jobAfterInitialSync, isNotNull);
        expect(
          jobAfterInitialSync.syncStatus,
          SyncStatus.synced,
          reason: 'Job should be synced after initial sync',
        );
        expect(
          jobAfterInitialSync.serverId,
          isNotNull,
          reason: 'ServerId should be set after initial sync',
        );
        final serverId = jobAfterInitialSync.serverId!;
        _logger.d('$_tag Initial sync complete. ServerId: $serverId');

        // Act: Update the job locally
        _logger.i('$_tag Acting: Updating job text locally...');
        final updateDetails = JobUpdateDetails(text: 'Updated test text');
        final updateResult = await jobRepository.updateJob(
          localId: localId,
          updates: updateDetails,
        );

        // Assert: Verify local update and status change
        expect(updateResult.isRight(), isTrue, reason: 'Local update failed');
        final jobAfterLocalUpdate = await localDataSource.getJobById(localId);
        expect(jobAfterLocalUpdate, isNotNull);
        expect(
          jobAfterLocalUpdate.text,
          'Updated test text',
          reason: 'Local text should be updated immediately',
        );
        expect(
          jobAfterLocalUpdate.syncStatus,
          SyncStatus.pending,
          reason: 'Status should be pending after local update',
        );
        _logger.d('$_tag Local update successful, status set to pending.');

        // Act: Trigger synchronization for the update
        _logger.i('$_tag Acting: Triggering sync for the update...');
        final updateSyncResult = await jobRepository.syncPendingJobs();

        // Assert: Sync orchestration should report success
        expect(
          updateSyncResult.isRight(),
          isTrue,
          reason: 'Update sync orchestration failed',
        );

        // Allow time for async operations
        _logger.d('$_tag Waiting for update sync operations to complete...');
        await Future.delayed(const Duration(seconds: 2)); // Adjust if needed

        // Assert: Verify final state in local DB
        _logger.i('$_tag Verifying final job state after update sync...');
        final jobFromDbFinal = await localDataSource.getJobById(localId);
        expect(
          jobFromDbFinal,
          isNotNull,
          reason: 'Job should still exist after update sync',
        );
        expect(
          jobFromDbFinal.syncStatus,
          SyncStatus.synced,
          reason: 'Final status should be synced after update sync',
        );
        expect(
          jobFromDbFinal.serverId,
          serverId,
          reason: 'ServerId should remain the same',
        );
        expect(
          jobFromDbFinal.text,
          'Updated test text',
          reason: 'Final text should be the updated value',
        );
        _logger.d('$_tag Job update synced successfully.');

        // Cleanup: Delete the dummy audio file
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i('$_tag --- Test: Update and Sync Job Complete ---');
      },
    );

    // Test Delete Sync (Local): Create -> Sync -> Delete Loc -> Sync -> Verify gone
    test(
      'should mark a job for deletion locally, sync the deletion, and remove it locally along with its file',
      () async {
        _logger.i('$_tag --- Test: Delete and Sync Job ---');
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();
        final mockFileSystem =
            sl<FileSystem>() as MockFileSystem; // Use the imported mock type

        // Arrange: Create, sync a job, and create its dummy file
        _logger.d('$_tag Arranging: Creating and syncing initial job...');
        final dummyAudioFileName =
            'delete_test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        // Use _tempDir
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio content for delete');
        final audioFilePath = dummyAudioFile.path;
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          userId: 'test-user-id-delete',
          audioFilePath: audioFilePath,
          text: 'Job to be deleted',
        );
        expect(
          createResult.isRight(),
          isTrue,
          reason: 'Initial creation failed',
        );
        final createdJob = createResult.getOrElse(
          () => throw Exception('Should have job'),
        );
        final localId = createdJob.localId;
        _logger.d('$_tag Job created locally with localId: $localId');

        final initialSyncResult = await jobRepository.syncPendingJobs();
        expect(
          initialSyncResult.isRight(),
          isTrue,
          reason: 'Initial sync failed',
        );
        await Future.delayed(const Duration(seconds: 2)); // Allow sync time

        final jobAfterInitialSync = await localDataSource.getJobById(localId);
        expect(jobAfterInitialSync, isNotNull);
        expect(jobAfterInitialSync.syncStatus, SyncStatus.synced);
        expect(jobAfterInitialSync.serverId, isNotNull);
        final serverId = jobAfterInitialSync.serverId!;
        _logger.d('$_tag Initial sync complete. ServerId: $serverId');

        // Act: Mark job for deletion locally
        _logger.i('$_tag Acting: Marking job for deletion locally...');
        final deleteResult = await jobRepository.deleteJob(localId);
        expect(deleteResult.isRight(), isTrue, reason: 'Local delete failed');

        // Assert: Verify local status is pendingDeletion
        final jobAfterLocalDelete = await localDataSource.getJobById(localId);
        expect(jobAfterLocalDelete, isNotNull);
        expect(
          jobAfterLocalDelete.syncStatus,
          SyncStatus.pendingDeletion,
          reason: 'Status should be pendingDeletion',
        );
        _logger.d('$_tag Job marked for deletion locally.');

        // Arrange: Expect file deletion call (returns Future<void>)
        when(
          mockFileSystem.deleteFile(audioFilePath),
        ).thenAnswer((_) async {}); // Correct: Return Future<void>

        // Act: Trigger sync for deletion
        _logger.i('$_tag Acting: Triggering sync for deletion...');
        final deleteSyncResult = await jobRepository.syncPendingJobs();
        expect(
          deleteSyncResult.isRight(),
          isTrue,
          reason: 'Delete sync orchestration failed',
        );

        // Allow time for async operations (API call, DB delete, file delete)
        _logger.d('$_tag Waiting for delete sync operations...');
        await Future.delayed(const Duration(seconds: 2));

        // Assert: Verify job is gone from local DB
        _logger.i('$_tag Verifying job is removed from local DB...');
        // Expect CacheException when trying to get deleted job
        expect(
          () async => await localDataSource.getJobById(localId),
          throwsA(isA<CacheException>()),
          reason:
              'Getting job by ID should throw CacheException after delete sync',
        );

        // Assert: Verify file system delete was called
        _logger.i('$_tag Verifying file deletion...');
        verify(mockFileSystem.deleteFile(audioFilePath)).called(1);

        _logger.i('$_tag --- Test: Delete and Sync Job Complete ---');
      },
    );

    // Test Sync Failure (Network): Create -> Mock Network Error -> Sync -> Verify job remains pending
    test(
      'should not attempt sync and leave job pending when network is offline',
      () async {
        _logger.i('$_tag --- Test: Sync Failure - Network Offline ---');
        final jobRepository = sl<JobRepository>();
        final localDataSource = sl<JobLocalDataSource>();
        // NetworkInfo is already mocked in setupDI and accessible via sl
        final mockNetworkInfo = sl<NetworkInfo>() as MockNetworkInfo;
        // Get the mocked remote data source to verify no calls are made
        // REMOVED: No longer needed as we are not mocking the remote source here

        // Arrange: Create a job locally
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'network_fail_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for network fail');
        final audioFilePath = dummyAudioFile.path;
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
          userId: 'test-user-id-network-fail',
          audioFilePath: audioFilePath,
          text: 'Job created before network failure',
        );
        expect(
          createResult.isRight(),
          isTrue,
          reason: 'Local job creation failed',
        );
        final createdJob = createResult.getOrElse(
          () => throw Exception('Should have created job'),
        );
        final localId = createdJob.localId;
        _logger.d('$_tag Job created locally with localId: $localId');

        // Arrange: Mock network info to be offline
        _logger.d('$_tag Arranging: Mocking network offline...');
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        // Act: Trigger synchronization
        _logger.i('$_tag Acting: Triggering sync...');
        final syncResult = await jobRepository.syncPendingJobs();

        // Assert: Orchestration should return Right(None()) as it shouldn't attempt sync
        _logger.d('$_tag Verifying sync orchestration result...');
        expect(
          syncResult.isRight(), // Changed: Expect Right(None()) now
          isTrue,
          reason:
              'Sync should return Right(None()) when offline, indicating no attempt was needed.',
        );
        _logger.d('$_tag Sync orchestration correctly returned Right(None()).');

        // Assert: Verify job state remains pending in local DB
        _logger.i('$_tag Verifying job state remains pending...');
        final jobFromDb = await localDataSource.getJobById(localId);
        expect(jobFromDb, isNotNull, reason: 'Job should still exist locally');
        expect(
          jobFromDb.syncStatus,
          SyncStatus.pending,
          reason: 'Job status should remain pending when offline',
        );
        expect(
          jobFromDb.serverId,
          isNull,
          reason: 'ServerId should remain null',
        );

        // Assert: Verify NO attempt was made to call the remote data source
        _logger.i('$_tag Verifying no remote API calls were made...');
        // REMOVED: We are injecting the REAL remote data source now for E2E,
        // so we cannot verify mock calls directly. The assertions on the Job's
        // final state (pending, null serverId) implicitly verify this.

        // Cleanup: Delete the dummy audio file
        _logger.d('$_tag Cleaning up dummy audio file...');
        if (await dummyAudioFile.exists()) {
          await dummyAudioFile.delete();
        }
        expect(await dummyAudioFile.exists(), isFalse);
        _logger.i(
          '$_tag --- Test: Sync Failure - Network Offline Complete ---',
        );
      },
    );

    // TODO: Test Sync Failure (Server 5xx): Create -> Mock Server 5xx -> Sync -> Verify Error Status

    // TODO: Test Retry Logic: Create -> Fail Sync -> Verify Error -> Wait -> Sync -> Verify Success or Failed

    // TODO: Test Server-Side Deletion Detection: Create -> Sync -> Mock Job Gone -> Sync -> Verify Local Deletion

    // TODO: Test Reset Failed Job: Create -> Fail Sync -> Verify Failed -> Reset -> Verify Pending -> Sync -> Verify Synced

    // Remaining TODOs moved to job_sync_failure_e2e_test.dart
  });
}
