import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for the dependencies
@GenerateMocks([JobLocalDataSource, JobRemoteDataSource])
import 'job_reader_service_test.mocks.dart';

void main() {
  late JobReaderService service;
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    service = JobReaderService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
    );
  });

  // Sample Job Entity data for testing expectations
  final tJob = Job(
    localId: 'test-local-id',
    serverId: 'test-server-id',
    userId: 'test-user-id',
    // TODO: Use the correct initial/pending status once JobStatus is defined/stable
    status: JobStatus.values[0], // Use the first value as a placeholder
    syncStatus: SyncStatus.synced,
    displayTitle: 'Test Job Title',
    audioFilePath: '/path/to/test.mp3',
    createdAt: DateTime(2023, 1, 1, 10, 0, 0),
    updatedAt: DateTime(2023, 1, 1, 11, 0, 0),
    displayText: 'Test display text',
    text: 'Test text',
  );
  final tJobsList = [tJob];

  // Sample JobHiveModel data for mocking local data source
  final tJobHiveModel = JobHiveModel(
    localId: 'test-local-id',
    serverId: 'test-server-id',
    userId: 'test-user-id',
    status: JobStatus.values[0].index, // Store index
    syncStatus: SyncStatus.synced.index, // Store index
    displayTitle: 'Test Job Title',
    audioFilePath: '/path/to/test.mp3',
    createdAt:
        DateTime(2023, 1, 1, 10, 0, 0).toIso8601String(), // Store as string
    updatedAt:
        DateTime(2023, 1, 1, 11, 0, 0).toIso8601String(), // Store as string
    displayText: 'Test display text',
    text: 'Test text',
  );
  final tJobHiveModelsList = [tJobHiveModel];

  group('JobReaderService', () {
    group('getJobs', () {
      test(
        'should return list of Job entities from local data source when call is successful',
        () async {
          // Arrange
          // Mock the local data source to return Hive models
          when(
            mockLocalDataSource.getAllJobHiveModels(),
          ).thenAnswer((_) async => tJobHiveModelsList);
          // Act
          final result = await service.getJobs();
          // Assert
          // Expect the service to return the mapped Job entities
          // Explicitly type the Right to match the function signature
          expect(result, isA<Right<Failure, List<Job>>>());
          expect(result.getOrElse(() => []), tJobsList);
          // Verify the correct local data source method was called
          verify(mockLocalDataSource.getAllJobHiveModels());
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(
            mockRemoteDataSource,
          ); // Ensure remote wasn't called
        },
      );

      test(
        'should return CacheFailure when the call to local data source is unsuccessful',
        () async {
          // Arrange
          // Mock the local data source method to throw
          when(
            mockLocalDataSource.getAllJobHiveModels(),
          ).thenThrow(CacheException('Failed to fetch jobs'));
          // Act
          final result = await service.getJobs();
          // Assert
          expect(result, Left(CacheFailure()));
          // Verify the correct local data source method was called
          verify(mockLocalDataSource.getAllJobHiveModels());
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
        },
      );
    });

    // Tests for getJobById
    group('getJobById', () {
      const tLocalId = 'test-local-id';

      test(
        'should return Job entity when local data source finds the job',
        () async {
          // Arrange
          when(
            mockLocalDataSource.getJobHiveModelById(tLocalId),
          ).thenAnswer((_) async => tJobHiveModel);
          // Act
          final result = await service.getJobById(tLocalId);
          // Assert
          expect(result, isA<Right<Failure, Job>>());
          expect(result.getOrElse(() => throw 'Test failed'), tJob);
          verify(mockLocalDataSource.getJobHiveModelById(tLocalId));
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
        },
      );

      test(
        'should return CacheFailure when local data source does not find the job (returns null)',
        () async {
          // Arrange
          when(
            mockLocalDataSource.getJobHiveModelById(tLocalId),
          ).thenAnswer((_) async => null);
          // Act
          final result = await service.getJobById(tLocalId);
          // Assert
          expect(result, Left(CacheFailure('Job with ID $tLocalId not found')));
          verify(mockLocalDataSource.getJobHiveModelById(tLocalId));
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
        },
      );

      test(
        'should return CacheFailure when the call to local data source throws CacheException',
        () async {
          // Arrange
          when(
            mockLocalDataSource.getJobHiveModelById(tLocalId),
          ).thenThrow(CacheException('DB Error'));
          // Act
          final result = await service.getJobById(tLocalId);
          // Assert
          expect(result, Left(CacheFailure()));
          verify(mockLocalDataSource.getJobHiveModelById(tLocalId));
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
        },
      );
    });

    // Tests for getJobsByStatus
    group('getJobsByStatus', () {
      // Create some jobs with different statuses for filtering
      // Manually create models since JobHiveModel might not have copyWith
      final tPendingJobHiveModel = JobHiveModel(
        localId: 'test-local-id-pending',
        serverId: tJobHiveModel.serverId,
        userId: tJobHiveModel.userId,
        status: tJobHiveModel.status,
        syncStatus: SyncStatus.pending.index, // The important part
        displayTitle: tJobHiveModel.displayTitle,
        audioFilePath: tJobHiveModel.audioFilePath,
        createdAt: tJobHiveModel.createdAt,
        updatedAt: tJobHiveModel.updatedAt,
        displayText: tJobHiveModel.displayText,
        text: tJobHiveModel.text,
      );
      final tSyncedJobHiveModel = JobHiveModel(
        localId: 'test-local-id-synced',
        serverId: tJobHiveModel.serverId,
        userId: tJobHiveModel.userId,
        status: tJobHiveModel.status,
        syncStatus: SyncStatus.synced.index, // The important part
        displayTitle: tJobHiveModel.displayTitle,
        audioFilePath: tJobHiveModel.audioFilePath,
        createdAt: tJobHiveModel.createdAt,
        updatedAt: tJobHiveModel.updatedAt,
        displayText: tJobHiveModel.displayText,
        text: tJobHiveModel.text,
      );
      final tErrorJobHiveModel = JobHiveModel(
        localId: 'test-local-id-error',
        serverId: tJobHiveModel.serverId,
        userId: tJobHiveModel.userId,
        status: tJobHiveModel.status,
        syncStatus: SyncStatus.error.index, // The important part
        displayTitle: tJobHiveModel.displayTitle,
        audioFilePath: tJobHiveModel.audioFilePath,
        createdAt: tJobHiveModel.createdAt,
        updatedAt: tJobHiveModel.updatedAt,
        displayText: tJobHiveModel.displayText,
        text: tJobHiveModel.text,
      );
      final tAllHiveModels = [
        tPendingJobHiveModel,
        tSyncedJobHiveModel,
        tErrorJobHiveModel,
      ];

      // Corresponding Job entities
      final tPendingJob = JobMapper.fromHiveModel(tPendingJobHiveModel);

      test('should return only jobs with the specified SyncStatus', () async {
        // Arrange
        when(
          mockLocalDataSource.getAllJobHiveModels(),
        ).thenAnswer((_) async => tAllHiveModels);
        // Act
        final result = await service.getJobsByStatus(SyncStatus.pending);
        // Assert
        expect(result, isA<Right<Failure, List<Job>>>());
        expect(result.getOrElse(() => []), [
          tPendingJob,
        ]); // Only the pending job
        verify(mockLocalDataSource.getAllJobHiveModels());
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
      });

      test('should return empty list if no jobs match the status', () async {
        // Arrange
        when(mockLocalDataSource.getAllJobHiveModels()).thenAnswer(
          (_) async => [tSyncedJobHiveModel, tErrorJobHiveModel],
        ); // No pending
        // Act
        final result = await service.getJobsByStatus(SyncStatus.pending);
        // Assert
        expect(result, isA<Right<Failure, List<Job>>>());
        expect(result.getOrElse(() => []), isEmpty);
        verify(mockLocalDataSource.getAllJobHiveModels());
        verifyNoMoreInteractions(mockLocalDataSource);
        verifyZeroInteractions(mockRemoteDataSource);
      });

      test(
        'should return CacheFailure when the call to local data source throws CacheException',
        () async {
          // Arrange
          when(
            mockLocalDataSource.getAllJobHiveModels(),
          ).thenThrow(CacheException('DB Error'));
          // Act
          final result = await service.getJobsByStatus(SyncStatus.pending);
          // Assert
          expect(result, Left(CacheFailure()));
          verify(mockLocalDataSource.getAllJobHiveModels());
          verifyNoMoreInteractions(mockLocalDataSource);
          verifyZeroInteractions(mockRemoteDataSource);
        },
      );
    });
  });
}
