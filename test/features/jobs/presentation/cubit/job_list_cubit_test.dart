import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

// Generate mocks
@GenerateMocks([WatchJobsUseCase, JobViewModelMapper, CreateJobUseCase])
import 'job_list_cubit_test.mocks.dart';

void main() {
  late MockWatchJobsUseCase mockWatchJobsUseCase;
  late MockJobViewModelMapper mockJobViewModelMapper;
  late MockCreateJobUseCase mockCreateJobUseCase;
  late JobListCubit jobListCubit;
  late StreamController<Either<Failure, List<Job>>> streamController;

  // Test data
  final tJobId1 = const Uuid().v4();
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
    title: 'Job 1 Title',
    text: 'Job 1 Text',
    syncStatus: SyncStatus.synced,
    hasFileIssue: false,
    displayDate: tJob1.updatedAt,
  );

  final tJobId2 = const Uuid().v4();
  final tJob2 = Job(
    localId: tJobId2,
    userId: 'user-1',
    status: JobStatus.transcribing,
    syncStatus: SyncStatus.pending,
    createdAt: DateTime(2023, 1, 3),
    updatedAt: DateTime(2023, 1, 4),
    text: 'Job 2 Text',
    failedAudioDeletionAttempts: 1,
  );
  final tViewModel2 = JobViewModel(
    localId: tJobId2,
    title: 'Job 2 Title',
    text: 'Job 2 Text',
    syncStatus: SyncStatus.pending,
    hasFileIssue: true,
    displayDate: tJob2.updatedAt,
  );

  // Create a job with an older date for sorting tests
  final tJobId3 = const Uuid().v4();
  final tJob3 = Job(
    localId: tJobId3,
    userId: 'user-1',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime(2022, 1, 1), // Older date
    updatedAt: DateTime(2022, 1, 2), // Older date
    text: 'Job 3 Text',
  );
  final tViewModel3 = JobViewModel(
    localId: tJobId3,
    title: 'Job 3 Title',
    text: 'Job 3 Text',
    syncStatus: SyncStatus.synced,
    hasFileIssue: false,
    displayDate: tJob3.updatedAt,
  );

  const tServerFailure = ServerFailure(message: 'Something went wrong');

  setUp(() {
    mockWatchJobsUseCase = MockWatchJobsUseCase();
    mockJobViewModelMapper = MockJobViewModelMapper();
    mockCreateJobUseCase = MockCreateJobUseCase();
    streamController = StreamController<Either<Failure, List<Job>>>.broadcast();

    // Default stub for use case stream
    when(
      mockWatchJobsUseCase.call(any),
    ).thenAnswer((_) => streamController.stream);

    // Stub mapper behavior (can be overridden in specific tests)
    when(mockJobViewModelMapper.toViewModel(tJob1)).thenReturn(tViewModel1);
    when(mockJobViewModelMapper.toViewModel(tJob2)).thenReturn(tViewModel2);
    when(mockJobViewModelMapper.toViewModel(tJob3)).thenReturn(tViewModel3);
  });

  // Helper to create the cubit AFTER setting up mocks for a specific test
  JobListCubit createCubit() {
    return JobListCubit(
      watchJobsUseCase: mockWatchJobsUseCase,
      mapper: mockJobViewModelMapper,
      createJobUseCase: mockCreateJobUseCase,
    );
  }

  tearDown(() {
    streamController.close();
  });

  test('initial state should be JobListInitial', () {
    jobListCubit = createCubit();
    // Assert: The state immediately after creation (and subscription start)
    expect(jobListCubit.state, isA<JobListLoading>());
    verify(mockWatchJobsUseCase.call(NoParams())).called(1);
    jobListCubit.close(); // Clean up instance created outside blocTest
  });

  group('WatchJobs Stream Handling', () {
    blocTest<JobListCubit, JobListState>(
      'emits [loading, loaded] when WatchJobsUseCase emits initial data',
      build: () => createCubit(),
      act: (cubit) => streamController.add(Right([tJob1])),
      // Expect initial loading state is skipped because blocTest starts after build
      expect:
          () => [
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              tViewModel1,
            ]),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        verify(mockJobViewModelMapper.toViewModel(tJob1));
      },
    );

    blocTest<JobListCubit, JobListState>(
      'emits [loading, loaded with empty list] when WatchJobsUseCase emits empty list',
      build: () => createCubit(),
      act: (cubit) => streamController.add(const Right([])),
      expect:
          () => [
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', []),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        verifyNever(mockJobViewModelMapper.toViewModel(any)); // No jobs to map
      },
    );

    blocTest<JobListCubit, JobListState>(
      'emits [loading, error] when WatchJobsUseCase emits failure',
      build: () => createCubit(),
      act: (cubit) => streamController.add(const Left(tServerFailure)),
      expect:
          () => [
            isA<JobListError>().having(
              (state) => (state).message,
              'message',
              tServerFailure.toString(),
            ),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        verifyNever(mockJobViewModelMapper.toViewModel(any));
      },
    );

    blocTest<JobListCubit, JobListState>(
      'emits [loading, loaded, loaded] for multiple data emissions',
      build: () => createCubit(),
      act: (cubit) {
        streamController.add(Right([tJob1]));
        streamController.add(Right([tJob1, tJob2])); // Add second job
        streamController.add(Right([tJob2])); // Remove first job
      },
      expect:
          () => [
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              tViewModel1,
            ]),
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              // Sort by displayDate: tJob2 (newer) comes before tJob1 (older)
              tViewModel2,
              tViewModel1,
            ]),
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              tViewModel2,
            ]),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        // Verify mapper calls for all emitted jobs
        verify(
          mockJobViewModelMapper.toViewModel(tJob1),
        ).called(2); // Called in first two emissions
        verify(
          mockJobViewModelMapper.toViewModel(tJob2),
        ).called(2); // Called in last two emissions
      },
    );

    blocTest<JobListCubit, JobListState>(
      'emits [loading, loaded, error, loaded] for data -> error -> data emissions',
      build: () => createCubit(),
      act: (cubit) {
        streamController.add(Right([tJob1]));
        streamController.add(const Left(tServerFailure));
        streamController.add(Right([tJob2])); // Recover with new data
      },
      expect:
          () => [
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              tViewModel1,
            ]),
            isA<JobListError>().having(
              (state) => (state).message,
              'message',
              tServerFailure.toString(),
            ),
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              tViewModel2,
            ]),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        verify(mockJobViewModelMapper.toViewModel(tJob1)).called(1);
        verify(mockJobViewModelMapper.toViewModel(tJob2)).called(1);
      },
    );

    blocTest<JobListCubit, JobListState>(
      'sorts jobs by displayDate in descending order (newest first)',
      build: () => createCubit(),
      act: (cubit) {
        // Add jobs in random order to ensure sorting is tested
        streamController.add(Right([tJob3, tJob1, tJob2]));
      },
      expect:
          () => [
            isA<JobListLoaded>().having(
              (state) => (state).jobs,
              'jobs sorted by date desc',
              // Expected order: tJob2 (newest), tJob1, tJob3 (oldest)
              [tViewModel2, tViewModel1, tViewModel3],
            ),
          ],
      verify: (_) {
        verify(mockWatchJobsUseCase.call(NoParams()));
        verify(mockJobViewModelMapper.toViewModel(tJob1));
        verify(mockJobViewModelMapper.toViewModel(tJob2));
        verify(mockJobViewModelMapper.toViewModel(tJob3));
      },
    );

    test('cancels stream subscription on close', () async {
      // Arrange
      jobListCubit = createCubit();
      // Verify subscription started
      verify(mockWatchJobsUseCase.call(NoParams())).called(1);

      // Act
      await jobListCubit.close();

      // Assert
      // Check if the stream controller's listener count dropped (indirect check)
      expect(streamController.hasListener, isFalse);
    });
  });

  group('refreshJobs', () {
    blocTest<JobListCubit, JobListState>(
      'emits [loading, loaded(initial), loading, loaded(refreshed)] when refreshJobs is called after initial load',
      // Build the cubit
      build: () => createCubit(),
      // Seed initial data immediately after build but before act
      seed: () {
        // Push initial data onto the stream
        streamController.add(Right([tJob1]));
        // Return the expected state AFTER the initial load completes
        // blocTest waits for this state before executing `act`.
        return JobListLoaded([tViewModel1]);
      },
      // Call refreshJobs and then provide new data
      act: (cubit) {
        // Kick off refresh and schedule mock data emission on next microtask
        final future = cubit.refreshJobs();
        Future.microtask(() => streamController.add(Right([tJob2])));
        return future;
      },
      // Expect the sequence: loading from refresh, loaded from refresh
      expect:
          () => [
            isA<JobListLoading>(),
            isA<JobListLoaded>().having((state) => (state).jobs, 'jobs', [
              tViewModel2,
            ]),
          ],
      verify: (_) {
        // Verify the use case was called by constructor AND the refresh call
        verify(
          mockWatchJobsUseCase.call(NoParams()),
        ).called(greaterThanOrEqualTo(2));
        // We rely on the `expect` block to verify the correct states (including mapped data) were emitted.
      },
    );
  });
}
