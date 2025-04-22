import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_job_by_id_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubits/job_detail_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_detail_cubit_test.mocks.dart';

// Generate mocks for dependencies
@GenerateMocks([WatchJobByIdUseCase])
void main() {
  late MockWatchJobByIdUseCase mockWatchJobByIdUseCase;
  const tJobId = 'test-job-id-123';
  const tUserId = 'test-user-id-abc'; // Added dummy userId
  final tWatchParams = WatchJobParams(localId: tJobId);

  setUp(() {
    mockWatchJobByIdUseCase = MockWatchJobByIdUseCase();
    // Cubit instantiation will be handled within blocTest build phase where needed
    // cubit = JobDetailCubit(watchJobByIdUseCase: mockWatchJobByIdUseCase, jobId: tJobId);
  });

  // tearDown(() {
  //   cubit.close(); // Cubit closing handled by blocTest automatically
  // });

  // Removed initial state test as blocTest covers it implicitly
  // test('initialState should be JobDetailLoading', () {
  //   // Need to instantiate cubit here if testing initial state directly
  // });

  group('watchJob', () {
    final tJob = Job(
      localId: tJobId,
      serverId: 'server-id-456',
      text: 'Test Job Text',
      audioFilePath: '/path/to/audio.aac',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      retryCount: 0,
      failedAudioDeletionAttempts: 0,
      userId: tUserId, // Added required userId
      status: JobStatus.completed, // Use JobStatus enum
    );
    final tJobStream = Stream.value(Right<Failure, Job?>(tJob));

    blocTest<JobDetailCubit, JobDetailState>(
      'should emit [JobDetailLoading, JobDetailLoaded] when job is found',
      build: () {
        when(mockWatchJobByIdUseCase.call(tWatchParams)) // Use params object
        .thenAnswer((_) => tJobStream);
        // Instantiate the cubit for the test
        return JobDetailCubit(
          watchJobByIdUseCase: mockWatchJobByIdUseCase,
          jobId: tJobId,
        );
      },
      // No act needed as cubit loads on init
      expect:
          () => [
            // Initial state is loading implicitly tested by blocTest start
            JobDetailLoaded(job: tJob),
          ],
      verify: (_) {
        verify(
          mockWatchJobByIdUseCase.call(tWatchParams),
        ).called(1); // Use params object
      },
    );

    final tNotFoundStream = Stream.value(Right<Failure, Job?>(null));

    blocTest<JobDetailCubit, JobDetailState>(
      'should emit [JobDetailLoading, JobDetailNotFound] when job is not found',
      build: () {
        when(mockWatchJobByIdUseCase.call(tWatchParams)) // Use params object
        .thenAnswer((_) => tNotFoundStream);
        return JobDetailCubit(
          watchJobByIdUseCase: mockWatchJobByIdUseCase,
          jobId: tJobId,
        );
      },
      expect: () => [const JobDetailNotFound()],
      verify: (_) {
        verify(
          mockWatchJobByIdUseCase.call(tWatchParams),
        ).called(1); // Use params object
      },
    );

    final tErrorStream = Stream.value(
      // Use a defined Failure type
      Left<Failure, Job?>(const CacheFailure('Database error')),
    );

    blocTest<JobDetailCubit, JobDetailState>(
      'should emit [JobDetailLoading, JobDetailError] when use case returns a Failure',
      build: () {
        when(mockWatchJobByIdUseCase.call(tWatchParams)) // Use params object
        .thenAnswer((_) => tErrorStream);
        return JobDetailCubit(
          watchJobByIdUseCase: mockWatchJobByIdUseCase,
          jobId: tJobId,
        );
      },
      expect: () => [const JobDetailError(message: 'Database error')],
      verify: (_) {
        verify(
          mockWatchJobByIdUseCase.call(tWatchParams),
        ).called(1); // Use params object
      },
    );

    // Test for stream updates
    blocTest<JobDetailCubit, JobDetailState>(
      'should emit new JobDetailLoaded states when the job stream updates',
      setUp: () {
        // Setup stream controller to push updates
        final controller = StreamController<Either<Failure, Job?>>();
        when(
          mockWatchJobByIdUseCase.call(tWatchParams),
        ).thenAnswer((_) => controller.stream);

        // Schedule stream events
        Future.microtask(() {
          controller.add(Right(tJob)); // Initial load
          controller.add(
            Right(tJob.copyWith(text: 'Updated Text')),
          ); // Update 1
          controller.add(
            Right(tJob.copyWith(syncStatus: SyncStatus.pending)),
          ); // Update 2
          controller.close();
        });
      },
      build:
          () => JobDetailCubit(
            watchJobByIdUseCase: mockWatchJobByIdUseCase,
            jobId: tJobId,
          ),
      expect:
          () => [
            JobDetailLoaded(job: tJob), // Initial state
            JobDetailLoaded(
              job: tJob.copyWith(text: 'Updated Text'),
            ), // Update 1
            JobDetailLoaded(
              job: tJob.copyWith(syncStatus: SyncStatus.pending),
            ), // Update 2
          ],
      verify: (_) {
        verify(mockWatchJobByIdUseCase.call(tWatchParams)).called(1);
      },
    );

    // Test for subscription cancellation
    test('should cancel stream subscription when closed', () async {
      // Arrange
      final controller = StreamController<Either<Failure, Job?>>();
      when(
        mockWatchJobByIdUseCase.call(tWatchParams),
      ).thenAnswer((_) => controller.stream);

      final cubit = JobDetailCubit(
        watchJobByIdUseCase: mockWatchJobByIdUseCase,
        jobId: tJobId,
      );

      // Ensure the stream is listened to initially
      await pumpEventQueue(); // Allow microtasks to complete (initial listen)
      expect(controller.hasListener, isTrue);

      // Act
      await cubit.close();

      // Assert
      expect(controller.hasListener, isFalse);
    });
  });
}
