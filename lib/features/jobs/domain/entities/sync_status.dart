import 'package:hive/hive.dart';

part 'sync_status.g.dart';

/// Enum representing the synchronization status of a local model.
@HiveType(typeId: 2) // Assign a unique typeId
enum SyncStatus {
  /// The item has been created or modified locally and needs to be synced with the backend.
  @HiveField(0)
  pending,

  /// The item is successfully synced with the backend.
  @HiveField(1)
  synced,

  /// The item has been marked for deletion locally and needs to be deleted on the backend.
  @HiveField(2)
  pendingDeletion,

  /// An error occurred during the last sync attempt for this item.
  @HiveField(3)
  error,

  /// Sync failed permanently after exceeding retry limit
  @HiveField(4)
  failed,
}
