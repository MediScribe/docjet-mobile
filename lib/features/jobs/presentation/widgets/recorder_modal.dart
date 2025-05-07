import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:docjet_mobile/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom-sheet modal that orchestrates recording & quick playback.
/// Pops with the **absolute** file path so the caller can persist it.
class RecorderModal extends StatelessWidget {
  const RecorderModal({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioCubit, AudioState>(
      builder: (context, audioState) {
        final audioCubit = context.read<AudioCubit>();

        // Are we currently recording or paused?
        final bool isRecordingPhase =
            audioState.phase == AudioPhase.recording ||
            audioState.phase == AudioPhase.recordingPaused;

        // Has a recording finished & been loaded into the player?
        final bool isAudioLoaded =
            audioState.filePath != null &&
            audioState.filePath!.isNotEmpty &&
            !isRecordingPhase;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAudioLoaded)
                const AudioPlayerWidget()
              else if (isRecordingPhase)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Pause / Resume (record) toggle
                    IconButton(
                      iconSize: 48,
                      tooltip:
                          audioState.phase == AudioPhase.recording
                              ? 'Pause'
                              : 'Resume',
                      icon: Icon(
                        audioState.phase == AudioPhase.recording
                            ? Icons.pause
                            : Icons.fiber_manual_record,
                        color:
                            audioState.phase == AudioPhase.recording
                                ? null
                                : Colors.red,
                      ),
                      onPressed: () {
                        if (audioState.phase == AudioPhase.recording) {
                          audioCubit.pauseRecording();
                        } else {
                          audioCubit.resumeRecording();
                        }
                      },
                    ),
                    // Stop button → finalises recording, keep modal open so user can review playback.
                    IconButton(
                      iconSize: 48,
                      tooltip: 'Stop Recording',
                      icon: const Icon(Icons.stop),
                      onPressed: () async {
                        await audioCubit.stopRecording();
                        // The modal stays open; when user dismisses, WillPopScope will pop with file path.
                      },
                    ),
                  ],
                )
              else
                // Idle – nothing recorded yet.
                IconButton(
                  iconSize: 64,
                  tooltip: 'Start Recording',
                  icon: const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                  ),
                  onPressed: audioCubit.startRecording,
                ),

              const SizedBox(height: 20),

              if (isRecordingPhase)
                Text(
                  'Recording: ${_formatDuration(audioState.position)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

              if (isAudioLoaded) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(audioCubit.state.filePath);
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
