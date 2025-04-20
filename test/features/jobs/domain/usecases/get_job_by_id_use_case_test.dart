import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/get_job_by_id_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Use existing mocks from get_jobs_use_case_test.mocks.dart
import 'get_jobs_use_case_test.mocks.dart';

void main() {
  late GetJobByIdUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = GetJobByIdUseCase(mockJobRepository);
  });

  const tLocalId = 'uuid-1';
  final tJob = Job(
    localId: tLocalId,
    serverId: 'server-1',
    userId: 'test-user-123',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced,
    text: 'Test Job 1',
    audioFilePath: '/path/to/audio1.mp4',
    createdAt: DateTime.parse('2023-01-01T10:00:00Z'),
    updatedAt: DateTime.parse('2023-01-01T10:00:00Z'),
    retryCount: 0,
    lastSyncAttemptAt: null,
  );

  test('should get job by id from the repository', () async {
    // Arrange
    when(mockJobRepository.getJobById(any)) // Use any() for the first pass
    .thenAnswer((_) async => Right(tJob));

    // Act
    final result = await useCase(const GetJobByIdParams(localId: tLocalId));

    // Assert
    expect(result, Right(tJob));
    verify(mockJobRepository.getJobById(tLocalId)); // Verify with specific id
    verifyNoMoreInteractions(mockJobRepository);
  });

  test('should return Failure when repository fails to find job', () async {
    // Arrange
    const tFailure = CacheFailure('Job not found');
    when(
      mockJobRepository.getJobById(any),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase(const GetJobByIdParams(localId: tLocalId));

    // Assert
    expect(result, const Left(tFailure));
    verify(mockJobRepository.getJobById(tLocalId));
    verifyNoMoreInteractions(mockJobRepository);
  });
}
