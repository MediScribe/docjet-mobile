import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/update_job_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'get_jobs_use_case_test.mocks.dart'; // Reuse mocks

void main() {
  late UpdateJobUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = UpdateJobUseCase(mockJobRepository);
  });

  const tLocalId = 'uuid-to-update';
  const tUpdateDetails = JobUpdateDetails(text: 'Updated text');

  // Expected result after successful update
  final tUpdatedJob = Job(
    localId: tLocalId,
    serverId: 'server-1', // Assuming it was synced before
    userId: 'test-user-123',
    status: JobStatus.completed, // Status might not change on text update
    syncStatus: SyncStatus.pending, // Should be marked pending after update
    text: 'Updated text',
    audioFilePath: '/path/to/audio1.mp4',
    createdAt: DateTime.parse('2023-01-01T10:00:00Z'),
    updatedAt: DateTime.now(), // Should be updated
    retryCount: 0,
    lastSyncAttemptAt: null,
  );

  final tParams = UpdateJobParams(localId: tLocalId, updates: tUpdateDetails);

  test(
    'should call repository to update job and return the updated job',
    () async {
      // Arrange
      when(
        mockJobRepository.updateJob(
          localId: anyNamed('localId'),
          updates: anyNamed('updates'),
        ),
      ).thenAnswer((_) async => Right(tUpdatedJob));

      // Act
      final result = await useCase(tParams);

      // Assert
      expect(result, Right(tUpdatedJob));
      verify(
        mockJobRepository.updateJob(localId: tLocalId, updates: tUpdateDetails),
      );
      verifyNoMoreInteractions(mockJobRepository);
    },
  );

  test('should return Failure when repository fails to update job', () async {
    // Arrange
    const tFailure = CacheFailure('Failed to update job locally');
    when(
      mockJobRepository.updateJob(
        localId: anyNamed('localId'),
        updates: anyNamed('updates'),
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase(tParams);

    // Assert
    expect(result, const Left(tFailure));
    verify(
      mockJobRepository.updateJob(localId: tLocalId, updates: tUpdateDetails),
    );
    verifyNoMoreInteractions(mockJobRepository);
  });
}
