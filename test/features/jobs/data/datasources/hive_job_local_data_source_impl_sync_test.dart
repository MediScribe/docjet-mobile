import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';

import 'hive_job_local_data_source_impl_sync_test.mocks.dart';

// Generate mocks for HiveInterface and Box
@GenerateMocks([HiveInterface, Box])
// Needs to be outside the main function
// We need a separate mock class for JobHiveModel because it extends HiveObject
// and we need to mock its methods like save() and properties like isInBox.
@GenerateMocks([], customMocks: [MockSpec<JobHiveModel>(as: #MockJobHiveModel)])
void main() {
  late MockHiveInterface mockHiveInterface;
  late MockBox<JobHiveModel> mockJobsBox;
  late HiveJobLocalDataSourceImpl dataSource;

  // Helper to create test models
  JobHiveModel createTestJobHiveModel({
    required String localId,
    required SyncStatus syncStatus,
    String? serverId,
    int? retryCount,
    String? lastSyncAttemptAt,
    JobStatus status = JobStatus.submitted,
    String userId = 'test-user',
    String createdAt = '2023-01-01T10:00:00Z',
    String? updatedAt,
  }) {
    return JobHiveModel(
      localId: localId,
      serverId: serverId,
      syncStatus: syncStatus.index,
      retryCount: retryCount,
      lastSyncAttemptAt: lastSyncAttemptAt,
      status: status.index,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  setUp(() {
    mockHiveInterface = MockHiveInterface();
    mockJobsBox = MockBox<JobHiveModel>();
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHiveInterface);

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

    // Default behavior for get/put/delete for update tests
    when(mockJobsBox.get(any)).thenReturn(null);
    when(
      mockJobsBox.put(any, any),
    ).thenAnswer((_) async => Future<void>.value());
    when(mockJobsBox.delete(any)).thenAnswer((_) async => Future<void>.value());
  });

  group('getJobsToSync', () {
    final pendingModel = createTestJobHiveModel(
      localId: '1',
      syncStatus: SyncStatus.pending,
    );
    final syncedModel = createTestJobHiveModel(
      localId: '2',
      syncStatus: SyncStatus.synced,
      serverId: 'server-2',
    );
    final errorModel = createTestJobHiveModel(
      localId: '3',
      syncStatus: SyncStatus.error,
      retryCount: 1,
    );

    final allModels = [pendingModel, syncedModel, errorModel];
    final expectedPendingJob = JobMapper.fromHiveModel(pendingModel);

    test(
      'should return a list of Job entities with pending sync status',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(allModels);

        // Act
        final result = await dataSource.getJobsToSync();

        // Assert
        expect(result, isA<List<Job>>());
        expect(result.length, 1);
        expect(result.first.localId, expectedPendingJob.localId);
        expect(result.first.syncStatus, SyncStatus.pending);
        verify(mockJobsBox.values);
      },
    );

    test('should return an empty list when no jobs are pending sync', () async {
      // Arrange
      when(mockJobsBox.values).thenReturn([syncedModel, errorModel]);

      // Act
      final result = await dataSource.getJobsToSync();

      // Assert
      expect(result, isEmpty);
      verify(mockJobsBox.values);
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive failed'));
      // Act
      final call = dataSource.getJobsToSync();
      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.values);
    });
  });

  group('updateJobSyncStatus', () {
    const tJobId = 'job-1';
    const tInitialStatus = SyncStatus.pending;
    const tTargetStatus = SyncStatus.synced;

    // Mock HiveObject for save() method test
    final mockHiveObjectModel =
        MockJobHiveModel(); // Needs separate mock class setup

    setUp(() {
      // Specific setup for this group if needed
      when(mockHiveObjectModel.localId).thenReturn(tJobId);
      when(mockHiveObjectModel.syncStatus).thenReturn(tInitialStatus.index);
      // Ensure isInBox is true for the save() path
      when(mockHiveObjectModel.isInBox).thenReturn(true);
      // Mock the save method for HiveObject
      when(
        mockHiveObjectModel.save(),
      ).thenAnswer((_) async => Future<void>.value());
    });

    test(
      'should update sync status of the job in the box using model.save()',
      () async {
        // Arrange
        // Ensure the box returns the *mock* HiveObject when get is called
        when(mockJobsBox.get(tJobId)).thenReturn(mockHiveObjectModel);

        // Act
        await dataSource.updateJobSyncStatus(tJobId, tTargetStatus);

        // Assert
        // Verify that the status was set on the mock object
        verify(mockHiveObjectModel.syncStatus = tTargetStatus.index);
        // Verify that save() was called on the mock object
        verify(mockHiveObjectModel.save());
        // Verify get was called on the box
        verify(mockJobsBox.get(tJobId));
        // Verify put was NOT called on the box (because save() was used)
        verifyNever(mockJobsBox.put(any, any));
      },
    );

    test(
      'should update sync status using box.put() if model is not in box',
      () async {
        // Arrange
        final notInBoxModel = createTestJobHiveModel(
          localId: tJobId,
          syncStatus: tInitialStatus,
        );
        // Simulate model.isInBox returning false implicitly by returning the plain model
        when(mockJobsBox.get(tJobId)).thenReturn(notInBoxModel);

        // Act
        await dataSource.updateJobSyncStatus(tJobId, tTargetStatus);

        // Assert
        // Verify get was called
        verify(mockJobsBox.get(tJobId));
        // Verify put WAS called WITHOUT prefix for capture
        final verificationResult = verify(
          mockJobsBox.put(tJobId, captureThat(isA<JobHiveModel>())),
        );
        // Check that the captured model has the updated status
        expect(
          verificationResult.captured.single.syncStatus,
          tTargetStatus.index,
        );
        // Verify save() was NOT called
        // We can't directly verify save() wasn't called on the *original* model instance easily with mockito,
        // but verifying put() was called is the main goal here.
      },
    );

    test('should throw CacheException if job with id is not found', () async {
      // Arrange
      when(mockJobsBox.get(tJobId)).thenReturn(null);

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, tTargetStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tJobId));
      verifyNever(mockJobsBox.put(any, any));
      // Verify save() was not called on our mock object
      verifyNever(mockHiveObjectModel.save());
    });

    test('should throw CacheException if Hive get fails', () async {
      // Arrange
      when(mockJobsBox.get(tJobId)).thenThrow(Exception('Hive get failed'));

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, tTargetStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tJobId));
      verifyNever(mockJobsBox.put(any, any));
      verifyNever(mockHiveObjectModel.save());
    });

    test('should throw CacheException if model.save() fails', () async {
      // Arrange
      when(mockJobsBox.get(tJobId)).thenReturn(mockHiveObjectModel);
      // Make save() throw an error
      when(mockHiveObjectModel.save()).thenThrow(Exception('Hive save failed'));

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, tTargetStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tJobId));
      verify(mockHiveObjectModel.save()); // Verify save was attempted
      verifyNever(mockJobsBox.put(any, any));
    });

    test('should throw CacheException if box.put() fails', () async {
      // Arrange
      final notInBoxModel = createTestJobHiveModel(
        localId: tJobId,
        syncStatus: tInitialStatus,
      );
      when(mockJobsBox.get(tJobId)).thenReturn(notInBoxModel);
      // Make put throw an error
      when(mockJobsBox.put(any, any)).thenThrow(Exception('Hive put failed'));

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, tTargetStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tJobId));
      verify(mockJobsBox.put(any, any)); // Verify put was attempted
    });
  });

  group('getSyncedJobs', () {
    final pendingModel = createTestJobHiveModel(
      localId: '1',
      syncStatus: SyncStatus.pending,
    );
    final syncedModelWithServerId = createTestJobHiveModel(
      localId: '2',
      syncStatus: SyncStatus.synced,
      serverId: 'server-2',
    );
    final syncedModelNoServerId = createTestJobHiveModel(
      localId: '3',
      syncStatus: SyncStatus.synced,
      serverId: null,
    ); // Should be excluded
    final errorModel = createTestJobHiveModel(
      localId: '4',
      syncStatus: SyncStatus.error,
      retryCount: 1,
    );

    final allModels = [
      pendingModel,
      syncedModelWithServerId,
      syncedModelNoServerId,
      errorModel,
    ];
    final expectedSyncedJob = JobMapper.fromHiveModel(syncedModelWithServerId);

    test(
      'should return list of Job entities with synced status and non-null serverId',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(allModels);

        // Act
        final result = await dataSource.getSyncedJobs(); // Use new method name

        // Assert
        expect(result, isA<List<Job>>());
        expect(result.length, 1);
        expect(result.first.localId, expectedSyncedJob.localId);
        expect(result.first.serverId, expectedSyncedJob.serverId);
        expect(result.first.syncStatus, SyncStatus.synced);
        verify(mockJobsBox.values);
      },
    );

    test(
      'should return empty list if no jobs are synced with serverId',
      () async {
        // Arrange
        when(
          mockJobsBox.values,
        ).thenReturn([pendingModel, syncedModelNoServerId, errorModel]);

        // Act
        final result = await dataSource.getSyncedJobs();

        // Assert
        expect(result, isEmpty);
        verify(mockJobsBox.values);
      },
    );

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive failed'));

      // Act
      final call = dataSource.getSyncedJobs();

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.values);
    });
  });
}
