import 'dart:async';
import 'dart:io' show FileSystemEntity, FileSystemEntityType, FileStat;

// ADD THIS IMPORT

// Import interfaces and entities
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import '../exceptions/audio_exceptions.dart';
import './audio_duration_retriever.dart';
import './audio_file_manager.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

/// Default implementation of [AudioFileManager].
/// Interacts with the [FileSystem] and uses [PathProvider] and [AudioDurationRetriever]
/// to manage recording files.
class AudioFileManagerImpl implements AudioFileManager {
  final FileSystem fileSystem;
  final PathProvider pathProvider;
  final AudioDurationRetriever audioDurationRetriever;
  // Using centralized logger with level OFF
  final logger = Logger(level: Level.off);

  AudioFileManagerImpl({
    required this.fileSystem,
    required this.pathProvider,
    required this.audioDurationRetriever,
  });

  @override
  Future<void> deleteRecording(String filePath) async {
    logger.d('Attempting to delete recording: $filePath');
    try {
      final exists = await fileSystem.fileExists(filePath);
      if (!exists) {
        logger.w('Attempted to delete non-existent file: $filePath');
        throw RecordingFileNotFoundException('File not found: $filePath');
      }
      await fileSystem.deleteFile(filePath);
      logger.i('Successfully deleted file: $filePath');
    } on RecordingFileNotFoundException {
      rethrow; // Allow specific exception to pass through
    } catch (e, s) {
      logger.e('Failed to delete file: $filePath', error: e, stackTrace: s);
      throw AudioFileSystemException('Failed to delete file: $filePath', e);
    }
  }

  @override
  Future<List<String>> listRecordingPaths() async {
    logger.d('Listing recording paths...');
    try {
      final directory = await pathProvider.getApplicationDocumentsDirectory();
      logger.d('Documents directory path: ${directory.path}');

      final dirExists = await fileSystem.directoryExists(directory.path);
      if (!dirExists) {
        logger.w('Documents directory does not exist, creating...');
        await fileSystem.createDirectory(directory.path, recursive: true);
        logger.i('Documents directory created.');
        return []; // No files exist if directory was just created
      }
      logger.d('Directory exists, listing contents...');

      final List<String> recordingPaths = [];
      final completer = Completer<List<String>>();
      final Stream<FileSystemEntity> entitiesStream = fileSystem.listDirectory(
        directory.path,
      );

      entitiesStream.listen(
        (entity) async {
          try {
            logger.d('Processing entity: ${entity.path}');
            final FileStat stat = await fileSystem.stat(entity.path);
            logger.d('Stat for ${entity.path}: type=${stat.type}');
            if (stat.type == FileSystemEntityType.file &&
                entity.path.endsWith('.m4a')) {
              logger.d('Adding valid recording path: ${entity.path}');
              recordingPaths.add(entity.path);
            }
          } catch (e, s) {
            logger.e(
              'Error processing entity: ${entity.path}',
              error: e,
              stackTrace: s,
            );
            // Skip problematic entity
          }
        },
        onError: (error, stackTrace) {
          logger.e(
            'Error listing directory contents',
            error: error,
            stackTrace: stackTrace,
          );
          if (!completer.isCompleted) {
            completer.completeError(
              AudioFileSystemException(
                'Failed to list recording paths due to stream error',
                error,
              ),
              stackTrace,
            );
          }
        },
        onDone: () {
          logger.d(
            'Finished listing directory. Found ${recordingPaths.length} recordings.',
          );
          if (!completer.isCompleted) {
            completer.complete(recordingPaths);
          }
        },
      );

      return completer.future;
    } catch (e, s) {
      logger.e('Failed to list recording paths', error: e, stackTrace: s);
      throw AudioFileSystemException('Failed to list recording paths', e);
    }
  }

  // --- Deprecated Method Implementation ---
  @Deprecated('Use listRecordingPaths instead of fetching details directly')
  @override
  Future<AudioRecord> getRecordingDetails(String filePath) async {
    logger.w('Deprecated method getRecordingDetails called for $filePath');
    // _getRecordDetails will now throw on error, so we just await it.
    // The try-catch is removed from here.
    final details = await _getRecordDetails(filePath);
    // The null check and throw are removed as _getRecordDetails guarantees
    // returning an AudioRecord or throwing an AudioFileSystemException.
    return details;
  }

  /// Helper to get stat and duration for a single path.
  /// Returns AudioRecord or throws AudioFileSystemException on error.
  Future<AudioRecord> _getRecordDetails(String path) async {
    try {
      final stat = await fileSystem.stat(path);

      // Throw if not a file BEFORE getting duration
      if (stat.type != FileSystemEntityType.file) {
        // Throw a specific exception for non-files.
        throw AudioFileSystemException('Path is not a file: $path');
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
      // Log specific file error, then rethrow wrapped in AudioFileSystemException
      logger.e('Failed to get details for file $path', error: e);
      throw AudioFileSystemException('Failed to get details for file $path', e);
    }
  }
}
