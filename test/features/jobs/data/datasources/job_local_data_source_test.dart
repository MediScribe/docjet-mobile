import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'job_local_data_source_test.mocks.dart'; // Generated file

// Annotations to generate mocks
@GenerateMocks([HiveInterface, Box])
void main() {
  late MockHiveInterface mockHive;
  late MockBox<JobHiveModel> mockBox;
  late HiveJobLocalDataSourceImpl dataSource;

  // Test data
  final tJobId = 'test-uuid-1';
  final tJobHiveModel = JobHiveModel(
    localId: tJobId,
    status: JobStatus.created.index,
    createdAt: DateTime(2024).toIso8601String(),
    updatedAt: DateTime(2024, 1, 2).toIso8601String(),
    userId: 'user-123',
    syncStatus: SyncStatus.synced.index,
  );

  final tJobHiveModelList = [tJobHiveModel];

  setUp(() {
    mockHive = MockHiveInterface();
    mockBox = MockBox<JobHiveModel>();
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHive);

    // Explicitly stub isBoxOpen to ensure openBox is called in the helper
    when(mockHive.isBoxOpen(any)).thenReturn(false);

    // Stub the openBox call to return the mocked box
    when(mockHive.openBox<JobHiveModel>(any)).thenAnswer((_) async => mockBox);
    // Default stub for box.values to avoid null errors in unrelated tests
    when(mockBox.values).thenReturn([]);
  });

  group('getAllJobHiveModels', () {
    test(
      'should return list of JobHiveModel from the box when cache is not empty',
      () async {
        // Arrange
        when(mockBox.values).thenReturn(tJobHiveModelList);
        // Act
        final result = await dataSource.getAllJobHiveModels();
        // Assert
        expect(result, equals(tJobHiveModelList));
        verify(
          mockHive.openBox<JobHiveModel>(
            HiveJobLocalDataSourceImpl.jobsBoxName,
          ),
        );
        verify(mockBox.values);
      },
    );

    test('should return empty list from the box when cache is empty', () async {
      // Arrange
      when(mockBox.values).thenReturn([]);
      // Act
      final result = await dataSource.getAllJobHiveModels();
      // Assert
      expect(result, equals([]));
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.values);
    });

    test('should throw CacheException when opening the box fails', () async {
      // Arrange
      when(
        mockHive.openBox<JobHiveModel>(any),
      ).thenThrow(Exception('Hive error'));
      // Act
      final call = dataSource.getAllJobHiveModels;
      // Assert
      expect(() => call(), throwsA(isA<CacheException>()));
    });
  });

  group('getJobHiveModelById', () {
    test('should return JobHiveModel from box when ID exists', () async {
      // Arrange
      when(mockBox.get(tJobId)).thenReturn(tJobHiveModel);
      // Act
      final result = await dataSource.getJobHiveModelById(tJobId);
      // Assert
      expect(result, equals(tJobHiveModel));
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.get(tJobId));
    });

    test('should return null when ID does not exist in box', () async {
      // Arrange
      when(mockBox.get(tJobId)).thenReturn(null);
      // Act
      final result = await dataSource.getJobHiveModelById(tJobId);
      // Assert
      expect(result, isNull);
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.get(tJobId));
    });

    test(
      'should throw CacheException when getting from the box fails',
      () async {
        // Arrange
        when(
          mockHive.openBox<JobHiveModel>(any),
        ).thenAnswer((_) async => mockBox); // Ensure box opens
        when(mockBox.get(any)).thenThrow(Exception('Hive error'));
        // Act
        final call = dataSource.getJobHiveModelById;
        // Assert
        expect(() => call(tJobId), throwsA(isA<CacheException>()));
      },
    );
  });

  group('saveJobHiveModel', () {
    test('should call box.put with the correct model', () async {
      // Arrange
      when(mockBox.put(any, any)).thenAnswer((_) async => Future<void>.value());
      // Act
      await dataSource.saveJobHiveModel(tJobHiveModel);
      // Assert
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.put(tJobHiveModel.localId, tJobHiveModel));
    });

    test('should throw CacheException when putting to the box fails', () async {
      // Arrange
      when(
        mockHive.openBox<JobHiveModel>(any),
      ).thenAnswer((_) async => mockBox); // Ensure box opens
      when(mockBox.put(any, any)).thenThrow(Exception('Hive error'));
      // Act
      final call = dataSource.saveJobHiveModel;
      // Assert
      expect(() => call(tJobHiveModel), throwsA(isA<CacheException>()));
    });
  });

  group('saveJobHiveModels', () {
    test('should call box.putAll with the correct map', () async {
      // Arrange
      when(mockBox.putAll(any)).thenAnswer((_) async => Future<void>.value());

      // Act
      final result = await dataSource.saveJobHiveModels(tJobHiveModelList);

      // Assert
      expect(result, isTrue);
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.putAll(any)).called(1);
    });

    test('should throw CacheException when putAll fails', () async {
      // Arrange
      when(
        mockHive.openBox<JobHiveModel>(any),
      ).thenAnswer((_) async => mockBox); // Ensure box opens
      when(mockBox.putAll(any)).thenThrow(Exception('Hive error'));
      // Act
      final call = dataSource.saveJobHiveModels;
      // Assert
      expect(() => call(tJobHiveModelList), throwsA(isA<CacheException>()));
    });
  });

  group('deleteJobHiveModel', () {
    test('should call box.delete with the correct id', () async {
      // Arrange
      when(mockBox.delete(any)).thenAnswer((_) async => Future<void>.value());
      // Act
      await dataSource.deleteJobHiveModel(tJobId);
      // Assert
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.delete(tJobId));
    });

    test('should throw CacheException when delete fails', () async {
      // Arrange
      when(
        mockHive.openBox<JobHiveModel>(any),
      ).thenAnswer((_) async => mockBox); // Ensure box opens
      when(mockBox.delete(any)).thenThrow(Exception('Hive error'));
      // Act
      final call = dataSource.deleteJobHiveModel;
      // Assert
      expect(() => call(tJobId), throwsA(isA<CacheException>()));
    });
  });

  group('clearAllJobHiveModels', () {
    test('should call box.clear', () async {
      // Arrange
      when(mockBox.clear()).thenAnswer((_) async => 1);
      // Add missing stub for the timestamp get call
      when(
        mockBox.get(HiveJobLocalDataSourceImpl.lastFetchTimestampKey),
      ).thenReturn(null);
      // Act
      await dataSource.clearAllJobHiveModels();
      // Assert
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.clear());
    });

    test('should throw CacheException when clear fails', () async {
      // Arrange
      when(
        mockHive.openBox<JobHiveModel>(any),
      ).thenAnswer((_) async => mockBox); // Ensure box opens
      when(mockBox.clear()).thenThrow(Exception('Hive error'));
      // Add missing stub for the timestamp get call (needed even if clear fails)
      when(
        mockBox.get(HiveJobLocalDataSourceImpl.lastFetchTimestampKey),
      ).thenReturn(null);

      // Act
      final call = dataSource.clearAllJobHiveModels;
      // Assert
      expect(() => call(), throwsA(isA<CacheException>()));
    });
  });

  group('getLastJobHiveModel', () {
    final tJobHiveModel2 = JobHiveModel(
      localId: 'job-2',
      status: JobStatus.submitted.index,
      createdAt: DateTime(2024, 1, 3).toIso8601String(),
      updatedAt: DateTime(2024, 1, 4).toIso8601String(),
      userId: 'user-456',
      syncStatus: SyncStatus.synced.index,
    );

    test('should return the job with the latest updatedAt timestamp', () async {
      // Arrange
      when(mockBox.values).thenReturn([tJobHiveModel, tJobHiveModel2]);
      // Act
      final result = await dataSource.getLastJobHiveModel();
      // Assert
      expect(
        result,
        equals(tJobHiveModel2),
      ); // tJobHiveModel2 has later updatedAt
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.values);
    });

    test('should return null when the cache is empty', () async {
      // Arrange
      when(mockBox.values).thenReturn([]);
      // Act
      final result = await dataSource.getLastJobHiveModel();
      // Assert
      expect(result, isNull);
      verify(
        mockHive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName),
      );
      verify(mockBox.values);
    });

    test('should throw CacheException when accessing values fails', () async {
      // Arrange
      when(
        mockHive.openBox<JobHiveModel>(any),
      ).thenAnswer((_) async => mockBox);
      when(mockBox.values).thenThrow(Exception('Hive error'));
      // Act
      final call = dataSource.getLastJobHiveModel;
      // Assert
      expect(() => call(), throwsA(isA<CacheException>()));
    });
  });
}
