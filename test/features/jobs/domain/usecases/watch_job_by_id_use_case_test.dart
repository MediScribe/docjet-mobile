import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_job_by_id_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'dart:async';

import 'watch_job_by_id_use_case_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late WatchJobByIdUseCase useCase;
  late MockJobRepository mockJobRepository;
  late StreamController<Either<Failure, Job?>> streamController;

  final tNow = DateTime.now();
  const tLocalId = '1';

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = WatchJobByIdUseCase(repository: mockJobRepository);
    streamController = StreamController<Either<Failure, Job?>>.broadcast();
  });

  tearDown(() {
    streamController.close();
  });

  test(
    'should call JobRepository.watchJobById and return its stream',
    () async {
      // Arrange
      final job = Job(
        localId: tLocalId,
        text: 'Job 1',
        status: JobStatus.transcribing,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: 'user1',
      );
      final stream = Stream.value(Right<Failure, Job?>(job));
      when(mockJobRepository.watchJobById(tLocalId)).thenAnswer((_) => stream);

      // Act
      final resultStream = useCase(const WatchJobParams(localId: tLocalId));

      // Assert
      expect(resultStream, isA<Stream<Either<Failure, Job?>>>());
      verify(mockJobRepository.watchJobById(tLocalId));
      verifyNoMoreInteractions(mockJobRepository);

      // Verify the stream emits the expected data
      await expectLater(resultStream, emits(Right<Failure, Job?>(job)));
    },
  );

  test('should handle null job (deleted job case)', () async {
    // Arrange
    when(
      mockJobRepository.watchJobById(tLocalId),
    ).thenAnswer((_) => streamController.stream);

    // Act
    final resultStream = useCase(const WatchJobParams(localId: tLocalId));

    // Assert
    verify(mockJobRepository.watchJobById(tLocalId));

    // Set up expectation *before* adding data and closing
    final expectation = expectLater(
      resultStream,
      emits(const Right<Failure, Job?>(null)),
    );

    // Add null to controller and CLOSE the stream
    streamController.add(const Right(null));
    await streamController.close(); // Explicitly close the stream here

    // Await the expectation
    await expectation;
  });

  test('should emit updated job when repository stream changes', () async {
    // Arrange
    final initialJob = Job(
      localId: tLocalId,
      text: 'Initial Text',
      status: JobStatus.completed,
      syncStatus: SyncStatus.synced,
      createdAt: tNow,
      updatedAt: tNow,
      userId: 'user1',
    );
    final updatedJob = initialJob.copyWith(
      text: 'Updated Text',
      updatedAt: tNow.add(const Duration(minutes: 1)),
      syncStatus: SyncStatus.pending,
    );

    // Mock the repository to return the controlled stream
    when(
      mockJobRepository.watchJobById(tLocalId),
    ).thenAnswer((_) => streamController.stream);

    // Act
    final resultStream = useCase(const WatchJobParams(localId: tLocalId));

    // Assert
    // Set up expectation *before* adding data and closing
    final expectation = expectLater(
      resultStream,
      emitsInOrder([
        Right<Failure, Job?>(initialJob),
        Right<Failure, Job?>(updatedJob),
      ]),
    );

    // Trigger the emissions by adding data to the controller
    streamController.add(Right(initialJob));
    // No need for Future.delayed if we close immediately after adding all events
    streamController.add(Right(updatedJob));
    await streamController.close(); // Explicitly close the stream here

    // Await the expectation
    await expectation;

    // Verification
    verify(mockJobRepository.watchJobById(tLocalId)).called(1);
  });
}
