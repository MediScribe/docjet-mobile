import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_repository_reconcile_test.mocks.dart';

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
  late JobRepositoryImpl repository;
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  late MockJobSyncOrchestratorService mockOrchestratorService;
  late MockAuthSessionProvider mockAuthSessionProvider;
  late MockAuthEventBus mockAuthEventBus;
  late MockJobLocalDataSource mockLocalDataSource;
  final Stream<AuthEvent> authStream = Stream<AuthEvent>.empty();

  setUp(() {
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    mockOrchestratorService = MockJobSyncOrchestratorService();
    mockAuthSessionProvider = MockAuthSessionProvider();
    mockAuthEventBus = MockAuthEventBus();
    mockLocalDataSource = MockJobLocalDataSource();

    // Mock the auth event stream
    when(mockAuthEventBus.stream).thenAnswer((_) => authStream);

    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      orchestratorService: mockOrchestratorService,
      authSessionProvider: mockAuthSessionProvider,
      authEventBus: mockAuthEventBus,
      localDataSource: mockLocalDataSource,
    );

    // Setup logging for tests
    LoggerFactory.clearLogs();
    LoggerFactory.setLogLevel(JobRepositoryImpl, Level.debug);
  });

  group('reconcileJobsWithServer', () {
    test(
      'should delegate to readerService.getJobs() and log success',
      () async {
        // Arrange
        final jobs = <Job>[];
        when(mockReaderService.getJobs()).thenAnswer((_) async => Right(jobs));

        // Act
        final result = await repository.reconcileJobsWithServer();

        // Assert
        verify(mockReaderService.getJobs()).called(1);
        expect(result, equals(const Right(unit)));
        expect(
          LoggerFactory.containsLog('Reconciling jobs with server'),
          isTrue,
        );
        expect(
          LoggerFactory.containsLog('Successfully reconciled jobs with server'),
          isTrue,
        );
      },
    );

    test(
      'should handle and log failures from readerService.getJobs()',
      () async {
        // Arrange
        final failure = ServerFailure();
        when(
          mockReaderService.getJobs(),
        ).thenAnswer((_) async => Left(failure));

        // Act
        final result = await repository.reconcileJobsWithServer();

        // Assert
        verify(mockReaderService.getJobs()).called(1);
        expect(result, equals(Left(failure)));
        expect(
          LoggerFactory.containsLog('Failed to reconcile jobs with server'),
          isTrue,
        );
      },
    );

    test('should handle exceptions and return failure', () async {
      // Arrange
      when(mockReaderService.getJobs()).thenThrow(Exception('Test exception'));

      // Act
      final result = await repository.reconcileJobsWithServer();

      // Assert
      verify(mockReaderService.getJobs()).called(1);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Expected Left(UnknownFailure)'),
      );
      expect(
        LoggerFactory.containsLog('Exception during jobs reconciliation'),
        isTrue,
      );
    });

    test('should handle ApiException and return ServerFailure', () async {
      // Arrange
      final apiException = ApiException(message: 'API error', statusCode: 500);
      when(mockReaderService.getJobs()).thenThrow(apiException);

      // Act
      final result = await repository.reconcileJobsWithServer();

      // Assert
      verify(mockReaderService.getJobs()).called(1);
      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<UnknownFailure>());
        expect(
          (failure as UnknownFailure).message,
          equals('Unexpected error during jobs reconciliation'),
        );
      }, (_) => fail('Expected Left(UnknownFailure)'));
      expect(
        LoggerFactory.containsLog('Exception during jobs reconciliation'),
        isTrue,
      );
    });
  });
}
