import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

// Helper function (keep global or move to utils)
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
  // Set Logger Level to OFF to disable logging in this file
  final logger = LoggerFactory.getLogger(
    _AudioPlayerWidgetState,
    level: Level.off,
  );

  // Local state for slider dragging visual feedback
  bool _isDragging = false;
  double _dragValue = 0.0;

  // --- Fix for Seek Jump-Back ---
  // Flag to keep UI locked briefly after seek ends
  bool _waitingForSeekConfirm = false;
  // Store the final value the user dragged to
  double _finalDragValue = 0.0;
  // Timer to reset the flag
  Timer? _seekConfirmTimer;
  // --- End Fix ---

  // Timing variables for rebuild tracking
  static int _lastBuildTime = 0;
  static int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastBuild = _lastBuildTime > 0 ? now - _lastBuildTime : 0;
    _lastBuildTime = now;
    _buildCount++;

    final fileId = widget.filePath.split('/').last;
    logger.t(
      '[UI TIMING] Widget rebuild #$_buildCount for $fileId, ${timeSinceLastBuild}ms since last rebuild, isPlaying=${widget.isPlaying}, isLoading=${widget.isLoading}',
    );

    final logPrefix = '[WIDGET_BUILD $fileId]';
    logger.t(
      '$logPrefix Rebuilding - Props: isPlaying=${widget.isPlaying}, isLoading=${widget.isLoading}, pos=${widget.currentPosition.inMilliseconds}ms, dur=${widget.totalDuration.inMilliseconds}ms, error=${widget.error}, isDragging=$_isDragging, dragValue=$_dragValue',
    );

    final bool canPlayPause = !widget.isLoading && widget.error == null;
    final bool canSeek =
        !widget.isLoading &&
        widget.error == null &&
        widget.totalDuration > Duration.zero;

    // Use milliseconds for slider precision
    final double sliderMax =
        (widget.totalDuration.inMilliseconds > 0
            ? widget.totalDuration.inMilliseconds.toDouble()
            : 1.0); // Avoid division by zero if duration is 0
    final double currentPositionValue = widget.currentPosition.inMilliseconds
        .toDouble()
        .clamp(0.0, sliderMax); // Ensure value stays within bounds

    // Determine the actual value to display on the slider and text
    final double displayValueMillis;
    if (_waitingForSeekConfirm) {
      displayValueMillis =
          _finalDragValue; // Use final drag value while waiting
    } else {
      displayValueMillis = _isDragging ? _dragValue : currentPositionValue;
    }
    final displayPosition = Duration(
      milliseconds: displayValueMillis.round(),
    ); // Use round()

    final String positionText = _formatDuration(displayPosition);
    final String durationText = _formatDuration(widget.totalDuration);

    // Refined build log
    logger.t(
      '[WIDGET_BUILD $fileId] Props: isPlaying=${widget.isPlaying}, isLoading=${widget.isLoading}, pos=${widget.currentPosition.inMilliseconds}ms, dur=${widget.totalDuration.inMilliseconds}ms | State: isDragging=$_isDragging, dragValue=$_dragValue | Error: ${widget.error}',
    );

    if (widget.isLoading) {
      return _buildLoadingIndicator();
    }

    if (widget.error != null) {
      return _buildErrorState(widget.error!);
    }

    // Use helper method for cleaner build function
    return _buildPlayerControls(
      context,
      canPlayPause,
      canSeek,
      displayValueMillis,
      sliderMax,
      positionText,
      durationText,
    );
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

  Widget _buildPlayerControls(
    BuildContext context,
    bool canPlayPause,
    bool canSeek,
    double displayValueMillis,
    double sliderMax,
    String positionText,
    String durationText,
  ) {
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
            tooltip: widget.isPlaying ? 'Pause' : 'Play / Resume',
            onPressed:
                canPlayPause
                    ? () {
                      _handlePlayPause();
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
                              // Log only on drag start
                              if (!_isDragging) {
                                final fileId = widget.filePath.split('/').last;
                                logger.d(
                                  '[WIDGET_SEEK $fileId] onChangeStart: value=${value.round()}ms',
                                );
                              }
                              setState(() {
                                _isDragging = true;
                                _dragValue = value;
                              });
                            }
                            : null,
                    onChangeEnd:
                        canSeek
                            ? (value) {
                              // Log on drag end
                              final fileId = widget.filePath.split('/').last;
                              final seekPosition = Duration(
                                milliseconds: value.round(), // Use round()
                              );
                              logger.d(
                                '[WIDGET_SEEK $fileId] onChangeEnd: value=${value.round()}ms -> Calling seekRecording',
                              );
                              // --- Fix for Seek Jump-Back ---
                              setState(() {
                                _isDragging = false;
                                _waitingForSeekConfirm = true; // Lock UI
                                _finalDragValue = value; // Store final value
                              });
                              // Cancel any previous timer
                              _seekConfirmTimer?.cancel();
                              // Start timer to unlock UI after debounce+buffer
                              _seekConfirmTimer = Timer(
                                const Duration(milliseconds: 150),
                                () {
                                  if (mounted) {
                                    // Check if widget is still mounted
                                    setState(
                                      () => _waitingForSeekConfirm = false,
                                    );
                                  }
                                },
                              );
                              // --- End Fix ---
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

  // Add logs for UI interaction events

  void _handlePlayPause() {
    final fileId = widget.filePath.split('/').last;
    final flowId =
        DateTime.now().millisecondsSinceEpoch % 10000; // Generate a flow ID
    // Demote flow start log to trace
    logger.t('[FLOW #$flowId] Play/Pause button pressed for $fileId');
    logger.d('[UI EVENT] Play/Pause button pressed for $fileId');

    // Get the current active file from the PlaybackInfo to see if it matches this widget
    final currentState = context.read<AudioListCubit>().state;
    final activeFilePath =
        currentState is AudioListLoaded
            ? currentState.playbackInfo.activeFilePath
            : null;
    final isActiveFilePlaying =
        currentState is AudioListLoaded
            ? currentState.playbackInfo.isPlaying
            : false;

    // Demote context check log to trace
    logger.t(
      '[FLOW #$flowId] [UI DECISION] $fileId - Context check: '
      'activeFilePath=${activeFilePath?.split('/').last}, '
      'isActiveFilePlaying=$isActiveFilePlaying, '
      'isThisWidgetTheActiveFile=${widget.filePath == activeFilePath}, '
      'widgetIsPlaying=${widget.isPlaying}',
    );

    // Demote before action log to trace
    logger.t(
      '[FLOW #$flowId] [UI DECISION] $fileId - Before action: isPlaying=${widget.isPlaying}, isLoading=${widget.isLoading}, position=${widget.currentPosition.inMilliseconds}ms, duration=${widget.totalDuration.inMilliseconds}ms',
    );

    // FIXED LOGIC: Only pause if this widget is for the active file
    final isThisWidgetTheActiveFile = widget.filePath == activeFilePath;

    if (widget.isPlaying && isThisWidgetTheActiveFile) {
      // Only pause if THIS widget represents the currently active file
      // Demote decision log to trace
      logger.t(
        '[FLOW #$flowId] [UI DECISION] $fileId - Widget is active and playing, calling pauseRecording()',
      );
      context.read<AudioListCubit>().pauseRecording();
    } else {
      // For all other cases, we want to play/resume this file
      if (widget.currentPosition > Duration.zero) {
        // Demote decision log to trace
        logger.t(
          '[FLOW #$flowId] [UI DECISION] $fileId - Widget reports position ${widget.currentPosition.inMilliseconds}ms, calling resumeRecording()',
        );
        context.read<AudioListCubit>().resumeRecording();
      } else {
        // Demote decision log to trace
        logger.t(
          '[FLOW #$flowId] [UI DECISION] $fileId - Widget reports zero position, calling playRecording()',
        );
        context.read<AudioListCubit>().playRecording(widget.filePath);
      }
    }
  }

  @override
  void dispose() {
    _seekConfirmTimer?.cancel(); // Cancel timer if widget is disposed
    super.dispose();
  }
}
