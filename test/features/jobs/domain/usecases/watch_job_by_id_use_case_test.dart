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

import 'watch_job_by_id_use_case_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late WatchJobByIdUseCase useCase;
  late MockJobRepository mockJobRepository;
  final tNow = DateTime.now();
  final tLocalId = '1';

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = WatchJobByIdUseCase(repository: mockJobRepository);
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
      final resultStream = useCase(WatchJobParams(localId: tLocalId));

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
    final stream = Stream.value(Right<Failure, Job?>(null));
    when(mockJobRepository.watchJobById(tLocalId)).thenAnswer((_) => stream);

    // Act
    final resultStream = useCase(WatchJobParams(localId: tLocalId));

    // Assert
    verify(mockJobRepository.watchJobById(tLocalId));

    // Verify the stream emits null for a deleted job
    await expectLater(resultStream, emits(Right<Failure, Job?>(null)));
  });
}
