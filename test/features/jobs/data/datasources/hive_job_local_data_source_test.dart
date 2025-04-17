import 'dart:io';

import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for Box AND HiveInterface
@GenerateMocks([Box, HiveInterface])
import 'hive_job_local_data_source_test.mocks.dart';

void main() {
  late HiveJobLocalDataSourceImpl dataSource;
  late MockBox<JobHiveModel> mockJobBox;
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
    mockJobBox = MockBox<JobHiveModel>();
    mockHiveInterface = MockHiveInterface(); // Instantiate mock Hive

    // Stub the HiveInterface methods to return the mock box
    when(
      mockHiveInterface.isBoxOpen(HiveJobLocalDataSourceImpl.jobsBoxName),
    ).thenReturn(true);
    when(
      mockHiveInterface.box<JobHiveModel>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenReturn(mockJobBox);
    // Stub openBox for completeness, though isBoxOpen should make it unnecessary in current impl
    when(
      mockHiveInterface.openBox<JobHiveModel>(
        HiveJobLocalDataSourceImpl.jobsBoxName,
      ),
    ).thenAnswer((_) async => mockJobBox);

    // Instantiate dataSource with the mock HiveInterface
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHiveInterface);
  });

  tearDown(() async {
    // Reset mocks
    reset(mockJobBox);
    reset(mockHiveInterface);
  });

  group('HiveJobLocalDataSource Implementation Tests', () {
    group('saveJobHiveModel', () {
      test('should call Box.put with the correct key and value', () async {
        // Arrange
        // Stub the put method to simulate successful save
        when(mockJobBox.put(any, any)).thenAnswer((_) async => Future.value());

        // Act
        await dataSource.saveJobHiveModel(tJobHiveModel);

        // Assert
        verify(mockJobBox.put(tJobHiveModel.id, tJobHiveModel)).called(1);
      });

      // TODO: Add test for HiveError during save
    });

    group('getAllJobHiveModels', () {
      test('should return list of JobHiveModel from the box', () async {
        // Arrange
        when(mockJobBox.values).thenReturn(tJobHiveModelList);

        // Act
        final result = await dataSource.getAllJobHiveModels();

        // Assert
        expect(result, equals(tJobHiveModelList));
        verify(mockJobBox.values).called(1);
      });

      test('should return empty list when box is empty', () async {
        // Arrange
        when(mockJobBox.values).thenReturn([]);

        // Act
        final result = await dataSource.getAllJobHiveModels();

        // Assert
        expect(result, isEmpty);
        verify(mockJobBox.values).called(1);
      });

      // TODO: Add test for HiveError during getAll
    });

    group('getJobHiveModelById', () {
      test('should return JobHiveModel when found in the box', () async {
        // Arrange
        when(mockJobBox.get(tJobHiveModel.id)).thenReturn(tJobHiveModel);

        // Act
        final result = await dataSource.getJobHiveModelById(tJobHiveModel.id);

        // Assert
        expect(result, equals(tJobHiveModel));
        verify(mockJobBox.get(tJobHiveModel.id)).called(1);
      });

      test('should return null when job ID is not found in the box', () async {
        // Arrange
        const nonExistentId = 'non-existent-id';
        when(mockJobBox.get(nonExistentId)).thenReturn(null);

        // Act
        final result = await dataSource.getJobHiveModelById(nonExistentId);

        // Assert
        expect(result, isNull);
        verify(mockJobBox.get(nonExistentId)).called(1);
      });

      // TODO: Add test for HiveError during getById
    });

    group('deleteJobHiveModel', () {
      test('should call Box.delete with the correct key', () async {
        // Arrange
        when(mockJobBox.delete(any)).thenAnswer((_) async => Future.value());

        // Act
        await dataSource.deleteJobHiveModel(tJobHiveModel.id);

        // Assert
        verify(mockJobBox.delete(tJobHiveModel.id)).called(1);
      });

      // TODO: Add test for HiveError during delete
    });

    group('clearAllJobHiveModels', () {
      test('should call Box.clear', () async {
        // Arrange
        // Stub clear to return the number of items deleted (e.g., 1)
        when(mockJobBox.clear()).thenAnswer((_) async => 1);

        // Act
        await dataSource.clearAllJobHiveModels();

        // Assert
        verify(mockJobBox.clear()).called(1);
      });

      // TODO: Add test for HiveError during clear
    });

    // TODO: Add tests for getJobsToSync
    // TODO: Add tests for updateJobSyncStatus
  });
}
