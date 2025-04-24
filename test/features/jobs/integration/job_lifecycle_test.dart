import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/core/error/failures.dart';
// REMOVE import 'package:docjet_mobile/core/platform/file_system.dart';
// import 'dart:io' show FileSystemException; // Not needed if mocking

// Import the services to mock them
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
// import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart'; // OLD
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'; // NEW
// Added this line
import 'dart:async'; // Import for StreamController

// Update GenerateMocks to mock the services
@GenerateMocks([
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  // JobSyncService, // OLD
  JobSyncOrchestratorService, // NEW
  AuthSessionProvider, // Add AuthSessionProvider
  AuthEventBus, // Add AuthEventBus
  JobLocalDataSource, // Add JobLocalDataSource
])
import 'job_lifecycle_test.mocks.dart';

// Add custom NetworkFailure for testing
class NetworkFailure extends Failure {
  @override
  String get message => 'Network connection failed'; // Provide a default message
}

void main() {
  late JobRepositoryImpl repository;
  // Declare mocks for the services
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  // late MockJobSyncService mockSyncService; // OLD
  late MockJobSyncOrchestratorService mockOrchestratorService; // NEW
  late MockAuthSessionProvider mockAuthSessionProvider;
  late MockAuthEventBus mockAuthEventBus; // Add mock for AuthEventBus
  late MockJobLocalDataSource
  mockLocalDataSource; // Add mock for JobLocalDataSource

  setUp(() {
    // Instantiate service mocks
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    // mockSyncService = MockJobSyncService(); // OLD
    mockOrchestratorService = MockJobSyncOrchestratorService(); // NEW
    mockAuthSessionProvider = MockAuthSessionProvider();
    mockAuthEventBus = MockAuthEventBus(); // Initialize mock AuthEventBus
    mockLocalDataSource =
        MockJobLocalDataSource(); // Initialize mock JobLocalDataSource

    // Setup mocks for AuthEventBus stream
    final controller = StreamController<AuthEvent>();
    when(mockAuthEventBus.stream).thenAnswer((_) => controller.stream);

    // Instantiate repository with mocked services
    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      orchestratorService: mockOrchestratorService,
      authSessionProvider: mockAuthSessionProvider,
      authEventBus: mockAuthEventBus, // Pass AuthEventBus
      localDataSource: mockLocalDataSource, // Pass JobLocalDataSource
    );

    // Add default mock for isAuthenticated for the whole group
    when(
      mockAuthSessionProvider.isAuthenticated(),
    ).thenAnswer((_) async => true); // Use thenAnswer and async
  });

  // Helper function to create a Job entity
  Job createJobEntity({
    required String localId,
    String? serverId,
    required String text,
    required String audioFilePath,
    required SyncStatus syncStatus,
    required DateTime createdAt,
    JobStatus status = JobStatus.created,
    String userId = 'test-user-id',
  }) {
    return Job(
      localId: localId,
      serverId: serverId,
      text: text,
      audioFilePath: audioFilePath,
      syncStatus: syncStatus,
      status: status,
      createdAt: createdAt,
      updatedAt: createdAt,
      userId: userId,
      displayTitle: '',
      displayText: '',
    );
  }

  // Split the test into individual test cases
  group('Repository integration tests', () {
    const audioPath = '/path/to/audio.mp3';
    const jobText = 'Test transcription';
    const updatedText = 'Updated transcription';
    const localId = 'local-uuid-1234';
    const serverId = 'server-id-5678';
    const userId = 'integration-test-user';
    final now = DateTime.now();

    // Common job entities
    final initialJob = createJobEntity(
      localId: localId,
      text: jobText,
      audioFilePath: audioPath,
      syncStatus: SyncStatus.pending,
      createdAt: now,
      userId: userId,
    );

    final syncedJob = initialJob.copyWith(
      serverId: serverId,
      syncStatus: SyncStatus.synced,
    );

    final updatedJobPending = syncedJob.copyWith(
      text: updatedText,
      syncStatus: SyncStatus.pending,
    );

    // Domain and data objects
    final JobUpdateDetails updateDetails = JobUpdateDetails(text: updatedText);
    final JobUpdateData updateData = JobUpdateData(text: updatedText);

    setUp(() {
      // Set up auth session provider for all tests
      when(
        mockAuthSessionProvider.getCurrentUserId(),
      ).thenAnswer((_) async => userId); // Use thenAnswer and async
    });

    test('should create job through repository', () async {
      // Arrange
      when(
        mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
      ).thenAnswer((_) async => Right(initialJob));

      // Act
      final result = await repository.createJob(
        audioFilePath: audioPath,
        text: jobText,
      );

      // Assert
      expect(result, Right(initialJob));
      verify(
        mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
      ).called(1);
    });

    test('should check authentication before creating job', () async {
      // Arrange
      when(
        mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
      ).thenAnswer(
        (_) async => Right(initialJob),
      ); // Assume writer service succeeds if called

      // Act
      await repository.createJob(audioFilePath: audioPath, text: jobText);

      // Assert
      // Verify isAuthenticated was checked first
      verify(mockAuthSessionProvider.isAuthenticated()).called(1);
      // Verify writer service was called *after* auth check (given the default setUp returns true)
      verify(
        mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
      ).called(1);
    });

    test('should return AuthFailure when not authenticated', () async {
      // Arrange
      // Override the default setUp for this specific test
      when(
        mockAuthSessionProvider.isAuthenticated(),
      ).thenAnswer((_) async => false);

      // Act
      final result = await repository.createJob(
        audioFilePath: audioPath,
        text: jobText,
      );

      // Assert
      expect(result, Left(AuthFailure()));
      // Verify the writer service was NOT called
      verifyNever(
        mockWriterService.createJob(
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
        ),
      );
    });

    test('should sync pending jobs through repository', () async {
      // Arrange
      when(
        mockOrchestratorService.syncPendingJobs(),
      ).thenAnswer((_) async => const Right(unit));

      // Act
      final result = await repository.syncPendingJobs();

      // Assert
      expect(result, const Right(unit));
      verify(mockOrchestratorService.syncPendingJobs()).called(1);
    });

    test('should update job through repository', () async {
      // Arrange
      when(
        mockWriterService.updateJob(localId: localId, updates: updateData),
      ).thenAnswer((_) async => Right(updatedJobPending));

      // Act
      final result = await repository.updateJob(
        localId: localId,
        updates: updateDetails,
      );

      // Assert
      expect(result, Right(updatedJobPending));
      verify(
        mockWriterService.updateJob(localId: localId, updates: updateData),
      ).called(1);
    });

    test('should delete job through repository', () async {
      // Arrange
      when(
        mockDeleterService.deleteJob(localId),
      ).thenAnswer((_) async => const Right(unit));

      // Act
      final result = await repository.deleteJob(localId);

      // Assert
      expect(result, const Right(unit));
      verify(mockDeleterService.deleteJob(localId)).called(1);
    });
  });
}

// REMOVED: Manual mock class definition
// class MockJobSyncProcessorService extends Mock
//     implements JobSyncProcessorService {}
