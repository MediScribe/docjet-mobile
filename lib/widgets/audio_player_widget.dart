import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A reusable widget for audio playback controls.
///
/// This widget provides a play/pause button and a seek slider tied to
/// an [AudioCubit] for controlling audio playback.
class AudioPlayerWidget extends StatelessWidget {
  /// Creates a new [AudioPlayerWidget].
  const AudioPlayerWidget({super.key});

  static const double _iconSize = 42;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioCubit, AudioState>(
      builder: (context, state) {
        // Don't show player if no file loaded
        if (state.filePath == null) {
          return const SizedBox.shrink();
        }

        // Calculate slider progress
        final progress =
            state.duration.inMilliseconds > 0
                ? state.position.inMilliseconds / state.duration.inMilliseconds
                : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause Button and Position Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Play/Pause Button
                  IconButton(
                    iconSize: _iconSize,
                    tooltip:
                        state.phase == AudioPhase.playing ? 'Pause' : 'Play',
                    icon: Icon(
                      state.phase == AudioPhase.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () => _onPlayPausePressed(context, state),
                  ),

                  // Position Text
                  Text(
                    '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              // Seek Slider with semantics and onChangeEnd (reduce seek spam)
              Semantics(
                label: 'Seek position',
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (_) {}, // Allow thumb to move
                  onChangeEnd:
                      (value) => _onSliderChanged(context, value, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onPlayPausePressed(BuildContext context, AudioState state) {
    final audioCubit = context.read<AudioCubit>();

    if (state.phase == AudioPhase.playing) {
      audioCubit.pause();
    } else {
      audioCubit.play();
    }
  }

  void _onSliderChanged(BuildContext context, double value, AudioState state) {
    final audioCubit = context.read<AudioCubit>();
    final newPosition = Duration(
      milliseconds: (value * state.duration.inMilliseconds).round(),
    );

    audioCubit.seek(newPosition);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}
