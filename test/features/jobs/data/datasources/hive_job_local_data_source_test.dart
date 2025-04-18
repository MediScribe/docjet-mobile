import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks file
import 'hive_job_local_data_source_test.mocks.dart';

// Annotations to generate mocks MUST be top-level or directly above the class/main
@GenerateMocks([HiveInterface, Box, JobHiveModel])
void main() {
  late HiveJobLocalDataSourceImpl dataSource;
  late MockHiveInterface mockHive;
  late MockBox<dynamic> mockBox;

  // Constants for keys and box name from implementation
  const String jobsBoxName = HiveJobLocalDataSourceImpl.jobsBoxName;
  const String timestampKey = HiveJobLocalDataSourceImpl.lastFetchTimestampKey;

  setUpAll(() {
    // Register type adapters required by the models/enums used in tests
    if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
      Hive.registerAdapter(JobHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(SyncStatusAdapter().typeId)) {
      Hive.registerAdapter(SyncStatusAdapter());
    }
  });

  setUp(() {
    // Create fresh mocks for each test
    mockHive = MockHiveInterface();
    mockBox = MockBox<dynamic>();
    // Instantiate dataSource for each test
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHive);

    // Basic box opening stubs
    when(mockHive.isBoxOpen(jobsBoxName)).thenReturn(false);
    when(
      mockHive.openBox<dynamic>(jobsBoxName),
    ).thenAnswer((_) async => mockBox);
    when(mockBox.isOpen).thenReturn(true);
  });

  tearDown(() {
    reset(mockHive);
    reset(mockBox);
  });

  // --- Test Groups --- //

  group('Last Fetch Time', () {
    final tTimestamp = DateTime(2023, 3, 15, 12, 0, 0);
    final tTimestampMillis = tTimestamp.millisecondsSinceEpoch;

    group('saveLastFetchTime', () {
      test('should call box put with correct key and timestamp', () async {
        // Arrange: Stub the specific put call for this test
        when(
          mockBox.put(timestampKey, tTimestampMillis),
        ).thenAnswer((_) async => Future<void>.value());

        // Act
        await dataSource.saveLastFetchTime(tTimestamp);

        // Assert
        // Verify box opening sequence was called
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        // Verify the specific put call
        verify(mockBox.put(timestampKey, tTimestampMillis)).called(1);
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      });

      test('should throw CacheException when put fails', () async {
        // Arrange: Stub put to throw an error
        final hiveError = HiveError('Failed to write');
        when(mockBox.put(timestampKey, tTimestampMillis)).thenThrow(hiveError);

        // Act
        final call = dataSource.saveLastFetchTime(tTimestamp);

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        verify(mockBox.put(timestampKey, tTimestampMillis)).called(1);
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      });
    });

    group('getLastFetchTime', () {
      test('should return DateTime when timestamp exists', () async {
        // Arrange: Stub the specific get call for this test
        when(mockBox.get(timestampKey)).thenReturn(tTimestampMillis);

        // Act
        final result = await dataSource.getLastFetchTime();

        // Assert
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        expect(result?.millisecondsSinceEpoch, equals(tTimestampMillis));
        verify(mockBox.get(timestampKey)).called(1);
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      });

      test('should return null when timestamp does not exist', () async {
        // Arrange: Stub get to return null
        when(mockBox.get(timestampKey)).thenReturn(null);

        // Act
        final result = await dataSource.getLastFetchTime();

        // Assert
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        expect(result, isNull);
        verify(mockBox.get(timestampKey)).called(1);
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      });

      test('should return null when value is not an int', () async {
        // Arrange: Stub get to return wrong type
        when(mockBox.get(timestampKey)).thenReturn('not-an-int');

        // Act
        final result = await dataSource.getLastFetchTime();

        // Assert
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        expect(result, isNull);
        verify(mockBox.get(timestampKey)).called(1);
        // Skip logger verification as it's internal
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      });

      test('should throw CacheException when get fails', () async {
        // Arrange: Stub get to throw an error
        final hiveError = HiveError('Failed to read');
        when(mockBox.get(timestampKey)).thenThrow(hiveError);

        // Act
        final call = dataSource.getLastFetchTime();

        // Assert
        await expectLater(call, throwsA(isA<CacheException>()));
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        verify(mockBox.get(timestampKey)).called(1);
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      });
    });
  });

  group('getJobsToSync', () {
    final tJob1 =
        JobHiveModel()
          ..localId = 'job-1'
          ..syncStatus = SyncStatus.pending;
    final tJob2 =
        JobHiveModel()
          ..localId = 'job-2'
          ..syncStatus = SyncStatus.synced;
    final tJob3 =
        JobHiveModel()
          ..localId = 'job-3'
          ..syncStatus = SyncStatus.error;
    final tJob4 =
        JobHiveModel()
          ..localId = 'job-4'
          ..syncStatus = SyncStatus.pending;
    final tJobsMap = {
      // Simulate a box with jobs and timestamp
      tJob1.localId: tJob1,
      tJob2.localId: tJob2,
      tJob3.localId: tJob3,
      tJob4.localId: tJob4,
      timestampKey: 1678886400000,
    };

    test('should return only jobs with pending syncStatus', () async {
      // Arrange: Stub the values getter
      when(mockBox.values).thenReturn(tJobsMap.values);

      // Act
      final result = await dataSource.getJobsToSync();

      // Assert
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      expect(result, equals([tJob1, tJob4]));
      verify(mockBox.values).called(1);
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });

    test('should return empty list when no jobs are pending', () async {
      // Arrange: Stub values with only non-pending jobs
      final tSyncedJobsMap = {
        tJob2.localId: tJob2,
        tJob3.localId: tJob3,
        timestampKey: 1,
      };
      when(mockBox.values).thenReturn(tSyncedJobsMap.values);

      // Act
      final result = await dataSource.getJobsToSync();

      // Assert
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      expect(result, isEmpty);
      verify(mockBox.values).called(1);
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });

    test(
      'should return empty list when box is empty (only timestamp)',
      () async {
        // Arrange: Stub values with only timestamp
        when(mockBox.values).thenReturn([1678886400000]);

        // Act
        final result = await dataSource.getJobsToSync();

        // Assert
        verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
        verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
        expect(result, isEmpty);
        verify(mockBox.values).called(1);
        verifyNoMoreInteractions(mockBox);
        verifyNoMoreInteractions(mockHive);
      },
    );

    test('should return empty list when box is truly empty', () async {
      // Arrange: Stub values with empty list
      when(mockBox.values).thenReturn([]);

      // Act
      final result = await dataSource.getJobsToSync();

      // Assert
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      expect(result, isEmpty);
      verify(mockBox.values).called(1);
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });

    test('should throw CacheException when values getter fails', () async {
      // Arrange: Stub values to throw error
      final hiveError = HiveError('Failed to read');
      when(mockBox.values).thenThrow(hiveError);

      // Act
      final call = dataSource.getJobsToSync();

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      verify(mockBox.values).called(1);
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });
  });

  group('updateJobSyncStatus', () {
    final tJobId = 'job-to-update';
    late MockJobHiveModel mockJobHiveModel; // Use the generated mock type

    setUp(() {
      mockJobHiveModel = MockJobHiveModel(); // Instantiate the mock
      when(mockJobHiveModel.localId).thenReturn(tJobId);
      when(mockJobHiveModel.key).thenReturn(tJobId);
    });

    test('should update status and save the job successfully', () async {
      // Arrange
      when(mockBox.get(tJobId)).thenReturn(mockJobHiveModel);
      when(mockJobHiveModel.isInBox).thenReturn(true);
      when(
        mockJobHiveModel.save(),
      ).thenAnswer((_) async => Future<void>.value());

      // Act
      await dataSource.updateJobSyncStatus(tJobId, SyncStatus.synced);

      // Assert
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      verify(mockBox.get(tJobId)).called(1);
      verify(mockJobHiveModel.isInBox).called(1);
      verify(mockJobHiveModel.syncStatus = SyncStatus.synced).called(1);
      verify(mockJobHiveModel.save()).called(1);
      verifyNever(mockBox.put(any, any));
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });

    test('should throw CacheException if job ID does not exist', () async {
      // Arrange: Stub get returning null
      when(mockBox.get(tJobId)).thenReturn(null);

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, SyncStatus.synced);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      verify(mockBox.get(tJobId)).called(1);
      verifyNever(mockJobHiveModel.save()); // Save should not be called
      verifyNever(mockBox.put(any, any));
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });

    test('should throw CacheException if getting job fails', () async {
      // Arrange: Stub get throwing an error
      final hiveError = HiveError('Failed to get');
      when(mockBox.get(tJobId)).thenThrow(hiveError);

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, SyncStatus.synced);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      verify(mockBox.get(tJobId)).called(1);
      verifyNever(mockJobHiveModel.save());
      verifyNever(mockBox.put(any, any));
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });

    test('should throw CacheException if saving job fails', () async {
      // Arrange: Stub get returning mock, but save throwing error
      when(mockBox.get(tJobId)).thenReturn(mockJobHiveModel);
      when(mockJobHiveModel.isInBox).thenReturn(true);
      final hiveError = HiveError('Failed to save');
      when(mockJobHiveModel.save()).thenThrow(hiveError);

      // Act
      final call = dataSource.updateJobSyncStatus(tJobId, SyncStatus.synced);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockHive.isBoxOpen(jobsBoxName)).called(1);
      verify(mockHive.openBox<dynamic>(jobsBoxName)).called(1);
      verify(mockBox.get(tJobId)).called(1);
      verify(mockJobHiveModel.isInBox).called(1);
      verify(mockJobHiveModel.syncStatus = SyncStatus.synced).called(1);
      verify(mockJobHiveModel.save()).called(1); // Verify save was called
      verifyNever(mockBox.put(any, any));
      verifyNoMoreInteractions(mockBox);
      verifyNoMoreInteractions(mockHive);
    });
  });

  // --- ADD STUBS FOR ALL OTHER ORIGINAL TEST GROUPS AS WELL --- //
  // e.g., saveJobHiveModel, getAllJobHiveModels, etc.
}
