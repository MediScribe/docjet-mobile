import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

// Using centralized logger with level OFF
final logger = Logger(level: Level.off);

class AudioPlayerWidget extends StatelessWidget {
  final String filePath;
  final VoidCallback onDelete;
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? error;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.onDelete,
    required this.isPlaying,
    required this.isLoading,
    required this.currentPosition,
    required this.totalDuration,
    this.error,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingIndicator();
    }

    if (error != null) {
      return _buildErrorState(error!);
    }

    return _buildPlayerControls(context);
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.red),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Recording',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls(BuildContext context) {
    final bool canPlayPause = !isLoading && error == null;
    final bool canSeek =
        !isLoading && error == null && totalDuration > Duration.zero;

    final double sliderMax =
        (totalDuration.inSeconds > 0
            ? totalDuration.inSeconds.toDouble()
            : 1.0);
    final double sliderValue = currentPosition.inSeconds.toDouble().clamp(
      0.0,
      sliderMax,
    );

    final String positionText = _formatDuration(currentPosition);
    final String durationText = _formatDuration(totalDuration);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            ),
            iconSize: 32,
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed:
                canPlayPause
                    ? () {
                      if (isPlaying) {
                        context.read<AudioListCubit>().pauseRecording();
                      } else {
                        context.read<AudioListCubit>().playRecording(filePath);
                      }
                    }
                    : null,
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12.0,
                    ),
                  ),
                  child: Slider(
                    value: sliderValue,
                    min: 0.0,
                    max: sliderMax,
                    onChanged:
                        canSeek
                            ? (value) {
                              context.read<AudioListCubit>().seekRecording(
                                Duration(seconds: value.toInt()),
                              );
                            }
                            : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        positionText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        durationText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Recording',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
