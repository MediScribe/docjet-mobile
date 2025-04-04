import 'dart:async';
import 'dart:io'; // Keep dart:io for FileSystemEntity type

// Remove direct package imports
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus; // Keep specific types
import 'package:record/record.dart';
import 'package:meta/meta.dart';

// Import interfaces
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import '../services/audio_duration_getter.dart';

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

// Import ffmpeg_kit_flutter
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final FileSystem fileSystem; // Inject FileSystem
  final PathProvider pathProvider; // Inject PathProvider
  final PermissionHandler permissionHandler; // Inject PermissionHandler
  final AudioDurationGetter audioDurationGetter; // Inject the new service
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
    required this.audioDurationGetter,
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
    try {
      // Use injected fileSystem
      // Removed redundant file existence check, handled by audioDurationGetter
      /*
      if (!await fileSystem.fileExists(filePath)) {
        throw RecordingFileNotFoundException(
          'Audio file not found at $filePath',
        );
      }
      */
      // Delegate to the injected service
      final duration = await audioDurationGetter.getDuration(filePath);
      // Removed null check, getter implementation should throw if null
      /*
      if (duration == null) {
        throw AudioPlayerException(
          'Could not determine duration for file $filePath (possibly invalid/corrupt)',
        );
      }
      */
      return duration;
    } catch (e) {
      // Rethrow known exceptions from the getter
      if (e is RecordingFileNotFoundException || e is AudioPlayerException) {
        rethrow;
      }
      // Wrap unexpected errors
      throw AudioPlayerException(
        'Unexpected error getting audio duration for $filePath',
        e,
      );
    } /* finally {
      // Remove player disposal, handled by getter implementation
      await player.dispose();
    } */
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
    // TODO: Implement concatenation using ffmpeg_kit_flutter
    // 1. Validate input: check if list is empty or has less than 2 paths?
    if (inputFilePaths.length < 2) {
      throw ArgumentError('Need at least two files to concatenate.');
    }
    // 2. Check file existence for all inputs (using fileSystem.fileExists)
    for (final path in inputFilePaths) {
      if (!await fileSystem.fileExists(path)) {
        throw RecordingFileNotFoundException(
          'Input file not found for concatenation: $path',
        );
      }
    }

    // 3. Generate output path and temporary list file path
    final appDir = await pathProvider.getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/concat_$timestamp.m4a';
    final listFilePath = '${appDir.path}/ffmpeg_list_$timestamp.txt';

    // 4. Create ffmpeg command (using concat demuxer)
    //    - Create and write to the temporary list file
    String fileListContent = '';
    for (final path in inputFilePaths) {
      // FFmpeg requires paths to be escaped, especially on certain platforms
      // Simple approach: wrap in single quotes. Robust escaping might be needed.
      fileListContent += "file '$path'\n";
    }

    final listFile = File(listFilePath);
    try {
      await listFile.writeAsString(fileListContent);

      // Construct the command
      // -f concat: Use the concat demuxer
      // -safe 0: Necessary for using relative/absolute paths in the list file
      // -i listFilePath: Input file is the text file listing the real inputs
      // -c copy: Copy codecs without re-encoding (faster, avoids quality loss)
      // outputPath: The final output file
      final command =
          '-f concat -safe 0 -i "$listFilePath" -c copy "$outputPath"';

      // 5. Execute using FFmpegKit.executeAsync() for non-blocking
      // debugPrint('Executing FFmpeg command: $command'); // Optional debug log
      final session = await FFmpegKit.executeAsync(command);
      final returnCode = await session.getReturnCode();

      // 6. Check result code and logs
      if (ReturnCode.isSuccess(returnCode)) {
        // 8. Return output path on success
        // debugPrint('FFmpeg concatenation successful: $outputPath');
        return outputPath;
      } else {
        // Concatenation failed
        final logs = await session.getLogsAsString();
        // debugPrint('FFmpeg concatenation failed. Logs:\n$logs');
        throw AudioConcatenationException(
          'FFmpeg concatenation failed with return code $returnCode',
          null, // Pass null for originalException when it's an FFmpeg status code failure
          logs: logs,
        );
      }
    } catch (e) {
      // Catch errors during file writing or ffmpeg execution
      if (e is AudioConcatenationException) rethrow;
      throw AudioConcatenationException(
        'Error during concatenation process: ${e.toString()}',
        e, // Pass the caught exception as originalException
      );
    } finally {
      // 7. Delete temporary list file regardless of success/failure
      try {
        if (await listFile.exists()) {
          await listFile.delete();
        }
      } catch (_) {
        // Ignore errors during cleanup, but maybe log them?
        // debugPrint('Failed to delete temporary ffmpeg list file: $listFilePath');
      }
    }
    // Remove the UnimplementedError as logic is now present
    // throw UnimplementedError('Concatenation not implemented yet.');
  }
}
