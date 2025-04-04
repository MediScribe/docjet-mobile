import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'audio_recorder_state.dart';

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  AudioRecorderCubit() : super(AudioRecorderInitial());

  final recorder = AudioRecorder();
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  String? _originalFilePath;
  Duration? _originalDuration;

  void checkPermission() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        emit(AudioRecorderPermissionDenied());
      } else {
        emit(AudioRecorderReady());
      }
    } catch (e) {
      emit(AudioRecorderError('Failed to check permissions: $e'));
    }
  }

  Future<Duration> _getAudioDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(filePath);
      return duration ?? Duration.zero;
    } finally {
      await player.dispose();
    }
  }

  void startRecording({AudioRecordState? appendTo}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (appendTo != null) {
        _originalFilePath = appendTo.filePath;
        _originalDuration = await _getAudioDuration(_originalFilePath!);
        _currentRecordingPath = '${appDir.path}/temp_recording_$timestamp.m4a';
      } else {
        _currentRecordingPath = '${appDir.path}/recording_$timestamp.m4a';
      }

      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        emit(AudioRecorderError('Microphone permission not granted'));
        return;
      }

      _recordingStartTime = DateTime.now();
      await recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      emit(
        AudioRecorderRecording(
          filePath: _currentRecordingPath!,
          duration: Duration.zero,
        ),
      );

      // Start duration timer
      _updateDuration();
    } catch (e) {
      emit(AudioRecorderError('Failed to start recording: $e'));
    }
  }

  void _updateDuration() async {
    if (state is AudioRecorderRecording) {
      final duration = DateTime.now().difference(_recordingStartTime!);
      emit(
        AudioRecorderRecording(
          filePath: _currentRecordingPath!,
          duration: duration,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (state is AudioRecorderRecording) {
        _updateDuration();
      }
    }
  }

  Future<void> _concatenateAudioFiles(
    String outputPath,
    List<String> inputPaths,
  ) async {
    final recorder = AudioRecorder();
    final player = AudioPlayer();

    try {
      // Start recording the output
      await recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outputPath,
      );

      // Play each file in sequence
      for (final inputPath in inputPaths) {
        // Set up the audio source
        await player.setFilePath(inputPath);

        // Play and wait for completion
        await player.play();
        await player.processingStateStream.firstWhere(
          (state) => state == ProcessingState.completed,
        );
      }

      // Stop recording
      await recorder.stop();
    } finally {
      await player.dispose();
    }
  }

  void stopRecording() async {
    try {
      // First emit a temporary state to stop the timer
      emit(AudioRecorderLoading());

      await recorder.stop();
      final path = _currentRecordingPath!;
      final duration =
          _recordingStartTime != null
              ? DateTime.now().difference(_recordingStartTime!)
              : const Duration(seconds: 0);

      if (_originalFilePath != null) {
        try {
          // Create a new concatenated file
          final appDir = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final concatenatedPath = '${appDir.path}/concatenated_$timestamp.m4a';

          // Concatenate the audio files
          await _concatenateAudioFiles(concatenatedPath, [
            _originalFilePath!,
            path,
          ]);

          // Verify the concatenated file exists and has content
          final concatenatedFile = File(concatenatedPath);
          if (!await concatenatedFile.exists()) {
            throw Exception('Failed to create concatenated file');
          }

          final concatenatedSize = await concatenatedFile.length();
          if (concatenatedSize == 0) {
            throw Exception('Concatenated file is empty');
          }

          // Clean up temporary files
          try {
            await File(path).delete();
          } catch (e) {
            debugPrint('Error deleting temporary recording: $e');
          }

          try {
            await File(_originalFilePath!).delete();
          } catch (e) {
            debugPrint('Error deleting original file: $e');
          }

          // Move concatenated file to original location
          await concatenatedFile.rename(_originalFilePath!);

          final totalDuration = (_originalDuration ?? Duration.zero) + duration;
          final originalPath = _originalFilePath!;

          _currentRecordingPath = null;
          _recordingStartTime = null;
          _originalFilePath = null;
          _originalDuration = null;

          emit(
            AudioRecorderStopped(
              record: AudioRecordState(
                filePath: originalPath,
                duration: totalDuration,
                createdAt: DateTime.now(),
              ),
            ),
          );

          // Force a reload of the recordings list
          await Future.delayed(const Duration(milliseconds: 500));
          loadRecordings();
        } catch (e) {
          debugPrint('Error during audio concatenation: $e');
          // If concatenation fails, at least save the new recording
          _currentRecordingPath = null;
          _recordingStartTime = null;
          _originalFilePath = null;
          _originalDuration = null;

          emit(
            AudioRecorderStopped(
              record: AudioRecordState(
                filePath: path,
                duration: duration,
                createdAt: DateTime.now(),
              ),
            ),
          );

          // Force a reload of the recordings list
          await Future.delayed(const Duration(milliseconds: 500));
          loadRecordings();
        }
      } else {
        _currentRecordingPath = null;
        _recordingStartTime = null;
        _originalFilePath = null;
        _originalDuration = null;

        emit(
          AudioRecorderStopped(
            record: AudioRecordState(
              filePath: path,
              duration: duration,
              createdAt: DateTime.now(),
            ),
          ),
        );

        // Force a reload of the recordings list
        await Future.delayed(const Duration(milliseconds: 500));
        loadRecordings();
      }
    } catch (e) {
      emit(AudioRecorderError('Failed to stop recording: $e'));
    }
  }

  void pauseRecording() async {
    try {
      if (state is AudioRecorderRecording) {
        await recorder.pause();
        final recordingState = state as AudioRecorderRecording;
        emit(
          AudioRecorderPaused(
            filePath: recordingState.filePath,
            duration: recordingState.duration,
          ),
        );
      }
    } catch (e) {
      emit(AudioRecorderError('Failed to pause recording: $e'));
    }
  }

  void resumeRecording() async {
    try {
      if (state is AudioRecorderPaused) {
        await recorder.resume();
        final pausedState = state as AudioRecorderPaused;
        emit(
          AudioRecorderRecording(
            filePath: pausedState.filePath,
            duration: pausedState.duration,
          ),
        );
        _updateDuration();
      }
    } catch (e) {
      emit(AudioRecorderError('Failed to resume recording: $e'));
    }
  }

  void loadRecordings() async {
    try {
      emit(AudioRecorderLoading());

      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(appDir.path);
      final recordings = <AudioRecordState>[];

      if (await recordingsDir.exists()) {
        await for (final file in recordingsDir.list()) {
          if (file.path.endsWith('.m4a') &&
              !file.path.contains('temp_recording_') &&
              !file.path.contains('concatenated_')) {
            final stat = await File(file.path).stat();
            final duration = await _getAudioDuration(file.path);
            recordings.add(
              AudioRecordState(
                filePath: file.path,
                duration: duration,
                createdAt: stat.modified,
              ),
            );
          }
        }
      }

      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(AudioRecorderListLoaded(recordings: recordings));
    } catch (e) {
      emit(AudioRecorderError('Failed to load recordings: $e'));
    }
  }

  void deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      loadRecordings(); // Reload the list after deletion
    } catch (e) {
      emit(AudioRecorderError('Failed to delete recording: $e'));
    }
  }
}
