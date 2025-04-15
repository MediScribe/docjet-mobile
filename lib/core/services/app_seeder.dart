import 'dart:async';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:shared_preferences/shared_preferences.dart';

/// Handles seeding initial data, like sample recordings, on first app launch.
class AppSeeder {
  final logger = LoggerFactory.getLogger(AppSeeder, level: Level.debug);
  final String _tag = logTag(AppSeeder);

  // Dependencies
  final FileSystem _fileSystem;
  final SharedPreferences _prefs;
  final LocalJobStore _localJobStore;
  final AudioPlayerAdapter _audioPlayerAdapter;

  // Configuration and constants
  static const String _seedingDonePrefsKey = 'app_seeding_done_v1';
  static const String _defaultSampleAssetPath =
      'assets/audio/short-audio-test-file.m4a';
  static const String _defaultSampleRelativePath =
      'sample_recording_short_test.m4a';

  // Configurable paths (useful for testing)
  final String sampleAssetPath;
  final String sampleRelativePath;

  // Synchronization
  final Completer<void> _seedingCompleter = Completer<void>();
  bool _seedingInProgress = false;

  AppSeeder({
    required FileSystem fileSystem,
    required SharedPreferences prefs,
    required LocalJobStore localJobStore,
    required AudioPlayerAdapter audioPlayerAdapter,
    this.sampleAssetPath = _defaultSampleAssetPath,
    this.sampleRelativePath = _defaultSampleRelativePath,
  }) : _fileSystem = fileSystem,
       _prefs = prefs,
       _localJobStore = localJobStore,
       _audioPlayerAdapter = audioPlayerAdapter {
    logger.d('$_tag AppSeeder initialized with debug logging enabled');
  }

  /// Determines whether seeding should be skipped based on current state
  /// Exposed for testing purposes
  bool shouldSkipSeeding(bool seedingDone, bool fileExists) {
    return seedingDone && fileExists;
  }

  /// Seeds initial data if needed, such as sample audio files for users to play with.
  /// This ensures that first-time users have content to interact with.
  Future<void> seedInitialDataIfNeeded() async {
    try {
      logger.d('$_tag seedInitialDataIfNeeded() called');

      // Check if another seeding operation is already in progress
      if (_seedingInProgress) {
        logger.d(
          '$_tag Seeding already in progress, waiting for completion...',
        );
        return _seedingCompleter.future;
      }

      // Check if we should skip seeding
      final seedingDone = await isSeedingDone();
      final fileExists = await _fileSystem.fileExists(sampleRelativePath);

      if (shouldSkipSeeding(seedingDone, fileExists)) {
        logger.d('$_tag Seeding already completed and files exist. Skipping.');
        return;
      }

      // Mark seeding as in progress and reset the completer if needed
      _seedingInProgress = true;
      if (_seedingCompleter.isCompleted) {
        // This should never happen in practice, but just in case
        logger.w(
          '$_tag Creating new seeding completer as previous one was completed',
        );
      }

      try {
        await executeSeedingTransaction();
        if (!_seedingCompleter.isCompleted) {
          _seedingCompleter.complete();
        }
      } catch (e, s) {
        logger.e(
          '$_tag Error during seeding transaction',
          error: e,
          stackTrace: s,
        );
        if (!_seedingCompleter.isCompleted) {
          _seedingCompleter.completeError(e, s);
        }
        rethrow;
      } finally {
        _seedingInProgress = false;
      }
    } catch (e, s) {
      logger.e(
        '$_tag Unexpected error in seedInitialDataIfNeeded',
        error: e,
        stackTrace: s,
      );
      rethrow; // Propagate error for handling by caller
    }
  }

  /// Forces a reset of sample data, useful for debugging or testing.
  /// Clears existing sample files and marks seeding as not done.
  Future<void> resetSampleData() async {
    try {
      logger.d('$_tag resetSampleData() called');

      // Check if another seeding operation is in progress
      if (_seedingInProgress) {
        logger.d(
          '$_tag Seeding in progress, cannot reset now. Try again later.',
        );
        throw Exception('Cannot reset while seeding is in progress');
      }

      // Delete the existing file if it exists
      if (await _fileSystem.fileExists(sampleRelativePath)) {
        await _fileSystem.deleteFile(sampleRelativePath);
        logger.d('$_tag Deleted existing sample file');
      }

      // Remove existing job if it exists
      final existingJob = await _localJobStore.getJob(sampleRelativePath);
      if (existingJob != null) {
        await _localJobStore.deleteJob(sampleRelativePath);
        logger.d('$_tag Deleted existing sample job');
      }

      // Mark seeding as not done
      await markSeedingAsDone(false);
      logger.i('$_tag Sample data reset complete');
    } catch (e, s) {
      logger.e('$_tag Error resetting sample data', error: e, stackTrace: s);
      throw Exception('Failed to reset sample data: $e');
    }
  }

  /// Executes the seeding transaction with proper rollback
  /// Exposed as protected method for testing
  @visibleForTesting
  Future<void> executeSeedingTransaction() async {
    logger.d('$_tag Starting seeding transaction');

    bool fileCopied = false;
    LocalJob? createdJob;

    try {
      // Check if a job already exists for this path (to avoid duplication)
      final existingJob = await _localJobStore.getJob(sampleRelativePath);

      if (existingJob != null) {
        logger.w('$_tag Sample job already exists. Marking seeding as done.');
        await markSeedingAsDone(true);
        return;
      }

      // Load the asset data
      final ByteData byteData = await rootBundle.load(sampleAssetPath);
      logger.d('$_tag Asset loaded, size: ${byteData.lengthInBytes} bytes');

      // Write the file - ALWAYS use relative paths for storage
      await _fileSystem.writeFile(
        sampleRelativePath,
        byteData.buffer.asUint8List(),
      );
      fileCopied = true;
      logger.d('$_tag Sample file written successfully');

      // Get duration of the copied file - pass relative path directly
      final duration = await _audioPlayerAdapter.getDuration(
        sampleRelativePath,
      );
      logger.d('$_tag Audio duration: ${duration.inMilliseconds}ms');

      // Create the local job
      final sampleJob = LocalJob(
        localFilePath: sampleRelativePath,
        durationMillis: duration.inMilliseconds,
        status: TranscriptionStatus.created,
        localCreatedAt: DateTime.now(),
        backendId: null,
      );

      // Save the job
      await _localJobStore.saveJob(sampleJob);
      createdJob = sampleJob;
      logger.d('$_tag LocalJob saved successfully');

      // Mark seeding as done ONLY after everything else succeeded
      await markSeedingAsDone(true);
      logger.i('$_tag Seeding transaction completed successfully');
    } catch (e, s) {
      logger.e(
        '$_tag Error during seeding, rolling back changes',
        error: e,
        stackTrace: s,
      );

      // Rollback: Delete the file if we created it
      if (fileCopied) {
        try {
          await _fileSystem.deleteFile(sampleRelativePath);
          logger.d('$_tag Rolled back file creation');
        } catch (rollbackError) {
          logger.e('$_tag Error rolling back file creation: $rollbackError');
        }
      }

      // Rollback: Delete the job if we created it
      if (createdJob != null) {
        try {
          await _localJobStore.deleteJob(sampleRelativePath);
          logger.d('$_tag Rolled back job creation');
        } catch (rollbackError) {
          logger.e('$_tag Error rolling back job creation: $rollbackError');
        }
      }

      // Re-throw the original error
      throw Exception('Seeding failed with rollback: $e');
    }
  }

  /// Sets the seeding completion flag
  /// Exposed for testing
  @visibleForTesting
  Future<void> markSeedingAsDone(bool isDone) async {
    try {
      await _prefs.setBool(_seedingDonePrefsKey, isDone);
      logger.i(
        '$_tag Marked seeding as ${isDone ? "done" : "not done"} in SharedPreferences',
      );
    } catch (e) {
      logger.e(
        '$_tag Error marking seeding as ${isDone ? "done" : "not done"}: $e',
      );
      throw Exception(
        'Failed to mark seeding as ${isDone ? "done" : "not done"}: $e',
      );
    }
  }

  /// Checks if seeding has been completed
  /// Exposed for testing
  @visibleForTesting
  Future<bool> isSeedingDone() async {
    return _prefs.getBool(_seedingDonePrefsKey) ?? false;
  }
}
