import 'dart:async';
import 'dart:io'; // Using dart:io directly for temp list file operations

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
// TODO: Add logging

/// Abstract interface for audio concatenation operations.
abstract class AudioConcatenationService {
  /// Concatenates multiple audio recording files into a single new file.
  ///
  /// Takes a list of [inputFilePaths] to concatenate in the specified order.
  /// Returns the path to the newly created concatenated file.
  /// Throws [ArgumentError] if [inputFilePaths] is invalid.
  /// Throws [RecordingFileNotFoundException] if an input file doesn't exist.
  /// Throws [AudioConcatenationException] if concatenation fails.
  /// Throws [AudioFileSystemException] for underlying file system errors during checks.
  Future<String> concatenate(List<String> inputFilePaths);
}

/// Implementation of [AudioConcatenationService] using FFmpegKit.
class FFmpegAudioConcatenator implements AudioConcatenationService {
  final FileSystem fileSystem;
  final PathProvider pathProvider;

  FFmpegAudioConcatenator({
    required this.fileSystem,
    required this.pathProvider,
  });

  @override
  Future<String> concatenate(List<String> inputFilePaths) async {
    // 1. Validate input
    if (inputFilePaths.length < 2) {
      throw ArgumentError('Need at least two files to concatenate.');
    }

    // 2. Check file existence for all inputs
    // We need to catch FileSystemExceptions during the loop specifically
    // while letting RecordingFileNotFoundException propagate directly.
    try {
      for (final path in inputFilePaths) {
        bool exists = false;
        try {
          exists = await fileSystem.fileExists(path);
        } catch (e) {
          // If fileSystem.fileExists itself throws, wrap it immediately
          throw AudioFileSystemException(
            'Error checking input file existence for concatenation: $path',
            e,
          );
        }
        if (!exists) {
          throw RecordingFileNotFoundException(
            'Input file not found for concatenation: $path',
          );
        }
      }
    } on RecordingFileNotFoundException {
      rethrow; // Let this specific exception propagate out
    } on AudioFileSystemException {
      rethrow; // Let our wrapped exception propagate out
    }

    // 3. Generate output path and temporary list file path
    final Directory appDir =
        await pathProvider.getApplicationDocumentsDirectory();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String outputPath = '${appDir.path}/concat_$timestamp.m4a';
    final String listFilePath = '${appDir.path}/ffmpeg_list_$timestamp.txt';

    // 4. Create ffmpeg command (using concat demuxer)
    //    - Create and write to the temporary list file
    String fileListContent = '';
    for (final path in inputFilePaths) {
      // Simple quoting for paths, might need refinement for edge cases
      fileListContent += "file '$path'\\n";
    }

    // Using dart:io directly for temp file - Abstraction could be enhanced later
    final listFile = File(listFilePath);
    try {
      // Write the list file
      await listFile.writeAsString(fileListContent);

      // Construct the command
      final command =
          '-f concat -safe 0 -i "$listFilePath" -c copy "$outputPath"';

      // 5. Execute using FFmpegKit.executeAsync()
      // debugPrint('Executing FFmpeg command: $command');
      final session = await FFmpegKit.executeAsync(command);
      final returnCode = await session.getReturnCode();

      // 6. Check result code and logs
      if (ReturnCode.isSuccess(returnCode)) {
        // debugPrint('FFmpeg concatenation successful: $outputPath');
        // Verify output file exists? Optional belt-and-suspenders check.
        if (!await fileSystem.fileExists(outputPath)) {
          throw AudioConcatenationException(
            'FFmpeg reported success but output file not found: $outputPath',
            null,
            logs: await session.getLogsAsString(), // Include logs for debugging
          );
        }
        return outputPath;
      } else {
        final logs = await session.getLogsAsString();
        // debugPrint('FFmpeg concatenation failed. Logs:\\n$logs');
        throw AudioConcatenationException(
          'FFmpeg concatenation failed with return code $returnCode',
          null,
          logs: logs,
        );
      }
    } catch (e) {
      // Catch errors during list file writing or ffmpeg execution/checking
      if (e is AudioConcatenationException || e is AudioFileSystemException) {
        rethrow; // Don't wrap already specific exceptions
      }
      throw AudioConcatenationException(
        'Error during concatenation process: ${e.toString()}',
        e,
      );
    } finally {
      // 7. Delete temporary list file regardless of success/failure
      try {
        // Using dart:io directly for temp file cleanup
        if (await listFile.exists()) {
          await listFile.delete();
        }
      } catch (_) {
        // Log cleanup failure? For now, ignore.
        // debugPrint('Failed to delete temporary ffmpeg list file: $listFilePath');
      }
    }
  }
}
