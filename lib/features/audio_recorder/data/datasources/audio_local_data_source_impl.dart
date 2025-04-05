import 'dart:async';
import 'dart:io'; // Keep dart:io for FileSystemEntity type

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
      final Map<Permission, PermissionStatus> statuses = await permissionHandler
          .request([microphonePermission]);
      return statuses[microphonePermission] == PermissionStatus.granted;
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
  Future<Duration> getAudioDuration(String filePath) async {
    try {
      // Delegate to the injected service
      return await audioDurationGetter.getDuration(filePath);
    } on RecordingFileNotFoundException {
      // Rethrow known exceptions directly
      rethrow;
    } on AudioPlayerException {
      // Rethrow known exceptions directly (if getter throws this)
      rethrow;
    } catch (e) {
      // Wrap unexpected errors from the getter as AudioPlayerException
      throw AudioPlayerException(
        'Unexpected error getting audio duration for $filePath from getter',
        e,
      );
    }
  }

  @override
  Future<FileStat> getFileStat(String filePath) async {
    try {
      return await fileSystem.stat(filePath);
    } on FileSystemException catch (e) {
      throw AudioFileSystemException(
        'Failed to get file stats for $filePath',
        e,
      );
    } catch (e) {
      // Catch any other potential errors during stat call
      throw AudioFileSystemException(
        'Unexpected error getting file stats for $filePath',
        e,
      );
    }
  }

  @override
  Future<List<String>> listRecordingFiles() async {
    try {
      // Use injected pathProvider
      final appDir = await pathProvider.getApplicationDocumentsDirectory();

      // Use injected fileSystem
      if (!await fileSystem.directoryExists(appDir.path)) {
        await fileSystem.createDirectory(appDir.path, recursive: true);
        return [];
      }

      // Use injected fileSystem (use async list now?)
      // Let's keep listSync for now to match original behaviour, but abstract it.
      /*
      final files =
          fileSystem
              .listDirectorySync(appDir.path)
              .where(
                (item) => item.path.endsWith('.m4a') && item is File,
              ) // File type check might need adjustment if abstraction changes
              .map((item) => item.path)
              .toList();
      return files;
      */
      // Use async listing now
      final List<String> files = [];
      final stream = fileSystem.listDirectory(appDir.path);
      await for (final entity in stream) {
        // Ensure it's a file and ends with .m4a before adding
        // Checking type via `is File` requires dart:io, use entity type property if available
        // from the abstraction, otherwise rely on path extension.
        if (entity.path.endsWith('.m4a')) {
          // Check if it's actually a file using stat, avoid adding directories
          try {
            final stat = await fileSystem.stat(entity.path);
            if (stat.type == FileSystemEntityType.file) {
              files.add(entity.path);
            }
          } catch (_) {
            // Ignore files we cannot stat (e.g., permission errors, broken links)
          }
        }
      }
      return files;
    } catch (e) {
      throw AudioFileSystemException('Failed to list recording files', e);
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
