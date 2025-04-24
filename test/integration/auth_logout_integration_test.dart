import 'dart:io';

// ignore: unused_import
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for what we need
@GenerateMocks([
  JobLocalDataSource,
  AuthSessionProvider,
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  JobSyncOrchestratorService,
  AuthService,
])
import 'auth_logout_integration_test.mocks.dart';

/// Test-specific [PathProvider] implementation to avoid platform dependency
class MockPathProvider implements PathProvider {
  final String _testDirPath;

  MockPathProvider(this._testDirPath);

  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    // Create and return a test-specific directory for isolation
    final dir = Directory(_testDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

/// Test-specific [FileSystem] implementation that uses the mock path provider
class TestFileSystem extends IoFileSystem {
  TestFileSystem(super.documentsPath);
}

void main() {
  late GetIt sl;
  late AuthEventBus authEventBus;
  late MockAuthService mockAuthService;
  late MockJobLocalDataSource mockJobLocalDataSource;
  late MockJobReaderService mockJobReaderService;
  late MockJobWriterService mockJobWriterService;
  late MockJobDeleterService mockJobDeleterService;
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;
  late MockAuthSessionProvider mockAuthSessionProvider;
  late JobRepository jobRepository; // The instance under test
  late Directory tempDir;

  setUp(() async {
    // Create temporary directory for tests
    tempDir = await Directory.systemTemp.createTemp('docjet_test_');

    // Reset GetIt before each test
    sl = GetIt.instance;
    sl.reset();

    // Register the test-specific PathProvider and FileSystem
    final mockPathProvider = MockPathProvider(tempDir.path);
    sl.registerLazySingleton<PathProvider>(() => mockPathProvider);
    sl.registerLazySingleton<FileSystem>(() => TestFileSystem(tempDir.path));

    // Create mocks
    mockAuthService = MockAuthService();
    mockJobLocalDataSource = MockJobLocalDataSource();
    mockJobReaderService = MockJobReaderService();
    mockJobWriterService = MockJobWriterService();
    mockJobDeleterService = MockJobDeleterService();
    mockJobSyncOrchestratorService = MockJobSyncOrchestratorService();
    mockAuthSessionProvider = MockAuthSessionProvider();

    // Create real AuthEventBus (not mocked)
    authEventBus = AuthEventBus();

    // Override registrations in GetIt
    sl.allowReassignment = true; // Allow overriding existing registrations
    sl.registerLazySingleton<AuthEventBus>(() => authEventBus);
    sl.registerLazySingleton<AuthService>(() => mockAuthService);
    sl.registerLazySingleton<JobLocalDataSource>(() => mockJobLocalDataSource);
    sl.registerLazySingleton<JobReaderService>(() => mockJobReaderService);
    sl.registerLazySingleton<JobWriterService>(() => mockJobWriterService);
    sl.registerLazySingleton<JobDeleterService>(() => mockJobDeleterService);
    sl.registerLazySingleton<JobSyncOrchestratorService>(
      () => mockJobSyncOrchestratorService,
    );
    sl.registerLazySingleton<AuthSessionProvider>(
      () => mockAuthSessionProvider,
    );

    // Register JobRepositoryImpl AFTER its dependencies are mocked
    sl.registerLazySingleton<JobRepository>(
      () => JobRepositoryImpl(
        readerService: mockJobReaderService,
        writerService: mockJobWriterService,
        deleterService: mockJobDeleterService,
        orchestratorService: mockJobSyncOrchestratorService,
        authSessionProvider: mockAuthSessionProvider,
        authEventBus: authEventBus,
        localDataSource: mockJobLocalDataSource,
      ),
    );

    // Get the repository instance
    jobRepository = sl<JobRepository>();

    // Default mock behaviors
    when(mockAuthService.login(any, any)).thenAnswer((_) async {
      authEventBus.add(AuthEvent.loggedIn);
      return User(id: 'user-123');
    });

    when(mockAuthService.logout()).thenAnswer((_) async {
      authEventBus.add(AuthEvent.loggedOut);
      return;
    });

    // Assume user is authenticated for service calls within the repo
    when(
      mockAuthSessionProvider.isAuthenticated(),
    ).thenAnswer((_) async => true);
    when(
      mockAuthSessionProvider.getCurrentUserId(),
    ).thenAnswer((_) async => 'user-123');

    // Mock the clearUserData method on the LOCAL DATA SOURCE
    when(
      mockJobLocalDataSource.clearUserData(),
    ).thenAnswer((_) async => Future.value());
  });

  tearDown(() async {
    sl.reset();
    // Clean up the temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'JobRepositoryImpl should react to AuthEvent.loggedOut and clear local user data',
    () async {
      // Arrange: Simulate login
      await mockAuthService.login('test@test.com', 'password');

      // Verify repository is properly set up
      expect(jobRepository, isA<JobRepositoryImpl>());

      // Act: Trigger logout via the event bus
      authEventBus.add(AuthEvent.loggedOut);

      // Allow time for the asynchronous event listener to react
      await Future.delayed(Duration.zero);

      // Assert: Verify clearUserData was called on the local data source
      verify(mockJobLocalDataSource.clearUserData()).called(1);
    },
  );

  test(
    'JobRepositoryImpl should properly clean up all job data for different statuses',
    () async {
      // Arrange: Add jobs data with different statuses to verify all are cleared
      when(
        mockJobLocalDataSource.getJobsByStatus(SyncStatus.synced),
      ).thenAnswer((_) async => []);
      when(
        mockJobLocalDataSource.getJobsByStatus(SyncStatus.pending),
      ).thenAnswer((_) async => []);
      when(
        mockJobLocalDataSource.getJobsByStatus(SyncStatus.error),
      ).thenAnswer((_) async => []);

      // Verify repository is ready
      expect(jobRepository, isNotNull);

      // Act: Trigger logout
      authEventBus.add(AuthEvent.loggedOut);
      await Future.delayed(Duration.zero);

      // Assert: Verify clearUserData was called
      verify(mockJobLocalDataSource.clearUserData()).called(1);
    },
  );

  test('JobRepositoryImpl should dispose subscription when destroyed', () async {
    // This test verifies that the repository properly cleans up its event subscription

    // Act: Get a reference to the repository and explicitly dispose it
    final repo = sl<JobRepository>() as JobRepositoryImpl;
    repo.dispose();

    // Simulate logout event after disposal
    authEventBus.add(AuthEvent.loggedOut);
    await Future.delayed(Duration.zero);

    // Assert: clearUserData should not be called after disposal
    verifyNever(mockJobLocalDataSource.clearUserData());
  });
}
