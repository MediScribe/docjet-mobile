import 'package:flutter_test/flutter_test.dart';
import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

void main() {
  group('Job Entity', () {
    final tNow = DateTime.now();
    final tLocalId = 'local-uuid-123';
    final tServerId = 'server-id-456';
    final tUserId = 'user-uuid-789';

    test('should be a subclass of Equatable', () {
      // Arrange
      final job = Job(
        localId: tLocalId,
        serverId: null, // Initially null
        status: JobStatus.transcribing,
        syncStatus: SyncStatus.pending,
        createdAt: tNow,
        updatedAt: tNow,
        userId: tUserId,
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
        userId: tUserId,
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
        userId: tUserId,
      );
      // Assert
      expect(job2.localId, tLocalId);
      expect(job2.serverId, tServerId);
    });

    test('should have correct props for Equatable comparison', () {
      // Arrange
      final job = Job(
        localId: tLocalId,
        serverId: tServerId,
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        createdAt: tNow,
        updatedAt: tNow,
        userId: tUserId,
        displayTitle: 'Test Job',
        displayText: 'Test text',
        errorCode: null,
        errorMessage: null,
        audioFilePath: '/path/to/audio.aac',
        text: 'Submitted text',
        additionalText: 'More info',
      );

      // Assert
      // This test will fail until localId and serverId are added to props
      expect(
        job.props,
        equals([
          tLocalId, // New
          tServerId, // New
          JobStatus.completed,
          SyncStatus.synced,
          tNow,
          tNow,
          tUserId,
          'Test Job',
          'Test text',
          null,
          null,
          '/path/to/audio.aac',
          'Submitted text',
          'More info',
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
        userId: tUserId,
      );

      // Act: Copy with updated serverId and status
      final updatedJob = originalJob.copyWith(
        serverId: tServerId,
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
      );

      // Assert
      // This test will fail until copyWith includes localId and serverId
      expect(updatedJob.localId, tLocalId); // Should remain the same
      expect(updatedJob.serverId, tServerId); // Should be updated
      expect(
        updatedJob.status,
        JobStatus.completed,
      ); // Corrected assertion status
      expect(updatedJob.syncStatus, SyncStatus.synced);
      expect(updatedJob.userId, tUserId); // Should remain the same
    });
  });
}
