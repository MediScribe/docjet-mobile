import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Keep helper function global or move to a util file
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final VoidCallback onDelete;
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? error;

  const AudioPlayerWidget({
    required Key key,
    required this.filePath,
    required this.onDelete,
    required this.isPlaying,
    required this.isLoading,
    required this.currentPosition,
    required this.totalDuration,
    required this.error,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  // Use the logger instance potentially defined in your logger.dart util
  // Or instantiate one if necessary: final logger = Logger('AudioPlayerWidget');

  // Local state for dragging
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final bool canPlayPause = !widget.isLoading && widget.error == null;
    final bool canSeek =
        !widget.isLoading &&
        widget.error == null &&
        widget.totalDuration > Duration.zero;

    // Use milliseconds for slider precision
    final double sliderMax =
        (widget.totalDuration.inMilliseconds > 0
            ? widget.totalDuration.inMilliseconds.toDouble()
            : 1.0);
    final double currentPositionValue = widget.currentPosition.inMilliseconds
        .toDouble()
        .clamp(0.0, sliderMax);

    // Determine the actual value to display on the slider and text
    final displayValueMillis = _isDragging ? _dragValue : currentPositionValue;
    final displayPosition = Duration(milliseconds: displayValueMillis.toInt());

    final String positionText = _formatDuration(displayPosition);
    final String durationText = _formatDuration(widget.totalDuration);

    // logger.d(
    //   "AudioPlayerWidget: isPlaying=${widget.isPlaying}, path=${widget.filePath.split('/').last}",
    // );
    // logger.d("AudioPlayerWidget: canPlayPause=$canPlayPause");
    // logger.d(
    //   "AudioPlayerWidget: canSeek=$canSeek, totalDuration=$widget.totalDuration",
    // );
    // logger.d("AudioPlayerWidget: sliderValue=$currentPositionValue / $sliderMax");

    if (widget.isLoading) {
      return _buildLoadingIndicator();
    }

    if (widget.error != null) {
      return _buildErrorState(widget.error!);
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
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Recording',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls(BuildContext context) {
    final bool canPlayPause = !widget.isLoading && widget.error == null;
    final bool canSeek =
        !widget.isLoading &&
        widget.error == null &&
        widget.totalDuration > Duration.zero;

    final double sliderMax =
        (widget.totalDuration.inMilliseconds > 0
            ? widget.totalDuration.inMilliseconds.toDouble()
            : 1.0);
    final double currentPositionValue = widget.currentPosition.inMilliseconds
        .toDouble()
        .clamp(0.0, sliderMax);

    // Determine the actual value to display on the slider and text
    final displayValueMillis = _isDragging ? _dragValue : currentPositionValue;
    final displayPosition = Duration(milliseconds: displayValueMillis.toInt());

    final String positionText = _formatDuration(displayPosition);
    final String durationText = _formatDuration(widget.totalDuration);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              widget.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
            iconSize: 32,
            tooltip: widget.isPlaying ? 'Pause' : 'Play',
            onPressed:
                canPlayPause
                    ? () {
                      // logger.d(
                      //   'AudioPlayerWidget: Play/Pause Tapped! isPlaying = ${widget.isPlaying}, filePath = ${widget.filePath.split('/').last}',
                      // );
                      if (widget.isPlaying) {
                        context.read<AudioListCubit>().pauseRecording();
                      } else {
                        context.read<AudioListCubit>().playRecording(
                          widget.filePath,
                        );
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
                    value: displayValueMillis,
                    min: 0.0,
                    max: sliderMax,
                    onChanged:
                        canSeek
                            ? (value) {
                              // Update local drag value for immediate feedback
                              setState(() {
                                _isDragging = true;
                                _dragValue = value;
                              });
                              // Consider throttling or debouncing if this causes performance issues
                            }
                            : null,
                    onChangeEnd:
                        canSeek
                            ? (value) {
                              final seekPosition = Duration(
                                milliseconds: value.toInt(),
                              );
                              // Reset dragging flag
                              setState(() {
                                _isDragging = false;
                              });
                              // Call the cubit to perform the actual seek
                              context.read<AudioListCubit>().seekRecording(
                                widget.filePath,
                                seekPosition,
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
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
