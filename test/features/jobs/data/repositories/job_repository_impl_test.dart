import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_repository_impl_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<JobReaderService>(),
  MockSpec<JobWriterService>(),
  MockSpec<JobDeleterService>(),
  MockSpec<JobSyncOrchestratorService>(),
])
void main() {
  late JobRepositoryImpl repository;
  late MockJobReaderService mockReaderService;
  late MockJobWriterService mockWriterService;
  late MockJobDeleterService mockDeleterService;
  late MockJobSyncOrchestratorService mockOrchestratorService;

  setUp(() {
    mockReaderService = MockJobReaderService();
    mockWriterService = MockJobWriterService();
    mockDeleterService = MockJobDeleterService();
    mockOrchestratorService = MockJobSyncOrchestratorService();
    repository = JobRepositoryImpl(
      readerService: mockReaderService,
      writerService: mockWriterService,
      deleterService: mockDeleterService,
      orchestratorService: mockOrchestratorService,
    );
  });

  // --- Test Data ---
  const tLocalId = 'test-local-id';
  const tAudioPath = '/path/to/audio.mp3';
  const tText = 'Some text';
  final tJob = Job(
    localId: tLocalId,
    userId: 'user1',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  const tUpdateData = JobUpdateData(text: 'Updated text');
  final tJobList = [tJob];

  // --- Tests ---

  group('JobRepositoryImpl Delegation Tests', () {
    test('should delegate getJobs to JobReaderService', () async {
      // Arrange
      when(
        mockReaderService.getJobs(),
      ).thenAnswer((_) async => Right(tJobList));
      // Act
      await repository.getJobs();
      // Assert
      verify(mockReaderService.getJobs()).called(1);
      verifyNoMoreInteractions(mockReaderService);
      verifyZeroInteractions(mockWriterService);
      verifyZeroInteractions(mockDeleterService);
      verifyZeroInteractions(mockOrchestratorService);
    });

    test('should delegate getJobById to JobReaderService', () async {
      // Arrange
      when(
        mockReaderService.getJobById(any),
      ).thenAnswer((_) async => Right(tJob));
      // Act
      await repository.getJobById(tLocalId);
      // Assert
      verify(mockReaderService.getJobById(tLocalId)).called(1);
      verifyNoMoreInteractions(mockReaderService);
      verifyZeroInteractions(mockWriterService);
      verifyZeroInteractions(mockDeleterService);
      verifyZeroInteractions(mockOrchestratorService);
    });

    test('should delegate createJob to JobWriterService', () async {
      // Arrange
      when(
        mockWriterService.createJob(
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async => Right(tJob));
      // Act
      await repository.createJob(audioFilePath: tAudioPath, text: tText);
      // Assert
      verify(
        mockWriterService.createJob(audioFilePath: tAudioPath, text: tText),
      ).called(1);
      verifyNoMoreInteractions(mockWriterService);
      verifyZeroInteractions(mockReaderService);
      verifyZeroInteractions(mockDeleterService);
      verifyZeroInteractions(mockOrchestratorService);
    });

    test('should delegate updateJob to JobWriterService', () async {
      // Arrange
      when(
        mockWriterService.updateJob(
          localId: anyNamed('localId'),
          updates: anyNamed('updates'),
        ),
      ).thenAnswer((_) async => Right(tJob));
      // Act
      await repository.updateJob(localId: tLocalId, updates: tUpdateData);
      // Assert
      verify(
        mockWriterService.updateJob(localId: tLocalId, updates: tUpdateData),
      ).called(1);
      verifyNoMoreInteractions(mockWriterService);
      verifyZeroInteractions(mockReaderService);
      verifyZeroInteractions(mockDeleterService);
      verifyZeroInteractions(mockOrchestratorService);
    });

    test('should delegate deleteJob to JobDeleterService', () async {
      // Arrange
      when(
        mockDeleterService.deleteJob(any),
      ).thenAnswer((_) async => const Right(unit));
      // Act
      await repository.deleteJob(tLocalId);
      // Assert
      verify(mockDeleterService.deleteJob(tLocalId)).called(1);
      verifyNoMoreInteractions(mockDeleterService);
      verifyZeroInteractions(mockReaderService);
      verifyZeroInteractions(mockWriterService);
      verifyZeroInteractions(mockOrchestratorService);
    });

    test(
      'should delegate syncPendingJobs to JobSyncOrchestratorService',
      () async {
        // Arrange
        when(
          mockOrchestratorService.syncPendingJobs(),
        ).thenAnswer((_) async => const Right(unit));
        // Act
        await repository.syncPendingJobs();
        // Assert
        verify(mockOrchestratorService.syncPendingJobs()).called(1);
        verifyNoMoreInteractions(mockOrchestratorService);
        verifyZeroInteractions(mockReaderService);
        verifyZeroInteractions(mockWriterService);
        verifyZeroInteractions(mockDeleterService);
      },
    );
  });
}
