import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/smart_delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for the required classes
@GenerateMocks([CreateJobUseCase, AppNotifierService])
import 'job_list_cubit_create_job_test.mocks.dart';

void main() {
  late MockCreateJobUseCase mockCreateJobUseCase;
  late MockAppNotifierService mockAppNotifierService;

  setUp(() {
    mockCreateJobUseCase = MockCreateJobUseCase();
    mockAppNotifierService = MockAppNotifierService();
  });

  JobListCubit createCubit() {
    // Provide fakes for un-related dependencies
    return JobListCubit(
      watchJobsUseCase: _FakeWatchJobsUseCase(),
      mapper: _FakeMapper(),
      createJobUseCase: mockCreateJobUseCase,
      deleteJobUseCase: _FakeDeleteJobUseCase(),
      smartDeleteJobUseCase: _FakeSmartDeleteJobUseCase(),
      appNotifierService: mockAppNotifierService,
    );
  }

  const tParams = CreateJobParams(
    audioFilePath: '/tmp/audio.wav',
    text: 'hello',
  );

  // Minimal Job instance for the success path
  final tJob = Job(
    localId: '123',
    status: JobStatus.created,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    userId: 'user',
  );

  group('createJob -> AppNotifierService.show', () {
    blocTest<JobListCubit, dynamic>(
      'does not call show() on success',
      build: () {
        when(
          mockCreateJobUseCase.call(tParams),
        ).thenAnswer((_) async => Right(tJob));
        return createCubit();
      },
      act: (cubit) async {
        await cubit.createJob(tParams);
      },
      verify: (_) {
        verify(mockCreateJobUseCase.call(tParams)).called(1);
        verifyNever(
          mockAppNotifierService.show(
            message: anyNamed('message'),
            type: anyNamed('type'),
            duration: anyNamed('duration'),
            id: anyNamed('id'),
          ),
        );
      },
    );

    blocTest<JobListCubit, dynamic>(
      'calls show() with MessageType.error on failure',
      build: () {
        when(mockCreateJobUseCase.call(tParams)).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'create failed')),
        );
        return createCubit();
      },
      act: (cubit) async {
        await cubit.createJob(tParams);
      },
      verify: (_) {
        verify(mockCreateJobUseCase.call(tParams)).called(1);
        verify(
          mockAppNotifierService.show(
            message: argThat(
              startsWith('Failed to create job'),
              named: 'message',
            ),
            type: MessageType.error,
            duration: anyNamed('duration'),
            id: anyNamed('id'),
          ),
        ).called(1);
      },
    );
  });
}

// -------------------- Fakes --------------------
class _FakeWatchJobsUseCase extends Fake implements WatchJobsUseCase {
  @override
  Stream<Either<Failure, List<Job>>> call(NoParams params) {
    return const Stream.empty();
  }
}

class _FakeMapper extends Mock implements JobViewModelMapper {}

class _FakeDeleteJobUseCase extends Mock implements DeleteJobUseCase {}

class _FakeSmartDeleteJobUseCase extends Fake implements SmartDeleteJobUseCase {
  @override
  Future<Either<Failure, bool>> call(SmartDeleteJobParams params) async {
    // Default behavior, can be overridden if a test needs specific interaction
    return const Right(false);
  }
}
