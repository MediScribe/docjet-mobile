import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p; // Added path import
import 'package:uuid/uuid.dart';

// Generate mocks for NetworkInfo AND AuthCredentialsProvider
@GenerateMocks([NetworkInfo, AuthCredentialsProvider])
import 'job_sync_e2e_test.mocks.dart';

// Implement the CORRECT FileSystem interface
class MockFileSystem extends Mock implements FileSystem {}

// --- Test Globals ---
final sl = GetIt.instance;
final _logger = LoggerFactory.getLogger('JobSyncE2eTest');
final _tag = logTag('JobSyncE2eTest');
const String _mockApiKey = 'test-api-key'; // As per mock_api_server README
Process? _mockServerProcess;
late Directory _tempDir;
late Box<JobHiveModel> _jobBox;
late String _dynamicMockServerUrl; // Store the dynamic URL
late int _mockServerPort; // Store the dynamic port

// --- Server Management Helpers (Adapted from mock_api_server/test/test_helpers.dart) ---

// Path to server executable (relative to mock_api_server directory, accessed from project root)
const String _mockServerScriptRelativePath = 'mock_api_server/bin/server.dart';

// Helper to print logs with a consistent prefix
void _logHelper(String testSuite, String message) {
  // Use the existing logger
  _logger.d('[$testSuite Helper] $message');
}

/// Clears the specified port and starts the mock server.
///
/// Returns a record containing the started [Process] object and the assigned port number.
/// Requires the test suite name for logging.
Future<(Process?, int)> _startMockServer(String testSuiteName) async {
  _logHelper(testSuiteName, 'Starting mock server management...');

  // Find an available port
  int assignedPort = 0;
  try {
    final serverSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    assignedPort = serverSocket.port;
    await serverSocket.close(); // Close the socket immediately
    _logHelper(testSuiteName, 'Found available port: $assignedPort');
  } catch (e, stackTrace) {
    _logHelper(testSuiteName, 'Error finding available port: $e $stackTrace');
    rethrow; // Fail setup if we can't get a port
  }

  // Start the server
  _logHelper(testSuiteName, 'Starting mock server on port $assignedPort...');
  Process? process;
  try {
    // Determine working directory (should be project root where flutter test runs)
    String workingDir = Directory.current.path;
    // The script path is relative to the project root
    final serverScriptPath = p.join(workingDir, _mockServerScriptRelativePath);

    // Verify script exists before attempting to start
    if (!await File(serverScriptPath).exists()) {
      final errorMsg = 'Mock server script not found at: $serverScriptPath';
      _logHelper(testSuiteName, errorMsg);
      throw FileSystemException(errorMsg);
    }

    _logHelper(testSuiteName, 'Using script: $serverScriptPath in $workingDir');

    process = await Process.start(
      'dart', // Use system dart
      [serverScriptPath, '--port', assignedPort.toString()],
      // Working directory should be project root
      // workingDirectory: workingDir,
    );
    _logHelper(testSuiteName, 'Mock server started (PID: ${process.pid})');

    // Pipe server output to test logger
    process.stdout.transform(utf8.decoder).listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        _logHelper(testSuiteName, '[MockServer OUT] $trimmed');
      }
    });
    process.stderr.transform(utf8.decoder).listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        _logger.e('[$testSuiteName Helper] [MockServer ERR] $trimmed');
      }
    });

    _logHelper(
      testSuiteName,
      'Waiting 3 seconds for server...',
    ); // Reduced wait
    await Future.delayed(const Duration(seconds: 3));
    _logHelper(testSuiteName, 'Server should be ready.');
    return (process, assignedPort);
  } catch (e, stackTrace) {
    _logHelper(testSuiteName, 'Error starting mock server: $e $stackTrace');
    process?.kill();
    rethrow; // Propagate error to fail setup
  }
}

/// Stops the mock server process gracefully.
///
/// Requires the [Process] object and test suite name for logging.
Future<void> _stopMockServer(String testSuiteName, Process? process) async {
  if (process == null) {
    _logHelper(testSuiteName, 'No server process to stop.');
    return;
  }
  _logHelper(testSuiteName, 'Stopping mock server (PID: ${process.pid})...');
  final killed = process.kill(ProcessSignal.sigterm);
  if (!killed) {
    _logHelper(testSuiteName, 'SIGTERM failed, sending SIGKILL...');
    process.kill(ProcessSignal.sigkill);
  }
  // Add a timeout for exit code
  try {
    await process.exitCode.timeout(const Duration(seconds: 2));
    _logHelper(testSuiteName, 'Mock server process exited.');
  } on TimeoutException {
    _logHelper(
      testSuiteName,
      'Server did not exit after SIGTERM/SIGKILL, may be orphaned.',
    );
  }
}

/// Sets up Dependency Injection container
Future<void> _setupDI() async {
  _logger.i('$_tag Setting up Dependency Injection...');
  await sl.reset();

  // --- External Dependencies ---
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _dynamicMockServerUrl,
        headers: {
          'X-API-Key': _mockApiKey,
          'Authorization': 'Bearer fake-test-token', // Mock server accepts any
        },
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    // Optional: Add interceptors for logging, etc.
    // dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    return dio;
  });

  // Use generated mocks
  sl.registerLazySingleton<NetworkInfo>(() => MockNetworkInfo());
  when(sl<NetworkInfo>().isConnected).thenAnswer((_) async => true);
  sl.registerLazySingleton<AuthCredentialsProvider>(
    () => MockAuthCredentialsProvider(),
  );
  // Stub the mock provider to return dummy credentials
  when(
    sl<AuthCredentialsProvider>().getApiKey(),
  ).thenAnswer((_) async => _mockApiKey);
  when(
    sl<AuthCredentialsProvider>().getAccessToken(),
  ).thenAnswer((_) async => 'fake-test-token');

  sl.registerLazySingleton<Uuid>(() => const Uuid());
  // Register MockFileSystem for the CORRECT FileSystem type
  sl.registerLazySingleton<FileSystem>(() => MockFileSystem());
  sl.registerLazySingleton<HiveInterface>(() => Hive);

  // --- Data Sources ---
  sl.registerLazySingleton<JobLocalDataSource>(
    () => HiveJobLocalDataSourceImpl(hive: sl()),
  );
  // Provide required dependencies based on actual constructor
  sl.registerLazySingleton<JobRemoteDataSource>(
    () => ApiJobRemoteDataSourceImpl(
      dio: sl(),
      authCredentialsProvider: sl(),
      // We don't need a custom multipart creator for this test
    ),
  );

  // --- Mappers ---
  // JobMapper uses static methods, no need to register in GetIt
  // sl.registerLazySingleton<JobMapper>(() => JobMapper(uuidGenerator: sl()));

  // --- Services ---
  // Services should now resolve correctly if their dependencies are met
  sl.registerLazySingleton<JobReaderService>(
    () => JobReaderService(localDataSource: sl(), remoteDataSource: sl()),
  );
  sl.registerLazySingleton<JobWriterService>(
    () => JobWriterService(localDataSource: sl(), uuid: sl()),
  );
  // Ensure services get the registered FileSystem type (handled by GetIt)
  sl.registerLazySingleton<JobDeleterService>(
    () => JobDeleterService(localDataSource: sl(), fileSystem: sl()),
  );
  sl.registerLazySingleton<JobSyncProcessorService>(
    () => JobSyncProcessorService(
      localDataSource: sl(),
      remoteDataSource: sl(),
      fileSystem: sl(),
    ),
  );
  sl.registerLazySingleton<JobSyncOrchestratorService>(
    () => JobSyncOrchestratorService(
      localDataSource: sl(),
      processorService: sl<JobSyncProcessorService>(),
      networkInfo: sl(),
    ),
  );

  // --- Repository ---
  sl.registerLazySingleton<JobRepository>(
    () => JobRepositoryImpl(
      readerService: sl(),
      writerService: sl(),
      deleterService: sl(),
      orchestratorService: sl<JobSyncOrchestratorService>(),
    ),
  );

  sl.registerLazySingleton<Box<JobHiveModel>>(() => _jobBox);

  _logger.i('$_tag Dependency Injection setup complete.');
}

void main() {
  // Make sure testWidgets uses the right binding for network calls
  // TestWidgetsFlutterBinding.ensureInitialized(); // <-- DO NOT USE for network tests

  setUpAll(() async {
    // --- Logging Setup ---
    LoggerFactory.setLogLevel('JobSyncE2eTest', Level.debug);
    _logger.i('$_tag --- Starting E2E Test Suite --- GOGO');

    // --- Mock Server Setup ---
    _logger.i('$_tag Starting mock server...');
    final serverResult = await _startMockServer('JobSyncE2eTest');
    _mockServerProcess = serverResult.$1;
    _mockServerPort = serverResult.$2;
    if (_mockServerProcess == null) {
      throw Exception('Mock server process failed to start.');
    }
    _dynamicMockServerUrl = 'http://localhost:$_mockServerPort';
    _logger.i(
      '$_tag Mock server started on $_dynamicMockServerUrl (PID: ${_mockServerProcess?.pid})',
    );

    // --- Hive Setup ---
    _logger.i('$_tag Initializing Hive for testing...');
    // Use path_provider to get a temporary directory suitable for testing
    _tempDir = await Directory.systemTemp.createTemp('hive_e2e_test_');
    _logger.d('$_tag Hive temp directory: ${_tempDir.path}');
    Hive.init(_tempDir.path);

    // Register Adapters (Essential!)
    if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
      Hive.registerAdapter(JobHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(SyncStatusAdapter().typeId)) {
      Hive.registerAdapter(SyncStatusAdapter());
    }

    _jobBox = await Hive.openBox<JobHiveModel>('jobs');
    _logger.i('$_tag Hive initialized and jobBox opened.');

    // --- DI Setup (AFTER server URL is known) ---
    await _setupDI();
  });

  tearDownAll(() async {
    _logger.i('$_tag --- Tearing Down E2E Test Suite ---');
    // --- DI Teardown ---
    _logger.i('$_tag Resetting Dependency Injection container...');
    await sl.reset();
    _logger.i('$_tag DI container reset.');

    // --- Hive Teardown ---
    _logger.i('$_tag Closing Hive...');
    await _jobBox.compact(); // Optional cleanup
    await Hive.close();
    // Delete the temporary directory
    try {
      await _tempDir.delete(recursive: true);
      _logger.i('$_tag Hive temporary directory deleted.');
    } catch (e) {
      _logger.w('$_tag Error deleting Hive temp directory: $e');
    }

    // --- Mock Server Teardown ---
    await _stopMockServer('JobSyncE2eTest', _mockServerProcess);

    _logger.i('$_tag --- E2E Test Suite Teardown Complete ---');
  });

  setUp(() async {
    _logger.d('$_tag --- Setting up test ---');
    // Clear logs before each test
    LoggerFactory.clearLogs();
    // Clear the job box before each test to ensure isolation
    await _jobBox.clear();
    _logger.d('$_tag Job box cleared.');
    // Reset and re-stub mocks
    reset(sl<NetworkInfo>());
    when(sl<NetworkInfo>().isConnected).thenAnswer((_) async => true);
    reset(sl<AuthCredentialsProvider>());
    when(
      sl<AuthCredentialsProvider>().getApiKey(),
    ).thenAnswer((_) async => _mockApiKey);
    when(
      sl<AuthCredentialsProvider>().getAccessToken(),
    ).thenAnswer((_) async => 'fake-test-token');

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

    // TODO: Add actual MVT test case here
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
        final dummyAudioFile = File('${_tempDir.path}/$dummyAudioFileName');
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

    // TODO: Add tests for update sync
    // TODO: Add tests for delete sync
    // TODO: Add tests for sync failures (network error, server error)
    // TODO: Add tests for retry logic
    // TODO: Add tests for server-side deletion detection

    // TODO: Remember to run `flutter pub run build_runner build --delete-conflicting-outputs`
    //       to generate the *.mocks.dart file after fixing these linter errors.
  });
}
