import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart'; // Keep this for Uuid class and mock generation

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
// Corrected import path
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
// Removed unused import for JobHiveModel
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';

import 'job_writer_service_test.mocks.dart'; // Will be generated

// Mocks - Changed UuidGenerator to Uuid
@GenerateMocks([JobLocalDataSource, Uuid])
void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockUuid mockUuid; // Mock Uuid directly
  late JobWriterService service;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockUuid = MockUuid(); // Instantiate MockUuid
    service = JobWriterService(
      localDataSource: mockLocalDataSource,
      uuid: mockUuid, // Inject MockUuid
    );
  });

  group('JobWriterService', () {
    group('createJob', () {
      const tAudioPath = '/path/to/new_audio.mp3';
      const tText = 'This is the transcript text.';
      const tLocalId = 'generated-uuid-123';
      final tNow = DateTime.now(); // Capture current time for comparison

      test(
        'should generate localId, create pending job, save locally, and return job entity',
        () async {
          // Arrange
          // 1. Stub UUID generation using v4()
          when(mockUuid.v4()).thenReturn(tLocalId);
          // 2. Stub local save to succeed
          // We expect saveJob to be called with a Job entity.
          when(mockLocalDataSource.saveJob(any)).thenAnswer(
            (_) async => unit,
          ); // Assume saveJob returns Future<Unit>

          // Act
          final result = await service.createJob(
            userId: 'user123',
            audioFilePath: tAudioPath,
            text: tText,
          );

          // Assert
          // 1. Check the result is Right(Job)
          expect(result, isA<Right<Failure, Job>>());
          result.fold(
            (failure) => fail('Expected Right(Job), got Left: $failure'),
            (job) {
              expect(job.localId, tLocalId);
              expect(job.serverId, isNull);
              expect(job.syncStatus, SyncStatus.pending);
              expect(job.audioFilePath, tAudioPath);
              expect(job.text, tText);
              expect(job.status, JobStatus.created); // Check initial status
              // Allow a small tolerance for timestamp comparison
              expect(job.createdAt.difference(tNow).inSeconds, lessThan(2));
              expect(job.updatedAt.difference(tNow).inSeconds, lessThan(2));
            },
          );
          // 2. Verify UUID generation was called using v4()
          verify(mockUuid.v4()).called(1);
          // 3. Verify local save was called with the correct Job structure
          verify(
            mockLocalDataSource.saveJob(
              argThat(
                predicate<Job>((job) {
                  return job.localId == tLocalId &&
                      job.serverId == null &&
                      job.syncStatus == SyncStatus.pending &&
                      job.audioFilePath == tAudioPath &&
                      job.text == tText &&
                      job.status == JobStatus.created;
                }),
              ),
            ),
          ).called(1);
          // 4. Verify no other interactions
          verifyNoMoreInteractions(mockUuid);
          verifyNoMoreInteractions(mockLocalDataSource);
        },
      );

      test(
        'should return CacheFailure when local data source fails to save',
        () async {
          // Arrange
          // 1. Stub UUID generation using v4()
          when(mockUuid.v4()).thenReturn(tLocalId);
          // 2. Stub local save to throw CacheException
          when(
            mockLocalDataSource.saveJob(any),
          ).thenThrow(CacheException('Failed to write'));

          // Act
          final result = await service.createJob(
            userId: 'user123',
            audioFilePath: tAudioPath,
            text: tText,
          );

          // Assert
          // 1. Check the result is Left(CacheFailure)
          expect(result, isA<Left<Failure, Job>>());
          result.fold(
            (failure) => expect(failure, isA<CacheFailure>()),
            (_) => fail('Expected Left(CacheFailure), got Right'),
          );
          // 2. Verify UUID generation was called using v4()
          verify(mockUuid.v4()).called(1);
          // 3. Verify local save attempt was made
          verify(mockLocalDataSource.saveJob(any)).called(1);
          // 4. Verify no other interactions
          verifyNoMoreInteractions(mockUuid);
          verifyNoMoreInteractions(mockLocalDataSource);
        },
      );
    }); // End createJob group

    group('updateJob', () {
      final tNow = DateTime.now();
      final tExistingJob = Job(
        localId: 'job1-local-id',
        serverId: 'job1-server-id',
        userId: 'user123',
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced, // Start as synced
        displayTitle: 'Original Title',
        audioFilePath: '/path/to/test.mp3',
        createdAt: tNow.subtract(const Duration(hours: 1)),
        updatedAt: tNow.subtract(
          const Duration(minutes: 30),
        ), // Needs to be before update
        text: 'Original text',
      );
      const tLocalId = 'job1-local-id';
      const tUpdatedText = 'Updated job text';
      final tUpdateData = JobUpdateData(text: tUpdatedText);

      test(
        'should fetch job, apply updates, set status to pending, save, and return updated job',
        () async {
          // Arrange
          // 1. Stub local fetch to return the existing job
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenAnswer((_) async => tExistingJob);
          // 2. Stub local save to succeed
          when(mockLocalDataSource.saveJob(any)).thenAnswer(
            (_) async => unit,
          ); // Assume saveJob returns Future<Unit>

          // Act
          final result = await service.updateJob(
            localId: tLocalId,
            updates: tUpdateData,
          );

          // Assert
          // 1. Check the result is Right(updated Job)
          expect(result, isA<Right<Failure, Job>>());
          result.fold((failure) => fail('Expected success, got $failure'), (
            updatedJob,
          ) {
            // Verify updated fields
            expect(updatedJob.text, tUpdatedText);
            // Verify status is pending
            expect(updatedJob.syncStatus, SyncStatus.pending);
            // Verify other fields remain correct
            expect(updatedJob.localId, tLocalId);
            expect(updatedJob.serverId, tExistingJob.serverId);
            expect(
              updatedJob.status,
              tExistingJob.status,
            ); // Status unchanged by this update
            // Verify updatedAt is newer
            expect(
              updatedJob.updatedAt.isAfter(tExistingJob.updatedAt),
              isTrue,
            );
          });

          // 2. Verify local fetch was called
          verify(mockLocalDataSource.getJobById(tLocalId)).called(1);

          // 3. Verify local save was called with the updated job
          final verification = verify(mockLocalDataSource.saveJob(captureAny));
          verification.called(1);
          final capturedJob = verification.captured.single as Job;

          // Deep check the captured job
          expect(capturedJob.localId, tLocalId);
          expect(capturedJob.text, tUpdatedText);
          expect(capturedJob.syncStatus, SyncStatus.pending);
          expect(capturedJob.serverId, tExistingJob.serverId);
          expect(capturedJob.status, tExistingJob.status);
          expect(capturedJob.updatedAt.isAfter(tExistingJob.updatedAt), isTrue);
          expect(
            capturedJob.createdAt,
            tExistingJob.createdAt,
          ); // CreatedAt shouldn't change

          // 4. Verify no other interactions
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyNoMoreInteractions(mockUuid); // Uuid not used in update
        },
      );

      test(
        'should return original job and not save if JobUpdateData has no changes',
        () async {
          // Arrange
          // 1. Stub local fetch to return the existing job
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenAnswer((_) async => tExistingJob);
          // 2. Create an empty JobUpdateData (no fields set)
          const emptyUpdateData = JobUpdateData();

          // Act
          final result = await service.updateJob(
            localId: tLocalId,
            updates: emptyUpdateData,
          );

          // Assert
          // 1. Check the result is Right(original Job)
          expect(result, isA<Right<Failure, Job>>());
          result.fold(
            (failure) =>
                fail('Expected success with original job, got $failure'),
            (returnedJob) {
              // Verify the returned job is identical to the original
              expect(returnedJob, tExistingJob);
              // Explicitly check syncStatus hasn't changed
              expect(returnedJob.syncStatus, tExistingJob.syncStatus);
            },
          );

          // 2. Verify local fetch was called once
          verify(mockLocalDataSource.getJobById(tLocalId)).called(1);

          // 3. Verify local save was NEVER called
          verifyNever(mockLocalDataSource.saveJob(any));

          // 4. Verify no other interactions
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyNoMoreInteractions(mockUuid);
        },
      );

      test(
        'should return CacheFailure when fetching the original job fails',
        () async {
          // Arrange
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenThrow(CacheException('Not found'));

          // Act
          final result = await service.updateJob(
            localId: tLocalId,
            updates: tUpdateData,
          );

          // Assert
          expect(result, isA<Left<Failure, Job>>());
          result.fold(
            (failure) => expect(failure, isA<CacheFailure>()),
            (_) => fail('Expected failure, got success'),
          );
          verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
          verifyNever(mockLocalDataSource.saveJob(any));
          verifyNoMoreInteractions(mockLocalDataSource);
        },
      );

      test(
        'should return CacheFailure when saving the updated job fails',
        () async {
          // Arrange
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenAnswer((_) async => tExistingJob);
          when(
            mockLocalDataSource.saveJob(any),
          ).thenThrow(CacheException('Save failed'));

          // Act
          final result = await service.updateJob(
            localId: tLocalId,
            updates: tUpdateData,
          );

          // Assert
          expect(result, isA<Left<Failure, Job>>());
          result.fold(
            (failure) => expect(failure, isA<CacheFailure>()),
            (_) => fail('Expected failure, got success'),
          );
          verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
          verify(
            mockLocalDataSource.saveJob(any),
          ).called(1); // Save was attempted
          verifyNoMoreInteractions(mockLocalDataSource);
        },
      );
    }); // End updateJob group

    group('updateJobSyncStatus', () {
      final tNow = DateTime.now();
      final tExistingJob = Job(
        localId: 'job-sync-test-id',
        serverId: 'server-id-exists',
        userId: 'user-sync',
        status: JobStatus.transcribed,
        syncStatus: SyncStatus.synced, // Start as synced
        displayTitle: 'Sync Status Test',
        audioFilePath: '/path/to/sync.mp3',
        createdAt: tNow.subtract(const Duration(days: 1)),
        updatedAt: tNow.subtract(const Duration(hours: 1)),
        text: 'Text for sync status update test',
      );
      const tLocalId = 'job-sync-test-id';
      const tNewSyncStatus = SyncStatus.error; // Example new status

      test(
        'should fetch job, update only syncStatus, save, and return unit',
        () async {
          // Arrange
          // 1. Stub local fetch
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenAnswer((_) async => tExistingJob);
          // 2. Stub local save
          when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

          // Act
          final result = await service.updateJobSyncStatus(
            localId: tLocalId,
            status: tNewSyncStatus,
          );

          // Assert
          // 1. Check result is Right(unit)
          expect(result, const Right(unit));

          // 2. Verify fetch
          verify(mockLocalDataSource.getJobById(tLocalId)).called(1);

          // 3. Verify save with correctly updated status
          final verification = verify(mockLocalDataSource.saveJob(captureAny));
          verification.called(1);
          final capturedJob = verification.captured.single as Job;

          expect(capturedJob.localId, tLocalId);
          expect(
            capturedJob.syncStatus,
            tNewSyncStatus,
          ); // CRITICAL: Check new sync status
          // Verify other fields are UNCHANGED
          expect(capturedJob.serverId, tExistingJob.serverId);
          expect(capturedJob.userId, tExistingJob.userId);
          expect(capturedJob.status, tExistingJob.status);
          expect(capturedJob.displayTitle, tExistingJob.displayTitle);
          expect(capturedJob.audioFilePath, tExistingJob.audioFilePath);
          expect(capturedJob.text, tExistingJob.text);
          expect(capturedJob.createdAt, tExistingJob.createdAt);
          // Note: updatedAt might or might not be updated here - plan doesn't specify.
          // Assuming it *doesn't* update for just a sync status change.
          expect(capturedJob.updatedAt, tExistingJob.updatedAt);

          // 4. Verify no other interactions
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyNoMoreInteractions(mockUuid); // Uuid not used here
        },
      );

      test('should return CacheFailure when fetching job fails', () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById(tLocalId),
        ).thenThrow(CacheException('Not found for sync update'));

        // Act
        final result = await service.updateJobSyncStatus(
          localId: tLocalId,
          status: tNewSyncStatus,
        );

        // Assert
        expect(result, isA<Left<Failure, Unit>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected failure, got success'),
        );
        verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
        verifyNever(mockLocalDataSource.saveJob(any));
        verifyNoMoreInteractions(mockLocalDataSource);
      });

      test('should return CacheFailure when saving job fails', () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById(tLocalId),
        ).thenAnswer((_) async => tExistingJob);
        when(
          mockLocalDataSource.saveJob(any),
        ).thenThrow(CacheException('Save failed during sync update'));

        // Act
        final result = await service.updateJobSyncStatus(
          localId: tLocalId,
          status: tNewSyncStatus,
        );

        // Assert
        expect(result, isA<Left<Failure, Unit>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected failure, got success'),
        );
        verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
        verify(mockLocalDataSource.saveJob(any)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
    }); // End updateJobSyncStatus group
  }); // End JobWriterService group
}
