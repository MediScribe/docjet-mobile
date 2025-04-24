import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
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
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Generate mocks for NetworkInfo, AuthCredentialsProvider, and FileSystem
@GenerateMocks([
  NetworkInfo,
  AuthCredentialsProvider,
  AuthSessionProvider,
  FileSystem,
  ApiJobRemoteDataSourceImpl,
])
import 'e2e_setup_helpers.mocks.dart'; // Import the generated mocks for this file

// --- Constants ---
const String mockApiKey = 'test-api-key';
const String mockServerScriptRelativePath = 'mock_api_server/bin/server.dart';
const String testSuiteName = 'JobSyncE2eTest'; // Centralized test suite name

// --- Globals (Managed within setup/teardown) ---
final sl = GetIt.instance;
final logger = LoggerFactory.getLogger(testSuiteName);
final tag = logTag(testSuiteName);

// --- Helper Functions ---

// Helper to print logs with a consistent prefix
void logHelper(String message) {
  logger.d('[$testSuiteName Helper] $message');
}

/// Clears the specified port and starts the mock server.
///
/// Returns a record containing the started [Process] object and the assigned port number.
Future<(Process?, int)> startMockServer() async {
  logHelper('Starting mock server management...');

  // Find an available port
  int assignedPort = 0;
  try {
    final serverSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    assignedPort = serverSocket.port;
    await serverSocket.close(); // Close the socket immediately
    logHelper('Found available port: $assignedPort');
  } catch (e, stackTrace) {
    logHelper('Error finding available port: $e $stackTrace');
    rethrow; // Fail setup if we can't get a port
  }

  // Start the server
  logHelper('Starting mock server on port $assignedPort...');
  Process? process;
  try {
    // Determine working directory (should be project root where flutter test runs)
    final workingDir = Directory.current.path;
    // The script path is relative to the project root
    final serverScriptPath = p.join(workingDir, mockServerScriptRelativePath);

    // Verify script exists before attempting to start
    if (!await File(serverScriptPath).exists()) {
      final errorMsg = 'Mock server script not found at: $serverScriptPath';
      logHelper(errorMsg);
      throw FileSystemException(errorMsg);
    }

    logHelper('Using script: $serverScriptPath in $workingDir');

    process = await Process.start(
      'dart', // Use system dart
      [serverScriptPath, '--port', assignedPort.toString()],
    );
    logHelper('Mock server started (PID: ${process.pid})');

    // Pipe server output to test logger
    process.stdout.transform(utf8.decoder).listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        logHelper('[MockServer OUT] $trimmed');
      }
    });
    process.stderr.transform(utf8.decoder).listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        logger.e('[$testSuiteName Helper] [MockServer ERR] $trimmed');
      }
    });

    logHelper('Waiting 3 seconds for server...'); // Reduced wait
    await Future.delayed(const Duration(seconds: 3));
    logHelper('Server should be ready.');
    return (process, assignedPort);
  } catch (e, stackTrace) {
    logHelper('Error starting mock server: $e $stackTrace');
    process?.kill();
    rethrow; // Propagate error to fail setup
  }
}

/// Stops the mock server process gracefully.
Future<void> stopMockServer(Process? process) async {
  if (process == null) {
    logHelper('No server process to stop.');
    return;
  }
  logHelper('Stopping mock server (PID: ${process.pid})...');
  final killed = process.kill(ProcessSignal.sigterm);
  if (!killed) {
    logHelper('SIGTERM failed, sending SIGKILL...');
    process.kill(ProcessSignal.sigkill);
  }
  // Add a timeout for exit code
  try {
    await process.exitCode.timeout(const Duration(seconds: 2));
    logHelper('Mock server process exited.');
  } on TimeoutException {
    logHelper('Server did not exit after SIGTERM/SIGKILL, may be orphaned.');
  }
}

/// Initializes Hive for testing.
///
/// Returns a record containing the temporary [Directory] and the opened [Box].
Future<(Directory, Box<JobHiveModel>)> setupHive() async {
  logger.i('$tag Initializing Hive for testing...');
  final tempDir = await Directory.systemTemp.createTemp('hive_e2e_test_');
  logHelper('Hive temp directory: ${tempDir.path}');
  // Use init, not initFlutter, for Dart tests
  // await Hive.initFlutter(tempDir.path); // WRONG for Dart tests
  Hive.init(tempDir.path); // CORRECT for Dart tests

  // Register Adapters (Essential!)
  if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
    Hive.registerAdapter(JobHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(SyncStatusAdapter().typeId)) {
    Hive.registerAdapter(SyncStatusAdapter());
  }

  final jobBox = await Hive.openBox<JobHiveModel>('jobs');
  logHelper('Hive initialized and jobBox opened.');
  return (tempDir, jobBox);
}

/// Cleans up Hive resources.
Future<void> teardownHive(Directory tempDir, Box<JobHiveModel> jobBox) async {
  logger.i('$tag Closing Hive...');
  if (jobBox.isOpen) {
    await jobBox.compact(); // Optional cleanup
    await jobBox.close();
  }
  await Hive.close(); // Close Hive itself
  // Delete the temporary directory
  try {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
      logHelper('Hive temporary directory deleted.');
    }
  } catch (e) {
    logger.w('$tag Error deleting Hive temp directory: $e');
  }
}

/// Sets up Dependency Injection container.
///
/// Requires the mock server URL and the job box.
/// Optionally registers a mock for [JobRemoteDataSource] instead of the real one.
Future<void> setupDI({
  required int mockServerPort,
  required Box<JobHiveModel> jobBox,
  bool registerMockDataSource = false, // Default to real implementation
}) async {
  logger.i(
    '$tag Setting up Dependency Injection (Mock DS: $registerMockDataSource)...',
  );
  await sl.reset();

  // --- Construct server domain ---
  final mockServerDomain = 'localhost:$mockServerPort';
  final baseUrl = ApiConfig.baseUrlFromDomain(mockServerDomain);
  logger.i('$tag Using mock server at $baseUrl');

  // --- External Dependencies ---
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'X-API-Key': mockApiKey,
          'Authorization': 'Bearer fake-test-token', // Mock server accepts any
        },
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    // dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    return dio;
  });

  // Use generated mocks
  sl.registerLazySingleton<NetworkInfo>(() => MockNetworkInfo());
  when(sl<NetworkInfo>().isConnected).thenAnswer((_) async => true);
  sl.registerLazySingleton<AuthCredentialsProvider>(
    () => MockAuthCredentialsProvider(),
  );
  when(
    sl<AuthCredentialsProvider>().getApiKey(),
  ).thenAnswer((_) async => mockApiKey);
  when(
    sl<AuthCredentialsProvider>().getAccessToken(),
  ).thenAnswer((_) async => 'fake-test-token');

  // Register AuthSessionProvider mock with consistently stubbed methods
  sl.registerLazySingleton<AuthSessionProvider>(
    () => MockAuthSessionProvider(),
  );
  // Configure the mock AuthSessionProvider with default test behaviors
  when(
    sl<AuthSessionProvider>().getCurrentUserId(),
  ).thenAnswer((_) async => 'test-user-id');
  when(
    sl<AuthSessionProvider>().isAuthenticated(),
  ).thenAnswer((_) async => true);

  sl.registerLazySingleton<Uuid>(() => const Uuid());
  sl.registerLazySingleton<FileSystem>(() => MockFileSystem());
  sl.registerLazySingleton<HiveInterface>(() => Hive);

  // Register the mock implementation with a specific name
  sl.registerLazySingleton<MockApiJobRemoteDataSourceImpl>(
    () => MockApiJobRemoteDataSourceImpl(),
    instanceName: 'mockDataSource',
  );
  // Register the real implementation with a specific name (optional, but good practice)
  sl.registerLazySingleton<ApiJobRemoteDataSourceImpl>(
    () => ApiJobRemoteDataSourceImpl(
      dio: sl(),
      authCredentialsProvider: sl(),
      authSessionProvider: sl(),
    ),
    instanceName: 'realDataSource',
  );

  // --- Data Sources ---
  sl.registerLazySingleton<JobLocalDataSource>(
    () => HiveJobLocalDataSourceImpl(hive: sl()),
  );

  // Conditionally register the default JobRemoteDataSource
  if (registerMockDataSource) {
    logger.i('$tag Registering MOCK JobRemoteDataSource');
    // Register the named mock as the default implementation for the interface
    sl.registerLazySingleton<JobRemoteDataSource>(
      () => sl<MockApiJobRemoteDataSourceImpl>(instanceName: 'mockDataSource'),
    );
  } else {
    logger.i('$tag Registering REAL JobRemoteDataSource');
    // Register the named real implementation as the default
    sl.registerLazySingleton<JobRemoteDataSource>(
      () => sl<ApiJobRemoteDataSourceImpl>(instanceName: 'realDataSource'),
    );
  }

  // --- Services ---
  sl.registerLazySingleton<JobReaderService>(
    () => JobReaderService(
      localDataSource: sl(),
      remoteDataSource: sl(),
      deleterService: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<JobWriterService>(
    () => JobWriterService(
      localDataSource: sl(),
      uuid: sl(),
      authSessionProvider: sl(),
    ),
  );
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
      networkInfo: sl(),
      processorService: sl(),
    ),
  );

  // --- Repository ---
  sl.registerLazySingleton<JobRepository>(
    () => JobRepositoryImpl(
      readerService: sl(),
      writerService: sl(),
      deleterService: sl(),
      orchestratorService: sl<JobSyncOrchestratorService>(),
      authSessionProvider: sl<AuthSessionProvider>(),
    ),
  );

  // Register the Hive Box instance
  sl.registerLazySingleton<Box<JobHiveModel>>(() => jobBox);

  logger.i('$tag Dependency Injection setup complete.');
}

/// Resets the Dependency Injection container.
Future<void> teardownDI() async {
  logger.i('$tag Resetting Dependency Injection container...');
  await sl.reset();
  logger.i('$tag DI container reset.');
}

/// Resets mocks for a new test.
void resetTestMocks() {
  if (sl.isRegistered<NetworkInfo>()) {
    reset(sl<NetworkInfo>());
    when(sl<NetworkInfo>().isConnected).thenAnswer((_) async => true);
  }
  if (sl.isRegistered<AuthCredentialsProvider>()) {
    reset(sl<AuthCredentialsProvider>());
    when(
      sl<AuthCredentialsProvider>().getApiKey(),
    ).thenAnswer((_) async => mockApiKey);
    when(
      sl<AuthCredentialsProvider>().getAccessToken(),
    ).thenAnswer((_) async => 'fake-test-token');
  }
  if (sl.isRegistered<AuthSessionProvider>()) {
    reset(sl<AuthSessionProvider>());
    when(
      sl<AuthSessionProvider>().getCurrentUserId(),
    ).thenAnswer((_) async => 'test-user-id');
    when(
      sl<AuthSessionProvider>().isAuthenticated(),
    ).thenAnswer((_) async => true);
  }
  if (sl.isRegistered<FileSystem>()) {
    reset(sl<FileSystem>());
  }
}

// --- New Shared Setup/Teardown Functions ---

/// Combined setup for an E2E test suite.
///
/// Starts the mock server, initializes Hive, and sets up DI.
/// Returns a record containing the necessary handles for teardown.
Future<(Process?, Directory, Box<JobHiveModel>)> setupE2ETestSuite({
  bool registerMockDataSource = false,
}) async {
  // --- Logging Setup ---
  LoggerFactory.setLogLevel(testSuiteName, Level.debug);
  logger.i('$tag --- Starting Shared E2E Test Suite Setup --- GOGO');

  // --- Mock Server Setup ---
  logger.i('$tag Starting mock server...');
  final serverResult = await startMockServer();
  final mockServerProcess = serverResult.$1;
  final mockServerPort = serverResult.$2;
  if (mockServerProcess == null) {
    throw Exception('Mock server process failed to start.');
  }

  // Use ApiConfig to get a formatted URL for logging
  final mockServerUrl = ApiConfig.baseUrlFromDomain(
    'localhost:$mockServerPort',
  );
  logger.i(
    '$tag Mock server started on $mockServerUrl (PID: ${mockServerProcess.pid})',
  );

  // --- Hive Setup ---
  final hiveResult = await setupHive();
  final tempDir = hiveResult.$1;
  final jobBox = hiveResult.$2;

  // --- DI Setup ---
  await setupDI(
    mockServerPort: mockServerPort,
    jobBox: jobBox,
    registerMockDataSource: registerMockDataSource,
  );

  logger.i('$tag --- Shared E2E Test Suite Setup Complete ---');
  return (mockServerProcess, tempDir, jobBox);
}

/// Combined teardown for an E2E test suite.
///
/// Tears down DI, cleans up Hive, and stops the mock server.
Future<void> teardownE2ETestSuite(
  Process? mockServerProcess,
  Directory tempDir,
  Box<JobHiveModel> jobBox,
) async {
  logger.i('$tag --- Tearing Down Shared E2E Test Suite ---');
  // --- DI Teardown ---
  await teardownDI();

  // --- Hive Teardown ---
  await teardownHive(tempDir, jobBox);

  // --- Mock Server Teardown ---
  await stopMockServer(mockServerProcess);

  logger.i('$tag --- Shared E2E Test Suite Teardown Complete ---');
}
