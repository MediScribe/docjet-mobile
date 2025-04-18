import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

void main() {
  group('SyncStatus', () {
    test('should contain pendingDeletion value', () {
      // This will fail until pendingDeletion is added to the enum
      expect(SyncStatus.values, contains(SyncStatus.pendingDeletion));
    });

    test('pendingDeletion should have correct string representation', () {
      // This tests the generated toString or manual override if any
      // Adjust the expected string based on how enums are stringified
      expect(SyncStatus.pendingDeletion.name, equals('pendingDeletion'));
    });

    // Optional: Test existing values if needed
    test('should contain existing values', () {
      expect(SyncStatus.values, contains(SyncStatus.pending));
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.error));
    });
  });
}
