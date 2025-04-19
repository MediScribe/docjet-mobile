import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

import 'job_sync_service_test.mocks.dart'; // Import generated mocks

@GenerateMocks([
  JobLocalDataSource,
  JobRemoteDataSource,
  NetworkInfo,
  FileSystem,
])
void main() {
  late JobSyncService service;
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockFileSystem mockFileSystem;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockFileSystem = MockFileSystem();

    service = JobSyncService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      networkInfo: mockNetworkInfo,
      fileSystem: mockFileSystem,
    );
  });

  // Sample data for a new pending job
  final tPendingJobNew = Job(
    localId: 'pendingNewJob1',
    userId: 'user123', // Assuming userId is needed or derived elsewhere
    status: JobStatus.created,
    syncStatus: SyncStatus.pending,
    displayTitle: 'New Pending Job Sync Test',
    audioFilePath: '/local/new_pending.mp3',
    text: 'Some initial text',
    additionalText: 'Some additional text',
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    serverId: null, // Explicitly null for a new job
  );

  // Sample data for the job after successful sync
  // Server might update status, serverId, and updatedAt
  final tSyncedJobFromServer = tPendingJobNew.copyWith(
    serverId: 'serverGeneratedId123',
    syncStatus: SyncStatus.synced, // Status becomes synced after API call
    // Potentially other fields updated by the server, like status or updatedAt
    updatedAt: DateTime.now(),
  );

  // Sample data for an existing job with pending updates
  final tExistingJobPendingUpdate = Job(
    localId: 'existingJob1-local',
    serverId: 'existingJob1-server', // Has a server ID
    userId: 'user456',
    status: JobStatus.transcribing, // Use a valid status
    syncStatus: SyncStatus.pending, // Marked as pending
    displayTitle: 'Updated Job Title Locally',
    audioFilePath: '/local/existing.mp3',
    text: 'Updated text locally',
    additionalText: null,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(
      const Duration(hours: 1),
    ), // Local update time
  );

  // Sample data for the job after successful update sync
  // Server might return slightly different data or just confirm the update
  final tUpdatedJobFromServer = tExistingJobPendingUpdate.copyWith(
    syncStatus: SyncStatus.synced, // Status becomes synced
    updatedAt: DateTime.now(), // Server sets the update timestamp
  );

  group('syncPendingJobs', () {
    test(
      'should sync NEW pending job: call remote create, save synced job locally',
      () async {
        // Arrange
        // 1. Network is connected
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);

        // 2. Local source returns the new pending job when asked for pending
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).thenAnswer((_) async => [tPendingJobNew]);

        // 3. Local source returns empty list when asked for pending deletion
        when(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).thenAnswer((_) async => []);

        // 4. Remote source successfully creates the job when syncSingleJob calls it
        // We expect syncSingleJob to be called with tPendingJobNew
        when(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).thenAnswer((_) async => tSyncedJobFromServer);

        // 5. Local source successfully saves the updated job when syncSingleJob calls it
        // ** CORRECTED MOCK RETURN VALUE: Use Future.value(unit) **
        when(
          mockLocalDataSource.saveJob(tSyncedJobFromServer),
        ).thenAnswer((_) async => unit); // Return unit directly

        // Act
        final result = await service.syncPendingJobs();

        // Assert
        // 1. Verify result is Right(unit)
        expect(result, equals(const Right(unit)));

        // 2. Verify network check happened
        verify(mockNetworkInfo.isConnected).called(1);

        // 3. Verify local source was queried for pending and pending deletion
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pending),
        ).called(1);
        verify(
          mockLocalDataSource.getJobsByStatus(SyncStatus.pendingDeletion),
        ).called(1);

        // 4. Verify remote source's createJob was called via syncSingleJob
        verify(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).called(1);

        // 5. Verify local source's saveJob was called via syncSingleJob
        verify(mockLocalDataSource.saveJob(tSyncedJobFromServer)).called(1);

        // 6. Verify no other interactions occurred for THIS job
        // (Other interactions might happen for _permanentlyDeleteJob if there were deletion jobs)
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );
        verifyNever(mockRemoteDataSource.deleteJob(any));
        verifyNever(mockFileSystem.deleteFile(any));
        // We expect saveJob, not deleteJob for a successful sync of a NEW job
        verifyNever(mockLocalDataSource.deleteJob(any));

        // Verify no more interactions
        verifyNoMoreInteractions(mockNetworkInfo);
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    // Add more tests based on sync_pending_jobs_test.dart
  });

  group('syncSingleJob', () {
    test(
      'should call remote createJob and save returned job when serverId is null',
      () async {
        // Arrange
        // Use the existing tPendingJobNew and tSyncedJobFromServer data
        when(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).thenAnswer((_) async => tSyncedJobFromServer);

        when(
          mockLocalDataSource.saveJob(tSyncedJobFromServer),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.syncSingleJob(tPendingJobNew);

        // Assert
        // 1. Expect Right(syncedJob)
        expect(result, equals(Right(tSyncedJobFromServer)));

        // 2. Verify remoteDataSource.createJob was called
        verify(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).called(1);

        // 3. Verify localDataSource.saveJob was called with the result
        verify(mockLocalDataSource.saveJob(tSyncedJobFromServer)).called(1);

        // 4. Verify no other interactions
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        // NetworkInfo and FileSystem are not used by syncSingleJob directly
        verifyZeroInteractions(mockNetworkInfo);
        verifyZeroInteractions(mockFileSystem);
      },
    );

    test(
      'should call remote updateJob and save returned job when serverId is NOT null',
      () async {
        // Arrange
        // Use the new test data tExistingJobPendingUpdate, tUpdatedJobFromServer
        when(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed('updates'), // Match any map for updates
          ),
        ).thenAnswer((_) async => tUpdatedJobFromServer);

        when(
          mockLocalDataSource.saveJob(tUpdatedJobFromServer),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.syncSingleJob(tExistingJobPendingUpdate);

        // Assert
        // 1. Expect Right(updatedJob)
        expect(result, equals(Right(tUpdatedJobFromServer)));

        // 2. Verify remoteDataSource.updateJob was called
        verify(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed(
              'updates',
            ), // Use anyNamed for map verification simplicity for now
          ),
        ).called(1);

        // 3. Verify localDataSource.saveJob was called with the result
        verify(mockLocalDataSource.saveJob(tUpdatedJobFromServer)).called(1);

        // 4. Verify remote createJob was NOT called
        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
          ),
        );
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockNetworkInfo);
        verifyZeroInteractions(mockFileSystem);
      },
    );

    test(
      'should return Left(ServerFailure) and save job with error status when remote createJob fails',
      () async {
        // Arrange
        final tException = ServerException('Network Error');
        when(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).thenThrow(tException);

        // Job data expected to be saved with error status
        final tErrorJob = tPendingJobNew.copyWith(syncStatus: SyncStatus.error);
        // Mock the saveJob call for the error case
        when(
          mockLocalDataSource.saveJob(tErrorJob),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.syncSingleJob(tPendingJobNew);

        // Assert
        // 1. Expect Left(ServerFailure) matching the format from the *specific* ServerException catch block
        expect(
          result,
          equals(Left(ServerFailure(message: tException.message))),
        );

        // 2. Verify remoteDataSource.createJob was called
        verify(
          mockRemoteDataSource.createJob(
            userId: tPendingJobNew.userId,
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        ).called(1);

        // 3. Verify localDataSource.saveJob was called with the error job
        verify(mockLocalDataSource.saveJob(tErrorJob)).called(1);

        // 4. Verify no other interactions
        verifyNever(
          mockRemoteDataSource.updateJob(
            jobId: anyNamed('jobId'),
            updates: anyNamed('updates'),
          ),
        );
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockNetworkInfo);
        verifyZeroInteractions(mockFileSystem);
      },
    );

    test(
      'should return Left(ServerFailure) and save job with error status when remote updateJob fails',
      () async {
        // Arrange
        final tException = ServerException('Update Failed');
        // Use the existing job that has a serverId
        when(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed('updates'),
          ),
        ).thenThrow(tException);

        // Job data expected to be saved with error status
        final tErrorJob = tExistingJobPendingUpdate.copyWith(
          syncStatus: SyncStatus.error,
        );
        when(
          mockLocalDataSource.saveJob(tErrorJob),
        ).thenAnswer((_) async => unit);

        // Act
        final result = await service.syncSingleJob(tExistingJobPendingUpdate);

        // Assert
        // 1. Expect Left(ServerFailure) matching the format from the ServerException catch block
        expect(
          result,
          equals(Left(ServerFailure(message: tException.message))),
        );

        // 2. Verify remoteDataSource.updateJob was called
        verify(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: anyNamed('updates'),
          ),
        ).called(1);

        // 3. Verify localDataSource.saveJob was called with the error job
        verify(mockLocalDataSource.saveJob(tErrorJob)).called(1);

        // 4. Verify no other interactions
        verifyNever(
          mockRemoteDataSource.createJob(
            userId: anyNamed('userId'),
            audioFilePath: anyNamed('audioFilePath'),
          ),
        );
        verifyNoMoreInteractions(mockRemoteDataSource);
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockNetworkInfo);
        verifyZeroInteractions(mockFileSystem);
      },
    );
  });

  group('_permanentlyDeleteJob', () {
    // Tests for _permanentlyDeleteJob helper will go here
  });
}
