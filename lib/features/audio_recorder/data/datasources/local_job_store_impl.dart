import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-based implementation of the [LocalJobStore] interface.
///
/// Uses a Hive [Box] to persist [LocalJob] objects.
/// The `localFilePath` of the [LocalJob] is used as the key in the box.
class HiveLocalJobStoreImpl implements LocalJobStore {
  /// The name of the Hive box used to store local jobs.
  static const String boxName = 'local_jobs';

  final Box<LocalJob> _box;

  /// Creates an instance of [HiveLocalJobStoreImpl].
  ///
  /// Requires an opened [Box<LocalJob>] to be passed.
  /// This ensures Hive is initialized and the box is ready before use.
  HiveLocalJobStoreImpl(this._box);

  /// Opens the Hive box required by this store.
  ///
  /// Must be called during app initialization before creating an instance
  /// of [HiveLocalJobStoreImpl]. Also registers the necessary adapter.
  static Future<Box<LocalJob>> openBox() async {
    // Register adapter if not already registered (safe to call multiple times)
    if (!Hive.isAdapterRegistered(LocalJobAdapter().typeId)) {
      Hive.registerAdapter(LocalJobAdapter());
    }
    // Register TranscriptionStatus adapter (Hive needs explicit handling for enums in lists/maps sometimes)
    // If not using complex structures with enums, the field adapter might suffice.
    // Let's register it defensively.
    return await Hive.openBox<LocalJob>(boxName);
  }

  @override
  Future<void> saveJob(LocalJob job) async {
    // Use localFilePath as the key for direct access and update.
    await _box.put(job.localFilePath, job);
  }

  @override
  Future<LocalJob?> getJob(String localFilePath) async {
    return _box.get(localFilePath);
  }

  @override
  Future<List<LocalJob>> getAllLocalJobs() async {
    return _box.values.toList();
  }

  @override
  Future<List<LocalJob>> getOfflineJobs() async {
    // Filter jobs that are typically considered needing upload/sync.
    // Adjust this logic based on specific requirements (e.g., include failed uploads for retry).
    return _box.values
        .where((job) => job.status == TranscriptionStatus.created)
        .toList();
  }

  @override
  Future<void> updateJobStatus(
    String localFilePath,
    TranscriptionStatus status, {
    String? backendId,
  }) async {
    final existingJob = _box.get(localFilePath);
    if (existingJob != null) {
      // Create a new instance with updated fields.
      // Hive requires putting the whole object again.
      final updatedJob = LocalJob(
        localFilePath: existingJob.localFilePath,
        durationMillis: existingJob.durationMillis,
        localCreatedAt: existingJob.localCreatedAt,
        status: status, // Update status
        backendId:
            backendId ?? existingJob.backendId, // Update backendId if provided
      );
      await _box.put(localFilePath, updatedJob);
    }
    // else: Job not found, maybe log this? Or silently ignore?
  }

  @override
  Future<void> deleteJob(String localFilePath) async {
    await _box.delete(localFilePath);
  }
}
