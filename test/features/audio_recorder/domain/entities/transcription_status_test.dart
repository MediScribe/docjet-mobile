import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

void main() {
  group('TranscriptionStatusX', () {
    group('fromString', () {
      test('should return correct enum for known lowercase status strings', () {
        expect(
          TranscriptionStatusX.fromString('created'),
          TranscriptionStatus.created,
        );
        expect(
          TranscriptionStatusX.fromString('submitted'),
          TranscriptionStatus.submitted,
        );
        expect(
          TranscriptionStatusX.fromString('processing'),
          TranscriptionStatus.processing,
        );
        expect(
          TranscriptionStatusX.fromString('transcribed'),
          TranscriptionStatus.transcribed,
        );
        expect(
          TranscriptionStatusX.fromString('generating'),
          TranscriptionStatus.generating,
        );
        expect(
          TranscriptionStatusX.fromString('completed'),
          TranscriptionStatus.completed,
        );
        expect(
          TranscriptionStatusX.fromString('failed'),
          TranscriptionStatus.failed,
        );
      });

      test('should return correct enum for known uppercase status strings', () {
        expect(
          TranscriptionStatusX.fromString('CREATED'),
          TranscriptionStatus.created,
        );
        expect(
          TranscriptionStatusX.fromString('SUBMITTED'),
          TranscriptionStatus.submitted,
        );
        // ... add others if case-insensitivity is critical
      });

      test('should return unknown for null input', () {
        expect(
          TranscriptionStatusX.fromString(null),
          TranscriptionStatus.unknown,
        );
      });

      test('should return unknown for unknown status strings', () {
        expect(
          TranscriptionStatusX.fromString('pending'),
          TranscriptionStatus.unknown,
        );
        expect(
          TranscriptionStatusX.fromString('random_garbage'),
          TranscriptionStatus.unknown,
        );
        expect(
          TranscriptionStatusX.fromString(''),
          TranscriptionStatus.unknown,
        );
      });
    });

    group('toJson', () {
      test('should return correct lowercase string for each enum value', () {
        expect(TranscriptionStatus.created.toJson(), 'created');
        expect(TranscriptionStatus.submitted.toJson(), 'submitted');
        expect(TranscriptionStatus.processing.toJson(), 'processing');
        expect(TranscriptionStatus.transcribed.toJson(), 'transcribed');
        expect(TranscriptionStatus.generating.toJson(), 'generating');
        expect(TranscriptionStatus.completed.toJson(), 'completed');
        expect(TranscriptionStatus.failed.toJson(), 'failed');
        expect(TranscriptionStatus.unknown.toJson(), 'unknown');
      });
    });

    group('displayLabel', () {
      test('should return non-empty string for all statuses', () {
        for (var status in TranscriptionStatus.values) {
          expect(status.displayLabel, isNotEmpty);
        }
      });
      // TODO: Add specific label tests if needed, potentially with localization checks later
    });

    group('isFinal', () {
      test('should return true only for completed and failed', () {
        expect(TranscriptionStatus.completed.isFinal, isTrue);
        expect(TranscriptionStatus.failed.isFinal, isTrue);
        expect(TranscriptionStatus.created.isFinal, isFalse);
        expect(TranscriptionStatus.submitted.isFinal, isFalse);
        expect(TranscriptionStatus.processing.isFinal, isFalse);
        expect(TranscriptionStatus.transcribed.isFinal, isFalse);
        expect(TranscriptionStatus.generating.isFinal, isFalse);
        expect(TranscriptionStatus.unknown.isFinal, isFalse);
      });
    });

    group('isInProgress', () {
      test(
        'should return true for submitted, processing, transcribed, generating',
        () {
          expect(TranscriptionStatus.submitted.isInProgress, isTrue);
          expect(TranscriptionStatus.processing.isInProgress, isTrue);
          expect(TranscriptionStatus.transcribed.isInProgress, isTrue);
          expect(TranscriptionStatus.generating.isInProgress, isTrue);
        },
      );

      test('should return false for created, completed, failed, unknown', () {
        expect(TranscriptionStatus.created.isInProgress, isFalse);
        expect(TranscriptionStatus.completed.isInProgress, isFalse);
        expect(TranscriptionStatus.failed.isInProgress, isFalse);
        expect(TranscriptionStatus.unknown.isInProgress, isFalse);
      });
    });
  });
}
