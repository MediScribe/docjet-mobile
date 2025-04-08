import 'dart:io';
import 'dart:typed_data';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p; // For path joining
import 'package:shared_preferences/shared_preferences.dart';

/// Handles seeding initial data, like sample recordings, on first app launch.
class AppSeeder {
  final LocalJobStore _localJobStore;
  final PathProvider _pathProvider;
  final FileSystem _fileSystem;
  final AudioDurationRetriever _audioDurationRetriever;
  final SharedPreferences _prefs;

  // --- Configuration for the sample ---
  static const String _sampleAssetPath =
      'assets/audio/short-audio-test-file.m4a';
  // Use a specific, identifiable filename in the documents directory
  static const String _sampleTargetFilename = 'sample_recording_short_test.m4a';
  // Key to check if seeding was already done
  static const String _seedingDonePrefsKey = 'app_seeding_done_v1';

  AppSeeder({
    required LocalJobStore localJobStore,
    required PathProvider pathProvider,
    required FileSystem fileSystem,
    required AudioDurationRetriever audioDurationRetriever,
    required SharedPreferences sharedPreferences,
  }) : _localJobStore = localJobStore,
       _pathProvider = pathProvider,
       _fileSystem = fileSystem,
       _audioDurationRetriever = audioDurationRetriever,
       _prefs = sharedPreferences;

  /// Copies sample assets and creates corresponding local jobs if not already done.
  Future<void> seedInitialDataIfNeeded() async {
    logger.i('[AppSeeder] Checking if initial data seeding is required...');

    final bool alreadySeeded = _prefs.getBool(_seedingDonePrefsKey) ?? false;

    if (alreadySeeded) {
      logger.i('[AppSeeder] Seeding already completed. Skipping.');
      return;
    }

    logger.i(
      '[AppSeeder] Seeding not done yet. Proceeding with sample data setup.',
    );

    try {
      final Directory docsDir =
          await _pathProvider.getApplicationDocumentsDirectory();
      final String targetPath = p.join(docsDir.path, _sampleTargetFilename);
      logger.d('[AppSeeder] Target path for sample: $targetPath');

      // 1. Check if the specific sample LocalJob already exists (e.g., partial past attempt)
      final existingJob = await _localJobStore.getJob(targetPath);
      if (existingJob != null) {
        logger.w(
          '[AppSeeder] Sample LocalJob already exists for $targetPath. Assuming seeding done for this item.',
        );
        // Mark as done generally, even if only one part was done before
        await _markSeedingAsDone();
        return;
      }

      // 2. Check if the target *file* already exists (e.g., copied but job not created)
      // We overwrite if it exists to ensure consistency with the expected asset.
      if (await _fileSystem.fileExists(targetPath)) {
        logger.w(
          '[AppSeeder] Target file $targetPath already exists. Overwriting.',
        );
        // No need to delete explicitly, writeFile will overwrite.
      }

      // 3. Copy the asset file
      logger.d('[AppSeeder] Loading asset: $_sampleAssetPath');
      final ByteData byteData = await rootBundle.load(_sampleAssetPath);
      logger.d('[AppSeeder] Writing asset to: $targetPath');
      await _fileSystem.writeFile(targetPath, byteData.buffer.asUint8List());
      logger.i('[AppSeeder] Successfully copied sample asset to $targetPath');

      // 4. Get duration of the *copied* file
      logger.d('[AppSeeder] Getting duration for: $targetPath');
      // IMPORTANT: Ensure the duration retriever works correctly here.
      // If it fails, the LocalJob won't be created, and seeding won't be marked done.
      final Duration duration = await _audioDurationRetriever.getDuration(
        targetPath,
      );
      logger.d('[AppSeeder] Duration retrieved: ${duration.inMilliseconds} ms');

      // 5. Create and save the LocalJob
      final sampleJob = LocalJob(
        localFilePath: targetPath, // Use the ACTUAL path in docs dir
        durationMillis: duration.inMilliseconds,
        status: TranscriptionStatus.created, // It's a local-only file initially
        localCreatedAt: DateTime.now(),
        backendId: null, // No backend ID for a purely local sample initially
        // isSample: true, // TODO: Add this flag later if needed by adding bool field to LocalJob
      );

      logger.d(
        '[AppSeeder] Saving LocalJob for sample: ${sampleJob.localFilePath}',
      );
      await _localJobStore.saveJob(sampleJob);
      logger.i('[AppSeeder] Successfully saved LocalJob for sample.');

      // 6. Mark seeding as done
      await _markSeedingAsDone();
    } catch (e, s) {
      logger.e(
        '[AppSeeder] CRITICAL ERROR during initial data seeding!',
        error: e,
        stackTrace: s,
      );
      // Decide how to handle: maybe retry next time? For now, log and stop.
      // Do NOT mark seeding as done if it failed critically.
    }
  }

  Future<void> _markSeedingAsDone() async {
    await _prefs.setBool(_seedingDonePrefsKey, true);
    logger.i('[AppSeeder] Marked seeding as done in SharedPreferences.');
  }
}
