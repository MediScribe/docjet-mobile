import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late JobViewModelMapper mapper;

  setUp(() {
    mapper = JobViewModelMapper();
  });

  group('JobViewModelMapper', () {
    test('should map Job entity to JobViewModel correctly', () {
      // Arrange
      final localId = Uuid().v4();
      final jobEntity = Job(
        localId: localId,
        userId: 'test-user-id',
        status: JobStatus.completed,
        serverId: 'server-123',
        text: 'Test Job Text',
        audioFilePath: '/path/to/audio.mp3',
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
        syncStatus: SyncStatus.synced,
        retryCount: 0,
        lastSyncAttemptAt: null,
        failedAudioDeletionAttempts: 0,
      );

      final expectedViewModel = JobViewModel(
        localId: localId,
        title: 'Test Job Text',
        text: 'Test Job Text',
        syncStatus: SyncStatus.synced,
        hasFileIssue: false, // 0 attempts means no issue
        displayDate:
            jobEntity
                .updatedAt, // Assuming we want to show the latest update time
      );

      // Act
      final result = mapper.toViewModel(jobEntity);

      // Assert
      expect(result, equals(expectedViewModel));
    });

    test(
      'should set hasFileIssue to true when failedAudioDeletionAttempts > 0',
      () {
        // Arrange
        final localId = Uuid().v4();
        final jobEntity = Job(
          localId: localId,
          userId: 'test-user-id-2',
          status: JobStatus.completed,
          serverId: 'server-456',
          text: 'Another Job',
          audioFilePath: '/path/to/another/audio.mp3',
          createdAt: DateTime(2023, 2, 1),
          updatedAt: DateTime(2023, 2, 2),
          syncStatus: SyncStatus.synced,
          retryCount: 0,
          lastSyncAttemptAt: null,
          failedAudioDeletionAttempts: 3, // > 0 attempts
        );

        final expectedViewModel = JobViewModel(
          localId: localId,
          title: 'Another Job',
          text: 'Another Job',
          syncStatus: SyncStatus.synced,
          hasFileIssue: true, // Should be true now
          displayDate: jobEntity.updatedAt,
        );

        // Act
        final result = mapper.toViewModel(jobEntity);

        // Assert
        expect(result.hasFileIssue, isTrue);
        expect(result, equals(expectedViewModel));
      },
    );
  });
}
