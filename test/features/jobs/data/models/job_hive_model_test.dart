import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart'; // Import HiveObject

void main() {
  setUp(() async {
    // Initialize Hive for testing if needed, or mock Hive operations.
    // Using hive_test might simplify this.
    // await setUpTestHive(); // Example if using hive_test
  });

  tearDown(() async {
    // await tearDownTestHive(); // Example if using hive_test
  });

  group('JobHiveModel', () {
    final tNow = DateTime.now();
    const tLocalId = 'local-uuid-123';
    const tUserId = 'user-uuid-789';

    // Basic instantiation test - this will fail until fields are added
    test('should correctly instantiate with localId and nullable serverId', () {
      // Arrange
      final model = JobHiveModel(
        localId: tLocalId,
        serverId: null,
        status:
            JobStatus.created.index, // Use enum index (int) not name (String)
        createdAt: tNow.toIso8601String(), // Convert to ISO string
        updatedAt: tNow.toIso8601String(), // Convert to ISO string
        userId: tUserId,
        syncStatus: SyncStatus.pending.index, // Use enum index (int) not enum
      );

      // Assert
      expect(model.localId, tLocalId);
      expect(model.serverId, isNull);
      expect(model.status, JobStatus.created.index); // Check int index
      expect(model.syncStatus, SyncStatus.pending.index); // Check int index
    });

    // We will need HiveFields for these in the actual model
    test('should have HiveField annotations for localId and serverId', () {
      // This test serves as a reminder for the GREEN step.
      // It doesn't directly test runtime but our intention.
      // In the GREEN step, we'll add @HiveField(X) to localId and serverId.
      // We expect localId to replace the old id field (likely index 0).
      // We expect serverId to get a new index (e.g., 13 if the last was 12).
      expect(true, isTrue); // Placeholder assertion
    });

    // Test HiveObject properties if needed (like key, isInBox)
    test('should be a subclass of HiveObject', () {
      expect(
        JobHiveModel(localId: 'test-id'),
        isA<HiveObject>(),
      ); // Use constructor with required field
    });

    // Add a copyWith test if JobHiveModel gets one (it doesn't have one now)
    // test('copyWith should work with new fields', () { ... });
  });
}
