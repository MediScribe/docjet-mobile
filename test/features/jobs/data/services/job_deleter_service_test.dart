import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

import 'job_deleter_service_test.mocks.dart';

@GenerateMocks([
  JobLocalDataSource,
  FileSystem,
  NetworkInfo,
  JobRemoteDataSource,
])
void main() {
  late JobDeleterService service;
  late MockJobLocalDataSource mockLocalDataSource;
  late MockFileSystem mockFileSystem;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockFileSystem = MockFileSystem();
    service = JobDeleterService(
      localDataSource: mockLocalDataSource,
      fileSystem: mockFileSystem,
    );
  });

  final tJob = Job(
    localId: 'job1',
    userId: 'user1',
    status: JobStatus.completed,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    audioFilePath: '/path/to/audio.mp3',
  );

  group('deleteJob (Mark for Deletion)', () {
    test(
      'should get job, update status to pendingDeletion, and save job',
      () async {
        // Arrange
        final tJobMarkedForDeletion = tJob.copyWith(
          syncStatus: SyncStatus.pendingDeletion,
        );
        when(
          mockLocalDataSource.getJobById(tJob.localId),
        ).thenAnswer((_) async => tJob);
        when(
          mockLocalDataSource.saveJob(tJobMarkedForDeletion),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.deleteJob(tJob.localId);

        // Assert
        expect(result, equals(const Right(unit)));
        verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
        verify(mockLocalDataSource.saveJob(tJobMarkedForDeletion)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockFileSystem);
      },
    );

    test(
      'should return CacheFailure when getJobById throws CacheException',
      () async {
        // Arrange
        final tException = CacheException('Job not found');
        when(
          mockLocalDataSource.getJobById(tJob.localId),
        ).thenThrow(tException);

        // Act
        final result = await service.deleteJob(tJob.localId);

        // Assert
        expect(
          result,
          equals(Left(CacheFailure(tException.message ?? 'Cache error'))),
        );
        verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
        verifyNever(mockLocalDataSource.saveJob(any));
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockFileSystem);
      },
    );

    test(
      'should return CacheFailure when saveJob throws CacheException',
      () async {
        // Arrange
        final tJobMarkedForDeletion = tJob.copyWith(
          syncStatus: SyncStatus.pendingDeletion,
        );
        final tException = CacheException('Save failed');
        when(
          mockLocalDataSource.getJobById(tJob.localId),
        ).thenAnswer((_) async => tJob);
        when(
          mockLocalDataSource.saveJob(tJobMarkedForDeletion),
        ).thenThrow(tException);

        // Act
        final result = await service.deleteJob(tJob.localId);

        // Assert
        expect(
          result,
          equals(Left(CacheFailure(tException.message ?? 'Cache error'))),
        );
        verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
        verify(mockLocalDataSource.saveJob(tJobMarkedForDeletion)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockFileSystem);
      },
    );
  });

  group('permanentlyDeleteJob', () {
    test('should delete job from local source and delete audio file', () async {
      // Arrange
      when(
        mockLocalDataSource.getJobById(tJob.localId),
      ).thenAnswer((_) async => tJob);
      when(
        mockLocalDataSource.deleteJob(tJob.localId),
      ).thenAnswer((_) async => unit);
      when(
        mockFileSystem.deleteFile(tJob.audioFilePath!),
      ).thenAnswer((_) async => Future.value());

      // Act
      final result = await service.permanentlyDeleteJob(tJob.localId);

      // Assert
      expect(result, equals(const Right(unit)));
      verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
      verify(mockLocalDataSource.deleteJob(tJob.localId)).called(1);
      verify(mockFileSystem.deleteFile(tJob.audioFilePath!)).called(1);
      verifyNoMoreInteractions(mockLocalDataSource);
      verifyNoMoreInteractions(mockFileSystem);
    });

    test(
      'should return Right(unit) even if job not found locally (already deleted)',
      () async {
        // Arrange
        final tException = CacheException('Not Found');
        when(
          mockLocalDataSource.getJobById(tJob.localId),
        ).thenThrow(tException);

        // Act
        final result = await service.permanentlyDeleteJob(tJob.localId);

        // Assert
        expect(result, equals(const Right(unit))); // Still success
        verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
        verifyNever(mockLocalDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test('should return Right(unit) even if file deletion fails', () async {
      // Arrange
      final tException = FileSystemException('Cannot delete');
      final tJobWithIncrementedCounter = tJob.copyWith(
        failedAudioDeletionAttempts: tJob.failedAudioDeletionAttempts + 1,
      );
      when(
        mockLocalDataSource.getJobById(tJob.localId),
      ).thenAnswer((_) async => tJob);
      when(
        mockLocalDataSource.deleteJob(tJob.localId),
      ).thenAnswer((_) async => unit);
      when(
        mockFileSystem.deleteFile(tJob.audioFilePath!),
      ).thenThrow(tException);
      when(
        mockLocalDataSource.saveJob(
          argThat(
            isA<Job>().having(
              (j) => j.failedAudioDeletionAttempts,
              'failedAudioDeletionAttempts',
              tJobWithIncrementedCounter.failedAudioDeletionAttempts,
            ),
          ),
        ),
      ).thenAnswer((_) async => unit);

      // Act
      final result = await service.permanentlyDeleteJob(tJob.localId);

      // Assert
      expect(result, equals(const Right(unit))); // Still success
      verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
      verify(mockLocalDataSource.deleteJob(tJob.localId)).called(1);
      verify(mockFileSystem.deleteFile(tJob.audioFilePath!)).called(1);
      verify(
        mockLocalDataSource.saveJob(
          argThat(
            isA<Job>().having(
              (j) => j.failedAudioDeletionAttempts,
              'failedAudioDeletionAttempts',
              tJobWithIncrementedCounter.failedAudioDeletionAttempts,
            ),
          ),
        ),
      ).called(1);
      verifyNoMoreInteractions(mockFileSystem);
    });

    test('should return Left(CacheFailure) if local deleteJob fails', () async {
      // Arrange
      final tException = CacheException('DB delete error');
      when(
        mockLocalDataSource.getJobById(tJob.localId),
      ).thenAnswer((_) async => tJob);
      when(mockLocalDataSource.deleteJob(tJob.localId)).thenThrow(tException);

      // Act
      final result = await service.permanentlyDeleteJob(tJob.localId);

      // Assert
      // Check the type of the value inside Left
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Expected Left, got Right'),
      );
      // Optionally, check the message:
      // result.fold(
      //   (failure) => expect((failure as CacheFailure).message, equals('Failed to delete job ${tJob.localId} from local DB: $tException')),
      //   (_) => fail('Expected Left, got Right'),
      // );
      verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
      verify(mockLocalDataSource.deleteJob(tJob.localId)).called(1);
      verifyNever(
        mockFileSystem.deleteFile(any),
      ); // Should fail before file deletion
      verifyNoMoreInteractions(mockLocalDataSource);
      verifyNoMoreInteractions(mockFileSystem);
    });

    test(
      'should not attempt file deletion if audioFilePath is null or empty',
      () async {
        // Arrange
        const uniqueId = 'job-no-audio';
        // Create a completely new Job object with null path
        final tJobNoAudio = Job(
          localId: uniqueId,
          userId: 'user-no-audio',
          status: JobStatus.created,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          audioFilePath: null, // Explicitly null
        );

        when(
          mockLocalDataSource.getJobById(uniqueId),
        ).thenAnswer((_) async => tJobNoAudio);
        when(
          mockLocalDataSource.deleteJob(uniqueId),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.permanentlyDeleteJob(uniqueId);

        // Assert
        expect(result, equals(const Right(unit)));
        verify(mockLocalDataSource.getJobById(uniqueId)).called(1);
        verify(mockLocalDataSource.deleteJob(uniqueId)).called(1);
        verifyNever(mockFileSystem.deleteFile(any));
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'should increment failedAudioDeletionAttempts and save job if file deletion fails',
      () async {
        // Arrange
        final tInitialJob = Job(
          localId: 'job-fail-delete',
          userId: 'user1',
          status: JobStatus.completed,
          syncStatus: SyncStatus.pendingDeletion, // Example status
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          audioFilePath: '/path/to/fail/audio.mp3',
          failedAudioDeletionAttempts: 1, // Initial count
        );
        final tExpectedUpdatedJob = tInitialJob.copyWith(
          failedAudioDeletionAttempts:
              tInitialJob.failedAudioDeletionAttempts + 1,
        );
        final tException = FileSystemException('Cannot delete');

        when(
          mockLocalDataSource.getJobById(tInitialJob.localId),
        ).thenAnswer((_) async => tInitialJob);
        when(
          mockFileSystem.deleteFile(tInitialJob.audioFilePath!),
        ).thenThrow(tException);
        // Expect the updated job to be saved
        when(
          mockLocalDataSource.saveJob(tExpectedUpdatedJob),
        ).thenAnswer((_) async => unit);
        // DB deletion should still succeed
        when(
          mockLocalDataSource.deleteJob(tInitialJob.localId),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.permanentlyDeleteJob(tInitialJob.localId);

        // Assert
        expect(
          result,
          equals(const Right(unit)),
        ); // Operation itself is non-fatal
        verify(mockLocalDataSource.getJobById(tInitialJob.localId)).called(1);
        verify(mockFileSystem.deleteFile(tInitialJob.audioFilePath!)).called(1);
        // Verify the job with the incremented counter was saved
        verify(mockLocalDataSource.saveJob(tExpectedUpdatedJob)).called(1);
        // Verify the DB deletion still proceeded
        verify(mockLocalDataSource.deleteJob(tInitialJob.localId)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'should return Right(unit) even if file deletion and subsequent save fail',
      () async {
        // Arrange
        final tException = FileSystemException('Cannot delete');
        final tSaveException = CacheException('Cannot save updated job');
        final tJobWithIncrementedCounter = tJob.copyWith(
          failedAudioDeletionAttempts: tJob.failedAudioDeletionAttempts + 1,
        );

        when(
          mockLocalDataSource.getJobById(tJob.localId),
        ).thenAnswer((_) async => tJob);
        when(
          mockLocalDataSource.deleteJob(tJob.localId),
        ).thenAnswer((_) async => unit); // DB delete still succeeds
        when(
          mockFileSystem.deleteFile(tJob.audioFilePath!),
        ).thenThrow(tException); // File deletion fails
        when(
          mockLocalDataSource.saveJob(
            argThat(
              isA<Job>().having(
                (j) => j.failedAudioDeletionAttempts,
                'failedAudioDeletionAttempts',
                tJobWithIncrementedCounter.failedAudioDeletionAttempts,
              ),
            ),
          ),
        ).thenThrow(tSaveException); // Saving the incremented job fails

        // Act
        final result = await service.permanentlyDeleteJob(tJob.localId);

        // Assert
        expect(result, equals(const Right(unit))); // Still overall success
        verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
        verify(mockLocalDataSource.deleteJob(tJob.localId)).called(1);
        verify(mockFileSystem.deleteFile(tJob.audioFilePath!)).called(1);
        // Verify the attempt to save the job with the incremented counter
        verify(
          mockLocalDataSource.saveJob(
            argThat(
              isA<Job>().having(
                (j) => j.failedAudioDeletionAttempts,
                'failedAudioDeletionAttempts',
                tJobWithIncrementedCounter.failedAudioDeletionAttempts,
              ),
            ),
          ),
        ).called(1);
        // Ensure no other interactions happened after the failed save
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );
  });

  group('attemptSmartDelete', () {
    late MockNetworkInfo mockNetworkInfo;
    late MockJobRemoteDataSource mockRemoteDataSource;
    late JobDeleterService smartService;

    setUp(() {
      mockNetworkInfo = MockNetworkInfo();
      mockRemoteDataSource = MockJobRemoteDataSource();
      smartService = JobDeleterService(
        localDataSource: mockLocalDataSource,
        fileSystem: mockFileSystem,
        networkInfo: mockNetworkInfo,
        remoteDataSource: mockRemoteDataSource,
      );
    });

    final tJobWithNullServerId = Job(
      localId: 'local1',
      userId: 'user1',
      serverId: null,
      status: JobStatus.completed,
      syncStatus: SyncStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      audioFilePath: '/path/to/audio.mp3',
    );

    final tJobWithEmptyServerId = Job(
      localId: 'local1',
      userId: 'user1',
      serverId: '',
      status: JobStatus.completed,
      syncStatus: SyncStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      audioFilePath: '/path/to/audio.mp3',
    );

    final tJobWithServerId = Job(
      localId: 'local1',
      userId: 'user1',
      serverId: 'server1',
      status: JobStatus.completed,
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      audioFilePath: '/path/to/audio.mp3',
    );

    test(
      'should immediately purge a job with null serverId (orphan)',
      () async {
        // Arrange
        // Initial check needs to be called first for the attemptSmartDelete
        when(
          mockLocalDataSource.getJobById('local1'),
        ).thenAnswer((_) async => tJobWithNullServerId);
        when(
          mockLocalDataSource.deleteJob('local1'),
        ).thenAnswer((_) async => unit);
        when(
          mockFileSystem.deleteFile(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await smartService.attemptSmartDelete('local1');

        // Assert
        expect(result, equals(const Right(true))); // true = immediate purge
        // Each test only verifies what it needs to care about
        verify(mockLocalDataSource.getJobById('local1')).called(2);
        verify(mockLocalDataSource.deleteJob('local1')).called(1);
        verifyNever(mockNetworkInfo.isConnected);
        verifyNever(mockRemoteDataSource.fetchJobById(any));
      },
    );

    test(
      'should immediately purge a job with empty serverId (also orphan)',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById('local1'),
        ).thenAnswer((_) async => tJobWithEmptyServerId);
        when(
          mockLocalDataSource.deleteJob('local1'),
        ).thenAnswer((_) async => unit);
        when(
          mockFileSystem.deleteFile(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await smartService.attemptSmartDelete('local1');

        // Assert
        expect(result, equals(const Right(true))); // true = immediate purge
        verify(mockLocalDataSource.getJobById('local1')).called(2);
        verify(mockLocalDataSource.deleteJob('local1')).called(1);
        verifyNever(mockNetworkInfo.isConnected);
        verifyNever(mockRemoteDataSource.fetchJobById(any));
      },
    );

    test('should mark for deletion when offline', () async {
      // Arrange
      when(
        mockLocalDataSource.getJobById('local1'),
      ).thenAnswer((_) async => tJobWithServerId);
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      // Test needs to handle the job being set to pendingDeletion
      when(
        mockLocalDataSource.saveJob(
          argThat(
            predicate<Job>(
              (j) =>
                  j.localId == 'local1' &&
                  j.syncStatus == SyncStatus.pendingDeletion,
            ),
          ),
        ),
      ).thenAnswer((_) async => unit);

      // Act
      final result = await smartService.attemptSmartDelete('local1');

      // Assert
      expect(result, equals(const Right(false))); // false = mark for deletion
      verify(mockLocalDataSource.getJobById('local1')).called(2);
      verify(mockNetworkInfo.isConnected).called(1);
      verify(mockLocalDataSource.saveJob(any)).called(1);
      verifyNever(mockRemoteDataSource.fetchJobById(any));
    });

    test(
      'should mark for deletion when job exists on server (200 status)',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById('local1'),
        ).thenAnswer((_) async => tJobWithServerId);
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(
          mockRemoteDataSource.fetchJobById('server1'),
        ).thenAnswer((_) async => tJobWithServerId);

        // Test needs to handle the job being set to pendingDeletion
        when(
          mockLocalDataSource.saveJob(
            argThat(
              predicate<Job>(
                (j) =>
                    j.localId == 'local1' &&
                    j.syncStatus == SyncStatus.pendingDeletion,
              ),
            ),
          ),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await smartService.attemptSmartDelete('local1');

        // Assert
        expect(result, equals(const Right(false))); // false = mark for deletion
        verify(mockLocalDataSource.getJobById('local1')).called(2);
        verify(mockNetworkInfo.isConnected).called(1);
        verify(mockRemoteDataSource.fetchJobById('server1')).called(1);
        verify(mockLocalDataSource.saveJob(any)).called(1);
      },
    );

    test(
      'should immediately purge when job does not exist on server (404 status)',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById('local1'),
        ).thenAnswer((_) async => tJobWithServerId);
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(
          mockRemoteDataSource.fetchJobById('server1'),
        ).thenThrow(ApiException(message: 'Not found', statusCode: 404));

        when(
          mockLocalDataSource.deleteJob('local1'),
        ).thenAnswer((_) async => unit);
        when(
          mockFileSystem.deleteFile(any),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await smartService.attemptSmartDelete('local1');

        // Assert
        expect(result, equals(const Right(true))); // true = immediate purge
        verify(mockLocalDataSource.getJobById('local1')).called(2);
        verify(mockNetworkInfo.isConnected).called(1);
        verify(mockRemoteDataSource.fetchJobById('server1')).called(1);
        verify(mockLocalDataSource.deleteJob('local1')).called(1);
      },
    );

    test(
      'should mark for deletion when API returns non-404 error (assume job exists)',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById('local1'),
        ).thenAnswer((_) async => tJobWithServerId);
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(
          mockRemoteDataSource.fetchJobById('server1'),
        ).thenThrow(ApiException(message: 'Server error', statusCode: 500));

        when(
          mockLocalDataSource.saveJob(
            argThat(
              predicate<Job>(
                (j) =>
                    j.localId == 'local1' &&
                    j.syncStatus == SyncStatus.pendingDeletion,
              ),
            ),
          ),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await smartService.attemptSmartDelete('local1');

        // Assert
        expect(result, equals(const Right(false))); // false = mark for deletion
        verify(mockLocalDataSource.getJobById('local1')).called(2);
        verify(mockNetworkInfo.isConnected).called(1);
        verify(mockRemoteDataSource.fetchJobById('server1')).called(1);
        verify(mockLocalDataSource.saveJob(any)).called(1);
      },
    );

    test('should mark for deletion when network check throws', () async {
      // Arrange
      when(
        mockLocalDataSource.getJobById('local1'),
      ).thenAnswer((_) async => tJobWithServerId);
      when(mockNetworkInfo.isConnected).thenThrow(Exception('Network error'));

      when(
        mockLocalDataSource.saveJob(
          argThat(
            predicate<Job>(
              (j) =>
                  j.localId == 'local1' &&
                  j.syncStatus == SyncStatus.pendingDeletion,
            ),
          ),
        ),
      ).thenAnswer((_) async => unit);

      // Act
      final result = await smartService.attemptSmartDelete('local1');

      // Assert
      expect(result, equals(const Right(false))); // false = mark for deletion
      verify(mockLocalDataSource.getJobById('local1')).called(2);
      verify(mockNetworkInfo.isConnected).called(1);
      verify(mockLocalDataSource.saveJob(any)).called(1);
      verifyNever(mockRemoteDataSource.fetchJobById(any));
    });

    test(
      'should return CacheFailure when job not found in local datastore',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById('local1'),
        ).thenThrow(CacheException('Job not found'));

        // Act
        final result = await smartService.attemptSmartDelete('local1');

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result, equals(Left(CacheFailure('Job not found'))));
        verify(mockLocalDataSource.getJobById('local1')).called(1);
        verifyNever(mockNetworkInfo.isConnected);
        verifyNever(mockRemoteDataSource.fetchJobById(any));
        verifyNever(mockLocalDataSource.saveJob(any));
        verifyNever(mockLocalDataSource.deleteJob(any));
      },
    );
  });

  // SPLIT THIS FILE INTO MULTIPLE FILES; DO NOT ADD ANYTHING ELSE TO THIS FILE
}
