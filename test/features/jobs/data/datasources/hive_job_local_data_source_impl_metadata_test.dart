import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'hive_job_local_data_source_impl_test.mocks.dart';

// Generate mocks for HiveInterface and Box
@GenerateMocks([HiveInterface, Box])
void main() {
  late MockHiveInterface mockHiveInterface;
  late MockBox<dynamic> mockMetadataBox;
  late HiveJobLocalDataSourceImpl dataSource;

  const String metadataBoxName = HiveJobLocalDataSourceImpl.metadataBoxName;
  const String metadataTimestampKey =
      HiveJobLocalDataSourceImpl.metadataTimestampKey;

  setUp(() {
    mockHiveInterface = MockHiveInterface();
    mockMetadataBox = MockBox<dynamic>();
    dataSource = HiveJobLocalDataSourceImpl(hive: mockHiveInterface);

    // Setup only for Metadata Box
    when(mockHiveInterface.isBoxOpen(metadataBoxName)).thenReturn(true);
    when(
      mockHiveInterface.box<dynamic>(metadataBoxName),
    ).thenReturn(mockMetadataBox);
    when(
      mockHiveInterface.openBox<dynamic>(metadataBoxName),
    ).thenAnswer((_) async => mockMetadataBox);
  });

  group('getLastFetchTime', () {
    final tTimestamp = DateTime.now().millisecondsSinceEpoch;
    final tDateTime = DateTime.fromMillisecondsSinceEpoch(tTimestamp);

    test('should return DateTime from cache when there is one', () async {
      // Arrange
      when(mockMetadataBox.get(metadataTimestampKey)).thenReturn(tTimestamp);
      // Act
      final result = await dataSource.getLastFetchTime();
      // Assert
      expect(result, equals(tDateTime));
      verify(mockMetadataBox.get(metadataTimestampKey));
    });

    test('should return null when there is no timestamp in cache', () async {
      // Arrange
      when(mockMetadataBox.get(metadataTimestampKey)).thenReturn(null);
      // Act
      final result = await dataSource.getLastFetchTime();
      // Assert
      expect(result, isNull);
      verify(mockMetadataBox.get(metadataTimestampKey));
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(
        mockMetadataBox.get(metadataTimestampKey),
      ).thenThrow(Exception('Hive failed'));
      // Act
      final call = dataSource.getLastFetchTime();
      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockMetadataBox.get(metadataTimestampKey));
    });

    test('should return null if the stored value is not an int', () async {
      // Arrange
      when(
        mockMetadataBox.get(metadataTimestampKey),
      ).thenReturn('not a timestamp'); // Stored wrong type
      // Act
      final result = await dataSource.getLastFetchTime();
      // Assert
      expect(result, isNull);
      verify(mockMetadataBox.get(metadataTimestampKey));
    });
  });

  group('saveLastFetchTime', () {
    final tDateTime = DateTime.now();
    final tTimestamp = tDateTime.toUtc().millisecondsSinceEpoch;

    test('should call Hive to save the timestamp', () async {
      // Arrange
      when(
        mockMetadataBox.put(metadataTimestampKey, tTimestamp),
      ).thenAnswer((_) async => Future<void>.value()); // Mock put
      // Act
      await dataSource.saveLastFetchTime(tDateTime);
      // Assert
      verify(mockMetadataBox.put(metadataTimestampKey, tTimestamp));
    });

    test('should throw CacheException when Hive call fails', () async {
      // Arrange
      when(
        mockMetadataBox.put(metadataTimestampKey, tTimestamp),
      ).thenThrow(Exception('Hive failed'));
      // Act
      final call = dataSource.saveLastFetchTime(tDateTime);
      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      verify(mockMetadataBox.put(metadataTimestampKey, tTimestamp));
    });
  });
}
