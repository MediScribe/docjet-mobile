import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:equatable/equatable.dart';

void main() {
  final tDateTime = DateTime.parse('2023-01-01T12:00:00Z');
  const tTranscriptionMinimal = Transcription(
    localFilePath: '/path/to/audio.m4a',
    status: TranscriptionStatus.created,
  );

  final tTranscriptionFull = Transcription(
    id: 'uuid-123',
    localFilePath: '/path/to/audio.m4a',
    status: TranscriptionStatus.completed,
    localCreatedAt: tDateTime,
    backendCreatedAt: tDateTime.add(const Duration(minutes: 1)),
    backendUpdatedAt: tDateTime.add(const Duration(minutes: 5)),
    localDurationMillis: 60000, // 1 minute
    // backendDurationMillis: null, // Removed
    displayTitle: 'Meeting Notes',
    displayText: 'This is the transcript...',
    errorCode: null,
    errorMessage: null,
  );

  group('Transcription Entity', () {
    test('should be a subclass of Equatable', () {
      expect(tTranscriptionMinimal, isA<Equatable>());
    });

    test('should have correct props for Equatable', () {
      // Test with minimal fields
      const minimal = Transcription(
        localFilePath: 'path1',
        status: TranscriptionStatus.created,
      );
      expect(
        minimal.props,
        containsAll([
          null, // id
          'path1',
          TranscriptionStatus.created,
          null, // localCreatedAt
          null, // backendCreatedAt
          null, // backendUpdatedAt
          null, // localDurationMillis
          // null, // backendDurationMillis REMOVED
          null, // displayTitle
          null, // displayText
          null, // errorCode
          null, // errorMessage
        ]),
      );

      // Test with all fields (matching tTranscriptionFull)
      expect(
        tTranscriptionFull.props,
        containsAll([
          'uuid-123',
          '/path/to/audio.m4a',
          TranscriptionStatus.completed,
          tDateTime,
          tDateTime.add(const Duration(minutes: 1)),
          tDateTime.add(const Duration(minutes: 5)),
          60000,
          // null, // REMOVED
          'Meeting Notes',
          'This is the transcript...',
          null,
          null,
        ]),
      );
    });

    test('instances with same properties should be equal', () {
      const instance1 = Transcription(
        localFilePath: 'path1',
        status: TranscriptionStatus.submitted,
        localDurationMillis: 1000,
      );
      const instance2 = Transcription(
        localFilePath: 'path1',
        status: TranscriptionStatus.submitted,
        localDurationMillis: 1000,
      );
      expect(instance1, equals(instance2));
    });

    test('instances with different properties should not be equal', () {
      const instance1 = Transcription(
        localFilePath: 'path1',
        status: TranscriptionStatus.submitted,
      );
      const instance2 = Transcription(
        localFilePath: 'path2', // Different path
        status: TranscriptionStatus.submitted,
      );
      const instance3 = Transcription(
        localFilePath: 'path1',
        status: TranscriptionStatus.processing, // Different status
      );
      expect(instance1, isNot(equals(instance2)));
      expect(instance1, isNot(equals(instance3)));
    });

    group('displayDurationMillis', () {
      test('should return localDurationMillis when it is not null', () {
        const transcription = Transcription(
          localFilePath: 'path',
          status: TranscriptionStatus.created,
          localDurationMillis: 15000,
        );
        expect(transcription.displayDurationMillis, 15000);
      });

      test('should return null when localDurationMillis is null', () {
        const transcription = Transcription(
          localFilePath: 'path',
          status: TranscriptionStatus.created,
          localDurationMillis: null, // Explicitly null
        );
        expect(transcription.displayDurationMillis, isNull);
      });

      // Removed tests related to backendDurationMillis precedence
    });
  });
}
