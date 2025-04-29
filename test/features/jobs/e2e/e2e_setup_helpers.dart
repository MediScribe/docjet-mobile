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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';

// Import the new container
import 'e2e_dependency_container.dart';

// Generate mocks for NetworkInfo, AuthCredentialsProvider, and FileSystem
@GenerateMocks([
  NetworkInfo,
  AuthCredentialsProvider,
  AuthSessionProvider,
  FileSystem,
  ApiJobRemoteDataSourceImpl,
  JobLocalDataSource,
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  JobSyncOrchestratorService,
  AuthEventBus,
])
import 'e2e_setup_helpers.mocks.dart'; // Import the generated mocks for this file

// --- Constants ---
const String mockApiKey = 'test-api-key';
const String mockServerScriptRelativePath = 'mock_api_server/bin/server.dart';
const String testSuiteName = 'JobSyncE2eTest'; // Centralized test suite name

// --- Globals (Managed within setup/teardown) ---
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

/// Sets up dependencies explicitly without using GetIt.
///
/// Returns an [E2EDependencyContainer] with all instantiated mocks and services.
/// Requires the mock server port and the job box.
/// Optionally uses a mock for [JobRemoteDataSource] instead of the real one.
E2EDependencyContainer setupDependencies({
  required int mockServerPort,
  required Box<JobHiveModel> jobBox,
  bool registerMockDataSource = false, // Default to real implementation
}) {
  logger.i(
    '$tag Setting up Explicit Dependencies (Mock DS: $registerMockDataSource)...',
  );

  // --- Construct server domain ---
  final mockServerDomain = 'localhost:$mockServerPort';
  final baseUrl = ApiConfig.baseUrlFromDomain(mockServerDomain);
  logger.i('$tag Using mock server at $baseUrl');

  // --- Instantiate Mocks ---
  final mockNetworkInfo = MockNetworkInfo();
  when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

  final mockAuthCredentialsProvider = MockAuthCredentialsProvider();
  when(
    mockAuthCredentialsProvider.getApiKey(),
  ).thenAnswer((_) async => mockApiKey);
  when(
    mockAuthCredentialsProvider.getAccessToken(),
  ).thenAnswer((_) async => 'fake-test-token');

  final mockAuthSessionProvider = MockAuthSessionProvider();
  when(
    mockAuthSessionProvider.getCurrentUserId(),
  ).thenAnswer((_) async => 'test-user-id');
  when(mockAuthSessionProvider.isAuthenticated()).thenAnswer((_) async => true);

  final mockFileSystem = MockFileSystem();
  final mockApiJobRemoteDataSource = MockApiJobRemoteDataSourceImpl();
  final mockAuthEventBus = MockAuthEventBus(); // Instantiate the mock event bus

  // --- Instantiate Real External Dependencies ---
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
  const uuid = Uuid();
  final hive = Hive; // Use the static Hive class instance
  final authEventBus = AuthEventBus(); // Instantiate real event bus

  // --- Instantiate Data Sources ---
  final jobLocalDataSource = HiveJobLocalDataSourceImpl(hive: hive);

  final JobRemoteDataSource jobRemoteDataSource;
  if (registerMockDataSource) {
    logger.i('$tag Using MOCK JobRemoteDataSource');
    jobRemoteDataSource = mockApiJobRemoteDataSource; // Use the mock instance
  } else {
    logger.i('$tag Using REAL JobRemoteDataSource');
    jobRemoteDataSource = ApiJobRemoteDataSourceImpl(
      // Instantiate real one
      dio: dio,
      authCredentialsProvider: mockAuthCredentialsProvider, // Use mock provider
      authSessionProvider: mockAuthSessionProvider, // Use mock provider
      fileSystem: mockFileSystem, // Use mock FS for path resolution
    );
  }

  // --- Instantiate Services (using previously created instances) ---
  // Need JobDeleterService first for JobReaderService
  final jobDeleterService = JobDeleterService(
    localDataSource: jobLocalDataSource,
    fileSystem: mockFileSystem, // Use mock FS
  );

  final jobReaderService = JobReaderService(
    localDataSource: jobLocalDataSource,
    remoteDataSource: jobRemoteDataSource, // Use real or mock instance
    deleterService: jobDeleterService, // Use created service
    networkInfo: mockNetworkInfo, // Use mock network info
  );

  final jobWriterService = JobWriterService(
    localDataSource: jobLocalDataSource,
    uuid: uuid, // Use real Uuid
    authSessionProvider: mockAuthSessionProvider, // Use mock provider
  );

  final jobSyncProcessorService = JobSyncProcessorService(
    localDataSource: jobLocalDataSource,
    remoteDataSource: jobRemoteDataSource, // Use real or mock instance
    fileSystem: mockFileSystem, // Use mock FS
  );

  final jobSyncOrchestratorService = JobSyncOrchestratorService(
    localDataSource: jobLocalDataSource,
    networkInfo: mockNetworkInfo, // Use mock network info
    processorService: jobSyncProcessorService, // Use created service
    authEventBus: authEventBus, // Add the required authEventBus parameter
  );

  // --- Instantiate Repository ---
  final jobRepository = JobRepositoryImpl(
    readerService: jobReaderService,
    writerService: jobWriterService,
    deleterService: jobDeleterService,
    orchestratorService: jobSyncOrchestratorService,
    authSessionProvider: mockAuthSessionProvider, // Use mock provider
    localDataSource: jobLocalDataSource,
    authEventBus: authEventBus, // Use real event bus instance
  );

  logger.i('$tag Explicit Dependency setup complete.');

  // --- Return Container ---
  return E2EDependencyContainer(
    // Mocks
    mockNetworkInfo: mockNetworkInfo,
    mockAuthCredentialsProvider: mockAuthCredentialsProvider,
    mockAuthSessionProvider: mockAuthSessionProvider,
    mockFileSystem: mockFileSystem,
    mockApiJobRemoteDataSource: mockApiJobRemoteDataSource,
    mockAuthEventBus: mockAuthEventBus, // Pass mock event bus
    // Real Instances
    dio: dio,
    uuid: uuid,
    hive: hive,
    jobBox: jobBox,
    jobLocalDataSource: jobLocalDataSource,
    jobRemoteDataSource:
        jobRemoteDataSource, // Pass the chosen (real/mock) instance
    jobRepository: jobRepository,
    authEventBus: authEventBus, // Pass real event bus instance
  );
}

/// Resets mocks for a new test using the provided container.
void resetTestMocks(E2EDependencyContainer dependencies) {
  reset(dependencies.mockNetworkInfo);
  when(dependencies.mockNetworkInfo.isConnected).thenAnswer((_) async => true);

  reset(dependencies.mockAuthCredentialsProvider);
  when(
    dependencies.mockAuthCredentialsProvider.getApiKey(),
  ).thenAnswer((_) async => mockApiKey);
  when(
    dependencies.mockAuthCredentialsProvider.getAccessToken(),
  ).thenAnswer((_) async => 'fake-test-token');

  reset(dependencies.mockAuthSessionProvider);
  when(
    dependencies.mockAuthSessionProvider.getCurrentUserId(),
  ).thenAnswer((_) async => 'test-user-id');
  when(
    dependencies.mockAuthSessionProvider.isAuthenticated(),
  ).thenAnswer((_) async => true);

  reset(dependencies.mockFileSystem);

  // Reset the API data source mock if it was used
  // Note: We reset the specific mock instance held in the container
  reset(dependencies.mockApiJobRemoteDataSource);

  // Reset the AuthEventBus mock
  reset(dependencies.mockAuthEventBus);
}

// --- New Shared Setup/Teardown Functions ---

/// Combined setup for an E2E test suite.
///
/// Starts the mock server, initializes Hive, and sets up explicit dependencies.
/// Returns a record containing the server process, Hive temp dir, job box,
/// and the dependency container.
Future<(Process?, Directory, Box<JobHiveModel>, E2EDependencyContainer)>
setupE2ETestSuite({bool registerMockDataSource = false}) async {
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

  // --- Explicit Dependency Setup ---
  final dependencies = setupDependencies(
    // Call new function
    mockServerPort: mockServerPort,
    jobBox: jobBox,
    registerMockDataSource: registerMockDataSource,
  );

  logger.i('$tag --- Shared E2E Test Suite Setup Complete ---');
  // Return the container along with other handles
  return (mockServerProcess, tempDir, jobBox, dependencies);
}

/// Combined teardown for an E2E test suite.
///
/// Cleans up Hive and stops the mock server. DI teardown is no longer needed.
Future<void> teardownE2ETestSuite(
  Process? mockServerProcess,
  Directory tempDir,
  Box<JobHiveModel> jobBox,
  // E2EDependencyContainer dependencies, // Container might not be needed here
) async {
  logger.i('$tag --- Tearing Down Shared E2E Test Suite ---');
  // --- Hive Teardown ---
  await teardownHive(tempDir, jobBox);

  // --- Mock Server Teardown ---
  await stopMockServer(mockServerProcess);

  logger.i('$tag --- Shared E2E Test Suite Teardown Complete ---');
}
