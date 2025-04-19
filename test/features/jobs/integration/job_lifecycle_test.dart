import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'dart:io' show FileSystemException;
import 'package:uuid/uuid.dart';

// Generate mocks
@GenerateMocks([JobLocalDataSource, JobRemoteDataSource, FileSystem, Uuid])
import 'job_lifecycle_test.mocks.dart';

// Add custom NetworkFailure for testing
class NetworkFailure extends Failure {}

void main() {
  late JobRepositoryImpl repository;
  late MockJobLocalDataSource localDataSource;
  late MockJobRemoteDataSource remoteDataSource;
  late MockFileSystem fileSystem;
  late MockUuid uuidGenerator;

  setUp(() {
    localDataSource = MockJobLocalDataSource();
    remoteDataSource = MockJobRemoteDataSource();
    fileSystem = MockFileSystem();
    uuidGenerator = MockUuid();

    repository = JobRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      fileSystemService: fileSystem,
      uuid: uuidGenerator,
    );
  });

  // Helper function to create a Job entity
  Job createJobEntity({
    required String localId,
    String? serverId,
    required String text,
    required String audioFilePath,
    required SyncStatus syncStatus,
    required DateTime createdAt,
  }) {
    return Job(
      localId: localId,
      serverId: serverId,
      text: text,
      audioFilePath: audioFilePath,
      syncStatus: syncStatus,
      status: JobStatus.created,
      createdAt: createdAt,
      updatedAt: createdAt,
      userId: 'test-user-id',
      displayTitle: '',
      displayText: '',
    );
  }

  // Helper function to create a JobHiveModel
  JobHiveModel createJobHiveModel({
    required String localId,
    String? serverId,
    required String text,
    required String audioFilePath,
    required SyncStatus syncStatus,
    required String createdAt,
  }) {
    return JobHiveModel(
      localId: localId,
      serverId: serverId,
      text: text,
      audioFilePath: audioFilePath,
      syncStatus: syncStatus.index,
      status: JobStatus.created.index,
      createdAt: createdAt,
      updatedAt: createdAt,
      userId: 'test-user-id',
    );
  }

  group('Job Lifecycle Integration Tests', () {
    test(
      'should handle complete job lifecycle: create → sync → update → sync → delete → sync',
      () async {
        // Arrange
        final audioPath = '/path/to/audio.mp3';
        final jobText = 'Test transcription';
        final updatedText = 'Updated transcription';
        final localId = 'local-uuid-1234';
        final serverId = 'server-id-5678';
        final now = DateTime.now();
        final nowIso = now.toIso8601String();

        // Mock UUID generation
        when(uuidGenerator.v4()).thenReturn(localId);

        // Expect local save on creation
        when(localDataSource.saveJobHiveModel(any)).thenAnswer((_) async {});

        // Initial job
        final initialJob = createJobEntity(
          localId: localId,
          text: jobText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.pending,
          createdAt: now,
        );

        // Initial job hive model
        final initialJobHiveModel = createJobHiveModel(
          localId: localId,
          text: jobText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.pending,
          createdAt: nowIso,
        );

        // Synced job with server ID
        final syncedJob = initialJob.copyWith(
          serverId: serverId,
          syncStatus: SyncStatus.synced,
        );

        // Synced job hive model
        final syncedJobHiveModel = createJobHiveModel(
          localId: localId,
          serverId: serverId,
          text: jobText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.synced,
          createdAt: nowIso,
        );

        // Setup mock for job retrieval
        when(
          localDataSource.getJobHiveModelById(localId),
        ).thenAnswer((_) async => syncedJobHiveModel);

        // Setup mock behavior for getting jobs to sync
        // First call during initial sync returns initialJobHiveModel
        when(
          localDataSource.getJobsToSync(),
        ).thenAnswer((_) async => [initialJobHiveModel]);

        // Mock updated job with new text
        final updatedHiveModel = createJobHiveModel(
          localId: localId,
          serverId: serverId,
          text: updatedText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.pending,
          createdAt: nowIso,
        );

        // Setup mock to return the updated model on second getJobHiveModelById call
        // We need to recreate this with thenReturn for multiple calls
        when(
          localDataSource.getJobHiveModelById(localId),
        ).thenAnswer((_) async => syncedJobHiveModel); // First call

        // After the update operation is done, return the updated model
        when(
          localDataSource.getJobHiveModelById(localId),
        ).thenAnswer((_) async => updatedHiveModel); // Second call

        // Expect remote create API call during sync
        when(
          remoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer((_) async => syncedJob);

        // Mock update job remotely
        when(
          remoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async => syncedJob);

        // Mock deletion behavior
        when(
          localDataSource.updateJobSyncStatus(
            localId,
            SyncStatus.pendingDeletion,
          ),
        ).thenAnswer((_) async {});

        // Properly mock the deleteJob method to return a Future<Unit>
        when(
          remoteDataSource.deleteJob(serverId),
        ).thenAnswer((_) => Future<Unit>.value(unit));

        when(fileSystem.deleteFile(audioPath)).thenAnswer((_) async => true);

        // Act & Assert - Job Creation
        final createdJobResult = await repository.createJob(
          audioFilePath: audioPath,
          text: jobText,
        );

        // Extract the job from Either result
        final createdJob = createdJobResult.fold(
          (failure) => throw Exception('Job creation failed: $failure'),
          (job) => job,
        );

        expect(createdJob.localId, equals(localId));
        expect(createdJob.serverId, isNull);
        expect(createdJob.syncStatus, equals(SyncStatus.pending));
        verify(localDataSource.saveJobHiveModel(any)).called(1);

        // Act & Assert - Initial Sync
        await repository.syncPendingJobs();

        verify(
          remoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).called(1);

        verify(
          localDataSource.updateJobSyncStatus(localId, SyncStatus.synced),
        ).called(1);

        // Setup second mock for getJobsToSync for update sync
        when(
          localDataSource.getJobsToSync(),
        ).thenAnswer((_) async => [updatedHiveModel]);

        // Act & Assert - Job Update
        final updatedJobResult = await repository.updateJob(
          jobId: localId,
          updates: {'text': updatedText},
        );

        // Extract the job from Either result
        final updatedJobEntity = updatedJobResult.fold(
          (failure) => throw Exception('Job update failed: $failure'),
          (job) => job,
        );

        expect(updatedJobEntity.text, equals(updatedText));
        expect(updatedJobEntity.syncStatus, equals(SyncStatus.pending));
        verify(
          localDataSource.saveJobHiveModel(any),
        ).called(2); // Called again for update

        // Act & Assert - Update Sync
        await repository.syncPendingJobs();

        verify(
          remoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        ).called(1);

        verify(
          localDataSource.updateJobSyncStatus(localId, SyncStatus.synced),
        ).called(1);

        // Act & Assert - Mark for Deletion
        final deleteResult = await repository.deleteJob(localId);

        // Handle the Either result correctly
        deleteResult.fold(
          (failure) => throw Exception('Job deletion failed: $failure'),
          (success) => expect(success, equals(unit)),
        );

        // Verify that the job model was saved with the pendingDeletion status
        verify(
          localDataSource.saveJobHiveModel(
            argThat(
              isA<JobHiveModel>()
                  .having((m) => m.localId, 'localId', localId)
                  .having(
                    (m) => m.syncStatus,
                    'syncStatus',
                    SyncStatus.pendingDeletion.index,
                  ),
            ),
          ),
        ).called(1);

        // Update mock for getting jobs to sync to include pending deletion
        // Create a new job hive model with pending deletion status
        final jobPendingDeletionHiveModel = createJobHiveModel(
          localId: localId,
          serverId: serverId,
          text: updatedText,
          audioFilePath: audioPath,
          syncStatus: SyncStatus.pendingDeletion,
          createdAt: nowIso,
        );

        // Setup third mock for getJobsToSync for deletion sync
        when(
          localDataSource.getJobsToSync(),
        ).thenAnswer((_) async => [jobPendingDeletionHiveModel]);

        // Act & Assert - Deletion Sync
        await repository.syncPendingJobs();

        verify(remoteDataSource.deleteJob(serverId)).called(1);
        verify(localDataSource.deleteJobHiveModel(localId)).called(1);
        verify(fileSystem.deleteFile(audioPath)).called(1);
      },
    );

    test(
      'should handle batch job operations with different sync states',
      () async {
        // Arrange
        final now = DateTime.now();
        final nowIso = now.toIso8601String();

        // Create multiple jobs with different states
        final localId1 = 'local-id-1';
        final localId2 = 'local-id-2';
        final localId3 = 'local-id-3';
        final serverId2 = 'server-id-2';
        final serverId3 = 'server-id-3';

        // 1. New job (pending creation)
        final newJobHiveModel = createJobHiveModel(
          localId: localId1,
          serverId: null,
          text: 'New job text',
          audioFilePath: '/path/audio1.mp3',
          syncStatus: SyncStatus.pending,
          createdAt: nowIso,
        );

        // 2. Existing job with updates (pending update)
        final updatedJobHiveModel = createJobHiveModel(
          localId: localId2,
          serverId: serverId2,
          text: 'Updated job text',
          audioFilePath: '/path/audio2.mp3',
          syncStatus: SyncStatus.pending,
          createdAt: nowIso,
        );

        // 3. Job pending deletion
        final deletedJobHiveModel = createJobHiveModel(
          localId: localId3,
          serverId: serverId3,
          text: 'To be deleted',
          audioFilePath: '/path/audio3.mp3',
          syncStatus: SyncStatus.pendingDeletion,
          createdAt: nowIso,
        );

        // Setup batch of jobs to sync
        when(localDataSource.getJobsToSync()).thenAnswer(
          (_) async => [
            newJobHiveModel,
            updatedJobHiveModel,
            deletedJobHiveModel,
          ],
        );

        // Mock successful creation response
        final createdJob = createJobEntity(
          localId: localId1,
          serverId: 'new-server-id-1',
          text: 'New job text',
          audioFilePath: '/path/audio1.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: now,
        );

        when(
          remoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer((_) async => createdJob);

        // Mock successful update response
        final updatedJob = createJobEntity(
          localId: localId2,
          serverId: serverId2,
          text: 'Updated job text',
          audioFilePath: '/path/audio2.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: now,
        );

        when(
          remoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        ).thenAnswer((_) async => updatedJob);

        // Mock successful deletion
        when(
          remoteDataSource.deleteJob(serverId3),
        ).thenAnswer((_) => Future<Unit>.value(unit));

        // Mock file system operation
        when(
          fileSystem.deleteFile('/path/audio3.mp3'),
        ).thenAnswer((_) async => true);

        // Mock saving jobs and updating statuses
        when(localDataSource.saveJobHiveModel(any)).thenAnswer((_) async {});
        when(
          localDataSource.updateJobSyncStatus(any, any),
        ).thenAnswer((_) async {});
        when(localDataSource.deleteJobHiveModel(any)).thenAnswer((_) async {});

        // Act - Sync all pending jobs
        await repository.syncPendingJobs();

        // Assert
        // Verify creation flow
        verify(
          remoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
            text: 'New job text',
            additionalText: anyNamed('additionalText'),
          ),
        ).called(1);

        verify(
          localDataSource.updateJobSyncStatus(localId1, SyncStatus.synced),
        ).called(1);

        // Verify update flow
        verify(
          remoteDataSource.updateJob(
            jobId: serverId2,
            updates: anyNamed('updates'),
          ),
        ).called(1);

        verify(
          localDataSource.updateJobSyncStatus(localId2, SyncStatus.synced),
        ).called(1);

        // Verify deletion flow
        verify(remoteDataSource.deleteJob(serverId3)).called(1);
        verify(localDataSource.deleteJobHiveModel(localId3)).called(1);
        verify(fileSystem.deleteFile('/path/audio3.mp3')).called(1);
      },
    );

    test('should detect and handle server-side deletions', () async {
      // Arrange
      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      // Create test data - we have 3 jobs locally
      final localId1 = 'local-id-1';
      final localId2 = 'local-id-2';
      final localId3 = 'local-id-3'; // This one will be "missing" from server

      final serverId1 = 'server-id-1';
      final serverId2 = 'server-id-2';
      final serverId3 = 'server-id-3'; // This server ID will be missing

      // Local jobs with synced status
      final localSyncedJobs = [
        createJobHiveModel(
          localId: localId1,
          serverId: serverId1,
          text: 'Job 1',
          audioFilePath: '/path/audio1.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: nowIso,
        ),
        createJobHiveModel(
          localId: localId2,
          serverId: serverId2,
          text: 'Job 2',
          audioFilePath: '/path/audio2.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: nowIso,
        ),
        createJobHiveModel(
          localId: localId3,
          serverId: serverId3,
          text: 'Job 3 (deleted on server)',
          audioFilePath: '/path/audio3.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: nowIso,
        ),
      ];

      // Server only returns 2 jobs (job3 is missing/deleted)
      final serverJobs = [
        createJobEntity(
          localId: localId1, // Repository will match by serverId
          serverId: serverId1,
          text: 'Job 1',
          audioFilePath: '/path/audio1.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: now,
        ),
        createJobEntity(
          localId: localId2, // Repository will match by serverId
          serverId: serverId2,
          text: 'Job 2',
          audioFilePath: '/path/audio2.mp3',
          syncStatus: SyncStatus.synced,
          createdAt: now,
        ),
        // serverId3 is missing
      ];

      // Mock remote data source to return just 2 jobs
      when(remoteDataSource.fetchJobs()).thenAnswer((_) async => serverJobs);

      // Mock local data source to return synced jobs
      when(
        localDataSource.getSyncedJobHiveModels(),
      ).thenAnswer((_) async => localSyncedJobs);

      // Mock getting all jobs (needed for getJobs initial check)
      when(
        localDataSource.getAllJobHiveModels(),
      ).thenAnswer((_) async => localSyncedJobs);

      // Mock file deletion
      when(
        fileSystem.deleteFile('/path/audio3.mp3'),
      ).thenAnswer((_) async => true);

      // Mock job deletion
      when(
        localDataSource.deleteJobHiveModel(localId3),
      ).thenAnswer((_) async {});

      // Mock save operations for the valid jobs
      when(
        localDataSource.saveJobHiveModels(any),
      ).thenAnswer((_) async => true);

      // Mock last fetch time
      when(
        localDataSource.getLastFetchTime(),
      ).thenAnswer((_) async => DateTime.now().subtract(Duration(hours: 1)));

      // Act - Get jobs which triggers server comparison
      final result = await repository.getJobs();

      // Assert
      // Should delete the job missing from server
      verify(localDataSource.deleteJobHiveModel(localId3)).called(1);
      verify(fileSystem.deleteFile('/path/audio3.mp3')).called(1);

      // Should save the remaining valid jobs
      verify(localDataSource.saveJobHiveModels(any)).called(1);

      // Result should contain only the valid jobs
      result.fold((failure) => throw Exception('getJobs failed: $failure'), (
        jobs,
      ) {
        expect(jobs.length, equals(2));
        expect(
          jobs.any((job) => job.serverId == serverId3),
          isFalse,
          reason: 'Deleted job should not be in results',
        );
      });
    });

    test('should handle network failures during sync', () async {
      // Arrange
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final localId = 'local-uuid-network-fail';

      // Create a pending job
      final pendingJob = createJobHiveModel(
        localId: localId,
        serverId: null,
        text: 'Job with network fail',
        audioFilePath: '/path/network-fail.mp3',
        syncStatus: SyncStatus.pending,
        createdAt: nowIso,
      );

      // Create a job with error status
      final pendingJobWithError = createJobHiveModel(
        localId: localId,
        serverId: null,
        text: 'Job with network fail',
        audioFilePath: '/path/network-fail.mp3',
        syncStatus: SyncStatus.error,
        createdAt: nowIso,
      );

      // Create a synced job for successful retry
      final syncedJob = createJobEntity(
        localId: localId,
        serverId: 'retry-succeeded-id',
        text: 'Job with network fail',
        audioFilePath: '/path/network-fail.mp3',
        syncStatus: SyncStatus.synced,
        createdAt: now,
      );

      // First phase: network failure
      // Setup pending jobs to sync
      when(
        localDataSource.getJobsToSync(),
      ).thenAnswer((_) async => [pendingJob]);

      // Simulate network failure
      when(
        remoteDataSource.createJob(
          userId: anyNamed('userId'),
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
          additionalText: anyNamed('additionalText'),
        ),
      ).thenThrow(NetworkFailure());

      // Mock status update
      when(
        localDataSource.updateJobSyncStatus(localId, SyncStatus.error),
      ).thenAnswer((_) async {});

      // Act - First sync attempt with network failure
      await repository.syncPendingJobs();

      // Assert
      // Should mark job as error, not delete it
      verify(
        localDataSource.updateJobSyncStatus(localId, SyncStatus.error),
      ).called(1);
      verifyNever(localDataSource.deleteJobHiveModel(any));

      // Second phase: successful retry
      // First reset all mocks
      reset(localDataSource);
      reset(remoteDataSource);

      // Setup new mocks for retry phase
      when(
        localDataSource.getJobsToSync(),
      ).thenAnswer((_) async => [pendingJobWithError]);

      when(
        localDataSource.updateJobSyncStatus(localId, SyncStatus.synced),
      ).thenAnswer((_) async {});

      // This time the network works
      when(
        remoteDataSource.createJob(
          userId: anyNamed('userId'),
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
          additionalText: anyNamed('additionalText'),
        ),
      ).thenAnswer((_) async => syncedJob);

      // Act - Second sync attempt with successful network
      await repository.syncPendingJobs();

      // Assert successful retry
      verify(
        remoteDataSource.createJob(
          userId: anyNamed('userId'),
          audioFilePath: anyNamed('audioFilePath'),
          text: anyNamed('text'),
          additionalText: anyNamed('additionalText'),
        ),
      ).called(1);

      verify(
        localDataSource.updateJobSyncStatus(localId, SyncStatus.synced),
      ).called(1);
    });

    test('should handle API errors during sync', () async {
      // Arrange
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final localId = 'local-uuid-api-error';
      final serverId = 'server-id-api-error';

      // Create a pending job that already has a serverId (update case)
      final pendingUpdateJob = createJobHiveModel(
        localId: localId,
        serverId: serverId,
        text: 'Job with API error',
        audioFilePath: '/path/api-error.mp3',
        syncStatus: SyncStatus.pending,
        createdAt: nowIso,
      );

      // Setup pending jobs to sync
      when(
        localDataSource.getJobsToSync(),
      ).thenAnswer((_) async => [pendingUpdateJob]);

      // Simulate API error (like a 500 status code)
      when(
        remoteDataSource.updateJob(
          jobId: anyNamed('jobId'),
          updates: anyNamed('updates'),
        ),
      ).thenThrow(ServerFailure());

      // Mock error status update
      when(
        localDataSource.updateJobSyncStatus(localId, SyncStatus.error),
      ).thenAnswer((_) async {});

      // Act
      await repository.syncPendingJobs();

      // Assert
      // Should mark job as error, not delete it
      verify(
        localDataSource.updateJobSyncStatus(localId, SyncStatus.error),
      ).called(1);
      verifyNever(localDataSource.deleteJobHiveModel(any));
    });

    test('should handle file system errors during job deletion', () async {
      // Arrange
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final localId = 'local-uuid-fs-error';
      final serverId = 'server-id-fs-error';
      final audioPath = '/path/filesystem-error.mp3';

      // Create a job pending deletion
      final pendingDeletionJob = createJobHiveModel(
        localId: localId,
        serverId: serverId,
        text: 'Job with file system error on delete',
        audioFilePath: audioPath,
        syncStatus: SyncStatus.pendingDeletion,
        createdAt: nowIso,
      );

      // Setup pending jobs to sync
      when(
        localDataSource.getJobsToSync(),
      ).thenAnswer((_) async => [pendingDeletionJob]);

      // Successful API deletion
      when(
        remoteDataSource.deleteJob(serverId),
      ).thenAnswer((_) => Future<Unit>.value(unit));

      // Successful DB deletion
      when(
        localDataSource.deleteJobHiveModel(localId),
      ).thenAnswer((_) async {});

      // Failed file deletion
      when(
        fileSystem.deleteFile(audioPath),
      ).thenThrow(FileSystemException('File not found or permission denied'));

      // Act
      await repository.syncPendingJobs();

      // Assert
      // Should still delete from API and local DB even if file deletion fails
      verify(remoteDataSource.deleteJob(serverId)).called(1);
      verify(localDataSource.deleteJobHiveModel(localId)).called(1);
      verify(fileSystem.deleteFile(audioPath)).called(1);

      // No error status update should happen since the job is being deleted anyway
      verifyNever(localDataSource.updateJobSyncStatus(any, any));
    });
  });
}
