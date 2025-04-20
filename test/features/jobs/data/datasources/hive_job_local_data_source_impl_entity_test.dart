import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'hive_job_local_data_source_impl_entity_test.mocks.dart';

// Generate mocks for HiveInterface and Box
@GenerateMocks([HiveInterface, Box])
void main() {
  late MockHiveInterface mockHiveInterface;
  late MockBox<JobHiveModel> mockJobsBox;
  // We don't need metadata box for these tests
  // late MockBox<dynamic> mockMetadataBox;
  late HiveJobLocalDataSourceImpl dataSource;

  setUp(() {
    mockHiveInterface = MockHiveInterface();
    mockJobsBox = MockBox<JobHiveModel>();
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHiveInterface);

    // Setup only for Jobs Box
    when(
      mockHiveInterface.isBoxOpen(HiveJobLocalDataSourceImpl.jobsBoxName),
    ).thenReturn(true);
    when(
      mockHiveInterface.box<JobHiveModel>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenReturn(mockJobsBox);
    when(
      mockHiveInterface.openBox<JobHiveModel>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenAnswer((_) async => mockJobsBox);
  });

  // --- Test Data Setup ---
  final now = DateTime.now();

  // Example JobHiveModels for testing
  final job1HiveModel = JobHiveModel(
    localId: '1',
    syncStatus: SyncStatus.pending.index,
    status: JobStatus.submitted.index,
    createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
    updatedAt: now.toIso8601String(),
    userId: 'user-123',
  );

  final job2HiveModel = JobHiveModel(
    localId: '2',
    syncStatus: SyncStatus.synced.index,
    status: JobStatus.completed.index,
    createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    updatedAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
    userId: 'user-123',
  );

  final List<JobHiveModel> tJobHiveModelList = [job1HiveModel, job2HiveModel];

  // Corresponding Job entities for testing
  final tJobList =
      tJobHiveModelList.map((model) => JobMapper.fromHiveModel(model)).toList();

  group('getJobs', () {
    test(
      'should return list of Job entities when cache call is successful',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(tJobHiveModelList);

        // Act
        final result = await dataSource.getJobs();

        // Assert
        // Compare localIds as object equality is tricky with mapper defaults
        final resultIds = result.map((j) => j.localId).toList();
        final expectedIds = tJobList.map((j) => j.localId).toList();
        expect(resultIds, equals(expectedIds));

        verify(
          mockHiveInterface.box<JobHiveModel>(
            HiveJobLocalDataSourceImpl.jobsBoxName,
          ),
        );
        verify(mockJobsBox.values);
      },
    );

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive error'));

      // Act
      final call = dataSource.getJobs();

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(
        mockHiveInterface.box<JobHiveModel>(
          HiveJobLocalDataSourceImpl.jobsBoxName,
        ),
      );
      verify(mockJobsBox.values);
    });
  });

  group('getJobById', () {
    final tJobId = '1';
    final tJobHiveModel = job1HiveModel; // Reuse from setup
    final tExpectedJob = JobMapper.fromHiveModel(tJobHiveModel);

    test('should return Job when found in cache', () async {
      // Arrange
      // Mock the underlying call to getJobHiveModelById
      when(mockJobsBox.get(tJobId)).thenReturn(tJobHiveModel);

      // Act
      final result = await dataSource.getJobById(tJobId);

      // Assert
      expect(result, equals(tExpectedJob));
      // Verify that the underlying get method was called
      verify(mockJobsBox.get(tJobId));
    });

    test('should throw CacheException when job not found', () async {
      // Arrange
      final tNotFoundId = 'not-found-id';
      when(mockJobsBox.get(tNotFoundId)).thenReturn(null);

      // Act
      final call = dataSource.getJobById(tNotFoundId);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tNotFoundId));
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      final tErrorId = 'error-id';
      when(mockJobsBox.get(tErrorId)).thenThrow(Exception('Hive error'));

      // Act
      final call = dataSource.getJobById(tErrorId);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tErrorId));
    });
  });

  group('saveJob', () {
    // Use one of the existing Job entities from setup
    final tJob = tJobList[0];
    // Create the expected Hive model that the mapper should produce
    final tExpectedHiveModel = JobMapper.toHiveModel(tJob);

    test('should map Job to JobHiveModel and call saveJobHiveModel', () async {
      // Arrange
      // Mock the underlying saveJobHiveModel call (which uses box.put)
      when(
        mockJobsBox.put(tExpectedHiveModel.localId, tExpectedHiveModel),
      ).thenAnswer((_) async => Future<void>.value());

      // Act
      final result = await dataSource.saveJob(tJob);

      // Assert
      expect(result, equals(unit)); // Should return unit on success
      // Verify that the underlying put method was called with the correct mapped model
      verify(mockJobsBox.put(tExpectedHiveModel.localId, tExpectedHiveModel));
    });

    test('should throw CacheException when saving fails', () async {
      // Arrange
      // Mock the underlying saveJobHiveModel call to throw an error
      when(
        mockJobsBox.put(tExpectedHiveModel.localId, tExpectedHiveModel),
      ).thenThrow(Exception('Hive save failed'));

      // Act
      final call = dataSource.saveJob(tJob);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.put(tExpectedHiveModel.localId, tExpectedHiveModel));
    });

    // Optional: Test for mapping errors if JobMapper.toHiveModel could throw
    // test('should throw CacheException if mapping fails', () async { ... });
  });

  group('deleteJob', () {
    final tJobId = 'job-to-delete';

    test(
      'should call deleteJobHiveModel with the correct id and return unit',
      () async {
        // Arrange
        // Mock the underlying deleteJobHiveModel call (which uses box.delete)
        when(
          mockJobsBox.delete(tJobId),
        ).thenAnswer((_) async => Future<void>.value());

        // Act
        final result = await dataSource.deleteJob(tJobId);

        // Assert
        expect(result, equals(unit)); // Should return unit on success
        // Verify that the underlying delete method was called
        verify(mockJobsBox.delete(tJobId));
      },
    );

    test('should throw CacheException when deleting fails', () async {
      // Arrange
      // Mock the underlying deleteJobHiveModel call to throw an error
      when(
        mockJobsBox.delete(tJobId),
      ).thenThrow(Exception('Hive delete failed'));

      // Act
      final call = dataSource.deleteJob(tJobId);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.delete(tJobId));
    });
  });

  group('getJobsByStatus', () {
    final tPendingStatus = SyncStatus.pending;

    // Use existing models from setup
    final pendingJobModel = job1HiveModel;
    final syncedJobModel = job2HiveModel;
    final allModels = [pendingJobModel, syncedJobModel];

    final expectedPendingJob = JobMapper.fromHiveModel(pendingJobModel);
    // final expectedSyncedJob = JobMapper.fromHiveModel(syncedJobModel);

    test(
      'should return only jobs matching the specified sync status',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(allModels);

        // Act
        final result = await dataSource.getJobsByStatus(tPendingStatus);

        // Assert
        expect(result, equals([expectedPendingJob]));
        // Compare localIds to be safe
        expect(result.first.localId, equals(expectedPendingJob.localId));
        verify(mockJobsBox.values);
      },
    );

    test('should return an empty list if no jobs match the status', () async {
      // Arrange
      when(mockJobsBox.values).thenReturn([syncedJobModel]); // Only synced

      // Act
      final result = await dataSource.getJobsByStatus(
        tPendingStatus,
      ); // Ask for pending

      // Assert
      expect(result, isEmpty);
      verify(mockJobsBox.values);
    });

    test('should return an empty list if the box is empty', () async {
      // Arrange
      when(mockJobsBox.values).thenReturn(<JobHiveModel>[]);

      // Act
      final result = await dataSource.getJobsByStatus(tPendingStatus);

      // Assert
      expect(result, isEmpty);
      verify(mockJobsBox.values);
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive error'));

      // Act
      final call = dataSource.getJobsByStatus(tPendingStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.values);
    });

    test('should retrieve jobs with pending status', () async {
      // Arrange
      final tPendingStatus = SyncStatus.pending;
      // Use existing models from setup
      final models = [
        job1HiveModel,
        job2HiveModel,
      ]; // job1 is pending, job2 is synced
      when(mockJobsBox.values).thenReturn(models);
      final expectedResult = [JobMapper.fromHiveModel(job1HiveModel)];

      // Act
      final result = await dataSource.getJobsByStatus(tPendingStatus);

      // Assert
      expect(result.length, 1);
      expect(result, equals(expectedResult));
      expect(result.first.syncStatus, tPendingStatus);
      verify(mockJobsBox.values);
    });

    test('should retrieve jobs with synced status', () async {
      // Arrange
      final tSyncedStatus = SyncStatus.synced;
      // Use existing models from setup
      final models = [
        job1HiveModel,
        job2HiveModel,
      ]; // job1 is pending, job2 is synced
      when(mockJobsBox.values).thenReturn(models);
      final expectedResult = [JobMapper.fromHiveModel(job2HiveModel)];

      // Act
      final result = await dataSource.getJobsByStatus(tSyncedStatus);

      // Assert
      expect(result.length, 1);
      expect(result, equals(expectedResult));
      expect(result.first.syncStatus, tSyncedStatus);
      verify(mockJobsBox.values);
    });
  });
}
