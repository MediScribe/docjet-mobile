import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'hive_job_local_data_source_impl_sync_test.mocks.dart';

// Generate mocks for HiveInterface and Box
@GenerateMocks([HiveInterface, Box, JobHiveModel]) // Add JobHiveModel mock
void main() {
  late MockHiveInterface mockHiveInterface;
  late MockBox<JobHiveModel> mockJobsBox;
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

  // --- Test Data ---
  final jobPending = JobHiveModel(
    localId: 'pending1',
    syncStatus: SyncStatus.pending.index,
  );
  final jobSynced = JobHiveModel(
    localId: 'synced1',
    serverId: 'server1', // Must have serverId
    syncStatus: SyncStatus.synced.index,
  );
  final jobError = JobHiveModel(
    localId: 'error1',
    syncStatus: SyncStatus.error.index,
  );
  final jobSyncedNoServerId = JobHiveModel(
    localId: 'synced2',
    serverId: null, // Missing serverId
    syncStatus: SyncStatus.synced.index,
  );

  final allJobs = [jobPending, jobSynced, jobError, jobSyncedNoServerId];

  group('getJobsToSync', () {
    test('should return only jobs with pending sync status', () async {
      // Arrange
      when(mockJobsBox.values).thenReturn(allJobs);

      // Act
      final result = await dataSource.getJobsToSync();

      // Assert
      expect(result, equals([jobPending]));
      verify(mockJobsBox.values);
    });

    test('should return empty list if no jobs are pending', () async {
      // Arrange
      when(mockJobsBox.values).thenReturn([jobSynced, jobError]);

      // Act
      final result = await dataSource.getJobsToSync();

      // Assert
      expect(result, isEmpty);
      verify(mockJobsBox.values);
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive error'));

      // Act
      final call = dataSource.getJobsToSync();

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.values);
    });
  });

  group('updateJobSyncStatus', () {
    final tJobId = 'job-to-update';
    final tStatus = SyncStatus.synced;
    // Use a MOCK JobHiveModel for verifying save() calls
    final mockJobModel = MockJobHiveModel();

    test(
      'should update the sync status and save the model via model.save()',
      () async {
        // Arrange
        // Stub the mock model's behavior
        when(mockJobModel.localId).thenReturn(tJobId);
        when(mockJobModel.isInBox).thenReturn(true); // Crucial for using save()
        when(mockJobModel.save()).thenAnswer((_) async => Future<void>.value());

        // Return the MOCK model when the box is queried
        when(mockJobsBox.get(tJobId)).thenReturn(mockJobModel);

        // Act
        await dataSource.updateJobSyncStatus(tJobId, tStatus);

        // Assert
        // Verify the status was set *on the mock model*
        verify(mockJobModel.syncStatus = tStatus.index);
        // Verify the model's save() method was called
        verify(mockJobModel.save());
        // Verify box.put was NOT called
        verifyNever(mockJobsBox.put(any, any));
      },
    );

    test(
      'should update sync status and save via box.put() if model not in box',
      () async {
        // Arrange
        final tJobModelNotInBox = JobHiveModel(
          localId: tJobId,
          syncStatus: SyncStatus.pending.index,
        );
        // Mock get to return a REAL model this time
        when(mockJobsBox.get(tJobId)).thenReturn(tJobModelNotInBox);
        // Mock put to succeed
        when(
          mockJobsBox.put(tJobId, any),
        ).thenAnswer((_) async => Future<void>.value());

        // Act
        await dataSource.updateJobSyncStatus(tJobId, tStatus);

        // Assert
        // Verify box.put WAS called with the updated model
        final captured =
            verify(mockJobsBox.put(tJobId, captureAny)).captured.single;
        expect(captured, isA<JobHiveModel>());
        expect(captured.localId, equals(tJobId));
        expect(captured.syncStatus, equals(tStatus.index));
        // Verify save() was NOT called (since we didn't use a mock model)
      },
    );

    test('should throw CacheException if the job model is not found', () async {
      // Arrange
      when(mockJobsBox.get(tJobId)).thenReturn(null);

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, tStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tJobId));
      verifyNever(mockJobsBox.put(any, any));
    });

    test('should throw CacheException if getting the job fails', () async {
      // Arrange
      when(mockJobsBox.get(tJobId)).thenThrow(Exception('Get failed'));

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, tStatus);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.get(tJobId));
      verifyNever(mockJobsBox.put(any, any));
    });

    test(
      'should throw CacheException if saving the job fails (using model.save)',
      () async {
        // Arrange
        when(mockJobModel.localId).thenReturn(tJobId);
        when(mockJobModel.isInBox).thenReturn(true);
        when(
          mockJobModel.save(),
        ).thenThrow(Exception('Save failed')); // Mock save to throw
        when(mockJobsBox.get(tJobId)).thenReturn(mockJobModel);

        // Act
        final call = dataSource.updateJobSyncStatus(tJobId, tStatus);

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(mockJobModel.syncStatus = tStatus.index);
        verify(mockJobModel.save());
        verifyNever(mockJobsBox.put(any, any));
      },
    );

    test(
      'should throw CacheException if saving the job fails (using box.put)',
      () async {
        // Arrange
        final tJobModelNotInBox = JobHiveModel(
          localId: tJobId,
          syncStatus: SyncStatus.pending.index,
        );
        when(mockJobsBox.get(tJobId)).thenReturn(tJobModelNotInBox);
        // Mock put to throw
        when(mockJobsBox.put(tJobId, any)).thenThrow(Exception('Put failed'));

        // Act
        final call = dataSource.updateJobSyncStatus(tJobId, tStatus);

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(mockJobsBox.put(tJobId, captureAny));
      },
    );
  });

  group('getSyncedJobHiveModels', () {
    test(
      'should return only jobs with synced status AND a non-null serverId',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(allJobs);

        // Act
        final result = await dataSource.getSyncedJobHiveModels();

        // Assert
        // Only jobSynced should match
        expect(result, equals([jobSynced]));
        verify(mockJobsBox.values);
      },
    );

    test('should return empty list if no jobs meet the criteria', () async {
      // Arrange
      when(
        mockJobsBox.values,
      ).thenReturn([jobPending, jobError, jobSyncedNoServerId]);

      // Act
      final result = await dataSource.getSyncedJobHiveModels();

      // Assert
      expect(result, isEmpty);
      verify(mockJobsBox.values);
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive error'));

      // Act
      final call = dataSource.getSyncedJobHiveModels();

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockJobsBox.values);
    });
  });
}
