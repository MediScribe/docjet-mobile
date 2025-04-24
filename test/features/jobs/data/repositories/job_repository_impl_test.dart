import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/error/failures.dart';
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
])
import 'job_repository_impl_test.mocks.dart';

void main() {
  late JobRepositoryImpl repository;
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  late MockJobSyncOrchestratorService mockOrchestratorService;
  late MockAuthSessionProvider mockAuthSessionProvider;

  setUp(() {
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    mockOrchestratorService = MockJobSyncOrchestratorService();
    mockAuthSessionProvider = MockAuthSessionProvider();
    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      orchestratorService: mockOrchestratorService,
      authSessionProvider: mockAuthSessionProvider,
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

  // --- Tests ---

  group('constructor', () {
    test('should require AuthSessionProvider parameter', () {
      // This is implicitly tested by the setUp function
      // If AuthSessionProvider wasn't required, the test would fail at setup
      expect(repository, isNotNull);
    });
  });

  group('createJob', () {
    test('should delegate to writer service with correct parameters', () async {
      // Arrange
      when(
        mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
      ).thenAnswer((_) async => Right(tJob));

      // Act
      final result = await repository.createJob(
        audioFilePath: tAudioPath,
        text: tText,
      );

      // Assert
      expect(result, equals(Right(tJob)));
      verify(
        mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
      ).called(1);
      verifyNoMoreInteractions(mockWriterService);
    });
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
}
