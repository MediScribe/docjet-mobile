import 'package:flutter_test/flutter_test.dart';
import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:uuid/uuid.dart';

void main() {
  const testUserId = 'test-user-id'; // Dummy user ID for tests

  group('Job Entity', () {
    final tNow = DateTime.now();
    final tLocalId = 'local-uuid-123';
    final tServerId = 'server-id-456';

    // Base job for reference if needed in multiple tests
    // final baseJob = Job(...);

    test('should be a subclass of Equatable', () {
      // Arrange
      final job = Job(
        localId: tLocalId,
        serverId: null, // Initially null
        status: JobStatus.transcribing,
        syncStatus: SyncStatus.pending,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
      );
      // Assert
      expect(job, isA<Equatable>());
    });

    test('should correctly instantiate with localId and nullable serverId', () {
      // Arrange & Act: Create with null serverId
      final job1 = Job(
        localId: tLocalId,
        serverId: null,
        status: JobStatus.transcribing,
        syncStatus: SyncStatus.pending,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
      );
      // Assert
      expect(job1.localId, tLocalId);
      expect(job1.serverId, isNull);

      // Arrange & Act: Create with non-null serverId
      final job2 = Job(
        localId: tLocalId,
        serverId: tServerId,
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
      );
      // Assert
      expect(job2.localId, tLocalId);
      expect(job2.serverId, tServerId);
    });

    test('should have correct props for Equatable comparison', () {
      // Arrange
      final job1 = Job(
        localId: tLocalId,
        serverId: tServerId,
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
        displayTitle: 'Test Job',
        displayText: 'Test text',
        errorCode: null,
        errorMessage: null,
        audioFilePath: '/path/to/audio.aac',
        text: 'Submitted text',
        additionalText: 'More info',
        retryCount: 3,
        lastSyncAttemptAt: tNow.subtract(const Duration(minutes: 10)),
        failedAudioDeletionAttempts: 1, // Test with non-default value
      );

      final job2 = Job(
        localId: tLocalId,
        serverId: tServerId,
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
        displayTitle: 'Test Job',
        displayText: 'Test text',
        errorCode: null,
        errorMessage: null,
        audioFilePath: '/path/to/audio.aac',
        text: 'Submitted text',
        additionalText: 'More info',
        retryCount: 3,
        lastSyncAttemptAt: tNow.subtract(const Duration(minutes: 10)),
        failedAudioDeletionAttempts: 1, // Match the value
      );

      // Assert: Equality check
      expect(job1, equals(job2));

      // Assert: Props list includes all fields, including the new one
      expect(
        job1.props,
        equals([
          tLocalId,
          tServerId,
          JobStatus.completed,
          SyncStatus.synced,
          tNow,
          tNow,
          testUserId,
          'Test Job',
          'Test text',
          null, // errorCode
          null, // errorMessage
          '/path/to/audio.aac',
          'Submitted text',
          'More info',
          3, // retryCount
          tNow.subtract(const Duration(minutes: 10)), // lastSyncAttemptAt
          1, // failedAudioDeletionAttempts
        ]),
      );
    });

    test('copyWith should create a copy with updated fields', () {
      // Arrange
      final originalJob = Job(
        localId: tLocalId,
        serverId: null,
        status: JobStatus.created,
        syncStatus: SyncStatus.pending,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
      );

      // Act: Copy with updated serverId and status
      final updatedJob = originalJob.copyWith(
        serverId: tServerId,
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
      );

      // Assert
      expect(updatedJob.localId, tLocalId); // Should remain the same
      expect(updatedJob.serverId, tServerId); // Should be updated
      expect(updatedJob.status, JobStatus.completed);
      expect(updatedJob.syncStatus, SyncStatus.synced);
      expect(updatedJob.userId, testUserId); // Should remain the same
      expect(updatedJob.createdAt, originalJob.createdAt);
    });

    test(
      'copyWith should correctly handle null values for optional fields',
      () {
        // Arrange
        final job = Job(
          localId: tLocalId,
          serverId: null,
          status: JobStatus.transcribing,
          syncStatus: SyncStatus.pending,
          createdAt: tNow,
          updatedAt: tNow,
          userId: testUserId,
          // Start with some non-null optional values
          displayTitle: 'Original Title',
          audioFilePath: '/original/path',
          retryCount: 1,
          failedAudioDeletionAttempts: 1,
        );

        // Act: Copy with explicit nulls for optional fields
        final updatedJob = job.copyWith(
          serverId: tServerId, // Update a required field too
          displayTitle: null, // Pass null
          setDisplayTitleNull: true, // Set the flag to actually USE the null
          audioFilePath: null, // Pass null
          setAudioFilePathNull: true, // Set the flag to actually USE the null
          // Keep others the same for this specific null test
          status: job.status,
          syncStatus: job.syncStatus,
        );

        // Assert: Check updated and nulled fields
        expect(updatedJob.localId, tLocalId);
        expect(updatedJob.serverId, tServerId);
        expect(updatedJob.status, job.status);
        expect(updatedJob.syncStatus, job.syncStatus);
        expect(updatedJob.userId, testUserId);
        expect(updatedJob.createdAt, job.createdAt);

        expect(updatedJob.displayTitle, isNull); // Should be null due to flag
        expect(
          updatedJob.audioFilePath,
          isNull,
        ); // Should be null due to ?? logic (original was not null)
        // Non-nullable fields retain original value as no new value was passed
        expect(updatedJob.retryCount, job.retryCount);
        expect(
          updatedJob.failedAudioDeletionAttempts,
          job.failedAudioDeletionAttempts,
        );
      },
    );

    test('copyWith should retain original values if not provided', () {
      // Arrange
      final originalJob = Job(
        localId: tLocalId,
        serverId: tServerId,
        status: JobStatus.created,
        syncStatus: SyncStatus.pending,
        createdAt: tNow,
        updatedAt: tNow,
        userId: testUserId,
        text: 'Original text',
        retryCount: 1,
        failedAudioDeletionAttempts: 1,
      );

      // Act: Copy with only one field updated
      final updatedJob = originalJob.copyWith(text: 'New Text');

      // Assert: Check updated field and that others remain unchanged
      expect(updatedJob.localId, originalJob.localId);
      expect(updatedJob.serverId, originalJob.serverId);
      expect(updatedJob.userId, originalJob.userId);
      expect(updatedJob.createdAt, originalJob.createdAt);
      expect(updatedJob.status, originalJob.status);
      expect(updatedJob.syncStatus, originalJob.syncStatus);
      expect(updatedJob.retryCount, originalJob.retryCount);
      expect(
        updatedJob.failedAudioDeletionAttempts,
        originalJob.failedAudioDeletionAttempts,
      );
      expect(updatedJob.text, 'New Text');
    });

    test('should have a default failedAudioDeletionAttempts of 0', () {
      // Arrange: Create a minimal job instance without specifying the field
      final job = Job(
        localId: 'minimal-id',
        userId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: JobStatus.created,
        syncStatus: SyncStatus.pending,
      );

      // Assert
      expect(job.failedAudioDeletionAttempts, 0);
      // Also check it's included in props with the default value
      expect(job.props, contains(0));
    });

    test('copyWith should update failedAudioDeletionAttempts', () {
      // Arrange
      final initialJob = Job(
        localId: const Uuid().v4(),
        userId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: JobStatus.created,
        syncStatus: SyncStatus.pending,
        failedAudioDeletionAttempts: 0, // Start with default
      );

      // Act
      final updatedJob = initialJob.copyWith(failedAudioDeletionAttempts: 5);

      // Assert
      expect(updatedJob.failedAudioDeletionAttempts, 5);
      // Verify other fields are retained
      expect(updatedJob.localId, initialJob.localId);
      expect(updatedJob.status, initialJob.status);
    });

    // Test JobStatus Enum - Check a couple of values
    test('JobStatus enum should have expected values', () {
      expect(JobStatus.created, isA<JobStatus>());
      expect(JobStatus.values, contains(JobStatus.completed));
      expect(JobStatus.values, contains(JobStatus.error));
    });

    // Test SyncStatus Enum - Check a couple of values
    test('SyncStatus enum should have expected values', () {
      expect(SyncStatus.pending, isA<SyncStatus>());
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.failed));
    });
  });
}
