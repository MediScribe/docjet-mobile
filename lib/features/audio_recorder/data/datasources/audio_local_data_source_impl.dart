import 'dart:async';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import '../services/audio_concatenation_service.dart';

import 'audio_local_data_source.dart';
import '../exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AudioRecorder recorder;
  final PathProvider pathProvider;
  final PermissionHandler permissionHandler;
  final AudioConcatenationService audioConcatenationService;
  final FileSystem fileSystem;
  final LocalJobStore localJobStore;
  final AudioPlayerAdapter audioPlayerAdapter;

  AudioLocalDataSourceImpl({
    required this.recorder,
    required this.pathProvider,
    required this.permissionHandler,
    required this.audioConcatenationService,
    required this.fileSystem,
    required this.localJobStore,
    required this.audioPlayerAdapter,
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
    try {
      final String? stoppedPath = await recorder.stop();

      if (stoppedPath == null) {
        throw const NoActiveRecordingException(
          'Failed to stop recording or recorder was not active.',
        );
      }

      if (!await fileSystem.fileExists(stoppedPath)) {
        throw RecordingFileNotFoundException(
          'Recording file not found at $stoppedPath after stopping.',
        );
      }

      final duration = await audioPlayerAdapter.getDuration(stoppedPath);
      final String relativeFilePath =
          stoppedPath.contains('/') ? stoppedPath.split('/').last : stoppedPath;
      final job = LocalJob(
        localFilePath: relativeFilePath,
        durationMillis: duration.inMilliseconds,
        status: TranscriptionStatus.created,
        localCreatedAt: DateTime.now(),
        backendId: null,
      );
      await localJobStore.saveJob(job);

      return stoppedPath;
    } catch (e) {
      if (e is RecordingFileNotFoundException ||
          e is NoActiveRecordingException) {
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
