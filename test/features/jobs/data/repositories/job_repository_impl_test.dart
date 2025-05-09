import 'dart:async'; // Import for StreamController
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  JobSyncOrchestratorService,
  AuthSessionProvider,
  AuthEventBus,
  JobLocalDataSource,
])
import 'job_repository_impl_test.mocks.dart';

void main() {
  late JobRepositoryImpl repository;
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  late MockJobSyncOrchestratorService mockOrchestratorService;
  late MockAuthSessionProvider mockAuthSessionProvider;
  late MockAuthEventBus mockAuthEventBus;
  late MockJobLocalDataSource mockLocalDataSource;

  setUp(() {
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    mockOrchestratorService = MockJobSyncOrchestratorService();
    mockAuthSessionProvider = MockAuthSessionProvider();
    mockAuthEventBus = MockAuthEventBus();
    mockLocalDataSource = MockJobLocalDataSource();

    // Setup mocks for AuthEventBus stream
    final controller = StreamController<AuthEvent>();
    when(mockAuthEventBus.stream).thenAnswer((_) => controller.stream);

    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      orchestratorService: mockOrchestratorService,
      authSessionProvider: mockAuthSessionProvider,
      authEventBus: mockAuthEventBus,
      localDataSource: mockLocalDataSource,
    );
  });

  // --- Test Data ---
  const tLocalId = 'test-local-id';
  const tAudioPath = '/path/to/audio.mp3';
  const tText = 'Some text';
  const tUserId = 'user1';
  final tJob = Job(
    localId: tLocalId,
    userId: tUserId,
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  const tUpdateDetails = JobUpdateDetails(text: 'new text');
  const tExpectedUpdateData = JobUpdateData(text: 'new text');
  final tJobList = [tJob];

  // --- New Authentication Test Data ---
  final tAuthFailure = AuthFailure();

  // --- Tests ---

  group('constructor', () {
    test('should require AuthSessionProvider parameter', () {
      // This is implicitly tested by the setUp function
      // If AuthSessionProvider wasn't required, the test would fail at setup
      expect(repository, isNotNull);
    });
  });

  group('createJob', () {
    test(
      'should delegate to writer service when authenticated without fetching userId',
      () async {
        // Arrange
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        // DO NOT mock or expect getCurrentUserId here
        when(
          mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
        ).thenAnswer((_) async => Right(tJob));
        // Mock orchestrator's syncPendingJobs now that it's called after successful creation
        when(
          mockOrchestratorService.syncPendingJobs(),
        ).thenAnswer((_) async => const Right(unit));

        // Act
        final result = await repository.createJob(
          audioFilePath: tAudioPath,
          text: tText,
        );

        // Assert
        expect(result, equals(Right(tJob)));
        verify(mockAuthSessionProvider.isAuthenticated()).called(1);
        verifyNever(
          mockAuthSessionProvider.getCurrentUserId(),
        ); // Ensure repo DOES NOT call this
        verify(
          mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
        ).called(1); // Verify writer service is called (without userId)
        // Verify orchestrator is now called with the new implementation
        verify(mockOrchestratorService.syncPendingJobs()).called(1);

        verifyNoMoreInteractions(mockWriterService);
        verifyNoMoreInteractions(mockAuthSessionProvider);
        verifyNoMoreInteractions(mockOrchestratorService);
        verifyZeroInteractions(mockReaderService);
        verifyZeroInteractions(mockDeleterService);
      },
    );

    test(
      'should trigger orchestrator\'s syncPendingJobs and return job on successful local creation',
      () async {
        // Arrange
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
        ).thenAnswer((_) async => Right(tJob));
        // Mock the orchestrator to return success for the sync call
        when(
          mockOrchestratorService.syncPendingJobs(),
        ).thenAnswer((_) async => const Right(unit));

        // Act
        final result = await repository.createJob(
          audioFilePath: tAudioPath,
          text: tText,
        );

        // Assert
        // Result of createJob should still be the job from writer service
        expect(result, equals(Right(tJob)));
        // Verify essential calls
        verify(mockAuthSessionProvider.isAuthenticated()).called(1);
        verify(
          mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
        ).called(1);
        // CRITICAL: Verify orchestrator was called
        verify(mockOrchestratorService.syncPendingJobs()).called(1);

        // Ensure no unexpected interactions
        verifyNoMoreInteractions(mockAuthSessionProvider);
        verifyNoMoreInteractions(mockWriterService);
        verifyNoMoreInteractions(mockOrchestratorService);
        verifyZeroInteractions(mockReaderService);
        verifyZeroInteractions(mockDeleterService);
      },
    );

    test('does not trigger sync when writerService fails', () async {
      // Arrange
      when(
        mockAuthSessionProvider.isAuthenticated(),
      ).thenAnswer((_) async => true);
      when(
        mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
      ).thenAnswer((_) async => Left(CacheFailure()));
      // No stub for syncPendingJobs on purpose

      // Act
      final result = await repository.createJob(
        audioFilePath: tAudioPath,
        text: tText,
      );

      // Assert
      expect(result, equals(Left(CacheFailure())));
      verify(mockAuthSessionProvider.isAuthenticated()).called(1);
      verify(
        mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
      ).called(1);
      // CRITICAL: Verify orchestrator was NOT called
      verifyNever(mockOrchestratorService.syncPendingJobs());

      verifyNoMoreInteractions(mockAuthSessionProvider);
      verifyNoMoreInteractions(mockWriterService);
      verifyZeroInteractions(mockOrchestratorService);
      verifyZeroInteractions(mockReaderService);
      verifyZeroInteractions(mockDeleterService);
    });

    test(
      'should return AuthFailure and not call writer service when user is not authenticated',
      () async {
        // Arrange
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => false);

        // Act
        final result = await repository.createJob(
          audioFilePath: tAudioPath,
          text: tText,
        );

        // Assert
        expect(result, equals(Left(tAuthFailure)));
        verify(
          mockAuthSessionProvider.isAuthenticated(),
        ).called(1); // Check if auth status was checked
        verifyNever(
          mockAuthSessionProvider.getCurrentUserId(),
        ); // Should not try to get user ID if not authenticated
        verifyNever(
          mockWriterService.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
          ),
        ); // Writer service should not be called
        // Verify orchestrator sync was NEVER called
        verifyNever(mockOrchestratorService.syncPendingJobs());

        verifyNoMoreInteractions(mockAuthSessionProvider);
        verifyZeroInteractions(mockWriterService);
        verifyZeroInteractions(mockReaderService);
        verifyZeroInteractions(mockDeleterService);
        verifyZeroInteractions(mockOrchestratorService);
      },
    );
  });

  group('authentication', () {
    // Moved createJob auth tests into the 'createJob' group above.
    // Keeping this group structure in case other methods need auth tests later.
  });

  group('getJobs', () {
    test('should return jobs from reader service', () async {
      // Arrange
      when(
        mockReaderService.getJobs(),
      ).thenAnswer((_) async => Right(tJobList));

      // Act
      final result = await repository.getJobs();

      // Assert
      expect(result, equals(Right(tJobList)));
      verify(mockReaderService.getJobs()).called(1);
    });
  });

  group('getJobById', () {
    test('should call reader service with correct id', () async {
      // Arrange
      when(
        mockReaderService.getJobById(tLocalId),
      ).thenAnswer((_) async => Right(tJob));

      // Act
      final result = await repository.getJobById(tLocalId);

      // Assert
      expect(result, equals(Right(tJob)));
      verify(mockReaderService.getJobById(tLocalId)).called(1);
    });
  });

  group('updateJob', () {
    test('should delegate to writer service with correct parameters', () async {
      // Arrange
      when(
        mockWriterService.updateJob(
          localId: tLocalId,
          updates: tExpectedUpdateData,
        ),
      ).thenAnswer((_) async => Right(tJob));

      // Act
      final result = await repository.updateJob(
        localId: tLocalId,
        updates: tUpdateDetails,
      );

      // Assert
      expect(result, equals(Right(tJob)));
      verify(
        mockWriterService.updateJob(
          localId: tLocalId,
          updates: tExpectedUpdateData,
        ),
      ).called(1);
    });
  });

  group('deleteJob', () {
    test('should delegate to deleter service with correct id', () async {
      // Arrange
      when(
        mockDeleterService.deleteJob(tLocalId),
      ).thenAnswer((_) async => const Right(unit));

      // Act
      final result = await repository.deleteJob(tLocalId);

      // Assert
      expect(result, equals(const Right(unit)));
      verify(mockDeleterService.deleteJob(tLocalId)).called(1);
    });
  });

  group('syncPendingJobs', () {
    test('should delegate to orchestrator service', () async {
      // Arrange
      when(
        mockOrchestratorService.syncPendingJobs(),
      ).thenAnswer((_) async => const Right(unit));

      // Act
      final result = await repository.syncPendingJobs();

      // Assert
      expect(result, equals(const Right(unit)));
      verify(mockOrchestratorService.syncPendingJobs()).called(1);
    });
  });

  group('resetFailedJob', () {
    test(
      'should delegate to orchestrator service with correct parameters',
      () async {
        // Arrange
        when(
          mockOrchestratorService.resetFailedJob(localId: tLocalId),
        ).thenAnswer((_) async => const Right(unit));

        // Act
        final result = await repository.resetFailedJob(tLocalId);

        // Assert
        expect(result, equals(const Right(unit)));
        verify(
          mockOrchestratorService.resetFailedJob(localId: tLocalId),
        ).called(1);
      },
    );
  });

  group('watchJobs', () {
    test('should call reader service and return stream', () {
      // Arrange
      final mockStream = Stream<Either<Failure, List<Job>>>.fromIterable([
        Right(tJobList),
      ]);
      when(mockReaderService.watchJobs()).thenAnswer((_) => mockStream);

      // Act
      final result = repository.watchJobs();

      // Assert - test that the repository returns the stream from the reader service
      expect(result, equals(mockStream));
      verify(mockReaderService.watchJobs()).called(1);
    });
  });

  group('watchJobById', () {
    test('should call reader service with correct id and return stream', () {
      // Arrange
      final mockStream = Stream<Either<Failure, Job?>>.fromIterable([
        Right(tJob),
      ]);
      when(
        mockReaderService.watchJobById(tLocalId),
      ).thenAnswer((_) => mockStream);

      // Act
      final result = repository.watchJobById(tLocalId);

      // Assert
      expect(result, equals(mockStream));
      verify(mockReaderService.watchJobById(tLocalId)).called(1);
    });
  });

  group('smartDeleteJob', () {
    test(
      'should delegate to deleter service attemptSmartDelete with correct id',
      () async {
        // Arrange
        when(
          mockDeleterService.attemptSmartDelete(tLocalId),
        ).thenAnswer((_) async => const Right(true));

        // Act
        final result = await repository.smartDeleteJob(tLocalId);

        // Assert
        expect(result, equals(const Right(true)));
        verify(mockDeleterService.attemptSmartDelete(tLocalId)).called(1);
      },
    );

    test(
      'should pass through true flag when job is purged immediately',
      () async {
        // Arrange
        when(
          mockDeleterService.attemptSmartDelete(tLocalId),
        ).thenAnswer((_) async => const Right(true));

        // Act
        final result = await repository.smartDeleteJob(tLocalId);

        // Assert
        expect(result, equals(const Right(true)));
        verify(mockDeleterService.attemptSmartDelete(tLocalId)).called(1);
      },
    );

    test(
      'should pass through false flag when job is marked for standard deletion',
      () async {
        // Arrange
        when(
          mockDeleterService.attemptSmartDelete(tLocalId),
        ).thenAnswer((_) async => const Right(false));

        // Act
        final result = await repository.smartDeleteJob(tLocalId);

        // Assert
        expect(result, equals(const Right(false)));
        verify(mockDeleterService.attemptSmartDelete(tLocalId)).called(1);
      },
    );

    test('should pass through failures from deleter service', () async {
      // Arrange
      final tFailure = CacheFailure('Failed to find job');
      when(
        mockDeleterService.attemptSmartDelete(tLocalId),
      ).thenAnswer((_) async => Left(tFailure));

      // Act
      final result = await repository.smartDeleteJob(tLocalId);

      // Assert
      expect(result, equals(Left(tFailure)));
      verify(mockDeleterService.attemptSmartDelete(tLocalId)).called(1);
    });
  });
}
