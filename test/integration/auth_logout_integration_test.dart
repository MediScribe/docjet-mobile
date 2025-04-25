import 'dart:io';

// ignore: unused_import
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
// import 'package:docjet_mobile/core/platform/file_system.dart'; // REMOVE if not needed
// import 'package:docjet_mobile/core/platform/path_provider.dart'; // REMOVE if not needed
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
// Keep for type
import 'package:flutter_test/flutter_test.dart';
// import 'package:get_it/get_it.dart'; // REMOVE GetIt
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

// REMOVE Test PathProvider and FileSystem if not directly needed
// /// Test-specific [PathProvider] implementation to avoid platform dependency
// class MockPathProvider implements PathProvider {
//   // ... implementation ...
// }
//
// /// Test-specific [FileSystem] implementation that uses the mock path provider
// class TestFileSystem extends IoFileSystem {
//   TestFileSystem(super.documentsPath);
// }

void main() {
  // late GetIt sl; // REMOVE GetIt variable
  late AuthEventBus authEventBus;
  late MockAuthService mockAuthService;
  late MockJobLocalDataSource mockJobLocalDataSource;
  late MockJobReaderService mockJobReaderService;
  late MockJobWriterService mockJobWriterService;
  late MockJobDeleterService mockJobDeleterService;
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;
  late MockAuthSessionProvider mockAuthSessionProvider;
  late JobRepositoryImpl jobRepository; // Use concrete type for dispose()
  late Directory tempDir;

  setUp(() async {
    // Create temporary directory for tests
    tempDir = await Directory.systemTemp.createTemp('docjet_test_');

    // REMOVE GetIt setup
    // sl = GetIt.instance;
    // sl.reset();
    //
    // // Register the test-specific PathProvider and FileSystem
    // final mockPathProvider = MockPathProvider(tempDir.path);
    // sl.registerLazySingleton<PathProvider>(() => mockPathProvider);
    // sl.registerLazySingleton<FileSystem>(() => TestFileSystem(tempDir.path));

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

    // REMOVE GetIt registrations
    // sl.allowReassignment = true; // Allow overriding existing registrations
    // sl.registerLazySingleton<AuthEventBus>(() => authEventBus);
    // sl.registerLazySingleton<AuthService>(() => mockAuthService);
    // sl.registerLazySingleton<JobLocalDataSource>(() => mockJobLocalDataSource);
    // sl.registerLazySingleton<JobReaderService>(() => mockJobReaderService);
    // sl.registerLazySingleton<JobWriterService>(() => mockJobWriterService);
    // sl.registerLazySingleton<JobDeleterService>(() => mockJobDeleterService);
    // sl.registerLazySingleton<JobSyncOrchestratorService>(
    //   () => mockJobSyncOrchestratorService,
    // );
    // sl.registerLazySingleton<AuthSessionProvider>(
    //   () => mockAuthSessionProvider,
    // );
    // sl.registerLazySingleton<JobRepository>(
    //   () => JobRepositoryImpl(
    //     // ... dependencies ...
    //   ),
    // );

    // Instantiate JobRepositoryImpl directly with mocks/real instances
    jobRepository = JobRepositoryImpl(
      readerService: mockJobReaderService,
      writerService: mockJobWriterService,
      deleterService: mockJobDeleterService,
      orchestratorService: mockJobSyncOrchestratorService,
      authSessionProvider: mockAuthSessionProvider,
      authEventBus: authEventBus,
      localDataSource: mockJobLocalDataSource,
    );

    // REMOVE GetIt retrieval
    // jobRepository = sl<JobRepository>();

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
    // REMOVE GetIt reset
    // sl.reset();
    // Clean up the temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'JobRepositoryImpl should call clearUserData on JobLocalDataSource upon logout event',
    () async {
      // Arrange: No specific job data arrangement needed, as we only mock/verify
      // the call to clearUserData() on the local data source.

      // Verify repository is ready (using the setup variable)
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

    // Act: Use the repository instance created in setUp and explicitly dispose it
    // final repo = sl<JobRepository>() as JobRepositoryImpl; // REMOVE GetIt access
    jobRepository.dispose(); // Call dispose directly on the instance

    // Simulate logout event after disposal
    authEventBus.add(AuthEvent.loggedOut);
    await Future.delayed(Duration.zero);

    // Assert: clearUserData should not be called after disposal
    verifyNever(mockJobLocalDataSource.clearUserData());
  });
}
