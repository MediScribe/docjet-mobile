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
import 'dart:async';

import 'watch_jobs_use_case_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late WatchJobsUseCase useCase;
  late MockJobRepository mockJobRepository;
  late StreamController<Either<Failure, List<Job>>> streamController;

  final tNow = DateTime.now();

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = WatchJobsUseCase(repository: mockJobRepository);
    streamController = StreamController<Either<Failure, List<Job>>>.broadcast();
  });

  tearDown(() {
    streamController.close();
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

  test('should emit updated job list when repository stream changes', () async {
    // Arrange
    final initialJobList = [
      Job(
        localId: '1',
        text: 'Job 1 Initial',
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: 'user1',
      ),
    ];
    final updatedJobList = [
      initialJobList[0].copyWith(
        text: 'Job 1 Updated',
        syncStatus: SyncStatus.pending,
        updatedAt: tNow.add(const Duration(seconds: 10)),
      ),
      Job(
        localId: '2',
        text: 'Job 2 New',
        status: JobStatus.transcribing,
        syncStatus: SyncStatus.pending,
        createdAt: tNow.add(const Duration(seconds: 5)),
        updatedAt: tNow.add(const Duration(seconds: 5)),
        userId: 'user1',
      ),
    ];

    // Mock the repository to return the controlled stream
    when(
      mockJobRepository.watchJobs(),
    ).thenAnswer((_) => streamController.stream);

    // Act
    final resultStream = useCase(NoParams());

    // Assert
    final expectation = expectLater(
      resultStream,
      emitsInOrder([
        Right<Failure, List<Job>>(initialJobList),
        Right<Failure, List<Job>>(updatedJobList),
      ]),
    );

    // Trigger the emissions by adding data to the controller
    streamController.add(Right(initialJobList));
    streamController.add(Right(updatedJobList));
    await streamController.close();

    // Await the expectation
    await expectation;

    // Verification
    verify(mockJobRepository.watchJobs()).called(1);
  });
}
