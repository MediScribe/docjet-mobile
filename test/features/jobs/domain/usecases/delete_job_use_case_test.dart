import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart'; // Remove comment
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'get_jobs_use_case_test.mocks.dart'; // Reuse mocks

void main() {
  late DeleteJobUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = DeleteJobUseCase(mockJobRepository);
  });

  const tLocalId = 'uuid-to-delete';

  const tParams = DeleteJobParams(localId: tLocalId);

  test('should call repository to delete job (mark for deletion)', () async {
    // Arrange
    // Successful deletion returns Right(unit)
    when(
      mockJobRepository.deleteJob(any),
    ).thenAnswer((_) async => const Right(unit));

    // Act
    final result = await useCase(tParams);

    // Assert
    expect(result, const Right(unit));
    verify(mockJobRepository.deleteJob(tLocalId));
    verifyNoMoreInteractions(mockJobRepository);
  });

  test('should return Failure when repository fails to delete job', () async {
    // Arrange
    const tFailure = CacheFailure('Failed to mark job for deletion');
    when(
      mockJobRepository.deleteJob(any),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase(tParams);

    // Assert
    expect(result, const Left(tFailure));
    verify(mockJobRepository.deleteJob(tLocalId));
    verifyNoMoreInteractions(mockJobRepository);
  });
}
