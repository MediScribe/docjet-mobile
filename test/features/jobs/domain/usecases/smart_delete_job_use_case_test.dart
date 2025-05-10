import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/smart_delete_job_use_case.dart';

import 'smart_delete_job_use_case_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late SmartDeleteJobUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = SmartDeleteJobUseCase(repository: mockJobRepository);
  });

  const tLocalId = 'test_local_id';
  final tServerFailure = ServerFailure(message: 'Server Error');

  group('SmartDeleteJobUseCase.call', () {
    test(
      'should call JobRepository.smartDeleteJob and return Right(true) when repository indicates immediate purge',
      () async {
        // Arrange
        when(
          mockJobRepository.smartDeleteJob(tLocalId),
        ).thenAnswer((_) async => const Right(true));
        // Act
        final result = await useCase(
          const SmartDeleteJobParams(localId: tLocalId),
        );
        // Assert
        expect(result, const Right(true));
        verify(mockJobRepository.smartDeleteJob(tLocalId));
        verifyNoMoreInteractions(mockJobRepository);
      },
    );

    test(
      'should call JobRepository.smartDeleteJob and return Right(false) when repository indicates mark for deletion',
      () async {
        // Arrange
        when(
          mockJobRepository.smartDeleteJob(tLocalId),
        ).thenAnswer((_) async => const Right(false));
        // Act
        final result = await useCase(
          const SmartDeleteJobParams(localId: tLocalId),
        );
        // Assert
        expect(result, const Right(false));
        verify(mockJobRepository.smartDeleteJob(tLocalId));
        verifyNoMoreInteractions(mockJobRepository);
      },
    );

    test(
      'should propagate Left(failure) when JobRepository.smartDeleteJob fails',
      () async {
        // Arrange
        when(
          mockJobRepository.smartDeleteJob(tLocalId),
        ).thenAnswer((_) async => Left(tServerFailure));
        // Act
        final result = await useCase(
          const SmartDeleteJobParams(localId: tLocalId),
        );
        // Assert
        expect(result, Left(tServerFailure));
        verify(mockJobRepository.smartDeleteJob(tLocalId));
        verifyNoMoreInteractions(mockJobRepository);
      },
    );
  });
}
