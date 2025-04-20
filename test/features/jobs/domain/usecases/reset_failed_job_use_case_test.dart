import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/reset_failed_job_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_failed_job_use_case_test.mocks.dart';

@GenerateNiceMocks([MockSpec<JobRepository>()])
void main() {
  late ResetFailedJobUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = ResetFailedJobUseCase(mockJobRepository);
  });

  const tLocalId = 'failed-job-123';
  const tParams = ResetFailedJobParams(localId: tLocalId);

  test(
    'should call JobRepository.resetFailedJob with the correct localId',
    () async {
      // Arrange
      // We don't need to mock the return value specifically for verifying the call
      when(
        mockJobRepository.resetFailedJob(any),
      ).thenAnswer((_) async => const Right(unit));

      // Act
      await useCase(tParams);

      // Assert
      verify(mockJobRepository.resetFailedJob(tLocalId));
      verifyNoMoreInteractions(mockJobRepository);
    },
  );

  test('should return the result from the repository on success', () async {
    // Arrange
    when(
      mockJobRepository.resetFailedJob(any),
    ).thenAnswer((_) async => const Right(unit));

    // Act
    final result = await useCase(tParams);

    // Assert
    expect(result, const Right(unit));
  });

  // Add tests for failure cases if needed (e.g., repository returning Left)
  // test('should return Failure from the repository on failure', () async {
  //   // Arrange
  //   final tFailure = CacheFailure('Failed to reset');
  //   when(mockJobRepository.resetFailedJob(any))
  //       .thenAnswer((_) async => Left(tFailure));
  //
  //   // Act
  //   final result = await useCase(tParams);
  //
  //   // Assert
  //   expect(result, Left(tFailure));
  // });
}
