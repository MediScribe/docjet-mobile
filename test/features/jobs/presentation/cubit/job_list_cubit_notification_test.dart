import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';

// Mockito generator
@GenerateMocks([DeleteJobUseCase, AppNotifierService])
import 'job_list_cubit_notification_test.mocks.dart';

void main() {
  late MockDeleteJobUseCase mockDeleteJobUseCase;
  late MockAppNotifierService mockAppNotifierService;

  const jobId = '42';

  setUp(() {
    mockDeleteJobUseCase = MockDeleteJobUseCase();
    mockAppNotifierService = MockAppNotifierService();
  });

  JobListCubit createCubit() {
    // We don't need other dependencies for these focused tests.
    return JobListCubit(
      watchJobsUseCase: _FakeWatchJobsUseCase(),
      mapper: _FakeMapper(),
      createJobUseCase: _FakeCreateJobUseCase(),
      deleteJobUseCase: mockDeleteJobUseCase,
      appNotifierService: mockAppNotifierService,
    );
  }

  group('deleteJob -> AppNotifierService.show', () {
    blocTest<JobListCubit, JobListState>(
      'calls show() with MessageType.error when use case fails',
      build: () {
        when(
          mockDeleteJobUseCase.call(any),
        ).thenAnswer((_) async => const Left(ServerFailure(message: 'boom')));
        return createCubit();
      },
      act: (cubit) async {
        await cubit.deleteJob(jobId);
      },
      verify: (_) {
        verify(
          mockAppNotifierService.show(
            message: argThat(
              startsWith('Failed to delete job'),
              named: 'message',
            ),
            type: MessageType.error,
            duration: anyNamed('duration'),
            id: anyNamed('id'),
          ),
        ).called(1);
      },
    );

    blocTest<JobListCubit, dynamic>(
      'does not call show() when use case succeeds',
      build: () {
        when(
          mockDeleteJobUseCase.call(any),
        ).thenAnswer((_) async => Right(unit));
        return createCubit();
      },
      act: (cubit) async {
        await cubit.deleteJob(jobId);
      },
      verify: (_) {
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
  });
}

// ---------------------- Fakes ----------------------
class _FakeWatchJobsUseCase extends Fake implements WatchJobsUseCase {
  @override
  Stream<Either<Failure, List<Job>>> call(NoParams params) {
    return const Stream.empty();
  }
}

class _FakeMapper extends Mock implements JobViewModelMapper {}

class _FakeCreateJobUseCase extends Mock implements CreateJobUseCase {}
