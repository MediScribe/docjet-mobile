import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart'; // For duration check
import 'package:meta/meta.dart'; // Import for annotation

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart'; // Import the specific exceptions

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final Permission microphonePermission;
  // Add other dependencies like file system wrappers if needed

  AudioLocalDataSourceImpl({
    required this.recorder,
    this.microphonePermission = Permission.microphone,
  });

  @visibleForTesting
  String? currentRecordingPath;
  // Use setter for testing - RENAME to lowerCamelCase
  @visibleForTesting
  set testingSetCurrentRecordingPath(String? path) {
    currentRecordingPath = path;
  }

  @override
  Future<bool> checkPermission() async {
    try {
      // Using recorder.hasPermission() first, as noted in original code review
      final bool recorderHasPermission = await recorder.hasPermission();
      if (recorderHasPermission) {
        return true;
      }
      // Fallback or second check using permission_handler
      final status = await microphonePermission.status;
      return status.isGranted;
    } catch (e) {
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      throw AudioPermissionException('Failed to check permission status', e);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await microphonePermission.request();
      return status.isGranted;
    } catch (e) {
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
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
        // This specific check results in a permission exception
        throw const AudioPermissionException(
          'Microphone permission not granted to start recording',
        );
      }

      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${appDir.path}/recording_$timestamp.m4a';
      currentRecordingPath = filePath;

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
      currentRecordingPath = null;
      // Catch permission exception specifically if it wasn't caught above
      if (e is AudioPermissionException) {
        rethrow; // Rethrow the specific exception
      }
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      // Treat other errors as recording start failures
      throw AudioRecordingException('Failed to start recording', e);
    }
  }

  @override
  Future<String> stopRecording() async {
    try {
      await recorder.stop(); // Stop the recording first
      final path = currentRecordingPath;
      currentRecordingPath = null;

      if (path == null) {
        // If path was null, it means we weren't recording
        throw const NoActiveRecordingException(
          'No recording was in progress to stop.',
        );
      }
      // Verify file exists after stopping. If recorder.stop() doesn't throw,
      // but the file is missing, it's a specific file not found issue.
      if (!await File(path).exists()) {
        throw RecordingFileNotFoundException(
          'Recording file not found at $path after stopping.',
        );
      }
      return path;
    } catch (e) {
      // Clear path in case of error during recorder.stop() itself
      currentRecordingPath = null;
      // Rethrow specific exceptions if already caught
      if (e is NoActiveRecordingException ||
          e is RecordingFileNotFoundException) {
        rethrow;
      }
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      // Treat other errors as recording stop failures
      throw AudioRecordingException('Failed to stop recording', e);
    }
  }

  @override
  Future<void> pauseRecording() async {
    if (currentRecordingPath == null) {
      throw const NoActiveRecordingException('No active recording to pause.');
    }
    try {
      await recorder.pause();
    } catch (e) {
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      throw AudioRecordingException('Failed to pause recording', e);
    }
  }

  @override
  Future<void> resumeRecording() async {
    if (currentRecordingPath == null) {
      throw const NoActiveRecordingException('No active recording to resume.');
    }
    try {
      await recorder.resume();
    } catch (e) {
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      throw AudioRecordingException('Failed to resume recording', e);
    }
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      } else {
        // Optionally log or handle the case where the file didn't exist
        // For consistency, we might throw, or just complete silently.
        // Let's throw for clarity that the requested file wasn't there.
        throw RecordingFileNotFoundException(
          'File $filePath not found for deletion.',
        );
      }
    } catch (e) {
      if (e is RecordingFileNotFoundException) {
        rethrow;
      }
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      // Treat other errors as file system failures during deletion
      throw AudioFileSystemException('Failed to delete recording $filePath', e);
    }
  }

  @override
  Future<Duration> getAudioDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      // Check if file exists before trying to load
      if (!await File(filePath).exists()) {
        throw RecordingFileNotFoundException(
          'Audio file not found at $filePath',
        );
      }
      final duration = await player.setFilePath(filePath);
      // If duration is null, the file might be corrupted or not audio
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
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      // Treat other errors (like player exceptions) as player failures
      throw AudioPlayerException(
        'Failed to get audio duration for $filePath',
        e,
      );
    } finally {
      // Ensure player is always disposed
      await player.dispose();
    }
  }

  @override
  Future<List<String>> listRecordingFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Ensure the directory exists before trying to list
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
        // If we just created it, it's empty
        return [];
      }
      final files =
          appDir
              .listSync()
              .where((item) => item.path.endsWith('.m4a') && item is File)
              .map((item) => item.path)
              .toList();
      return files;
    } catch (e) {
      // TODO: Consider logging 'e' here if needed via a dedicated logger service
      // Treat errors during listing as file system failures
      throw AudioFileSystemException('Failed to list recording files', e);
    }
  }

  @override
  Future<String> concatenateRecordings(
    String originalFilePath,
    String newSegmentPath,
  ) async {
    // TODO: Implement robust concatenation using ffmpeg_kit_flutter or similar.
    // This current implementation is a placeholder and WILL NOT WORK.
    throw UnimplementedError(
      'Audio concatenation is not implemented yet. Investigate ffmpeg_kit_flutter.',
    );

    /*
    // Example conceptual steps (DO NOT USE THE OLD METHOD):
    1. Verify input files exist.
    2. Choose a robust library (e.g., ffmpeg_kit_flutter).
    3. Construct the ffmpeg command (e.g., using -i for inputs, -filter_complex concat=n=2:v=0:a=1 for audio).
       Ensure correct handling of paths and potential special characters.
    4. Define an output path.
    5. Execute the command using the library.
    6. Check the execution result and verify the output file.
    7. Clean up temporary files if necessary (e.g., the newSegmentPath might be temporary).
    8. Return the path of the final concatenated file.
    */
  }

  // TODO: Implement robust concatenation using ffmpeg_kit_flutter or similar.
  Future<String> concatenateAudioFiles(
    List<String> filePaths,
    String outputPath,
  ) async {
    // This is a placeholder and needs a real implementation!
    // print('Simulating concatenation...');
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate work
    // In a real scenario, you would use ffmpeg or similar here.
    // If successful, return the outputPath.
    // If failed, throw ConcatenationException.
    if (filePaths.isEmpty) throw Exception('No files to concatenate');
    // Example: throw ConcatenationException('FFmpeg failed with error code X');
    return outputPath; // Placeholder success
  }
}
