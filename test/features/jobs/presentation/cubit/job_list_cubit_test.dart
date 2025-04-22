import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/state/job_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

// Generate mocks
@GenerateMocks([WatchJobsUseCase, JobViewModelMapper])
import 'job_list_cubit_test.mocks.dart';

void main() {
  late MockWatchJobsUseCase mockWatchJobsUseCase;
  late MockJobViewModelMapper mockJobViewModelMapper;
  late JobListCubit jobListCubit;
  late StreamController<Either<Failure, List<Job>>> streamController;

  // Test data
  final tJobId1 = Uuid().v4();
  final tJob1 = Job(
    localId: tJobId1,
    userId: 'user-1',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime(2023, 1, 1),
    updatedAt: DateTime(2023, 1, 2),
    text: 'Job 1 Text',
  );
  final tViewModel1 = JobViewModel(
    localId: tJobId1,
    text: 'Job 1 Text',
    syncStatus: SyncStatus.synced,
    hasFileIssue: false,
    displayDate: tJob1.updatedAt,
  );

  setUp(() {
    mockWatchJobsUseCase = MockWatchJobsUseCase();
    mockJobViewModelMapper = MockJobViewModelMapper();
    streamController = StreamController<Either<Failure, List<Job>>>.broadcast();

    // Default stub for use case stream
    when(
      mockWatchJobsUseCase.call(any),
    ).thenAnswer((_) => streamController.stream);

    jobListCubit = JobListCubit(
      watchJobsUseCase: mockWatchJobsUseCase,
      mapper: mockJobViewModelMapper,
    );
  });

  tearDown(() {
    streamController.close();
    jobListCubit.close();
  });

  test('initial state should be JobListState.initial()', () {
    expect(jobListCubit.state, equals(JobListState.initial()));
  });

  group('loadJobs', () {
    blocTest<JobListCubit, JobListState>(
      'emits [loading, success] when WatchJobsUseCase returns data',
      setUp: () {
        // Arrange: Mock mapper behavior BEFORE the stream emits
        when(mockJobViewModelMapper.toViewModel(tJob1)).thenReturn(tViewModel1);
      },
      build: () => jobListCubit,
      act: (cubit) {
        // Act: Trigger the subscription and emit data
        cubit.loadJobs(); // Call the method that starts listening
        streamController.add(Right([tJob1]));
      },
      expect:
          () => <JobListState>[
            // Assert
            JobListState.initial().copyWith(isLoading: true),
            JobListState.initial().copyWith(
              isLoading: false,
              jobs: [tViewModel1],
            ),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        verify(mockJobViewModelMapper.toViewModel(tJob1));
        verifyNoMoreInteractions(mockWatchJobsUseCase);
        verifyNoMoreInteractions(mockJobViewModelMapper);
      },
    );

    blocTest<JobListCubit, JobListState>(
      'emits [loading, error] when WatchJobsUseCase returns failure',
      build: () => jobListCubit,
      act: (cubit) {
        // Act: Trigger the subscription and emit an error
        cubit.loadJobs();
        streamController.add(
          Left(ServerFailure(message: 'Something went wrong')),
        );
      },
      expect:
          () => <JobListState>[
            // Assert
            JobListState.initial().copyWith(isLoading: true),
            JobListState.initial().copyWith(
              isLoading: false,
              error: 'ServerFailure(Something went wrong, 0)',
            ),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        // Mapper should NOT be called on failure
        verifyNever(mockJobViewModelMapper.toViewModel(any));
        verifyNoMoreInteractions(mockWatchJobsUseCase);
        verifyNoMoreInteractions(mockJobViewModelMapper);
      },
    );

    // Add more tests: Multiple emissions, empty list, etc.
  });
}
