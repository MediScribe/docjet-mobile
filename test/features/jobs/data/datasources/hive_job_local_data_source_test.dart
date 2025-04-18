import 'dart:io';

import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';

// Generate mocks for Box AND HiveInterface
@GenerateMocks([Box<dynamic>, HiveInterface])
import 'hive_job_local_data_source_test.mocks.dart';

void main() {
  late HiveJobLocalDataSourceImpl dataSource;
  late MockBox<dynamic> mockBox;
  late MockHiveInterface mockHiveInterface; // Mock HiveInterface
  late Directory testTempDir;

  // Dummy JobHiveModel for testing
  // Create instance and assign fields directly
  final tJobHiveModel =
      JobHiveModel()
        ..id = 'test-id-1'
        ..userId = 'user-123'
        ..status = 'submitted'
        ..createdAt = DateTime(2023, 1, 1, 10, 0, 0).toUtc()
        ..updatedAt = DateTime(2023, 1, 1, 10, 0, 0).toUtc()
        ..text = 'Test text'
        ..additionalText = 'Additional test text'
        ..displayTitle = null
        ..displayText = null
        ..errorCode = null
        ..errorMessage = null
        ..audioFilePath = '/path/to/audio.mp3';
  // Note: syncStatus and lastSyncedAt are not part of the current JobHiveModel

  final tJobHiveModelList = [tJobHiveModel];

  setUpAll(() async {
    // 1. Set up a temporary directory for Hive testing
    testTempDir = await Directory.systemTemp.createTemp('hive_local_test_');
    Hive.init(testTempDir.path);

    // 2. Register Hive Adapter if not already registered
    if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
      Hive.registerAdapter(JobHiveModelAdapter());
    }
  });

  tearDownAll(() async {
    // Close Hive and delete the temporary directory
    await Hive.close();
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    mockBox = MockBox<dynamic>();
    mockHiveInterface = MockHiveInterface(); // Instantiate mock Hive

    // Stub the HiveInterface methods to return the mock dynamic box
    when(
      mockHiveInterface.isBoxOpen(HiveJobLocalDataSourceImpl.jobsBoxName),
    ).thenReturn(true);
    when(
      mockHiveInterface.box<dynamic>(HiveJobLocalDataSourceImpl.jobsBoxName),
    ).thenReturn(mockBox);
    when(
      mockHiveInterface.openBox<dynamic>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenAnswer((_) async => mockBox);

    // Instantiate dataSource with the mock HiveInterface
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHiveInterface);
  });

  tearDown(() async {
    // Reset mocks
    reset(mockBox);
    reset(mockHiveInterface);
  });

  group('HiveJobLocalDataSource Implementation Tests', () {
    group('saveJobHiveModel', () {
      test('should call Box.put with the correct key and value', () async {
        // Arrange
        // Stub the put method to simulate successful save
        when(mockBox.put(any, any)).thenAnswer((_) async => Future.value());

        // Act
        await dataSource.saveJobHiveModel(tJobHiveModel);

        // Assert
        verify(mockBox.put(tJobHiveModel.id, tJobHiveModel)).called(1);
      });

      // TODO: Add test for HiveError during save
    });

    group('getAllJobHiveModels', () {
      test(
        'should return list of JobHiveModel from the box, filtering out other types',
        () async {
          // Arrange
          // Include a non-JobHiveModel value in the mock return
          final dynamicValues = [tJobHiveModel, 123456789]; // Job + timestamp
          when(mockBox.values).thenReturn(dynamicValues);

          // Act
          final result = await dataSource.getAllJobHiveModels();

          // Assert
          // Expect only the JobHiveModel list
          expect(result, equals(tJobHiveModelList));
          verify(mockBox.values).called(1);
        },
      );

      test('should return empty list when box is empty', () async {
        // Arrange
        when(mockBox.values).thenReturn([]);

        // Act
        final result = await dataSource.getAllJobHiveModels();

        // Assert
        expect(result, isEmpty);
        verify(mockBox.values).called(1);
      });

      // TODO: Add test for HiveError during getAll
    });

    group('getJobHiveModelById', () {
      test('should return JobHiveModel when found in the box', () async {
        // Arrange
        when(mockBox.get(tJobHiveModel.id)).thenReturn(tJobHiveModel);

        // Act
        final result = await dataSource.getJobHiveModelById(tJobHiveModel.id);

        // Assert
        expect(result, equals(tJobHiveModel));
        verify(mockBox.get(tJobHiveModel.id)).called(1);
      });

      test(
        'should return null when ID exists but value is not a JobHiveModel',
        () async {
          // Arrange
          const otherKey =
              HiveJobLocalDataSourceImpl
                  .jobsBoxName; // Use box name as a dummy key
          const otherValue = 12345; // Simulate timestamp or other data
          when(mockBox.get(otherKey)).thenReturn(otherValue);

          // Act
          final result = await dataSource.getJobHiveModelById(otherKey);

          // Assert
          expect(result, isNull);
          verify(mockBox.get(otherKey)).called(1);
        },
      );

      // TODO: Add test for HiveError during getById
    });

    group('deleteJobHiveModel', () {
      test('should call Box.delete with the correct key', () async {
        // Arrange
        when(mockBox.delete(any)).thenAnswer((_) async => Future.value());

        // Act
        await dataSource.deleteJobHiveModel(tJobHiveModel.id);

        // Assert
        verify(mockBox.delete(tJobHiveModel.id)).called(1);
      });

      // TODO: Add test for HiveError during delete
    });

    group('clearAllJobHiveModels', () {
      test('should call Box.clear and restore timestamp if present', () async {
        // Arrange
        const timestampKey =
            'lastFetchTimestamp'; // Ensure this matches implementation
        const timestampValue = 1672531200000; // Example timestamp milliseconds
        // Stub get to return timestamp
        when(mockBox.get(timestampKey)).thenReturn(timestampValue);
        // Stub clear to return the number of items deleted (e.g., 2: job + timestamp)
        when(mockBox.clear()).thenAnswer((_) async => 2);
        // Stub put to simulate restoring timestamp
        when(
          mockBox.put(timestampKey, timestampValue),
        ).thenAnswer((_) async => Future.value());

        // Act
        await dataSource.clearAllJobHiveModels();

        // Assert
        verify(mockBox.get(timestampKey)).called(1);
        verify(mockBox.clear()).called(1);
        verify(
          mockBox.put(timestampKey, timestampValue),
        ).called(1); // Verify timestamp restore
      });

      test(
        'should call Box.clear and NOT restore timestamp if not present',
        () async {
          // Arrange
          const timestampKey =
              'lastFetchTimestamp'; // Ensure this matches implementation
          // Stub get to return null (no timestamp)
          when(mockBox.get(timestampKey)).thenReturn(null);
          // Stub clear to return the number of items deleted (e.g., 1: just a job)
          when(mockBox.clear()).thenAnswer((_) async => 1);
          // NO need to stub put for timestamp

          // Act
          await dataSource.clearAllJobHiveModels();

          // Assert
          verify(mockBox.get(timestampKey)).called(1);
          verify(mockBox.clear()).called(1);
          verifyNever(
            mockBox.put(timestampKey, any),
          ); // Verify timestamp restore NOT called
        },
      );

      // TODO: Add test for HiveError during clear
    });

    // --- ADDED: Tests for timestamp methods ---
    group('saveLastFetchTime', () {
      final tTime = DateTime.now();
      const tKey = 'lastFetchTimestamp';
      final tMillis = tTime.toUtc().millisecondsSinceEpoch;

      test(
        'should call box.put with correct key and timestamp in millis',
        () async {
          // Arrange
          when(mockBox.put(any, any)).thenAnswer((_) async => Future.value());

          // Act
          await dataSource.saveLastFetchTime(tTime);

          // Assert
          verify(mockBox.put(tKey, tMillis)).called(1);
        },
      );

      test('should throw CacheException when box.put throws', () async {
        // Arrange
        final hiveError = HiveError('Failed to write');
        when(mockBox.put(any, any)).thenThrow(hiveError);

        // Act
        final call = dataSource.saveLastFetchTime;

        // Assert
        expect(() => call(tTime), throwsA(isA<CacheException>()));
      });
    });

    group('getLastFetchTime', () {
      const tKey = 'lastFetchTimestamp';
      final tTime = DateTime.now();
      final tMillis = tTime.toUtc().millisecondsSinceEpoch;

      test('should return DateTime when timestamp exists in box', () async {
        // Arrange
        when(mockBox.get(tKey)).thenReturn(tMillis);

        // Act
        final result = await dataSource.getLastFetchTime();

        // Assert
        // Compare millisecondsSinceEpoch for equality as DateTime objects might differ slightly
        expect(result?.millisecondsSinceEpoch, equals(tMillis));
        verify(mockBox.get(tKey)).called(1);
      });

      test('should return null when timestamp key does not exist', () async {
        // Arrange
        when(mockBox.get(tKey)).thenReturn(null);

        // Act
        final result = await dataSource.getLastFetchTime();

        // Assert
        expect(result, isNull);
        verify(mockBox.get(tKey)).called(1);
      });

      test('should return null when value for key is not an int', () async {
        // Arrange
        when(
          mockBox.get(tKey),
        ).thenReturn('not-a-timestamp'); // Return wrong type

        // Act
        final result = await dataSource.getLastFetchTime();

        // Assert
        expect(result, isNull);
        verify(mockBox.get(tKey)).called(1);
      });

      test('should throw CacheException when box.get throws', () async {
        // Arrange
        final hiveError = HiveError('Failed to read');
        when(mockBox.get(tKey)).thenThrow(hiveError);

        // Act
        final call = dataSource.getLastFetchTime;

        // Assert
        expect(call, throwsA(isA<CacheException>()));
      });
    });
    // --- END: Added tests ---

    // TODO: Add tests for getJobsToSync
    // TODO: Add tests for updateJobSyncStatus
  });
}
