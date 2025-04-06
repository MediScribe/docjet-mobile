import 'dart:async';
import 'dart:io'; // Keep dart:io for FileSystemEntity type

import 'package:flutter/foundation.dart'; // For debugPrint
// import 'package:path/path.dart' as p; // REMOVED Unused import

// Remove direct package imports
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// Import interfaces
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart'; // Correct import
import '../services/audio_duration_getter.dart';
import '../services/audio_concatenation_service.dart'; // Import the new service
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // Import AudioRecord

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

// Remove ffmpeg imports, they are now in the service
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_audio/return_code.dart';

/// Default implementation of [AudioLocalDataSource].
/// Interacts with the [AudioRecorder] and [FileSystem] to manage recordings.
class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final FileSystem fileSystem;
  final PathProvider pathProvider;
  final PermissionHandler permissionHandler; // Use the type directly
  final AudioDurationGetter audioDurationGetter;
  final AudioConcatenationService audioConcatenationService;

  AudioLocalDataSourceImpl({
    required this.recorder,
    required this.fileSystem,
    required this.pathProvider,
    required this.permissionHandler,
    required this.audioDurationGetter,
    required this.audioConcatenationService,
  });

  @override
  Future<bool> checkPermission() async {
    try {
      // Use the recorder's check first, as it might involve more specific platform checks
      final hasRecorderPerm = await recorder.hasPermission();
      if (hasRecorderPerm) {
        return true;
      }
      // Fallback to permission_handler for status if recorder says no (or if first check is false)
      // Note: This differs slightly from original logic for better testability
      // It ensures we always eventually check via permissionHandler if recorder returns false.
      final status = await permissionHandler.status(Permission.microphone);
      return status == PermissionStatus.granted;
    } catch (e) {
      // Consider logging the error
      throw AudioPermissionException(
        'Failed to check microphone permission',
        e,
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      // Pass a list containing the permission
      final Map<Permission, PermissionStatus> statuses = await permissionHandler
          .request([Permission.microphone]);
      // Check the status from the returned map
      final status = statuses[Permission.microphone];
      return status == PermissionStatus.granted;
    } catch (e) {
      throw AudioPermissionException(
        'Failed to request microphone permission',
        e,
      );
    }
  }

  @override
  Future<String> startRecording() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) {
          throw const AudioPermissionException(
            'Microphone permission denied.',
            null, // No underlying error object
          );
        }
      }

      final appDir = await pathProvider.getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final path = '${appDir.path}/rec_$timestamp.m4a';

      // Use injected fileSystem to ensure directory exists
      await fileSystem.createDirectory(appDir.path, recursive: true);

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
        ), // Or your preferred config
        path: path,
      );

      // RETURN the path
      return path;
    } on AudioPermissionException {
      // Explicitly rethrow permission exceptions
      rethrow;
    } catch (e) {
      throw AudioRecordingException('Failed to start recording', e);
    }
  }

  @override
  Future<String> stopRecording({required String recordingPath}) async {
    // Use the provided recordingPath directly
    final path = recordingPath;

    try {
      await recorder.stop();

      // Use injected fileSystem
      if (!await fileSystem.fileExists(path)) {
        throw RecordingFileNotFoundException(
          'Recording file not found at $path after stopping.',
        );
      }
      return path; // Return provided path
    } catch (e) {
      if (e is RecordingFileNotFoundException) {
        // Rethrow specific exception if file check failed
        rethrow;
      }
      // Wrap other recorder/filesystem errors
      throw AudioRecordingException('Failed to stop recording', e);
    }
  }

  @override
  Future<void> pauseRecording({required String recordingPath}) async {
    // Use provided recordingPath (though recorder API might not need it explicitly)
    try {
      await recorder.pause();
    } catch (e) {
      throw AudioRecordingException(
        'Failed to pause recording for path: $recordingPath',
        e,
      );
    }
  }

  @override
  Future<void> resumeRecording({required String recordingPath}) async {
    // Use provided recordingPath (though recorder API might not need it explicitly)
    try {
      await recorder.resume();
    } catch (e) {
      throw AudioRecordingException(
        'Failed to resume recording for path: $recordingPath',
        e,
      );
    }
  }

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
      debugPrint(
        'Failed to list recording details due to a broader error: $e',
      ); // Log outer error
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

      // If it's a file, get duration. This might throw.
      final duration = await audioDurationGetter.getDuration(path);

      // If stat and duration succeed, return the record.
      return AudioRecord(
        filePath: path,
        duration: duration,
        createdAt: stat.modified,
      );
    } catch (e, s) {
      // Log the specific error and path if stat or getDuration fails
      debugPrint('Failed to get details for $path: $e\\nStackTrace: $s');
      // Return null on failure so Future.wait doesn't break
      return null;
    }
  }

  @override
  Future<String> concatenateRecordings(List<String> inputFilePaths) async {
    // Delegate the entire operation to the injected service.
    // The service now handles validation, ffmpeg execution, and error handling.
    try {
      return await audioConcatenationService.concatenate(inputFilePaths);
    } catch (e) {
      // The service should throw specific exceptions (ArgumentError,
      // RecordingFileNotFoundException, AudioConcatenationException, AudioFileSystemException).
      // We might want to re-wrap them here ONLY if the Repository layer expects
      // *only* exceptions defined in audio_exceptions.dart.
      // For now, let's rethrow directly, assuming the Repository's _tryCatch
      // can handle ArgumentError and the specific audio exceptions.
      // If _tryCatch needs updates, that's a separate step.
      rethrow;
    }
  }
}
