import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart'; // Assuming NoParams is here or needs creation
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart'; // Assuming Job entity exists and exports JobStatus
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import JobStatus
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'; // Import SyncStatus
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/get_jobs_use_case.dart'; // Will cause error initially
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import generated mock file
import 'get_jobs_use_case_test.mocks.dart';

// Generate mocks for JobRepository
@GenerateMocks([JobRepository])
void main() {
  late GetJobsUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = GetJobsUseCase(mockJobRepository);
  });

  // Dummy Job data for testing - Changed to final
  final tJob1 = Job(
    localId: 'uuid-1',
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
  // Dummy Job data for testing - Changed to final
  final tJob2 = Job(
    localId: 'uuid-2',
    serverId: null,
    userId: 'test-user-123',
    status: JobStatus.created,
    syncStatus: SyncStatus.pending,
    text: 'Test Job 2',
    audioFilePath: '/path/to/audio2.mp4',
    createdAt: DateTime.parse('2023-01-02T11:00:00Z'),
    updatedAt: DateTime.parse('2023-01-02T11:00:00Z'),
    retryCount: 0,
    lastSyncAttemptAt: null,
  );
  final tJobList = [tJob1, tJob2];

  test('should get list of jobs from the repository', () async {
    // Arrange
    // Define what the mock repository should return when getJobs is called
    when(mockJobRepository.getJobs()).thenAnswer((_) async => Right(tJobList));

    // Act
    // Execute the use case
    final result = await useCase(NoParams()); // Assuming NoParams exists

    // Assert
    // Check if the result matches the expected list
    expect(result, Right(tJobList));
    // Verify that the getJobs method was called exactly once
    verify(mockJobRepository.getJobs());
    // Ensure no other methods were called on the repository
    verifyNoMoreInteractions(mockJobRepository);
  });

  test('should return Failure when repository fails', () async {
    // Arrange
    const tFailure = ServerFailure(message: 'Failed to fetch jobs');
    when(
      mockJobRepository.getJobs(),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase(NoParams());

    // Assert
    expect(result, const Left(tFailure));
    verify(mockJobRepository.getJobs());
    verifyNoMoreInteractions(mockJobRepository);
  });
}
