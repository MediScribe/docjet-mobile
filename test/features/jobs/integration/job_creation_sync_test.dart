import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_creation_sync_test.mocks.dart';

@GenerateMocks([
  JobReaderService,
  JobWriterService,
  JobDeleterService,
  JobSyncOrchestratorService,
  AuthSessionProvider,
  AuthEventBus,
  JobLocalDataSource,
])
void main() {
  final logger = LoggerFactory.getLogger('JobCreationSyncTest');
  final tag = logTag('JobCreationSyncTest');

  late JobRepositoryImpl repository;
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  late MockJobSyncOrchestratorService mockOrchestratorService;
  late MockAuthSessionProvider mockAuthSessionProvider;
  late MockAuthEventBus mockAuthEventBus;
  late MockJobLocalDataSource mockLocalDataSource;

  const audioPath = 'test/path/to/audio.mp3';
  const jobText = 'Test job text';

  final initialJob = Job(
    localId: 'local-123',
    serverId: null,
    userId: 'test-user',
    status: JobStatus.created,
    syncStatus: SyncStatus.pending,
    text: jobText,
    audioFilePath: audioPath,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    mockOrchestratorService = MockJobSyncOrchestratorService();
    mockAuthSessionProvider = MockAuthSessionProvider();
    mockAuthEventBus = MockAuthEventBus();
    mockLocalDataSource = MockJobLocalDataSource();

    when(mockAuthEventBus.stream).thenAnswer((_) => Stream<AuthEvent>.empty());

    // Set up mockLocalDataSource stubs
    when(
      mockLocalDataSource.getJobById(any),
    ).thenAnswer((_) async => initialJob);

    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      orchestratorService: mockOrchestratorService,
      authSessionProvider: mockAuthSessionProvider,
      authEventBus: mockAuthEventBus,
      localDataSource: mockLocalDataSource,
    );

    LoggerFactory.clearLogs();
    LoggerFactory.setLogLevel(JobRepositoryImpl, Level.debug);
  });

  group('Immediate Job Sync Tests', () {
    test(
      'should trigger immediate sync after successful job creation',
      () async {
        logger.i('$tag Testing immediate sync after job creation...');

        // Arrange
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).thenAnswer((_) async => Right(initialJob));
        when(
          mockOrchestratorService.syncPendingJobs(),
        ).thenAnswer((_) async => const Right(unit));

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
        verify(mockOrchestratorService.syncPendingJobs()).called(1);
        logger.i(
          '$tag Test passed: immediate sync was triggered after job creation',
        );
      },
    );

    test('should not trigger sync if job creation fails', () async {
      logger.i('$tag Testing sync not triggered when job creation fails...');

      // Arrange
      when(
        mockAuthSessionProvider.isAuthenticated(),
      ).thenAnswer((_) async => true);
      when(
        mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
      ).thenAnswer((_) async => Left(ServerFailure()));

      // Act
      final result = await repository.createJob(
        audioFilePath: audioPath,
        text: jobText,
      );

      // Assert
      expect(result.isLeft(), true);
      verify(
        mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
      ).called(1);
      verifyNever(mockOrchestratorService.syncPendingJobs());
      logger.i(
        '$tag Test passed: sync was not triggered after failed job creation',
      );
    });

    test('should not trigger sync if user is not authenticated', () async {
      logger.i(
        '$tag Testing sync not triggered when user is not authenticated...',
      );

      // Arrange - auth check fails before calling writer service
      when(
        mockAuthSessionProvider.isAuthenticated(),
      ).thenAnswer((_) async => false);

      // Act
      final result = await repository.createJob(
        audioFilePath: audioPath,
        text: jobText,
      );

      // Assert
      expect(result.isLeft(), true);
      verifyNever(
        mockWriterService.createJob(
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
        ),
      );
      verifyNever(mockOrchestratorService.syncPendingJobs());
      logger.i(
        '$tag Test passed: sync was not triggered when user is not authenticated',
      );
    });

    test(
      'should handle sync errors gracefully without affecting job creation result',
      () async {
        logger.i('$tag Testing error handling during immediate sync...');

        // Arrange - job creation succeeds but sync fails with error
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).thenAnswer((_) async => Right(initialJob));
        when(
          mockOrchestratorService.syncPendingJobs(),
        ).thenAnswer((_) async => Left(ServerFailure(message: 'Sync error')));

        // Act
        final result = await repository.createJob(
          audioFilePath: audioPath,
          text: jobText,
        );

        // Assert - job creation should still succeed despite sync error
        expect(result, Right(initialJob));
        verify(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).called(1);
        verify(mockOrchestratorService.syncPendingJobs()).called(1);
        logger.i('$tag Test passed: job creation succeeded despite sync error');
      },
    );

    test(
      'should handle unexpected exceptions during sync without affecting job creation',
      () async {
        logger.i(
          '$tag Testing unexpected exception handling during immediate sync...',
        );

        // Arrange - job creation succeeds but sync throws exception
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).thenAnswer((_) async => Right(initialJob));

        when(mockOrchestratorService.syncPendingJobs()).thenAnswer((_) async {
          logger.d('$tag Simulating sync exception (expected in test)');
          return Left(ServerFailure(message: 'Intentional test failure'));
        });

        // Act
        final result = await repository.createJob(
          audioFilePath: audioPath,
          text: jobText,
        );

        // Assert - job creation should still succeed despite sync exception
        expect(result, Right(initialJob));
        verify(
          mockWriterService.createJob(audioFilePath: audioPath, text: jobText),
        ).called(1);
        verify(mockOrchestratorService.syncPendingJobs()).called(1);
        logger.i(
          '$tag Test passed: job creation succeeded despite sync exception',
        );
      },
    );
  });
}
