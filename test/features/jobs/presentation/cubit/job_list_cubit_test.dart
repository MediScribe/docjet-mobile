import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
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
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';

// Generate mocks (DeleteJobUseCase mocked manually below to avoid build_runner churn)
@GenerateMocks([
  WatchJobsUseCase,
  JobViewModelMapper,
  CreateJobUseCase,
  DeleteJobUseCase,
  AppNotifierService,
  SmartDeleteJobUseCase,
])
import 'job_list_cubit_test.mocks.dart';

// Remove the commented out manual mock class

void main() {
  late MockWatchJobsUseCase mockWatchJobsUseCase;
  late MockJobViewModelMapper mockJobViewModelMapper;
  late MockCreateJobUseCase mockCreateJobUseCase;
  late MockDeleteJobUseCase mockDeleteJobUseCase;
  late MockAppNotifierService mockAppNotifierService;
  late MockSmartDeleteJobUseCase mockSmartDeleteJobUseCase;
  JobListCubit? jobListCubit;
  late StreamController<Either<Failure, List<Job>>> streamController;

  // Sample timestamps
  final dateTime1 = DateTime(2023, 1, 15, 10, 30);
  final dateTime2 = DateTime(2023, 1, 17, 12, 45);
  final dateTime3 = DateTime(2023, 1, 10, 16, 20);

  const tServerFailure = ServerFailure(message: 'Server error');

  // Minimal domain entities
  final tJob1 = Job(
    localId: '1',
    status: JobStatus.created,
    syncStatus: SyncStatus.synced,
    createdAt: dateTime1,
    updatedAt: dateTime1,
    userId: 'user1',
  );

  final tJob2 = Job(
    localId: '2',
    status: JobStatus.created,
    syncStatus: SyncStatus.synced,
    createdAt: dateTime2,
    updatedAt: dateTime2,
    userId: 'user1',
  );

  final tJob3 = Job(
    localId: '3',
    status: JobStatus.created,
    syncStatus: SyncStatus.synced,
    createdAt: dateTime3,
    updatedAt: dateTime3,
    userId: 'user1',
  );

  // Corresponding view-models (using helper factory)
  final tViewModel1 = JobViewModel.forTest(
    localId: '1',
    title: 'Job 1',
    text: 'Sample text 1',
    displayDate: dateTime1,
  );

  final tViewModel2 = JobViewModel.forTest(
    localId: '2',
    title: 'Job 2',
    text: 'Sample text 2',
    displayDate: dateTime2,
  );

  final tViewModel3 = JobViewModel.forTest(
    localId: '3',
    title: 'Job 3',
    text: 'Sample text 3',
    displayDate: dateTime3,
  );

  setUp(() {
    mockWatchJobsUseCase = MockWatchJobsUseCase();
    mockJobViewModelMapper = MockJobViewModelMapper();
    mockCreateJobUseCase = MockCreateJobUseCase();
    mockDeleteJobUseCase = MockDeleteJobUseCase();
    mockAppNotifierService = MockAppNotifierService();
    mockSmartDeleteJobUseCase = MockSmartDeleteJobUseCase();
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
      deleteJobUseCase: mockDeleteJobUseCase,
      appNotifierService: mockAppNotifierService,
      smartDeleteJobUseCase: mockSmartDeleteJobUseCase,
    );
  }

  tearDown(() async {
    streamController.close();
    if (jobListCubit != null && jobListCubit!.isClosed == false) {
      await jobListCubit!.close();
    }
  });

  test('initial state should be JobListLoading', () async {
    jobListCubit = createCubit();
    // Assert: The state immediately after creation (and subscription start)
    expect(jobListCubit!.state, isA<JobListLoading>());
    verify(mockWatchJobsUseCase.call(NoParams())).called(1);
    await jobListCubit!.close(); // Clean up instance
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
      await jobListCubit!.close();

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

  group('deleteJob', () {
    blocTest<JobListCubit, JobListState>(
      'emits optimistic JobListLoaded without the job then nothing else on successful deletion',
      build: () {
        when(
          mockDeleteJobUseCase.call(any),
        ).thenAnswer((_) async => Right(unit));
        return createCubit();
      },
      act: (cubit) async {
        // Provide initial data with two jobs
        streamController.add(Right([tJob1, tJob2]));
        await Future.microtask(() {}); // allow cubit to process
        await cubit.deleteJob(tJob1.localId);
      },
      expect:
          () => [
            // Initial load with two jobs (sorted by date)
            isA<JobListLoaded>().having((s) => s.jobs, 'jobs', [
              tViewModel2, // newer date
              tViewModel1,
            ]),
            // Optimistic removal leaves only job2
            isA<JobListLoaded>().having((s) => s.jobs, 'jobs after delete', [
              tViewModel2,
            ]),
          ],
      verify: (_) {
        verify(
          mockDeleteJobUseCase.call(DeleteJobParams(localId: tJob1.localId)),
        ).called(1);
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

    blocTest<JobListCubit, JobListState>(
      'emits optimistic removal then rollback when deletion fails and shows error banner',
      build: () {
        const failure = ServerFailure(message: 'delete failed');
        when(
          mockDeleteJobUseCase.call(any),
        ).thenAnswer((_) async => const Left(failure));
        return createCubit();
      },
      act: (cubit) async {
        streamController.add(Right([tJob1, tJob2]));
        await Future.microtask(() {});
        await cubit.deleteJob(tJob1.localId);
      },
      expect:
          () => [
            isA<JobListLoaded>().having((s) => s.jobs, 'jobs', [
              tViewModel2,
              tViewModel1,
            ]),
            isA<JobListLoaded>().having((s) => s.jobs, 'jobs after delete', [
              tViewModel2,
            ]),
            // Rollback
            isA<JobListLoaded>().having((s) => s.jobs, 'jobs rollback', [
              tViewModel2,
              tViewModel1,
            ]),
          ],
      verify: (_) {
        verify(
          mockDeleteJobUseCase.call(DeleteJobParams(localId: tJob1.localId)),
        ).called(1);
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

    blocTest<JobListCubit, JobListState>(
      'does nothing when state is not JobListLoaded',
      build: () {
        when(
          mockDeleteJobUseCase.call(any),
        ).thenAnswer((_) async => Right(unit));
        return createCubit();
      },
      act: (cubit) async {
        // Note: do NOT emit initial jobs, cubit is still in loading state
        await cubit.deleteJob(tJob1.localId);
      },
      expect: () => [],
      verify: (_) {
        verify(
          mockDeleteJobUseCase.call(DeleteJobParams(localId: tJob1.localId)),
        ).called(1);
      },
    );
  });

  group('smartDeleteJob', () {
    const tLocalId = 'job-to-delete-smartly';
    final tParams = SmartDeleteJobParams(localId: tLocalId);
    const tUnknownFailure = UnknownFailure('Something went wrong');
    // Adjusted tAppMessage to match the actual message format from _showErrorBanner
    final tAppMessageFromCubit = AppMessage(
      message: 'Failed to delete job: Something went wrong',
      type: MessageType.error,
    );

    blocTest<JobListCubit, JobListState>(
      'when SmartDeleteJobUseCase returns Right(true) (immediate purge), it should log success and not emit new state',
      build: () {
        when(
          mockSmartDeleteJobUseCase.call(tParams),
        ).thenAnswer((_) async => const Right(true));
        return createCubit();
      },
      act: (cubit) => cubit.smartDeleteJob(tLocalId),
      expect: () => [], // No state emission expected as UI is optimistic
      verify: (_) {
        verify(mockSmartDeleteJobUseCase.call(tParams)).called(1);
        // Verify logging once LoggerService is integrated/mocked
        // Adjusted verifyNever for named arguments
        verifyNever(
          mockAppNotifierService.show(
            message: anyNamed('message'),
            type: anyNamed('type'),
          ),
        );
      },
    );

    blocTest<JobListCubit, JobListState>(
      'when SmartDeleteJobUseCase returns Right(false) (marked for deletion), it should log success and not emit new state',
      build: () {
        when(
          mockSmartDeleteJobUseCase.call(tParams),
        ).thenAnswer((_) async => const Right(false));
        return createCubit();
      },
      act: (cubit) => cubit.smartDeleteJob(tLocalId),
      expect: () => [], // No state emission expected
      verify: (_) {
        verify(mockSmartDeleteJobUseCase.call(tParams)).called(1);
        // Verify logging
        // Adjusted verifyNever for named arguments
        verifyNever(
          mockAppNotifierService.show(
            message: anyNamed('message'),
            type: anyNamed('type'),
          ),
        );
      },
    );

    blocTest<JobListCubit, JobListState>(
      'when SmartDeleteJobUseCase returns Left(Failure), it should call AppNotifierService.show() with error message',
      build: () {
        when(
          mockSmartDeleteJobUseCase.call(tParams),
        ).thenAnswer((_) async => const Left(tUnknownFailure));
        when(
          mockAppNotifierService.show(
            message: anyNamed('message'),
            type: anyNamed('type'),
          ),
        ).thenReturn(null);
        return createCubit();
      },
      act: (cubit) => cubit.smartDeleteJob(tLocalId),
      expect: () => [],
      verify: (_) {
        verify(mockSmartDeleteJobUseCase.call(tParams)).called(1);
        // Using tAppMessageFromCubit for verification
        verify(
          mockAppNotifierService.show(
            message: tAppMessageFromCubit.message,
            type: tAppMessageFromCubit.type,
          ),
        ).called(1);
      },
    );

    blocTest<JobListCubit, JobListState>(
      'when SmartDeleteJobUseCase throws an exception, it should call AppNotifierService.show() with error message',
      build: () {
        when(
          mockSmartDeleteJobUseCase.call(tParams),
        ).thenThrow(Exception('boom'));
        when(
          mockAppNotifierService.show(
            message: anyNamed('message'),
            type: anyNamed('type'),
          ),
        ).thenReturn(null);
        return createCubit();
      },
      act: (cubit) => cubit.smartDeleteJob(tLocalId),
      expect: () => [],
      verify: (_) {
        verify(mockSmartDeleteJobUseCase.call(tParams)).called(1);
        verify(
          mockAppNotifierService.show(
            message: argThat(
              contains('Failed to delete job'),
              named: 'message',
            ),
            type: MessageType.error,
          ),
        ).called(1);
      },
    );
  });
}
