import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
// import 'package:docjet_mobile/core/platform/file_system.dart'; // UNUSED
import 'package:docjet_mobile/core/utils/log_helpers.dart';
// import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'; // UNUSED
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
// import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart'; // UNUSED
// import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'; // UNUSED
// import 'package:docjet_mobile/features/jobs/domain/entities/job.dart'; // UNUSED
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
// import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart'; // UNUSED
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Import the setup helpers
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

// Remove duplicate mock generation
// @GenerateMocks([NetworkInfo, AuthCredentialsProvider, FileSystem])
// import 'job_sync_e2e_test.mocks.dart';

// REMOVE ALL HELPER FUNCTIONS (_logHelper, _startMockServer, _stopMockServer, _setupDI)
// ... existing code ...

void main() {
  // Note: TestWidgetsFlutterBinding.ensureInitialized() MUST NOT be used for network tests

  setUpAll(() async {
    // --- Shared Setup ---
    // Use the default (real remote data source)
    // final setupResult = await setupE2ETestSuite();
    // Ensure we get the MOCK remote data source for this test suite
    final setupResult = await setupE2ETestSuite(registerMockDataSource: true);
    _mockServerProcess = setupResult.$1;
    _tempDir = setupResult.$2;
    _jobBox = setupResult.$3;
    _dependencies = setupResult.$4; // Store the container
    // REMOVE all the individual setup steps (they are now inside setupE2ETestSuite)
  });

  tearDownAll(() async {
    // --- Shared Teardown ---
    await teardownE2ETestSuite(
      _mockServerProcess,
      _tempDir,
      _jobBox,
    ); // Call the shared teardown
    // REMOVE all individual teardown steps (they are now inside teardownE2ETestSuite)
  });

  setUp(() async {
    _logger.d('$_tag --- Setting up test ---');
    // Clear logs before each test
    LoggerFactory.clearLogs();
    // Clear the job box before each test to ensure isolation
    await _jobBox.clear();
    _logger.d('$_tag Job box cleared.');
    // Reset mocks using helper and container
    resetTestMocks(_dependencies); // Pass the container

    _logger.d('$_tag Test setup complete.');
  });

  tearDown(() {
    _logger.d('$_tag --- Tearing down test ---');
    // Any specific cleanup after each test can go here
  });

  group('Job Sync E2E Tests', () {
    test('Setup and Teardown Check', () {
      _logger.i('$_tag Running dummy test to verify setup...');
      // Check dependencies from the container
      expect(_dependencies.jobRepository, isNotNull);
      expect(_dependencies.jobBox.isOpen, isTrue);
      expect(_mockServerProcess, isNotNull);
      expect(_dependencies.mockFileSystem, isNotNull);
      _logger.i('$_tag Dummy test passed.');
    });

    // MVT: Create job locally, sync to mock server, verify status and serverId
    test(
      'should create a job locally and sync it successfully with the mock server',
      () async {
        _logger.i('$_tag --- Test: Create and Sync Job ---');
        // Get dependencies from container
        final jobRepository = _dependencies.jobRepository;
        final localDataSource = _dependencies.jobLocalDataSource;

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

        // Arrange: Stub the remote createJob call to succeed
        final mockServerId = const Uuid().v4();
        final mockRemoteDataSource =
            _dependencies.jobRemoteDataSource as MockApiJobRemoteDataSourceImpl;
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer(
          // Return the original job data but with synced status and serverId
          (_) async => createdJob.copyWith(
            serverId: mockServerId,
            syncStatus: SyncStatus.synced,
          ),
        );

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
        // Get dependencies from container
        final jobRepository = _dependencies.jobRepository;
        final localDataSource = _dependencies.jobLocalDataSource;

        // Arrange Part 1: Create and initial sync
        _logger.d('$_tag Arranging: Creating initial job...');
        final dummyAudioFileName =
            'update_test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        // Use _tempDir
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio content for update');
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
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

        // Arrange: Stub initial createJob call
        final mockRemoteDataSource =
            _dependencies.jobRemoteDataSource as MockApiJobRemoteDataSourceImpl;
        final initialServerId = const Uuid().v4();
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer(
          (_) async => createdJob.copyWith(
            serverId: initialServerId,
            syncStatus: SyncStatus.synced,
          ),
        );

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

        // Arrange: Stub updateJob call to succeed
        // Note: updateJob returns the updated Job
        when(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'), // Use jobId
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async {
          // Find the locally updated job to return it
          final updatedLocalJob = await localDataSource.getJobById(localId);
          // Simulate server returning the updated job marked as synced
          return updatedLocalJob.copyWith(syncStatus: SyncStatus.synced);
        });

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

    // Test Deletion Sync: Create -> Sync -> Delete -> Sync -> Verify Gone
    test(
      // Test name adjusted to reflect implementation
      'should delete a job locally, sync the deletion, and verify it is removed locally and file is deleted',
      () async {
        _logger.i('$_tag --- Test: Delete and Sync Job ---');

        // --- Explicit DI Setup for JobRepository is NO LONGER NEEDED ---
        // We get the real repository and necessary mocks from the container
        final jobRepository = _dependencies.jobRepository;
        final localDataSource = _dependencies.jobLocalDataSource;
        // Note: setupE2ETestSuite provides the REAL JobRepository, which uses
        // the MOCK FileSystem and MOCK RemoteDataSource (if specified in setup).
        // We need mocks for verification/stubbing within this test.
        final mockFileSystem = _dependencies.mockFileSystem;
        final mockRemoteDataSource =
            _dependencies.jobRemoteDataSource as MockApiJobRemoteDataSourceImpl;
        // We also need the mock local data source for direct verification/stubbing if needed
        // However, the test seems designed to work against the real Hive one mostly.
        // Let's keep using the real one from the container for now.

        // Arrange Part 1: Create and initial sync state using REAL localDataSource
        _logger.d('$_tag Arranging: Creating and syncing initial job...');
        final dummyAudioFileName =
            'delete_test_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio content for delete');
        final audioFilePath = dummyAudioFile.path;
        expect(await dummyAudioFile.exists(), isTrue);

        // Directly add a job to the REAL local data source (Hive box)
        final initialJob = JobHiveModel(
          localId: 'delete-local-id',
          serverId: 'server-id-for-delete', // Assume already synced
          userId: 'test-user-id', // Use default user id from helper
          audioFilePath: audioFilePath,
          text: 'Text for deletion job',
          status: JobStatus.submitted.index, // Use 'status' (assuming)
          syncStatus: SyncStatus.synced.index, // Use 'syncStatus' (assuming)
          createdAt: DateTime.now().toIso8601String(), // Convert to String
          updatedAt: DateTime.now().toIso8601String(), // Convert to String
          retryCount: 0,
        );
        await _dependencies.jobBox.put(initialJob.localId, initialJob);
        final localId = initialJob.localId;
        _logger.d('$_tag Job added directly to Hive box');

        // Verify state using REAL local data source
        final jobBeforeDelete = await localDataSource.getJobById(
          localId,
        ); // Uses real Hive impl
        expect(jobBeforeDelete, isNotNull);
        expect(jobBeforeDelete.syncStatus, SyncStatus.synced);
        expect(jobBeforeDelete.serverId, initialJob.serverId);
        _logger.d('$_tag Job state before delete verified.');

        // Arrange Part 2: Stub MOCK remote data source for deletion
        _logger.d('$_tag Arranging: Stubbing remote delete operation...');
        when(
          mockRemoteDataSource.deleteJob(initialJob.serverId!),
        ).thenAnswer((_) async => unit); // Return unit from dartz

        // Act: Delete the job locally (uses REAL repository)
        _logger.d('$_tag Acting: Deleting job locally...');
        final deleteResult = await jobRepository.deleteJob(localId);
        expect(deleteResult.isRight(), isTrue, reason: 'Local delete failed');

        // Assert: Verify state after local delete (using REAL local data source)
        final jobAfterLocalDelete = await localDataSource.getJobById(
          localId,
        ); // Uses real Hive impl
        expect(jobAfterLocalDelete, isNotNull);
        expect(
          jobAfterLocalDelete.syncStatus,
          SyncStatus.pendingDeletion,
          reason: 'Status should be pendingDeletion after local delete',
        );
        _logger.d(
          '$_tag Local delete successful, status set to pendingDeletion.',
        );

        // Act: Trigger sync to process the deletion (uses REAL repo)
        _logger.d('$_tag Acting: Triggering sync for deletion...');
        final deletionSyncResult = await jobRepository.syncPendingJobs();
        expect(
          deletionSyncResult.isRight(),
          isTrue,
          reason: 'Deletion sync failed',
        );
        await Future.delayed(const Duration(seconds: 1)); // Allow time

        // Assert: Verify job is gone from local data source by expecting an exception
        _logger.d('$_tag Verifying job removal from local storage...');
        expect(
          () async =>
              await localDataSource.getJobById(localId), // Uses real Hive impl
          throwsA(isA<CacheException>()),
          reason: 'Expected CacheException after deletion sync',
        );
        _logger.d(
          '$_tag Job successfully deleted and synced (verified by exception).',
        );

        // Assert: Verify remote delete was called (using MOCK remote source)
        verify(mockRemoteDataSource.deleteJob(initialJob.serverId!)).called(1);

        // Assert: Verify file system delete was called (using MOCK file system)
        _logger.i('$_tag Verifying file deletion...');
        verify(mockFileSystem.deleteFile(audioFilePath)).called(1);
        _logger.d('$_tag File deletion verified.');

        // Cleanup
        if (await dummyAudioFile.exists()) {
          // Check actual file
          await dummyAudioFile.delete();
        }
        _logger.i('$_tag --- Test: Delete and Sync Job Complete ---');
      },
    );

    // Test Sync Failure (Network): Create -> Mock Network Error -> Sync -> Verify job remains pending
    test(
      'should not attempt sync and leave job pending when network is offline',
      () async {
        _logger.i('$_tag --- Test: Sync Failure - Network Offline ---');

        // Get dependencies from container
        final jobRepository = _dependencies.jobRepository;
        final localDataSource =
            _dependencies.jobLocalDataSource; // Real Hive impl
        final mockNetworkInfo = _dependencies.mockNetworkInfo;
        final mockRemoteDataSource = _dependencies.mockApiJobRemoteDataSource;

        // Arrange: Create a job locally (using REAL repo -> REAL writer -> REAL local DS)
        _logger.d('$_tag Arranging: Creating job locally...');
        final dummyAudioFileName =
            'network_fail_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
        await dummyAudioFile.writeAsString('dummy audio for network fail');
        final audioFilePath = dummyAudioFile.path;
        expect(await dummyAudioFile.exists(), isTrue);

        final createResult = await jobRepository.createJob(
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

        // Arrange: Mock network info to be offline (using mock from container)
        _logger.d('$_tag Arranging: Mocking network offline...');
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        // Act: Trigger synchronization (using REAL repo)
        _logger.i('$_tag Acting: Triggering sync...');
        final syncResult = await jobRepository.syncPendingJobs();

        // Assert: Orchestration should return Right(unit) as it handles the offline case gracefully
        _logger.d('$_tag Verifying sync orchestration result...');
        expect(
          syncResult.isRight(),
          isTrue,
          reason:
              'Sync should return Right(unit) when offline, indicating no attempt needed.',
        );
        _logger.d('$_tag Sync orchestration correctly returned Right(unit).');

        // Assert: Verify job state remains pending in local DB (using REAL local DS)
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

        // Assert: Verify network check occurred (interaction with mock from container)
        verify(
          mockNetworkInfo.isConnected,
        ).called(greaterThan(0)); // Called by orchestrator

        // Assert: Verify remote methods were NOT called
        verifyNever(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        );
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'), // Use jobId instead of serverId
            updates: anyNamed('updates'),
          ),
        );
        verifyNever(mockRemoteDataSource.deleteJob(any));

        _logger.i(
          '$_tag Network offline check verified, remote calls avoided.',
        );

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
      timeout: const Timeout(Duration(minutes: 1)), // Increase timeout
    );

    // TODO: Test Sync Failure (Server 5xx): Create -> Mock Server 5xx -> Sync -> Verify Error Status

    // TODO: Test Retry Logic: Create -> Fail Sync -> Verify Error -> Wait -> Sync -> Verify Success or Failed

    // TODO: Test Server-Side Deletion Detection: Create -> Sync -> Mock Job Gone -> Sync -> Verify Local Deletion

    // TODO: Test Reset Failed Job: Create -> Fail Sync -> Verify Failed -> Reset -> Verify Pending -> Sync -> Verify Synced

    // Remaining TODOs moved to job_sync_failure_e2e_test.dart
  });
}
