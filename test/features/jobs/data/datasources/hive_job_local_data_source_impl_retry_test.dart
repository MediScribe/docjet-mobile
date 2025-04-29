import 'dart:math';

import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'hive_job_local_data_source_impl_retry_test.mocks.dart';

// Generate mocks for HiveInterface and Box
@GenerateMocks([HiveInterface, Box])
void main() {
  late MockHiveInterface mockHiveInterface;
  late MockBox<JobHiveModel> mockJobsBox;
  // We don't need metadata box for these tests
  // late MockBox<dynamic> mockMetadataBox;
  late HiveJobLocalDataSourceImpl dataSource;

  // const String metadataBoxName = 'app_metadata';
  // const String metadataTimestampKey = 'lastFetchTimestamp';

  // Helper function to create test models with specific retry/sync properties
  JobHiveModel createTestJobHiveModel({
    required String localId,
    required SyncStatus syncStatus,
    int? retryCount,
    String? lastSyncAttemptAt,
    JobStatus status = JobStatus.submitted, // Default
    String userId = 'test-user', // Default
    String createdAt = '2023-01-01T10:00:00Z', // Default
    String? updatedAt, // Default
  }) {
    return JobHiveModel(
      localId: localId,
      syncStatus: syncStatus.index,
      retryCount: retryCount,
      lastSyncAttemptAt: lastSyncAttemptAt,
      status: status.index,
      userId: userId,
      createdAt: createdAt,
      updatedAt:
          updatedAt ?? createdAt, // Default updatedAt to createdAt if null
      // Add other fields as needed with defaults
    );
  }

  setUp(() {
    mockHiveInterface = MockHiveInterface();
    mockJobsBox = MockBox<JobHiveModel>();
    // mockMetadataBox = MockBox<dynamic>();
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
  const tBaseBackoff = Duration(minutes: 1); // Example backoff
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
    const maxRetries = 5;
    const baseBackoff = Duration(seconds: 30);

    test('should return empty list when no jobs are in error state', () async {
      // Arrange
      final nonErrorJobs = [
        createTestJobHiveModel(localId: '1', syncStatus: SyncStatus.pending),
        createTestJobHiveModel(localId: '2', syncStatus: SyncStatus.synced),
      ];
      when(mockJobsBox.values).thenReturn(nonErrorJobs);

      // Act
      final result = await dataSource.getJobsToRetry(maxRetries, baseBackoff);

      // Assert
      expect(result, isEmpty);
      verify(mockJobsBox.values);
    });

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
}
