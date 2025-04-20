import 'dart:math';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'hive_job_local_data_source_impl_test.mocks.dart';

// Generate mocks for HiveInterface and Box
@GenerateMocks([HiveInterface, Box])
void main() {
  late MockHiveInterface mockHiveInterface;
  late MockBox<JobHiveModel> mockJobsBox;
  late MockBox<dynamic> mockMetadataBox;
  late HiveJobLocalDataSourceImpl dataSource;

  const String metadataBoxName = 'app_metadata';
  const String metadataTimestampKey = 'lastFetchTimestamp';

  setUp(() {
    mockHiveInterface = MockHiveInterface();
    mockJobsBox = MockBox<JobHiveModel>();
    mockMetadataBox = MockBox<dynamic>();
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHiveInterface);

    when(
      mockHiveInterface.isBoxOpen(HiveJobLocalDataSourceImpl.jobsBoxName),
    ).thenReturn(true);
    when(
      mockHiveInterface.box<JobHiveModel>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenReturn(mockJobsBox);
    when(mockHiveInterface.isBoxOpen(metadataBoxName)).thenReturn(true);
    when(
      mockHiveInterface.box<dynamic>(metadataBoxName),
    ).thenReturn(mockMetadataBox);
    when(
      mockHiveInterface.openBox<dynamic>(metadataBoxName),
    ).thenAnswer((_) async => mockMetadataBox);
    when(
      mockHiveInterface.openBox<JobHiveModel>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenAnswer((_) async => mockJobsBox);
  });

  // --- Test Data Setup ---
  final now = DateTime.now();
  final tBaseBackoff = const Duration(minutes: 1); // Example backoff
  const tMaxRetries = 3;

  // Helper function to calculate expected backoff time
  DateTime calculateBackoffTime(int retryCount, Duration baseBackoff) {
    return now.subtract(baseBackoff * pow(2, retryCount).toInt());
  }

  // Example JobHiveModels for testing
  final job1RetryableNoLastAttempt = JobHiveModel(
    localId: '1',
    syncStatus: SyncStatus.error.index,
    retryCount: 1, // Below max retries
    lastSyncAttemptAt: null, // Null last attempt, should retry
  );

  final job2RetryableBackoffPassed = JobHiveModel(
    localId: '2',
    syncStatus: SyncStatus.error.index,
    retryCount: 1,
    // Last attempt was long enough ago based on backoff (1 * 2^1 = 2 mins)
    lastSyncAttemptAt:
        calculateBackoffTime(
          1,
          tBaseBackoff,
        ).subtract(const Duration(seconds: 1)).toIso8601String(),
  );

  final job3NotRetryableMaxRetries = JobHiveModel(
    localId: '3',
    syncStatus: SyncStatus.error.index,
    retryCount: tMaxRetries, // At max retries
    lastSyncAttemptAt: now.subtract(const Duration(days: 1)).toIso8601String(),
  );

  final job4NotRetryableBackoffNotPassed = JobHiveModel(
    localId: '4',
    syncStatus: SyncStatus.error.index,
    retryCount: 1,
    // Last attempt was too recent (within backoff period)
    lastSyncAttemptAt:
        calculateBackoffTime(
          1,
          tBaseBackoff,
        ).add(const Duration(minutes: 1)).toIso8601String(),
  );

  final job5NotErrorStatus = JobHiveModel(
    localId: '5',
    syncStatus: SyncStatus.synced.index, // Not error status
    retryCount: 0,
    lastSyncAttemptAt: null,
    status: JobStatus.completed.index,
    createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
    updatedAt: now.toIso8601String(),
    userId: 'user-123',
  );

  // Subset of models for getJobs test
  final List<JobHiveModel> tJobHiveModelList = [
    job1RetryableNoLastAttempt,
    job5NotErrorStatus,
  ];

  // Corresponding Job entities for getJobs test
  final tJobList = [
    JobMapper.fromHiveModel(job1RetryableNoLastAttempt),
    JobMapper.fromHiveModel(job5NotErrorStatus),
  ];

  final allTestJobModelsOnly = [
    job1RetryableNoLastAttempt,
    job2RetryableBackoffPassed,
    job3NotRetryableMaxRetries,
    job4NotRetryableBackoffNotPassed,
    job5NotErrorStatus,
  ];

  // Compare based on localId
  final expectedRetryableJobIds = [
    job1RetryableNoLastAttempt.localId, // Use model's localId
    job2RetryableBackoffPassed.localId, // Use model's localId
  ];

  group('getJobsToRetry', () {
    test(
      'should return jobs with error status, below max retries, and whose backoff period has passed',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(allTestJobModelsOnly);

        // Act
        final result = await dataSource.getJobsToRetry(
          tMaxRetries,
          tBaseBackoff,
        );

        // Assert
        // FIX: Compare list of localIds instead of full objects
        final resultIds = result.map((job) => job.localId).toList();
        expect(resultIds, equals(expectedRetryableJobIds));

        verify(
          mockHiveInterface.box<JobHiveModel>(
            HiveJobLocalDataSourceImpl.jobsBoxName,
          ),
        );
        verify(mockJobsBox.values);
      },
    );

    test(
      'should return an empty list if no jobs meet the retry criteria',
      () async {
        // Arrange
        final nonRetryableModels = [
          job3NotRetryableMaxRetries,
          job4NotRetryableBackoffNotPassed,
          job5NotErrorStatus,
        ];
        when(mockJobsBox.values).thenReturn(nonRetryableModels);

        // Act
        final result = await dataSource.getJobsToRetry(
          tMaxRetries,
          tBaseBackoff,
        );

        // Assert
        expect(result, isEmpty);
        verify(
          mockHiveInterface.box<JobHiveModel>(
            HiveJobLocalDataSourceImpl.jobsBoxName,
          ),
        );
        verify(mockJobsBox.values);
      },
    );

    test(
      'should return an empty list if the box is empty or contains no jobs',
      () async {
        // Arrange
        when(mockJobsBox.values).thenReturn(<JobHiveModel>[]); // Empty box

        // Act
        final result = await dataSource.getJobsToRetry(
          tMaxRetries,
          tBaseBackoff,
        );

        // Assert
        expect(result, isEmpty);
      },
    );

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(mockJobsBox.values).thenThrow(Exception('Hive failed miserably'));

      // Act
      final call = dataSource.getJobsToRetry(tMaxRetries, tBaseBackoff);

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

  group('getJobs', () {
    test('should return list of Job entities when cache call is successful', () async {
      // Arrange
      // IMPORTANT: Mock the underlying getAllJobHiveModels call
      // We need to bypass the actual Hive logic and provide the models directly
      // This requires modifying the dataSource instance or how it's mocked,
      // or more simply, mocking the getAllJobHiveModels method directly if possible.
      // Let's assume we can mock the direct call for simplicity here.
      // This might require making getAllJobHiveModels public or using a spy.
      // *** Correction: We mock the box.values which getAllJobHiveModels uses! ***

      when(mockJobsBox.values).thenReturn(tJobHiveModelList);

      // Act
      final result = await dataSource.getJobs();

      // Assert
      // Compare localIds as object equality is tricky with mapper defaults
      final resultIds = result.map((j) => j.localId).toList();
      final expectedIds = tJobList.map((j) => j.localId).toList();
      expect(resultIds, equals(expectedIds));

      // Verify underlying hive call (indirectly via getAllJobHiveModels -> _getOpenBox -> box.values)
      verify(
        mockHiveInterface.box<JobHiveModel>(
          HiveJobLocalDataSourceImpl.jobsBoxName,
        ),
      ).called(1);
      verify(mockJobsBox.values).called(1);
    });

    test(
      'should throw CacheException when underlying Hive call fails',
      () async {
        // Arrange
        when(mockJobsBox.values).thenThrow(Exception('Hive failed'));

        // Act
        final call = dataSource.getJobs();

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(
          mockHiveInterface.box<JobHiveModel>(
            HiveJobLocalDataSourceImpl.jobsBoxName,
          ),
        ).called(1);
        verify(mockJobsBox.values).called(1);
      },
    );
  });

  group('Timestamp Handling (Metadata Box)', () {
    final tTime = DateTime.now();
    final tTimestampKey = metadataTimestampKey;
    final tTimestampMillis = tTime.toUtc().millisecondsSinceEpoch;

    group('saveLastFetchTime', () {
      test(
        'should save the timestamp (as UTC epoch millis) into the METADATA box',
        () async {
          // Arrange
          // No specific arrangement needed beyond setUp mocks

          // Act
          await dataSource.saveLastFetchTime(tTime);

          // Assert
          // Verify interaction ONLY with the metadata box
          verify(mockHiveInterface.box<dynamic>(metadataBoxName));
          verify(
            mockMetadataBox.put(tTimestampKey, tTimestampMillis),
          ).called(1);

          // Verify NO interaction with the jobs box for the timestamp key
          verifyNever(
            mockJobsBox.put(
              // Use the OLD key here to ensure it's not written to jobs box
              'lastFetchTimestamp',
              any,
            ),
          );
          verifyNever(mockJobsBox.put(tTimestampKey, any));
        },
      );

      test('should throw CacheException if metadata box put fails', () async {
        // Arrange
        when(
          mockMetadataBox.put(tTimestampKey, tTimestampMillis),
        ).thenThrow(Exception('Hive metadata put failed'));

        // Act
        final call = dataSource.saveLastFetchTime(tTime);

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(mockMetadataBox.put(tTimestampKey, tTimestampMillis));
      });
    });

    group('getLastFetchTime', () {
      test(
        'should retrieve the timestamp from the METADATA box and return as DateTime',
        () async {
          // Arrange
          when(mockMetadataBox.get(tTimestampKey)).thenReturn(tTimestampMillis);
          final expectedDateTime = DateTime.fromMillisecondsSinceEpoch(
            tTimestampMillis,
          );

          // Act
          final result = await dataSource.getLastFetchTime();

          // Assert
          expect(result, equals(expectedDateTime));
          // Verify interaction ONLY with the metadata box
          verify(mockHiveInterface.box<dynamic>(metadataBoxName));
          verify(mockMetadataBox.get(tTimestampKey)).called(1);
          // Verify NO interaction with the jobs box
          verifyNever(mockJobsBox.get('lastFetchTimestamp'));
          verifyNever(mockJobsBox.get(tTimestampKey));
        },
      );

      test(
        'should return null if timestamp is not found in METADATA box',
        () async {
          // Arrange
          when(mockMetadataBox.get(tTimestampKey)).thenReturn(null);

          // Act
          final result = await dataSource.getLastFetchTime();

          // Assert
          expect(result, isNull);
          verify(mockMetadataBox.get(tTimestampKey));
          verifyNever(mockJobsBox.get('lastFetchTimestamp'));
          verifyNever(mockJobsBox.get(tTimestampKey));
        },
      );

      test(
        'should return null and log warning if timestamp in METADATA box is not int',
        () async {
          // Arrange
          when(mockMetadataBox.get(tTimestampKey)).thenReturn('not an int');

          // Act
          final result = await dataSource.getLastFetchTime();

          // Assert
          expect(result, isNull);
          verify(mockMetadataBox.get(tTimestampKey));
          // We can't easily verify logs here, but the null return is key
        },
      );

      test('should throw CacheException if metadata box get fails', () async {
        // Arrange
        when(
          mockMetadataBox.get(tTimestampKey),
        ).thenThrow(Exception('Hive metadata get failed'));

        // Act
        final call = dataSource.getLastFetchTime();

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(mockMetadataBox.get(tTimestampKey));
      });
    });
  });

  // TODO: Add test groups for other methods:
  // - getJobs
  // - getJobById
  // - saveJob
  // - deleteJob
  // - getJobsByStatus
  // - getAllJobHiveModels
  // - getJobHiveModelById
  // - saveJobHiveModel
  // - saveJobHiveModels
  // - deleteJobHiveModel
  // - clearAllJobHiveModels
  // - getLastJobHiveModel
  // - getLastFetchTime
  // - saveLastFetchTime
  // - getJobsToSync
  // - updateJobSyncStatus
  // - getSyncedJobHiveModels
}
