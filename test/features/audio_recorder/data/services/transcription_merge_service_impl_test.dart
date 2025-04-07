import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/transcription_merge_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

void main() {
  late TranscriptionMergeServiceImpl mergeService;

  setUp(() {
    mergeService = TranscriptionMergeServiceImpl();
  });

  // --- Test Data Helpers ---
  final tNow = DateTime.now();

  // Local Job Examples
  final tLocalCreated = LocalJob(
    localFilePath: '/local/created.m4a',
    durationMillis: 10000,
    status: TranscriptionStatus.created,
    localCreatedAt: tNow.subtract(const Duration(days: 1)),
    backendId: null,
  );
  final tLocalSynced = LocalJob(
    localFilePath: '/local/synced.m4a',
    durationMillis: 20000,
    status: TranscriptionStatus.submitted, // Local might lag
    localCreatedAt: tNow.subtract(const Duration(hours: 12)),
    backendId: 'backend-id-synced',
  );
  final tLocalAnomalous = LocalJob(
    localFilePath: '/local/anomalous.m4a',
    durationMillis: 5000,
    status: TranscriptionStatus.created,
    localCreatedAt: tNow.subtract(const Duration(hours: 1)),
    backendId: 'backend-id-anomalous', // Remote doesn't know this ID
  );

  // Remote Job Examples
  final tRemoteSynced = Transcription(
    id: 'backend-id-synced',
    localFilePath: '', // Will be overridden by merge
    status: TranscriptionStatus.processing,
    localCreatedAt: null, // Will be overridden by merge
    backendCreatedAt: tNow.subtract(const Duration(hours: 11)),
    backendUpdatedAt: tNow.subtract(
      const Duration(minutes: 30),
    ), // Newest update time
    localDurationMillis: null, // Will be overridden by merge
    displayTitle: 'Synced Title',
  );
  final tRemoteBackendOnly = Transcription(
    id: 'backend-id-web',
    localFilePath: '', // No local path known
    status: TranscriptionStatus.completed,
    localCreatedAt: null,
    backendCreatedAt: tNow.subtract(const Duration(days: 2)),
    backendUpdatedAt: tNow.subtract(
      const Duration(days: 1),
    ), // Older update time
    localDurationMillis: null,
    displayTitle: 'Web Upload Title',
    displayText: 'Some text',
  );

  group('TranscriptionMergeServiceImpl', () {
    test('should correctly merge synced jobs, prioritizing remote data', () {
      // Arrange
      final remoteJobs = [tRemoteSynced];
      final localJobs = [tLocalCreated, tLocalSynced];

      // Act
      final result = mergeService.mergeJobs(remoteJobs, localJobs);

      // Assert
      expect(result.length, 2);

      // Verify synced job (should be first due to sort by backendUpdatedAt)
      final synced = result.firstWhere((t) => t.id == 'backend-id-synced');
      expect(synced.status, tRemoteSynced.status); // Remote status wins
      expect(
        synced.displayTitle,
        tRemoteSynced.displayTitle,
      ); // Remote title wins
      expect(synced.backendUpdatedAt, tRemoteSynced.backendUpdatedAt);
      expect(
        synced.localFilePath,
        tLocalSynced.localFilePath,
      ); // Local path kept
      expect(
        synced.localCreatedAt,
        tLocalSynced.localCreatedAt,
      ); // Local created kept
      expect(
        synced.localDurationMillis,
        tLocalSynced.durationMillis,
      ); // Local duration kept

      // Verify local-only job
      final localOnly = result.firstWhere((t) => t.id == null);
      expect(localOnly.status, tLocalCreated.status);
      expect(localOnly.localFilePath, tLocalCreated.localFilePath);
      expect(localOnly.localCreatedAt, tLocalCreated.localCreatedAt);
      expect(localOnly.localDurationMillis, tLocalCreated.durationMillis);
      expect(localOnly.backendUpdatedAt, isNull);
      expect(localOnly.displayTitle, isNull);

      // Verify sort order (newest backendUpdatedAt/localCreatedAt first)
      expect(result[0].id, 'backend-id-synced');
      expect(result[1].id, isNull);
    });

    test('should include backend-only jobs not present locally', () {
      // Arrange
      final remoteJobs = [tRemoteSynced, tRemoteBackendOnly];
      final localJobs = [tLocalSynced]; // Only matches tRemoteSynced

      // Act
      final result = mergeService.mergeJobs(remoteJobs, localJobs);

      // Assert
      expect(result.length, 2);

      // Find and verify the backend-only item
      final backendOnly = result.firstWhere((t) => t.id == 'backend-id-web');
      expect(backendOnly.localFilePath, isEmpty); // No local path
      expect(backendOnly.status, tRemoteBackendOnly.status);
      expect(backendOnly.displayTitle, tRemoteBackendOnly.displayTitle);
      expect(backendOnly.displayText, tRemoteBackendOnly.displayText);
      expect(backendOnly.localCreatedAt, isNull);
      expect(backendOnly.localDurationMillis, isNull);
      expect(backendOnly.backendUpdatedAt, tRemoteBackendOnly.backendUpdatedAt);

      // Find and verify the synced item (check one key field)
      final synced = result.firstWhere((t) => t.id == 'backend-id-synced');
      expect(synced.localFilePath, tLocalSynced.localFilePath);

      // Verify sort order (tRemoteSynced has newer backendUpdatedAt)
      expect(result[0].id, 'backend-id-synced');
      expect(result[1].id, 'backend-id-web');
    });

    test('should handle empty remote list, returning only local jobs', () {
      // Arrange
      final remoteJobs = <Transcription>[];
      final localJobs = [tLocalCreated];

      // Act
      final result = mergeService.mergeJobs(remoteJobs, localJobs);

      // Assert
      expect(result.length, 1);
      expect(result[0].id, isNull);
      expect(result[0].localFilePath, tLocalCreated.localFilePath);
      expect(result[0].status, tLocalCreated.status);
    });

    test('should handle empty local list, returning only remote jobs', () {
      // Arrange
      final remoteJobs = [tRemoteBackendOnly];
      final localJobs = <LocalJob>[];

      // Act
      final result = mergeService.mergeJobs(remoteJobs, localJobs);

      // Assert
      expect(result.length, 1);
      expect(result[0].id, tRemoteBackendOnly.id);
      expect(result[0].localFilePath, isEmpty);
    });

    test('should handle both lists being empty', () {
      // Arrange
      final remoteJobs = <Transcription>[];
      final localJobs = <LocalJob>[];

      // Act
      final result = mergeService.mergeJobs(remoteJobs, localJobs);

      // Assert
      expect(result, isEmpty);
    });

    test(
      'should handle anomalous local jobs (with backendId not in remote list)',
      () {
        // Arrange
        final remoteJobs = <Transcription>[]; // Remote knows nothing
        final localJobs = [tLocalAnomalous]; // Local has ID remote doesn't

        // Act
        final result = mergeService.mergeJobs(remoteJobs, localJobs);

        // Assert
        expect(result.length, 1);
        final anomalous = result[0];
        expect(
          anomalous.id,
          tLocalAnomalous.backendId,
        ); // Keeps known backendId
        expect(anomalous.localFilePath, tLocalAnomalous.localFilePath);
        expect(anomalous.status, tLocalAnomalous.status); // Keeps local status
        expect(anomalous.localCreatedAt, tLocalAnomalous.localCreatedAt);
        expect(anomalous.localDurationMillis, tLocalAnomalous.durationMillis);
        expect(anomalous.backendUpdatedAt, isNull);
        expect(anomalous.displayTitle, isNull);
      },
    );

    // TODO: Add more tests for sorting edge cases (null dates, equal dates)
    // TODO: Add tests for multiple local jobs matching one remote ID (if needed)
  });
}
