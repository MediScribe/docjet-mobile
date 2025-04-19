import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

import 'job_deleter_service_test.mocks.dart';

@GenerateMocks([JobLocalDataSource, FileSystem])
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
      when(
        mockLocalDataSource.getJobById(tJob.localId),
      ).thenAnswer((_) async => tJob);
      when(
        mockLocalDataSource.deleteJob(tJob.localId),
      ).thenAnswer((_) async => unit);
      when(
        mockFileSystem.deleteFile(tJob.audioFilePath!),
      ).thenThrow(tException);

      // Act
      final result = await service.permanentlyDeleteJob(tJob.localId);

      // Assert
      expect(result, equals(const Right(unit))); // Still success
      verify(mockLocalDataSource.getJobById(tJob.localId)).called(1);
      verify(mockLocalDataSource.deleteJob(tJob.localId)).called(1);
      verify(mockFileSystem.deleteFile(tJob.audioFilePath!)).called(1);
      verifyNoMoreInteractions(mockLocalDataSource);
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
  });
}
