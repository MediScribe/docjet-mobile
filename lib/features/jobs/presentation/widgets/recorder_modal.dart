import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:docjet_mobile/core/theme/app_color_tokens.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/widgets/buttons/circular_action_button.dart';
import 'package:docjet_mobile/core/widgets/buttons/record_start_button.dart';
import 'package:docjet_mobile/widgets/audio_player_widget.dart';

/// A modal bottom sheet for recording and previewing audio
class RecorderModal extends StatelessWidget {
  const RecorderModal({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioCubit, AudioState>(
      builder: (context, audioState) {
        final audioCubit = context.read<AudioCubit>();
        final appColors = getAppColors(context);
        final ThemeData theme = Theme.of(context);
        final Color defaultBgColor =
            theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

        // Determine the state of recording
        final bool isRecordingPhase =
            audioState.phase == AudioPhase.recording ||
            audioState.phase == AudioPhase.recordingPaused;

        final bool isAudioLoaded =
            audioState.filePath != null &&
            audioState.filePath!.isNotEmpty &&
            !isRecordingPhase;

        // Determine background color based on state using theme tokens
        Color currentBgColor;
        bool isActivelyRecordingOrPaused = false;

        switch (audioState.phase) {
          case AudioPhase.recording:
            currentBgColor = appColors.colorSemanticRecordBackground;
            isActivelyRecordingOrPaused = true;
            break;
          case AudioPhase.recordingPaused:
            currentBgColor = appColors.colorSemanticPausedBackground;
            isActivelyRecordingOrPaused = true;
            break;
          default: // idle, loading, playing, playingPaused
            currentBgColor = defaultBgColor;
            isActivelyRecordingOrPaused = false;
        }

        // Determine default text color based on background
        final Color defaultTextColor =
            isActivelyRecordingOrPaused
                ? Colors
                    .white // Keep white for red/blue semantic backgrounds
                : theme.textTheme.bodyMedium?.color ?? Colors.black;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: currentBgColor,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 50,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAudioLoaded)
                  const AudioPlayerWidget()
                else if (isRecordingPhase)
                  _buildRecordingControls(
                    context,
                    audioState,
                    audioCubit,
                    theme,
                    defaultTextColor,
                  )
                else
                  RecordStartButton(onTap: audioCubit.startRecording),

                if (isAudioLoaded) ...[
                  const SizedBox(height: 16),
                  _buildActionButtons(context, audioCubit, appColors),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the recording controls UI section
  Widget _buildRecordingControls(
    BuildContext context,
    AudioState audioState,
    AudioCubit audioCubit,
    ThemeData theme,
    Color textColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatDuration(audioState.position),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          audioState.phase == AudioPhase.recording
              ? 'Recording'
              : 'Recording paused',
          style: theme.textTheme.titleMedium?.copyWith(color: textColor),
        ),
        const SizedBox(height: 24.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (audioState.phase == AudioPhase.recording)
              CircularActionButton(
                tooltip: 'Pause',
                buttonColor: Colors.white,
                size: 64.0,
                onTap: audioCubit.pauseRecording,
                child: const Icon(Icons.pause, size: 32.0, color: Colors.red),
              )
            else if (audioState.phase == AudioPhase.recordingPaused)
              CircularActionButton(
                tooltip: 'Resume',
                buttonColor: Colors.white,
                size: 64.0,
                onTap: audioCubit.resumeRecording,
                child: const Icon(
                  Icons.play_arrow,
                  size: 40.0,
                  color: Colors.red,
                ),
              ),
            CircularActionButton(
              tooltip: 'Stop Recording',
              buttonColor: Colors.white,
              size: 64.0,
              onTap: () async {
                await audioCubit.stopRecording();
              },
              child: Container(
                width: 28.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the action buttons (Accept/Cancel) for the audio playback UI
  Widget _buildActionButtons(
    BuildContext context,
    AudioCubit audioCubit,
    AppColorTokens appColors,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text('Accept'),
          style: ElevatedButton.styleFrom(
            backgroundColor: appColors.colorInteractivePrimaryBackground,
            foregroundColor: appColors.colorInteractivePrimaryForeground,
          ),
          onPressed: () {
            Navigator.of(context).pop(audioCubit.state.filePath);
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.cancel),
          label: const Text('Cancel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: appColors.colorInteractiveSecondaryBackground,
            foregroundColor: appColors.colorInteractiveSecondaryForeground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Formats duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
