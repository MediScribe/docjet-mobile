import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'delete_job_test.mocks.dart';

// Generate mocks for the dependencies
@GenerateNiceMocks([
  MockSpec<JobLocalDataSource>(),
  MockSpec<JobRemoteDataSource>(),
  MockSpec<FileSystem>(), // Use FileSystem, not FileSystemService
  MockSpec<Uuid>(),
])
void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockFileSystem mockFileSystemService; // Use MockFileSystem
  late MockUuid mockUuid;
  late JobRepositoryImpl repository;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockFileSystemService = MockFileSystem(); // Use MockFileSystem
    mockUuid = MockUuid();
    repository = JobRepositoryImpl(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      fileSystemService: mockFileSystemService, // Pass MockFileSystem
      uuid: mockUuid,
    );
  });

  const tLocalId = 'test-local-id';
  const tServerId = 'test-server-id';
  final tNow = DateTime.now();
  final tNowString = tNow.toIso8601String();

  final tSyncedJobHiveModel = JobHiveModel(
    localId: tLocalId,
    serverId: tServerId,
    createdAt: tNowString, // Use ISO String
    updatedAt: tNowString, // Use ISO String
    text: 'Synced job text',
    audioFilePath: '/path/to/synced/audio.mp3',
    status: JobStatus.completed.index, // Use index
    syncStatus: SyncStatus.synced.index, // Use index
  );

  final tUnsyncedJobHiveModel = JobHiveModel(
    localId: tLocalId,
    serverId: null, // Unsynced job
    createdAt: tNowString, // Use ISO String
    updatedAt: tNowString, // Use ISO String
    text: 'Unsynced job text',
    audioFilePath: '/path/to/unsynced/audio.mp3',
    // Assuming transcribing exists as a status between pending and completed
    status: JobStatus.transcribing.index, // Use index and a valid status
    syncStatus: SyncStatus.pending.index, // Use index
  );

  group('deleteJob', () {
    test(
      'should get job from local data source, set syncStatus to pendingDeletion, and save it back - Synced Job',
      () async {
        // Arrange
        // Manually create the expected model since copyWith might not exist
        final expectedUpdatedModel = JobHiveModel(
          localId: tSyncedJobHiveModel.localId,
          serverId: tSyncedJobHiveModel.serverId,
          createdAt: tSyncedJobHiveModel.createdAt,
          // Assume updatedAt is updated by the save method, don't check it strictly here
          updatedAt: tSyncedJobHiveModel.updatedAt,
          text: tSyncedJobHiveModel.text,
          audioFilePath: tSyncedJobHiveModel.audioFilePath,
          status: tSyncedJobHiveModel.status,
          syncStatus:
              SyncStatus.pendingDeletion.index, // Set to pendingDeletion
        );

        when(
          mockLocalDataSource.getJobHiveModelById(any),
        ).thenAnswer((_) async => tSyncedJobHiveModel); // Return model directly
        when(
          mockLocalDataSource.saveJobHiveModel(any),
        ).thenAnswer((_) async => const Right(null)); // Simulate success

        // Act
        final result = await repository.deleteJob(tLocalId);

        // Assert
        expect(result, isA<Right<dynamic, Unit>>()); // Expect Right(unit)
        verify(mockLocalDataSource.getJobHiveModelById(tLocalId)).called(1);
        // Capture the argument passed to saveJobHiveModel
        final captured =
            verify(
                  mockLocalDataSource.saveJobHiveModel(captureAny),
                ).captured.single
                as JobHiveModel;
        // Check only the status, allow other fields like updatedAt to differ if the implementation updates them
        expect(captured.localId, expectedUpdatedModel.localId);
        expect(captured.serverId, expectedUpdatedModel.serverId);
        expect(captured.createdAt, expectedUpdatedModel.createdAt);
        expect(captured.text, expectedUpdatedModel.text);
        expect(captured.audioFilePath, expectedUpdatedModel.audioFilePath);
        expect(captured.status, expectedUpdatedModel.status);
        expect(captured.syncStatus, expectedUpdatedModel.syncStatus);

        // expect(captured, expectedUpdatedModel); // Compare the whole object - REVERTED
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
        verifyZeroInteractions(mockFileSystemService);
        verifyZeroInteractions(mockUuid);
      },
    );

    test(
      'should get job from local data source, set syncStatus to pendingDeletion, and save it back - Unsynced Job',
      () async {
        // Arrange
        // Manually create the expected model
        final expectedUpdatedModel = JobHiveModel(
          localId: tUnsyncedJobHiveModel.localId,
          serverId: tUnsyncedJobHiveModel.serverId,
          createdAt: tUnsyncedJobHiveModel.createdAt,
          updatedAt: tUnsyncedJobHiveModel.updatedAt,
          text: tUnsyncedJobHiveModel.text,
          audioFilePath: tUnsyncedJobHiveModel.audioFilePath,
          status: tUnsyncedJobHiveModel.status,
          syncStatus:
              SyncStatus.pendingDeletion.index, // Set to pendingDeletion
        );

        when(mockLocalDataSource.getJobHiveModelById(any)).thenAnswer(
          (_) async => tUnsyncedJobHiveModel,
        ); // Return model directly
        when(
          mockLocalDataSource.saveJobHiveModel(any),
        ).thenAnswer((_) async => const Right(null));

        // Act
        final result = await repository.deleteJob(tLocalId);

        // Assert
        expect(result, isA<Right<dynamic, Unit>>()); // Expect Right(unit)
        verify(mockLocalDataSource.getJobHiveModelById(tLocalId)).called(1);
        final captured =
            verify(
                  mockLocalDataSource.saveJobHiveModel(captureAny),
                ).captured.single
                as JobHiveModel;
        // Check relevant fields, excluding updatedAt
        expect(captured.localId, expectedUpdatedModel.localId);
        expect(captured.serverId, expectedUpdatedModel.serverId);
        expect(captured.createdAt, expectedUpdatedModel.createdAt);
        // expect(captured.updatedAt, expectedUpdatedModel.updatedAt); // Exclude updatedAt
        expect(captured.text, expectedUpdatedModel.text);
        expect(captured.audioFilePath, expectedUpdatedModel.audioFilePath);
        expect(captured.status, expectedUpdatedModel.status);
        expect(captured.syncStatus, expectedUpdatedModel.syncStatus);

        // expect(captured, expectedUpdatedModel); // Compare the whole object - REVERTED
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
        verifyZeroInteractions(mockFileSystemService);
        verifyZeroInteractions(mockUuid);
      },
    );

    test(
      'should return failure when job is not found in local data source',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getJobHiveModelById(any),
        ).thenAnswer((_) async => null); // Return null for not found

        // Act
        final result = await repository.deleteJob(tLocalId);

        // Assert
        expect(result, isA<Left<Failure, Unit>>()); // Check for Left
        result.fold(
          (failure) => expect(
            failure,
            isA<CacheFailure>(),
          ), // Check type is CacheFailure
          (_) => fail('Expected Left, but got Right'),
        );
        verify(mockLocalDataSource.getJobHiveModelById(tLocalId)).called(1);
        verifyNever(mockLocalDataSource.saveJobHiveModel(any));
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
        verifyZeroInteractions(mockFileSystemService);
        verifyZeroInteractions(mockUuid);
      },
    );

    test('should return failure when saving job fails', () async {
      // Arrange
      when(
        mockLocalDataSource.getJobHiveModelById(any),
      ).thenAnswer((_) async => tSyncedJobHiveModel); // Return model directly
      when(mockLocalDataSource.saveJobHiveModel(any)).thenThrow(
        CacheException('Failed to save job'),
      ); // Throw exception for save failure

      // Act
      final result = await repository.deleteJob(tLocalId);

      // Assert
      expect(result, isA<Left<Failure, Unit>>()); // Check for Left
      result.fold(
        (failure) =>
            expect(failure, isA<CacheFailure>()), // Check type is CacheFailure
        (_) => fail('Expected Left, but got Right'),
      );
      verify(mockLocalDataSource.getJobHiveModelById(tLocalId)).called(1);
      verify(
        mockLocalDataSource.saveJobHiveModel(any),
      ).called(1); // It was called
      verifyNoMoreInteractions(mockLocalDataSource);
      verifyZeroInteractions(mockRemoteDataSource);
      verifyZeroInteractions(mockFileSystemService);
      verifyZeroInteractions(mockUuid);
    });
  });
}
