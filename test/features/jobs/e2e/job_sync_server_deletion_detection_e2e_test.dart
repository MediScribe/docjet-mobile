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
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';

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
    final setupResult = await setupE2ETestSuite(registerMockDataSource: true);
    _mockServerProcess = setupResult.$1;
    _tempDir = setupResult.$2;
    _jobBox = setupResult.$3;
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

  group('Job Sync Server Deletion Detection E2E Tests', () {
    // ADJUSTED Group Name
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
      _logger.d(
        '$_tag Arranging: Creating job locally with pre-synced status...',
      );
      final dummyAudioFileName =
          'server_delete_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final dummyAudioFile = File(p.join(_tempDir.path, dummyAudioFileName));
      await dummyAudioFile.writeAsString('dummy audio for server delete');
      final audioFilePath = dummyAudioFile.path;
      final userId = 'test-user-id-server-delete';
      final initialText = 'Job to be deleted by server';
      expect(await dummyAudioFile.exists(), isTrue);

      // Create job with synced status and serverId to simulate a previously synced job
      final mockServerId = const Uuid().v4();
      final localId = const Uuid().v4();

      _logger.d(
        '$_tag Creating job with localId: $localId, serverId: $mockServerId, syncStatus: synced',
      );

      // Create a job entity with synced status and server ID
      await localDataSource.saveJob(
        Job(
          localId: localId,
          userId: userId,
          audioFilePath: audioFilePath,
          text: initialText,
          serverId: mockServerId,
          syncStatus: SyncStatus.synced,
          status: JobStatus.completed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          retryCount: 0,
          lastSyncAttemptAt: null,
        ),
      );

      // Verify the job is properly created in the synced state
      final jobFromDb = await localDataSource.getJobById(localId);
      expect(
        jobFromDb.syncStatus,
        SyncStatus.synced,
        reason: 'Job should be created with synced status',
      );
      expect(
        jobFromDb.serverId,
        mockServerId,
        reason: 'Job should have correct serverId',
      );
      expect(
        jobFromDb.audioFilePath,
        audioFilePath,
        reason: 'Job should have correct audioFilePath',
      );
      _logger.d('$_tag Verified job exists in database with synced status');

      // Mock all necessary remote data source calls
      _logger.d(
        '$_tag Mocking fetchJobs() to return empty list (simulating server-side deletion)',
      );
      when(mockRemoteDataSource.fetchJobs()).thenAnswer((_) async => []);

      // Mock file deletion to succeed
      _logger.d('$_tag Mocking deleteFile() to succeed');
      when(mockFileSystem.deleteFile(audioFilePath)).thenAnswer((_) async {});

      // Act: Call getJobs() which should trigger the server-side deletion check
      _logger.i(
        '$_tag Acting: Calling getJobs() to trigger server-side deletion detection',
      );
      final getJobsResult = await jobRepository.getJobs();

      // Allow time for deletion detection to complete
      await Future.delayed(const Duration(seconds: 2));

      // Assert: Verify the result of getJobs
      expect(
        getJobsResult.isRight(),
        isTrue,
        reason: 'getJobs should return Right',
      );
      expect(
        getJobsResult.getOrElse(() => []),
        isEmpty,
        reason: 'getJobs should return empty list',
      );

      // Verify fetchJobs was called
      verify(mockRemoteDataSource.fetchJobs()).called(1);

      // Assert: Verify job is GONE from local DB (asserting on exception)
      _logger.i('$_tag Verifying job is removed from local DB');
      await expectLater(
        () async => await localDataSource.getJobById(localId),
        throwsA(isA<CacheException>()),
        reason:
            'Job should be deleted locally after server-side deletion detection',
      );

      // Assert: Verify file system delete was called
      _logger.i('$_tag Verifying file deletion was called');
      verify(mockFileSystem.deleteFile(audioFilePath)).called(1);

      // Cleanup: Ensure dummy file is gone if needed
      _logger.d('$_tag Cleaning up dummy audio file if it still exists');
      if (await dummyAudioFile.exists()) {
        await dummyAudioFile.delete();
      }
      expect(await dummyAudioFile.exists(), isFalse);
      _logger.i('$_tag --- Test: Server-Side Deletion Detection Complete ---');
    });
  });
}
