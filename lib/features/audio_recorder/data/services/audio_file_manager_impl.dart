import 'dart:async';
import 'dart:io'; // Keep dart:io for FileSystemEntity type

// import 'package:flutter/foundation.dart'; // For debugPrint

// ADD THIS IMPORT
import 'package:docjet_mobile/core/utils/logger.dart';

// Import interfaces and entities
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import '../exceptions/audio_exceptions.dart';
import './audio_duration_retriever.dart';
import './audio_file_manager.dart';

/// Default implementation of [AudioFileManager].
/// Interacts with the [FileSystem] and uses [PathProvider] and [AudioDurationRetriever]
/// to manage recording files.
class AudioFileManagerImpl implements AudioFileManager {
  final FileSystem fileSystem;
  final PathProvider pathProvider;
  final AudioDurationRetriever audioDurationRetriever;

  AudioFileManagerImpl({
    required this.fileSystem,
    required this.pathProvider,
    required this.audioDurationRetriever,
  });

  @override
  Future<void> deleteRecording(String filePath) async {
    try {
      // Use injected fileSystem
      if (await fileSystem.fileExists(filePath)) {
        await fileSystem.deleteFile(filePath);
      } else {
        throw RecordingFileNotFoundException(
          'File $filePath not found for deletion.',
        );
      }
    } catch (e) {
      if (e is RecordingFileNotFoundException) {
        rethrow;
      }
      throw AudioFileSystemException('Failed to delete recording $filePath', e);
    }
  }

  @override
  Future<List<AudioRecord>> listRecordingDetails() async {
    try {
      final appDir = await pathProvider.getApplicationDocumentsDirectory();
      final dirPath = appDir.path;

      if (!await fileSystem.directoryExists(dirPath)) {
        await fileSystem.createDirectory(dirPath, recursive: true);
        return []; // No directory, no files.
      }

      final List<Future<AudioRecord?>> recordFutures = [];
      final stream = fileSystem.listDirectory(dirPath);

      await for (final entity in stream) {
        if (entity.path.endsWith('.m4a')) {
          // Directly add the future returned by the error-handling helper
          recordFutures.add(_getRecordDetails(entity.path));
        }
      }

      if (recordFutures.isEmpty) {
        return []; // No potential files found.
      }

      // Wait for all stat/duration fetches to complete concurrently
      final results = await Future.wait(recordFutures);

      // Filter out nulls (failed fetches or non-files) and sort
      final List<AudioRecord> records =
          results.whereType<AudioRecord>().toList();
      records.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ); // Sort descending

      return records;
    } catch (e) {
      // Catch broader errors (directory listing, initial check/create)
      logger.e(
        'Failed to list recording details due to a broader error',
        error: e,
      );
      throw AudioFileSystemException('Failed to list recording details', e);
    }
  }

  /// Helper to get stat and duration for a single path.
  /// Returns null if not a file or if an error occurs during stat/duration retrieval.
  Future<AudioRecord?> _getRecordDetails(String path) async {
    try {
      final stat = await fileSystem.stat(path);

      // Skip if not a file BEFORE getting duration
      if (stat.type != FileSystemEntityType.file) {
        // Return null for non-files (e.g., a directory named .m4a). This is not an error.
        return null;
      }

      final duration = await audioDurationRetriever.getDuration(path);

      // Use modified time as created time
      final createdAt = stat.modified;

      return AudioRecord(
        filePath: path,
        duration: duration,
        createdAt: createdAt,
      );
    } catch (e) {
      // Log specific file error, then return null to allow Future.wait to continue
      logger.e('Failed to get details for file $path', error: e);
      return null;
    }
  }
}
