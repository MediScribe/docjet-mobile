import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart'; // Keep this for Uuid class and mock generation

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
// Corrected import path
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // Add this import
// Removed unused import for JobHiveModel
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';

import 'job_writer_service_test.mocks.dart'; // Will be generated

// Mocks - Changed UuidGenerator to Uuid
@GenerateMocks([
  JobLocalDataSource,
  Uuid,
  AuthSessionProvider,
]) // Add AuthSessionProvider to the mocks
void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockUuid mockUuid; // Mock Uuid directly
  late MockAuthSessionProvider mockAuthSessionProvider; // Add this mock
  late JobWriterService service;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockUuid = MockUuid(); // Instantiate MockUuid
    mockAuthSessionProvider = MockAuthSessionProvider(); // Initialize the mock
    service = JobWriterService(
      localDataSource: mockLocalDataSource,
      uuid: mockUuid, // Inject MockUuid
      authSessionProvider: mockAuthSessionProvider, // Inject the mock
    );
  });

  group('JobWriterService', () {
    group('createJob', () {
      const tAudioPath = '/path/to/new_audio.mp3';
      const tText = 'This is the transcript text.';
      const tLocalId = 'generated-uuid-123';
      const tUserId = 'user123'; // We'll still need this for verification
      final tNow = DateTime.now(); // Changed back to final

      // Add this new test for AuthSessionProvider
      test(
        'should get userId from AuthSessionProvider and create job',
        () async {
          // Arrange
          // 1. Stub UUID generation using v4()
          when(mockUuid.v4()).thenReturn(tLocalId);
          // 2. Stub auth provider to return a user ID
          when(
            mockAuthSessionProvider.getCurrentUserId(),
          ).thenAnswer((_) async => tUserId);
          // 3. Stub local save to succeed
          when(mockLocalDataSource.saveJob(any)).thenAnswer(
            (_) async => unit,
          ); // Assume saveJob returns Future<Unit>

          // Act
          final result = await service.createJob(
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
              expect(
                job.userId,
                tUserId,
              ); // Should come from AuthSessionProvider
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
          // 3. Verify AuthSessionProvider.getCurrentUserId was called
          verify(mockAuthSessionProvider.getCurrentUserId()).called(1);
          // 4. Verify local save was called with the correct Job structure
          verify(
            mockLocalDataSource.saveJob(
              argThat(
                predicate<Job>((job) {
                  return job.localId == tLocalId &&
                      job.serverId == null &&
                      job.userId ==
                          tUserId && // Verify userId from auth provider
                      job.syncStatus == SyncStatus.pending &&
                      job.audioFilePath == tAudioPath &&
                      job.text == tText &&
                      job.status == JobStatus.created;
                }),
              ),
            ),
          ).called(1);
          // 5. Verify no other interactions
          verifyNoMoreInteractions(mockUuid);
          verifyNoMoreInteractions(mockAuthSessionProvider);
          verifyNoMoreInteractions(mockLocalDataSource);
        },
      );

      test('should handle authentication errors during job creation', () async {
        // Arrange
        // 1. Stub UUID generation
        when(mockUuid.v4()).thenReturn(tLocalId);
        // 2. Stub auth provider to throw an exception
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenThrow(Exception('Not authenticated'));

        // Act
        final result = await service.createJob(
          audioFilePath: tAudioPath,
          text: tText,
        );

        // Assert
        // 1. Check the result is Left(AuthFailure)
        expect(result, isA<Left<Failure, Job>>());
        result.fold(
          (failure) => expect(failure, isA<AuthFailure>()),
          (_) => fail('Expected Left(AuthFailure), got Right'),
        );
        // 2. Verify AuthSessionProvider.getCurrentUserId was called
        verify(mockAuthSessionProvider.getCurrentUserId()).called(1);
        // 3. Verify no UUID generation or local save was attempted
        verifyNever(mockUuid.v4());
        verifyNever(mockLocalDataSource.saveJob(any));
        // 4. Verify no other interactions
        verifyNoMoreInteractions(mockAuthSessionProvider);
        verifyNoMoreInteractions(mockLocalDataSource);
      });

      test('should create, save, and return pending job', () async {
        // Arrange
        // 1. Stub UUID generation using v4()
        when(mockUuid.v4()).thenReturn(tLocalId);
        // 2. Stub auth provider to return a user ID
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenAnswer((_) async => tUserId);
        // 3. Stub local save to succeed
        when(
          mockLocalDataSource.saveJob(any),
        ).thenAnswer((_) async => unit); // Assume saveJob returns Future<Unit>

        // Act
        final result = await service.createJob(
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
        // 3. Verify auth provider was called
        verify(mockAuthSessionProvider.getCurrentUserId()).called(1);
        // 4. Verify local save was called with the correct Job structure
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
        // 5. Verify no other interactions
        verifyNoMoreInteractions(mockUuid);
        verifyNoMoreInteractions(mockAuthSessionProvider);
        verifyNoMoreInteractions(mockLocalDataSource);
      });

      test('should return CacheFailure on save error', () async {
        // Arrange
        // 1. Stub UUID generation using v4()
        when(mockUuid.v4()).thenReturn(tLocalId);
        // 2. Stub auth provider
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenAnswer((_) async => tUserId);
        // 3. Stub local save to throw CacheException
        when(
          mockLocalDataSource.saveJob(any),
        ).thenThrow(CacheException('Failed to write'));

        // Act
        final result = await service.createJob(
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
        // 3. Verify auth provider was called
        verify(mockAuthSessionProvider.getCurrentUserId()).called(1);
        // 4. Verify local save attempt was made
        verify(mockLocalDataSource.saveJob(any)).called(1);
        // 5. Verify no other interactions
        verifyNoMoreInteractions(mockUuid);
        verifyNoMoreInteractions(mockAuthSessionProvider);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
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
        'should apply updates, mark pending, save, and return job',
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

      test('should return original job if no changes provided', () async {
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
          (failure) => fail('Expected success with original job, got $failure'),
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
      });

      test('should return CacheFailure on fetch error', () async {
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
      });

      test('should return CacheFailure on save error', () async {
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
      });
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

      test('should update syncStatus, save, and return unit', () async {
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
      });

      test('should return CacheFailure on fetch error', () async {
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

      test('should return CacheFailure on save error', () async {
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

    group('resetDeletionFailureCounter', () {
      final tNow = DateTime.now();
      final tJob = Job(
        // Rename tExistingJob to tJob for consistency
        localId: 'job-reset-id',
        serverId: 'server-reset-id',
        userId: 'user-reset',
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        displayTitle: 'Reset Counter Test',
        audioFilePath: '/path/to/reset_test.mp3',
        createdAt: tNow.subtract(const Duration(hours: 1)),
        updatedAt: tNow.subtract(const Duration(minutes: 30)),
        text: 'Text for reset test',
        failedAudioDeletionAttempts: 5, // Start with a non-zero counter
      );
      const tLocalId = 'job-reset-id';

      test(
        'should reset counter, save, and return job if counter > 0',
        () async {
          // Arrange
          // 1. Stub local fetch to return the job with a non-zero counter
          when(
            mockLocalDataSource.getJobById(tLocalId),
          ).thenAnswer((_) async => tJob); // Use tJob
          // 2. Stub local save to succeed
          when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async => unit);

          // Act
          final result = await service.resetDeletionFailureCounter(tLocalId);

          // Assert
          // 1. Check the result is Right(updated Job)
          expect(result, isA<Right<Failure, Job>>());
          result.fold((failure) => fail('Expected success, got $failure'), (
            updatedJob,
          ) {
            // Verify counter is reset
            expect(updatedJob.failedAudioDeletionAttempts, 0);
            // Verify updatedAt is newer
            expect(
              updatedJob.updatedAt.isAfter(tJob.updatedAt),
              isTrue,
            ); // Use tJob
            // Verify other fields remain unchanged
            expect(updatedJob.localId, tLocalId);
            expect(updatedJob.serverId, tJob.serverId); // Use tJob
            expect(
              updatedJob.syncStatus,
              tJob.syncStatus,
            ); // SyncStatus should be preserved
            expect(updatedJob.status, tJob.status); // Use tJob
            expect(updatedJob.createdAt, tJob.createdAt); // Use tJob
          });

          // 2. Verify local fetch was called
          verify(mockLocalDataSource.getJobById(tLocalId)).called(1);

          // 3. Verify local save was called with the updated job
          final verification = verify(mockLocalDataSource.saveJob(captureAny));
          verification.called(1);
          final capturedJob = verification.captured.single as Job;

          // Deep check the captured job
          expect(capturedJob.localId, tLocalId);
          expect(capturedJob.failedAudioDeletionAttempts, 0);
          expect(
            capturedJob.updatedAt.isAfter(tJob.updatedAt),
            isTrue,
          ); // Use tJob
          expect(capturedJob.syncStatus, tJob.syncStatus); // Use tJob
          expect(capturedJob.serverId, tJob.serverId); // Use tJob
          expect(capturedJob.status, tJob.status); // Use tJob
          expect(capturedJob.createdAt, tJob.createdAt); // Use tJob

          // 4. Verify no other interactions
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyNoMoreInteractions(mockUuid); // Uuid not used
        },
      );

      test('should return original job if counter is 0', () async {
        // Arrange
        // 1. Create a job with counter already 0
        final tJobWithZeroCounter = tJob.copyWith(
          // Use tJob
          failedAudioDeletionAttempts: 0,
          updatedAt: tNow.subtract(
            const Duration(minutes: 15),
          ), // Different updatedAt
        );
        // 2. Stub local fetch to return this job
        when(
          mockLocalDataSource.getJobById(tLocalId),
        ).thenAnswer((_) async => tJobWithZeroCounter);

        // Act
        final result = await service.resetDeletionFailureCounter(tLocalId);

        // Assert
        // 1. Check the result is Right(original Job)
        expect(result, isA<Right<Failure, Job>>());
        result.fold(
          (failure) => fail('Expected success with original job, got $failure'),
          (returnedJob) {
            // Verify it's the *exact* same job instance (or equal)
            expect(returnedJob, tJobWithZeroCounter);
            expect(returnedJob.failedAudioDeletionAttempts, 0);
            // Ensure updatedAt was *not* changed
            expect(returnedJob.updatedAt, tJobWithZeroCounter.updatedAt);
          },
        );

        // 2. Verify local fetch was called
        verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
        // 3. Verify local save was *NOT* called
        verifyNever(mockLocalDataSource.saveJob(any));
        // 4. Verify no other interactions
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockUuid);
      });

      test('should return CacheFailure on fetch error', () async {
        // Arrange
        when(
          mockLocalDataSource.getJobById(tLocalId),
        ).thenThrow(CacheException('Fetch failed'));

        // Act
        final result = await service.resetDeletionFailureCounter(tLocalId);

        // Assert
        expect(result, isA<Left<Failure, Job>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected Left(CacheFailure), got Right'),
        );
        verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockUuid);
      });

      test('should return CacheFailure on save error', () async {
        // Arrange
        // 1. Stub fetch to return the job with a non-zero counter
        when(
          mockLocalDataSource.getJobById(tLocalId),
        ).thenAnswer((_) async => tJob); // Use tJob
        // 2. Stub save to throw an exception
        when(
          mockLocalDataSource.saveJob(any),
        ).thenThrow(CacheException('Save failed'));

        // Act
        final result = await service.resetDeletionFailureCounter(tLocalId);

        // Assert
        expect(result, isA<Left<Failure, Job>>());
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Expected Left(CacheFailure), got Right'),
        );
        verify(mockLocalDataSource.getJobById(tLocalId)).called(1);
        // Verify save was attempted
        verify(
          mockLocalDataSource.saveJob(
            argThat(
              predicate<Job>((job) => job.failedAudioDeletionAttempts == 0),
            ),
          ),
        ).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockUuid);
      });
    }); // End resetDeletionFailureCounter group
  }); // End JobWriterService group
}
