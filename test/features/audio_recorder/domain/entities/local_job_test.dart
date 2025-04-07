import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:equatable/equatable.dart';

void main() {
  final tDateTime = DateTime.parse('2023-01-01T10:00:00Z');
  final tLocalJob = LocalJob(
    localFilePath: '/data/user/0/com.example.app/files/recording_1.m4a',
    durationMillis: 12345,
    status: TranscriptionStatus.created,
    localCreatedAt: tDateTime,
    backendId: null, // Initially null
  );

  final tLocalJobWithBackendId = LocalJob(
    localFilePath: '/data/user/0/com.example.app/files/recording_2.m4a',
    durationMillis: 54321,
    status: TranscriptionStatus.submitted,
    localCreatedAt: tDateTime.add(const Duration(hours: 1)),
    backendId: 'uuid-backend-567',
  );

  group('LocalJob Entity', () {
    test('should be a subclass of Equatable', () {
      expect(tLocalJob, isA<Equatable>());
    });

    test('should have correct props for Equatable', () {
      expect(
        tLocalJob.props,
        containsAll([
          '/data/user/0/com.example.app/files/recording_1.m4a',
          12345,
          TranscriptionStatus.created,
          tDateTime,
          null, // backendId
        ]),
      );

      expect(
        tLocalJobWithBackendId.props,
        containsAll([
          '/data/user/0/com.example.app/files/recording_2.m4a',
          54321,
          TranscriptionStatus.submitted,
          tDateTime.add(const Duration(hours: 1)),
          'uuid-backend-567', // backendId
        ]),
      );
    });

    test('instances with same properties should be equal', () {
      final instance1 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 1000,
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime,
      );
      final instance2 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 1000,
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime,
      );
      expect(instance1, equals(instance2));
    });

    test('instances with different properties should not be equal', () {
      final instance1 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 1000,
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime,
      );
      final instance2 = LocalJob(
        localFilePath: 'path2', // Different path
        durationMillis: 1000,
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime,
      );
      final instance3 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 2000, // Different duration
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime,
      );
      final instance4 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 1000,
        status: TranscriptionStatus.submitted, // Different status
        localCreatedAt: tDateTime,
      );
      final instance5 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 1000,
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime.add(
          const Duration(seconds: 1),
        ), // Different time
      );
      final instance6 = LocalJob(
        localFilePath: 'path1',
        durationMillis: 1000,
        status: TranscriptionStatus.created,
        localCreatedAt: tDateTime,
        backendId: 'id1', // Different backendId (null vs non-null)
      );

      expect(instance1, isNot(equals(instance2)));
      expect(instance1, isNot(equals(instance3)));
      expect(instance1, isNot(equals(instance4)));
      expect(instance1, isNot(equals(instance5)));
      expect(instance1, isNot(equals(instance6)));
    });
  });
}
