import 'dart:async';
// import 'dart:io'; // Keep dart:io for FileSystemEntity type

// import 'package:flutter/foundation.dart'; // For debugPrint
// import 'package:path/path.dart' as p; // REMOVED Unused import

// Remove direct package imports
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// Import interfaces
import 'package:docjet_mobile/core/platform/path_provider.dart'; // Kept for startRecording
import 'package:docjet_mobile/core/platform/permission_handler.dart'; // Correct import
import '../services/audio_concatenation_service.dart'; // Import the new service
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // Import AudioRecord

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

// Import FileSystem for createDirectory check in startRecording
import 'package:docjet_mobile/core/platform/file_system.dart';

// Remove ffmpeg imports, they are now in the service
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_audio/return_code.dart';

/// Default implementation of [AudioLocalDataSource].
/// Interacts with the [AudioRecorder] and manages permissions and recording lifecycle.
class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final PathProvider pathProvider;
  final PermissionHandler permissionHandler; // Use the type directly
  final AudioConcatenationService audioConcatenationService;

  // Added FileSystem dependency back for startRecording directory check
  final FileSystem fileSystem;

  AudioLocalDataSourceImpl({
    required this.recorder,
    required this.pathProvider,
    required this.permissionHandler,
    required this.audioConcatenationService,
    required this.fileSystem, // Added back
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
      // Ensure directory exists before starting recording
      if (!await fileSystem.directoryExists(appDir.path)) {
        await fileSystem.createDirectory(appDir.path, recursive: true);
      }

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
