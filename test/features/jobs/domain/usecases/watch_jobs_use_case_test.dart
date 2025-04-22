import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

import 'watch_jobs_use_case_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late WatchJobsUseCase useCase;
  late MockJobRepository mockJobRepository;
  final tNow = DateTime.now();

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = WatchJobsUseCase(repository: mockJobRepository);
  });

  test('should call JobRepository.watchJobs and return its stream', () async {
    // Arrange
    final jobs = [
      Job(
        localId: '1',
        text: 'Job 1',
        status: JobStatus.transcribing,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: 'user1',
      ),
      Job(
        localId: '2',
        text: 'Job 2',
        status: JobStatus.completed,
        syncStatus: SyncStatus.pending,
        createdAt: tNow,
        updatedAt: tNow,
        userId: 'user1',
      ),
    ];
    final stream = Stream.value(Right<Failure, List<Job>>(jobs));
    when(mockJobRepository.watchJobs()).thenAnswer((_) => stream);

    // Act
    final resultStream = useCase(NoParams());

    // Assert
    expect(resultStream, isA<Stream<Either<Failure, List<Job>>>>());
    verify(mockJobRepository.watchJobs());
    verifyNoMoreInteractions(mockJobRepository);

    // Verify the stream emits the expected data
    await expectLater(resultStream, emits(Right<Failure, List<Job>>(jobs)));
  });
}
