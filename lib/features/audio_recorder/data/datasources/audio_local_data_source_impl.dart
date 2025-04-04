import 'dart:async';
import 'dart:io'; // Keep dart:io for FileSystemEntity type

// Remove direct package imports
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus; // Keep specific types
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meta/meta.dart';

// Import interfaces
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final FileSystem fileSystem; // Inject FileSystem
  final PathProvider pathProvider; // Inject PathProvider
  final PermissionHandler permissionHandler; // Inject PermissionHandler
  final Permission microphonePermission =
      Permission.microphone; // Keep this definition

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
  });

  @override
  Future<bool> checkPermission() async {
    try {
      final status = await permissionHandler.status(microphonePermission);
      return status == PermissionStatus.granted;
    } catch (e) {
      throw AudioPermissionException('Failed to check permission status', e);
    }
  }

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
    // TODO: Refactor this - still creates AudioPlayer locally
    // Maybe inject an AudioPlayer factory or wrapper?
    final player = AudioPlayer();
    try {
      // Use injected fileSystem
      if (!await fileSystem.fileExists(filePath)) {
        throw RecordingFileNotFoundException(
          'Audio file not found at $filePath',
        );
      }
      final duration = await player.setFilePath(filePath);
      if (duration == null) {
        throw AudioPlayerException(
          'Could not determine duration for file $filePath (possibly invalid/corrupt)',
        );
      }
      return duration;
    } catch (e) {
      if (e is RecordingFileNotFoundException || e is AudioPlayerException) {
        rethrow;
      }
      throw AudioPlayerException(
        'Failed to get audio duration for $filePath',
        e,
      );
    } finally {
      await player.dispose();
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
      final files =
          fileSystem
              .listDirectorySync(appDir.path)
              .where(
                (item) => item.path.endsWith('.m4a') && item is File,
              ) // File type check might need adjustment if abstraction changes
              .map((item) => item.path)
              .toList();
      return files;
    } catch (e) {
      throw AudioFileSystemException('Failed to list recording files', e);
    }
  }

  @override
  Future<String> concatenateRecordings(
    String originalFilePath,
    String newSegmentPath,
  ) async {
    // TODO: Implement using fileSystem and potentially ffmpeg
    throw UnimplementedError(
      'Audio concatenation is not implemented yet. Needs ffmpeg integration.',
    );
  }

  // Remove the old concatenateAudioFiles method
}
