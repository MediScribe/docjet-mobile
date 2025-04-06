import 'dart:async';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import '../services/audio_concatenation_service.dart';

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final PathProvider pathProvider;
  final PermissionHandler permissionHandler;
  final AudioConcatenationService audioConcatenationService;
  final FileSystem fileSystem;

  AudioLocalDataSourceImpl({
    required this.recorder,
    required this.pathProvider,
    required this.permissionHandler,
    required this.audioConcatenationService,
    required this.fileSystem,
  });

  @override
  Future<bool> checkPermission() async {
    try {
      final hasRecorderPerm = await recorder.hasPermission();
      if (hasRecorderPerm) {
        return true;
      }
      final status = await permissionHandler.status(Permission.microphone);
      return status == PermissionStatus.granted;
    } catch (e) {
      throw AudioPermissionException(
        'Failed to check microphone permission',
        e,
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final Map<Permission, PermissionStatus> statuses = await permissionHandler
          .request([Permission.microphone]);
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
            null,
          );
        }
      }

      final appDir = await pathProvider.getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final path = '${appDir.path}/rec_$timestamp.m4a';

      if (!await fileSystem.directoryExists(appDir.path)) {
        await fileSystem.createDirectory(appDir.path, recursive: true);
      }

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      return path;
    } on AudioPermissionException {
      rethrow;
    } catch (e) {
      throw AudioRecordingException('Failed to start recording', e);
    }
  }

  @override
  Future<String> stopRecording({required String recordingPath}) async {
    final path = recordingPath;

    try {
      await recorder.stop();

      if (!await fileSystem.fileExists(path)) {
        throw RecordingFileNotFoundException(
          'Recording file not found at $path after stopping.',
        );
      }
      return path;
    } catch (e) {
      if (e is RecordingFileNotFoundException) {
        rethrow;
      }
      throw AudioRecordingException('Failed to stop recording', e);
    }
  }

  @override
  Future<void> pauseRecording({required String recordingPath}) async {
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
    try {
      return await audioConcatenationService.concatenate(inputFilePaths);
    } catch (e) {
      rethrow;
    }
  }
}
