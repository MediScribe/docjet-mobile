import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'get_jobs_use_case_test.mocks.dart'; // Reuse mocks

void main() {
  late CreateJobUseCase useCase;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    useCase = CreateJobUseCase(mockJobRepository);
  });

  const tAudioFilePath = '/path/to/new_audio.mp4';
  const tText = 'This is the transcript text.';
  const tUserId = 'test-user-123';

  // Expected result after successful creation (example)
  final tCreatedJob = Job(
    localId: 'new-uuid-generated-by-repo',
    serverId: null,
    userId: tUserId,
    status: JobStatus.created,
    syncStatus: SyncStatus.pending,
    text: tText,
    audioFilePath: tAudioFilePath,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    retryCount: 0,
    lastSyncAttemptAt: null,
  );

  final tParams = CreateJobParams(audioFilePath: tAudioFilePath, text: tText);

  test(
    'should call repository to create job and return the created job',
    () async {
      // Arrange
      when(
        mockJobRepository.createJob(
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async => Right(tCreatedJob));

      // Act
      final result = await useCase(tParams);

      // Assert
      expect(result, Right(tCreatedJob));
      verify(
        mockJobRepository.createJob(audioFilePath: tAudioFilePath, text: tText),
      );
      verifyNoMoreInteractions(mockJobRepository);
    },
  );

  test('should return Failure when repository fails to create job', () async {
    // Arrange
    const tFailure = CacheFailure('Failed to save job locally');
    when(
      mockJobRepository.createJob(
        audioFilePath: anyNamed('audioFilePath'),
        text: anyNamed('text'),
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase(tParams);

    // Assert
    expect(result, const Left(tFailure));
    verify(
      mockJobRepository.createJob(audioFilePath: tAudioFilePath, text: tText),
    );
    verifyNoMoreInteractions(mockJobRepository);
  });

  test('should create a job via the repository', () async {
    // Arrange
    const tAudioFilePath = 'path/to/audio.mp3';
    const tText = 'Initial text';
    final tJob = Job(
      localId: 'uuid',
      userId: tUserId,
      status: JobStatus.created,
      syncStatus: SyncStatus.pending,
      text: tText,
      audioFilePath: tAudioFilePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      retryCount: 0,
      lastSyncAttemptAt: null,
    );

    when(
      mockJobRepository.createJob(
        audioFilePath: anyNamed('audioFilePath'),
        text: anyNamed('text'),
      ),
    ).thenAnswer((_) async => Right(tJob));

    // Act
    final result = await useCase(
      const CreateJobParams(audioFilePath: tAudioFilePath, text: tText),
    );

    // Assert
    expect(result, Right(tJob));
    verify(
      mockJobRepository.createJob(audioFilePath: tAudioFilePath, text: tText),
    );
    verifyNoMoreInteractions(mockJobRepository);
  });
}
