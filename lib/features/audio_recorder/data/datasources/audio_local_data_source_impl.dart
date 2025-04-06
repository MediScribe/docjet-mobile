import 'dart:async';
import 'dart:io'; // Keep dart:io for FileSystemEntity type

import 'package:flutter/foundation.dart' show debugPrint; // Import debugPrint
// import 'package:path/path.dart' as p; // REMOVED Unused import

// Remove direct package imports
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:meta/meta.dart';

// Import interfaces
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart'
    as custom_ph;
import '../services/audio_duration_getter.dart';
import '../services/audio_concatenation_service.dart'; // Import the new service
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // Import AudioRecord

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

// Remove ffmpeg imports, they are now in the service
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_audio/return_code.dart';

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final FileSystem fileSystem; // Inject FileSystem
  final PathProvider pathProvider; // Inject PathProvider
  final custom_ph.PermissionHandler
  permissionHandler; // Inject PermissionHandler
  final AudioDurationGetter audioDurationGetter; // Inject the new service
  final AudioConcatenationService
  audioConcatenationService; // Inject the concatenation service

  // Keep the private field
  String? _currentRecordingPath;

  // Public getter for the path
  String? get currentRecordingPath => _currentRecordingPath;

  // Keep the testing setter using the private field
  @visibleForTesting
  set testingSetCurrentRecordingPath(String? path) {
    _currentRecordingPath = path;
  }

  AudioLocalDataSourceImpl({
    required this.recorder,
    required this.fileSystem,
    required this.pathProvider,
    required this.permissionHandler,
    required this.audioDurationGetter,
    required this.audioConcatenationService,
  });

  // Define the permission object locally, needed for the requestPermission call
  final Permission microphonePermission = Permission.microphone;

  // Restore checkPermission to use the INJECTED handler for fallback (easier to test)
  @override
  Future<bool> checkPermission() async {
    try {
      final bool recorderHasPermission = await recorder.hasPermission();
      if (recorderHasPermission) {
        return true;
      }
      final status = await permissionHandler.status(microphonePermission);
      final bool granted = status == PermissionStatus.granted;
      return granted;
    } catch (e) {
      throw AudioPermissionException('Failed to check permission status', e);
    }
  }

  // requestPermission already uses the injected handler
  @override
  Future<bool> requestPermission() async {
    try {
      // Explicitly request microphone permission.
      final Map<Permission, PermissionStatus> statuses = await permissionHandler
          .request([microphonePermission]);
      // Return true if granted, false otherwise.
      final status = statuses[microphonePermission];
      if (status == null) {
        // Should not happen if we requested it, but handle defensively.
        throw AudioPermissionException(
          'Permission status was unexpectedly null.',
        );
      }
      return status == PermissionStatus.granted;
    } catch (e) {
      // Catch potential exceptions from the handler and wrap them.
      throw AudioPermissionException(
        'Failed to request microphone permission: ${e.toString()}',
        e, // Pass original exception if needed for logging
      );
    }
  }

  @override
  Future<String> startRecording() async {
    try {
      final hasPermission = await checkPermission(); // Uses refactored method
      if (!hasPermission) {
        throw const AudioPermissionException(
          'Microphone permission not granted to start recording',
        );
      }

      // Use injected pathProvider
      final appDir = await pathProvider.getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${appDir.path}/recording_$timestamp.m4a';
      // Assign to the private field
      _currentRecordingPath = filePath;

      // Ensure directory exists using injected fileSystem
      if (!await fileSystem.directoryExists(appDir.path)) {
        await fileSystem.createDirectory(appDir.path, recursive: true);
      }

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      return filePath;
    } catch (e) {
      // Assign null to the private field on error
      _currentRecordingPath = null;
      if (e is AudioPermissionException) {
        rethrow;
      }
      throw AudioRecordingException('Failed to start recording', e);
    }
  }

  @override
  Future<String> stopRecording() async {
    // Check the private field *before* trying to stop
    if (_currentRecordingPath == null) {
      throw const NoActiveRecordingException(
        'No recording was in progress to stop.',
      );
    }

    // Keep the original path from the private field
    final path = _currentRecordingPath;

    try {
      await recorder.stop();
      // Assign null to the private field after successful stop
      _currentRecordingPath = null;

      // Use injected fileSystem - Assert path is non-null with !
      if (!await fileSystem.fileExists(path!)) {
        // Path is already nulled, just throw
        throw RecordingFileNotFoundException(
          'Recording file not found at $path after stopping.',
        );
      }
      return path; // Return original path - Assert non-null with !
    } catch (e) {
      // Ensure the private field is nulled out even if stop() or fileExists() fails
      _currentRecordingPath = null;
      if (e is RecordingFileNotFoundException) {
        // Rethrow specific exception if file check failed
        rethrow;
      }
      // Wrap other recorder/filesystem errors
      throw AudioRecordingException('Failed to stop recording', e);
    }
  }

  @override
  Future<void> pauseRecording() async {
    // Check the private field
    if (_currentRecordingPath == null) {
      throw const NoActiveRecordingException('No active recording to pause.');
    }
    try {
      await recorder.pause();
    } catch (e) {
      throw AudioRecordingException('Failed to pause recording', e);
    }
  }

  @override
  Future<void> resumeRecording() async {
    // Check the private field
    if (_currentRecordingPath == null) {
      throw const NoActiveRecordingException('No active recording to resume.');
    }
    try {
      await recorder.resume();
    } catch (e) {
      throw AudioRecordingException('Failed to resume recording', e);
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
    final List<AudioRecord> records = [];
    try {
      final appDir = await pathProvider.getApplicationDocumentsDirectory();

      if (!await fileSystem.directoryExists(appDir.path)) {
        // If dir doesn't exist, create it and return empty list
        // (or should we throw? For listing, returning empty seems reasonable)
        await fileSystem.createDirectory(appDir.path, recursive: true);
        return [];
      }

      final stream = fileSystem.listDirectory(appDir.path);
      await for (final entity in stream) {
        if (entity.path.endsWith('.m4a')) {
          try {
            final stat = await fileSystem.stat(entity.path);
            // Only process actual files
            if (stat.type == FileSystemEntityType.file) {
              final duration = await audioDurationGetter.getDuration(
                entity.path,
              );
              records.add(
                AudioRecord(
                  filePath: entity.path,
                  duration: duration,
                  createdAt: stat.modified,
                ),
              );
            }
          } catch (e) {
            // IMPORTANT: Log this error with a proper logger!
            // For now, print to console.
            // Decide if specific error types need different handling.
            debugPrint(
              'Error processing file ${entity.path}: ${e.toString()}',
            ); // Replaced print
            // Continue to the next file
          }
        }
      }
      // Optionally sort records by date?
      // records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (e) {
      // Catch errors related to listing the directory itself
      throw AudioFileSystemException('Failed to list recording details', e);
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
